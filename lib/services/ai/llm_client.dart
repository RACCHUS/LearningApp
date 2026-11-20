import 'dart:convert';
import 'package:http/http.dart' as http;
import 'byok_provider.dart';
import 'byok_release_gate.dart';
import 'llm_failure.dart';

export 'llm_failure.dart' show LlmFailureKind;

/// Exception thrown during LLM inference or schema validation.
class LlmException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  /// What went wrong, for choosing the learner message and whether to retry.
  final LlmFailureKind kind;

  /// How long the provider asked us to wait, when it said.
  final Duration? retryAfter;

  const LlmException(
    this.message, {
    this.statusCode,
    this.details,
    this.kind = LlmFailureKind.unknown,
    this.retryAfter,
  });

  /// Builds the exception for a non-2xx provider response. The body is
  /// read for its error code only and is not kept.
  factory LlmException.fromResponse(AiProvider provider, http.Response r) {
    final c = classifyProviderError(
      provider,
      r.statusCode,
      r.body,
      headers: r.headers,
    );
    return LlmException(
      'AI provider request failed (${c.kind.name}).',
      statusCode: r.statusCode,
      kind: c.kind,
      retryAfter: c.retryAfter,
    );
  }

  @override
  String toString() =>
      'LlmException($message${statusCode != null ? ', status: $statusCode' : ''})';
}

/// Explicit allowlist: browser-supplied custom URLs must never receive an
/// API credential. Local models and delegated OAuth require separate reviewed
/// transports rather than the credential-bearing BYOK HTTP client.
abstract final class ByokEndpointPolicy {
  static bool isApproved(ByokConfig config) {
    if (config.provider == AiProvider.mock) return true;
    if (config.customEndpoint != null) return false;
    final endpoint = Uri.tryParse(config.endpoint);
    return endpoint != null &&
        endpoint.scheme == 'https' &&
        endpoint.userInfo.isEmpty &&
        endpoint.query.isEmpty &&
        endpoint.fragment.isEmpty &&
        config.endpoint == config.provider.defaultEndpoint;
  }

  static void requireApproved(ByokConfig config) {
    if (!isApproved(config)) {
      throw const LlmException('This BYOK provider endpoint is not approved.');
    }
  }
}

/// Abstract contract for LLM inference with structured JSON outputs (ARCH-4).
abstract class LlmClient {
  Future<String> generateStructuredJson({
    required String prompt,
    required Map<String, dynamic> jsonSchema,
    String? systemPrompt,
  });

  /// Sends [prompt] as a plain chat message and returns the reply text,
  /// exactly as a learner would copy it from a chat. The app's own paste
  /// pipeline (fences, sentinels, validation) then reads it, so a reply
  /// from a key and a pasted reply are checked the same way.
  Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 8192,
  });

  /// Model IDs this key can use for text generation, so settings can offer
  /// real choices instead of a hard-coded name that may be retired.
  Future<List<String>> listModels();

  /// Factory to instantiate the appropriate client from a [ByokConfig].
  factory LlmClient.create(ByokConfig config, {http.Client? httpClient}) {
    ByokReleaseGate.requireEnabled();
    ByokEndpointPolicy.requireApproved(config);
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
    // Direct construction must not bypass the owner safety latch.
    ByokReleaseGate.requireEnabled();
    ByokEndpointPolicy.requireApproved(config);
    if (config.apiKey.trim().isEmpty) {
      throw const LlmException('No BYOK credential supplied.');
    }
    final url = Uri.parse(
      '${config.endpoint}/models/${Uri.encodeComponent(config.model)}:generateContent',
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

    final response = await _send(
      () => _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey,
        },
        body: jsonEncode(payload),
      ),
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
      throw LlmException.fromResponse(AiProvider.gemini, response);
    }
  }

  void _requireReady() {
    // Direct construction must not bypass the owner safety latch.
    ByokReleaseGate.requireEnabled();
    ByokEndpointPolicy.requireApproved(config);
    if (config.apiKey.trim().isEmpty) {
      throw const LlmException(
        'No BYOK credential supplied.',
        kind: LlmFailureKind.badCredential,
      );
    }
  }

  @override
  Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 8192,
  }) async {
    _requireReady();
    final url = Uri.parse(
      '${config.endpoint}/models/${Uri.encodeComponent(config.model)}:generateContent',
    );
    final response = await _send(
      () => _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': config.apiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.4,
            'maxOutputTokens': maxOutputTokens,
          },
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException.fromResponse(AiProvider.gemini, response);
    }
    final data = jsonDecode(response.body);
    if (data is! Map) {
      throw const LlmException('Empty reply', kind: LlmFailureKind.emptyReply);
    }
    final feedback = data['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] != null) {
      throw const LlmException('Prompt blocked', kind: LlmFailureKind.blocked);
    }
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates[0] is! Map) {
      throw const LlmException('Empty reply', kind: LlmFailureKind.emptyReply);
    }
    final first = candidates[0] as Map;
    final content = first['content'];
    final parts = content is Map ? content['parts'] : null;
    final text = parts is List
        ? [
            for (final p in parts)
              if (p is Map && p['text'] is String && p['thought'] != true)
                p['text'] as String,
          ].join()
        : '';
    final reason = '${first['finishReason'] ?? ''}';
    if (text.trim().isEmpty) {
      const refused = {'SAFETY', 'PROHIBITED_CONTENT', 'BLOCKLIST', 'SPII'};
      throw LlmException(
        'No text in reply ($reason)',
        kind: refused.contains(reason)
            ? LlmFailureKind.blocked
            : LlmFailureKind.emptyReply,
      );
    }
    // A reply cut off at MAX_TOKENS is still returned: the paste pipeline
    // keeps the finished items and asks only for the rest.
    return text;
  }

  @override
  Future<List<String>> listModels() async {
    _requireReady();
    final response = await _send(
      () => _client.get(
        Uri.parse('${config.endpoint}/models?pageSize=200'),
        headers: {'x-goog-api-key': config.apiKey},
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException.fromResponse(AiProvider.gemini, response);
    }
    final data = jsonDecode(response.body);
    final models = data is Map ? data['models'] : null;
    if (models is! List) return const [];
    return [
      for (final m in models)
        if (m is Map &&
            m['name'] is String &&
            m['supportedGenerationMethods'] is List &&
            (m['supportedGenerationMethods'] as List)
                .contains('generateContent'))
          (m['name'] as String).replaceFirst('models/', ''),
    ];
  }
}

