import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:notlyfe/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AiProviderType {
  gemini('Google Gemini', 'gemini'),
  openai('ChatGPT (OpenAI)', 'openai'),
  claude('Claude (Anthropic)', 'claude');

  final String displayName;
  final String key;
  const AiProviderType(this.displayName, this.key);

  static AiProviderType fromKey(String? key) {
    for (final type in values) {
      if (type.key == key) return type;
    }
    return AiProviderType.gemini;
  }
}

class AiModelOption {
  final String modelId;
  final String displayName;
  final String description;
  final AiProviderType provider;

  const AiModelOption({
    required this.modelId,
    required this.displayName,
    required this.description,
    required this.provider,
  });
}

class MultiAiService {
  static const List<AiModelOption> availableModels = [
    // Google Gemini
    AiModelOption(
      modelId: 'gemini-1.5-flash',
      displayName: 'Gemini 1.5 Flash (Recommended)',
      description: 'Fast, multimodal model optimized for quick reasoning and low latency.',
      provider: AiProviderType.gemini,
    ),
    AiModelOption(
      modelId: 'gemini-1.5-pro',
      displayName: 'Gemini 1.5 Pro',
      description: 'Advanced reasoning, complex problem solving, and large context.',
      provider: AiProviderType.gemini,
    ),
    AiModelOption(
      modelId: 'gemini-2.0-flash-exp',
      displayName: 'Gemini 2.0 Flash (Experimental)',
      description: 'Next-generation Gemini preview model.',
      provider: AiProviderType.gemini,
    ),

    // OpenAI (ChatGPT)
    AiModelOption(
      modelId: 'gpt-4o-mini',
      displayName: 'GPT-4o Mini (Fast & Efficient)',
      description: 'Affordable, intelligent small model for everyday conversational tasks.',
      provider: AiProviderType.openai,
    ),
    AiModelOption(
      modelId: 'gpt-4o',
      displayName: 'GPT-4o (Omni Reasoning)',
      description: 'Flagship model for high-intelligence multimodal tasks.',
      provider: AiProviderType.openai,
    ),
    AiModelOption(
      modelId: 'gpt-3.5-turbo',
      displayName: 'GPT-3.5 Turbo',
      description: 'Fast legacy ChatGPT completion model.',
      provider: AiProviderType.openai,
    ),

    // Anthropic Claude
    AiModelOption(
      modelId: 'claude-3-5-sonnet-20241022',
      displayName: 'Claude 3.5 Sonnet (State-of-the-Art)',
      description: 'Most intelligent Claude model for deep thinking, writing, and coding.',
      provider: AiProviderType.claude,
    ),
    AiModelOption(
      modelId: 'claude-3-haiku-20240307',
      displayName: 'Claude 3 Haiku (Lightweight)',
      description: 'Ultra-fast and cost-effective Claude for instant responses.',
      provider: AiProviderType.claude,
    ),
  ];

  static const String _activeProviderKey = 'ai_active_provider';
  static const String _modelKeyPrefix = 'ai_active_model_';
  static const String _apiKeyPrefix = 'ai_secure_key_';

  /// Get current active AI provider
  static Future<AiProviderType> getActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeProviderKey);
    return AiProviderType.fromKey(raw);
  }

  /// Set current active AI provider
  static Future<void> setActiveProvider(AiProviderType provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProviderKey, provider.key);
  }

  /// Get active model for a provider
  static Future<String> getActiveModelFor(AiProviderType provider) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('$_modelKeyPrefix${provider.key}');
    if (saved != null && saved.isNotEmpty) return saved;

    // Default per provider
    switch (provider) {
      case AiProviderType.gemini:
        return 'gemini-1.5-flash';
      case AiProviderType.openai:
        return 'gpt-4o-mini';
      case AiProviderType.claude:
        return 'claude-3-5-sonnet-20241022';
    }
  }

  /// Set active model for a provider
  static Future<void> setActiveModelFor(AiProviderType provider, String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_modelKeyPrefix${provider.key}', modelId);
  }

  /// Get encrypted API key for a provider
  static Future<String?> getApiKeyFor(AiProviderType provider) async {
    final key = await SecureStorageService.readSecure('$_apiKeyPrefix${provider.key}');
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    // Also check legacy gemini global key if provider is gemini
    if (provider == AiProviderType.gemini) {
      final legacy = await SecureStorageService.readSecure('gemini_api_key_global_default');
      if (legacy != null && legacy.trim().isNotEmpty) {
        return legacy.trim();
      }
    }
    return null;
  }

  /// Save encrypted API key for a provider
  static Future<void> saveApiKeyFor(AiProviderType provider, String apiKey) async {
    final clean = apiKey.trim();
    if (clean.isEmpty) {
      await SecureStorageService.deleteSecure('$_apiKeyPrefix${provider.key}');
      if (provider == AiProviderType.gemini) {
        await SecureStorageService.deleteSecure('gemini_api_key_global_default');
      }
    } else {
      await SecureStorageService.writeSecure('$_apiKeyPrefix${provider.key}', clean);
    }
  }

  /// Check if an API key exists for a provider
  static Future<bool> hasKeyFor(AiProviderType provider) async {
    final key = await getApiKeyFor(provider);
    return key != null && key.isNotEmpty;
  }

  /// Creates and returns the active LlmProvider, or null if no API key is provided
  static Future<LlmProvider?> createActiveLlmProvider() async {
    final provider = await getActiveProvider();
    final apiKey = await getApiKeyFor(provider);

    // If user has not configured their own API key, return null so chat prompts for key
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final modelId = await getActiveModelFor(provider);

    switch (provider) {
      case AiProviderType.gemini:
        return GeminiProvider(
          model: GenerativeModel(
            model: modelId,
            apiKey: apiKey,
          ),
        );
      case AiProviderType.openai:
        return OpenAiLlmProvider(
          apiKey: apiKey,
          modelId: modelId,
        );
      case AiProviderType.claude:
        return ClaudeLlmProvider(
          apiKey: apiKey,
          modelId: modelId,
        );
    }
  }
}

