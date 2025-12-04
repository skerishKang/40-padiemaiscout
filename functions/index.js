/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");
// const {getStorage} = require("firebase-admin/storage");
const {GoogleGenerativeAI} = require("@google/generative-ai");
require("dotenv").config();
const {setGlobalOptions} = require("firebase-functions/v2");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

initializeApp();

const db = getFirestore();
// const storage = getStorage();

setGlobalOptions({region: "asia-northeast3"});

exports.helloWorld = (req, res) => {
  res.send("Hello from Firebase!");
};

// --- Helper Function: 환경 변수에서 API 키 목록 가져오기 ---
function getApiKeysFromEnv() {
  try {
    const keysString = process.env.GEMINI_API_KEYS ||
      process.env.GEMINI_API_KEY ||
      (functions.config().gemini &&
        (functions.config().gemini.keys || functions.config().gemini.key));
    if (!keysString) {
      console.error(
        "환경 변수 'GEMINI_API_KEYS' 또는 'gemini.keys'가 설정되지 않았습니다.",
      );
      return [];
    }
    return keysString.split(",")
      .map((key) => key.trim())
      .filter((key) => key);
  } catch (e) {
    console.error("환경 변수에서 Gemini API 키 읽기 중 오류:", e);
    return [];
  }
}

// --- Helper Function: 허용된 Gemini 모델 목록 읽기 ---
function getAllowedModelsFromEnv() {
  try {
    const modelsString = process.env.GEMINI_ALLOWED_MODELS ||
      (functions.config().gemini && functions.config().gemini.models);

    const fallbackModels = [
      "gemini-2.5-flash-lite",
      "gemini-2.5-flash",
      "gemini-2.5-pro",
    ];

    if (!modelsString) {
      return fallbackModels;
    }

    const models = modelsString
      .split(",")
      .map((m) => m.trim())
      .filter((m) => m);

    return models.length > 0 ? models : fallbackModels;
  } catch (e) {
    console.error("환경 변수에서 Gemini 모델 목록 읽기 중 오류:", e);
    return ["gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-2.5-pro"];
  }
}

// Gemini 모델명은 GoogleGenerativeAI.listModels()로 확인 가능
const GEMINI_MODEL_NAME = "gemini-2.5-flash-lite";

// --- 실험용 API 키 유효성 검사 함수 ---
exports.checkApiKeyStatus = functions.https.onCall(async (data, context) => {
  const apiKeys = getApiKeysFromEnv();
  if (apiKeys.length === 0) {
    return {status: "error", message: "설정된 Gemini API 키가 없습니다."};
  }
  const testModelName = "gemini-2.5-flash-lite";
  for (const apiKey of apiKeys) {
    if (!apiKey) continue;
    const apiKeyShort = apiKey.substring(0, 5) + "...";
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: testModelName});
      await model.generateContent("ping");
      return {
        status: "valid",
        message: `API 키 [${apiKeyShort}]가 유효합니다.`,
      };
    } catch (error) {
      if (error.message &&
          (error.message.includes("quota") ||
           error.message.includes("Quota"))) {
        continue;
      }
    }
  }
  return {
    status: "invalid",
    message: "설정된 모든 API 키가 유효하지 않거나 할당량이 초과되었습니다.",
  };
});

