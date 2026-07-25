import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'capture_settings_repository.dart';
import 'capture_settings_screen.dart';

class ActivityTimelineScreen extends StatelessWidget {
  const ActivityTimelineScreen({
    super.key,
    required this.database,
    required this.captureSettingsRepository,
  });

  final KangoosDatabase database;
  final CaptureSettingsRepository captureSettingsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: 'Capture settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CaptureSettingsScreen(repository: captureSettingsRepository),
            )),
          ),
        ],
      ),
      body: StreamBuilder<List<Activity>>(
        stream: database.watchRecentActivities(),
        builder: (context, snapshot) {
          final activities = snapshot.data;
          if (activities == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (activities.isEmpty) {
            return const Center(child: Text('No activity captured yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                title: Text(
                  activity.windowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(activity.appName),
                trailing: Text(_formatTime(activity.capturedAt)),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }
}
