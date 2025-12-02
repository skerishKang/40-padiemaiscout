export type Language = 'ko' | 'en';

export type ModelType = 'gemini-2.5-flash' | 'gemini-2.0-flash-thinking-exp-1219' | 'gemini-1.5-pro';

export interface CompanyProfile {
  name: string;
  industry: string;
  employees: number;
  revenue: string;
  location: string;
  description: string;
}

export interface GrantAnalysisResult {
  grantTitle: string;
  issuingAgency: string;
  deadline: string;
  fundingAmount: string;
  eligibilityCriteria: string[];
  summary: string;
  suitabilityScore: number; // 0 to 100
  suitabilityReasoning: string;
  keyRequirements: string[];
  matchStatus: 'High' | 'Medium' | 'Low';
}

export enum AppStep {
  PROFILE = 'PROFILE',
  UPLOAD = 'UPLOAD',
  SEARCH = 'SEARCH',
  ANALYZING = 'ANALYZING',
  RESULTS = 'RESULTS',
}

export interface UploadedFile {
  base64: string;
  mimeType: string;
  name: string;
}

export interface SearchResult {
  text: string;
  sourceLinks: {
    title: string;
    uri: string;
  }[];
}