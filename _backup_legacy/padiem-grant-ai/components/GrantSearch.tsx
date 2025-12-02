import React, { useState } from 'react';
import { Search, Globe, ArrowRight, Loader2, ExternalLink } from 'lucide-react';
import { Language, SearchResult } from '../types';
import { searchGrants } from '../services/gemini';

interface Props {
  language: Language;
  onSearchComplete?: (query: string) => void;
}

const GrantSearch: React.FC<Props> = ({ language, onSearchComplete }) => {
  const [query, setQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [result, setResult] = useState<SearchResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const t = {
    title: language === 'ko' ? '지원사업 실시간 검색' : 'Real-time Grant Search',
    subtitle: language === 'ko' 
      ? '찾고 싶은 지원사업 키워드를 입력하세요 (예: AI 예비창업패키지, 서울시 소상공인)' 
      : 'Enter keywords to find grants (e.g., AI startup funding, Seoul small business)',
    placeholder: language === 'ko' ? '검색어 입력...' : 'Enter keywords...',
    searchBtn: language === 'ko' ? '검색' : 'Search',
    searching: language === 'ko' ? '검색 중...' : 'Searching...',
    source: language === 'ko' ? '출처' : 'Sources',
    noResults: language === 'ko' ? '검색 결과가 없습니다.' : 'No results found.',
    tip: language === 'ko' 
      ? '팁: 찾으신 공고의 PDF를 다운로드하여 "공고 업로드" 메뉴에서 상세 분석을 받아보세요.' 
      : 'Tip: Download the PDF of the grant you find, then use the "Upload" tab for detailed analysis.',
  };

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!query.trim()) return;

    setIsSearching(true);
    setError(null);
    setResult(null);

    try {
      const searchResult = await searchGrants(query, language);
      setResult(searchResult);
      if (onSearchComplete) onSearchComplete(query);
    } catch (err) {
      setError(language === 'ko' ? '검색 중 오류가 발생했습니다.' : 'Error occurred during search.');
      console.error(err);
    } finally {
      setIsSearching(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto w-full space-y-8">
      
      {/* Search Box */}
      <div className="bg-white shadow-xl rounded-2xl overflow-hidden border border-slate-100">
        <div className="p-8 bg-indigo-600">
          <h2 className="text-2xl font-bold text-white flex items-center gap-2 mb-2">
            <Globe className="h-6 w-6" />
            {t.title}
          </h2>
          <p className="text-indigo-100 mb-6">
            {t.subtitle}
          </p>
          
          <form onSubmit={handleSearch} className="relative">
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t.placeholder}
              className="w-full pl-5 pr-32 py-4 rounded-xl border-0 shadow-lg focus:ring-2 focus:ring-indigo-300 text-lg placeholder:text-slate-400 text-slate-900"
            />
            <button
              type="submit"
              disabled={isSearching || !query.trim()}
              className="absolute right-2 top-2 bottom-2 bg-indigo-800 hover:bg-indigo-900 text-white px-6 rounded-lg font-medium transition-colors flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSearching ? <Loader2 className="h-5 w-5 animate-spin" /> : <Search className="h-5 w-5" />}
              {isSearching ? t.searching : t.searchBtn}
            </button>
          </form>
        </div>
      </div>

      {/* Results */}
      {error && (
        <div className="p-4 bg-red-50 text-red-700 rounded-xl border border-red-200 text-center">
          {error}
        </div>
      )}

      {result && (
        <div className="bg-white shadow-lg rounded-2xl border border-slate-100 overflow-hidden">
          <div className="p-6 sm:p-8">
            <h3 className="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
              <Search className="h-5 w-5 text-indigo-600" />
              Gemini Search Results
            </h3>
            
            {/* Main Text Content */}
            <div className="prose prose-indigo max-w-none text-slate-600 bg-slate-50 p-6 rounded-xl border border-slate-200">
              <div className="whitespace-pre-wrap leading-relaxed">
                {result.text}
              </div>
            </div>

            {/* Tip */}
            <div className="mt-6 flex items-start gap-3 p-4 bg-blue-50 text-blue-800 rounded-lg text-sm">
              <div className="bg-blue-100 p-1 rounded-full">
                <ArrowRight className="h-4 w-4" />
              </div>
              <p>{t.tip}</p>
            </div>

            {/* Source Links (Grounding) */}
            {result.sourceLinks.length > 0 && (
              <div className="mt-8">
                <h4 className="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3">
                  {t.source}
                </h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  {result.sourceLinks.map((link, idx) => (
                    <a 
                      key={idx}
                      href={link.uri}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-start gap-3 p-3 rounded-lg border border-slate-200 hover:border-indigo-300 hover:bg-indigo-50 transition-all group"
                    >
                      <div className="mt-1 bg-slate-100 p-1.5 rounded group-hover:bg-white transition-colors">
                        <ExternalLink className="h-4 w-4 text-slate-500 group-hover:text-indigo-600" />
                      </div>
                      <div className="overflow-hidden">
                        <p className="text-sm font-medium text-slate-900 truncate group-hover:text-indigo-700">
                          {link.title || "No Title"}
                        </p>
                        <p className="text-xs text-slate-400 truncate mt-0.5">
                          {link.uri}
                        </p>
                      </div>
                    </a>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default GrantSearch;