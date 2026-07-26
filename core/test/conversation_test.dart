import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  test('createConversation then appendMessage round-trips through messagesForConversation',
      () async {
    final id = await database.createConversation();

    await database.appendMessage(id, LlmRole.user, 'hello');
    await database.appendMessage(id, LlmRole.assistant, 'hi there');

    final messages = await database.messagesForConversation(id);
    expect(messages, hasLength(2));
    expect(messages[0].role, LlmRole.user);
    expect(messages[0].content, 'hello');
    expect(messages[1].role, LlmRole.assistant);
    expect(messages[1].content, 'hi there');
  });

  test('latestConversationId returns the most recently updated conversation', () async {
    expect(await database.latestConversationId(), isNull);

    final first = await database.createConversation();
    final second = await database.createConversation();
    expect(await database.latestConversationId(), second);

    await database.appendMessage(first, LlmRole.user, 'bump me');
    expect(await database.latestConversationId(), first);
  });

  test('messagesForConversation only returns messages for that conversation', () async {
    final a = await database.createConversation();
    final b = await database.createConversation();
    await database.appendMessage(a, LlmRole.user, 'in a');
    await database.appendMessage(b, LlmRole.user, 'in b');

    final messages = await database.messagesForConversation(a);
    expect(messages, hasLength(1));
    expect(messages.single.content, 'in a');
  });
}
