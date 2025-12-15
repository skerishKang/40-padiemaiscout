import { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { X } from 'lucide-react';
import { collection, query, orderBy, limit, getDocs, Timestamp, doc, getDoc } from 'firebase/firestore';
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

const normalizeRole = (role: unknown) => {
    return typeof role === 'string' ? role.toLowerCase() : '';
};

const isProOrAboveRole = (role: unknown) => {
    const normalized = normalizeRole(role);
    return normalized === 'pro' || normalized === 'premium' || normalized === 'admin';
};

export default function Dashboard() {
    const location = useLocation();
    const navigate = useNavigate();
    const [user, setUser] = useState<User | null>(null);
    const [userProfile, setUserProfile] = useState<any>(null);
    const [allGrants, setAllGrants] = useState<Grant[]>([]);
    const [recommendedGrants, setRecommendedGrants] = useState<Grant[]>([]);
    const [loading, setLoading] = useState(true);
    const [viewMode, setViewMode] = useState<'closing-soon' | 'newest'>('newest');
    const [sourceFilter, setSourceFilter] = useState<'all' | 'bizinfo' | 'k-startup' | 'user-upload'>('all');
    const [searchQuery, setSearchQuery] = useState('');
    const [currentPage, setCurrentPage] = useState(1);
    const ITEMS_PER_PAGE = 10;
    const [analysisPreviewGrant, setAnalysisPreviewGrant] = useState<Grant | null>(null);
    const [selectedRecoGrant, setSelectedRecoGrant] = useState<Grant | null>(null);

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
                // 최근 저장된 공고를 createdAt 기준으로 가져옵니다.
                // 마감임박/최신순 정렬과 source 필터는 아래 filteredGrants 단계에서 처리합니다.
                const grantsQuery = query(
                    collection(db, 'grants'),
                    orderBy('createdAt', 'desc'),
                    limit(100)
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

    useEffect(() => {
        // URL 쿼리 파라미터(source)를 기반으로 초기 sourceFilter 설정
        const params = new URLSearchParams(location.search);
        const sourceParam = params.get('source');
        const qParam = params.get('q') || '';
        if (sourceParam === 'all' || sourceParam === 'bizinfo' || sourceParam === 'k-startup' || sourceParam === 'user-upload') {
            setSourceFilter(sourceParam as 'all' | 'bizinfo' | 'k-startup' | 'user-upload');
        }
        setSearchQuery(qParam);
    }, [location.search]);

    // 정렬/필터 변경 시 페이지를 1페이지로 리셋
    useEffect(() => {
        setCurrentPage(1);
    }, [sourceFilter, viewMode, searchQuery]);

    // Pro 유저를 위한 실제 추천 로직 (Gemini checkSuitability 사용)
    useEffect(() => {
        const runRealRecommendation = async () => {
            if (!user || !userProfile) return;
            const role = userProfile?.role;
            // Pro 이상에게만 실제 추천 로직 적용
            if (!isProOrAboveRole(role)) return;
            if (allGrants.length === 0) return;

            try {
                const buildFallbackRecommendations = (): Grant[] => {
                    const base = [...allGrants]
                        .sort((a, b) => {
                            const aTime = a.deadlineTimestamp?.toMillis() ?? Number.POSITIVE_INFINITY;
                            const bTime = b.deadlineTimestamp?.toMillis() ?? Number.POSITIVE_INFINITY;
                            return aTime - bTime;
                        })
                        .slice(0, 3);
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
                        if (data && data.status === 'ok' && data.suitability) {
                            const rawScore = data.suitability.score;
                            const score = typeof rawScore === 'number'
                                ? rawScore
                                : typeof rawScore === 'string'
                                    ? Number(rawScore)
                                    : Number.NaN;
                            if (!Number.isNaN(score)) {
                                scored.push({ grant, score, reason: data.suitability.reason });
                            }
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
                    const { grant, reason, score } = item;
                    // reason을 간단한 bullet 형태로 분리
                    const reasons = reason
                        ? reason
                            .split(/[\n\r]+/)
                            .map(s => s.trim())
                            .filter(s => s.length > 0)
                        : ['이 공고는 회원님의 조건과 잘 맞는 것으로 판단됩니다.'];
                    return {
                        ...grant,
                        matchReason: [`AI 적합도 ${Math.round(score)}점`, ...reasons].slice(0, 3),
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

    const getDeadlineBadgeLabel = (grant: Grant) => {
        const dday = calculateDday(grant.deadlineTimestamp);
        const endLabel = getGrantEndDateLabel(grant);

        // 마감 정보가 없으면 상시로 표시
        if (!grant.deadlineTimestamp && (!endLabel || endLabel === '상시')) {
            return '상시';
        }

        // 상시 공고인 경우 그대로 표시
        if (endLabel === '상시') {
            return '상시';
        }

        return `${endLabel} (${dday || 'D-?'})`;
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

    const buildGrantAiPrompt = (grant: Grant) => {
        const title = getGrantTitle(grant);
        const department = getGrantDepartment(grant);
        const endLabel = getGrantEndDateLabel(grant);
        const dday = calculateDday(grant.deadlineTimestamp);
        const link = grant.link || '';

        const lines = [
            '다음 지원사업 공고를 분석해줘.',
            '',
            `제목: ${title}`,
            `소관기관/주관기관: ${department}`,
            `신청 마감: ${endLabel}${dday ? ` (${dday})` : ''}`,
            link ? `공고 링크: ${link}` : '공고 링크: (링크 없음)',
            '',
            '우리 회사가 이 공고에 지원 가능한지, 가능성과 이유, 준비해야 할 것들을 단계별로 정리해서 알려줘.',
        ];

        return lines.join('\n');
    };

    const handleAskAiForGrant = (grant: Grant) => {
        const prompt = buildGrantAiPrompt(grant);
        navigate('/chat', {
            state: {
                initialInput: prompt,
                fromGrant: true,
            },
        });
    };

    // Check if profile is complete (Basic check)
    const isProfileComplete = userProfile?.industry && userProfile?.location;
    const userRole = normalizeRole(userProfile?.role);
    const isProOrPremium = isProOrAboveRole(userRole);

    const roleLabel = (() => {
        if (!user) return '게스트';
        if (userRole === 'pro') return 'Pro';
        if (userRole === 'premium') return 'Premium';
        if (userRole === 'admin') return '관리자';
        return 'Free';
    })();

    const recommendationSubtitle = (() => {
        if (!user) {
            return '로그인하고 기업 프로필을 설정하면 우리 회사에 맞는 지원사업을 추천해드립니다.';
        }
        if (!isProOrPremium) {
            return '현재 일반 회원입니다. Pro / 프리미엄으로 업그레이드하면 Gemini 기반 AI 맞춤 추천을 받을 수 있습니다.';
        }
        return '기업 프로필과 Gemini 상세 분석을 기반으로 한 AI 맞춤 추천 결과입니다.';
    })();

    const normalizedQuery = searchQuery.trim().toLowerCase();

    // Filter Logic
    const filteredGrants = [...allGrants]
        .filter((grant) => {
            if (sourceFilter === 'all') return true;
            return grant.source === sourceFilter;
        })
        .filter((grant) => {
            if (!normalizedQuery) return true;
            const haystack = [
                getGrantTitle(grant),
                getGrantDepartment(grant),
                grant.analysisResult?.신청자격_상세,
                grant.analysisResult?.지원규모_금액,
                grant.analysisResult?.신청기간_종료일,
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase();
            return haystack.includes(normalizedQuery);
        })
        .sort((a, b) => {
            if (viewMode === 'newest') {
                const aTime = a.analyzedAt?.toMillis() || a.createdAt?.toMillis() || 0;
                const bTime = b.analyzedAt?.toMillis() || b.createdAt?.toMillis() || 0;
                return bTime - aTime;
            }
            return (a.deadlineTimestamp?.toMillis() || 0) - (b.deadlineTimestamp?.toMillis() || 0);
        });

    const totalPages = Math.max(1, Math.ceil((filteredGrants.length || 0) / ITEMS_PER_PAGE));
    const safeCurrentPage = Math.min(currentPage, totalPages);
    const startIndex = (safeCurrentPage - 1) * ITEMS_PER_PAGE;
    const paginatedGrants = filteredGrants.slice(startIndex, startIndex + ITEMS_PER_PAGE);

    return (
        <div className="h-full flex flex-col gap-4 sm:gap-6 px-3 py-3 sm:p-4 max-w-5xl mx-auto w-full">
            {/* Header */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div>
                    <h1 className="text-2xl font-bold text-slate-900">
                        {user?.displayName ? `${user.displayName}님,` : '사장님,'}
                    </h1>
                    <p className="text-slate-500">오늘의 맞춤 공고를 확인해보세요.</p>
                </div>
                <div className="flex flex-col items-end gap-1">
                    <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-slate-900 text-white">
                        {roleLabel === '게스트'
                            ? '로그인 필요'
                            : roleLabel === 'Free'
                                ? 'Free 플랜'
                                : `${roleLabel} 플랜`}
                    </span>
                    {isProOrPremium && (
                        <span className="text-[11px] text-emerald-600 font-medium">
                            AI 맞춤 추천 활성화
                        </span>
                    )}
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
                <div className="flex flex-wrap items-center gap-1.5 sm:gap-2 mb-2">
                    <span className="text-lg font-bold text-slate-900">오늘의 추천 3</span>
                    <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-bold rounded-full">AI Pick</span>
                </div>
                <p className="text-xs text-slate-400 mb-4">{recommendationSubtitle}</p>

                <div className="flex flex-col gap-4">
                    {loading ? (
                        [1, 2, 3].map((i) => (
                            <div
                                key={i}
                                className="w-full h-[200px] bg-slate-100 rounded-2xl animate-pulse"
                            />
                        ))
                    ) : recommendedGrants.length > 0 ? (
                        recommendedGrants.map((grant) => (
                            <RecommendationCard
                                key={grant.id}
                                grant={{
                                    id: grant.id,
                                    title: getGrantTitle(grant),
                                    department: getGrantDepartment(grant),
                                    endDate: getGrantEndDateLabel(grant),
                                    views: 0,
                                    matchReason: grant.matchReason,
                                }}
                                onClick={() => setSelectedRecoGrant(grant)}
                                onAskAi={() => handleAskAiForGrant(grant)}
                            />
                        ))
                    ) : !user || !isProOrPremium ? (
                        <div className="w-full h-[200px] flex flex-col items-center justify-center bg-slate-50 rounded-2xl border border-dashed border-slate-300 text-slate-500 p-6 text-center">
                            <p className="font-medium mb-1">
                                AI 맞춤 추천은 Pro / 프리미엄 전용 기능입니다.
                            </p>
                            <p className="text-sm text-slate-400 mb-3">
                                기업 프로필을 설정하고 Pro로 업그레이드하면 우리 회사에 딱 맞는 지원사업을
                                추천해드립니다.
                            </p>
                            <a
                                href="/pricing"
                                className="inline-flex items-center justify-center px-4 py-2 text-xs font-bold rounded-xl bg-slate-900 text-white hover:bg-slate-800 transition-colors"
                            >
                                Pro 혜택 확인하기
                            </a>
                        </div>
                    ) : (
                        <div className="w-full h-[200px] flex flex-col items-center justify-center bg-slate-50 rounded-2xl border border-dashed border-slate-300 text-slate-500 p-6 text-center">
                            <p className="font-medium mb-1">아직 추천할 공고가 없습니다.</p>
                            <p className="text-sm text-slate-400">
                                Admin에서 상세 분석(프리미엄)을 실행해 분석된 공고를 늘리면 더 정확한 추천을 받을
                                수 있습니다.
                            </p>
                        </div>
                    )}
                </div>
            </section>

            {/* Section 2: Exploration List */}
            <section className="flex-1 flex flex-col min-h-0">
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4">
                    <div className="flex gap-2 bg-slate-100 p-1 rounded-lg">
                        <button
                            onClick={() => setViewMode('newest')}
                            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-all cursor-pointer ${viewMode === 'newest'
                                    ? 'bg-white text-blue-600 shadow-sm'
                                    : 'text-slate-500 hover:text-slate-700'
                                }`}
                        >
                            최신순
                        </button>
                        <button
                            onClick={() => setViewMode('closing-soon')}
                            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-all cursor-pointer ${viewMode === 'closing-soon'
                                    ? 'bg-white text-purple-600 shadow-sm'
                                    : 'text-slate-500 hover:text-slate-700'
                                }`}
                        >
                            마감임박
                        </button>
                    </div>

                    <div className="flex gap-3 items-center justify-end">
                        <div className="flex gap-1 bg-slate-50 p-1 rounded-lg">
                            <button
                                onClick={() => setSourceFilter('all')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${sourceFilter === 'all'
                                        ? 'bg-white text-slate-900 shadow-sm'
                                        : 'text-slate-500 hover:text-slate-700'
                                    }`}
                            >
                                전체
                            </button>
                            <button
                                onClick={() => setSourceFilter('bizinfo')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${sourceFilter === 'bizinfo'
                                        ? 'bg-white text-blue-600 shadow-sm'
                                        : 'text-slate-500 hover:text-slate-700'
                                    }`}
                            >
                                기업마당
                            </button>
                            <button
                                onClick={() => setSourceFilter('k-startup')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${sourceFilter === 'k-startup'
                                        ? 'bg-white text-indigo-600 shadow-sm'
                                        : 'text-slate-500 hover:text-slate-700'
                                    }`}
                            >
                                K-Startup
                            </button>
                            <button
                                onClick={() => setSourceFilter('user-upload')}
                                className={`px-2 py-1 text-xs font-medium rounded-md transition-all cursor-pointer ${sourceFilter === 'user-upload'
                                        ? 'bg-white text-green-600 shadow-sm'
                                        : 'text-slate-500 hover:text-slate-700'
                                    }`}
                            >
                                PDF 업로드
                            </button>
                        </div>
                    </div>
                </div>

                <div className="flex-1 bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
                    <div className="overflow-y-auto flex-1 p-2 space-y-2 scrollbar-thin scrollbar-thumb-slate-200">
                        {loading ? (
                            <p className="text-center text-slate-500 py-8">공고를 불러오는 중...</p>
                        ) : filteredGrants.length === 0 ? (
                            <p className="text-center text-slate-500 py-8">조건에 맞는 공고가 없습니다.</p>
                        ) : (
                            paginatedGrants.map((grant) => (
                                <div
                                    key={grant.id}
                                    className="p-3 hover:bg-slate-50 rounded-xl transition-colors cursor-pointer group border-b border-slate-50 last-border-0"
                                    onClick={() => handleGrantClick(grant)}
                                >
                                    {/* 모바일: 세로 레이아웃, 데스크탑: 가로 레이아웃 */}
                                    <div className="flex flex-col gap-2">
                                        {/* 제목 - 항상 가장 먼저 */}
                                        <h4 className="font-bold text-slate-900 text-sm line-clamp-2 group-hover:text-blue-600 transition-colors">
                                            {getGrantTitle(grant)}
                                        </h4>
                                        {/* 배지들 - flex-wrap으로 감싸기 */}
                                        <div className="flex flex-wrap items-center gap-1.5">
                                            {getSourceBadge(grant.source)}
                                            <span
                                                className={`px-1.5 py-0.5 text-[10px] font-bold rounded ${calculateDday(grant.deadlineTimestamp) === 'D-Day'
                                                        ? 'bg-red-100 text-red-600'
                                                        : 'bg-slate-100 text-slate-500'
                                                    }`}
                                            >
                                                {getDeadlineBadgeLabel(grant)}
                                            </span>
                                            {grant.analysisResult && (
                                                <button
                                                    type="button"
                                                    onClick={(e) => {
                                                        e.stopPropagation();
                                                        setAnalysisPreviewGrant(grant);
                                                    }}
                                                    className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-purple-50 text-purple-600 border border-purple-100 hover:bg-purple-100 transition-colors"
                                                >
                                                    상세분석
                                                </button>
                                            )}
                                            <button
                                                type="button"
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    handleAskAiForGrant(grant);
                                                }}
                                                className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-blue-50 text-blue-600 border border-blue-100 hover:bg-blue-100 transition-colors"
                                            >
                                                AI 분석
                                            </button>
                                        </div>
                                        {/* 하단 정보 - 소관부처 & 지원규모 */}
                                        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-500">
                                            <span>{getGrantDepartment(grant)}</span>
                                            <span className="font-medium text-slate-600 bg-slate-100 px-2 py-0.5 rounded">
                                                {grant.analysisResult?.지원규모_금액 || '지원 규모 상세페이지 확인'}
                                            </span>
                                        </div>
                                    </div>
                                </div>
                            ))
                        )}
                    </div>
                    {!loading && filteredGrants.length > 0 && (
                        <div className="border-t border-slate-100 px-3 py-2 flex items-center justify-between text-xs text-slate-500">
                            <span>
                                페이지 {safeCurrentPage} / {totalPages} · 총 {filteredGrants.length}건
                            </span>
                            <div className="flex gap-2">
                                <button
                                    type="button"
                                    onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
                                    disabled={safeCurrentPage === 1}
                                    className="px-2 py-1 rounded border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                                >
                                    이전
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
                                    disabled={safeCurrentPage === totalPages}
                                    className="px-2 py-1 rounded border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                                >
                                    다음
                                </button>
                            </div>
                        </div>
                    )}
                </div>
            </section>

            {/* 상세분석 요약 모달 */}
            {analysisPreviewGrant && analysisPreviewGrant.analysisResult && (
                <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40">
                    <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 space-y-4">
                        <div className="flex items-center justify-between mb-2">
                            <h2 className="text-base font-bold text-slate-900">상세 분석 요약</h2>
                            <button
                                type="button"
                                onClick={() => setAnalysisPreviewGrant(null)}
                                className="p-1.5 rounded-full text-slate-400 hover:text-slate-600 hover:bg-slate-100"
                                title="닫기"
                            >
                                <X size={16} />
                            </button>
                        </div>
                        <div className="space-y-2 text-sm text-slate-700">
                            <div>
                                <div className="text-xs font-semibold text-slate-500 mb-0.5">사업명</div>
                                <div className="font-medium text-slate-900">
                                    {getGrantTitle(analysisPreviewGrant)}
                                </div>
                            </div>
                            <div className="grid grid-cols-2 gap-3 mt-2">
                                <div>
                                    <div className="text-xs font-semibold text-slate-500 mb-0.5">담당 부처/지자체</div>
                                    <div className="text-xs text-slate-700">
                                        {getGrantDepartment(analysisPreviewGrant)}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-xs font-semibold text-slate-500 mb-0.5">신청 마감</div>
                                    <div className="text-xs text-slate-700">
                                        {getGrantEndDateLabel(analysisPreviewGrant)}
                                    </div>
                                </div>
                            </div>
                            {analysisPreviewGrant.analysisResult.신청자격_상세 && (
                                <div className="mt-3">
                                    <div className="text-xs font-semibold text-slate-500 mb-0.5">신청 자격 요약</div>
                                    <p className="text-xs text-slate-700 whitespace-pre-wrap line-clamp-4">
                                        {analysisPreviewGrant.analysisResult.신청자격_상세}
                                    </p>
                                </div>
                            )}
                            {analysisPreviewGrant.analysisResult.지원규모_금액 && (
                                <div className="mt-2 text-xs text-slate-600">
                                    <span className="font-semibold">지원 규모: </span>
                                    {analysisPreviewGrant.analysisResult.지원규모_금액}
                                </div>
                            )}
                        </div>
                        <div className="flex justify-end gap-2 pt-2">
                            <button
                                type="button"
                                onClick={() => setAnalysisPreviewGrant(null)}
                                className="px-3 py-1.5 text-xs rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50"
                            >
                                닫기
                            </button>
                            <button
                                type="button"
                                onClick={() => {
                                    handleGrantClick(analysisPreviewGrant);
                                    setAnalysisPreviewGrant(null);
                                }}
                                className="px-3 py-1.5 text-xs rounded-lg bg-slate-900 text-white hover:bg-slate-800"
                            >
                                원문 페이지 열기
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* 추천 상세 모달 */}
            {selectedRecoGrant && (
                <div className="fixed inset-0 z-40 flex items-center justify-center bg-black/40">
                    <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 space-y-4">
                        <div className="flex items-center justify-between mb-2">
                            <h2 className="text-base font-bold text-slate-900">추천 공고 상세</h2>
                            <button
                                type="button"
                                onClick={() => setSelectedRecoGrant(null)}
                                className="p-1.5 rounded-full text-slate-400 hover:text-slate-600 hover:bg-slate-100"
                                title="닫기"
                            >
                                <X size={16} />
                            </button>
                        </div>
                        <div className="space-y-2 text-sm text-slate-700">
                            <div>
                                <div className="text-xs font-semibold text-slate-500 mb-0.5">사업명</div>
                                <div className="font-medium text-slate-900">
                                    {getGrantTitle(selectedRecoGrant)}
                                </div>
                            </div>
                            <div className="grid grid-cols-2 gap-3 mt-2">
                                <div>
                                    <div className="text-xs font-semibold text-slate-500 mb-0.5">담당 부처/지자체</div>
                                    <div className="text-xs text-slate-700">
                                        {getGrantDepartment(selectedRecoGrant)}
                                    </div>
                                </div>
                                <div>
                                    <div className="text-xs font-semibold text-slate-500 mb-0.5">신청 마감</div>
                                    <div className="text-xs text-slate-700">
                                        {getGrantEndDateLabel(selectedRecoGrant)}
                                    </div>
                                </div>
                            </div>
                            {selectedRecoGrant.matchReason && selectedRecoGrant.matchReason.length > 0 && (
                                <div className="mt-3">
                                    <div className="text-xs font-semibold text-slate-500 mb-1">추천 이유</div>
                                    <ul className="list-disc list-inside space-y-0.5 text-xs text-slate-700">
                                        {selectedRecoGrant.matchReason.map((reason, idx) => (
                                            <li key={idx}>{reason}</li>
                                        ))}
                                    </ul>
                                </div>
                            )}
                        </div>
                        <div className="flex justify-end gap-2 pt-2">
                            <button
                                type="button"
                                onClick={() => setSelectedRecoGrant(null)}
                                className="px-3 py-1.5 text-xs rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50"
                            >
                                닫기
                            </button>
                            <button
                                type="button"
                                onClick={() => {
                                    handleGrantClick(selectedRecoGrant);
                                    setSelectedRecoGrant(null);
                                }}
                                className="px-3 py-1.5 text-xs rounded-lg bg-slate-900 text-white hover:bg-slate-800"
                            >
                                원문 페이지 열기
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
