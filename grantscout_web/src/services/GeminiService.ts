import { httpsCallable } from 'firebase/functions';
import { functions } from '../lib/firebase';

export type GeminiModelType = "gemini-2.5-flash-lite" | "gemini-2.5-flash" | "gemini-2.5-pro";

class GeminiService {
    private currentModel: GeminiModelType = "gemini-2.5-flash-lite";

    public setModel(model: GeminiModelType) {
        this.currentModel = model;
    }

    public getCurrentModel() {
        return this.currentModel;
    }

    public async generateContent(prompt: string, fileData?: { mimeType: string; data: string }): Promise<string> {
        try {
            console.log("[GeminiService] generateContent payload", {
                hasPrompt: !!prompt,
                promptPreview: prompt ? String(prompt).slice(0, 80) : "",
                hasFileData: !!fileData,
                model: this.currentModel,
            });

            // Specify the region where the function is deployed
            const chatWithGemini = httpsCallable(functions, 'chatWithGemini', { timeout: 60000 });
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