/// OpenAI / ChatGPT implementation of LlmProvider
class OpenAiLlmProvider extends LlmProvider with ChangeNotifier {
  final String apiKey;
  final String modelId;
  final List<ChatMessage> _history;

  OpenAiLlmProvider({
    required this.apiKey,
    required this.modelId,
    Iterable<ChatMessage>? history,
  }) : _history = List<ChatMessage>.from(history ?? []);

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    yield* _streamOpenAiResponse(prompt, history: const []);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    final stream = _streamOpenAiResponse(prompt, history: _history.sublist(0, _history.length - 2));
    yield* stream.map((chunk) {
      llmMessage.append(chunk);
      return chunk;
    });
  }

  Stream<String> _streamOpenAiResponse(String prompt, {required List<ChatMessage> history}) async* {
    final client = http.Client();
    try {
      final messages = <Map<String, String>>[];
      for (final msg in history) {
        if (msg.text != null && msg.text!.isNotEmpty) {
          messages.add({
            'role': msg.origin.isUser ? 'user' : 'assistant',
            'content': msg.text!,
          });
        }
      }
      messages.add({'role': 'user', 'content': prompt});

      final request = http.Request(
        'POST',
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      request.body = jsonEncode({
        'model': modelId,
        'stream': true,
        'messages': messages,
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        try {
          final errJson = jsonDecode(body);
          final msg = errJson['error']?['message'] ?? body;
          yield 'OpenAI Error ($msg)';
        } catch (_) {
          yield 'OpenAI Error (${response.statusCode}): $body';
        }
        return;
      }

      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ')) {
          final data = trimmed.substring(6).trim();
          if (data == '[DONE]') break;
          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'];
            if (delta != null && delta is String) {
              yield delta;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}

/// Anthropic Claude implementation of LlmProvider
class ClaudeLlmProvider extends LlmProvider with ChangeNotifier {
  final String apiKey;
  final String modelId;
  final List<ChatMessage> _history;

  ClaudeLlmProvider({
    required this.apiKey,
    required this.modelId,
    Iterable<ChatMessage>? history,
  }) : _history = List<ChatMessage>.from(history ?? []);

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    yield* _streamClaudeResponse(prompt, history: const []);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    final stream = _streamClaudeResponse(prompt, history: _history.sublist(0, _history.length - 2));
    yield* stream.map((chunk) {
      llmMessage.append(chunk);
      return chunk;
    });
  }

  Stream<String> _streamClaudeResponse(String prompt, {required List<ChatMessage> history}) async* {
    final client = http.Client();
    try {
      final messages = <Map<String, String>>[];
      for (final msg in history) {
        if (msg.text != null && msg.text!.isNotEmpty) {
          messages.add({
            'role': msg.origin.isUser ? 'user' : 'assistant',
            'content': msg.text!,
          });
        }
      }
      messages.add({'role': 'user', 'content': prompt});

      final request = http.Request(
        'POST',
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      });
      request.body = jsonEncode({
        'model': modelId,
        'max_tokens': 4096,
        'stream': true,
        'messages': messages,
      });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        try {
          final errJson = jsonDecode(body);
          final msg = errJson['error']?['message'] ?? body;
          yield 'Claude Error ($msg)';
        } catch (_) {
          yield 'Claude Error (${response.statusCode}): $body';
        }
        return;
      }

      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data: ')) {
          final data = trimmed.substring(6).trim();
          try {
            final json = jsonDecode(data);
            if (json['type'] == 'content_block_delta') {
              final text = json['delta']?['text'];
              if (text != null && text is String) {
                yield text;
              }
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}

