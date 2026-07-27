import 'package:flutter/material.dart';

import 'code_highlight.dart';
import 'copy_button.dart';

class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = language?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(label, style: theme.textTheme.labelSmall),
              ),
              const Spacer(),
              CopyIconButton(text: code),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SelectableText.rich(highlightedCode(
              code,
              theme: codeHighlightTheme(theme.brightness),
              language: language,
              baseStyle: codeTextStyle(context),
            )),
          ),
        ],
      ),
    );
  }
}
