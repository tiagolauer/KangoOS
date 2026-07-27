import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

const _confirmationDuration = Duration(seconds: 2);

Future<void> copyTextToClipboard(BuildContext context, String text) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  messenger.showSnackBar(SnackBar(
    content: Text(l10n.copiedToClipboard),
    duration: _confirmationDuration,
  ));
}

class CopyIconButton extends StatelessWidget {
  const CopyIconButton({super.key, required this.text, this.iconSize = 16});

  final String text;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.copy_all_outlined, size: iconSize),
      tooltip: AppLocalizations.of(context).copyToClipboard,
      visualDensity: VisualDensity.compact,
      onPressed: () => copyTextToClipboard(context, text),
    );
  }
}
