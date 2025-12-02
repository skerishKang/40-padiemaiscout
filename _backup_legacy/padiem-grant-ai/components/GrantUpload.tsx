import React, { useState } from 'react';
import { Upload, FileType, X, ArrowRight, ArrowLeft, Image as ImageIcon } from 'lucide-react';
import { Language } from '../types';

interface Props {
  onFileSelect: (file: File) => void;
  onBack: () => void;
  isAnalyzing: boolean;
  language: Language;
}

const GrantUpload: React.FC<Props> = ({ onFileSelect, onBack, isAnalyzing, language }) => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);

  const t = {
    title: language === 'ko' ? '공고 문서 업로드' : 'Upload Grant Document',
    subtitle: language === 'ko' 
      ? '공고문(PDF, 이미지)을 업로드하면 핵심 정보를 자동으로 추출합니다.' 
      : 'Upload the official announcement (PDF, Image) to extract key data.',
    dropText: language === 'ko' ? '클릭 또는 파일 드래그 (PDF, JPG, PNG)' : 'Click to upload or drag & drop (PDF, JPG, PNG)',
    limitText: language === 'ko' ? 'HWP/Word 파일은 PDF나 이미지로 변환하여 올려주세요. (최대 20MB)' : 'Please convert HWP/Word to PDF or Image. Max size 20MB.',
    analyzing: language === 'ko' ? 'Padiem AI 분석 중...' : 'Padiem AI Analyzing...',
    analyzeBtn: language === 'ko' ? '공고 분석 시작' : 'Analyze Grant',
    backBtn: language === 'ko' ? '회사 정보 수정' : 'Back to Profile',
    errType: language === 'ko' ? 'PDF 또는 이미지 파일(JPG, PNG)만 가능합니다.' : 'Only PDF or Image files (JPG, PNG) are supported.',
    errSize: language === 'ko' ? '파일 크기는 20MB를 초과할 수 없습니다.' : 'File size too large. Max 20MB.',
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setError(null);
    if (event.target.files && event.target.files[0]) {
      const file = event.target.files[0];
      validateAndSetFile(file);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setError(null);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
       const file = e.dataTransfer.files[0];
       validateAndSetFile(file);
    }
  };

  const validateAndSetFile = (file: File) => {
    const validTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp'];
    if (!validTypes.includes(file.type)) {
      setError(t.errType);
      return;
    }
    if (file.size > 20 * 1024 * 1024) { 
      setError(t.errSize);
      return;
    }
    setSelectedFile(file);
  }

  const handleAnalyze = () => {
    if (selectedFile) {
      onFileSelect(selectedFile);
    }
  };

  return (
    <div className="max-w-2xl mx-auto w-full">
      <div className="bg-white shadow-xl rounded-2xl overflow-hidden border border-slate-100">
         <div className="px-8 py-6 bg-white border-b border-slate-100">
          <h2 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <Upload className="h-6 w-6 text-indigo-600" />
            {t.title}
          </h2>
          <p className="text-slate-500 mt-1">
            {t.subtitle}
          </p>
        </div>

        <div className="p-8">
          {!selectedFile ? (
            <div 
              className="border-2 border-dashed border-slate-300 rounded-xl p-12 text-center bg-slate-50 hover:bg-slate-100 transition-colors cursor-pointer relative"
              onDragOver={(e) => e.preventDefault()}
              onDrop={handleDrop}
            >
              <input 
                type="file" 
                accept="application/pdf,image/jpeg,image/png,image/webp"
                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                onChange={handleFileChange}
              />
              <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-indigo-100 text-indigo-600 mb-4">
                <Upload className="h-8 w-8" />
              </div>
              <h3 className="text-lg font-medium text-slate-900 mb-2">{t.dropText}</h3>
              <p className="text-sm text-slate-500">
                {t.limitText}
              </p>
            </div>
          ) : (
             <div className="bg-indigo-50 border border-indigo-100 rounded-xl p-6 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="bg-white p-3 rounded-lg shadow-sm">
                    {selectedFile.type.startsWith('image/') ? (
                      <ImageIcon className="h-8 w-8 text-indigo-600" />
                    ) : (
                      <FileType className="h-8 w-8 text-indigo-600" />
                    )}
                  </div>
                  <div>
                    <h4 className="font-medium text-indigo-900 truncate max-w-[200px] sm:max-w-xs">{selectedFile.name}</h4>
                    <p className="text-sm text-indigo-600">{(selectedFile.size / 1024 / 1024).toFixed(2)} MB</p>
                  </div>
                </div>
                <button 
                  onClick={() => setSelectedFile(null)}
                  className="p-2 hover:bg-indigo-200 rounded-full transition-colors text-indigo-600"
                >
                  <X className="h-5 w-5" />
                </button>
             </div>
          )}

          {error && (
            <div className="mt-4 p-4 bg-red-50 text-red-700 rounded-lg text-sm border border-red-200 flex items-center gap-2">
              <X className="h-4 w-4" /> {error}
            </div>
          )}

          <div className="flex justify-between items-center mt-8">
             <button
              onClick={onBack}
              className="flex items-center gap-2 px-6 py-2.5 rounded-lg text-sm font-medium text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
            >
              <ArrowLeft className="h-4 w-4" /> {t.backBtn}
            </button>
            <button
              onClick={handleAnalyze}
              disabled={!selectedFile || isAnalyzing}
              className={`flex items-center justify-center gap-2 px-8 py-3 rounded-lg text-sm font-bold text-white transition-all transform 
                ${!selectedFile || isAnalyzing 
                  ? 'bg-slate-300 cursor-not-allowed' 
                  : 'bg-indigo-600 hover:bg-indigo-700 shadow-lg shadow-indigo-200 hover:scale-[1.02]'
                }`}
            >
              {isAnalyzing ? (
                <>
                  <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  {t.analyzing}
                </>
              ) : (
                <>
                  {t.analyzeBtn}
                  <ArrowRight className="h-4 w-4" />
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default GrantUpload;