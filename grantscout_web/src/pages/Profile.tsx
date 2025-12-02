import React, { useState, useEffect } from 'react';
import { Save, Building2, Calendar, DollarSign, Users, MapPin, Award } from 'lucide-react';
import { auth, db } from '../lib/firebase';
import { signInAnonymously, onAuthStateChanged } from 'firebase/auth';
import { doc, setDoc, getDoc } from 'firebase/firestore';

export default function Profile() {
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState('');
    const [formData, setFormData] = useState({
        industry: '',
        stage: '',
        revenue: '',
        employees: '',
        location: '',
        certifications: [] as string[],
    });

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (user) => {
            if (user) {
                // Load existing profile
                const docRef = doc(db, 'users', user.uid);
                const docSnap = await getDoc(docRef);
                if (docSnap.exists()) {
                    setFormData(docSnap.data() as any);
                }
            } else {
                // Sign in anonymously if not logged in
                signInAnonymously(auth).catch(console.error);
            }
        });
        return () => unsubscribe();
    }, []);

    const handleChange = (e: React.ChangeEvent<HTMLSelectElement | HTMLInputElement>) => {
        const { name, value } = e.target;
        setFormData(prev => ({ ...prev, [name]: value }));
    };

    const handleCheckboxChange = (value: string) => {
        setFormData(prev => {
            const certs = prev.certifications || [];
            if (certs.includes(value)) {
                return { ...prev, certifications: certs.filter(c => c !== value) };
            } else {
                return { ...prev, certifications: [...certs, value] };
            }
        });
    };

    const handleSave = async () => {
        setLoading(true);
        setMessage('');
        try {
            const user = auth.currentUser;
            if (!user) throw new Error("No user found");

            await setDoc(doc(db, 'users', user.uid), formData, { merge: true });
            setMessage('성공적으로 저장되었습니다!');
        } catch (error) {
            console.error("Save error:", error);
            setMessage('저장에 실패했습니다.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="max-w-2xl mx-auto bg-white rounded-xl shadow-sm border border-slate-200 p-6 lg:p-8">
            <div className="mb-8">
                <h2 className="text-2xl font-bold text-slate-900">기업 프로필</h2>
                <p className="text-slate-500 mt-1">정확한 정보를 입력할수록 매칭 정확도가 올라갑니다.</p>
            </div>

            <div className="space-y-6">
                {/* Industry */}
                <div>
                    <label htmlFor="industry" className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2">
                        <Building2 size={16} /> 업종
                    </label>
                    <select
                        id="industry"
                        name="industry"
                        value={formData.industry}
                        onChange={handleChange}
                        className="w-full p-3 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary-100 focus:border-primary-500 outline-none"
                    >
                        <option value="">선택해주세요</option>
                        <option value="IT/SW">IT / 소프트웨어</option>
                        <option value="Manufacturing">제조업</option>
                        <option value="Service">서비스업</option>
                        <option value="Bio">바이오 / 헬스케어</option>
                        <option value="Other">기타</option>
                    </select>
                </div>

                {/* Stage */}
                <div>
                    <label htmlFor="stage" className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2">
                        <Calendar size={16} /> 업력 (창업일 기준)
                    </label>
                    <select
                        id="stage"
                        name="stage"
                        value={formData.stage}
                        onChange={handleChange}
                        className="w-full p-3 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary-100 focus:border-primary-500 outline-none"
                    >
                        <option value="">선택해주세요</option>
                        <option value="pre">예비창업자</option>
                        <option value="under_3">3년 미만 (초기창업)</option>
                        <option value="3_to_7">3년 ~ 7년 (도약기)</option>
                        <option value="over_7">7년 이상</option>
                    </select>
                </div>

                {/* Revenue */}
                <div>
                    <label htmlFor="revenue" className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2">
                        <DollarSign size={16} /> 연 매출액
                    </label>
                    <select
                        id="revenue"
                        name="revenue"
                        value={formData.revenue}
                        onChange={handleChange}
                        className="w-full p-3 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary-100 focus:border-primary-500 outline-none"
                    >
                        <option value="">선택해주세요</option>
                        <option value="under_100m">1억원 미만</option>
                        <option value="100m_to_1b">1억 ~ 10억원</option>
                        <option value="1b_to_5b">10억 ~ 50억원</option>
                        <option value="over_5b">50억원 이상</option>
                    </select>
                </div>

                {/* Employees */}
                <div>
                    <label htmlFor="employees" className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2">
                        <Users size={16} /> 직원 수
                    </label>
                    <select
                        id="employees"
                        name="employees"
                        value={formData.employees}
                        onChange={handleChange}
                        className="w-full p-3 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary-100 focus:border-primary-500 outline-none"
                    >
                        <option value="">선택해주세요</option>
                        <option value="under_5">5인 미만</option>
                        <option value="5_to_10">5 ~ 10인</option>
                        <option value="10_to_50">10 ~ 50인</option>
                        <option value="over_50">50인 이상</option>
                    </select>
                </div>

                {/* Location */}
                <div>
                    <label htmlFor="location" className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2">
                        <MapPin size={16} /> 소재지
                    </label>
                    <select
                        id="location"
                        name="location"
                        value={formData.location}
                        onChange={handleChange}
                        className="w-full p-3 bg-slate-50 border border-slate-200 rounded-lg focus:ring-2 focus:ring-primary-100 focus:border-primary-500 outline-none"
                    >
                        <option value="">선택해주세요</option>
                        <option value="Seoul">서울</option>
                        <option value="Gyeonggi">경기/인천</option>
                        <option value="Other">그 외 지역</option>
                    </select>
                </div>

                {/* Certifications */}
                <div>
                    <label className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-3">
                        <Award size={16} /> 보유 인증 (가산점 항목)
                    </label>
                    <div className="grid grid-cols-2 gap-3">
                        {['벤처기업', '이노비즈', '메인비즈', '기업부설연구소', '여성기업', '청년창업'].map((cert) => (
                            <label key={cert} className="flex items-center gap-2 p-3 border border-slate-200 rounded-lg cursor-pointer hover:bg-slate-50">
                                <input
                                    type="checkbox"
                                    checked={formData.certifications?.includes(cert)}
                                    onChange={() => handleCheckboxChange(cert)}
                                    className="w-4 h-4 text-primary-600 rounded focus:ring-primary-500"
                                />
                                <span className="text-sm text-slate-700">{cert}</span>
                            </label>
                        ))}
                    </div>
                </div>

                <div className="pt-4">
                    <button
                        onClick={handleSave}
                        disabled={loading}
                        className="w-full py-3 bg-primary-600 text-white font-bold rounded-lg hover:bg-primary-700 disabled:opacity-50 transition-colors flex items-center justify-center gap-2"
                    >
                        {loading ? '저장 중...' : <><Save size={20} /> 저장하기</>}
                    </button>
                    {message && (
                        <p className={`mt-3 text-center text-sm ${message.includes('실패') ? 'text-red-500' : 'text-green-600'}`}>
                            {message}
                        </p>
                    )}
                </div>
            </div>
        </div>
    );
}
