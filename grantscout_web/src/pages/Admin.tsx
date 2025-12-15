import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldAlert, Users, CreditCard, Database, RefreshCw, Clock } from 'lucide-react';
import { db, functions } from '../lib/firebase';
import { collection, getCountFromServer, query, where, getDocs, orderBy, limit, doc, setDoc } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';

interface SchedulerConfig {
    enabled: boolean;
    intervalMinutes: number;
    mode?: 'interval' | 'daily';
    dailyTimes?: string[];
    lastRunAt?: string | null;
    lastRunResult?: string | null;
    lastRunError?: string | null;
}

interface AdminUser {
    id: string;
    email?: string;
    displayName?: string;
    role?: string;
    createdAt?: any;
    lastLogin?: any;
}

interface AdminSyncLog {
    id: string;
    type: string;
    status: string;
    message?: string;
    meta?: any;
    triggeredAt?: any;
    triggerEmail?: string;
}

export default function Admin() {
    const navigate = useNavigate();
    const [stats, setStats] = useState({ totalUsers: 0, proUsers: 0 });
    const [grantStats, setGrantStats] = useState({ totalGrants: 0, bizinfoGrants: 0, userUploadGrants: 0 });
    const [analysisStats, setAnalysisStats] = useState({ scrapedGrants: 0, analyzedScrapedGrants: 0, pendingScrapedGrants: 0 });
    const [syncSinceDate, setSyncSinceDate] = useState('');
    const [syncRangeDays, setSyncRangeDays] = useState(7);
    const [bizinfoSyncing, setBizinfoSyncing] = useState(false);
    const [kStartupSyncing, setKStartupSyncing] = useState(false);
    const [analyzeSyncing, setAnalyzeSyncing] = useState(false);
    const [syncResult, setSyncResult] = useState<string | null>(null);
    const [schedulerConfig, setSchedulerConfig] = useState<SchedulerConfig | null>(null);
    const [newDailyTime, setNewDailyTime] = useState('09:00');
    const [loadingScheduler, setLoadingScheduler] = useState(false);
    const [savingScheduler, setSavingScheduler] = useState(false);
    const [schedulerMessage, setSchedulerMessage] = useState<string | null>(null);
    const [users, setUsers] = useState<AdminUser[]>([]);
    const [loadingUsers, setLoadingUsers] = useState(false);
    const [updatingUserId, setUpdatingUserId] = useState<string | null>(null);
    const [userSearch, setUserSearch] = useState('');
    const [userRoleFilter, setUserRoleFilter] = useState<'all' | 'free' | 'pro' | 'premium' | 'admin'>('all');
    const [syncLogs, setSyncLogs] = useState<AdminSyncLog[]>([]);
    const [loadingLogs, setLoadingLogs] = useState(false);
    const [logPage, setLogPage] = useState(1);
    const [logDateFilter, setLogDateFilter] = useState<'today' | '7days' | '30days' | 'all'>('7days');
    const LOGS_PER_PAGE = 10;

    const handleSyncBizinfo = async () => {
        if (!syncSinceDate) {
            setSyncResult('[기업마당] 실패: 기준일(sinceDate)을 선택해주세요.');
            return;
        }
        setBizinfoSyncing(true);
        setSyncResult(null);
        try {
            const scrapeBizinfo = httpsCallable(functions, 'scrapeBizinfo');
            const result = await scrapeBizinfo({ sinceDate: syncSinceDate, rangeDays: syncRangeDays });
            const data = result.data as any;
            const detail = data && typeof data.newCount === 'number'
                ? ` (신규 ${data.newCount} / 업데이트 ${data.updatedCount ?? 0} / 스킵 ${data.skippedCount ?? 0})`
                : '';
            setSyncResult(`[기업마당] 성공: ${data.message || ''}${detail}`);
        } catch (error: any) {
            console.error("Bizinfo sync failed:", error);
            setSyncResult(`[기업마당] 실패: ${error.message}`);
        } finally {
            setBizinfoSyncing(false);
        }
    };

    const handleSyncKStartup = async () => {
        if (!syncSinceDate) {
            setSyncResult('[#K-Startup] 실패: 기준일(sinceDate)을 선택해주세요.');
            return;
        }
        setKStartupSyncing(true);
        setSyncResult(null);
        try {
            const scrapeKStartup = httpsCallable(functions, 'scrapeKStartup');
            const result = await scrapeKStartup({ sinceDate: syncSinceDate, rangeDays: syncRangeDays });
            const data = result.data as any;
            const detail = data && typeof data.newCount === 'number'
                ? ` (신규 ${data.newCount} / 업데이트 ${data.updatedCount ?? 0} / 스킵 ${data.skippedCount ?? 0})`
                : '';
            setSyncResult(`[#K-Startup] 성공: ${data.message || ''}${detail}`);
        } catch (error: any) {
            console.error("K-Startup sync failed:", error);
            setSyncResult(`[#K-Startup] 실패: ${error.message}`);
        } finally {
            setKStartupSyncing(false);
        }
    };

    const handleAnalyzeScrapedGrants = async () => {
        setAnalyzeSyncing(true);
        setSyncResult(null);
        try {
            const analyzeBatch = httpsCallable(functions, 'analyzeScrapedGrantsBatch');
            const result = await analyzeBatch({ batchSize: 5 });
            const data = result.data as any;
            const prefix = '[상세분석]';
            if (data && data.success) {
                setSyncResult(`${prefix} 성공: ${data.message || ''}`);
            } else {
                setSyncResult(`${prefix} 실패: ${(data && data.message) || '알 수 없는 오류'}`);
            }
        } catch (error: any) {
            console.error('Analyze scraped grants failed:', error);
            setSyncResult(`[상세분석] 실패: ${error.message}`);
        } finally {
            setAnalyzeSyncing(false);
        }
    };

    const fetchSchedulerConfig = async () => {
        setLoadingScheduler(true);
        setSchedulerMessage(null);
        try {
            const getConfig = httpsCallable(functions, 'getBizinfoSchedulerConfig');
            const result = await getConfig();
            const data = result.data as any;
            if (data && data.success && data.config) {
                setSchedulerConfig({
                    enabled: !!data.config.enabled,
                    intervalMinutes: Number(data.config.intervalMinutes) || 60,
                    mode: data.config.mode === 'daily' ? 'daily' : 'interval',
                    dailyTimes: Array.isArray(data.config.dailyTimes) ? data.config.dailyTimes : [],
                    lastRunAt: data.config.lastRunAt || null,
                    lastRunResult: data.config.lastRunResult || null,
                    lastRunError: data.config.lastRunError || null,
                });
            } else {
                setSchedulerMessage('스케줄러 설정을 불러오지 못했습니다.');
            }
        } catch (error: any) {
            console.error('Failed to fetch scheduler config:', error);
            setSchedulerMessage(error.message || '스케줄러 설정 조회 중 오류가 발생했습니다.');
        } finally {
            setLoadingScheduler(false);
        }
    };

    const handleSaveScheduler = async () => {
        if (!schedulerConfig) return;
        setSavingScheduler(true);
        setSchedulerMessage(null);
        try {
            const updateConfig = httpsCallable(functions, 'updateBizinfoSchedulerConfig');
            const result = await updateConfig({
                enabled: schedulerConfig.enabled,
                intervalMinutes: schedulerConfig.intervalMinutes,
                mode: schedulerConfig.mode || 'interval',
                dailyTimes: Array.isArray(schedulerConfig.dailyTimes) ? schedulerConfig.dailyTimes : [],
            } as any);
            const data = result.data as any;
            if (data && data.success && data.config) {
                setSchedulerConfig({
                    enabled: !!data.config.enabled,
                    intervalMinutes: Number(data.config.intervalMinutes) || schedulerConfig.intervalMinutes,
                    mode: data.config.mode === 'daily' ? 'daily' : 'interval',
                    dailyTimes: Array.isArray(data.config.dailyTimes) ? data.config.dailyTimes : schedulerConfig.dailyTimes,
                    lastRunAt: data.config.lastRunAt || schedulerConfig.lastRunAt || null,
                    lastRunResult: data.config.lastRunResult || schedulerConfig.lastRunResult || null,
                    lastRunError: data.config.lastRunError || schedulerConfig.lastRunError || null,
                });
                setSchedulerMessage('스케줄러 설정이 저장되었습니다.');
            } else {
                setSchedulerMessage('스케줄러 설정 저장에 실패했습니다.');
            }
        } catch (error: any) {
            console.error('Failed to update scheduler config:', error);
            setSchedulerMessage(error.message || '스케줄러 설정 저장 중 오류가 발생했습니다.');
        } finally {
            setSavingScheduler(false);
        }
    };

    const fetchUsers = async () => {
        setLoadingUsers(true);
        try {
            const usersColl = collection(db, 'users');
            const usersQuery = query(usersColl, orderBy('createdAt', 'desc'), limit(100));
            const snapshot = await getDocs(usersQuery);
            const list: AdminUser[] = snapshot.docs.map((docSnap) => {
                const data = docSnap.data() as any;
                return {
                    id: docSnap.id,
                    email: data.email || '',
                    displayName: data.displayName || '',
                    role: data.role || 'free',
                    createdAt: data.createdAt,
                    lastLogin: data.lastLogin,
                };
            });
            setUsers(list);
        } catch (error) {
            console.error('Failed to fetch users:', error);
        } finally {
            setLoadingUsers(false);
        }
    };

    const fetchSyncLogs = async () => {
        setLoadingLogs(true);
        try {
            const logsColl = collection(db, 'admin_sync_logs');
            const logsQuery = query(logsColl, orderBy('triggeredAt', 'desc'), limit(50));
            const snapshot = await getDocs(logsQuery);
            const list: AdminSyncLog[] = snapshot.docs.map((docSnap) => {
                const data = docSnap.data() as any;
                return {
                    id: docSnap.id,
                    type: data.type || '',
                    status: data.status || '',
                    message: data.message || '',
                    meta: data.meta || null,
                    triggeredAt: data.triggeredAt,
                    triggerEmail: data.triggerEmail || '',
                };
            });
            setSyncLogs(list);
        } catch (error) {
            console.error('Failed to fetch sync logs:', error);
        } finally {
            setLoadingLogs(false);
        }
    };

    const handleChangeUserRole = async (userId: string, newRole: string) => {
        const labelMap: Record<string, string> = {
            free: '일반',
            pro: 'Pro',
            premium: 'Premium',
            admin: '관리자',
        };
        const label = labelMap[newRole] || newRole;
        if (!window.confirm(`등급을 ${label}(으)로 변경하시겠습니까?`)) return;

        setUpdatingUserId(userId);
        try {
            const userRef = doc(db, 'users', userId);
            await setDoc(userRef, { role: newRole }, { merge: true });
            setUsers((prev) => prev.map((u) => (u.id === userId ? { ...u, role: newRole } : u)));
            alert(`등급이 ${label}(으)로 변경되었습니다.`);
        } catch (error: any) {
            console.error('Failed to update user role:', error);
            const errorMsg = error?.code === 'permission-denied'
                ? '권한이 없습니다. Firestore 보안 규칙을 확인해주세요.'
                : `등급 변경 중 오류: ${error?.message || error}`;
            alert(errorMsg);
        } finally {
            setUpdatingUserId(null);
        }
    };

    const filteredUsers = users.filter((u) => {
        const role = (u.role || 'free') as 'free' | 'pro' | 'premium' | 'admin';
        if (userRoleFilter !== 'all' && role !== userRoleFilter) {
            return false;
        }
        if (!userSearch.trim()) return true;
        const q = userSearch.trim().toLowerCase();
        const name = (u.displayName || '').toLowerCase();
        const email = (u.email || '').toLowerCase();
        const id = (u.id || '').toLowerCase();
        return name.includes(q) || email.includes(q) || id.includes(q);
    });

    const formatLastRunAt = (value?: string | null) => {
        if (!value) return '-';
        const date = new Date(value);
        if (isNaN(date.getTime())) return value;
        return date.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
    };

    const formatLogTime = (value: any) => {
        if (!value) return '-';
        try {
            if (value.toDate && typeof value.toDate === 'function') {
                const d = value.toDate() as Date;
                return d.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
            }
            if (typeof value === 'string') {
                const d = new Date(value);
                if (!isNaN(d.getTime())) {
                    return d.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
                }
                return value;
            }
        } catch (e) {
            console.error('Failed to format log time:', e);
        }
        return '-';
    };

    useEffect(() => {
        const fetchStats = async () => {
            try {
                const usersColl = collection(db, 'users');

                // Total Users
                const totalSnapshot = await getCountFromServer(usersColl);

                // Pro Users
                const proQuery = query(usersColl, where('role', '==', 'pro'));
                const proSnapshot = await getCountFromServer(proQuery);

                setStats({
                    totalUsers: totalSnapshot.data().count,
                    proUsers: proSnapshot.data().count
                });

                // 공고 통계 (grants 컬렉션)
                const grantsColl = collection(db, 'grants');
                const totalGrantsSnap = await getCountFromServer(grantsColl);

                const bizinfoQuery = query(grantsColl, where('source', '==', 'bizinfo'));
                const bizinfoSnap = await getCountFromServer(bizinfoQuery);

                const userUploadQuery = query(grantsColl, where('source', '==', 'user-upload'));
                const userUploadSnap = await getCountFromServer(userUploadQuery);

                const kStartupQuery = query(grantsColl, where('source', '==', 'k-startup'));
                const kStartupSnap = await getCountFromServer(kStartupQuery);

                const bizinfoAnalyzedQuery = query(grantsColl, where('source', '==', 'bizinfo'), where('analysisResult', '!=', null));
                const bizinfoAnalyzedSnap = await getCountFromServer(bizinfoAnalyzedQuery);

                const kStartupAnalyzedQuery = query(grantsColl, where('source', '==', 'k-startup'), where('analysisResult', '!=', null));
                const kStartupAnalyzedSnap = await getCountFromServer(kStartupAnalyzedQuery);

                setGrantStats({
                    totalGrants: totalGrantsSnap.data().count,
                    bizinfoGrants: bizinfoSnap.data().count,
                    userUploadGrants: userUploadSnap.data().count,
                });

                const scrapedGrants = bizinfoSnap.data().count + kStartupSnap.data().count;
                const analyzedScrapedGrants = bizinfoAnalyzedSnap.data().count + kStartupAnalyzedSnap.data().count;
                const pendingScrapedGrants = Math.max(0, scrapedGrants - analyzedScrapedGrants);

                setAnalysisStats({
                    scrapedGrants,
                    analyzedScrapedGrants,
                    pendingScrapedGrants,
                });
            } catch (error) {
                console.error("Error fetching stats:", error);
            }
        };
        const init = async () => {
            await fetchStats();
            await fetchSchedulerConfig();
            await fetchUsers();
            await fetchSyncLogs();
        };

        init();
    }, []);

    return (
        <div className="max-w-4xl mx-auto px-3 py-4 sm:p-6">
            <div className="flex flex-col sm:flex-row sm:items-center gap-3 mb-6">
                <div className="flex items-center gap-3">
                    <div className="p-2.5 sm:p-3 bg-slate-900 text-white rounded-xl">
                        <ShieldAlert size={20} />
                    </div>
                    <div>
                        <h1 className="text-xl sm:text-2xl font-bold text-slate-900">관리자 대시보드</h1>
                        <p className="text-sm text-slate-500">시스템 관리 및 데이터 수집을 수행합니다.</p>
                    </div>
                </div>
            </div>

            {/* Stats Overview */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 sm:gap-4 mb-6">
                <div className="bg-white p-3 sm:p-4 rounded-xl border border-slate-200 shadow-sm">
                    <div className="flex items-center gap-2 mb-1">
                        <div className="p-1.5 bg-green-50 text-green-600 rounded-lg">
                            <Database size={14} />
                        </div>
                        <span className="text-[10px] sm:text-xs text-slate-500">총 공고</span>
                    </div>
                    <p className="text-lg sm:text-xl font-bold text-slate-900">{grantStats.totalGrants}건</p>
                </div>
                <div className="bg-white p-3 sm:p-4 rounded-xl border border-slate-200 shadow-sm">
                    <div className="flex items-center gap-2 mb-1">
                        <div className="p-1.5 bg-blue-50 text-blue-600 rounded-lg">
                            <Users size={14} />
                        </div>
                        <span className="text-[10px] sm:text-xs text-slate-500">총 유저</span>
                    </div>
                    <p className="text-lg sm:text-xl font-bold text-slate-900">{stats.totalUsers}명</p>
                </div>
                <div className="bg-white p-3 sm:p-4 rounded-xl border border-slate-200 shadow-sm">
                    <div className="flex items-center gap-2 mb-1">
                        <div className="p-1.5 bg-purple-50 text-purple-600 rounded-lg">
                            <CreditCard size={14} />
                        </div>
                        <span className="text-[10px] sm:text-xs text-slate-500">Pro 멤버</span>
                    </div>
                    <p className="text-lg sm:text-xl font-bold text-slate-900">{stats.proUsers}명</p>
                </div>
                <div className="bg-white p-3 sm:p-4 rounded-xl border border-slate-200 shadow-sm">
                    <div className="flex items-center gap-2 mb-1">
                        <div className="p-1.5 bg-amber-50 text-amber-600 rounded-lg">
                            <Database size={14} />
                        </div>
                        <span className="text-[10px] sm:text-xs text-slate-500">분석/미분석</span>
                    </div>
                    <p className="text-sm sm:text-base font-bold text-slate-900">{analysisStats.analyzedScrapedGrants}/{analysisStats.pendingScrapedGrants}</p>
                </div>
            </div>

            <div className="grid grid-cols-1 gap-4 sm:gap-6">
                {/* Data Collection Section */}
                <div className="bg-white p-4 sm:p-6 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex flex-col gap-4 mb-4">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-green-50 text-green-600 rounded-lg">
                                <Database size={18} />
                            </div>
                            <div>
                                <h3 className="font-bold text-slate-900 text-sm sm:text-base">데이터 수집 및 동기화</h3>
                                <p className="text-xs sm:text-sm text-slate-500">외부 사이트에서 공고를 수집합니다.</p>
                            </div>
                        </div>
                        <div className="flex flex-col gap-2">
                            <div className="flex flex-col sm:flex-row sm:items-center gap-2 text-xs">
                                <div className="flex items-center gap-2">
                                    <span className="text-slate-600 font-medium">기준일</span>
                                    <input
                                        type="date"
                                        value={syncSinceDate}
                                        onChange={(e) => setSyncSinceDate(e.target.value)}
                                        className="px-3 py-2 rounded-xl border border-slate-200 text-slate-700 bg-white"
                                    />
                                </div>
                                <div className="flex items-center gap-2">
                                    <span className="text-slate-600 font-medium">기간</span>
                                    <select
                                        value={syncRangeDays}
                                        onChange={(e) => setSyncRangeDays(Number(e.target.value) || 7)}
                                        className="px-3 py-2 rounded-xl border border-slate-200 text-slate-700 bg-white"
                                    >
                                        <option value={1}>1일</option>
                                        <option value={2}>2일</option>
                                        <option value={3}>3일</option>
                                        <option value={4}>4일</option>
                                        <option value={5}>5일</option>
                                        <option value={6}>6일</option>
                                        <option value={7}>7일</option>
                                    </select>
                                </div>
                                <button
                                    type="button"
                                    onClick={() => setSyncSinceDate('')}
                                    className="px-3 py-2 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
                                >
                                    초기화
                                </button>
                                <span className="text-slate-500">기준일을 선택하면 해당 날짜부터 기간만큼만 저장합니다(최대 7일).</span>
                            </div>
                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                                <button
                                    onClick={handleSyncBizinfo}
                                    disabled={bizinfoSyncing || !syncSinceDate}
                                    className="px-3 py-2.5 bg-slate-900 text-white font-bold rounded-xl hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 cursor-pointer text-xs sm:text-sm"
                                >
                                    {bizinfoSyncing ? (
                                        <>
                                            <RefreshCw size={16} className="animate-spin" />
                                            동기화 중...
                                        </>
                                    ) : (
                                        <>
                                            <RefreshCw size={16} />
                                            기업마당 동기화
                                        </>
                                    )}
                                </button>
                                <button
                                    onClick={handleSyncKStartup}
                                    disabled={kStartupSyncing || !syncSinceDate}
                                    className="px-3 py-2.5 bg-blue-600 text-white font-bold rounded-xl hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 cursor-pointer text-xs sm:text-sm"
                                >
                                    {kStartupSyncing ? (
                                        <>
                                            <RefreshCw size={16} className="animate-spin" />
                                            동기화 중...
                                        </>
                                    ) : (
                                        <>
                                            <RefreshCw size={16} />
                                            K-Startup 동기화
                                        </>
                                    )}
                                </button>
                                <button
                                    onClick={handleAnalyzeScrapedGrants}
                                    disabled={analyzeSyncing}
                                    className="px-3 py-2.5 bg-purple-600 text-white font-bold rounded-xl hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 cursor-pointer text-xs sm:text-sm"
                                >
                                    {analyzeSyncing ? (
                                        <>
                                            <RefreshCw size={16} className="animate-spin" />
                                            상세분석 중...
                                        </>
                                    ) : (
                                        <>
                                            <RefreshCw size={16} />
                                            상세 분석
                                        </>
                                    )}
                                </button>
                            </div>
                            <div className="flex flex-wrap gap-2 text-xs text-slate-600">
                                <button
                                    type="button"
                                    onClick={() => navigate('/grants?source=bizinfo')}
                                    className="px-3 py-1 rounded-full bg-slate-50 hover:bg-slate-100 border border-slate-200 transition-colors cursor-pointer"
                                >
                                    기업마당 공고 보기
                                </button>
                                <button
                                    type="button"
                                    onClick={() => navigate('/grants?source=k-startup')}
                                    className="px-3 py-1 rounded-full bg-slate-50 hover:bg-slate-100 border border-slate-200 transition-colors cursor-pointer"
                                >
                                    K-Startup 공고 보기
                                </button>
                            </div>
                        </div>
                    </div>
                    {syncResult && (
                        <div className={`p-3 rounded-xl text-xs sm:text-sm ${syncResult.includes('성공') ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                            {syncResult}
                        </div>
                    )}
                </div>

                {/* Scheduler Section */}
                <div className="bg-white p-4 sm:p-6 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-purple-50 text-purple-600 rounded-lg">
                                <Clock size={18} />
                            </div>
                            <div>
                                <h3 className="font-bold text-slate-900 text-sm sm:text-base">스케줄러 설정</h3>
                                <p className="text-xs sm:text-sm text-slate-500">기업마당 자동 수집 주기를 관리합니다.</p>
                            </div>
                        </div>
                        <button
                            onClick={fetchSchedulerConfig}
                            disabled={loadingScheduler}
                            className="px-3 py-1.5 text-xs border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {loadingScheduler ? '불러오는 중...' : '새로고침'}
                        </button>
                    </div>

                    {schedulerConfig && (
                        <div className="space-y-3">
                            <div className="flex items-center justify-between">
                                <span className="text-xs sm:text-sm text-slate-700">스케줄러 활성화</span>
                                <button
                                    type="button"
                                    onClick={() =>
                                        setSchedulerConfig((prev) =>
                                            prev ? { ...prev, enabled: !prev.enabled } : prev,
                                        )
                                    }
                                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${schedulerConfig.enabled ? 'bg-green-500' : 'bg-slate-300'}`}
                                >
                                    <span
                                        className={`inline-block h-5 w-5 transform rounded-full bg-white transition-transform ${schedulerConfig.enabled ? 'translate-x-5' : 'translate-x-1'}`}
                                    />
                                </button>
                            </div>

                            <div className="flex flex-col sm:flex-row sm:items-end gap-2">
                                <div className="flex-1">
                                    <p className="text-xs text-slate-700 mb-1">실행 방식</p>
                                    <select
                                        value={schedulerConfig.mode || 'interval'}
                                        onChange={(e) => {
                                            const nextMode = e.target.value === 'daily' ? 'daily' : 'interval';
                                            setSchedulerConfig((prev) => {
                                                if (!prev) return prev;
                                                if (nextMode === 'daily') {
                                                    const times = Array.isArray(prev.dailyTimes) && prev.dailyTimes.length > 0 ? prev.dailyTimes : ['09:00'];
                                                    return { ...prev, mode: 'daily', dailyTimes: times };
                                                }
                                                return { ...prev, mode: 'interval' };
                                            });
                                        }}
                                        className="w-full px-3 py-2 border border-slate-200 rounded-lg text-xs sm:text-sm bg-white"
                                    >
                                        <option value="daily">정규시간(매일)</option>
                                        <option value="interval">간격(분)</option>
                                    </select>
                                </div>
                                <div className="text-[10px] sm:text-xs text-slate-400">
                                    <p>정규시간은 15분 단위로 실행됩니다.</p>
                                </div>
                            </div>

                            {((schedulerConfig.mode || 'interval') === 'interval') && (
                                <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                                    <div className="flex-1">
                                        <p className="text-xs text-slate-700 mb-1">실행 간격(분)</p>
                                        <input
                                            type="number"
                                            min={15}
                                            max={1440}
                                            value={schedulerConfig.intervalMinutes}
                                            onChange={(e) =>
                                                setSchedulerConfig((prev) =>
                                                    prev
                                                        ? { ...prev, intervalMinutes: Number(e.target.value) || 0 }
                                                        : prev,
                                                )
                                            }
                                            className="w-full px-3 py-2 border border-slate-200 rounded-lg text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                                        />
                                    </div>
                                    <div className="text-[10px] sm:text-xs text-slate-400">
                                        <p>최소 15분, 최대 1440분(24시간)</p>
                                    </div>
                                </div>
                            )}

                            {((schedulerConfig.mode || 'interval') === 'daily') && (
                                <div className="space-y-2">
                                    <div className="flex flex-col sm:flex-row sm:items-end gap-2">
                                        <div className="flex-1">
                                            <p className="text-xs text-slate-700 mb-1">정규시간(HH:mm)</p>
                                            <input
                                                type="time"
                                                step={900}
                                                value={newDailyTime}
                                                onChange={(e) => setNewDailyTime(e.target.value)}
                                                className="w-full px-3 py-2 border border-slate-200 rounded-lg text-xs sm:text-sm bg-white"
                                            />
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => {
                                                setSchedulerConfig((prev) => {
                                                    if (!prev) return prev;
                                                    const existing = Array.isArray(prev.dailyTimes) ? prev.dailyTimes : [];
                                                    const cleaned = [
                                                        ...existing,
                                                        newDailyTime,
                                                    ]
                                                        .map((t) => String(t || '').trim())
                                                        .filter((t) => /^\d{2}:\d{2}$/.test(t));
                                                    const unique = Array.from(new Set(cleaned)).sort().slice(0, 4);
                                                    return { ...prev, dailyTimes: unique };
                                                });
                                            }}
                                            className="px-4 py-2 bg-slate-900 text-white text-xs sm:text-sm font-bold rounded-xl hover:bg-slate-800 transition-colors"
                                        >
                                            추가
                                        </button>
                                    </div>

                                    <div className="flex flex-wrap gap-2">
                                        {(Array.isArray(schedulerConfig.dailyTimes) ? schedulerConfig.dailyTimes : []).map((t) => (
                                            <button
                                                key={t}
                                                type="button"
                                                onClick={() =>
                                                    setSchedulerConfig((prev) => {
                                                        if (!prev) return prev;
                                                        const next = (Array.isArray(prev.dailyTimes) ? prev.dailyTimes : []).filter((x) => x !== t);
                                                        return { ...prev, dailyTimes: next };
                                                    })
                                                }
                                                className="px-3 py-1 rounded-full border border-slate-200 bg-white text-xs text-slate-700 hover:bg-slate-50"
                                            >
                                                {t} 삭제
                                            </button>
                                        ))}
                                        {(Array.isArray(schedulerConfig.dailyTimes) ? schedulerConfig.dailyTimes : []).length === 0 && (
                                            <span className="text-xs text-slate-400">정규시간을 1개 이상 추가해주세요.</span>
                                        )}
                                    </div>
                                </div>
                            )}

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-slate-500 bg-slate-50 rounded-xl p-3">
                                <div>
                                    <p className="font-medium text-slate-600 mb-0.5">마지막 실행</p>
                                    <p className="text-[11px]">{formatLastRunAt(schedulerConfig.lastRunAt)}</p>
                                </div>
                                <div>
                                    <p className="font-medium text-slate-600 mb-0.5">마지막 결과</p>
                                    <p className="line-clamp-2 text-[11px]">{schedulerConfig.lastRunResult || schedulerConfig.lastRunError || '-'}</p>
                                </div>
                            </div>

                            <div className="flex items-center justify-end gap-2 pt-1">
                                <button
                                    type="button"
                                    onClick={handleSaveScheduler}
                                    disabled={savingScheduler}
                                    className="px-4 py-2 bg-slate-900 text-white text-xs sm:text-sm font-bold rounded-xl hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    {savingScheduler ? '저장 중...' : '설정 저장'}
                                </button>
                            </div>
                        </div>
                    )}

                    {!schedulerConfig && !loadingScheduler && (
                        <p className="text-xs sm:text-sm text-slate-500">스케줄러 설정을 불러오지 못했습니다. 새로고침을 눌러 다시 시도해주세요.</p>
                    )}

                    {schedulerMessage && (
                        <div className="mt-3 text-xs text-slate-600 bg-slate-50 rounded-xl px-3 py-2">
                            {schedulerMessage}
                        </div>
                    )}
                </div>

                {/* User Management Section */}
                <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-6">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
                        <div>
                            <h3 className="text-sm sm:text-base font-bold text-slate-900">유저 관리</h3>
                            <p className="text-xs text-slate-500 mt-0.5">가입한 유저의 등급을 조정합니다.</p>
                        </div>
                        <button
                            type="button"
                            onClick={fetchUsers}
                            disabled={loadingUsers}
                            className="px-3 py-1.5 text-xs border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {loadingUsers ? '불러오는 중...' : '새로고침'}
                        </button>
                    </div>

                    {/* 검색 / Role 필터 */}
                    <div className="flex flex-col gap-2 mb-4">
                        <div className="flex gap-2">
                            <input
                                type="text"
                                placeholder="이름, 이메일 검색"
                                value={userSearch}
                                onChange={(e) => setUserSearch(e.target.value)}
                                className="flex-1 min-w-0 px-3 py-1.5 text-xs border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                            />
                            <select
                                value={userRoleFilter}
                                onChange={(e) => setUserRoleFilter(e.target.value as 'all' | 'free' | 'pro' | 'premium' | 'admin')}
                                className="px-2 py-1.5 text-xs border border-slate-200 rounded-lg bg-white"
                            >
                                <option value="all">전체</option>
                                <option value="free">일반</option>
                                <option value="pro">Pro</option>
                                <option value="premium">Premium</option>
                                <option value="admin">관리자</option>
                            </select>
                        </div>
                    </div>

                    {/* 모바일: 카드 레이아웃 */}
                    <div className="space-y-2 sm:hidden">
                        {loadingUsers ? (
                            <p className="text-center text-slate-400 py-6">유저 목록을 불러오는 중...</p>
                        ) : filteredUsers.length === 0 ? (
                            <p className="text-center text-slate-400 py-6">조건에 맞는 유저가 없습니다.</p>
                        ) : (
                            filteredUsers.slice(0, 10).map((u) => (
                                <div key={u.id} className="p-3 border border-slate-100 rounded-xl bg-slate-50/50">
                                    <div className="flex items-center justify-between gap-2 mb-1">
                                        <span className="text-xs font-medium text-slate-900 truncate">
                                            {u.displayName || u.email || '(이름 없음)'}
                                        </span>
                                        <select
                                            value={u.role || 'free'}
                                            onChange={(e) => handleChangeUserRole(u.id, e.target.value)}
                                            disabled={updatingUserId === u.id}
                                            className="border border-slate-200 rounded-lg px-2 py-1 text-[10px] bg-white"
                                        >
                                            <option value="free">일반</option>
                                            <option value="pro">Pro</option>
                                            <option value="premium">Premium</option>
                                            <option value="admin">관리자</option>
                                        </select>
                                    </div>
                                    <p className="text-[10px] text-slate-500 truncate">{u.email || '—'}</p>
                                </div>
                            ))
                        )}
                        {filteredUsers.length > 10 && (
                            <p className="text-center text-xs text-slate-400 py-2">+{filteredUsers.length - 10}명 더 있음</p>
                        )}
                    </div>

                    {/* 데스크탑: 테이블 레이아웃 */}
                    <div className="hidden sm:block overflow-x-auto -mx-3">
                        <table className="min-w-full text-sm text-slate-700">
                            <thead className="bg-slate-50 text-xs uppercase text-slate-500">
                                <tr>
                                    <th className="px-3 py-2 text-left">사용자</th>
                                    <th className="px-3 py-2 text-left">이메일</th>
                                    <th className="px-3 py-2 text-left">등급</th>
                                    <th className="px-3 py-2 text-left">최근 로그인</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loadingUsers ? (
                                    <tr>
                                        <td colSpan={4} className="px-3 py-6 text-center text-slate-400">
                                            유저 목록을 불러오는 중입니다...
                                        </td>
                                    </tr>
                                ) : filteredUsers.length === 0 ? (
                                    <tr>
                                        <td colSpan={4} className="px-3 py-6 text-center text-slate-400">
                                            조건에 맞는 유저가 없습니다.
                                        </td>
                                    </tr>
                                ) : (
                                    filteredUsers.map((u) => (
                                        <tr key={u.id} className="border-t border-slate-100 hover:bg-slate-50">
                                            <td className="px-3 py-2">
                                                <div className="flex flex-col">
                                                    <span className="font-medium text-slate-900">
                                                        {u.displayName || u.email || '(이름 없음)'}
                                                    </span>
                                                    <span className="text-[11px] text-slate-400">ID: {u.id}</span>
                                                </div>
                                            </td>
                                            <td className="px-3 py-2 text-xs text-slate-600">{u.email || '—'}</td>
                                            <td className="px-3 py-2">
                                                <select
                                                    value={u.role || 'free'}
                                                    onChange={(e) => handleChangeUserRole(u.id, e.target.value)}
                                                    disabled={updatingUserId === u.id}
                                                    className="border border-slate-200 rounded-lg px-2 py-1 text-xs bg-white"
                                                >
                                                    <option value="free">일반</option>
                                                    <option value="pro">Pro</option>
                                                    <option value="premium">Premium</option>
                                                    <option value="admin">관리자</option>
                                                </select>
                                            </td>
                                            <td className="px-3 py-2 text-xs text-slate-500">
                                                {u.lastLogin && (u.lastLogin as any).toDate
                                                    ? (u.lastLogin as any).toDate().toLocaleDateString('ko-KR')
                                                    : '—'}
                                            </td>
                                        </tr>
                                    ))
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>

                {/* Sync Logs Section */}
                <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-6">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
                        <div>
                            <h3 className="text-base font-bold text-slate-900">동기화 로그</h3>
                            <p className="text-xs text-slate-500 mt-1">
                                최근 Bizinfo / K-Startup / 상세분석 실행 이력을 확인합니다.
                            </p>
                        </div>
                        <div className="flex items-center gap-2">
                            <select
                                value={logDateFilter}
                                onChange={(e) => {
                                    setLogDateFilter(e.target.value as 'today' | '7days' | '30days' | 'all');
                                    setLogPage(1);
                                }}
                                className="px-2 py-1.5 text-xs border border-slate-200 rounded-lg bg-white"
                            >
                                <option value="today">오늘</option>
                                <option value="7days">최근 7일</option>
                                <option value="30days">최근 30일</option>
                                <option value="all">전체</option>
                            </select>
                            <button
                                type="button"
                                onClick={fetchSyncLogs}
                                disabled={loadingLogs}
                                className="px-3 py-1.5 text-xs border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                                {loadingLogs ? '불러오는 중...' : '새로고침'}
                            </button>
                        </div>
                    </div>

                    {/* 날짜 필터링 로직 */}
                    {(() => {
                        const now = new Date();
                        const filterLogs = syncLogs.filter((log) => {
                            if (logDateFilter === 'all') return true;
                            if (!log.triggeredAt) return false;
                            const logDate = log.triggeredAt.toDate ? log.triggeredAt.toDate() : new Date(log.triggeredAt);
                            const diffMs = now.getTime() - logDate.getTime();
                            const diffDays = diffMs / (1000 * 60 * 60 * 24);
                            if (logDateFilter === 'today') return diffDays < 1;
                            if (logDateFilter === '7days') return diffDays < 7;
                            if (logDateFilter === '30days') return diffDays < 30;
                            return true;
                        });

                        const totalLogPages = Math.max(1, Math.ceil(filterLogs.length / LOGS_PER_PAGE));
                        const safeLogPage = Math.min(logPage, totalLogPages);
                        const startIdx = (safeLogPage - 1) * LOGS_PER_PAGE;
                        const paginatedLogs = filterLogs.slice(startIdx, startIdx + LOGS_PER_PAGE);

                        const getTypeLabel = (type: string) => {
                            if (type === 'scrape_bizinfo') return '기업마당 동기화';
                            if (type === 'scrape_k_startup') return 'K-Startup 동기화';
                            if (type === 'analyze_scraped_grants_batch') return '상세 분석 배치';
                            if (type === 'scheduled_scrape_bizinfo') return '스케줄 Bizinfo';
                            return type;
                        };

                        return (
                            <>
                                {/* 모바일: 카드 레이아웃 */}
                                <div className="space-y-2 sm:hidden">
                                    {loadingLogs ? (
                                        <p className="text-center text-slate-400 py-6">로그를 불러오는 중...</p>
                                    ) : paginatedLogs.length === 0 ? (
                                        <p className="text-center text-slate-400 py-6">해당 기간의 로그가 없습니다.</p>
                                    ) : (
                                        paginatedLogs.map((log) => (
                                            <div key={log.id} className="p-3 border border-slate-100 rounded-xl bg-slate-50/50">
                                                <div className="flex items-center justify-between gap-2 mb-2">
                                                    <span className="text-[11px] font-medium text-slate-800">
                                                        {getTypeLabel(log.type)}
                                                    </span>
                                                    <span
                                                        className={`px-2 py-0.5 rounded-full border text-[10px] font-semibold ${log.status === 'success'
                                                            ? 'bg-green-50 text-green-700 border-green-100'
                                                            : log.status === 'error'
                                                                ? 'bg-red-50 text-red-700 border-red-100'
                                                                : 'bg-slate-50 text-slate-600 border-slate-200'
                                                            }`}
                                                    >
                                                        {log.status === 'success' ? '성공' : log.status === 'error' ? '실패' : log.status}
                                                    </span>
                                                </div>
                                                <p className="text-[10px] text-slate-500 mb-1">{formatLogTime(log.triggeredAt)}</p>
                                                {log.meta && (typeof log.meta.newCount === 'number' || typeof log.meta.updatedCount === 'number' || typeof log.meta.skippedCount === 'number') && (
                                                    <p className="text-[10px] text-slate-600 mb-1">
                                                        신규 {typeof log.meta.newCount === 'number' ? log.meta.newCount : 0} / 업데이트 {typeof log.meta.updatedCount === 'number' ? log.meta.updatedCount : 0} / 스킵 {typeof log.meta.skippedCount === 'number' ? log.meta.skippedCount : 0}
                                                    </p>
                                                )}
                                                {log.message && (
                                                    <p className="text-[11px] text-slate-600 line-clamp-2">{log.message}</p>
                                                )}
                                            </div>
                                        ))
                                    )}
                                </div>

                                {/* 데스크탑: 테이블 레이아웃 */}
                                <div className="hidden sm:block overflow-x-auto -mx-3">
                                    <table className="min-w-full text-xs text-slate-700">
                                        <thead className="bg-slate-50 text-[11px] uppercase text-slate-500">
                                            <tr>
                                                <th className="px-3 py-2 text-left">시간</th>
                                                <th className="px-3 py-2 text-left">작업</th>
                                                <th className="px-3 py-2 text-left">상태</th>
                                                <th className="px-3 py-2 text-left">메시지</th>
                                                <th className="px-3 py-2 text-left">업서트</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {loadingLogs ? (
                                                <tr>
                                                    <td colSpan={5} className="px-3 py-6 text-center text-slate-400">
                                                        로그를 불러오는 중입니다...
                                                    </td>
                                                </tr>
                                            ) : paginatedLogs.length === 0 ? (
                                                <tr>
                                                    <td colSpan={5} className="px-3 py-6 text-center text-slate-400">
                                                        해당 기간의 로그가 없습니다.
                                                    </td>
                                                </tr>
                                            ) : (
                                                paginatedLogs.map((log) => (
                                                    <tr key={log.id} className="border-t border-slate-100 hover:bg-slate-50">
                                                        <td className="px-3 py-2 align-top whitespace-nowrap">
                                                            {formatLogTime(log.triggeredAt)}
                                                        </td>
                                                        <td className="px-3 py-2 align-top">
                                                            <span className="text-[11px] font-medium text-slate-800">
                                                                {getTypeLabel(log.type)}
                                                            </span>
                                                        </td>
                                                        <td className="px-3 py-2 align-top">
                                                            <span
                                                                className={`inline-flex items-center px-2 py-0.5 rounded-full border text-[10px] font-semibold ${log.status === 'success'
                                                                    ? 'bg-green-50 text-green-700 border-green-100'
                                                                    : log.status === 'error'
                                                                        ? 'bg-red-50 text-red-700 border-red-100'
                                                                        : 'bg-slate-50 text-slate-600 border-slate-200'
                                                                    }`}
                                                            >
                                                                {log.status === 'success' ? '성공' : log.status === 'error' ? '실패' : log.status}
                                                            </span>
                                                        </td>
                                                        <td className="px-3 py-2 align-top max-w-xs">
                                                            <p className="text-[11px] text-slate-600 line-clamp-2">
                                                                {log.message || '—'}
                                                            </p>
                                                        </td>
                                                        <td className="px-3 py-2 align-top whitespace-nowrap text-[11px] text-slate-600">
                                                            {log.meta && (typeof log.meta.newCount === 'number' || typeof log.meta.updatedCount === 'number' || typeof log.meta.skippedCount === 'number')
                                                                ? `${typeof log.meta.newCount === 'number' ? log.meta.newCount : 0}/${typeof log.meta.updatedCount === 'number' ? log.meta.updatedCount : 0}/${typeof log.meta.skippedCount === 'number' ? log.meta.skippedCount : 0}`
                                                                : '—'}
                                                        </td>
                                                    </tr>
                                                ))
                                            )}
                                        </tbody>
                                    </table>
                                </div>

                                {/* 페이지네이션 */}
                                {!loadingLogs && filterLogs.length > LOGS_PER_PAGE && (
                                    <div className="mt-3 pt-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
                                        <span>
                                            {safeLogPage} / {totalLogPages} 페이지 · 총 {filterLogs.length}건
                                        </span>
                                        <div className="flex gap-2">
                                            <button
                                                type="button"
                                                onClick={() => setLogPage((p) => Math.max(1, p - 1))}
                                                disabled={safeLogPage === 1}
                                                className="px-2 py-1 rounded border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                                            >
                                                이전
                                            </button>
                                            <button
                                                type="button"
                                                onClick={() => setLogPage((p) => Math.min(totalLogPages, p + 1))}
                                                disabled={safeLogPage === totalLogPages}
                                                className="px-2 py-1 rounded border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                                            >
                                                다음
                                            </button>
                                        </div>
                                    </div>
                                )}
                            </>
                        );
                    })()}
                </div>
            </div>
        </div>
    );
}