enum LlmRole { system, user, assistant }

class LlmMessage {
  const LlmMessage({required this.role, required this.content});

  final LlmRole role;
  final String content;
}

abstract class LlmProvider {
  String get id;

  Stream<String> chat(List<LlmMessage> messages);
}
