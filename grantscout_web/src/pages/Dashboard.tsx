import { TrendingUp, CheckCircle, ArrowRight, Sparkles } from 'lucide-react';

export default function Dashboard() {
    return (
        <div className="h-full flex flex-col gap-6 p-4">
            <div className="flex items-center justify-between mb-2">
                <h2 className="text-2xl font-bold text-slate-900">공고 리스트</h2>
                <span className="text-sm text-slate-500">오늘 업데이트된 공고 12건</span>
            </div>

            <div className="grid grid-cols-2 gap-4 h-64">
                <button className="relative group overflow-hidden rounded-3xl bg-white border border-white/40 shadow-xl shadow-slate-200/50 p-6 flex flex-col justify-between hover:scale-[1.02] transition-all duration-300">
                    <div className="absolute inset-0 bg-gradient-to-br from-blue-50/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                    <div className="relative z-10 text-left">
                        <div className="w-12 h-12 bg-blue-100 rounded-2xl flex items-center justify-center text-blue-600 mb-4 shadow-inner">
                            <TrendingUp size={24} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-900 leading-tight">최신 공고<br />확인하기</h3>
                    </div>
                    <div className="relative z-10 flex items-center gap-2 text-sm font-medium text-slate-500 group-hover:text-blue-600 transition-colors">
                        <span>전체 보기</span>
                        <ArrowRight size={16} />
                    </div>
                </button>

                <button className="relative group overflow-hidden rounded-3xl bg-white border border-white/40 shadow-xl shadow-slate-200/50 p-6 flex flex-col justify-between hover:scale-[1.02] transition-all duration-300">
                    <div className="absolute inset-0 bg-gradient-to-br from-purple-50/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity" />
                    <div className="relative z-10 text-left">
                        <div className="w-12 h-12 bg-purple-100 rounded-2xl flex items-center justify-center text-purple-600 mb-4 shadow-inner">
                            <Sparkles size={24} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-900 leading-tight">나에게 딱 맞는<br />공고 추천</h3>
                    </div>
                    <div className="relative z-10 flex items-center gap-2 text-sm font-medium text-slate-500 group-hover:text-purple-600 transition-colors">
                        <span>추천 보기</span>
                        <ArrowRight size={16} />
                    </div>
                </button>
            </div>

            {/* Recent Items List */}
            <div className="flex-1 bg-white/60 backdrop-blur-md rounded-3xl border border-white/40 shadow-lg p-6 overflow-hidden flex flex-col">
                <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2">
                    <CheckCircle size={18} className="text-green-500" />
                    마감 임박 공고
                </h3>
                <div className="flex-1 overflow-y-auto space-y-3 pr-2 scrollbar-thin scrollbar-thumb-slate-200">
                    {[1, 2, 3, 4, 5].map((i) => (
                        <div key={i} className="p-4 bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-all cursor-pointer group">
                            <div className="flex justify-between items-start mb-2">
                                <span className="px-2 py-1 bg-slate-100 text-slate-600 text-[10px] font-bold rounded-lg">D-{i * 2}</span>
                                <span className="text-xs text-slate-400">2025.04.0{i} 마감</span>
                            </div>
                            <h4 className="font-bold text-slate-900 text-sm mb-1 line-clamp-2 group-hover:text-primary-600 transition-colors">
                                2025년도 창업성장기술개발사업 디딤돌 창업과제 제{i}차 시행계획 공고
                            </h4>
                            <div className="flex gap-2 text-xs text-slate-500 mt-2">
                                <span className="bg-slate-50 px-2 py-1 rounded-md border border-slate-100">최대 1.2억</span>
                                <span className="bg-slate-50 px-2 py-1 rounded-md border border-slate-100">7년 미만</span>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
}
