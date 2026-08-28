enum LlmRole { system, user, assistant, tool }

/// How much the model should reason before answering. Maps to each
/// provider's own mechanism (OpenAI's `reasoning_effort`, Anthropic's
/// extended thinking, Gemini's thinking budget) — support and behavior
/// vary by provider and model; see each provider for specifics.
enum ReasoningEffort { fast, balanced, thinking }

class LlmMessage {
  const LlmMessage({
    required this.role,
    required this.content,
    this.toolCalls = const [],
    this.toolCallId,
    this.name,
  });

  final LlmRole role;
  final String content;
  final List<LlmToolCall> toolCalls;
  final String? toolCallId;
  final String? name;
}

class LlmToolDefinition {
  const LlmToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
}

class LlmToolCall {
  const LlmToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

enum LlmStopReason { completed, toolCalls, length, other }

class LlmResponse {
  const LlmResponse({
    required this.content,
    this.toolCalls = const [],
    this.stopReason = LlmStopReason.completed,
  });

  final String content;
  final List<LlmToolCall> toolCalls;
  final LlmStopReason stopReason;
}

abstract class LlmProvider {
  String get id;

  bool get supportsToolCalls => false;

  Stream<String> chat(List<LlmMessage> messages);

  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async => LlmResponse(content: await chat(messages).join());
}