// --- 적합성 분석 Cloud Function ---
exports.checkSuitability = functions.https.onCall(async (data, context) => {
  const userProfile = data.userProfile;
  const analysisResult = data.analysisResult;
  if (!userProfile || !analysisResult) {
    return {
      status: "error",
      message: "userProfile과 analysisResult가 모두 필요합니다.",
    };
  }
  const apiKeys = getApiKeysFromEnv();
  if (apiKeys.length === 0) {
    return {status: "error", message: "설정된 Gemini API 키가 없습니다."};
  }
  let lastError = null;
  for (const apiKey of apiKeys) {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: GEMINI_MODEL_NAME});
      const prompt = "# 역할: 당신은 대한민국 정부 및 공공기관의 지원사업 " +
        "공고와 신청 기업 정보를 비교하여, 해당 기업이 지원사업에 얼마나 " +
        "적합한지를 객관적인 기준에 따라 평가하는 전문 심사관입니다.\n" +
        "# 입력:\n[지원사업 공고 분석 결과 JSON]\n" +
        JSON.stringify(analysisResult, null, 2) + "\n" +
        "[회사 정보 JSON]\n" + JSON.stringify(userProfile, null, 2) + "\n" +
        "# 지시사항:\n주어진 두 JSON 정보를 바탕으로, 회사가 지원사업 공고의 " +
        "자격 요건, 지원 내용, 우대 조건, 제외 조건 등을 얼마나 충족하는지 " +
        "종합적으로 평가하십시오. 평가 결과는 0점에서 100점 사이의 정수 " +
        "점수(score)와 구체적인 평가 사유(reason)를 포함하는 JSON 객체 " +
        "형식으로 반환해야 합니다.\n# 평가 기준 및 점수 산정 가이드라인:\n" +
        "1. 필수 자격 요건 (가장 중요):\n   - [지원사업 공고 분석 결과]의 " +
        "'지원대상_요약', '신청자격_상세'(업력 조건은 회사의 establishmentDate와 " +
        "공고의 기준 비교), '주요 사업장 소재지 (시/도)' 등과 [회사 정보]의 " +
        "'businessType', 'establishmentDate', 'locationRegion' 등을 비교합니다.\n" +
        "   - 하나 이상의 필수 자격 요건을 명백하게 충족하지 못하면 점수는 " +
        "40점 이하로 제한되어야 하며, 사유에 명확히 명시해야 합니다. " +
        "(예: 업력 미달, 소재지 불일치 등)\n   - 모든 필수 자격 요건을 충족하면 " +
        "기본 점수 60점으로 시작합니다.\n2. 사업 내용 및 키워드 관련성:\n" +
        "   - [지원사업 공고 분석 결과]의 '사업명', '지원내용', " +
        "'사업분야_키워드' 등과 [회사 정보]의 'businessType', 'techKeywords' " +
        "등의 연관성을 평가합니다.\n   - 관련성이 높을수록 가점합니다 (최대 +20점).\n" +
        "3. 우대 조건 (해당 시):\n   - 공고 분석 결과에 명시적인 우대 조건이 있고, " +
        "회사 정보가 이를 충족한다면 가점합니다 (최대 +10점).\n" +
        "4. 규모 및 기타 조건:\n   - [지원사업 공고 분석 결과]의 '지원규모_금액', " +
        "'지원기간_협약기간' 등과 [회사 정보]의 'employeeCount' 등을 비교하여, " +
        "회사의 규모나 상황이 사업의 취지에 부합하는지 간접적으로 평가합니다. " +
        "(가/감점 ±10점 범위)\n5. 신청 제외 대상:\n   - [지원사업 공고 분석 결과]의 " +
        "'신청제외대상_요약'과 [회사 정보]를 비교하여, 회사가 명백한 제외 사유에 " +
        "해당한다면 점수를 0점으로 하고 사유에 명시해야 합니다.\n" +
        "# 결과 형식 (JSON):\n반드시 다음 JSON 형식으로 결과를 반환해야 합니다. " +
        "score는 정수, reason은 문자열입니다.\n{\n  \"score\": <0부터 100 사이의 " +
        "정수 점수>,\n  \"reason\": \"<점수 산정의 구체적인 근거. 어떤 조건이 " +
        "충족/미충족되었는지, 긍정/부정 요인은 무엇인지 명확하게 설명>\"\n}\n" +
        "주의사항:\n오직 제공된 JSON 정보만을 기반으로 평가해야 합니다. " +
        "외부 지식이나 추론을 사용하지 마십시오.\nreason은 평가 결과에 대한 " +
        "객관적이고 상세한 설명이어야 합니다. 단순히 점수만 나열하지 마십시오.\n" +
        "결과는 반드시 유효한 JSON 형식이어야 합니다.";
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
  return {
    status: "error",
    message: "적합성 분석 실패",
    error: lastError && lastError.toString(),
  };
});

