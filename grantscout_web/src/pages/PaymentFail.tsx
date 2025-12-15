import { Link, useSearchParams } from 'react-router-dom';

export default function PaymentFail() {
    const [searchParams] = useSearchParams();

    const code = searchParams.get('code') || '';
    const message = searchParams.get('message') || '';
    const orderId = searchParams.get('orderId') || '';

    return (
        <div className="max-w-2xl mx-auto px-4 py-12">
            <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-8">
                <h2 className="text-2xl font-bold text-slate-900">결제 실패</h2>
                <p className="mt-2 text-slate-600">결제가 완료되지 않았습니다.</p>

                <div className="mt-6 rounded-xl bg-slate-50 border border-slate-200 p-4 text-sm text-slate-700 space-y-1">
                    {orderId && (
                        <div><span className="font-semibold">주문번호:</span> {orderId}</div>
                    )}
                    {code && (
                        <div><span className="font-semibold">코드:</span> {code}</div>
                    )}
                    {message && (
                        <div><span className="font-semibold">메시지:</span> {message}</div>
                    )}
                    {!code && !message && (
                        <div>실패 상세 정보가 없습니다.</div>
                    )}
                </div>

                <div className="mt-8 flex flex-col sm:flex-row gap-3">
                    <Link
                        to="/pricing"
                        className="px-4 py-2 rounded-xl bg-primary-600 text-white font-bold text-center hover:bg-primary-700"
                    >
                        다시 시도하기
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
