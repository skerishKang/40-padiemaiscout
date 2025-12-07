import { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { Filter } from 'lucide-react';
import { collection, query, where, orderBy, limit, getDocs, Timestamp, doc, getDoc } from 'firebase/firestore';
import { db, auth, functions } from '../lib/firebase';
import { httpsCallable } from 'firebase/functions';
import { onAuthStateChanged, type User } from 'firebase/auth';
import RecommendationCard from '../components/RecommendationCard';

interface Grant {
    id: string;
    analysisResult?: {
        사업명?: string;
        지원규모_금액?: string;
        신청자격_상세?: string;
        신청기간_종료일?: string;
        소관부처_지자체?: string;
    };
    deadlineTimestamp?: Timestamp;
    analyzedAt?: Timestamp;
    source?: 'bizinfo' | 'k-startup' | 'user-upload'; // Added source field
    title?: string;
    department?: string;
    period?: string;
    link?: string;
    createdAt?: Timestamp;
    // For recommendation logic
    matchReason?: string[];
}

export default function Dashboard() {
    const location = useLocation();
    const [user, setUser] = useState<User | null>(null);
    const [userProfile, setUserProfile] = useState<any>(null);
    const [allGrants, setAllGrants] = useState<Grant[]>([]);
    const [recommendedGrants, setRecommendedGrants] = useState<Grant[]>([]);
    const [loading, setLoading] = useState(true);
    const [viewMode, setViewMode] = useState<'closing-soon' | 'newest'>('newest');
    const [sourceFilter, setSourceFilter] = useState<'all' | 'bizinfo' | 'k-startup' | 'user-upload'>('all');

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
            setUser(currentUser);
            if (currentUser) {
                // Fetch Profile
                try {
                    const docRef = doc(db, 'users', currentUser.uid);
                    const docSnap = await getDoc(docRef);
                    if (docSnap.exists()) {
                        setUserProfile(docSnap.data());
                    }
                } catch (error) {
                    console.error("Error fetching profile:", error);
                }
            }
        });
        return () => unsubscribe();
    }, []);

    useEffect(() => {
        const fetchGrants = async () => {
            try {
                const now = Timestamp.now();

                // Fetch active grants (deadline > now) from 'grants' collection
                const grantsQuery = query(
                    collection(db, 'grants'), // Changed from 'uploaded_files'
                    where('deadlineTimestamp', '>', now),
                    orderBy('deadlineTimestamp', 'asc'),
                    limit(50)
                );

                const snapshot = await getDocs(grantsQuery);
                const grants = snapshot.docs.map(doc => ({
                    id: doc.id,
                    ...doc.data()
                } as Grant));

                setAllGrants(grants);

            } catch (error) {
                console.error("Error fetching grants:", error);
            } finally {
                setLoading(false);
            }
        };

        fetchGrants();
    }, []);

    // URL 쿼리 파라미터(source)를 기반으로 초기 sourceFilter 설정
    useEffect(() => {
        const params = new URLSearchParams(location.search);
        const sourceParam = params.get('source');
        if (sourceParam === 'all' || sourceParam === 'bizinfo' || sourceParam === 'k-startup' || sourceParam === 'user-upload') {
            setSourceFilter(sourceParam as 'all' | 'bizinfo' | 'k-startup' | 'user-upload');
        }
    }, [location.search]);

    // Pro 유저를 위한 실제 추천 로직 (Gemini checkSuitability 사용)
    useEffect(() => {
        const runRealRecommendation = async () => {
            if (!user || !userProfile) return;
            const role = userProfile?.role;
            // Pro 이상에게만 실제 추천 로직 적용
            if (role !== 'pro' && role !== 'premium') return;
            if (allGrants.length === 0) return;

            try {
                const buildFallbackRecommendations = (): Grant[] => {
                    const base = allGrants.slice(0, 3);
                    return base.map(grant => ({
                        ...grant,
                        matchReason: grant.matchReason && grant.matchReason.length > 0
                            ? grant.matchReason
                            : ['아직 상세 적합도 점수는 없지만, 마감이 임박한 순으로 추천하는 공고입니다.'],
                    }));
                };

                const checkSuitabilityFn = httpsCallable(functions, 'checkSuitability');
                // 분석 결과가 있는 공고 중 일부만 대상으로 적합도 계산 (과도한 호출 방지)
                const candidates = allGrants
                    .filter(g => g.analysisResult)
                    .slice(0, 10);
                if (candidates.length === 0) {
                    setRecommendedGrants(buildFallbackRecommendations());
                    return;
                }

                const scored: { grant: Grant; score: number; reason?: string }[] = [];
                for (const grant of candidates) {
                    try {
                        const res: any = await checkSuitabilityFn({
                            userProfile,
                            analysisResult: grant.analysisResult,
                        });
                        const data = res.data;
                        if (data && data.status === 'ok' && data.suitability && typeof data.suitability.score === 'number') {
                            scored.push({ grant, score: data.suitability.score, reason: data.suitability.reason });
                        }
                    } catch (e) {
                        // 개별 공고 실패는 무시하고 다음으로 진행
                        console.error('checkSuitability failed for grant', grant.id, e);
                    }
                }

                if (scored.length === 0) {
                    setRecommendedGrants(buildFallbackRecommendations());
                    return;
                }

                scored.sort((a, b) => b.score - a.score);
                const top3 = scored.slice(0, 3).map(item => {
                    const { grant, reason } = item;
                    // reason을 간단한 bullet 형태로 분리
                    const reasons = reason
                        ? reason
                            .split(/[\n\r]+/)
                            .map(s => s.trim())
                            .filter(s => s.length > 0)
                        : ['이 공고는 회원님의 조건과 잘 맞는 것으로 판단됩니다.'];
                    return {
                        ...grant,
                        matchReason: reasons.slice(0, 3),
                    };
                });

                setRecommendedGrants(top3);
            } catch (e) {
                console.error('runRealRecommendation failed', e);
            }
        };

        runRealRecommendation();
    }, [user, userProfile, allGrants]);

    const calculateDday = (timestamp?: Timestamp) => {
        if (!timestamp) return '';
        const now = new Date();
        const deadline = timestamp.toDate();
        const diffTime = deadline.getTime() - now.getTime();
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays === 0 ? 'D-Day' : `D-${diffDays}`;
    };

    const getSourceBadge = (source?: string) => {
        switch (source) {
            case 'bizinfo':
                return <span className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-blue-100 text-blue-600">기업마당</span>;
            case 'k-startup':
                return <span className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-indigo-100 text-indigo-600">K-Startup</span>;
            case 'user-upload':
                return <span className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-green-100 text-green-600">PDF 업로드</span>;
            default:
                return <span className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-slate-100 text-slate-500">기타</span>;
        }
    };

    const getGrantTitle = (grant: Grant) => {
        return grant.analysisResult?.사업명 || grant.title || '제목 없음';
    };

    const getGrantDepartment = (grant: Grant) => {
        return grant.analysisResult?.소관부처_지자체 || grant.department || '소관부처 미정';
    };

    const getGrantEndDateLabel = (grant: Grant) => {
        if (grant.analysisResult?.신청기간_종료일) {
            return grant.analysisResult.신청기간_종료일;
        }
        if (grant.period) {
            return grant.period;
        }
        return '상시';
    };

    const handleGrantClick = (grant: Grant) => {
        if (grant.link) {
            window.open(grant.link, '_blank', 'noopener,noreferrer');
            return;
        }
        alert(`공고 클릭: ${getGrantTitle(grant)}`);
    };

    // Check if profile is complete (Basic check)
    const isProfileComplete = userProfile?.industry && userProfile?.location;
    const userRole = userProfile?.role;
    const isProOrPremium = userRole === 'pro' || userRole === 'premium';

    // Filter Logic
    const filteredGrants = [...allGrants]
        .filter(grant => {
            if (sourceFilter === 'all') return true;
            return grant.source === sourceFilter;
        })
        .sort((a, b) => {
            if (viewMode === 'newest') {
                // Sort by analyzedAt (desc)
                const aTime = a.analyzedAt?.toMillis() || a.createdAt?.toMillis() || 0;
                const bTime = b.analyzedAt?.toMillis() || b.createdAt?.toMillis() || 0;
                return bTime - aTime;
            } else {
                // Sort by deadline (asc)
                return (a.deadlineTimestamp?.toMillis() || 0) - (b.deadlineTimestamp?.toMillis() || 0);
            }
        });

    return (
        <div className="h-full flex flex-col gap-6 p-4 max-w-5xl mx-auto w-full">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-2xl font-bold text-slate-900">
                        {user?.displayName ? `${user.displayName}님,` : '사장님,'}
                    </h1>
                    <p className="text-slate-500">오늘의 맞춤 공고를 확인해보세요.</p>
                </div>
            </div>

            {/* Profile Setup CTA (Visible only if profile is incomplete) */}
            {!loading && user && !isProfileComplete && (
                <div className="bg-blue-50 border border-blue-100 rounded-2xl p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 animate-in fade-in slide-in-from-top-4 duration-500">
                    <div>
                        <h3 className="text-lg font-bold text-blue-900 mb-1">
                            🏢 우리 기업 정보를 입력해주세요!
                        </h3>
                        <p className="text-blue-700 text-sm">
                            업종, 지역, 업력을 입력하면 <strong>딱 맞는 지원사업</strong>을 추천해드립니다.
                        </p>
                    </div>
                    <a
                        href="/profile"
                        className="px-5 py-2.5 bg-blue-600 text-white font-bold rounded-xl hover:bg-blue-700 transition-colors shadow-sm whitespace-nowrap"
                    >
                        프로필 설정하기
                    </a>
                </div>
            )}

            {/* Section 1: Recommended Grants (Slide) */}
            <section>
                <div className="flex items-center gap-2 mb-2">
                    <span className="text-lg font-bold text-slate-900">오늘의 추천 3</span>
                    <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-bold rounded-full">AI Pick</span>
                </div>
                <p className="text-xs text-slate-400 mb-4">
                    Pro / 프리미엄 회원에게는 기업 프로필과 Gemini 분석을 기반으로 한 맞춤 추천을 제공합니다.
                </p>

                <div className="flex gap-4 overflow-x-auto pb-4 snap-x snap-mandatory scrollbar-hide">
                    {loading ? (
                        [1, 2, 3].map(i => (
                            <div key={i} className="min-w-[300px] h-[200px] bg-slate-100 rounded-2xl animate-pulse" />
                        ))
                    ) : recommendedGrants.length > 0 ? (
                        recommendedGrants.map(grant => (
                            <RecommendationCard
                                key={grant.id}
                                grant={{
                                    id: grant.id,
                                    title: getGrantTitle(grant),
                                    department: getGrantDepartment(grant),
                                    endDate: getGrantEndDateLabel(grant),
                                    views: 0,
                                    matchReason: grant.matchReason
                                }}
                                onClick={() => handleGrantClick(grant)}
                            />
                        ))
                    ) : (!user || !isProOrPremium) ? (
                        <div className="w-full min-w-[300px] h-[200px] flex flex-col items-center justify-center bg-slate-50 rounded-2xl border border-dashed border-slate-300 text-slate-500 p-6 text-center">
                            <p className="font-medium mb-1">AI 맞춤 추천은 Pro / 프리미엄 전용 기능입니다.</p>
                            <p className="text-sm text-slate-400 mb-3">
                                기업 프로필을 설정하고 Pro로 업그레이드하면 우리 회사에 딱 맞는 지원사업을 추천해드립니다.
                            </p>
                            <a
                                href="/pricing"
                                className="inline-flex items-center justify-center px-4 py-2 text-xs font-bold rounded-xl bg-slate-900 text-white hover:bg-slate-800 transition-colors"
                            >
                                Pro 혜택 확인하기
                            </a>
                        </div>
                    ) : (
                        <div className="w-full min-w-[300px] h-[200px] flex flex-col items-center justify-center bg-slate-50 rounded-2xl border border-dashed border-slate-300 text-slate-500 p-6 text-center">
                            <p className="font-medium mb-1">아직 추천할 공고가 없습니다.</p>
                            <p className="text-sm text-slate-400">
                                Admin에서 상세 분석(프리미엄)을 실행해 분석된 공고를 늘리면 더 정확한 추천을 받을 수 있습니다.
                            </p>
                        </div>
                    )}
                </div>
            </section>

            {/* Section 2: Exploration List */}
            <section className="flex-1 flex flex-col min-h-0">
                <div className="flex items-center justify-between mb-4">
                    <div className="flex gap-2 bg-slate-100 p-1 rounded-lg">
                        <button
                            onClick={() => setViewMode('newest')}
                            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-all ${viewMode === 'newest' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'
                                }`}
                        >
                            최신순
                        </button>
                        <button
                            onClick={() => setViewMode('closing-soon')}
                            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-all ${viewMode === 'closing-soon' ? 'bg-white text-purple-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'
                                }`}
                        >
                            마감임박
                        </button>
                    </div>

                    <div className="flex gap-3 items-center">
                        <div className="flex gap-1 bg-slate-50 p-1 rounded-lg">
                            <button
                                onClick={() => setSourceFilter('all')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all ${sourceFilter === 'all' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
                            >
                                전체
                            </button>
                            <button
                                onClick={() => setSourceFilter('bizinfo')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all ${sourceFilter === 'bizinfo' ? 'bg-white text-blue-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
                            >
                                기업마당
                            </button>
                            <button
                                onClick={() => setSourceFilter('k-startup')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all ${sourceFilter === 'k-startup' ? 'bg-white text-indigo-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
                            >
                                K-Startup
                            </button>
                            <button
                                onClick={() => setSourceFilter('user-upload')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all ${sourceFilter === 'user-upload' ? 'bg-white text-green-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
                            >
                                PDF 업로드
                            </button>
                        </div>
                        <button className="p-2 bg-white border border-slate-200 rounded-lg text-slate-500 hover:bg-slate-50" title="필터 옵션">
                            <Filter size={18} />
                        </button>
                    </div>
                </div>

                <div className="flex-1 bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
                    <div className="overflow-y-auto flex-1 p-2 space-y-2 scrollbar-thin scrollbar-thumb-slate-200">
                        {loading ? (
                            <p className="text-center text-slate-500 py-8">공고를 불러오는 중...</p>
                        ) : filteredGrants.length === 0 ? (
                            <p className="text-center text-slate-500 py-8">조건에 맞는 공고가 없습니다.</p>
                        ) : (
                            filteredGrants.map(grant => (
                                <div
                                    key={grant.id}
                                    className="p-4 hover:bg-slate-50 rounded-xl transition-colors cursor-pointer group border-b border-slate-50 last:border-0"
                                    onClick={() => handleGrantClick(grant)}
                                >
                                    <div className="flex justify-between items-start gap-4">
                                        <div className="flex-1">
                                            <div className="flex items-center gap-2 mb-1">
                                                {getSourceBadge(grant.source)}
                                                {grant.analysisResult && (
                                                    <span className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-purple-50 text-purple-600 border border-purple-100">
                                                        상세분석
                                                    </span>
                                                )}
                                                <span
                                                    className={`px-1.5 py-0.5 text-[10px] font-bold rounded ${
                                                        calculateDday(grant.deadlineTimestamp) === 'D-Day'
                                                            ? 'bg-red-100 text-red-600'
                                                            : 'bg-slate-100 text-slate-500'
                                                    }`}
                                                >
                                                    {calculateDday(grant.deadlineTimestamp) || '상시'}
                                                </span>
                                                <span className="text-xs text-slate-400">
                                                    {getGrantDepartment(grant)}
                                                </span>
                                            </div>
                                            <h4 className="font-bold text-slate-900 text-sm line-clamp-1 group-hover:text-blue-600 transition-colors">
                                                {getGrantTitle(grant)}
                                            </h4>
                                        </div>
                                        <div className="text-right shrink-0">
                                            <span className="text-xs font-medium text-slate-500 bg-slate-100 px-2 py-1 rounded-lg">
                                                {grant.analysisResult?.지원규모_금액 || '금액 미정'}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                </div>
            </section>
        </div>
    );
}
