/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { FieldValue: firebaseFieldValue } = require("firebase-admin/firestore");
// Gemini API SDK 추가
const { GoogleGenerativeAI } = require("@google/generative-ai");
// .env 파일 지원을 위한 dotenv 적용 (로컬 개발용)
require("dotenv").config();
// v2 import 추가
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

initializeApp();

const db = getFirestore();
const storage = getStorage();

setGlobalOptions({ region: "asia-northeast3" });

exports.helloWorld = (req, res) => {
  res.send("Hello from Firebase!");
};

// 기존 extractPdfText 함수 제거 후 v2 방식으로 재정의
exports.extractPdfText = onObjectFinalized({ cpu: 1 }, async (event) => {
  const fileBucket = event.data.bucket;
  const filePath = event.data.name;
  const contentType = event.data.contentType;

  if (!contentType || !contentType.startsWith("application/pdf")) {
    logger.log(`파일 [${filePath}]은 PDF가 아니므로 처리하지 않습니다.`);
    return null;
  }
  if (!filePath || !filePath.startsWith("uploads/")) {
    logger.log(`파일 [${filePath}]은 'uploads/' 경로가 아니므로 처리하지 않습니다.`);
    return null;
  }

  logger.info(
    `!!! Function Handler Entered !!! Event Object (v2 data):`,
    event.data,
  );
  logger.info(`PDF 분석 PoC 트리거: ${filePath}`);

  const bucket = storage.bucket(fileBucket);
  const tempFilePath = path.join(os.tmpdir(), path.basename(filePath));

  try {
    logger.info(`Attempting to download to temp path: ${tempFilePath}`);
    await bucket.file(filePath).download({ destination: tempFilePath });
    logger.info(`PDF 파일 다운로드 완료: ${tempFilePath}`);

    // --- Gemini 분석 호출 전 테스트용 3초 지연 ---
    logger.info("Starting 3-second delay for testing loading indicator...");
    await new Promise((resolve) => setTimeout(resolve, 3000)); // 3초 지연
    logger.info("Delay finished. Calling Gemini API...");

    // 2. Gemini API로 텍스트 추출 (기존 로직 재사용)
    let extractedTextRaw = null;
    let lastError = null;
    const GEMINI_API_KEYS = (
      process.env.GEMINI_API_KEYS ||
      process.env.GEMINI_API_KEY ||
      (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT.gemini && process.env.GCLOUD_PROJECT.gemini.key) ||
      ""
    )
      .toString()
      .split(",")
      .map((k) => k.trim())
      .filter(Boolean);
    let analysisResult = null;
    let processingStatus = "processing";
    for (const apiKey of GEMINI_API_KEYS) {
      try {
        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: GEMINI_MODEL_NAME });
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
                  text:
                    `너는 한국 정부의 지원사업 공고문을 분석하는 전문가야. 주어진 PDF 문서의 텍스트 내용을 바탕으로 다음 항목들을 정확하고 간결하게 추출해서 JSON 형식으로 정리해줘. 각 항목에 대한 정보가 문서에 명확히 언급되지 않았다면 "정보 없음" 또는 "해당 없음"으로 표시해줘.\n\n{
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
}\n\n중요: '신청기간_시작일'과 '신청기간_종료일' 항목은 반드시 'YYYY-MM-DD' 형식으로 추출해야 해. 만약 '2024년 7월 15일'이나 '24.07.15'와 같은 다른 형식으로 기재되어 있다면, 'YYYY-MM-DD' 형식으로 변환해서 입력해야 해. 해당 정보가 공고문에 명확히 없다면 값은 null로 설정해줘. 추출할 정보는 반드시 주어진 문서 내용에 근거해야 해. 추론하거나 외부 정보를 추가하지 마.`,
                },
              ],
            },
          ],
        });
        extractedTextRaw = result.response.text();
        // --- Gemini 응답 클리닝 및 JSON 파싱 ---
        let cleanedJsonString = extractedTextRaw.trim();
        const codeBlockMatch = cleanedJsonString.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
        if (codeBlockMatch) {
          cleanedJsonString = codeBlockMatch[1].trim();
        }
        try {
          analysisResult = JSON.parse(cleanedJsonString);
          logger.info("Gemini 응답 JSON 파싱 성공!");

          // --- 마감일 처리 로직 추가 ---
          let deadlineTimestamp = null;
          const deadlineString = analysisResult.신청기간_종료일;
          logger.info(`Attempting to parse deadline: "${deadlineString}" (Type: ${typeof deadlineString})`);
          if (deadlineString && typeof deadlineString === 'string') {
            const datePattern = /^\d{4}-\d{2}-\d{2}$/;
            if (datePattern.test(deadlineString)) {
              logger.info(`Deadline string passed format check.`);
              try {
                const dateParts = deadlineString.split('-');
                const parsedDate = new Date(Date.UTC(
                  parseInt(dateParts[0]),
                  parseInt(dateParts[1]) - 1,
                  parseInt(dateParts[2])
                ));
                if (!isNaN(parsedDate.getTime())) {
                  deadlineTimestamp = Timestamp.fromDate(parsedDate);
                  logger.info(`Deadline successfully parsed to Timestamp.`);
                } else {
                  logger.warn(`Invalid date parsed from deadline string: ${deadlineString}`);
                }
              } catch (e) {
                logger.error(`Error during Date/Timestamp conversion for "${deadlineString}":`, e);
              }
            } else {
              logger.warn(`Deadline string "${deadlineString}" FAILED format check (YYYY-MM-DD).`);
            }
          } else {
            logger.info("No valid deadline string found in analysisResult.");
          }
          // --- 마감일 처리 로직 끝 ---

          processingStatus = "analysis_success";
          // Firestore 업데이트 데이터 준비 (성공 시)
          analysisResult.deadlineTimestamp = deadlineTimestamp; // analysisResult에도 포함(선택)
          analysisResult.deadlineTimestampType = deadlineTimestamp ? 'Timestamp' : 'null'; // 디버깅용
          // updateData는 아래 try 블록에서 사용
        } catch (jsonErr) {
          logger.error(
            "Gemini 응답 JSON 파싱 실패",
            jsonErr,
            "원본 응답 미리보기:",
            extractedTextRaw.substring(0, 100),
          );
          processingStatus = "text_extracted_failed";
          analysisResult = null;
        }
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
    }

    // Firestore 쿼리 및 업데이트 (기존 로직 재사용)
    const storagePathValue = filePath;
    const uploadedFilesRef = db.collection("uploaded_files");
    logger.info(`Attempting to find document with storagePath: ${storagePathValue}`);

    let docRef;
    let docId;
    try {
      const querySnapshot = await uploadedFilesRef
        .where("storagePath", "==", storagePathValue)
        .limit(1)
        .get();

      if (querySnapshot.empty) {
        logger.error(
          `CRITICAL: No Firestore document found for storagePath: ` +
          `${storagePathValue}. Function cannot proceed.`,
        );
        return;
      }

      docRef = querySnapshot.docs[0].ref;
      docId = docRef.id;
      logger.info(
        `SUCCESS: Found Firestore document ID: ${docId} for storagePath: ` +
        `${storagePathValue}`,
      );
      // --- 분석 시작 시점에 상태 선반영 ---
      try {
        await docRef.update({
          analysisStatus: "processing",
          analyzedAt: FieldValue.serverTimestamp(),
          processingStartedAt: FieldValue.serverTimestamp(),
        });
        logger.info(
          `Status updated to 'processing' for document: ${docId}`
        );
      } catch (initUpdateError) {
        logger.error(
          `Failed to update status to 'processing' for document: ${docId}`,
          initUpdateError,
        );
      }
    } catch (queryError) {
      logger.error(
        `CRITICAL: Error querying Firestore for storagePath: ${storagePathValue}`,
        queryError,
      );
      return;
    }

    // Firestore 업데이트 (성공/실패 명확 분리)
    try {
      const updateData = {
        analysisStatus: processingStatus,
        analysisResult: analysisResult,
        extractedTextRaw: extractedTextRaw || "",
        analyzedAt: FieldValue.serverTimestamp(),
        processingEndedAt: FieldValue.serverTimestamp(),
        // --- 중요: 마감일 Timestamp 필드 추가 ---
        deadlineTimestamp: (analysisResult && analysisResult.deadlineTimestamp) ? analysisResult.deadlineTimestamp : null,
      };
      await docRef.update(updateData);
      logger.info(
        `SUCCESS: Firestore document update complete for ID: ${docId} with status: ${processingStatus}`
      );
    } catch (error) {
      logger.error(
        `ERROR: Failed processing/updating Firestore for ID: ${docId}`,
        error,
      );
      try {
        await docRef.update({
          analysisStatus: "text_extracted_failed",
          errorDetails:
            error.message || "Unknown error during extraction/update",
          analyzedAt: FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        logger.error(
          `ERROR: Failed to update Firestore error status for ID: ${docId}`,
          updateError,
        );
      }
    }
  } catch (e) {
    logger.error("!!!!!!!!!! UNCAUGHT EXCEPTION IN HANDLER !!!!!!!!!!", e);
  } finally {
    if (fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
      logger.info(`임시 파일 삭제 완료: ${tempFilePath}`);
    }
  }
  return null;
});

