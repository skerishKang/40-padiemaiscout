import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Building2, Calendar, DollarSign, Users, MapPin, Award, Save } from 'lucide-react';
import { auth, db } from '../lib/firebase';
import { signOut, onAuthStateChanged, type User as FirebaseUser } from 'firebase/auth';
import { doc, getDoc, setDoc } from 'firebase/firestore';

export default function Profile() {
    const navigate = useNavigate();
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
        scrapeCount: 0,
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
            }
        });
        return () => unsubscribe();
    }, []);

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
                role: 'free',
                scrapeCount: 0
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

    // Auto-save logic removed

    const handleSave = async () => {
        // Immediate save
        if (!user) return;
        setLoading(true);
        try {
            await setDoc(doc(db, 'users', user.uid), formData, { merge: true });
            setMessage('저장되었습니다! 대시보드로 이동합니다...');

            // Navigate to Dashboard after a short delay
            setTimeout(() => {
                navigate('/');
            }, 1000);
        } catch (error) {
            console.error("Save error:", error);
            setMessage('저장에 실패했습니다.');
        } finally {
            setLoading(false);
        }
    };

    // 추천 준비도 체크리스트용 파생 상태
    const readinessItems = [
        {
            key: 'industry',
            label: '업종',
            done: !!formData.industry,
        },
        {
            key: 'stage',
            label: '업력 (창업일 기준)',
            done: !!formData.stage,
        },
        {
            key: 'revenue',
            label: '연 매출액',
            done: !!formData.revenue,
        },
        {
            key: 'employees',
            label: '직원 수',
            done: !!formData.employees,
        },
        {
            key: 'location',
            label: '소재지',
            done: !!formData.location,
        },
        {
            key: 'certifications',
            label: '보유 인증(있다면 가산점)',
            done: (formData.certifications?.length || 0) > 0,
        },
    ];

    const completedReadinessCount = readinessItems.filter(item => item.done).length;
    const totalReadinessCount = readinessItems.length;
    const readinessRatio = totalReadinessCount > 0 ? completedReadinessCount / totalReadinessCount : 0;

    return (
        <div className="max-w-2xl mx-auto bg-white rounded-xl shadow-sm border border-slate-200 p-6 lg:p-8">
            <div className="mb-8 flex justify-between items-center">
                <div>
                    <h2 className="text-2xl font-bold text-slate-900">기업 프로필</h2>
                    <p className="text-slate-500 mt-1">정확한 정보를 입력할수록 매칭 정확도가 올라갑니다.</p>
                </div>
                <div className="text-right flex items-center gap-4">
                    {/* Saving Indicator Removed */}

                    {user && !user.isAnonymous && (
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
                                <button onClick={handleLogout} className="text-xs text-red-500 hover:underline cursor-pointer">로그아웃</button>
                            </div>
                        </div>
                    )}
                </div>
            </div>

            <div className="space-y-6">
                {/* 추천 준비도 체크리스트 */}
                <div className="border border-slate-200 rounded-xl p-4 bg-slate-50/80">
                    <div className="flex items-center justify-between mb-3 gap-4">
                        <div>
                            <p className="text-xs font-semibold text-slate-500">추천 준비도 체크리스트</p>
                            <p className="text-xs text-slate-600 mt-1">
                                AI가 우리 회사를 더 잘 이해할 수 있도록 아래 항목들을 채워주세요.
                            </p>
                        </div>
                        <div className="text-right shrink-0">
                            <p className="text-xs font-medium text-slate-500">
                                {completedReadinessCount}/{totalReadinessCount} 단계 완료
                            </p>
                            <div className="mt-1 w-24 h-2 rounded-full bg-slate-200 overflow-hidden">
                                <div
                                    className="h-full rounded-full bg-blue-500 transition-all"
                                    style={{ width: `${Math.max(8, readinessRatio * 100)}%` }}
                                />
                            </div>
                        </div>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                        {readinessItems.map(item => (
                            <div
                                key={item.key}
                                className={`flex items-center justify-between px-3 py-2 rounded-lg text-xs border ${item.done
                                    ? 'bg-blue-50 border-blue-100 text-blue-800'
                                    : 'bg-white border-slate-200 text-slate-600'
                                    }`}
                            >
                                <span className="flex items-center gap-1.5">
                                    <span
                                        className={`inline-block w-1.5 h-1.5 rounded-full ${item.done ? 'bg-blue-500' : 'bg-slate-300'}`}
                                    />
                                    {item.label}
                                </span>
                                <span className={item.done ? 'text-[10px] font-semibold text-blue-700' : 'text-[10px] text-slate-400'}>
                                    {item.done ? '완료' : '입력 필요'}
                                </span>
                            </div>
                        ))}
                    </div>
                </div>

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

                <div className="pt-6 border-t border-slate-100 flex flex-col sm:flex-row gap-3">
                    <button
                        onClick={handleSave}
                        disabled={loading}
                        className="flex-1 py-3 bg-blue-600 text-white font-bold rounded-xl hover:bg-blue-700 disabled:opacity-50 transition-colors flex items-center justify-center gap-2 shadow-sm"
                    >
                        {loading ? '저장 중...' : <><Save size={20} /> 저장하기</>}
                    </button>

                    <button
                        onClick={() => {
                            if (window.confirm('입력한 내용을 모두 초기화하시겠습니까?')) {
                                setFormData({
                                    industry: '',
                                    stage: '',
                                    revenue: '',
                                    employees: '',
                                    location: '',
                                    certifications: [],
                                    role: formData.role, // Keep role
                                    scrapeCount: formData.scrapeCount // Keep usage stats
                                });
                                setMessage('초기화되었습니다. (저장하려면 저장 버튼을 누르세요)');
                            }
                        }}
                        className="px-6 py-3 bg-white text-slate-600 font-bold rounded-xl border border-slate-200 hover:bg-slate-50 transition-colors"
                    >
                        초기화
                    </button>

                    <button
                        onClick={async () => {
                            if (window.confirm('정말로 기업 정보를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.')) {
                                setLoading(true);
                                try {
                                    if (user) {
                                        // Reset to empty state in DB
                                        const emptyData = {
                                            industry: '',
                                            stage: '',
                                            revenue: '',
                                            employees: '',
                                            location: '',
                                            certifications: [],
                                            role: 'free',
                                            scrapeCount: 0
                                        };
                                        await setDoc(doc(db, 'users', user.uid), emptyData);
                                        setFormData(emptyData);
                                        setMessage('기업 정보가 삭제되었습니다.');
                                    }
                                } catch (e) {
                                    console.error(e);
                                    setMessage('삭제 실패');
                                } finally {
                                    setLoading(false);
                                }
                            }
                        }}
                        className="px-6 py-3 bg-red-50 text-red-600 font-bold rounded-xl border border-red-100 hover:bg-red-100 transition-colors"
                    >
                        삭제
                    </button>
                </div>
                {message && (
                    <p className={`mt-3 text-center text-sm font-medium ${message.includes('실패') || message.includes('삭제') ? 'text-red-500' : 'text-blue-600'}`}>
                        {message}
                    </p>
                )}
            </div>
        </div>
    );
}
