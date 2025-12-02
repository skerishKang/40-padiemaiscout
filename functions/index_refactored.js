const functions = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");
const fs = require("fs");
const os = require("os");
const path = require("path");
const {onObjectFinalized} = require("firebase-functions/v2/storage");
const {setGlobalOptions} = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");

// Import custom services
const GeminiService = require("./src/services/gemini-service");
const FirestoreService = require("./src/services/firestore-service");
const SuitabilityService = require("./src/services/suitability-service");

// Load environment variables
require("dotenv").config();

// Initialize Firebase Admin
initializeApp();

// Set global options
setGlobalOptions({region: "us-central1"});

// Initialize services
const geminiService = new GeminiService();
const firestoreService = new FirestoreService();
const suitabilityService = new SuitabilityService();
const storage = getStorage();

// Health check endpoint
exports.helloWorld = (req, res) => {
  res.send("Hello from Firebase!");
};

// PDF text extraction function
exports.extractPdfText = onObjectFinalized({cpu: 1}, async (event) => {
  const fileBucket = event.data.bucket;
  const filePath = event.data.name;
  const contentType = event.data.contentType;

  // Validate file type and path
  if (!contentType || !contentType.startsWith("application/pdf")) {
    logger.log(`파일 [${filePath}]은 PDF가 아니므로 처리하지 않습니다.`);
    return null;
  }
  
  if (!filePath || !filePath.startsWith("uploads/")) {
    logger.log(`파일 [${filePath}]은 'uploads/' 경로가 아니므로 처리하지 않습니다.`);
    return null;
  }

  logger.info(`PDF 분석 시작: ${filePath}`);

  const bucket = storage.bucket(fileBucket);
  const tempFilePath = path.join(os.tmpdir(), path.basename(filePath));

  try {
    // Download file to temporary location
    logger.info(`파일 다운로드 시작: ${tempFilePath}`);
    await bucket.file(filePath).download({destination: tempFilePath});
    logger.info(`PDF 파일 다운로드 완료: ${tempFilePath}`);

    // Find corresponding Firestore document
    const documentResult = await firestoreService.findDocumentByStoragePath(filePath);
    if (!documentResult) {
      return null;
    }

    const { docRef, docId } = documentResult;

    // Update status to processing
    await firestoreService.updateProcessingStatus(docRef, docId);

    // Add delay for testing loading indicator
    logger.info("3초 지연 시작 (로딩 표시 테스트용)...");
    await new Promise((resolve) => setTimeout(resolve, 3000));
    logger.info("지연 완료. Gemini API 호출 시작...");

    // Analyze PDF content with Gemini
    const analysisResult = await geminiService.analyzePdfContent(tempFilePath);

    // Update Firestore with results
    await firestoreService.updateAnalysisResults(docRef, docId, analysisResult);

  } catch (e) {
    logger.error("PDF 처리 중 예상치 못한 오류:", e);
  } finally {
    // Clean up temporary file
    if (fs.existsSync(tempFilePath)) {
      fs.unlinkSync(tempFilePath);
      logger.info(`임시 파일 삭제 완료: ${tempFilePath}`);
    }
  }

  return null;
});

// API key status check function
exports.checkApiKeyStatus = functions.https.onCall(async (data, context) => {
  // For production, uncomment authentication check
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', '인증 필요');
  // }

  return await geminiService.checkApiKeyStatus();
});

// Suitability analysis function
exports.checkSuitability = functions.https.onCall(async (data, context) => {
  const userProfile = data.userProfile;
  const analysisResult = data.analysisResult;
  
  if (!userProfile || !analysisResult) {
    return {status: "error", message: "userProfile과 analysisResult가 모두 필요합니다."};
  }

  return await suitabilityService.checkSuitability(userProfile, analysisResult);
});