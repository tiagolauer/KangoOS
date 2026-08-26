import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'capture/activity_summary_service.dart';
import 'capture/audio_capture_service.dart';
import 'capture/capture_settings_repository.dart';
import 'capture/capture_source_registry.dart';
import 'capture/capture_status.dart';
import 'capture/whisper_model_repository.dart';
import 'capture/window_capture_service.dart';
import 'database_encryption.dart';
import 'embedding/settings_embedding_provider.dart';
import 'home/app_shell.dart';
import 'memory/memory_compaction_service.dart';
import 'quick_capture_service.dart';
import 'runtime/kango_runtime.dart';
import 'settings_repository.dart';
import 'theme/kangoos_theme.dart';
import 'tray/tray_panel.dart';
import 'tray/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _startKangoos();
  } catch (error, stackTrace) {
    stderr.writeln('KangoOS failed to start: $error\n$stackTrace');
    runApp(StartupErrorApp(error: error));
  }
}

Future<void> _startKangoos() async {
  final supportDir = await getApplicationSupportDirectory();
  final environmentKey =
      databaseEncryptionKeyFromEnvironment(Platform.environment);
  final encryptionKey =
      environmentKey ?? await DatabaseEncryptionKeyProvider().getOrCreateKey();
  final databaseFile = File(
    Platform.environment[databasePathEnvironmentKey] ??
        p.join(supportDir.path, 'kangoos.db'),
  );

  final KangoosDatabase database;
  try {
    KangoosDatabase.applyPendingRestore(databaseFile, encryptionKey);
    KangoosDatabase.removePlaintextBackups(databaseFile);
    if (KangoosDatabase.isPlaintextDatabase(databaseFile)) {
      KangoosDatabase.encryptPlaintextDatabase(databaseFile, encryptionKey);
    }
    await KangoosDatabase.backupBeforeMigration(databaseFile, encryptionKey);
    database =
        KangoosDatabase.native(databaseFile, encryptionKey: encryptionKey);
    await database.allSnippets();
  } catch (e) {
    runApp(DatabaseErrorApp(error: e, databasePath: databaseFile.path));
    return;
  }

  final settingsRepository = SettingsRepository();
  final snippetRepository = SqliteSnippetRepository(database);
  final embeddingProvider =
      SettingsEmbeddingProvider(repository: settingsRepository);
  final semanticSearch = SemanticSearch(
    repository: snippetRepository,
    embeddingProvider: embeddingProvider,
  );
  final snippetService = SnippetService(
    repository: snippetRepository,
    semanticSearch: semanticSearch,
  );
  final activityRepository = SqliteActivityRepository(database);
  final summaryRepository = SqliteSummaryRepository(database);
  final conversationRepository = SqliteConversationRepository(database);
  final episodeRepository = SqliteEpisodeRepository(database);
  final captureSettingsRepository = CaptureSettingsRepository();
  final captureSourceRegistry = CaptureSourceRegistry();
  final captureStatus = CaptureStatusController();
  final memoryQueryEngine = MemoryQueryEngine(
    episodes: episodeRepository,
    embeddingProvider: embeddingProvider,
  );
  final memory = MemoryService(
    database: database,
    activities: activityRepository,
    summaries: summaryRepository,
    episodes: episodeRepository,
    queryEngine: memoryQueryEngine,
    privacyFilterProvider: () async => PrivacyFilter(
      redactPii: (await captureSettingsRepository.load()).redactPii,
    ),
  );
  final memoryFormation = MemoryFormationService(
    activities: activityRepository,
    episodes: episodeRepository,
    embeddingProvider: embeddingProvider,
  );
  final hierarchy = MemoryHierarchyService(
    episodes: episodeRepository,
    summaries: summaryRepository,
  );
  final needsCaptureConsent =
      !(await captureSettingsRepository.hasShownConsent());
  if (needsCaptureConsent) {
    await captureSettingsRepository.save(const CaptureSettings(paused: true));
  }
  final windowCapture = WindowCaptureService(
    memory: memory,
    settingsRepository: captureSettingsRepository,
    sourceRegistry: captureSourceRegistry,
    captureStatus: captureStatus,
  );
  final activitySummary = ActivitySummaryService(
    memory: memory,
    settingsRepository: settingsRepository,
    captureSettingsRepository: captureSettingsRepository,
    memoryFormation: memoryFormation,
  );
  final audioCapture = AudioCaptureService(
    memory: memory,
    settingsRepository: captureSettingsRepository,
    modelRepository: WhisperModelRepository(),
    sourceRegistry: captureSourceRegistry,
    captureStatus: captureStatus,
  );
  final memoryCompaction = MemoryCompactionService(hierarchy: hierarchy);
  final quickCapture = QuickCaptureService(
    snippets: snippetService,
  );
  late final KangoRuntime runtime;
  final tray = TrayService(
    captureSettingsRepository: captureSettingsRepository,
    onSaveClipboardAsSnippet: quickCapture.saveClipboard,
    onQuit: () => runtime.stop(),
  );
  runtime = KangoRuntime(
    services: [
      windowCapture,
      activitySummary,
      audioCapture,
      memoryCompaction,
      tray,
    ],
    onStopped: database.close,
  );
  await runtime.start();

  Future<void> restartAfterRestore() async {
    await runtime.stop();
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  runApp(KangoosApp(
    snippetRepository: snippetRepository,
    snippets: snippetService,
    memory: memory,
    conversations: conversationRepository,
    captureSettingsRepository: captureSettingsRepository,
    captureStatus: captureStatus,
    needsCaptureConsent: needsCaptureConsent,
    trayService: tray,
    onRestoreStaged: restartAfterRestore,
  ));
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('pt'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: KangoosTheme.light,
      darkTheme: KangoosTheme.dark,
      themeMode: ThemeMode.system,
      home: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.startupErrorTitle,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(l10n.startupErrorBody),
                    const SizedBox(height: 12),
                    SelectableText('$error',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({
    super.key,
    required this.error,
    required this.databasePath,
  });

  final Object error;
  final String databasePath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('pt'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: KangoosTheme.light,
      darkTheme: KangoosTheme.dark,
      themeMode: ThemeMode.system,
      home: Builder(builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.databaseErrorTitle,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(l10n.databaseErrorBody),
                    const SizedBox(height: 12),
                    SelectableText(l10n.databaseErrorPath(databasePath)),
                    const SizedBox(height: 12),
                    SelectableText('$error',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class KangoosApp extends StatelessWidget {
  const KangoosApp({
    super.key,
    required this.snippetRepository,
    required this.snippets,
    required this.memory,
    required this.conversations,
    required this.captureSettingsRepository,
    this.captureStatus,
    this.needsCaptureConsent = false,
    this.trayService,
    this.onRestoreStaged,
  });

  final SnippetRepository snippetRepository;
  final SnippetService snippets;
  final MemoryService memory;
  final ConversationRepository conversations;
  final CaptureSettingsRepository captureSettingsRepository;
  final CaptureStatusController? captureStatus;
  final bool needsCaptureConsent;
  final TrayService? trayService;
  final Future<void> Function()? onRestoreStaged;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('pt'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: KangoosTheme.light,
      darkTheme: KangoosTheme.dark,
      themeMode: ThemeMode.system,
      home: _home(),
    );
  }

  Widget _home() {
    final appShell = AppShell(
      snippetRepository: snippetRepository,
      snippets: snippets,
      memory: memory,
      conversations: conversations,
      captureSettingsRepository: captureSettingsRepository,
      captureStatus: captureStatus,
      needsCaptureConsent: needsCaptureConsent,
      onRestoreStaged: onRestoreStaged,
    );
    final tray = trayService;
    if (tray == null) return appShell;
    final trayPanel = Theme(
      data: KangoosTheme.dark,
      child: TrayPanel(
        captureSettingsRepository: captureSettingsRepository,
        captureStatus: captureStatus,
        onOpen: tray.showMainWindow,
        onHide: tray.hideTrayPanel,
        onToggleCapture: tray.toggleCapture,
        onQuickCapture: tray.saveClipboardAsSnippet,
        onQuit: tray.quit,
      ),
    );

    return ValueListenableBuilder<bool>(
      valueListenable: tray.panelVisible,
      builder: (context, visible, _) {
        return IndexedStack(
          index: visible ? 1 : 0,
          children: [appShell, trayPanel],
        );
      },
    );
  }
}
