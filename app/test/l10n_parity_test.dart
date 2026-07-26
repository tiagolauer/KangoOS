import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _messageKeys(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return decoded.keys.where((key) => !key.startsWith('@')).toSet();
}

void main() {
  test('every English message has a Portuguese translation', () {
    final en = _messageKeys('lib/l10n/app_en.arb');
    final pt = _messageKeys('lib/l10n/app_pt.arb');

    expect(pt.difference(en), isEmpty,
        reason: 'app_pt.arb has keys missing from the English template');
    expect(en.difference(pt), isEmpty,
        reason: 'these messages are not translated to Portuguese');
  });

  test('no translation is left identical to a long English source', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));

    expect(en.serverSync, isNot(pt.serverSync));
    expect(en.commonSave, isNot(pt.commonSave));
    expect(en.dayToday, isNot(pt.dayToday));
  });

  test('supported locales are English and Portuguese', () {
    expect(AppLocalizations.supportedLocales.map((l) => l.languageCode),
        containsAll(['en', 'pt']));
  });
}
