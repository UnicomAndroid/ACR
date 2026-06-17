import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';

/// OpenAI 兼容 API 调用服务
class OpenAIService {
  OpenAIService._();
  static final OpenAIService I = OpenAIService._();

  Future<String?> summarize({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String transcription,
  }) async {
    if (transcription.trim().isEmpty) return null;

    try {
      final client = OpenAIClient.withApiKey(apiKey, baseUrl: baseUrl);
      final res = await client.chat.completions.create(
        ChatCompletionCreateRequest(
          model: model,
          temperature: 0.3,
          maxTokens: 500,
          messages: [
            ChatMessage.system('你是一个通话内容摘要助手。请用简洁的中文总结：'
                '1. 通话主题 2. 关键要点（3-5条）3. 后续行动项。若内容非中文请用对应语言。'),
            ChatMessage.user(transcription),
          ],
        ),
      );
      return res.text;
    } catch (e) {
      debugPrint('OpenAI 摘要失败: $e');
      return null;
    }
  }
}
