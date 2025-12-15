import { loadTossPayments } from '@tosspayments/payment-sdk';

const clientKey = import.meta.env.VITE_TOSS_CLIENT_KEY;

export const requestPayment = async (userEmail: string, userName: string) => {
    try {
        if (!clientKey) {
            throw new Error('VITE_TOSS_CLIENT_KEY가 설정되지 않았습니다.');
        }

        const tossPayments = await loadTossPayments(clientKey);

        await tossPayments.requestPayment('카드', {
            amount: 9900,
            orderId: 'ORDER_' + new Date().getTime(),
            orderName: 'GrantScout Pro (월간 구독)',
            customerName: userName || 'GrantScout User',
            customerEmail: userEmail,
            successUrl: window.location.origin + '/payment/success',
            failUrl: window.location.origin + '/payment/fail',
        });
    } catch (error) {
        console.error("Payment failed:", error);
        throw error;
    }
};
