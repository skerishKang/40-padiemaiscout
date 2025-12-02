enum LLMProvider {
  gemini,
  openai,
  claude,
  gpt4,
  gpt35,
  clovaX,
  huggingface,
}

class LLMModel {
  final String id;
  final String name;
  final LLMProvider provider;
  final String description;
  final int maxTokens;
  final double costPerToken;
  final List<String> capabilities;
  final bool requiresApiKey;
  final String? apiKeyPlaceholder;

  const LLMModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.maxTokens,
    required this.costPerToken,
    required this.capabilities,
    this.requiresApiKey = true,
    this.apiKeyPlaceholder,
  });

  factory LLMModel.geminiPro() {
    return const LLMModel(
      id: 'gemini-1.5-pro',
      name: 'Gemini 1.5 Pro',
      provider: LLMProvider.gemini,
      description: 'Google의 최신 고성능 모델',
      maxTokens: 1000000,
      costPerToken: 0.0005,
      capabilities: ['text', 'code', 'analysis', 'multimodal'],
      requiresApiKey: true,
      apiKeyPlaceholder: 'GEMINI_API_KEY',
    );
  }

  factory LLMModel.geminiFlash() {
    return const LLMModel(
      id: 'gemini-1.5-flash',
      name: 'Gemini 1.5 Flash',
      provider: LLMProvider.gemini,
      description: '빠르고 효율적인 경량 모델',
      maxTokens: 1000000,
      costPerToken: 0.0001,
      capabilities: ['text', 'analysis', 'speed'],
      requiresApiKey: true,
      apiKeyPlaceholder: 'GEMINI_API_KEY',
    );
  }

  factory LLMModel.gpt4() {
    return const LLMModel(
      id: 'gpt-4',
      name: 'GPT-4',
      provider: LLMProvider.openai,
      description: 'OpenAI의 고성능 언어 모델',
      maxTokens: 8192,
      costPerToken: 0.03,
      capabilities: ['text', 'code', 'analysis', 'reasoning'],
      requiresApiKey: true,
      apiKeyPlaceholder: 'OPENAI_API_KEY',
    );
  }

  factory LLMModel.gpt35Turbo() {
    return const LLMModel(
      id: 'gpt-3.5-turbo',
      name: 'GPT-3.5 Turbo',
      provider: LLMProvider.openai,
      description: 'OpenAI의 빠르고 효율적인 모델',
      maxTokens: 4096,
      costPerToken: 0.002,
      capabilities: ['text', 'code', 'analysis'],
      requiresApiKey: true,
      apiKeyPlaceholder: 'OPENAI_API_KEY',
    );
  }

  factory LLMModel.claude3() {
    return const LLMModel(
      id: 'claude-3-sonnet',
      name: 'Claude 3 Sonnet',
      provider: LLMProvider.claude,
      description: 'Anthropic의 안전하고 강력한 모델',
      maxTokens: 100000,
      costPerToken: 0.003,
      capabilities: ['text', 'analysis', 'reasoning'],
      requiresApiKey: true,
      apiKeyPlaceholder: 'ANTHROPIC_API_KEY',
    );
  }

  factory LLMModel.clovaX() {
    return const LLMModel(
      id: 'clova-x',
      name: 'CLOVA X',
      provider: LLMProvider.clovaX,
      description: 'Naver의 한글 최적화 모델',
      maxTokens: 4096,
      costPerToken: 0.001,
      capabilities: ['text', 'korean', 'analysis'],
      requiresApiKey: true,
      apiKeyPlaceholder: 'CLOVA_API_KEY',
    );
  }

  static List<LLMModel> getAllModels() {
    return [
      LLMModel.geminiPro(),
      LLMModel.geminiFlash(),
      LLMModel.gpt4(),
      LLMModel.gpt35Turbo(),
      LLMModel.claude3(),
      LLMModel.clovaX(),
    ];
  }

  static List<LLMModel> getModelsByProvider(LLMProvider provider) {
    return getAllModels().where((model) => model.provider == provider).toList();
  }

  String get providerDisplayName {
    switch (provider) {
      case LLMProvider.gemini:
        return 'Google';
      case LLMProvider.openai:
        return 'OpenAI';
      case LLMProvider.claude:
        return 'Anthropic';
      case LLMProvider.clovaX:
        return 'Naver';
      case LLMProvider.gpt4:
      case LLMProvider.gpt35:
      case LLMProvider.huggingface:
        return provider.name.toUpperCase();
    }
  }

  String get costDisplay {
    if (costPerToken < 0.001) {
      return '\$${(costPerToken * 1000000).toInt()} per 1M tokens';
    } else {
      return '\$${costPerToken.toStringAsFixed(4)} per token';
    }
  }
}

class LLMConfig {
  final String modelId;
  final LLMProvider? provider;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final Map<String, dynamic> customParameters;

  const LLMConfig({
    required this.modelId,
    this.provider,
    required this.apiKey,
    this.temperature = 0.7,
    this.maxTokens = 1000,
    this.customParameters = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'modelId': modelId,
      'provider': provider?.name,
      'apiKey': apiKey,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'customParameters': customParameters,
    };
  }

  factory LLMConfig.fromMap(Map<String, dynamic> map) {
    LLMProvider? provider;
    if (map['provider'] != null) {
      try {
        provider = LLMProvider.values.firstWhere(
          (p) => p.name == map['provider'],
        );
      } catch (e) {
        provider = null;
      }
    }

    return LLMConfig(
      modelId: map['modelId'] ?? '',
      provider: provider,
      apiKey: map['apiKey'] ?? '',
      temperature: map['temperature']?.toDouble() ?? 0.7,
      maxTokens: map['maxTokens']?.toInt() ?? 1000,
      customParameters: Map<String, dynamic>.from(map['customParameters'] ?? {}),
    );
  }

  LLMConfig copyWith({
    String? modelId,
    LLMProvider? provider,
    String? apiKey,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? customParameters,
  }) {
    return LLMConfig(
      modelId: modelId ?? this.modelId,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      customParameters: customParameters ?? this.customParameters,
    );
  }
}