/// Runs one HTTP call, turning transport failures (offline, CORS, DNS)
/// into a classified [LlmException].
Future<http.Response> _send(Future<http.Response> Function() call) async {
  try {
    return await call();
  } on LlmException {
    rethrow;
  } catch (_) {
    throw const LlmException(
      'Could not reach the AI provider.',
      kind: LlmFailureKind.network,
    );
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
    // Direct construction must not bypass the owner safety latch.
    ByokReleaseGate.requireEnabled();
    ByokEndpointPolicy.requireApproved(config);
    if (config.apiKey.trim().isEmpty) {
      throw const LlmException('No BYOK credential supplied.');
    }
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

    var response = await _send(
      () => _client.post(url, headers: headers, body: jsonEncode(payload)),
    );

    // If json_schema is unsupported by the specific endpoint/model, fallback to json_object
    if (response.statusCode == 400 && response.body.contains('response_format')) {
      final fallbackPayload = {
        'model': config.model,
        'messages': messages,
        'response_format': {'type': 'json_object'},
        'temperature': 0.2,
      };
      response = await _send(
        () => _client.post(
          url,
          headers: headers,
          body: jsonEncode(fallbackPayload),
        ),
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
      throw LlmException.fromResponse(config.provider, response);
    }
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${config.apiKey}',
        'Content-Type': 'application/json',
        if (config.provider == AiProvider.openrouter) ...{
          'HTTP-Referer': 'https://learningapp.org',
          'X-Title': 'LearningApp PWA',
        },
      };

  void _requireReady() {
    ByokReleaseGate.requireEnabled();
    ByokEndpointPolicy.requireApproved(config);
    if (config.apiKey.trim().isEmpty) {
      throw const LlmException(
        'No BYOK credential supplied.',
        kind: LlmFailureKind.badCredential,
      );
    }
  }

  @override
  Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 8192,
  }) async {
    _requireReady();
    // No token cap is sent: OpenAI models disagree on the parameter name,
    // and an unknown one fails the whole request.
    final response = await _send(
      () => _client.post(
        Uri.parse('${config.endpoint}/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': config.model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException.fromResponse(config.provider, response);
    }
    final data = jsonDecode(response.body);
    final choices = data is Map ? data['choices'] : null;
    final message = choices is List && choices.isNotEmpty && choices[0] is Map
        ? (choices[0] as Map)['message']
        : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      final refusal = message is Map ? message['refusal'] : null;
      throw LlmException(
        'No text in reply',
        kind: refusal != null
            ? LlmFailureKind.blocked
            : LlmFailureKind.emptyReply,
      );
    }
    return content;
  }

  @override
  Future<List<String>> listModels() async {
    _requireReady();
    final response = await _send(
      () => _client.get(
        Uri.parse('${config.endpoint}/models'),
        headers: _headers,
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException.fromResponse(config.provider, response);
    }
    final data = jsonDecode(response.body);
    final models = data is Map ? data['data'] : null;
    if (models is! List) return const [];
    return [
      for (final m in models)
        if (m is Map && m['id'] is String) m['id'] as String,
    ]..sort();
  }
}

/// High-fidelity offline Mock LLM client generating valid structured JSON responses.
class MockLlmClient implements LlmClient {
  final Map<String, String> responses = {};

  @override
  Future<String> generateText({
    required String prompt,
    int maxOutputTokens = 8192,
  }) async {
    for (final entry in responses.entries) {
      if (prompt.contains(entry.key)) return entry.value;
    }
    throw const LlmException(
      'The simulator has no reply for this prompt.',
      kind: LlmFailureKind.emptyReply,
    );
  }

  @override
  Future<List<String>> listModels() async => const ['mock-v1'];

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

