import React from 'react';
import { GrantAnalysisResult, Language, CompanyProfile } from '../types';
import { 
  CheckCircle, 
  AlertTriangle, 
  XCircle, 
  Calendar, 
  DollarSign, 
  Building2, 
  FileText, 
  ListChecks, 
  TrendingUp,
  RefreshCcw,
  UserPlus
} from 'lucide-react';

interface Props {
  result: GrantAnalysisResult;
  onReset: () => void;
  onRefineProfile: () => void;
  language: Language;
  companyName: string;
}

const AnalysisDashboard: React.FC<Props> = ({ result, onReset, onRefineProfile, language, companyName }) => {
  
  const t = {
    deadline: language === 'ko' ? '마감일' : 'Deadline',
    amount: language === 'ko' ? '지원 금액' : 'Amount',
    summary: language === 'ko' ? '요약' : 'Summary',
    fitAnalysis: language === 'ko' ? 'AI 적합성 분석' : 'AI Fit Analysis',
    score: language === 'ko' ? '점수' : 'Score',
    eligibility: language === 'ko' ? '지원 자격' : 'Eligibility Criteria',
    requirements: language === 'ko' ? '필수 요건' : 'Key Requirements',
    analyzeAgain: language === 'ko' ? '다른 공고 분석하기' : 'Analyze Another Grant',
    addProfile: language === 'ko' ? '회사 정보 입력하고 정확도 높이기' : 'Add Profile for Better Accuracy',
    profileMissing: language === 'ko' ? '회사 정보 미입력' : 'Profile Missing'
  };

  const getScoreColor = (score: number) => {
    if (score >= 80) return 'text-emerald-600 bg-emerald-50 border-emerald-200';
    if (score >= 50) return 'text-amber-600 bg-amber-50 border-amber-200';
    return 'text-red-600 bg-red-50 border-red-200';
  };

  const getMatchIcon = (status: string) => {
    switch (status.toLowerCase()) {
      case 'high': return <CheckCircle className="h-8 w-8 text-emerald-500" />;
      case 'medium': return <AlertTriangle className="h-8 w-8 text-amber-500" />;
      case 'low': return <XCircle className="h-8 w-8 text-red-500" />;
      default: return <AlertTriangle className="h-8 w-8 text-slate-500" />;
    }
  };

  const isProfileEmpty = !companyName || companyName.trim() === '';

  return (
    <div className="max-w-6xl mx-auto w-full space-y-6">
      
      {/* Header / Score Card */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-white rounded-2xl shadow-sm border border-slate-200 p-6">
          <div className="flex items-start justify-between">
            <div>
              <div className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mb-2">
                {result.issuingAgency}
              </div>
              <h1 className="text-2xl font-bold text-slate-900 leading-tight">
                {result.grantTitle}
              </h1>
            </div>
            {getMatchIcon(result.matchStatus)}
          </div>
          
          <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
             <div className="flex items-center gap-3 p-3 bg-slate-50 rounded-lg">
                <div className="bg-white p-2 rounded border border-slate-100">
                  <Calendar className="h-5 w-5 text-indigo-600" />
                </div>
                <div>
                  <p className="text-xs text-slate-500 font-medium uppercase">{t.deadline}</p>
                  <p className="text-sm font-semibold text-slate-900">{result.deadline}</p>
                </div>
             </div>
             <div className="flex items-center gap-3 p-3 bg-slate-50 rounded-lg">
                <div className="bg-white p-2 rounded border border-slate-100">
                  <DollarSign className="h-5 w-5 text-indigo-600" />
                </div>
                <div>
                  <p className="text-xs text-slate-500 font-medium uppercase">{t.amount}</p>
                  <p className="text-sm font-semibold text-slate-900">{result.fundingAmount}</p>
                </div>
             </div>
          </div>

          <div className="mt-6">
            <h3 className="text-sm font-semibold text-slate-900 flex items-center gap-2 mb-2">
              <FileText className="h-4 w-4 text-slate-400" />
              {t.summary}
            </h3>
            <p className="text-slate-600 text-sm leading-relaxed">
              {result.summary}
            </p>
          </div>
        </div>

        {/* Fit Analysis Card */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col h-full">
           <div className="flex justify-between items-center mb-4">
             <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2">
              <TrendingUp className="h-5 w-5 text-indigo-600" />
              {t.fitAnalysis}
            </h3>
            {isProfileEmpty && (
              <span className="text-xs font-medium bg-slate-100 text-slate-500 px-2 py-1 rounded">
                {t.profileMissing}
              </span>
            )}
           </div>
          
          <div className="flex items-center justify-center mb-6">
             <div className="relative w-32 h-32">
               <svg className="w-full h-full" viewBox="0 0 36 36">
                  <path
                    className="text-slate-100"
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="3"
                  />
                  <path
                    className={`${result.suitabilityScore >= 80 ? 'text-emerald-500' : result.suitabilityScore >= 50 ? 'text-amber-500' : 'text-red-500'} transition-all duration-1000 ease-out`}
                    strokeDasharray={`${result.suitabilityScore}, 100`}
                    d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="3"
                  />
                </svg>
                <div className="absolute inset-0 flex items-center justify-center flex-col">
                  <span className="text-3xl font-bold text-slate-900">{result.suitabilityScore}</span>
                  <span className="text-xs text-slate-500">{t.score}</span>
                </div>
             </div>
          </div>

          <div className={`p-4 rounded-xl text-sm ${getScoreColor(result.suitabilityScore)} mb-4`}>
            <p className="font-medium">{result.suitabilityReasoning}</p>
          </div>
          
          {isProfileEmpty && (
            <button 
              onClick={onRefineProfile}
              className="mt-auto flex items-center justify-center gap-2 w-full py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium transition-colors shadow-sm"
            >
              <UserPlus className="h-4 w-4" />
              {t.addProfile}
            </button>
          )}
        </div>
      </div>

      {/* Details Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        
        {/* Eligibility */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6">
          <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-4">
            <Building2 className="h-5 w-5 text-indigo-600" />
            {t.eligibility}
          </h3>
          <ul className="space-y-3">
            {result.eligibilityCriteria.map((item, idx) => (
              <li key={idx} className="flex items-start gap-3">
                 <div className="mt-1 min-w-[1.25rem]">
                   <div className="h-5 w-5 rounded-full bg-indigo-50 text-indigo-600 flex items-center justify-center text-xs font-bold">
                     {idx + 1}
                   </div>
                 </div>
                 <span className="text-slate-600 text-sm">{item}</span>
              </li>
            ))}
          </ul>
        </div>

        {/* Requirements */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6">
          <h3 className="text-lg font-bold text-slate-900 flex items-center gap-2 mb-4">
            <ListChecks className="h-5 w-5 text-indigo-600" />
            {t.requirements}
          </h3>
          <ul className="space-y-3">
             {result.keyRequirements.map((item, idx) => (
              <li key={idx} className="flex items-start gap-3">
                 <CheckCircle className="h-5 w-5 text-emerald-500 flex-shrink-0 mt-0.5" />
                 <span className="text-slate-600 text-sm">{item}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div className="flex justify-center pt-8 pb-12">
        <button
          onClick={onReset}
          className="flex items-center gap-2 px-8 py-3 bg-white border border-slate-300 shadow-sm rounded-lg text-slate-700 font-medium hover:bg-slate-50 transition-colors"
        >
          <RefreshCcw className="h-4 w-4" />
          {t.analyzeAgain}
        </button>
      </div>

    </div>
  );
};

export default AnalysisDashboard;