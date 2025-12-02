import { GoogleGenAI, Type, Schema } from "@google/genai";
import { CompanyProfile, GrantAnalysisResult, Language, ModelType, SearchResult } from "../types";

const apiKey = process.env.API_KEY;

if (!apiKey) {
  console.error("API_KEY is missing in process.env");
}

const ai = new GoogleGenAI({ apiKey: apiKey || '' });

const analysisSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    grantTitle: { type: Type.STRING, description: "The official title of the grant or funding program." },
    issuingAgency: { type: Type.STRING, description: "The organization offering the grant." },
    deadline: { type: Type.STRING, description: "The submission deadline date (YYYY-MM-DD or specific text)." },
    fundingAmount: { type: Type.STRING, description: "Total funding amount or max per applicant." },
    eligibilityCriteria: { 
      type: Type.ARRAY, 
      items: { type: Type.STRING },
      description: "List of key eligibility requirements." 
    },
    summary: { type: Type.STRING, description: "A concise summary of the grant purpose." },
    suitabilityScore: { type: Type.INTEGER, description: "A score from 0 to 100 indicating fit for the user's company. If company profile is missing, return 50." },
    suitabilityReasoning: { type: Type.STRING, description: "Detailed explanation of why this score was assigned. If profile is missing, explain generally." },
    keyRequirements: { 
      type: Type.ARRAY, 
      items: { type: Type.STRING },
      description: "Specific documents or certifications required."
    },
    matchStatus: { type: Type.STRING, enum: ["High", "Medium", "Low"], description: "Overall classification of the match." }
  },
  required: ["grantTitle", "issuingAgency", "deadline", "fundingAmount", "suitabilityScore", "suitabilityReasoning", "matchStatus"]
};

export const analyzeGrantDocument = async (
  fileBase64: string, 
  mimeType: string, 
  profile: CompanyProfile,
  language: Language,
  modelName: ModelType = 'gemini-2.5-flash'
): Promise<GrantAnalysisResult> => {
  
  const isProfileEmpty = !profile.name || profile.name.trim() === '';

  const profileContext = isProfileEmpty 
    ? `User has NOT provided a specific company profile yet. 
       - Evaluate the grant generally. 
       - Set 'suitabilityScore' to 50 (Neutral) unless the grant is obviously for everyone.
       - In 'suitabilityReasoning', explain generally what kind of companies this grant is best suited for, and explicitly state that the user should provide company details for a personalized score.`
    : `Company Profile:
       - Name: ${profile.name}
       - Industry: ${profile.industry}
       - Employees: ${profile.employees}
       - Revenue: ${profile.revenue}
       - Location: ${profile.location}
       - Description: ${profile.description}
       
       Be critical about the 'suitabilityScore' (0-100). 
       - If the company is clearly ineligible (e.g., wrong industry, wrong location, revenue too high/low), give a low score (<50) and 'Low' status.
       - If it's a perfect fit, give >80 and 'High'.
       - Otherwise 'Medium'.`;

  const languageInstruction = language === 'ko' 
    ? "OUTPUT MUST BE IN KOREAN (Hangul). Translate all extracted fields (summary, reasoning, criteria, etc.) into natural Korean."
    : "Output must be in English.";

  const systemInstruction = `
    You are Padiem Grant AI, an expert AI grant analyst. 
    Your task is to analyze a grant announcement document (PDF or Image) and extract structured data.
    
    ${profileContext}

    ${languageInstruction}

    Analyze the document strictly. If the document is not a grant announcement, indicate this in the summary.
  `;

  try {
    const response = await ai.models.generateContent({
      model: modelName,
      config: {
        systemInstruction: systemInstruction,
        responseMimeType: "application/json",
        responseSchema: analysisSchema,
        temperature: 0.2,
      },
      contents: {
        parts: [
          {
            inlineData: {
              mimeType: mimeType,
              data: fileBase64
            }
          },
          {
            text: "Analyze this grant document based on the system instructions."
          }
        ]
      }
    });

    const text = response.text;
    if (!text) throw new Error("No response from Gemini");

    return JSON.parse(text) as GrantAnalysisResult;

  } catch (error) {
    console.error("Error analyzing grant:", error);
    throw error;
  }
};

export const searchGrants = async (
  query: string,
  language: Language
): Promise<SearchResult> => {
  const modelName = 'gemini-2.5-flash'; // Flash is good for search
  
  const langPrompt = language === 'ko' 
    ? "한국어로 답변해줘. 한국의 최신 정부 지원사업(K-Startup, 기업마당 등) 위주로 찾아줘." 
    : "Answer in English. Focus on grants in South Korea.";

  const prompt = `
    Find recent government grant announcements or funding programs related to: "${query}".
    ${langPrompt}
    Provide a summary of the 3-5 most relevant grants found. 
    For each grant, list the Title, Agency, Deadline (if available), and a brief 1-sentence description.
    Make the output easy to read.
  `;

  try {
    const response = await ai.models.generateContent({
      model: modelName,
      contents: prompt,
      config: {
        tools: [{ googleSearch: {} }],
        // Note: responseMimeType is NOT allowed with googleSearch
      },
    });

    const text = response.text || "No results found.";
    
    // Extract grounding chunks (source links)
    const chunks = response.candidates?.[0]?.groundingMetadata?.groundingChunks || [];
    const sourceLinks = chunks
      .map((chunk: any) => {
        if (chunk.web) {
          return { title: chunk.web.title, uri: chunk.web.uri };
        }
        return null;
      })
      .filter((link: any) => link !== null);

    return {
      text,
      sourceLinks
    };

  } catch (error) {
    console.error("Error searching grants:", error);
    throw error;
  }
};