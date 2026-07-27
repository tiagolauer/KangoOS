import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight.dart' show highlight, Node;

import 'theme/kangoos_theme.dart';

const _plaintext = 'plaintext';
const _rootStyleKey = 'root';

Map<String, TextStyle> codeHighlightTheme(Brightness brightness) =>
    brightness == Brightness.dark ? atomOneDarkTheme : atomOneLightTheme;

TextStyle codeTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  final root = codeHighlightTheme(theme.brightness)[_rootStyleKey];
  return TextStyle(
    fontFamilyFallback: KangoosTheme.monoFallback,
    fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) - 1,
    height: 1.45,
    color: root?.color ?? theme.colorScheme.onSurface,
  );
}

TextSpan highlightedCode(
  String source, {
  required Map<String, TextStyle> theme,
  String? language,
  TextStyle? baseStyle,
}) {
  final result = highlight.parse(source, language: _knownLanguage(language));
  return TextSpan(
    style: baseStyle,
    children: _spans(result.nodes ?? const <Node>[], theme),
  );
}

String _knownLanguage(String? language) {
  final name = language?.trim().toLowerCase();
  return (name == null || name.isEmpty) ? _plaintext : name;
}

List<TextSpan> _spans(List<Node> nodes, Map<String, TextStyle> theme) {
  return [
    for (final node in nodes)
      if (node.value != null)
        TextSpan(text: node.value, style: theme[node.className ?? ''])
      else
        TextSpan(
          style: theme[node.className ?? ''],
          children: _spans(node.children ?? const <Node>[], theme),
        ),
  ];
}

class HighlightedCodeController extends TextEditingController {
  HighlightedCodeController({super.text, String? language})
      : _language = language;

  String? _language;

  set language(String? value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return highlightedCode(
      text,
      theme: codeHighlightTheme(Theme.of(context).brightness),
      language: _language,
      baseStyle: style,
    );
  }
}
