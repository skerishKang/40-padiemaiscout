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
const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require("firebase-admin/firestore");
// const {getStorage} = require("firebase-admin/storage");
const { GoogleGenerativeAI } = require("@google/generative-ai");
require("dotenv").config();
const { setGlobalOptions } = require("firebase-functions/v2");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

initializeApp();

const db = getFirestore();
// const storage = getStorage();

setGlobalOptions({ region: "asia-northeast3" });

const ADMIN_EMAILS = [
  "padiemipu@gmail.com",
  "paidemipu@gmail.com",
  "limone@example.com",
  "admin@mdreader.com",
];

function getContextEmail(context) {
  if (!context || !context.auth || !context.auth.token) return null;
  const email = context.auth.token.email;
  return typeof email === "string" ? email : null;
}

function normalizeRole(value) {
  return typeof value === "string" ? value.toLowerCase() : "";
}

async function getUserRoleByUid(uid) {
  if (!uid) return "free";
  try {
    const snap = await db.collection("users").doc(uid).get();
    const data = snap.exists ? snap.data() : {};
    const role = normalizeRole(data && data.role);
    return role || "free";
  } catch (e) {
    return "free";
  }
}

async function isAdminContext(context) {
  if (!context || !context.auth) return false;
  const email = getContextEmail(context);
  if (email && ADMIN_EMAILS.includes(email)) return true;
  const role = await getUserRoleByUid(context.auth.uid);
  return role === "admin";
}

function requireAuth(context) {
  if (!context || !context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return context.auth.uid;
}

async function requireAdmin(context) {
  requireAuth(context);
  const ok = await isAdminContext(context);
  if (!ok) {
    throw new functions.https.HttpsError("permission-denied", "관리자 권한이 필요합니다.");
  }
}

function formatKstDateKey(date) {
  const kstMs = date.getTime() + (9 * 60 * 60 * 1000);
  const kstDate = new Date(kstMs);
  const y = kstDate.getUTCFullYear();
  const m = String(kstDate.getUTCMonth() + 1).padStart(2, "0");
  const d = String(kstDate.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

async function enforceDailyRateLimit(uid, action, limitPerDay) {
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  const safeAction = typeof action === "string" && action ? action : "unknown";
  const limit = typeof limitPerDay === "number" && limitPerDay > 0 ? limitPerDay : 10;

  const todayKey = formatKstDateKey(new Date());
  const docId = `${uid}_${safeAction}_${todayKey}`;
  const ref = db.collection("rate_limits").doc(docId);

  let newCount = null;
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const current = snap.exists ? snap.data() : {};
      const count = typeof current.count === "number" ? current.count : 0;

      if (count >= limit) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          `일일 사용 횟수를 초과했습니다. (하루 ${limit}회)`,
        );
      }

      newCount = count + 1;
      tx.set(ref, {
        uid,
        action: safeAction,
        dateKey: todayKey,
        count: newCount,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });
  } catch (e) {
    if (e instanceof functions.https.HttpsError) throw e;
    throw new functions.https.HttpsError(
      "internal",
      "사용량 제한 처리 중 오류가 발생했습니다.",
    );
  }

  return { dateKey: todayKey, count: newCount, limit };
}

// --- Admin Sync Log Helper (운영용 장기 로그) ---
async function logAdminSync(type, status, message, meta, context) {
  try {
    const logData = {
      type,
      status,
      message: message || "",
      meta: meta || null,
      triggeredAt: FieldValue.serverTimestamp(),
    };

    if (context && context.auth) {
      logData.triggerUid = context.auth.uid || null;
      if (context.auth.token && context.auth.token.email) {
        logData.triggerEmail = context.auth.token.email;
      }
    }

    await db.collection("admin_sync_logs").add(logData);
  } catch (e) {
    console.error("[logAdminSync] Failed to write admin_sync_logs: ", e);
  }
}

// 기본 예제용 HTTP 함수는 v2 런타임에서도 인식 가능한 onRequest 래퍼를 사용하도록 수정
exports.helloWorld = functions.https.onRequest((req, res) => {
  res.send("Hello from Firebase!");
});

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

function parseJsonSafe(value) {
  try {
    return JSON.parse(value);
  } catch (e) {
    return null;
  }
}

function extractJsonFromText(text) {
  if (!text || typeof text !== "string") return null;

  const direct = parseJsonSafe(text);
  if (direct) return direct;

  const fenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fenceMatch && fenceMatch[1]) {
    const fenced = parseJsonSafe(fenceMatch[1]);
    if (fenced) return fenced;
  }

  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");
  if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
    const sliced = text.slice(firstBrace, lastBrace + 1);
    const slicedParsed = parseJsonSafe(sliced);
    if (slicedParsed) return slicedParsed;
  }

  return null;
}

function normalizeSuitabilityPayload(payload) {
  if (!payload || typeof payload !== "object") return null;
  const rawScore = payload.score;
  const score = typeof rawScore === "number"
    ? rawScore
    : typeof rawScore === "string"
      ? Number(rawScore)
      : Number.NaN;

  if (Number.isNaN(score)) return null;

  return {
    score: Math.max(0, Math.min(100, Math.round(score))),
    reason: typeof payload.reason === "string" ? payload.reason : "",
  };
}

// Gemini 모델명은 GoogleGenerativeAI.listModels()로 확인 가능
const GEMINI_MODEL_NAME = "gemini-2.5-flash-lite";

