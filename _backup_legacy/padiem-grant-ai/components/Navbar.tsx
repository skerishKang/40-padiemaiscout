import React, { useState } from 'react';
import { Target, Settings, ChevronDown, Search, Upload, User, Menu, X } from 'lucide-react';
import { Language, ModelType, AppStep } from '../types';

interface Props {
  language: Language;
  onLanguageChange: (lang: Language) => void;
  selectedModel: ModelType;
  onModelChange: (model: ModelType) => void;
  currentStep: AppStep;
  onNavigate: (step: AppStep) => void;
}

const Navbar: React.FC<Props> = ({ 
  language, 
  onLanguageChange, 
  selectedModel, 
  onModelChange,
  currentStep,
  onNavigate
}) => {
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const toggleSettings = () => setIsSettingsOpen(!isSettingsOpen);
  const toggleMobileMenu = () => setIsMobileMenuOpen(!isMobileMenuOpen);

  const models: {id: ModelType, name: string}[] = [
    { id: 'gemini-2.5-flash', name: 'Gemini 2.5 Flash (Fast)' },
    { id: 'gemini-2.0-flash-thinking-exp-1219', name: 'Gemini 2.0 Flash Thinking (Deep)' },
    { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro (Robust)' },
  ];

  const navItems = [
    { id: AppStep.SEARCH, label: language === 'ko' ? '공고 검색' : 'Search Grants', icon: Search },
    { id: AppStep.UPLOAD, label: language === 'ko' ? '공고 업로드' : 'Upload Grant', icon: Upload },
    { id: AppStep.PROFILE, label: language === 'ko' ? '회사 프로필' : 'Company Profile', icon: User },
  ];

  const isNavActive = (step: AppStep) => {
    if (step === AppStep.SEARCH && currentStep === AppStep.SEARCH) return true;
    if (step === AppStep.UPLOAD && (currentStep === AppStep.UPLOAD || currentStep === AppStep.ANALYZING || currentStep === AppStep.RESULTS)) return true;
    if (step === AppStep.PROFILE && currentStep === AppStep.PROFILE) return true;
    return false;
  };

  return (
    <nav className="bg-white border-b border-slate-200 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center gap-6">
            <div className="flex-shrink-0 flex items-center gap-2 cursor-pointer" onClick={() => onNavigate(AppStep.SEARCH)}>
              <div className="bg-indigo-600 p-1.5 rounded-lg">
                <Target className="h-6 w-6 text-white" />
              </div>
              <span className="font-bold text-xl text-slate-900 tracking-tight hidden sm:block">Padiem Grant AI</span>
              <span className="font-bold text-xl text-slate-900 tracking-tight sm:hidden">Padiem</span>
            </div>

            {/* Desktop Nav */}
            <div className="hidden md:flex items-center space-x-1">
              {navItems.map((item) => (
                <button
                  key={item.id}
                  onClick={() => onNavigate(item.id)}
                  className={`flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                    isNavActive(item.id)
                      ? 'bg-indigo-50 text-indigo-700'
                      : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                  }`}
                >
                  <item.icon className="h-4 w-4" />
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          <div className="flex items-center gap-2 sm:gap-4">
            
            {/* Model Selector */}
            <div className="relative hidden sm:block">
              <button 
                onClick={toggleSettings}
                className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-medium bg-slate-50 text-slate-600 hover:bg-slate-100 border border-slate-200 transition-colors"
              >
                <Settings className="h-3.5 w-3.5" />
                <span className="hidden lg:inline">Model</span>
                <ChevronDown className="h-3 w-3" />
              </button>
              
              {isSettingsOpen && (
                <>
                  <div className="fixed inset-0 z-10" onClick={() => setIsSettingsOpen(false)}></div>
                  <div className="absolute right-0 mt-2 w-56 bg-white rounded-lg shadow-lg border border-slate-100 z-20 py-1">
                    <div className="px-3 py-2 text-xs font-semibold text-slate-400 uppercase tracking-wider">
                      Select AI Model
                    </div>
                    {models.map((model) => (
                      <button
                        key={model.id}
                        onClick={() => {
                          onModelChange(model.id);
                          setIsSettingsOpen(false);
                        }}
                        className={`w-full text-left px-4 py-2 text-sm ${
                          selectedModel === model.id 
                            ? 'bg-indigo-50 text-indigo-700 font-medium' 
                            : 'text-slate-700 hover:bg-slate-50'
                        }`}
                      >
                        {model.name}
                      </button>
                    ))}
                  </div>
                </>
              )}
            </div>

            {/* Language Toggle */}
            <div className="flex bg-slate-100 rounded-lg p-1">
              <button
                onClick={() => onLanguageChange('ko')}
                className={`px-2 sm:px-3 py-1 text-xs font-semibold rounded-md transition-all ${
                  language === 'ko' 
                    ? 'bg-white text-indigo-600 shadow-sm' 
                    : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                한글
              </button>
              <button
                onClick={() => onLanguageChange('en')}
                className={`px-2 sm:px-3 py-1 text-xs font-semibold rounded-md transition-all ${
                  language === 'en' 
                    ? 'bg-white text-indigo-600 shadow-sm' 
                    : 'text-slate-500 hover:text-slate-700'
                }`}
              >
                Eng
              </button>
            </div>

            {/* Mobile Menu Button */}
            <div className="md:hidden">
              <button onClick={toggleMobileMenu} className="p-2 text-slate-600">
                {isMobileMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Menu */}
      {isMobileMenuOpen && (
        <div className="md:hidden bg-white border-t border-slate-200">
          <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
             {navItems.map((item) => (
                <button
                  key={item.id}
                  onClick={() => {
                    onNavigate(item.id);
                    setIsMobileMenuOpen(false);
                  }}
                  className={`flex w-full items-center gap-2 px-3 py-3 rounded-lg text-base font-medium ${
                    isNavActive(item.id)
                      ? 'bg-indigo-50 text-indigo-700'
                      : 'text-slate-600 hover:bg-slate-50'
                  }`}
                >
                  <item.icon className="h-5 w-5" />
                  {item.label}
                </button>
              ))}
              <div className="border-t border-slate-100 mt-2 pt-2">
                 <div className="px-3 py-2 text-xs font-semibold text-slate-400 uppercase">Model</div>
                 {models.map((model) => (
                    <button
                      key={model.id}
                      onClick={() => {
                        onModelChange(model.id);
                        setIsMobileMenuOpen(false);
                      }}
                      className={`flex w-full items-center px-3 py-2 text-sm ${
                        selectedModel === model.id ? 'text-indigo-600 font-medium' : 'text-slate-600'
                      }`}
                    >
                      {model.name}
                    </button>
                 ))}
              </div>
          </div>
        </div>
      )}
    </nav>
  );
};

export default Navbar;