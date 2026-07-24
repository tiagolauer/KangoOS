# kangoos_core

Pure Dart core engine for [KangoOS](../README.md): snippet storage (drift/SQLite), search and LLM adapter. Consumed by the `app` package via a path dependency.

## Usage

```dart
import 'package:kangoos_core/kangoos_core.dart';
import 'package:drift/drift.dart';

final db = KangoosDatabase.memory(); // or KangoosDatabase.native(File(path))

final id = await db.createSnippet(SnippetsCompanion.insert(
  title: 'Reverse a string',
  content: 'input.split("").reversed.join()',
  language: const Value('dart'),
  tags: const Value(['string', 'algorithm']),
));

final snippet = await db.getSnippetById(id);
```
