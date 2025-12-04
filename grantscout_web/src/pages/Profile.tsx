import { useState, useEffect } from 'react';
import { Building2, Calendar, DollarSign, Users, MapPin, Award, Download, Save } from 'lucide-react';
import { auth, db, googleProvider, functions } from '../lib/firebase';
import { signInWithPopup, signOut, onAuthStateChanged, type User as FirebaseUser } from 'firebase/auth';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';

export default function Profile() {
    const [loading, setLoading] = useState(false);
    const [message, setMessage] = useState('');
    const [user, setUser] = useState<FirebaseUser | null>(null);
    const [formData, setFormData] = useState({
        industry: '',
        stage: '',
        revenue: '',
        employees: '',
        location: '',
        certifications: [] as string[],
        role: 'free', // Default role
    });

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
            setUser(currentUser);
            if (currentUser) {
                // Load existing profile
                const docRef = doc(db, 'users', currentUser.uid);
                const docSnap = await getDoc(docRef);
                if (docSnap.exists()) {
                    setFormData(prev => ({ ...prev, ...docSnap.data() }));
                }
            } else {
                // Sign in anonymously if not logged in
                // signInAnonymously(auth).catch(console.error); // Optional: Disable auto-anonymous if we want forced login
            }
        });
        return () => unsubscribe();
    }, []);

    const handleGoogleLogin = async () => {
        try {
            await signInWithPopup(auth, googleProvider);
        } catch (error) {
            console.error("Login failed:", error);
            setMessage('로그인에 실패했습니다.');
        }
    };

    const handleLogout = async () => {
        try {
            await signOut(auth);
            setFormData({
                industry: '',
                stage: '',
                revenue: '',
                employees: '',
                location: '',
                certifications: [],
                role: 'free'
            });
            setMessage('로그아웃 되었습니다.');
        } catch (error) {
            console.error("Logout failed:", error);
        }
    };

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
            <div className="mb-8 flex justify-between items-center">
                <div>
                    <h2 className="text-2xl font-bold text-slate-900">기업 프로필</h2>
                    <p className="text-slate-500 mt-1">정확한 정보를 입력할수록 매칭 정확도가 올라갑니다.</p>
                </div>
                <div className="text-right">
                    {user && !user.isAnonymous ? (
                        <div className="flex flex-col items-end gap-2">
                            <div className="flex items-center gap-2">
                                {user.photoURL && (
                                    <img
                                        src={user.photoURL}
                                        alt="Profile"
                                        className="w-8 h-8 rounded-full"
                                    />
                                )}
                                <span className="text-sm font-medium text-slate-700">{user.displayName}</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <span
                                    className={`px-2 py-1 text-xs font-bold rounded ${formData.role === 'pro' ? 'bg-purple-100 text-purple-700' : 'bg-gray-100 text-gray-600'}`}>
                                    {formData.role === 'pro' ? 'PRO Plan' : 'Free Plan'}
                                </span>
                                <button onClick={handleLogout} className="text-xs text-red-500 hover:underline">로그아웃</button>
                            </div>
                        </div>
                    ) : (
                        <button
                            onClick={handleGoogleLogin}
                            className="px-4 py-2 bg-white border border-slate-300 rounded-lg text-slate-700 text-sm font-medium hover:bg-slate-50 flex items-center gap-2"
                        >
                            <img
                                src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg"
                                className="w-4 h-4"
                                alt="Google"
                            />
                            Google로 로그인
                        </button>
                    )}
                </div>
            </div>

            <div className="space-y-6">
                {/* Industry */}
                <div>
                    <label
                        htmlFor="industry"
                        className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2"
                    >
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
                    <label
                        htmlFor="stage"
                        className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2"
                    >
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
                    <label
                        htmlFor="revenue"
                        className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2"
                    >
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
                    <label
                        htmlFor="employees"
                        className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2"
                    >
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
                    <label
                        htmlFor="location"
                        className="flex items-center gap-2 text-sm font-medium text-slate-700 mb-2"
                    >
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
                    <div className="mt-8 pt-8 border-t border-slate-200">
                        <h3 className="text-lg font-bold text-slate-900 mb-4">관리자 기능</h3>
                        <button
                            onClick={async () => {
                                try {
                                    const scrapeFn = httpsCallable(functions, 'scrapeBizinfo');
                                    const result = await scrapeFn();
                                    const data = result.data as { message: string };
                                    alert(data.message);
                                } catch (error: unknown) {
                                    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
                                    alert('스크래핑 실패: ' + errorMessage);
                                }
                            }}
                            className="flex items-center gap-2 px-4 py-2 bg-slate-800 text-white rounded-xl hover:bg-slate-700 transition-colors"
                        >
                            <Download size={18} />
                            Bizinfo 공고 가져오기 (Agent)
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
