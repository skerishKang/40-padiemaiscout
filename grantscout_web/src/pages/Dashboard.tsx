import { useState, useEffect } from 'react';
import { Filter } from 'lucide-react';
import { collection, query, where, orderBy, limit, getDocs, Timestamp, doc, getDoc } from 'firebase/firestore';
import { db, auth } from '../lib/firebase';
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
    // For recommendation logic
    matchReason?: string[];
}

export default function Dashboard() {
    const [user, setUser] = useState<User | null>(null);
    const [userProfile, setUserProfile] = useState<any>(null);
    const [allGrants, setAllGrants] = useState<Grant[]>([]);
    const [recommendedGrants, setRecommendedGrants] = useState<Grant[]>([]);
    const [loading, setLoading] = useState(true);
    const [viewMode, setViewMode] = useState<'closing-soon' | 'newest'>('newest');

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

                // Fetch active grants (deadline > now)
                const grantsQuery = query(
                    collection(db, 'uploaded_files'),
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

                // Mock Recommendation Logic
                const shuffled = [...grants].sort(() => 0.5 - Math.random());
                const top3 = shuffled.slice(0, 3).map(g => ({
                    ...g,
                    matchReason: ['서울 소재 기업 우대', '창업 3년 미만 적합']
                }));
                setRecommendedGrants(top3);

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

    // Check if profile is complete (Basic check)
    const isProfileComplete = userProfile?.industry && userProfile?.location;

    // Filter Logic
    const filteredGrants = [...allGrants].sort((a, b) => {
        if (viewMode === 'newest') {
            // Sort by analyzedAt (desc)
            return (b.analyzedAt?.toMillis() || 0) - (a.analyzedAt?.toMillis() || 0);
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
                <div className="flex items-center gap-2 mb-4">
                    <span className="text-lg font-bold text-slate-900">오늘의 추천 3</span>
                    <span className="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-bold rounded-full">AI Pick</span>
                </div>

                <div className="flex gap-4 overflow-x-auto pb-4 snap-x snap-mandatory scrollbar-hide">
                    {loading ? (
                        [1, 2, 3].map(i => (
                            <div key={i} className="min-w-[300px] h-[200px] bg-slate-100 rounded-2xl animate-pulse" />
                        ))
                    ) : (
                        recommendedGrants.map(grant => (
                            <RecommendationCard
                                key={grant.id}
                                grant={{
                                    id: grant.id,
                                    title: grant.analysisResult?.사업명 || '제목 없음',
                                    department: grant.analysisResult?.소관부처_지자체 || '부처 미정',
                                    endDate: grant.analysisResult?.신청기간_종료일 || '상시',
                                    views: 0,
                                    matchReason: grant.matchReason
                                }}
                                onClick={() => alert(`공고 클릭: ${grant.analysisResult?.사업명}`)}
                            />
                        ))
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

                    <div className="flex gap-2">
                        {/* Simple Filter Dropdown Mockup */}
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
                                    onClick={() => alert(`공고 클릭: ${grant.analysisResult?.사업명}`)}
                                >
                                    <div className="flex justify-between items-start gap-4">
                                        <div className="flex-1">
                                            <div className="flex items-center gap-2 mb-1">
                                                <span className={`px-1.5 py-0.5 text-[10px] font-bold rounded ${calculateDday(grant.deadlineTimestamp) === 'D-Day' ? 'bg-red-100 text-red-600' : 'bg-slate-100 text-slate-500'
                                                    }`}>
                                                    {calculateDday(grant.deadlineTimestamp) || '상시'}
                                                </span>
                                                <span className="text-xs text-slate-400">
                                                    {grant.analysisResult?.소관부처_지자체 || '소관부처 미정'}
                                                </span>
                                            </div>
                                            <h4 className="font-bold text-slate-900 text-sm line-clamp-1 group-hover:text-blue-600 transition-colors">
                                                {grant.analysisResult?.사업명 || '제목 없음'}
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
