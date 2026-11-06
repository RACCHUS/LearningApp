import 'dart:convert';
import 'package:http/http.dart' as http;
import 'byok_provider.dart';

/// Exception thrown during LLM inference or schema validation.
class LlmException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const LlmException(this.message, {this.statusCode, this.details});

  @override
  String toString() =>
      'LlmException($message${statusCode != null ? ', status: $statusCode' : ''})';
}

/// Abstract contract for LLM inference with structured JSON outputs (ARCH-4).
abstract class LlmClient {
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  });

  /// Factory to instantiate the appropriate client from a [ByokConfig].
  factory LlmClient.create(ByokConfig config, {http.Client? httpClient}) {
    switch (config.provider) {
      case AiProvider.gemini:
        return GeminiLlmClient(config, httpClient: httpClient);
      case AiProvider.openrouter:
      case AiProvider.openai:
        return OpenAiCompatibleLlmClient(config, httpClient: httpClient);
      case AiProvider.mock:
        return MockLlmClient();
    }
  }
}

/// Direct Google AI Studio Gemini API client with structured outputs.
class GeminiLlmClient implements LlmClient {
  final ByokConfig config;
  final http.Client _client;

  GeminiLlmClient(this.config, {http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  @override
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  }) async {
    final url = Uri.parse(
      '${config.endpoint}/models/${config.model}:generateContent?key=${config.apiKey}',
    );

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': jsonSchema,
        'temperature': 0.2,
      },
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
    };

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'] as String?;
          if (text != null && text.isNotEmpty) {
            return text;
          }
        }
      }
      throw const LlmException('Empty response received from Gemini API');
    } else {
      throw LlmException(
        'Gemini API request failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}

/// OpenAI-compatible client (works with OpenRouter and direct OpenAI endpoints).
class OpenAiCompatibleLlmClient implements LlmClient {
  final ByokConfig config;
  final http.Client _client;

  OpenAiCompatibleLlmClient(this.config, {http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  @override
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  }) async {
    final url = Uri.parse('${config.endpoint}/chat/completions');

    final headers = {
      'Authorization': 'Bearer ${config.apiKey}',
      'Content-Type': 'application/json',
      if (config.provider == AiProvider.openrouter) ...{
        'HTTP-Referer': 'https://learningapp.org',
        'X-Title': 'LearningApp PWA',
      },
    };

    final messages = [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': prompt},
    ];

    // Attempt OpenAI structured outputs (json_schema) first
    final payload = {
      'model': config.model,
      'messages': messages,
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'curriculum_output',
          'strict': true,
          'schema': jsonSchema,
        },
      },
      'temperature': 0.2,
    };

    var response = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(payload),
    );

    // If json_schema is unsupported by the specific endpoint/model, fallback to json_object
    if (response.statusCode == 400 && response.body.contains('response_format')) {
      final fallbackPayload = {
        'model': config.model,
        'messages': messages,
        'response_format': {'type': 'json_object'},
        'temperature': 0.2,
      };
      response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(fallbackPayload),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
      throw const LlmException('Empty choices in OpenAI-compatible response');
    } else {
      throw LlmException(
        'OpenAI API request failed: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}

/// High-fidelity offline Mock LLM client generating valid structured JSON responses.
class MockLlmClient implements LlmClient {
  final Map<String, String> responses = {};

  void setMockResponse(String promptSubstring, String jsonResponse) {
    responses[promptSubstring] = jsonResponse;
  }

  @override
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  }) async {
    for (final entry in responses.entries) {
      if (prompt.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default mock response: Haladyna-compliant assessment item
    return jsonEncode({
      'prompt':
          'Under the Florida Building Code, what is the minimum required ground slope away from foundation walls for the first 10 feet?',
      'options': [
        'At least 6 inches fall within 10 feet (5% grade)',
        'At least 2 inches fall within 10 feet (1.7% grade)',
        'At least 12 inches fall within 10 feet (10% grade)',
        'Level ground with continuous perimeter swales',
      ],
      'correct_index': 0,
      'explanation':
          'Option A is correct: FBC Section 1804.4 specifies a minimum 5% slope (6 inches within 10 feet) to ensure positive drainage away from foundations. Options B and D provide inadequate slope, while Option C exceeds minimum code requirements.',
      'source_citation': 'Florida Building Code (Building) §1804.4',
      'bloom_level': 'apply',
      'difficulty': 'intermediate',
      'expected_seconds': 60,
    });
  }
}

