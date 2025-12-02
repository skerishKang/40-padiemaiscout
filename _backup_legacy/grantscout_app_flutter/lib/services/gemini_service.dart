import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_key_service.dart';

class GrantAnalysisResult {
  final String grantTitle;
  final String issuingAgency;
  final String deadline;
  final String fundingAmount;
  final List<String> eligibilityCriteria;
  final String summary;
  final int suitabilityScore;
  final String suitabilityReasoning;
  final List<String> keyRequirements;
  final String matchStatus;

  GrantAnalysisResult({
    required this.grantTitle,
    required this.issuingAgency,
    required this.deadline,
    required this.fundingAmount,
    required this.eligibilityCriteria,
    required this.summary,
    required this.suitabilityScore,
    required this.suitabilityReasoning,
    required this.keyRequirements,
    required this.matchStatus,
  });

  factory GrantAnalysisResult.fromJson(Map<String, dynamic> json) {
    return GrantAnalysisResult(
      grantTitle: json['grantTitle'] ?? '',
      issuingAgency: json['issuingAgency'] ?? '',
      deadline: json['deadline'] ?? '',
      fundingAmount: json['fundingAmount'] ?? '',
      eligibilityCriteria: List<String>.from(json['eligibilityCriteria'] ?? []),
      summary: json['summary'] ?? '',
      suitabilityScore: json['suitabilityScore'] ?? 50,
      suitabilityReasoning: json['suitabilityReasoning'] ?? '',
      keyRequirements: List<String>.from(json['keyRequirements'] ?? []),
      matchStatus: json['matchStatus'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grantTitle': grantTitle,
      'issuingAgency': issuingAgency,
      'deadline': deadline,
      'fundingAmount': fundingAmount,
      'eligibilityCriteria': eligibilityCriteria,
      'summary': summary,
      'suitabilityScore': suitabilityScore,
      'suitabilityReasoning': suitabilityReasoning,
      'keyRequirements': keyRequirements,
      'matchStatus': matchStatus,
    };
  }
}

class GeminiService {
  static const String _defaultModel = 'gemini-1.5-flash';

  static Future<String> _getApiKey() async {
    // 1. Try to get from ApiKeyService (Firestore)
    final apiKeys = await ApiKeyService.getAllApiKeys();
    if (apiKeys.containsKey('gemini')) {
      return apiKeys['gemini']!;
    }
    // 2. Fallback or error
    throw Exception('Gemini API Key not found. Please add it in Settings.');
  }

  static Future<String> _getModelName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('llm_config')
            .get();
        if (doc.exists && doc.data() != null) {
          return doc.data()!['modelId'] ?? _defaultModel;
        }
      }
    } catch (e) {
      // Ignore error and use default
    }
    return _defaultModel;
  }

  static Future<GrantAnalysisResult> analyzeGrantDocument({
    required Uint8List fileBytes,
    required String mimeType,
    required Map<String, dynamic> companyProfile,
    String language = 'ko',
  }) async {
    final apiKey = await _getApiKey();
    final modelName = await _getModelName();

    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.2,
      ),
    );

    final isProfileEmpty = companyProfile['companyName'] == null ||
        companyProfile['companyName'].toString().isEmpty;

    final profileContext = isProfileEmpty
        ? '''User has NOT provided a specific company profile yet. 
       - Evaluate the grant generally. 
       - Set 'suitabilityScore' to 50 (Neutral) unless the grant is obviously for everyone.
       - In 'suitabilityReasoning', explain generally what kind of companies this grant is best suited for, and explicitly state that the user should provide company details for a personalized score.'''
        : '''Company Profile:
       - Name: ${companyProfile['companyName']}
       - Industry: ${companyProfile['businessType']}
       - Employees: ${companyProfile['employeeCount']}
       - Location: ${companyProfile['locationRegion']}
       - Keywords: ${companyProfile['techKeywords']}
       
       Be critical about the 'suitabilityScore' (0-100). 
       - If the company is clearly ineligible (e.g., wrong industry, wrong location, revenue too high/low), give a low score (<50) and 'Low' status.
       - If it's a perfect fit, give >80 and 'High'.
       - Otherwise 'Medium'.''';

    final languageInstruction = language == 'ko'
        ? "OUTPUT MUST BE IN KOREAN (Hangul). Translate all extracted fields (summary, reasoning, criteria, etc.) into natural Korean."
        : "Output must be in English.";

    final systemInstruction = '''
    You are Padiem Grant AI, an expert AI grant analyst. 
    Your task is to analyze a grant announcement document (PDF or Image) and extract structured data.
    
    $profileContext

    $languageInstruction

    Analyze the document strictly. If the document is not a grant announcement, indicate this in the summary.
    
    Response Schema (JSON):
    {
      "grantTitle": "string",
      "issuingAgency": "string",
      "deadline": "string (YYYY-MM-DD or text)",
      "fundingAmount": "string",
      "eligibilityCriteria": ["string"],
      "summary": "string",
      "suitabilityScore": integer (0-100),
      "suitabilityReasoning": "string",
      "keyRequirements": ["string"],
      "matchStatus": "string (High/Medium/Low)"
    }
    ''';

    final content = [
      Content.multi([
        TextPart(systemInstruction),
        DataPart(mimeType, fileBytes),
        TextPart("Analyze this grant document based on the system instructions."),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      final text = response.text;
      if (text == null) throw Exception("No response from Gemini");

      // Clean up JSON if needed (sometimes models add markdown blocks)
      String jsonStr = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      return GrantAnalysisResult.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      print("Error analyzing grant: $e");
      rethrow;
    }
  }
}
