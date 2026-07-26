enum LlmRole { system, user, assistant }

/// How much the model should reason before answering. Maps to each
/// provider's own mechanism (OpenAI's `reasoning_effort`, Anthropic's
/// extended thinking, Gemini's thinking budget) — support and behavior
/// vary by provider and model; see each provider for specifics.
enum ReasoningEffort { fast, balanced, thinking }

class LlmMessage {
  const LlmMessage({required this.role, required this.content});

  final LlmRole role;
  final String content;
}

abstract class LlmProvider {
  String get id;

  Stream<String> chat(List<LlmMessage> messages);
}