// --- Chat with Gemini Cloud Function ---
exports.chatWithGemini = functions.https.onCall(async (request, context) => {
  const payload = request && typeof request === "object" && "data" in request ?
    request.data :
    request;

  const {prompt, fileData, model: preferredModel} = payload || {};
  let finalPrompt = prompt;

  if (typeof finalPrompt !== "string") {
    finalPrompt = finalPrompt ? String(finalPrompt) : "";
  }

  const hasTextPrompt = finalPrompt.trim().length > 0;
  const hasFileData = !!fileData;

  if (!hasTextPrompt && hasFileData) {
    finalPrompt = "첨부한 문서를 분석해서 핵심 내용과 우리 기업의 지원 " +
      "적합성을 요약해줘.";
  }

  const effectiveHasTextPrompt = finalPrompt.trim().length > 0;

  if (!effectiveHasTextPrompt && !hasFileData) {
    console.error("[chatWithGemini] Missing prompt and fileData in request", {
      rawRequestShape: request && typeof request === "object" ? {
        hasDataField: Object.prototype.hasOwnProperty.call(request, "data"),
        keys: Object.keys(request || {}),
      } : null,
      payload,
      typeofPrompt: typeof prompt,
      finalPromptType: typeof finalPrompt,
      finalPromptLength: finalPrompt ? finalPrompt.length : 0,
    });
    return {
      status: "success",
      text: "메시지가 비어 있습니다. 아래 입력창에 질문이나 공고문 관련 " +
        "내용을 적은 후 다시 전송해 주세요.",
      model: null,
    };
  }

  console.log("[chatWithGemini] Incoming request", {
    hasTextPrompt: effectiveHasTextPrompt,
    hasFileData,
    preferredModel,
    promptLength: finalPrompt.length,
    promptPreview: finalPrompt ? String(finalPrompt).slice(0, 50) : "",
  });

  const apiKeys = getApiKeysFromEnv();
  console.log("[chatWithGemini] apiKey count:", apiKeys.length);

  if (apiKeys.length === 0) {
    console.error(
      "[chatWithGemini] No Gemini API keys configured in environment",
    );
    return {status: "error", message: "No Gemini API keys configured"};
  }

  const allowedModels = getAllowedModelsFromEnv();
  console.log("[chatWithGemini] allowedModels:", allowedModels);

  const candidateModels = [];
  if (preferredModel && allowedModels.includes(preferredModel)) {
    candidateModels.push(preferredModel);
  }
  for (const m of allowedModels) {
    if (!candidateModels.includes(m)) {
      candidateModels.push(m);
    }
  }

  console.log("[chatWithGemini] candidateModels (order):", candidateModels);

  let lastError = null;
  for (const apiKey of apiKeys) {
    const genAI = new GoogleGenerativeAI(apiKey);
    const apiKeyShort = apiKey.substring(0, 5);

    for (const modelName of candidateModels) {
      try {
        console.log("[chatWithGemini] Trying model with key", {
          apiKey: apiKeyShort + "...",
          modelName,
        });

        const model = genAI.getGenerativeModel({model: modelName});

        const parts = [];
        if (finalPrompt && finalPrompt.trim().length > 0) {
          parts.push({text: finalPrompt});
        }
        if (fileData) {
          parts.push({
            inlineData: {
              mimeType: fileData.mimeType,
              data: fileData.data,
            },
          });
        }

        const req = {
          contents: [
            {
              role: "user",
              parts,
            },
          ],
        };

        const result = await model.generateContent(req);
        const response = await result.response;
        const text = response.text();

        console.log("[chatWithGemini] Success", {
          model: modelName,
          textPreview: text ? text.slice(0, 100) : "",
        });

        return {status: "success", text, model: modelName};
      } catch (err) {
        lastError = err;
        const msg = (err && err.message) ? err.message : String(err || "");
        console.error(
          `[chatWithGemini] Gemini API error with key ${apiKeyShort}..., ` +
          `model ${modelName}:`,
          msg,
        );

        const lower = msg.toLowerCase();
        const isQuotaOrPermissionIssue =
          lower.includes("quota") ||
          lower.includes("exceeded") ||
          lower.includes("permission") ||
          lower.includes("permission_denied") ||
          lower.includes("insufficient") ||
          lower.includes("not found") ||
          lower.includes("model");

        if (!isQuotaOrPermissionIssue) {
            console.error(
              "[chatWithGemini] Non-quota/permission/model error, " +
              "moving to next API key",
            );
          break;
        }
        console.log(
          "[chatWithGemini] Treating error as quota/permission/model issue, " +
          "trying next model",
        );
      }
    }
  }

  console.error("[chatWithGemini] All models and API keys failed", {
    lastError: lastError ? (lastError.message || String(lastError)) : null,
  });

  return {
    status: "error",
    message: (lastError && lastError.message) ?
      lastError.message : "All API keys failed or exhausted",
    error: lastError ? lastError.toString() : "Unknown error",
    debug: {
      preferredModel: preferredModel || null,
      candidateModels,
      apiKeyCount: apiKeys.length,
    },
  };
});

