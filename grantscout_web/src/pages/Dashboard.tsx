import { useState, useEffect } from 'react';
import { TrendingUp, CheckCircle, ArrowRight } from 'lucide-react';
import { collection, query, where, orderBy, limit, getDocs, Timestamp } from 'firebase/firestore';
import { db } from '../lib/firebase';

interface Grant {
    id: string;
    analysisResult?: {
        사업명?: string;
        지원규모_금액?: string;
        신청자격_상세?: string; // or 지원대상_요약
        신청기간_종료일?: string;
    };
    deadlineTimestamp?: Timestamp;
}

export default function Dashboard() {
    const [closingSoon, setClosingSoon] = useState<Grant[]>([]);
    const [newest, setNewest] = useState<Grant[]>([]);
    const [loading, setLoading] = useState(true);
    const [viewMode, setViewMode] = useState<'closing-soon' | 'newest'>('closing-soon');

    useEffect(() => {
        const fetchGrants = async () => {
            try {
                const now = Timestamp.now();

                // Closing Soon Query
                const closingQuery = query(
                    collection(db, 'uploaded_files'),
                    where('deadlineTimestamp', '>', now),
                    orderBy('deadlineTimestamp', 'asc'),
                    limit(10)
                );

                // Newest Query
                const newestQuery = query(
                    collection(db, 'uploaded_files'),
                    orderBy('analyzedAt', 'desc'),
                    limit(10)
                );

                const [closingSnapshot, newestSnapshot] = await Promise.all([
                    getDocs(closingQuery),
                    getDocs(newestQuery)
                ]);

                const closingGrants = closingSnapshot.docs.map(doc => ({
                    id: doc.id,
                    ...doc.data()
                } as Grant));

                const newestGrants = newestSnapshot.docs.map(doc => ({
                    id: doc.id,
                    ...doc.data()
                } as Grant));

                setClosingSoon(closingGrants);
                setNewest(newestGrants);
            } catch (error) {
                console.error("Error fetching grants:", error);
            } finally {
                setLoading(false);
            }
        };

        fetchGrants();
    }, []);

    const calculateDday = (timestamp?: Timestamp) => {
        if (!timestamp) return '';
        const now = new Date();
        const deadline = timestamp.toDate();
        const diffTime = deadline.getTime() - now.getTime();
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays === 0 ? 'D-Day' : `D-${diffDays}`;
    };

    const currentGrants = viewMode === 'closing-soon' ? closingSoon : newest;

    return (
        <div className="h-full flex flex-col gap-6 p-4">
            <div className="flex items-center justify-between mb-2">
                <h2 className="text-2xl font-bold text-slate-900">공고 리스트</h2>
                <span className="text-sm text-slate-500">
                    {viewMode === 'closing-soon' ? '마감 임박 공고' : '최신 등록 공고'} {currentGrants.length}건
                </span>
            </div>

            <div className="grid grid-cols-2 gap-4 h-64">
                <button
                    onClick={() => setViewMode('newest')}
                    className={`relative group overflow-hidden rounded-3xl bg-white border shadow-xl p-6 flex flex-col justify-between hover:scale-[1.02] transition-all duration-300 cursor-pointer z-10 ${viewMode === 'newest' ? 'border-blue-200 ring-2 ring-blue-100' : 'border-white/40 shadow-slate-200/50'}`}
                >
                    <div className="absolute inset-0 bg-gradient-to-br from-blue-50/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none" />
                    <div className="relative z-10 text-left pointer-events-none">
                        <div className="w-12 h-12 bg-blue-100 rounded-2xl flex items-center justify-center text-blue-600 mb-4 shadow-inner">
                            <TrendingUp size={24} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-900 leading-tight">최신 공고<br />확인하기</h3>
                    </div>
                    <div className="relative z-10 flex items-center gap-2 text-sm font-medium text-slate-500 group-hover:text-blue-600 transition-colors pointer-events-none">
                        <span>전체 보기</span>
                        <ArrowRight size={16} />
                    </div>
                </button>

                <button
                    onClick={() => setViewMode('closing-soon')}
                    className={`relative group overflow-hidden rounded-3xl bg-white border shadow-xl p-6 flex flex-col justify-between hover:scale-[1.02] transition-all duration-300 cursor-pointer z-10 ${viewMode === 'closing-soon' ? 'border-purple-200 ring-2 ring-purple-100' : 'border-white/40 shadow-slate-200/50'}`}
                >
                    <div className="absolute inset-0 bg-gradient-to-br from-purple-50/50 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none" />
                    <div className="relative z-10 text-left pointer-events-none">
                        <div className="w-12 h-12 bg-purple-100 rounded-2xl flex items-center justify-center text-purple-600 mb-4 shadow-inner">
                            <CheckCircle size={24} />
                        </div>
                        <h3 className="text-lg font-bold text-slate-900 leading-tight">마감 임박<br />공고 보기</h3>
                    </div>
                    <div className="relative z-10 flex items-center gap-2 text-sm font-medium text-slate-500 group-hover:text-purple-600 transition-colors pointer-events-none">
                        <span>목록 보기</span>
                        <ArrowRight size={16} />
                    </div>
                </button>
            </div>

            {/* List */}
            <div className="flex-1 bg-white/60 backdrop-blur-md rounded-3xl border border-white/40 shadow-lg p-6 overflow-hidden flex flex-col">
                <h3 className="font-bold text-slate-800 mb-4 flex items-center gap-2">
                    {viewMode === 'closing-soon' ? (
                        <>
                            <CheckCircle size={18} className="text-green-500" />
                            마감 임박 공고
                        </>
                    ) : (
                        <>
                            <TrendingUp size={18} className="text-blue-500" />
                            최신 등록 공고
                        </>
                    )}
                </h3>
                <div className="flex-1 overflow-y-auto space-y-3 pr-2 scrollbar-thin scrollbar-thumb-slate-200">
                    {loading ? (
                        <p className="text-center text-slate-500 py-4">공고를 불러오는 중...</p>
                    ) : currentGrants.length === 0 ? (
                        <p className="text-center text-slate-500 py-4">
                            {viewMode === 'closing-soon' ? '마감 임박 공고가 없습니다.' : '등록된 공고가 없습니다.'}
                        </p>
                    ) : (
                        currentGrants.map((grant) => (
                            <div key={grant.id} className="p-4 bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-all cursor-pointer group">
                                <div className="flex justify-between items-start mb-2">
                                    <span className={`px-2 py-1 text-[10px] font-bold rounded-lg ${grant.deadlineTimestamp && calculateDday(grant.deadlineTimestamp) === 'D-Day'
                                        ? 'bg-red-100 text-red-600'
                                        : 'bg-slate-100 text-slate-600'
                                        }`}>
                                        {calculateDday(grant.deadlineTimestamp) || '상시'}
                                    </span>
                                    <span className="text-xs text-slate-400">
                                        {grant.analysisResult?.신청기간_종료일 || '상시/미정'} 마감
                                    </span>
                                </div>
                                <h4 className="font-bold text-slate-900 text-sm mb-1 line-clamp-2 group-hover:text-primary-600 transition-colors">
                                    {grant.analysisResult?.사업명 || '제목 없음'}
                                </h4>
                                <div className="flex gap-2 text-xs text-slate-500 mt-2">
                                    <span className="bg-slate-50 px-2 py-1 rounded-md border border-slate-100">
                                        {grant.analysisResult?.지원규모_금액 || '금액 미정'}
                                    </span>
                                </div>
                            </div>
                        ))
                    )}
                </div>
            </div>
        </div>
    );
}
