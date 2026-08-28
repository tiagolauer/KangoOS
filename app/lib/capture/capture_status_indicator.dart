import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'capture_status.dart';

class CaptureStatusIndicator extends StatelessWidget {
  const CaptureStatusIndicator({super.key, required this.controller});

  final CaptureStatusController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CaptureRuntimeStatus>(
      valueListenable: controller,
      builder: (context, status, _) {
        final indicators = <Widget>[
          if (status.microphoneActive)
            _StatusItem(
              icon: Icons.mic,
              label: AppLocalizations.of(context).microphoneCaptureActive,
            ),
          if (status.ocrActive)
            _StatusItem(
              icon: Icons.document_scanner_outlined,
              label: AppLocalizations.of(context).ocrCaptureActive,
            ),
          if (status.systemLocked)
            _StatusItem(
              icon: Icons.lock_outline,
              label: AppLocalizations.of(context).captureSuspendedLocked,
            ),
          if (status.userIdle && !status.systemLocked)
            _StatusItem(
              icon: Icons.hourglass_empty,
              label: AppLocalizations.of(context).captureIdleMode,
            ),
        ];
        if (indicators.isEmpty) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        return Semantics(
          liveRegion: true,
          child: ColoredBox(
            color: colors.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Wrap(spacing: 16, runSpacing: 8, children: indicators),
            ),
          ),
        );
      },
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
}
