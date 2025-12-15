import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { httpsCallable } from 'firebase/functions';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db, functions } from '../lib/firebase';

type PaymentStatus = 'loading' | 'success' | 'error';

type ConfirmPaymentRequest = {
    paymentKey: string;
    orderId: string;
    amount: number;
};

type ConfirmPaymentResponse = {
    success: boolean;
    message?: string;
};

type UserDocData = {
    role?: string;
};

export default function PaymentSuccess() {
    const [searchParams] = useSearchParams();
    const [status, setStatus] = useState<PaymentStatus>('loading');
    const [message, setMessage] = useState('결제 확인 중입니다...');
    const [role, setRole] = useState<string | null>(null);

    const paymentKey = searchParams.get('paymentKey') || '';
    const orderId = searchParams.get('orderId') || '';
    const amountParam = searchParams.get('amount') || '';
    const amount = amountParam ? Number(amountParam) : Number.NaN;

    const isValidQuery = !!paymentKey && !!orderId && !!amountParam && !Number.isNaN(amount);

    useEffect(() => {
        if (!isValidQuery) return;

        let hasConfirmed = false;
        const unsubscribeAuth = onAuthStateChanged(auth, async (user) => {
            if (hasConfirmed) return;

            if (!user) {
                setStatus('error');
                setMessage('로그인이 필요합니다. 로그인 후 다시 시도해 주세요.');
                return;
            }

            hasConfirmed = true;
            setStatus('loading');
            setMessage('결제 확인 중입니다...');

            try {
                const confirmPayment = httpsCallable<ConfirmPaymentRequest, ConfirmPaymentResponse>(
                    functions,
                    'confirmPayment'
                );
                const result = await confirmPayment({ paymentKey, orderId, amount });

                if (result.data && result.data.success) {
                    setStatus('success');
                    setMessage(result.data.message || '결제가 완료되었습니다.');

                    try {
                        const snap = await getDoc(doc(db, 'users', user.uid));
                        const userData = snap.data() as UserDocData | undefined;
                        setRole(userData?.role || null);
                    } catch {
                        setRole(null);
                    }

                    return;
                }

                setStatus('error');
                setMessage(result.data?.message || '결제 확인에 실패했습니다.');
            } catch (error: unknown) {
                setStatus('error');
                setMessage(error instanceof Error ? error.message : '결제 확인 중 오류가 발생했습니다.');
            }
        });

        return () => unsubscribeAuth();
    }, [isValidQuery, paymentKey, orderId, amount]);

    if (!isValidQuery) {
        return (
            <div className="max-w-2xl mx-auto px-4 py-12">
                <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-8">
                    <h2 className="text-2xl font-bold text-slate-900">결제 확인 실패</h2>
                    <p className="mt-2 text-slate-600">결제 정보가 올바르지 않습니다.</p>

                    <div className="mt-8 flex flex-col sm:flex-row gap-3">
                        <Link
                            to="/pricing"
                            className="px-4 py-2 rounded-xl bg-primary-600 text-white font-bold text-center hover:bg-primary-700"
                        >
                            멤버십으로 이동
                        </Link>
                        <Link
                            to="/profile"
                            className="px-4 py-2 rounded-xl bg-slate-100 text-slate-700 font-bold text-center hover:bg-slate-200"
                        >
                            프로필로 이동
                        </Link>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-2xl mx-auto px-4 py-12">
            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-8">
                <h2 className="text-2xl font-bold text-slate-900">결제 완료</h2>
                <p className="mt-2 text-slate-600">{message}</p>

                <div className="mt-6 rounded-xl bg-slate-50 border border-slate-200 p-4 text-sm text-slate-700 space-y-1">
                    <div><span className="font-semibold">주문번호:</span> {orderId}</div>
                    <div><span className="font-semibold">금액:</span> {Number.isNaN(amount) ? '-' : `${amount.toLocaleString()}원`}</div>
                    <div><span className="font-semibold">paymentKey:</span> {paymentKey}</div>
                    {role && (
                        <div><span className="font-semibold">현재 등급:</span> {role}</div>
                    )}
                </div>

                <div className="mt-8 flex flex-col sm:flex-row gap-3">
                    <Link
                        to="/profile"
                        className="px-4 py-2 rounded-xl bg-primary-600 text-white font-bold text-center hover:bg-primary-700"
                    >
                        프로필로 이동
                    </Link>
                    <Link
                        to="/grants"
                        className="px-4 py-2 rounded-xl bg-slate-100 text-slate-700 font-bold text-center hover:bg-slate-200"
                    >
                        공고 보러가기
                    </Link>
                </div>

                {status === 'error' && (
                    <p className="mt-4 text-xs text-slate-500">
                        결제 승인 확인은 로그인 상태가 필요합니다. 결제를 완료했는데도 Pro로 변경되지 않았다면 로그인 후 다시 시도해 주세요.
                    </p>
                )}
            </div>
        </div>
    );
}
