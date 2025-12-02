const {GoogleGenerativeAI} = require("@google/generative-ai");
const fs = require("fs");
const logger = require("firebase-functions/logger");

const GEMINI_MODEL_NAME = "models/gemini-2.0-flash";

class GeminiService {
  constructor() {
    this.apiKeys = this._getApiKeysFromEnv();
  }

  _getApiKeysFromEnv() {
    try {
      const keysString = process.env.GEMINI_API_KEYS ||
        process.env.GEMINI_API_KEY;
      if (!keysString) {
        logger.error("환경 변수 'GEMINI_API_KEYS'가 설정되지 않았습니다.");
        return [];
      }
      return keysString.split(",").map((key) => key.trim()).filter((key) => key);
    } catch (e) {
      logger.error("환경 변수에서 Gemini API 키 읽기 중 오류:", e);
      return [];
    }
  }

  async analyzePdfContent(tempFilePath) {
    let extractedTextRaw = null;
    let lastError = null;
    let analysisResult = null;

    for (const apiKey of this.apiKeys) {
      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({model: GEMINI_MODEL_NAME});
        const pdfBase64 = fs.readFileSync(tempFilePath).toString("base64");
        
        logger.info("PDF 파일 Base64 인코딩 완료, 길이: " + pdfBase64.length);
        
        const result = await model.generateContent({
          contents: [
            {
              role: "user",
              parts: [
                {
                  inlineData: {
                    mimeType: "application/pdf",
                    data: pdfBase64,
                  },
                },
                {
                  text: this._getAnalysisPrompt(),
                },
              ],
            },
          ],
        });

        extractedTextRaw = result.response.text();
        analysisResult = this._parseGeminiResponse(extractedTextRaw);
        
        logger.info(
            `Gemini API 텍스트 추출 성공 (API 키: ${apiKey.slice(0, 8)}...), 길이: ${extractedTextRaw.length}`,
        );
        break;
      } catch (err) {
        lastError = err;
        logger.error(`Gemini API 키(${apiKey.slice(0, 8)}...) 실패`, err);
        if (!(err.message && err.message.toLowerCase().includes("quota"))) {
          break;
        }
      }
    }

    if (!extractedTextRaw) {
      logger.error("모든 Gemini API 키에서 텍스트 추출 실패", lastError);
      return {
        success: false,
        error: lastError,
        extractedTextRaw: null,
        analysisResult: null,
      };
    }

    return {
      success: true,
      extractedTextRaw,
      analysisResult,
    };
  }

  _getAnalysisPrompt() {
    return `너는 한국 정부의 지원사업 공고문을 분석하는 전문가야. 주어진 PDF 문서의 텍스트 내용을 바탕으로 다음 항목들을 정확하고 간결하게 추출해서 JSON 형식으로 정리해줘. 각 항목에 대한 정보가 문서에 명확히 언급되지 않았다면 "정보 없음" 또는 "해당 없음"으로 표시해줘.

{
  "사업명": "[사업의 공식 명칭]",
  "주관기관": "[사업 주관/운영 기관명]",
  "지원대상_요약": "[지원 대상에 대한 간략한 설명]",
  "신청자격_상세": "[업력, 소재지, 대표자 요건 등 상세 자격 조건 목록 또는 설명]",
  "지원내용": "[제공되는 지원 종류 목록 또는 설명]",
  "지원규모_금액": "[기업당 지원 최대/평균 금액]",
  "신청기간_시작일": "YYYY-MM-DD 형식의 신청 시작일, 없으면 null",
  "신청기간_종료일": "YYYY-MM-DD 형식의 신청 마감일, 없으면 null",
  "신청방법": "[온라인 접수 URL 또는 이메일 주소 등]",
  "지원기간_협약기간": "[실제 지원 기간 또는 협약 기간]",
  "신청제외대상_요약": "[주요 신청 제외 조건 요약]",
  "사업분야_키워드": ["[사업 관련 핵심 키워드 목록]"]
}

중요: '신청기간_시작일'과 '신청기간_종료일' 항목은 반드시 'YYYY-MM-DD' 형식으로 추출해야 해. 만약 '2024년 7월 15일'이나 '24.07.15'와 같은 다른 형식으로 기재되어 있다면, 'YYYY-MM-DD' 형식으로 변환해서 입력해야 해. 해당 정보가 공고문에 명확히 없다면 값은 null로 설정해줘. 추출할 정보는 반드시 주어진 문서 내용에 근거해야 해. 추론하거나 외부 정보를 추가하지 마.`;
  }

  _parseGeminiResponse(extractedTextRaw) {
    let cleanedJsonString = extractedTextRaw.trim();
    const codeBlockMatch = cleanedJsonString.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (codeBlockMatch) {
      cleanedJsonString = codeBlockMatch[1].trim();
    }

    try {
      const analysisResult = JSON.parse(cleanedJsonString);
      logger.info("Gemini 응답 JSON 파싱 성공!");
      return analysisResult;
    } catch (jsonErr) {
      logger.error(
          "Gemini 응답 JSON 파싱 실패",
          jsonErr,
          "원본 응답 미리보기:",
          extractedTextRaw.substring(0, 100),
      );
      return null;
    }
  }

  async checkApiKeyStatus() {
    if (this.apiKeys.length === 0) {
      return {status: "error", message: "설정된 Gemini API 키가 없습니다."};
    }

    const testModelName = "gemini-1.5-flash-latest";
    for (const apiKey of this.apiKeys) {
      if (!apiKey) continue;
      const apiKeyShort = apiKey.substring(0, 5) + "...";
      
      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({model: testModelName});
        await model.generateContent("ping");
        return {status: "valid", message: `API 키 [${apiKeyShort}]가 유효합니다.`};
      } catch (error) {
        if (error.message && (error.message.includes("quota") || error.message.includes("Quota"))) {
          continue;
        }
      }
    }
    return {status: "invalid", message: "설정된 모든 API 키가 유효하지 않거나 할당량이 초과되었습니다."};
  }
}

module.exports = GeminiService;