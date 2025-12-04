import { loadTossPayments } from '@tosspayments/payment-sdk';

const clientKey = 'test_ck_D5GePWvyJnrK0W0k6q8gLzN97Eoq'; // Test Client Key

export const requestPayment = async (userEmail: string, userName: string) => {
    try {
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
