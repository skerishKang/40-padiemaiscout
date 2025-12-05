import { useState, useEffect } from 'react';
import { ShieldAlert, Users, CreditCard, Database, RefreshCw, Clock } from 'lucide-react';
import { db, functions } from '../lib/firebase';
import { collection, getCountFromServer, query, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';

interface SchedulerConfig {
    enabled: boolean;
    intervalMinutes: number;
    lastRunAt?: string | null;
    lastRunResult?: string | null;
    lastRunError?: string | null;
}

export default function Admin() {
    const [stats, setStats] = useState({ totalUsers: 0, proUsers: 0 });
    const [syncing, setSyncing] = useState(false);
    const [syncResult, setSyncResult] = useState<string | null>(null);
    const [schedulerConfig, setSchedulerConfig] = useState<SchedulerConfig | null>(null);
    const [loadingScheduler, setLoadingScheduler] = useState(false);
    const [savingScheduler, setSavingScheduler] = useState(false);
    const [schedulerMessage, setSchedulerMessage] = useState<string | null>(null);

    const handleSync = async () => {
        setSyncing(true);
        setSyncResult(null);
        try {
            const scrapeBizinfo = httpsCallable(functions, 'scrapeBizinfo');
            const result = await scrapeBizinfo();
            const data = result.data as any;
            setSyncResult(`성공: ${data.message}`);
        } catch (error: any) {
            console.error("Sync failed:", error);
            setSyncResult(`실패: ${error.message}`);
        } finally {
            setSyncing(false);
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
            } as any);
            const data = result.data as any;
            if (data && data.success && data.config) {
                setSchedulerConfig({
                    enabled: !!data.config.enabled,
                    intervalMinutes: Number(data.config.intervalMinutes) || schedulerConfig.intervalMinutes,
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

    const formatLastRunAt = (value?: string | null) => {
        if (!value) return '-';
        const date = new Date(value);
        if (isNaN(date.getTime())) return value;
        return date.toLocaleString('ko-KR', { timeZone: 'Asia/Seoul' });
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
            } catch (error) {
                console.error("Error fetching stats:", error);
            }
        };
        const init = async () => {
            await fetchStats();
            await fetchSchedulerConfig();
        };

        init();
    }, []);

    return (
        <div className="max-w-4xl mx-auto p-6">
            <div className="flex items-center gap-3 mb-8">
                <div className="p-3 bg-slate-900 text-white rounded-xl">
                    <ShieldAlert size={24} />
                </div>
                <div>
                    <h1 className="text-2xl font-bold text-slate-900">관리자 대시보드</h1>
                    <p className="text-slate-500">시스템 관리 및 데이터 수집을 수행합니다.</p>
                </div>
            </div>

            {/* Stats Overview */}
            <div className="grid grid-cols-2 gap-4 mb-8">
                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
                    <div className="p-3 bg-blue-50 text-blue-600 rounded-xl">
                        <Users size={24} />
                    </div>
                    <div>
                        <p className="text-sm text-slate-500 font-medium">총 가입 유저</p>
                        <p className="text-2xl font-bold text-slate-900">{stats.totalUsers}명</p>
                    </div>
                </div>
                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm flex items-center gap-4">
                    <div className="p-3 bg-purple-50 text-purple-600 rounded-xl">
                        <CreditCard size={24} />
                    </div>
                    <div>
                        <p className="text-sm text-slate-500 font-medium">Pro 멤버십</p>
                        <p className="text-2xl font-bold text-slate-900">{stats.proUsers}명</p>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 gap-6">
                {/* Data Collection Section */}
                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-green-50 text-green-600 rounded-lg">
                                <Database size={20} />
                            </div>
                            <div>
                                <h3 className="font-bold text-slate-900">데이터 수집 및 동기화</h3>
                                <p className="text-sm text-slate-500">외부 사이트(기업마당 등)에서 공고를 수집합니다.</p>
                            </div>
                        </div>
                        <button
                            onClick={handleSync}
                            disabled={syncing}
                            className="px-4 py-2 bg-slate-900 text-white font-bold rounded-xl hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                        >
                            {syncing ? (
                                <>
                                    <RefreshCw size={18} className="animate-spin" />
                                    동기화 중...
                                </>
                            ) : (
                                <>
                                    <RefreshCw size={18} />
                                    데이터 동기화
                                </>
                            )}
                        </button>
                    </div>
                    {syncResult && (
                        <div className={`p-4 rounded-xl text-sm ${syncResult.includes('성공') ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                            {syncResult}
                        </div>
                    )}
                </div>

                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm mt-6">
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-3">
                            <div className="p-2 bg-purple-50 text-purple-600 rounded-lg">
                                <Clock size={20} />
                            </div>
                            <div>
                                <h3 className="font-bold text-slate-900">스케줄러 설정</h3>
                                <p className="text-sm text-slate-500">기업마당 자동 수집 주기와 활성화를 관리합니다.</p>
                            </div>
                        </div>
                        <button
                            onClick={fetchSchedulerConfig}
                            disabled={loadingScheduler}
                            className="px-3 py-1.5 text-sm border border-slate-200 rounded-xl text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                            {loadingScheduler ? '불러오는 중...' : '새로고침'}
                        </button>
                    </div>

                    {schedulerConfig && (
                        <div className="space-y-4">
                            <div className="flex items-center justify-between">
                                <span className="text-sm text-slate-700">스케줄러 활성화</span>
                                <button
                                    type="button"
                                    onClick={() => setSchedulerConfig({
                                        ...schedulerConfig,
                                        enabled: !schedulerConfig.enabled,
                                    })}
                                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${schedulerConfig.enabled ? 'bg-green-500' : 'bg-slate-300'}`}
                                >
                                    <span
                                        className={`inline-block h-5 w-5 transform rounded-full bg-white transition-transform ${schedulerConfig.enabled ? 'translate-x-5' : 'translate-x-1'}`}
                                    />
                                </button>
                            </div>

                            <div className="flex items-center gap-3">
                                <div className="flex-1">
                                    <p className="text-sm text-slate-700 mb-1">실행 간격(분)</p>
                                    <input
                                        type="number"
                                        min={15}
                                        max={1440}
                                        value={schedulerConfig.intervalMinutes}
                                        onChange={(e) => setSchedulerConfig({
                                            ...schedulerConfig,
                                            intervalMinutes: Number(e.target.value) || 0,
                                        })}
                                        className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                                    />
                                </div>
                                <div className="text-xs text-slate-400">
                                    <p>최소 15분, 최대 1440분(24시간)</p>
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4 text-xs text-slate-500 bg-slate-50 rounded-xl p-3">
                                <div>
                                    <p className="font-medium text-slate-600 mb-1">마지막 실행 시각</p>
                                    <p>{formatLastRunAt(schedulerConfig.lastRunAt)}</p>
                                </div>
                                <div>
                                    <p className="font-medium text-slate-600 mb-1">마지막 결과</p>
                                    <p className="line-clamp-2">{schedulerConfig.lastRunResult || schedulerConfig.lastRunError || '-'}</p>
                                </div>
                            </div>

                            <div className="flex items-center justify-end gap-2 pt-2">
                                <button
                                    type="button"
                                    onClick={handleSaveScheduler}
                                    disabled={savingScheduler}
                                    className="px-4 py-2 bg-slate-900 text-white text-sm font-bold rounded-xl hover:bg-slate-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    {savingScheduler ? '저장 중...' : '설정 저장'}
                                </button>
                            </div>
                        </div>
                    )}

                    {!schedulerConfig && !loadingScheduler && (
                        <p className="text-sm text-slate-500">스케줄러 설정을 불러오지 못했습니다. 새로고침을 눌러 다시 시도해주세요.</p>
                    )}

                    {schedulerMessage && (
                        <div className="mt-4 text-xs text-slate-600 bg-slate-50 rounded-xl px-3 py-2">
                            {schedulerMessage}
                        </div>
                    )}
                </div>

                {/* Placeholder for other admin features */}
                <div className="bg-slate-50 rounded-2xl border border-slate-200 p-12 flex flex-col items-center justify-center text-slate-400 border-dashed">
                    <ShieldAlert size={48} className="mb-4 opacity-20" />
                    <p className="text-lg font-medium">추가 관리 기능 준비 중...</p>
                    <p className="text-sm">유저 관리, 결제 내역 확인 등의 기능이 추가될 예정입니다.</p>
                </div>
            </div>
        </div>
    );
}