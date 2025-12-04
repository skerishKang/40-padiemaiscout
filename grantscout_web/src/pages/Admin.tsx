import { useState, useEffect } from 'react';
import { ShieldAlert, Users, CreditCard } from 'lucide-react';
import { db } from '../lib/firebase';
import { collection, getCountFromServer, query, where } from 'firebase/firestore';

export default function Admin() {
    const [stats, setStats] = useState({ totalUsers: 0, proUsers: 0 });

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

        fetchStats();
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