// --- 실험용 API 키 유효성 검사 함수 ---
exports.checkApiKeyStatus = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);

  const apiKeys = getApiKeysFromEnv();
  if (apiKeys.length === 0) {
    return { status: "error", message: "설정된 Gemini API 키가 없습니다." };
  }
  const testModelName = "gemini-2.5-flash-lite";
  for (const apiKey of apiKeys) {
    if (!apiKey) continue;
    const apiKeyShort = apiKey.substring(0, 5) + "...";
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: testModelName });
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
  const uid = requireAuth(context);
  await enforceDailyRateLimit(uid, "checkSuitability", 10);

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
    return { status: "error", message: "설정된 Gemini API 키가 없습니다." };
  }
  let lastError = null;
  for (const apiKey of apiKeys) {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: GEMINI_MODEL_NAME });
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
      const parsed = extractJsonFromText(text);
      const suitability = normalizeSuitabilityPayload(parsed);
      if (!suitability) {
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
  return {
    status: "error",
    message: "적합성 분석 실패",
    error: lastError && lastError.toString(),
  };
});

// --- Chat with Gemini Cloud Function ---
exports.chatWithGemini = functions.https.onCall(async (request, context) => {
  const uid = requireAuth(context);
  await enforceDailyRateLimit(uid, "chatWithGemini", 10);

  const payload = request && typeof request === "object" && "data" in request ?
    request.data :
    request;

  const { prompt, fileData, model: preferredModel } = payload || {};
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
    return { status: "error", message: "No Gemini API keys configured" };
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

        const model = genAI.getGenerativeModel({ model: modelName });

        const parts = [];
        if (finalPrompt && finalPrompt.trim().length > 0) {
          parts.push({ text: finalPrompt });
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

        return { status: "success", text, model: modelName };
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
const TOSS_SECRET_KEY = process.env.TOSS_SECRET_KEY ||
  (functions.config().toss && functions.config().toss.secret_key);
const axios = require("axios");

exports.confirmPayment = functions.https.onCall(async (request, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "로그인이 필요합니다.",
    );
  }

  const data = request.data || request;
  const { paymentKey, orderId, amount } = data;
  const userId = context.auth.uid;

  const widgetSecretKey = TOSS_SECRET_KEY;
  if (!widgetSecretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "TOSS_SECRET_KEY가 설정되지 않았습니다.",
    );
  }

  try {
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
      const currentRole = await getUserRoleByUid(userId);
      if (currentRole === "premium" || currentRole === "admin") {
        await db.collection("users").doc(userId).set({
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        await db.collection("users").doc(userId).set({
          role: "pro",
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await db.collection("payments").add({
        userId,
        orderId,
        amount,
        paymentKey,
        status: "DONE",
        createdAt: FieldValue.serverTimestamp(),
        provider: "toss",
      });

      return { success: true, message: "Pro 등급으로 업그레이드되었습니다." };
    }
  } catch (error) {
    console.error(
      "Payment Confirmation Error:",
      error.response ? error.response.data : error,
    );

    if (error.response && error.response.data &&
      error.response.data.code === "ALREADY_PROCESSED_PAYMENT") {
      const currentRole = await getUserRoleByUid(userId);
      if (currentRole === "premium" || currentRole === "admin") {
        await db.collection("users").doc(userId).set({
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        await db.collection("users").doc(userId).set({
          role: "pro",
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
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
const crypto = require("crypto");

const bizinfoSchedulerDocRef = db.collection("system_settings").doc("bizinfoScheduler");
const DEFAULT_BIZINFO_SCHEDULER_CONFIG = {
  enabled: false,
  mode: "interval",
  dailyTimes: ["09:00"],
  intervalMinutes: 60,
};

function normalizeIsoDateString(value) {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim();
  const match = trimmed.match(/(\d{4})[-.](\d{2})[-.](\d{2})/);
  if (!match) return null;
  return `${match[1]}-${match[2]}-${match[3]}`;
}

function parseIsoDateToUtcStart(isoDate) {
  const normalized = normalizeIsoDateString(isoDate);
  if (!normalized) return null;
  const parts = normalized.split("-");
  if (parts.length !== 3) return null;
  const d = new Date(Date.UTC(
    parseInt(parts[0], 10),
    parseInt(parts[1], 10) - 1,
    parseInt(parts[2], 10),
  ));
  return isNaN(d.getTime()) ? null : d;
}

function clampRangeDays(value) {
  const n = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(n)) return 7;
  const v = Math.round(n);
  if (v < 1) return 1;
  if (v > 7) return 7;
  return v;
}

function addDaysUtc(date, days) {
  return new Date(date.getTime() + days * 24 * 60 * 60 * 1000);
}

function parseDailyTimeToMinutes(value) {
  if (!value || typeof value !== "string") return null;
  const trimmed = value.trim();
  const match = trimmed.match(/^(\d{2}):(\d{2})$/);
  if (!match) return null;
  const hh = parseInt(match[1], 10);
  const mm = parseInt(match[2], 10);
  if (!Number.isFinite(hh) || !Number.isFinite(mm)) return null;
  if (hh < 0 || hh > 23) return null;
  if (mm < 0 || mm > 59) return null;
  if (mm % 15 !== 0) return null;
  return hh * 60 + mm;
}

function normalizeDailyTimes(values) {
  const list = Array.isArray(values) ? values : [];
  const cleaned = list
    .map((t) => (typeof t === "string" ? t.trim() : ""))
    .filter((t) => !!parseDailyTimeToMinutes(t));
  const unique = Array.from(new Set(cleaned)).sort();
  return unique.slice(0, 4);
}

function getSeoulNowParts(date) {
  const base = date instanceof Date ? date : new Date();
  const d = new Date(base.getTime() + 9 * 60 * 60 * 1000);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  const hour = d.getUTCHours();
  const minute = d.getUTCMinutes();
  return {
    ymd: `${year}-${month}-${day}`,
    hour,
    minute,
    totalMinutes: hour * 60 + minute,
  };
}

function buildGrantDocId(source, link) {
  const base = `${String(source || "")}::${String(link || "")}`;
  const hash = crypto.createHash("sha256").update(base).digest("hex");
  return `${source}_${hash.slice(0, 24)}`;
}

async function getBizinfoSchedulerConfigInternal() {
  const snap = await bizinfoSchedulerDocRef.get();
  const data = snap.exists ? snap.data() : {};
  const config = Object.assign({}, DEFAULT_BIZINFO_SCHEDULER_CONFIG, data || {});
  if (config.mode !== "daily" && config.mode !== "interval") {
    config.mode = DEFAULT_BIZINFO_SCHEDULER_CONFIG.mode;
  }
  config.dailyTimes = normalizeDailyTimes(config.dailyTimes);
  if (config.mode === "daily" && config.dailyTimes.length === 0) {
    config.dailyTimes = DEFAULT_BIZINFO_SCHEDULER_CONFIG.dailyTimes.slice();
  }
  if (!config.intervalMinutes || typeof config.intervalMinutes !== "number" || config.intervalMinutes <= 0) {
    config.intervalMinutes = DEFAULT_BIZINFO_SCHEDULER_CONFIG.intervalMinutes;
  }
  return config;
}

async function applyBizinfoSchedulerConfigUpdate(updates) {
  const safeUpdates = {};
  if (typeof updates.enabled === "boolean") {
    safeUpdates.enabled = updates.enabled;
  }
  if (typeof updates.mode === "string") {
    safeUpdates.mode = updates.mode === "daily" ? "daily" : "interval";
  }
  if (Array.isArray(updates.dailyTimes)) {
    safeUpdates.dailyTimes = normalizeDailyTimes(updates.dailyTimes);
  }
  if (typeof updates.intervalMinutes === "number" && updates.intervalMinutes > 0) {
    const min = 15;
    const max = 24 * 60;
    let v = Math.round(updates.intervalMinutes);
    if (v < min) {
      v = min;
    }
    if (v > max) {
      v = max;
    }
    safeUpdates.intervalMinutes = v;
  }
  if (Object.keys(safeUpdates).length === 0) {
    return getBizinfoSchedulerConfigInternal();
  }
  await bizinfoSchedulerDocRef.set(safeUpdates, { merge: true });
  return getBizinfoSchedulerConfigInternal();
}

// --- Bizinfo Scraping Logic (Shared) ---
async function performBizinfoScraping(options) {
  // 실제 지원사업 공고 목록 페이지 (검색/필터 포함 메인 리스트)
  const targetUrl = "https://www.bizinfo.go.kr/web/lay1/bbs/S1T122C128/AS/74/list.do";

  const sinceDate = options && typeof options.sinceDate === "string" ? options.sinceDate : null;
  const sinceUtc = sinceDate ? parseIsoDateToUtcStart(sinceDate) : null;
  const rangeDays = options && typeof options.rangeDays !== "undefined" ? clampRangeDays(options.rangeDays) : 7;
  const endUtcExclusive = sinceUtc ? addDaysUtc(sinceUtc, rangeDays) : null;

  const maxPages = 20;
  const rows = 15;

  try {
    const scrapedItems = [];
    for (let page = 1; page <= maxPages; page += 1) {
      const pageUrl = page === 1 ? targetUrl : `${targetUrl}?rows=${rows}&cpage=${page}`;
      const response = await axios.get(pageUrl);
      const html = response.data;
      const $ = cheerio.load(html);
      const pageItems = [];
      let minRowDate = null;

      $("div.table_Type_1 table tbody tr").each((index, element) => {
        const tds = $(element).find("td");
        if (tds.length < 8) {
          return;
        }

        const rawTitle = $(tds[2]).text().trim();
        const titleLink = $(tds[2]).find("a").attr("href") || "";
        const periodText = $(tds[3]).text().replace(/\s+/g, " ").trim();
        const department = $(tds[4]).text().trim();
        const date = $(tds[6]).text().trim();

        const normalizedDate = normalizeIsoDateString(date);
        const rowDate = normalizedDate ? parseIsoDateToUtcStart(normalizedDate) : null;
        if (rowDate) {
          if (!minRowDate || rowDate.getTime() < minRowDate.getTime()) {
            minRowDate = rowDate;
          }
        }
        if (sinceUtc) {
          if (!rowDate) {
            return;
          }
          if (rowDate.getTime() < sinceUtc.getTime()) {
            return;
          }
          if (endUtcExclusive && rowDate.getTime() >= endUtcExclusive.getTime()) {
            return;
          }
        }

        const title = rawTitle.replace(/\s+/g, " ");
        if (!title) {
          return;
        }

        let link = "";
        if (titleLink) {
          if (titleLink.startsWith("http")) {
            link = titleLink;
          } else if (titleLink.startsWith("/")) {
            link = "https://www.bizinfo.go.kr" + titleLink;
          } else {
            link = "https://www.bizinfo.go.kr/web/lay1/bbs/S1T122C128/AS/74/" + titleLink;
          }
        }
        if (!link) {
          return;
        }

        let deadlineTimestamp = null;
        if (periodText) {
          const match = periodText.match(/(\d{4}-\d{2}-\d{2})\s*$/);
          if (match) {
            const endDateStr = match[1];
            const parts = endDateStr.split("-");
            const parsedDate = new Date(Date.UTC(
              parseInt(parts[0], 10),
              parseInt(parts[1], 10) - 1,
              parseInt(parts[2], 10),
            ));
            if (!isNaN(parsedDate.getTime())) {
              deadlineTimestamp = Timestamp.fromDate(parsedDate);
            }
          }
        }

        const item = {
          title,
          link,
          department,
          date,
          period: periodText,
          contentHash: crypto
            .createHash("sha256")
            .update(JSON.stringify({
              title,
              department: department || null,
              date: date || null,
              period: periodText || null,
              deadline: deadlineTimestamp ? deadlineTimestamp.toMillis() : null,
            }))
            .digest("hex"),
          scrapedAt: new Date().toISOString(),
        };
        if (deadlineTimestamp) {
          item.deadlineTimestamp = deadlineTimestamp;
        }

        pageItems.push(item);
      });

      if (pageItems.length === 0) {
        break;
      }
      scrapedItems.push(...pageItems);

      if (sinceUtc && minRowDate && minRowDate.getTime() < sinceUtc.getTime()) {
        break;
      }
    }

    if (scrapedItems.length === 0) {
      console.log("No items scraped.");
      return { success: false, message: "스크래핑된 공고가 없습니다.", count: 0 };
    }

    const docRefs = scrapedItems.map((item) => {
      return db.collection("grants").doc(buildGrantDocId("bizinfo", item.link));
    });
    const snaps = docRefs.length > 0 ? await db.getAll(...docRefs) : [];

    let newCount = 0;
    let updatedCount = 0;
    let skippedCount = 0;

    const batch = db.batch();
    let writeOps = 0;
    snaps.forEach((snap, idx) => {
      const item = scrapedItems[idx];
      const docRef = docRefs[idx];
      const existingHash = snap.exists ? ((snap.data() || {}).contentHash || null) : null;
      const nextHash = item && item.contentHash ? item.contentHash : null;

      if (snap.exists && existingHash && nextHash && existingHash === nextHash) {
        skippedCount += 1;
        return;
      }

      const payload = {
        ...item,
        source: "bizinfo",
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        payload.createdAt = FieldValue.serverTimestamp();
        newCount += 1;
      } else {
        updatedCount += 1;
      }
      batch.set(docRef, payload, { merge: true });
      writeOps += 1;
    });
    if (writeOps > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: `${scrapedItems.length}건 스크래핑(신규 ${newCount} / 업데이트 ${updatedCount} / 스킵 ${skippedCount})`,
      data: scrapedItems,
      count: scrapedItems.length,
      savedCount: newCount + updatedCount,
      newCount,
      updatedCount,
      skippedCount,
    };
  } catch (error) {
    console.error("Scraping Logic Error:", error);
    throw error;
  }
}

// --- K-Startup Scraping Logic (Ongoing Biz Notices) ---
async function performKStartupScraping(options) {
  const targetUrl = "https://www.k-startup.go.kr/web/contents/bizpbanc-ongoing.do";

  const sinceDate = options && typeof options.sinceDate === "string" ? options.sinceDate : null;
  const sinceUtc = sinceDate ? parseIsoDateToUtcStart(sinceDate) : null;
  const rangeDays = options && typeof options.rangeDays !== "undefined" ? clampRangeDays(options.rangeDays) : 7;
  const endUtcExclusive = sinceUtc ? addDaysUtc(sinceUtc, rangeDays) : null;

  const maxPages = 20;

  try {
    const scrapedItems = [];
    for (let page = 1; page <= maxPages; page += 1) {
      const pageUrl = page === 1 ? targetUrl : `${targetUrl}?page=${page}&pbancClssCd=PBC010`;
      const response = await axios.get(pageUrl);
      const html = response.data;
      const $ = cheerio.load(html);
      const pageItems = [];
      let minRowDate = null;

      if (page > 1) {
        const activePageRaw = $(".paginate a.active").first().text().trim();
        const activePage = Number(activePageRaw);
        if (Number.isFinite(activePage) && activePage !== page) {
          break;
        }
      }

      $("li.notice:contains('마감일자')").each((index, element) => {
        const $el = $(element);
        const text = $el.text().replace(/\s+/g, " ").trim();
        if (!text || !text.includes("마감일자")) {
          return;
        }

        const titleElement = $el.find("a, strong, h4").first();
        const rawTitle = titleElement.text().trim() || text;
        const title = rawTitle.replace(/\s+/g, " ");
        if (!title) {
          return;
        }

        let href = titleElement.attr("href") || "";
        let link = "";
        if (href) {
          if (href.startsWith("javascript:")) {
            const idMatch = href.match(/go_view\((\d+)\)/);
            const id = idMatch ? idMatch[1] : null;
            link = id ? `${targetUrl}#${id}` : `${targetUrl}#${crypto.createHash("sha256").update(text).digest("hex").slice(0, 12)}`;
          } else if (href.startsWith("http")) {
            link = href;
          } else if (href.startsWith("/")) {
            link = "https://www.k-startup.go.kr" + href;
          } else {
            link = "https://www.k-startup.go.kr" + (href.startsWith("?") ? href : "/" + href);
          }
        }
        if (!link) {
          return;
        }

        // 마감일자 추출
        const deadlineMatch = text.match(/마감일자\s+(\d{4}-\d{2}-\d{2})/);
        let deadlineTimestamp = null;
        let periodText = null;
        if (deadlineMatch) {
          periodText = deadlineMatch[1];
          const parts = periodText.split("-");
          if (parts.length === 3) {
            const parsedDate = new Date(Date.UTC(
              parseInt(parts[0], 10),
              parseInt(parts[1], 10) - 1,
              parseInt(parts[2], 10),
            ));
            if (!isNaN(parsedDate.getTime())) {
              deadlineTimestamp = Timestamp.fromDate(parsedDate);
            }
          }
        }

        // 기관명 추출
        let department = null;
        // 1차: 기존 패턴 (일부 공고에서 사용)
        const deptMatch = text.match(/마감일자\s+\d{4}-\d{2}-\d{2}\s+(.+?)\s+조회/);
        if (deptMatch) {
          department = deptMatch[1].trim();
        }
        // 2차: "창업보육센터 지원사업 호서대학교산학협력단 등록일자 ..." 형태 처리
        if (!department) {
          const deptMatch2 = text.match(/지원사업\s+(.+?)\s+등록일자/);
          if (deptMatch2) {
            department = deptMatch2[1].trim();
          }
        }

        const postedDateMatch = text.match(/등록일자\s+(\d{4}-\d{2}-\d{2})/);
        const postedDate = postedDateMatch ? postedDateMatch[1] : null;
        const rowDate = postedDate ? parseIsoDateToUtcStart(postedDate) : null;
        if (rowDate) {
          if (!minRowDate || rowDate.getTime() < minRowDate.getTime()) {
            minRowDate = rowDate;
          }
        }
        if (sinceUtc) {
          if (!rowDate) {
            return;
          }
          if (rowDate.getTime() < sinceUtc.getTime()) {
            return;
          }
          if (endUtcExclusive && rowDate.getTime() >= endUtcExclusive.getTime()) {
            return;
          }
        }

        const item = {
          title,
          link,
          department: department || null,
          period: periodText,
          date: postedDate,
          contentHash: crypto
            .createHash("sha256")
            .update(JSON.stringify({
              title,
              department: department || null,
              date: postedDate || null,
              period: periodText || null,
              deadline: deadlineTimestamp ? deadlineTimestamp.toMillis() : null,
            }))
            .digest("hex"),
          scrapedAt: new Date().toISOString(),
        };
        if (deadlineTimestamp) {
          item.deadlineTimestamp = deadlineTimestamp;
        }

        pageItems.push(item);
      });

      if (pageItems.length === 0) {
        break;
      }
      scrapedItems.push(...pageItems);

      if (sinceUtc && minRowDate && minRowDate.getTime() < sinceUtc.getTime()) {
        break;
      }
    }

    if (scrapedItems.length === 0) {
      console.log("No K-Startup items scraped.");
      return {
        success: false,
        message: "K-Startup에서 스크래핑된 공고가 없습니다.",
        count: 0,
      };
    }

    const docRefs = scrapedItems.map((item) => {
      return db.collection("grants").doc(buildGrantDocId("k-startup", item.link));
    });
    const snaps = docRefs.length > 0 ? await db.getAll(...docRefs) : [];

    let newCount = 0;
    let updatedCount = 0;
    let skippedCount = 0;

    const batch = db.batch();
    let writeOps = 0;
    snaps.forEach((snap, idx) => {
      const item = scrapedItems[idx];
      const docRef = docRefs[idx];
      const existingHash = snap.exists ? ((snap.data() || {}).contentHash || null) : null;
      const nextHash = item && item.contentHash ? item.contentHash : null;

      if (snap.exists && existingHash && nextHash && existingHash === nextHash) {
        skippedCount += 1;
        return;
      }

      const payload = {
        ...item,
        source: "k-startup",
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        payload.createdAt = FieldValue.serverTimestamp();
        newCount += 1;
      } else {
        updatedCount += 1;
      }
      batch.set(docRef, payload, { merge: true });
      writeOps += 1;
    });
    if (writeOps > 0) {
      await batch.commit();
    }

    return {
      success: true,
      message: `K-Startup ${scrapedItems.length}건 스크래핑(신규 ${newCount} / 업데이트 ${updatedCount} / 스킵 ${skippedCount})`,
      data: scrapedItems,
      count: scrapedItems.length,
      savedCount: newCount + updatedCount,
      newCount,
      updatedCount,
      skippedCount,
    };
  } catch (error) {
    console.error("K-Startup Scraping Logic Error:", error);
    throw error;
  }
}

// --- Helper: analysisResult 기반 deadlineTimestamp 생성 ---
function buildDeadlineTimestampFromAnalysis(analysisResult) {
  if (!analysisResult || !analysisResult.신청기간_종료일) {
    return null;
  }

  const deadlineString = analysisResult.신청기간_종료일;
  console.log("[analyzeScrapedGrantsBatch] Parsing deadline:", deadlineString);

  if (typeof deadlineString !== "string") {
    return null;
  }

  const datePattern = /^\d{4}-\d{2}-\d{2}$/;
  if (!datePattern.test(deadlineString)) {
    console.log("[analyzeScrapedGrantsBatch] Deadline does not match YYYY-MM-DD:", deadlineString);
    return null;
  }

  try {
    const parts = deadlineString.split("-");
    const parsedDate = new Date(Date.UTC(
      parseInt(parts[0], 10),
      parseInt(parts[1], 10) - 1,
      parseInt(parts[2], 10),
    ));
    if (!isNaN(parsedDate.getTime())) {
      return Timestamp.fromDate(parsedDate);
    }
  } catch (e) {
    console.error("[analyzeScrapedGrantsBatch] Error while building deadlineTimestamp:", e);
  }

  return null;
}

// --- Helper: Web 페이지 텍스트 기반 공고 상세 분석 ---
async function analyzeGrantDetailWithGemini(rawText) {
  const apiKeys = getApiKeysFromEnv();
  if (!apiKeys || apiKeys.length === 0) {
    console.error("[analyzeGrantDetailWithGemini] No Gemini API keys configured.");
    return { success: false, error: "NO_API_KEYS" };
  }

  const prompt = "너는 한국 정부 및 공공기관의 지원사업 공고를 분석하는 전문가야. " +
    "아래는 웹사이트에서 가져온 지원사업 공고 상세페이지의 텍스트야. " +
    "이 텍스트를 기반으로 지원사업 정보를 JSON 형태로 정확하게 추출해줘.\n\n" +
    "[공고문 텍스트 시작]\n" +
    rawText +
    "\n[공고문 텍스트 끝]\n\n" +
    "다음 JSON 스키마에 맞춰 응답해야 해:\n" +
    "{\n" +
    '  "사업명": "[사업의 공식 명칭]",\n' +
    '  "주관기관": "[사업 주관/운영 기관명]",\n' +
    '  "지원대상_요약": "[지원 대상에 대한 간략한 설명]",\n' +
    '  "신청자격_상세": "[업력, 소재지, 대표자 요건 등 상세 자격 조건 목록 또는 설명]",\n' +
    '  "지원내용": "[제공되는 지원 종류 목록 또는 설명]",\n' +
    '  "지원규모_금액": "[기업당 지원 최대/평균 금액]",\n' +
    '  "신청기간_시작일": "YYYY-MM-DD 형식의 신청 시작일, 없으면 null",\n' +
    '  "신청기간_종료일": "YYYY-MM-DD 형식의 신청 마감일, 없으면 null",\n' +
    '  "신청방법": "[온라인 접수 URL 또는 이메일 주소 등]",\n' +
    '  "지원기간_협약기간": "[실제 지원 기간 또는 협약 기간]",\n' +
    '  "신청제외대상_요약": "[주요 신청 제외 조건 요약]",\n' +
    '  "사업분야_키워드": ["[사업 관련 핵심 키워드 목록]"]\n' +
    "}\n\n" +
    "중요: '신청기간_시작일'과 '신청기간_종료일'은 반드시 'YYYY-MM-DD' 형식으로 반환해야 해. " +
    "문서에 정보가 없으면 null로 설정해. 반드시 순수 JSON만 응답하고, 설명 문장은 포함하지 마.";

  let lastError = null;
  for (const apiKey of apiKeys) {
    try {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: GEMINI_MODEL_NAME });
      const result = await model.generateContent(prompt);
      const text = result.response.text();
      let cleaned = text.trim();
      const codeBlockMatch = cleaned.match(/```(?:json)?\s*([\s\S]*?)```/i);
      if (codeBlockMatch) {
        cleaned = codeBlockMatch[1].trim();
      }
      const analysisResult = JSON.parse(cleaned);
      return {
        success: true,
        extractedTextRaw: rawText,
        analysisResult,
        rawResponse: text,
      };
    } catch (err) {
      lastError = err;
      const message = err && err.message ? err.message.toLowerCase() : "";
      console.error("[analyzeGrantDetailWithGemini] Gemini error:", err);
      if (!message.includes("quota")) {
        break;
      }
    }
  }

  return {
    success: false,
    error: lastError ? lastError.toString() : "UNKNOWN_ERROR",
  };
}

// --- Scraped Grants Batch Analyzer ---
exports.analyzeScrapedGrantsBatch = functions.https.onCall(async (request, context) => {
  await requireAdmin(context);

  const payload = request && typeof request === "object" && "data" in request ?
    request.data :
    request;

  const batchSizeRaw = payload && typeof payload.batchSize === "number" ? payload.batchSize : 5;
  const batchSize = Math.max(1, Math.min(10, Math.round(batchSizeRaw)));

  const allowedSources = Array.isArray(payload && payload.sources) && (payload.sources.length > 0)
    ? payload.sources.filter((s) => s === "bizinfo" || s === "k-startup")
    : ["bizinfo", "k-startup"];

  try {
    const queryRef = db.collection("grants")
      .where("source", "in", allowedSources)
      .orderBy("createdAt", "desc")
      .limit(50);

    const snapshot = await queryRef.get();
    if (snapshot.empty) {
      return {
        success: false,
        message: "해당 source에서 공고를 찾을 수 없습니다.",
        processed: 0,
        results: [],
      };
    }

    const targets = [];
    snapshot.forEach((docSnap) => {
      if (targets.length >= batchSize) {
        return;
      }
      const data = docSnap.data() || {};
      if (data.analysisResult) {
        return;
      }
      if (!data.link) {
        return;
      }
      targets.push({ doc: docSnap, data });
    });

    if (targets.length === 0) {
      return {
        success: false,
        message: "분석이 필요한 공고가 없습니다.",
        processed: 0,
        results: [],
      };
    }

    const results = [];
    for (const target of targets) {
      const { doc, data } = target;
      const docRef = doc.ref;
      const grantId = doc.id;
      let status = "processed";
      let errorMessage = null;

      try {
        const res = await axios.get(data.link, { timeout: 10000 });
        const html = res.data;
        const $ = cheerio.load(html);
        const bodyText = "" + $("body").text().replace(/\s+/g, " ").trim();

        if (!bodyText || bodyText.length < 200) {
          status = "skipped";
          errorMessage = "본문 텍스트가 너무 짧아서 분석을 건너뜁니다.";
        } else {
          const analysis = await analyzeGrantDetailWithGemini(bodyText);
          if (!analysis.success || !analysis.analysisResult) {
            status = "error";
            errorMessage = "Gemini 분석 실패";
          } else {
            const analysisResult = analysis.analysisResult;
            const deadlineTimestamp = buildDeadlineTimestampFromAnalysis(analysisResult);
            const updateData = {
              analysisResult,
              analysisStatus: "analysis_success",
              extractedTextRaw: analysis.extractedTextRaw || "",
              analyzedAt: FieldValue.serverTimestamp(),
            };
            if (deadlineTimestamp) {
              updateData.deadlineTimestamp = deadlineTimestamp;
            }
            await docRef.set(updateData, { merge: true });
          }
        }
      } catch (err) {
        console.error("[analyzeScrapedGrantsBatch] Error processing grant", grantId, err);
        status = "error";
        errorMessage = err && err.message ? err.message : String(err || "");
        try {
          await docRef.set({
            analysisStatus: "analysis_failed",
            analysisError: errorMessage,
            analyzedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        } catch (updateErr) {
          console.error("[analyzeScrapedGrantsBatch] Failed to update error status", grantId, updateErr);
        }
      }

      results.push({
        id: grantId,
        status,
        error: errorMessage,
      });
    }

    const processedCount = results.filter((r) => r.status === "processed").length;
    const successMessage = `${processedCount}건의 공고를 상세 분석했습니다.`;

    try {
      await logAdminSync(
        "analyze_scraped_grants_batch",
        "success",
        successMessage,
        { processed: processedCount, batchSize, sources: allowedSources },
        context,
      );
    } catch (e) {
      // 로깅 실패는 서비스 동작에 영향을 주지 않음
    }

    return {
      success: true,
      message: successMessage,
      processed: processedCount,
      results,
    };
  } catch (error) {
    console.error("[analyzeScrapedGrantsBatch] Fatal error:", error);
    try {
      await logAdminSync(
        "analyze_scraped_grants_batch",
        "error",
        error && error.message ? error.message : String(error),
        { batchSize, sources: allowedSources },
        context,
      );
    } catch (e) {
      // ignore log error
    }
    throw new functions.https.HttpsError(
      "internal",
      "스크랩된 공고 상세 분석 중 오류가 발생했습니다: " + (error && error.message ? error.message : String(error)),
    );
  }
});

exports.getBizinfoSchedulerConfig = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);

  try {
    const config = await getBizinfoSchedulerConfigInternal();
    let lastRunAt = null;
    if (config.lastRunAt && typeof config.lastRunAt.toDate === "function") {
      lastRunAt = config.lastRunAt.toDate().toISOString();
    } else if (typeof config.lastRunAt === "string") {
      lastRunAt = config.lastRunAt;
    }
    return {
      success: true,
      config: Object.assign({}, config, { lastRunAt }),
    };
  } catch (error) {
    console.error("getBizinfoSchedulerConfig error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "스케줄러 설정 조회 중 오류가 발생했습니다.",
    );
  }
});

exports.updateBizinfoSchedulerConfig = functions.https.onCall(async (data, context) => {
  await requireAdmin(context);

  const payload = data && typeof data === "object" && "data" in data ? data.data : data;
  const updates = {};
  if (payload && typeof payload === "object") {
    if (typeof payload.enabled === "boolean") {
      updates.enabled = payload.enabled;
    }
    if (typeof payload.intervalMinutes === "number") {
      updates.intervalMinutes = payload.intervalMinutes;
    }
    if (typeof payload.mode === "string") {
      updates.mode = payload.mode;
    }
    if (Array.isArray(payload.dailyTimes)) {
      updates.dailyTimes = payload.dailyTimes;
    }
  }
  if (Object.keys(updates).length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "업데이트할 필드가 없습니다.",
    );
  }
  try {
    const config = await applyBizinfoSchedulerConfigUpdate(updates);
    let lastRunAt = null;
    if (config.lastRunAt && typeof config.lastRunAt.toDate === "function") {
      lastRunAt = config.lastRunAt.toDate().toISOString();
    } else if (typeof config.lastRunAt === "string") {
      lastRunAt = config.lastRunAt;
    }
    return {
      success: true,
      config: Object.assign({}, config, { lastRunAt }),
    };
  } catch (error) {
    console.error("updateBizinfoSchedulerConfig error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "스케줄러 설정 업데이트 중 오류가 발생했습니다.",
    );
  }
});

exports.scrapeBizinfo = functions.https.onCall(async (request, context) => {
  await requireAdmin(context);

  try {
    const payload = request && typeof request === "object" && "data" in request ?
      request.data :
      request;
    const sinceDateRaw = payload && typeof payload.sinceDate === "string" ? payload.sinceDate : null;
    const sinceDate = normalizeIsoDateString(sinceDateRaw);
    if (!sinceDate) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "기준일(sinceDate, YYYY-MM-DD)을 입력해주세요.",
      );
    }
    const rangeDays = payload && typeof payload.rangeDays !== "undefined" ? clampRangeDays(payload.rangeDays) : 7;
    const result = await performBizinfoScraping({ sinceDate, rangeDays });
    try {
      await logAdminSync(
        "scrape_bizinfo",
        "success",
        result && result.message ? result.message : "Bizinfo 스크래핑 성공",
        {
          count: result && typeof result.count === "number" ? result.count : null,
          savedCount: result && typeof result.savedCount === "number" ? result.savedCount : null,
          newCount: result && typeof result.newCount === "number" ? result.newCount : null,
          updatedCount: result && typeof result.updatedCount === "number" ? result.updatedCount : null,
          skippedCount: result && typeof result.skippedCount === "number" ? result.skippedCount : null,
          sinceDate: sinceDate || null,
          rangeDays,
        },
        context,
      );
    } catch (e) {
      // 로깅 실패는 서비스 동작에 영향을 주지 않음
    }
    return result;
  } catch (error) {
    console.error("Scraping Error:", error);
    try {
      await logAdminSync(
        "scrape_bizinfo",
        "error",
        error && error.message ? error.message : String(error),
        null,
        context,
      );
    } catch (e) {
      // ignore log error
    }
    throw new functions.https.HttpsError(
      "internal",
      "스크래핑 중 오류가 발생했습니다: " + error.message,
    );
  }
});

exports.scrapeKStartup = functions.https.onCall(async (request, context) => {
  await requireAdmin(context);

  try {
    const payload = request && typeof request === "object" && "data" in request ?
      request.data :
      request;
    const sinceDateRaw = payload && typeof payload.sinceDate === "string" ? payload.sinceDate : null;
    const sinceDate = normalizeIsoDateString(sinceDateRaw);
    if (!sinceDate) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "기준일(sinceDate, YYYY-MM-DD)을 입력해주세요.",
      );
    }
    const rangeDays = payload && typeof payload.rangeDays !== "undefined" ? clampRangeDays(payload.rangeDays) : 7;
    const result = await performKStartupScraping({ sinceDate, rangeDays });
    try {
      await logAdminSync(
        "scrape_k_startup",
        "success",
        result && result.message ? result.message : "K-Startup 스크래핑 성공",
        {
          count: result && typeof result.count === "number" ? result.count : null,
          savedCount: result && typeof result.savedCount === "number" ? result.savedCount : null,
          newCount: result && typeof result.newCount === "number" ? result.newCount : null,
          updatedCount: result && typeof result.updatedCount === "number" ? result.updatedCount : null,
          skippedCount: result && typeof result.skippedCount === "number" ? result.skippedCount : null,
          sinceDate: sinceDate || null,
          rangeDays,
        },
        context,
      );
    } catch (e) {
      // 로깅 실패는 서비스 동작에 영향을 주지 않음
    }
    return result;
  } catch (error) {
    console.error("K-Startup Scraping Error:", error);
    try {
      await logAdminSync(
        "scrape_k_startup",
        "error",
        error && error.message ? error.message : String(error),
        null,
        context,
      );
    } catch (e) {
      // ignore log error
    }
    throw new functions.https.HttpsError(
      "internal",
      "K-Startup 스크래핑 중 오류가 발생했습니다: " + error.message,
    );
  }
});

const { onSchedule } = require("firebase-functions/v2/scheduler");

// ... (existing code)

// --- Scheduled Scraper (Every Day at 09:00 KST) ---
exports.scheduledScrapeBizinfo = onSchedule({
  schedule: "every 15 minutes",
  timeZone: "Asia/Seoul",
}, async () => {
  console.log("Running scheduled Bizinfo scraping (interval mode)...");
  try {
    const now = new Date();
    const seoul = getSeoulNowParts(now);
    const nowBucket = Math.floor(seoul.totalMinutes / 15) * 15;
    const runKey = `${seoul.ymd}_${String(nowBucket).padStart(4, "0")}`;

    const lock = await db.runTransaction(async (tx) => {
      const snap = await tx.get(bizinfoSchedulerDocRef);
      const data = snap.exists ? snap.data() : {};
      const config = Object.assign({}, DEFAULT_BIZINFO_SCHEDULER_CONFIG, data || {});

      if (config.mode !== "daily" && config.mode !== "interval") {
        config.mode = DEFAULT_BIZINFO_SCHEDULER_CONFIG.mode;
      }
      config.dailyTimes = normalizeDailyTimes(config.dailyTimes);
      if (config.mode === "daily" && config.dailyTimes.length === 0) {
        config.dailyTimes = DEFAULT_BIZINFO_SCHEDULER_CONFIG.dailyTimes.slice();
      }
      if (!config.intervalMinutes || typeof config.intervalMinutes !== "number" || config.intervalMinutes <= 0) {
        config.intervalMinutes = DEFAULT_BIZINFO_SCHEDULER_CONFIG.intervalMinutes;
      }

      if (!config.enabled) {
        return { shouldRun: false, reason: "disabled" };
      }

      if (config.mode === "daily") {
        const due = config.dailyTimes.some((t) => {
          const minutes = parseDailyTimeToMinutes(t);
          if (minutes === null) return false;
          return Math.floor(minutes / 15) * 15 === nowBucket;
        });
        if (!due) {
          return { shouldRun: false, reason: "not_due" };
        }
        if (config.lastRunKey === runKey) {
          return { shouldRun: false, reason: "already_ran" };
        }
      } else {
        const intervalMinutes = config.intervalMinutes;
        let shouldRun = true;
        if (config.lastRunAt && typeof config.lastRunAt.toDate === "function") {
          const lastRunDate = config.lastRunAt.toDate();
          const diffMs = now.getTime() - lastRunDate.getTime();
          const diffMinutes = diffMs / (1000 * 60);
          if (diffMinutes < intervalMinutes) {
            shouldRun = false;
          }
        }
        if (!shouldRun) {
          return { shouldRun: false, reason: "interval_not_elapsed" };
        }
      }

      tx.set(bizinfoSchedulerDocRef, {
        lastRunAt: FieldValue.serverTimestamp(),
        lastRunKey: runKey,
        lastRunError: null,
      }, { merge: true });

      return { shouldRun: true };
    });

    if (!lock || !lock.shouldRun) {
      if (lock && lock.reason === "disabled") {
        console.log("Bizinfo scheduler is disabled; skipping run.");
      } else if (lock && lock.reason === "not_due") {
        console.log("Skipping Bizinfo scraping; not a daily scheduled time.");
      } else if (lock && lock.reason === "already_ran") {
        console.log("Skipping Bizinfo scraping; already ran for this time slot.");
      } else if (lock && lock.reason === "interval_not_elapsed") {
        console.log("Skipping Bizinfo scraping; interval has not elapsed yet.");
      } else {
        console.log("Skipping Bizinfo scraping.");
      }
      return;
    }

    const result = await performBizinfoScraping({ sinceDate: seoul.ymd, rangeDays: 1 });
    console.log("Scheduled scraping completed:", result.message);
    await bizinfoSchedulerDocRef.set({
      lastRunAt: FieldValue.serverTimestamp(),
      lastRunKey: runKey,
      lastRunResult: result.message,
      lastRunError: null,
    }, { merge: true });
    try {
      await logAdminSync(
        "scheduled_scrape_bizinfo",
        "success",
        result && result.message ? result.message : "스케줄 Bizinfo 스크래핑 성공",
        {
          scheduled: true,
          count: result && typeof result.count === "number" ? result.count : null,
          savedCount: result && typeof result.savedCount === "number" ? result.savedCount : null,
          newCount: result && typeof result.newCount === "number" ? result.newCount : null,
          updatedCount: result && typeof result.updatedCount === "number" ? result.updatedCount : null,
          skippedCount: result && typeof result.skippedCount === "number" ? result.skippedCount : null,
        },
        null,
      );
    } catch (e) {
      // ignore log error
    }
  } catch (error) {
    console.error("Scheduled scraping failed:", error);
    try {
      try {
        await logAdminSync(
          "scheduled_scrape_bizinfo",
          "error",
          error && error.message ? error.message : String(error),
          { scheduled: true },
          null,
        );
      } catch (e) {
        // ignore log error
      }
      await bizinfoSchedulerDocRef.set({
        lastRunAt: FieldValue.serverTimestamp(),
        lastRunError: error && error.message ? error.message : String(error),
      }, { merge: true });
    } catch (e) {
      console.error("Failed to update scheduler status:", e);
    }
  }
});
