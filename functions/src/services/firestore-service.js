const { getFirestore, Timestamp, FieldValue } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

class FirestoreService {
  constructor() {
    this.db = getFirestore();
  }

  async findDocumentByStoragePath(storagePath) {
    try {
      const uploadedFilesRef = this.db.collection("uploaded_files");
      logger.info(`Attempting to find document with storagePath: ${storagePath}`);

      const querySnapshot = await uploadedFilesRef
          .where("storagePath", "==", storagePath)
          .limit(1)
          .get();

      if (querySnapshot.empty) {
        logger.error(
            `CRITICAL: No Firestore document found for storagePath: ${storagePath}. Function cannot proceed.`,
        );
        return null;
      }

      const docRef = querySnapshot.docs[0].ref;
      const docId = docRef.id;
      logger.info(
        `SUCCESS: Found Firestore document ID: ${docId} for storagePath: ${storagePath}`,
      );

      return { docRef, docId };
    } catch (queryError) {
      logger.error(
          `CRITICAL: Error querying Firestore for storagePath: ${storagePath}`,
          queryError,
      );
      return null;
    }
  }

  async updateProcessingStatus(docRef, docId) {
    try {
      await docRef.update({
        analysisStatus: "processing",
        analyzedAt: FieldValue.serverTimestamp(),
        processingStartedAt: FieldValue.serverTimestamp(),
      });
      logger.info(`Status updated to 'processing' for document: ${docId}`);
    } catch (initUpdateError) {
      logger.error(
        `Failed to update status to 'processing' for document: ${docId}`,
        initUpdateError,
      );
      throw initUpdateError;
    }
  }

  async updateAnalysisResults(docRef, docId, analysisData) {
    try {
      const deadlineTimestamp = this._processDeadlineTimestamp(analysisData.analysisResult);

      const updateData = {
        analysisStatus: analysisData.success ? "analysis_success" : "text_extracted_failed",
        analysisResult: analysisData.analysisResult,
        extractedTextRaw: analysisData.extractedTextRaw || "",
        analyzedAt: FieldValue.serverTimestamp(),
        processingEndedAt: FieldValue.serverTimestamp(),
        deadlineTimestamp: deadlineTimestamp,
      };

      await docRef.update(updateData);
      logger.info(
        `SUCCESS: Firestore document update complete for ID: ${docId} with status: ${updateData.analysisStatus}`
      );
    } catch (error) {
      logger.error(
          `ERROR: Failed processing/updating Firestore for ID: ${docId}`,
          error,
      );
      await this._updateErrorStatus(docRef, docId, error);
    }
  }

  _processDeadlineTimestamp(analysisResult) {
    if (!analysisResult || !analysisResult.신청기간_종료일) {
      return null;
    }

    const deadlineString = analysisResult.신청기간_종료일;
    logger.info(`Attempting to parse deadline: "${deadlineString}" (Type: ${typeof deadlineString})`);

    if (typeof deadlineString !== 'string') {
      return null;
    }

    const datePattern = /^\d{4}-\d{2}-\d{2}$/;
    if (!datePattern.test(deadlineString)) {
      logger.warn(`Deadline string "${deadlineString}" FAILED format check (YYYY-MM-DD).`);
      return null;
    }

    try {
      const dateParts = deadlineString.split('-');
      const parsedDate = new Date(Date.UTC(
        parseInt(dateParts[0]),
        parseInt(dateParts[1]) - 1,
        parseInt(dateParts[2])
      ));

      if (!isNaN(parsedDate.getTime())) {
        logger.info(`Deadline successfully parsed to Timestamp.`);
        return Timestamp.fromDate(parsedDate);
      } else {
        logger.warn(`Invalid date parsed from deadline string: ${deadlineString}`);
        return null;
      }
    } catch (e) {
      logger.error(`Error during Date/Timestamp conversion for "${deadlineString}":`, e);
      return null;
    }
  }

  async _updateErrorStatus(docRef, docId, error) {
    try {
      await docRef.update({
        analysisStatus: "text_extracted_failed",
        errorDetails: error.message || "Unknown error during extraction/update",
        analyzedAt: FieldValue.serverTimestamp(),
      });
    } catch (updateError) {
      logger.error(
          `ERROR: Failed to update Firestore error status for ID: ${docId}`,
          updateError,
      );
    }
  }
}

module.exports = FirestoreService;