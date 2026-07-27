import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../code_block.dart';
import '../code_highlight.dart';

const _languageClassPrefix = 'language-';

class MarkdownMessage extends StatelessWidget {
  const MarkdownMessage({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium,
        listBullet: theme.textTheme.bodyMedium,
        code: codeTextStyle(context)
            .copyWith(backgroundColor: colors.surfaceContainerHigh),
        blockquoteDecoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      builders: {'pre': _CodeBlockBuilder()},
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitText(md.Text text, TextStyle? preferredStyle) =>
      const SizedBox.shrink();

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return CodeBlock(
      code: element.textContent.trimRight(),
      language: _languageOf(element),
    );
  }

  String? _languageOf(md.Element element) {
    final children =
        element.children?.whereType<md.Element>() ?? const <md.Element>[];
    if (children.isEmpty) return null;
    final className = children.first.attributes['class'];
    if (className == null || !className.startsWith(_languageClassPrefix)) {
      return null;
    }
    return className.substring(_languageClassPrefix.length);
  }
}
