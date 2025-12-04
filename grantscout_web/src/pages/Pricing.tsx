
import { Check, Zap } from 'lucide-react';
import { requestPayment } from '../lib/payment';
import { auth } from '../lib/firebase';
import { useNavigate } from 'react-router-dom';

export default function Pricing() {
    const navigate = useNavigate();

    const handleUpgrade = async () => {
        const user = auth.currentUser;
        if (!user) {
            alert('로그인이 필요합니다.');
            navigate('/profile'); // Redirect to login
            return;
        }
        try {
            await requestPayment(user.email || '', user.displayName || '');
        } catch {
            // Error handled in payment.ts
        }
    };

    return (
        <div className="max-w-5xl mx-auto px-4 py-12">
            <div className="text-center mb-12">
                <h2 className="text-3xl font-bold text-slate-900">요금제 안내</h2>
                <p className="text-slate-500 mt-2">기업 성장에 필요한 최적의 플랜을 선택하세요.</p>
            </div>

            <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
                {/* Free Plan */}
                <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-8 flex flex-col">
                    <div className="mb-4">
                        <span className="text-sm font-bold text-slate-500 uppercase tracking-wider">Free</span>
                        <h3 className="text-4xl font-bold text-slate-900 mt-2">₩0 <span className="text-lg font-normal text-slate-500">/ 월</span></h3>
                    </div>
                    <ul className="space-y-4 mb-8 flex-1">
                        <li className="flex items-center gap-3 text-slate-600">
                            <Check size={20} className="text-green-500" /> 기본 공고 검색
                        </li>
                        <li className="flex items-center gap-3 text-slate-600">
                            <Check size={20} className="text-green-500" /> 관심 공고 저장 (최대 5개)
                        </li>
                        <li className="flex items-center gap-3 text-slate-600">
                            <Check size={20} className="text-green-500" /> 기본 알림 서비스
                        </li>
                    </ul>
                    <button className="w-full py-3 bg-slate-100 text-slate-700 font-bold rounded-xl hover:bg-slate-200 transition-colors">
                        현재 이용 중
                    </button>
                </div>

                {/* Pro Plan */}
                <div className="bg-white rounded-2xl shadow-lg border-2 border-primary-500 p-8 flex flex-col relative overflow-hidden">
                    <div className="absolute top-0 right-0 bg-primary-500 text-white text-xs font-bold px-3 py-1 rounded-bl-xl">
                        POPULAR
                    </div>
                    <div className="mb-4">
                        <span className="text-sm font-bold text-primary-600 uppercase tracking-wider">Pro</span>
                        <h3 className="text-4xl font-bold text-slate-900 mt-2">₩9,900 <span className="text-lg font-normal text-slate-500">/ 월</span></h3>
                    </div>
                    <ul className="space-y-4 mb-8 flex-1">
                        <li className="flex items-center gap-3 text-slate-700 font-medium">
                            <Check size={20} className="text-primary-500" /> <span className="font-bold">무제한</span> 공고 검색 및 저장
                        </li>
                        <li className="flex items-center gap-3 text-slate-700 font-medium">
                            <Check size={20} className="text-primary-500" /> <span className="font-bold">AI 맞춤형</span> 공고 추천
                        </li>
                        <li className="flex items-center gap-3 text-slate-700 font-medium">
                            <Check size={20} className="text-primary-500" /> 합격 확률 분석 리포트
                        </li>
                        <li className="flex items-center gap-3 text-slate-700 font-medium">
                            <Check size={20} className="text-primary-500" /> 담당자 직통 연락처 열람
                        </li>
                    </ul>
                    <button
                        onClick={handleUpgrade}
                        className="w-full py-3 bg-primary-600 text-white font-bold rounded-xl hover:bg-primary-700 transition-colors flex items-center justify-center gap-2 shadow-lg shadow-primary-200"
                    >
                        <Zap size={20} /> Pro 업그레이드
                    </button>
                </div>
            </div>
        </div>
    );
}
