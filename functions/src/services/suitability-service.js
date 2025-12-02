const {GoogleGenerativeAI} = require("@google/generative-ai");
const logger = require("firebase-functions/logger");

const GEMINI_MODEL_NAME = "models/gemini-2.0-flash";

class SuitabilityService {
  constructor() {
    this.apiKeys = this._getApiKeysFromEnv();
  }

  _getApiKeysFromEnv() {
    try {
      const keysString = process.env.GEMINI_API_KEYS ||
        process.env.GEMINI_API_KEY;
      if (!keysString) {
        return [];
      }
      return keysString.split(",").map((key) => key.trim()).filter((key) => key);
    } catch (e) {
      logger.error("환경 변수에서 Gemini API 키 읽기 중 오류:", e);
      return [];
    }
  }

  async checkSuitability(userProfile, analysisResult) {
    if (this.apiKeys.length === 0) {
      return {status: "error", message: "설정된 Gemini API 키가 없습니다."};
    }

    let lastError = null;
    for (const apiKey of this.apiKeys) {
      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({model: GEMINI_MODEL_NAME});
        const prompt = this._generateSuitabilityPrompt(userProfile, analysisResult);
        
        const result = await model.generateContent(prompt);
        const text = result.response.text();
        
        let suitability = null;
        try {
          suitability = JSON.parse(text);
        } catch (e) {
          return {status: "ok", raw: text, parseError: true};
        }
        
        return {status: "ok", suitability};
      } catch (err) {
        lastError = err;
        if (!(err.message && err.message.toLowerCase().includes("quota"))) {
          break;
        }
      }
    }
    return {status: "error", message: "적합성 분석 실패", error: lastError && lastError.toString()};
  }

  _generateSuitabilityPrompt(userProfile, analysisResult) {
    return "# 역할: 당신은 대한민국 정부 및 공공기관의 지원사업 공고와 신청 기업 정보를 비교하여, 해당 기업이 지원사업에 얼마나 적합한지를 객관적인 기준에 따라 평가하는 전문 심사관입니다.\n" +
      "# 입력:\n" +
      "[지원사업 공고 분석 결과 JSON]\n" +
      JSON.stringify(analysisResult, null, 2) + "\n" +
      "[회사 정보 JSON]\n" +
      JSON.stringify(userProfile, null, 2) + "\n" +
      "# 지시사항:\n" +
      "주어진 두 JSON 정보를 바탕으로, 회사가 지원사업 공고의 자격 요건, 지원 내용, 우대 조건, 제외 조건 등을 얼마나 충족하는지 종합적으로 평가하십시오. 평가 결과는 0점에서 100점 사이의 정수 점수(score)와 구체적인 평가 사유(reason)를 포함하는 JSON 객체 형식으로 반환해야 합니다.\n" +
      "# 평가 기준 및 점수 산정 가이드라인:\n" +
      "1. 필수 자격 요건 (가장 중요):\n" +
      "   - [지원사업 공고 분석 결과]의 '지원대상_요약', '신청자격_상세'(업력 조건은 회사의 establishmentDate와 공고의 기준 비교), '주요 사업장 소재지 (시/도)' 등과 [회사 정보]의 'businessType', 'establishmentDate', 'locationRegion' 등을 비교합니다.\n" +
      "   - 하나 이상의 필수 자격 요건을 명백하게 충족하지 못하면 점수는 40점 이하로 제한되어야 하며, 사유에 명확히 명시해야 합니다. (예: 업력 미달, 소재지 불일치 등)\n" +
      "   - 모든 필수 자격 요건을 충족하면 기본 점수 60점으로 시작합니다.\n" +
      "2. 사업 내용 및 키워드 관련성:\n" +
      "   - [지원사업 공고 분석 결과]의 '사업명', '지원내용', '사업분야_키워드' 등과 [회사 정보]의 'businessType', 'techKeywords' 등의 연관성을 평가합니다.\n" +
      "   - 관련성이 높을수록 가점합니다 (최대 +20점).\n" +
      "3. 우대 조건 (해당 시):\n" +
      "   - 공고 분석 결과에 명시적인 우대 조건이 있고, 회사 정보가 이를 충족한다면 가점합니다 (최대 +10점).\n" +
      "4. 규모 및 기타 조건:\n" +
      "   - [지원사업 공고 분석 결과]의 '지원규모_금액', '지원기간_협약기간' 등과 [회사 정보]의 'employeeCount' 등을 비교하여, 회사의 규모나 상황이 사업의 취지에 부합하는지 간접적으로 평가합니다. (가/감점 ±10점 범위)\n" +
      "5. 신청 제외 대상:\n" +
      "   - [지원사업 공고 분석 결과]의 '신청제외대상_요약'과 [회사 정보]를 비교하여, 회사가 명백한 제외 사유에 해당한다면 점수를 0점으로 하고 사유에 명시해야 합니다.\n" +
      "# 결과 형식 (JSON):\n" +
      "반드시 다음 JSON 형식으로 결과를 반환해야 합니다. score는 정수, reason은 문자열입니다.\n" +
      "{\n  \"score\": <0부터 100 사이의 정수 점수>,\n  \"reason\": \"<점수 산정의 구체적인 근거. 어떤 조건이 충족/미충족되었는지, 긍정/부정 요인은 무엇인지 명확하게 설명>\"\n}\n" +
      "주의사항:\n" +
      "오직 제공된 JSON 정보만을 기반으로 평가해야 합니다. 외부 지식이나 추론을 사용하지 마십시오.\n" +
      "reason은 평가 결과에 대한 객관적이고 상세한 설명이어야 합니다. 단순히 점수만 나열하지 마십시오.\n" +
      "결과는 반드시 유효한 JSON 형식이어야 합니다.";
  }
}

module.exports = SuitabilityService;