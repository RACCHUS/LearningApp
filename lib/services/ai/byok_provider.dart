import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'byok_release_gate.dart';

/// Supported AI providers for Bring-Your-Own-Key (BYOK) generation (ARCH-4).
enum AiProvider {
  gemini,
  openrouter,
  openai,
  mock;

  String get displayName {
    switch (this) {
      case AiProvider.gemini:
        return 'Google Gemini (AI Studio)';
      case AiProvider.openrouter:
        return 'OpenRouter (Multi-Model)';
      case AiProvider.openai:
        return 'OpenAI (Direct)';
      case AiProvider.mock:
        return 'Mock / Local Simulator';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProvider.gemini:
        return 'gemini-1.5-flash';
      case AiProvider.openrouter:
        return 'google/gemini-2.0-flash-001';
      case AiProvider.openai:
        return 'gpt-4o-mini';
      case AiProvider.mock:
        return 'mock-v1';
    }
  }

  String get defaultEndpoint {
    switch (this) {
      case AiProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AiProvider.openrouter:
        return 'https://openrouter.ai/api/v1';
      case AiProvider.openai:
        return 'https://api.openai.com/v1';
      case AiProvider.mock:
        return 'local://mock';
    }
  }
}

/// Configuration model for BYOK API keys and settings.
/// Strictly stored on the client side; NEVER transmitted to the LearningApp backend.
class ByokConfig {
  final AiProvider provider;
  final String apiKey;
  final String model;
  final String? customEndpoint;

  const ByokConfig({
    required this.provider,
    required this.apiKey,
    required this.model,
    this.customEndpoint,
  });

  bool get isConfigured =>
      provider == AiProvider.mock || apiKey.trim().isNotEmpty;

  String get endpoint => customEndpoint ?? provider.defaultEndpoint;

  ByokConfig copyWith({
    AiProvider? provider,
    String? apiKey,
    String? model,
    String? customEndpoint,
  }) {
    return ByokConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      customEndpoint: customEndpoint ?? this.customEndpoint,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'apiKey': apiKey,
        'model': model,
        if (customEndpoint != null) 'customEndpoint': customEndpoint,
      };

  factory ByokConfig.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String? ?? 'gemini';
    final provider = AiProvider.values.firstWhere(
      (p) => p.name == providerName,
      orElse: () => AiProvider.gemini,
    );
    return ByokConfig(
      provider: provider,
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? provider.defaultModel,
      customEndpoint: json['customEndpoint'] as String?,
    );
  }

  static const defaultMock = ByokConfig(
    provider: AiProvider.mock,
    apiKey: '',
    model: 'mock-v1',
  );
}

/// Legacy browser-local BYOK settings. Stored credentials are not encrypted;
/// saving is blocked pending remediation. Clear remains available.
class ByokStorageService {
  static const _prefKey = 'learningapp_byok_config';
  final SharedPreferences? _prefs;

  ByokStorageService([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<ByokConfig> loadConfig() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) {
        return ByokConfig(
          provider: AiProvider.gemini,
          apiKey: '',
          model: AiProvider.gemini.defaultModel,
        );
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ByokConfig.fromJson(map);
    } catch (_) {
      return ByokConfig(
        provider: AiProvider.gemini,
        apiKey: '',
        model: AiProvider.gemini.defaultModel,
      );
    }
  }

  Future<void> saveConfig(ByokConfig config) async {
    // Never persist new raw API keys while BYOK is suspended.
    ByokReleaseGate.requireEnabled();
    final prefs = await _getPrefs();
    await prefs.setString(_prefKey, jsonEncode(config.toJson()));
  }

  Future<void> clearConfig() async {
    final prefs = await _getPrefs();
    await prefs.remove(_prefKey);
  }
}

