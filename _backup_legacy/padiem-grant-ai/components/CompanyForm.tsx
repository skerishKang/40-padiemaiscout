import React, { useState } from 'react';
import { CompanyProfile, Language } from '../types';
import { Building2, MapPin, Users, DollarSign, Briefcase, FileText, ArrowRight, SkipForward } from 'lucide-react';

interface Props {
  initialData: CompanyProfile;
  onSubmit: (data: CompanyProfile) => void;
  language: Language;
}

const CompanyForm: React.FC<Props> = ({ initialData, onSubmit, language }) => {
  const [formData, setFormData] = useState<CompanyProfile>(initialData);

  const t = {
    title: language === 'ko' ? '회사 정보' : 'Company Profile',
    subtitle: language === 'ko' 
      ? '지원사업 적합성 분석을 위해 회사 정보를 입력해주세요.' 
      : 'Tell us about your organization so AI can assess grant suitability.',
    name: language === 'ko' ? '회사명' : 'Company Name',
    industry: language === 'ko' ? '업종' : 'Industry',
    location: language === 'ko' ? '소재지' : 'Location (HQ)',
    employees: language === 'ko' ? '직원 수' : 'Number of Employees',
    revenue: language === 'ko' ? '연 매출 (대략)' : 'Annual Revenue (Approx.)',
    description: language === 'ko' ? '사업 내용' : 'Business Description',
    demoBtn: language === 'ko' ? '예시 데이터 채우기' : 'Fill Demo Data',
    nextBtn: language === 'ko' ? '다음: 공고 업로드' : 'Next: Upload Grant',
    skipBtn: language === 'ko' ? '건너뛰기 (나중에 입력)' : 'Skip for Now',
    ph: {
      name: language === 'ko' ? '예: (주)테크노바' : 'e.g. Acme Corp',
      industry: language === 'ko' ? '예: 소프트웨어 개발, 제조' : 'e.g. Manufacturing, Software',
      location: language === 'ko' ? '예: 서울 강남구' : 'e.g. Seoul, Gangnam-gu',
      revenue: language === 'ko' ? '예: 10억 ~ 50억' : 'e.g. $1M - $5M',
      desc: language === 'ko' ? '회사의 주력 사업과 기술에 대해 간단히 설명해주세요...' : 'Briefly describe what your company does...',
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'employees' ? parseInt(value) || 0 : value
    }));
  };

  const handleDemoFill = () => {
    if (language === 'ko') {
      setFormData({
        name: "주식회사 테크노바",
        industry: "AI 소프트웨어 & SaaS",
        employees: 25,
        revenue: "10억 - 50억 원",
        location: "서울시 강남구",
        description: "물류 최적화를 위한 AI 기반 라스트마일 배송 솔루션을 개발하고 운영합니다."
      });
    } else {
      setFormData({
        name: "TechNova Solutions",
        industry: "SaaS & AI Software",
        employees: 25,
        revenue: "500M - 1B KRW",
        location: "Seoul, South Korea",
        description: "We develop AI-driven automation tools for small logistics companies to optimize last-mile delivery routes."
      });
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  const handleSkip = () => {
    onSubmit({
      name: '',
      industry: '',
      employees: 0,
      revenue: '',
      location: '',
      description: ''
    });
  };

  return (
    <div className="max-w-3xl mx-auto w-full">
      <div className="bg-white shadow-xl rounded-2xl overflow-hidden border border-slate-100">
        <div className="px-8 py-6 bg-indigo-600">
          <h2 className="text-2xl font-bold text-white flex items-center gap-2">
            <Building2 className="h-6 w-6" />
            {t.title}
          </h2>
          <p className="text-indigo-100 mt-1">
            {t.subtitle}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="p-8 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-2">
              <label className="text-sm font-semibold text-slate-700 flex items-center gap-2">
                <Briefcase className="h-4 w-4 text-slate-400" /> {t.name}
              </label>
              <input
                type="text"
                name="name"
                required
                value={formData.name}
                onChange={handleChange}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors"
                placeholder={t.ph.name}
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-semibold text-slate-700 flex items-center gap-2">
                <Building2 className="h-4 w-4 text-slate-400" /> {t.industry}
              </label>
              <input
                type="text"
                name="industry"
                required
                value={formData.industry}
                onChange={handleChange}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors"
                placeholder={t.ph.industry}
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-semibold text-slate-700 flex items-center gap-2">
                <MapPin className="h-4 w-4 text-slate-400" /> {t.location}
              </label>
              <input
                type="text"
                name="location"
                required
                value={formData.location}
                onChange={handleChange}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors"
                placeholder={t.ph.location}
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm font-semibold text-slate-700 flex items-center gap-2">
                <Users className="h-4 w-4 text-slate-400" /> {t.employees}
              </label>
              <input
                type="number"
                name="employees"
                min="0"
                required
                value={formData.employees}
                onChange={handleChange}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors"
              />
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-semibold text-slate-700 flex items-center gap-2">
                <DollarSign className="h-4 w-4 text-slate-400" /> {t.revenue}
              </label>
              <input
                type="text"
                name="revenue"
                required
                value={formData.revenue}
                onChange={handleChange}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors"
                placeholder={t.ph.revenue}
              />
            </div>

            <div className="space-y-2 md:col-span-2">
              <label className="text-sm font-semibold text-slate-700 flex items-center gap-2">
                <FileText className="h-4 w-4 text-slate-400" /> {t.description}
              </label>
              <textarea
                name="description"
                required
                rows={3}
                value={formData.description}
                onChange={handleChange}
                className="w-full px-4 py-2 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition-colors"
                placeholder={t.ph.desc}
              />
            </div>
          </div>

          <div className="flex flex-col-reverse sm:flex-row gap-4 pt-4 border-t border-slate-100">
             <button
              type="button"
              onClick={handleSkip}
              className="flex items-center justify-center gap-2 px-6 py-2.5 rounded-lg text-sm font-medium text-slate-500 hover:text-slate-700 hover:bg-slate-100 transition-colors"
            >
              <SkipForward className="h-4 w-4" />
              {t.skipBtn}
            </button>
             <button
              type="button"
              onClick={handleDemoFill}
              className="px-6 py-2.5 rounded-lg text-sm font-medium text-indigo-600 bg-indigo-50 hover:bg-indigo-100 transition-colors"
            >
              {t.demoBtn}
            </button>
            <button
              type="submit"
              className="flex-1 flex items-center justify-center gap-2 px-6 py-2.5 rounded-lg text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 shadow-md shadow-indigo-200 transition-all hover:scale-[1.02]"
            >
              {t.nextBtn}
              <ArrowRight className="h-4 w-4" />
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CompanyForm;