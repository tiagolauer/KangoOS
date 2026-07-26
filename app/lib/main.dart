import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'capture/activity_summary_service.dart';
import 'capture/audio_capture_service.dart';
import 'capture/capture_settings_repository.dart';
import 'capture/whisper_model_repository.dart';
import 'capture/window_capture_service.dart';
import 'database_encryption.dart';
import 'home/app_shell.dart';
import 'settings_repository.dart';
import 'theme/kangoos_theme.dart';
import 'tray/tray_service.dart';

const defaultEmbeddingModel = 'nomic-embed-text';

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
  final encryptionKey = await DatabaseEncryptionKeyProvider().getOrCreateKey();
  final databaseFile = File(p.join(supportDir.path, 'kangoos.db'));

  final KangoosDatabase database;
  try {
    if (KangoosDatabase.isPlaintextDatabase(databaseFile)) {
      KangoosDatabase.encryptPlaintextDatabase(databaseFile, encryptionKey);
    }
    database = KangoosDatabase.native(databaseFile, encryptionKey: encryptionKey);
    await database.allSnippets();
  } catch (e) {
    runApp(DatabaseErrorApp(error: e, databasePath: databaseFile.path));
    return;
  }

  final semanticSearch = SemanticSearch(
    database: database,
    embeddingProvider: OllamaEmbeddingProvider(model: defaultEmbeddingModel),
  );
  final captureSettingsRepository = CaptureSettingsRepository();
  final needsCaptureConsent =
      !(await captureSettingsRepository.hasShownConsent());
  if (needsCaptureConsent) {
    await captureSettingsRepository.save(const CaptureSettings(paused: true));
  }
  WindowCaptureService(
          database: database, settingsRepository: captureSettingsRepository)
      .start();
  ActivitySummaryService(
          database: database, settingsRepository: SettingsRepository())
      .start();
  AudioCaptureService(
    database: database,
    settingsRepository: captureSettingsRepository,
    modelRepository: WhisperModelRepository(),
  ).start();
  await TrayService(captureSettingsRepository: captureSettingsRepository)
      .init();

  runApp(KangoosApp(
    database: database,
    semanticSearch: semanticSearch,
    captureSettingsRepository: captureSettingsRepository,
    needsCaptureConsent: needsCaptureConsent,
  ));
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    required this.database,
    required this.semanticSearch,
    required this.captureSettingsRepository,
    this.needsCaptureConsent = false,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final CaptureSettingsRepository captureSettingsRepository;
  final bool needsCaptureConsent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: KangoosTheme.light,
      darkTheme: KangoosTheme.dark,
      themeMode: ThemeMode.system,
      home: AppShell(
        database: database,
        semanticSearch: semanticSearch,
        captureSettingsRepository: captureSettingsRepository,
        needsCaptureConsent: needsCaptureConsent,
      ),
    );
  }
}
