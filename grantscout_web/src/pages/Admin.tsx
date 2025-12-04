import { useState } from 'react';
import { Download, ShieldAlert } from 'lucide-react';
import { functions } from '../lib/firebase';
import { httpsCallable } from 'firebase/functions';

export default function Admin() {
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState('');

    const handleScrape = async () => {
        setLoading(true);
        setMessage('');
        try {
            const scrapeFn = httpsCallable(functions, 'scrapeBizinfo');
            const result = await scrapeFn();
            const data = result.data as { message: string };
            setMessage(data.message);
        } catch (error: unknown) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            setMessage('스크래핑 실패: ' + errorMessage);
        } finally {
            setLoading(false);
        }
    };

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

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {/* Scraping Card */}
                <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm">
                    <h3 className="text-lg font-bold text-slate-900 mb-2 flex items-center gap-2">
                        <Download size={20} className="text-blue-600" />
                        데이터 수집 에이전트
                    </h3>
                    <p className="text-sm text-slate-500 mb-6">
                        기업마당(Bizinfo)에서 최신 지원사업 공고를 수집하여 Firestore에 저장합니다.
                    </p>

                    <button
                        onClick={handleScrape}
                        disabled={loading}
                        className="w-full py-3 bg-slate-900 text-white font-bold rounded-xl hover:bg-slate-800 disabled:opacity-50 transition-colors flex items-center justify-center gap-2"
                    >
                        {loading ? '에이전트 실행 중...' : 'Bizinfo 스크래핑 실행'}
                    </button>

                    {message && (
                        <div className={`mt-4 p-3 rounded-lg text-sm ${message.includes('실패') ? 'bg-red-50 text-red-600' : 'bg-green-50 text-green-600'}`}>
                            {message}
                        </div>
                    )}
                </div>

                {/* Placeholder for other admin features */}
                <div className="bg-slate-50 rounded-2xl border border-slate-200 p-6 flex items-center justify-center text-slate-400 border-dashed">
                    <p>추가 관리 기능 준비 중...</p>
                </div>
            </div>
        </div>
    );
}