// --- Helper Function: 환경 변수에서 API 키 목록 가져오기 ---
function getApiKeysFromEnv() {
  try {
    // .env 우선, 없으면 functions.config() 사용
    const keysString = process.env.GEMINI_API_KEYS ||
      process.env.GEMINI_API_KEY ||
      (functions.config().gemini && (functions.config().gemini.keys || functions.config().gemini.key));
    if (!keysString) {
      console.error("환경 변수 'GEMINI_API_KEYS' 또는 'gemini.keys'가 설정되지 않았습니다.");
      return [];
    }
    return keysString.split(",").map((key) => key.trim()).filter((key) => key);
  } catch (e) {
    console.error("환경 변수에서 Gemini API 키 읽기 중 오류:", e);
    return [];
  }
}

// --- 실험용 API 키 유효성 검사 함수 (인증/권한 체크 주석처리) ---
exports.checkApiKeyStatus = functions.https.onCall(async (data, context) => {
  // // 운영 시 인증 필요
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', '인증 필요');
  // }

  const apiKeys = getApiKeysFromEnv();
  if (apiKeys.length === 0) {
    return { status: "error", message: "설정된 Gemini API 키가 없습니다." };
  }
  const testModelName = "gemini-1.5-flash-latest";
  for (const apiKey of apiKeys) {
    if (!apiKey) continue;
    const apiKeyShort = apiKey.substring(0, 5) + "...";
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: testModelName });
      await model.generateContent("ping");
      return { status: "valid", message: `API 키 [${apiKeyShort}]가 유효합니다.` };
    } catch (error) {
      if (error.message && (error.message.includes("quota") || error.message.includes("Quota"))) {
        // 할당량 초과는 다음 키로
        continue;
      }
      // 기타 오류는 다음 키로
    }
  }
  return { status: "invalid", message: "설정된 모든 API 키가 유효하지 않거나 할당량이 초과되었습니다." };
});

