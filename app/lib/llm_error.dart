import 'dart:async';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

String describeLlmError(AppLocalizations l10n, Object error) =>
    error is TimeoutException
        ? l10n.llmTimedOut(defaultLlmTimeout.inSeconds)
        : '$error';
