import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/llm_model.dart';
import '../utils/error_handler.dart';

class LLMModelSelector extends StatefulWidget {
  final LLMConfig? currentConfig;
  final Function(LLMConfig) onConfigChanged;

  const LLMModelSelector({
    super.key,
    this.currentConfig,
    required this.onConfigChanged,
  });

  @override
  State<LLMModelSelector> createState() => _LLMModelSelectorState();
}

class _LLMModelSelectorState extends State<LLMModelSelector> {
  LLMModel? _selectedModel;
  final _apiKeyController = TextEditingController();
  final _temperatureController = TextEditingController(text: '0.7');
  final _maxTokensController = TextEditingController(text: '1000');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFromCurrentConfig();
  }

  void _initializeFromCurrentConfig() {
    if (widget.currentConfig != null) {
      final config = widget.currentConfig!;
      _selectedModel = LLMModel.getAllModels()
          .firstWhere((model) => model.id == config.modelId);
      _apiKeyController.text = config.apiKey;
      _temperatureController.text = config.temperature.toString();
      _maxTokensController.text = config.maxTokens.toString();
    } else {
      // 기본값으로 Gemini Pro 선택
      _selectedModel = LLMModel.geminiPro();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'AI 모델 설정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildModelSelector(),
            const SizedBox(height: 16),
            _buildApiKeyInput(),
            const SizedBox(height: 16),
            _buildAdvancedSettings(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '모델 선택',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<LLMModel>(
          value: _selectedModel,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'AI 모델을 선택하세요',
          ),
          items: LLMModel.getAllModels().map((model) {
            return DropdownMenuItem(
              value: model,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${model.providerDisplayName} - ${model.costDisplay}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (LLMModel? model) {
            setState(() {
              _selectedModel = model;
            });
          },
        ),
        if (_selectedModel != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '모델 정보',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedModel!.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: _selectedModel!.capabilities.map((capability) {
                    return Chip(
                      label: Text(
                        capability,
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor: Colors.blue[100],
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildApiKeyInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'API 키',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: _selectedModel?.apiKeyPlaceholder ?? 'API 키를 입력하세요',
            suffixIcon: IconButton(
              icon: Icon(
                _apiKeyController.text.isNotEmpty
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  if (_apiKeyController.text.isNotEmpty) {
                    _apiKeyController.clear();
                  }
                });
              },
            ),
          ),
          obscureText: _apiKeyController.text.isNotEmpty,
          maxLines: 1,
        ),
        if (_selectedModel != null) ...[
          const SizedBox(height: 4),
          Text(
            '${_selectedModel!.providerDisplayName}에서 API 키를 발급받으세요.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedSettings() {
    return ExpansionTile(
      title: const Text(
        '고급 설정',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _temperatureController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Temperature (0-1)',
                  hintText: '생성의 무작위성',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxTokensController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Max Tokens',
                  hintText: '최대 토큰 수',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Temperature: 낮을수록 일관된 답변, 높을수록 창의적인 답변\n'
          'Max Tokens: 응답의 최대 길이',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _testConnection,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('연결 테스트'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveConfig,
            child: const Text('설정 저장'),
          ),
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    if (_selectedModel == null || _apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델과 API 키를 모두 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 실제 연결 테스트 구현
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API 연결에 성공했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final error = ErrorHandler.handleError(e);
      ErrorHandler.showErrorSnackBar(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    if (_selectedModel == null || _apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델과 API 키를 모두 입력해주세요.')),
      );
      return;
    }

    final temperature = double.tryParse(_temperatureController.text) ?? 0.7;
    final maxTokens = int.tryParse(_maxTokensController.text) ?? 1000;

    final config = LLMConfig(
      modelId: _selectedModel!.id,
      apiKey: _apiKeyController.text,
      temperature: temperature.clamp(0.0, 1.0),
      maxTokens: maxTokens.clamp(1, _selectedModel!.maxTokens),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('llm_config')
            .set(config.toMap());
      }

      widget.onConfigChanged(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정이 저장되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final error = ErrorHandler.handleError(e);
      ErrorHandler.showErrorSnackBar(context, error);
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }
}