// Gemini 모델명은 GoogleGenerativeAI.listModels()로 확인 가능
// 예시: (Python)
// import google.generativeai as genai
// for model in genai.list_models():
//     print(model)
// Node.js SDK에는 listModels 직접 지원이 없으므로, 공식 문서 또는 REST API 참고
// 최신 모델명 예시: gemini-1.5-flash, gemini-1.5-pro, gemini-pro 등
const GEMINI_MODEL_NAME = "models/gemini-2.0-flash";

// --- 적합성 분석 Cloud Function ---
exports.checkSuitability = functions.https.onCall(async (data, context) => {
  // 입력: { userProfile, analysisResult }
  const userProfile = data.userProfile;
  const analysisResult = data.analysisResult;
  if (!userProfile || !analysisResult) {
    return { status: "error", message: "userProfile과 analysisResult가 모두 필요합니다." };
  }
  const apiKeys = getApiKeysFromEnv();
  if (apiKeys.length === 0) {
    return { status: "error", message: "설정된 Gemini API 키가 없습니다." };
  }
  let lastError = null;
  for (const apiKey of apiKeys) {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: GEMINI_MODEL_NAME });
      const prompt =
        "# 역할: 당신은 대한민국 정부 및 공공기관의 지원사업 공고와 신청 기업 정보를 비교하여, 해당 기업이 지원사업에 얼마나 적합한지를 객관적인 기준에 따라 평가하는 전문 심사관입니다.\n" +
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
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      let suitability = null;
      try {
        suitability = JSON.parse(text);
      } catch (e) {
        // 파싱 실패 시 원문 반환
        return { status: "ok", raw: text, parseError: true };
      }
      return { status: "ok", suitability };
    } catch (err) {
      lastError = err;
      if (!(err.message && err.message.toLowerCase().includes("quota"))) {
        break;
      }
    }
  }
  return { status: "error", message: "적합성 분석 실패", error: lastError && lastError.toString() };
});

// --- Chat with Gemini Cloud Function ---
exports.chatWithGemini = functions.https.onCall(async (data, context) => {
  const { prompt, fileData } = data;

  if (!prompt) {
    return { status: "error", message: "Prompt is required" };
  }

  const apiKeys = getApiKeysFromEnv();
  if (apiKeys.length === 0) {
    return { status: "error", message: "No Gemini API keys configured" };
  }

  let lastError = null;
  for (const apiKey of apiKeys) {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      // Use a model that supports vision if fileData is present, otherwise standard model
      // For simplicity, using the configured model name or defaulting to flash
      const modelName = GEMINI_MODEL_NAME || "gemini-1.5-flash";
      const model = genAI.getGenerativeModel({ model: modelName });

      const parts = [{ text: prompt }];
      if (fileData) {
        parts.push({
          inlineData: {
            mimeType: fileData.mimeType,
            data: fileData.data
          }
        });
      }

      const result = await model.generateContent(parts);
      const response = await result.response;
      const text = response.text();

      return { status: "success", text };
    } catch (err) {
      lastError = err;
      console.error(`Gemini API error with key ${apiKey.substring(0, 5)}...:`, err);
      if (!(err.message && err.message.toLowerCase().includes("quota"))) {
        // If not a quota error, maybe try next key anyway? 
        // For now, we treat non-quota errors as fatal for that key but try others just in case
        // or break if we want to fail fast. 
        // Let's continue to try other keys.
      }
    }
  }

  return {
    status: "error",
    message: "All API keys failed or exhausted",
    error: lastError ? lastError.toString() : "Unknown error"
  };
});
