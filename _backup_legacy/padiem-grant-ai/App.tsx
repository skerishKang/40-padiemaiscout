import React, { useState } from 'react';
import Navbar from './components/Navbar';
import CompanyForm from './components/CompanyForm';
import GrantUpload from './components/GrantUpload';
import AnalysisDashboard from './components/AnalysisDashboard';
import GrantSearch from './components/GrantSearch';
import { CompanyProfile, AppStep, GrantAnalysisResult, Language, ModelType, UploadedFile } from './types';
import { analyzeGrantDocument } from './services/gemini';
import { AlertCircle } from 'lucide-react';

const App: React.FC = () => {
  const [currentStep, setCurrentStep] = useState<AppStep>(AppStep.PROFILE);
  const [language, setLanguage] = useState<Language>('ko'); 
  const [selectedModel, setSelectedModel] = useState<ModelType>('gemini-2.5-flash');
  
  const [companyProfile, setCompanyProfile] = useState<CompanyProfile>({
    name: '',
    industry: '',
    employees: 0,
    revenue: '',
    location: '',
    description: ''
  });
  
  // Store the file so we can re-analyze it if the profile changes
  const [uploadedFile, setUploadedFile] = useState<UploadedFile | null>(null);
  const [analysisResult, setAnalysisResult] = useState<GrantAnalysisResult | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const t = {
    errorTitle: language === 'ko' ? '분석 오류' : 'Analysis Error',
    errorDesc: language === 'ko' 
      ? '문서를 분석하지 못했습니다. 유효한 PDF/이미지 파일인지, API 키가 올바른지 확인해주세요.' 
      : 'Failed to analyze the document. Please ensure the API key is valid and the file is a readable PDF/Image.',
    errorFile: language === 'ko' ? '파일을 읽는 중 오류가 발생했습니다.' : 'Error reading the file.',
    errorGeneric: language === 'ko' ? '알 수 없는 오류가 발생했습니다.' : 'An unexpected error occurred.',
    dismiss: language === 'ko' ? '닫기' : 'Dismiss'
  };

  const handleProfileSubmit = (data: CompanyProfile) => {
    setCompanyProfile(data);
    
    // If we already have a file, it means we came from the Results page to "Refine Profile".
    // We should immediately re-analyze with the new data.
    if (uploadedFile && currentStep === AppStep.PROFILE) {
      handleReAnalysis(uploadedFile, data);
    } else {
      setCurrentStep(AppStep.UPLOAD);
    }
  };

  const handleFileUpload = async (file: File) => {
    setIsAnalyzing(true);
    setError(null);
    try {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = async () => {
        const base64String = reader.result as string;
        const base64Content = base64String.split(',')[1];
        
        const fileData: UploadedFile = {
          base64: base64Content,
          mimeType: file.type,
          name: file.name
        };
        setUploadedFile(fileData);

        try {
          const result = await analyzeGrantDocument(fileData.base64, fileData.mimeType, companyProfile, language, selectedModel);
          setAnalysisResult(result);
          setCurrentStep(AppStep.RESULTS);
        } catch (err: any) {
          console.error(err);
          setError(t.errorDesc);
        } finally {
          setIsAnalyzing(false);
        }
      };
      reader.onerror = () => {
        setError(t.errorFile);
        setIsAnalyzing(false);
      };
    } catch (err) {
      setError(t.errorGeneric);
      setIsAnalyzing(false);
    }
  };

  const handleReAnalysis = async (file: UploadedFile, profile: CompanyProfile) => {
    setIsAnalyzing(true);
    setCurrentStep(AppStep.ANALYZING); // Show loading spinner
    try {
      const result = await analyzeGrantDocument(file.base64, file.mimeType, profile, language, selectedModel);
      setAnalysisResult(result);
      setCurrentStep(AppStep.RESULTS);
    } catch (err) {
      console.error(err);
      setError(t.errorDesc);
      setCurrentStep(AppStep.UPLOAD);
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleReset = () => {
    setAnalysisResult(null);
    setUploadedFile(null);
    setCurrentStep(AppStep.UPLOAD);
  };

  const handleBackToProfile = () => {
    setCurrentStep(AppStep.PROFILE);
  };

  const handleRefineProfile = () => {
    setCurrentStep(AppStep.PROFILE);
  };

  const handleNavigate = (step: AppStep) => {
    // If navigating to results but no result exists, go to upload
    if (step === AppStep.RESULTS && !analysisResult) {
      setCurrentStep(AppStep.UPLOAD);
      return;
    }
    setCurrentStep(step);
  };

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col font-sans text-slate-900">
      <Navbar 
        language={language} 
        onLanguageChange={setLanguage} 
        selectedModel={selectedModel}
        onModelChange={setSelectedModel}
        currentStep={currentStep}
        onNavigate={handleNavigate}
      />
      
      <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 w-full">
        
        {error && (
           <div className="max-w-2xl mx-auto mb-6 p-4 bg-red-50 text-red-700 rounded-xl border border-red-200 flex items-start gap-3 shadow-sm">
              <AlertCircle className="h-5 w-5 flex-shrink-0 mt-0.5" />
              <div>
                <h4 className="font-semibold">{t.errorTitle}</h4>
                <p className="text-sm mt-1">{error}</p>
                <button 
                  onClick={() => setError(null)}
                  className="text-sm font-semibold underline mt-2 hover:text-red-800"
                >
                  {t.dismiss}
                </button>
              </div>
           </div>
        )}

        {/* SEARCH STEP */}
        {currentStep === AppStep.SEARCH && (
          <GrantSearch language={language} />
        )}

        {/* PROFILE STEP */}
        {currentStep === AppStep.PROFILE && (
          <CompanyForm 
            initialData={companyProfile} 
            onSubmit={handleProfileSubmit} 
            language={language}
          />
        )}

        {/* UPLOAD & ANALYZING STEPS */}
        {(currentStep === AppStep.UPLOAD || currentStep === AppStep.ANALYZING) && (
          <GrantUpload 
            onFileSelect={handleFileUpload}
            onBack={handleBackToProfile}
            isAnalyzing={isAnalyzing}
            language={language}
          />
        )}

        {/* RESULTS STEP */}
        {currentStep === AppStep.RESULTS && analysisResult && (
          <AnalysisDashboard 
            result={analysisResult} 
            onReset={handleReset} 
            onRefineProfile={handleRefineProfile}
            language={language}
            companyName={companyProfile.name}
          />
        )}

      </main>

      <footer className="bg-white border-t border-slate-200 py-6">
         <div className="max-w-7xl mx-auto px-4 text-center text-slate-400 text-sm">
            <p>&copy; {new Date().getFullYear()} Padiem Grant AI. Powered by Google Gemini.</p>
         </div>
      </footer>
    </div>
  );
};

export default App;