// --- Toss Payments Confirmation ---
const TOSS_SECRET_KEY = "REDACTED_TOSS_SECRET_KEY";
const axios = require("axios");

exports.confirmPayment = functions.https.onCall(async (request, context) => {
  if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
  }

  const data = request.data || request;
  const {paymentKey, orderId, amount} = data;
  const userId = context.auth.uid;

  try {
    const widgetSecretKey = TOSS_SECRET_KEY;
    const encryptedSecretKey = Buffer.from(
      widgetSecretKey + ":",
    ).toString("base64");

      const response = await axios.post(
        "https://api.tosspayments.com/v1/payments/confirm",
        {
          paymentKey,
          orderId,
          amount,
        },
        {
          headers: {
            "Authorization": `Basic ${encryptedSecretKey}`,
            "Content-Type": "application/json",
          },
        },
      );

    if (response.status === 200) {
      await db.collection("users").doc(userId).update({
        role: "pro",
        updatedAt: FieldValue.serverTimestamp(),
      });

      await db.collection("payments").add({
        userId,
        orderId,
        amount,
        paymentKey,
        status: "DONE",
        createdAt: FieldValue.serverTimestamp(),
        provider: "toss",
      });

      return {success: true, message: "Pro 등급으로 업그레이드되었습니다."};
    }
  } catch (error) {
      console.error(
        "Payment Confirmation Error:",
        error.response ? error.response.data : error,
      );

    if (error.response && error.response.data &&
        error.response.data.code === "ALREADY_PROCESSED_PAYMENT") {
      await db.collection("users").doc(userId).update({
        role: "pro",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {
        success: true,
        message: "이미 처리된 결제입니다. 등급이 갱신되었습니다.",
      };
    }

      throw new functions.https.HttpsError(
        "internal",
        "결제 승인 중 오류가 발생했습니다.",
      );
  }
});

// --- Bizinfo Scraping Agent ---
const cheerio = require("cheerio");

exports.scrapeBizinfo = functions.https.onCall(async (request, context) => {
  if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
  }

  try {
    const targetUrl = "https://www.bizinfo.go.kr/web/lay1/bbs/S1T122C128/A/74/list.do";

    const response = await axios.get(targetUrl);
    const html = response.data;
    const $ = cheerio.load(html);

    const scrapedItems = [];

    $(".table_list tbody tr").each((index, element) => {
      const title = $(element).find(".txt_l a").text().trim();
      const link = $(element).find(".txt_l a").attr("href");
      const department = $(element).find("td:nth-child(3)").text().trim();
      const date = $(element).find("td:nth-child(5)").text().trim();

      if (title && link) {
        scrapedItems.push({
          title,
          link: "https://www.bizinfo.go.kr" + link,
          department,
          date,
          scrapedAt: new Date().toISOString(),
        });
      }
    });

    const batch = db.batch();
    scrapedItems.forEach((item) => {
      const docRef = db.collection("grants").doc();
      batch.set(docRef, {
        ...item,
        source: "bizinfo",
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    return {
      success: true,
      message: `${scrapedItems.length}건의 공고를 스크래핑하여 저장했습니다.`,
      data: scrapedItems,
    };
  } catch (error) {
    console.error("Scraping Error:", error);
      throw new functions.https.HttpsError(
        "internal",
        "스크래핑 중 오류가 발생했습니다: " + error.message,
      );
  }
});
