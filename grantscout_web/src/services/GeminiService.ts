import { httpsCallable } from 'firebase/functions';
import { functions } from '../lib/firebase';

export type GeminiModelType = "gemini-1.5-flash" | "gemini-1.5-pro" | "gemini-1.5-flash-8b";

class GeminiService {
    private currentModel: GeminiModelType = "gemini-1.5-flash";

    public setModel(model: GeminiModelType) {
        this.currentModel = model;
    }

    public getCurrentModel() {
        return this.currentModel;
    }

    public async generateContent(prompt: string, fileData?: { mimeType: string; data: string }): Promise<string> {
        try {
            // Specify the region where the function is deployed
            const chatWithGemini = httpsCallable(functions, 'chatWithGemini', { timeout: 60000 });
            // Note: If functions instance isn't region-specific, we might need to get a region-specific instance.
            // But usually httpsCallable handles it if we pass the right instance or options?
            // Actually, the firebase.ts exports 'functions' which is getFunctions(app). 
            // By default getFunctions(app) uses us-central1.
            // We need to update firebase.ts to use getFunctions(app, 'asia-northeast3').
            const result = await chatWithGemini({
                prompt,
                fileData,
                model: this.currentModel // Optional: Pass model if backend supports it
            });

            const data = result.data as any;
            if (data.status === 'error') {
                throw new Error(data.message || data.error || 'Unknown error from backend');
            }

            return data.text;
        } catch (error: any) {
            console.error("Gemini Service Error:", error);
            throw error;
        }
    }
}

export const geminiService = new GeminiService();
