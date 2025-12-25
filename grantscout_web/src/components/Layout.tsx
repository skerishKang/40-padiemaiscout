import React, { useState, useEffect } from 'react';
import { Outlet, Link, useLocation, useNavigate } from 'react-router-dom';
import { LayoutDashboard, MessageSquare, FileText, Menu, X, UserCircle, LogOut, CreditCard, ShieldAlert, Bell, Search } from 'lucide-react';
import { onAuthStateChanged, type User } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../lib/firebase';
import clsx from 'clsx';

interface SidebarItemProps {
    icon: React.ComponentType<{ size: number; className?: string }>;
    label: string;
    to: string;
    active?: boolean;
    onClick?: () => void;
}

function SidebarItem({ icon: Icon, label, to, active, onClick }: SidebarItemProps) {
    return (
        <Link
            to={to}
            onClick={onClick}
            className={clsx(
                "flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all duration-300 cursor-pointer",
                active
                    ? "bg-primary-100 text-primary-700 shadow-inner"
                    : "text-slate-600 hover:bg-slate-100/50 hover:text-slate-900"
            )}
        >
            <Icon size={20} className={clsx("transition-transform duration-300", active && "scale-110")} />
            <span>{label}</span>
        </Link>
    );
}

export default function Layout() {
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const [isMobileSearchOpen, setIsMobileSearchOpen] = useState(false);
    const [isProfileMenuOpen, setIsProfileMenuOpen] = useState(false);
    const [isNotificationMenuOpen, setIsNotificationMenuOpen] = useState(false);
    const [viewMode, setViewMode] = useState<'desktop' | 'mobile'>(() => {
        if (typeof window === 'undefined') return 'desktop';
        return window.innerWidth < 1024 ? 'mobile' : 'desktop';
    });
    const [user, setUser] = useState<User | null>(null);
    const [userRole, setUserRole] = useState<string | null>(null);
    const [headerSearch, setHeaderSearch] = useState('');
    const location = useLocation();
    const navigate = useNavigate();

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
            setUser(currentUser);

            if (currentUser) {
                (async () => {
                    try {
                        const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
                        const data = userDoc.data() as any;
                        setUserRole((data && data.role) || 'free');
                    } catch (error) {
                        console.error("레이아웃에서 유저 프로필 로드 중 오류:", error);
                        setUserRole(null);
                    }
                })();
            } else {
                setUserRole(null);
            }
        });
        return () => unsubscribe();
    }, []);

    useEffect(() => {
        setIsProfileMenuOpen(false);
        setIsNotificationMenuOpen(false);
        setIsMobileSearchOpen(false);
        setIsMobileMenuOpen(false);
    }, [location.pathname]);

    useEffect(() => {
        if (typeof window === 'undefined') return;
        const handleResize = () => {
            setViewMode(window.innerWidth < 1024 ? 'mobile' : 'desktop');
        };
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    const navItems = [
        { icon: MessageSquare, label: '스카우터', to: '/' },
        { icon: LayoutDashboard, label: '공고목록', to: '/grants' },
        { icon: FileText, label: '기업 프로필', to: '/profile' },
        { icon: CreditCard, label: '멤버십', to: '/pricing' },
    ];

    const isNavActive = (to: string) => {
        if (to === '/') {
            return location.pathname === '/' || location.pathname === '/chat';
        }
        return location.pathname === to;
    };

    // Admin Check
    const adminEmails = [
        'padiemipu@gmail.com',
        'paidemipu@gmail.com', // Typo fallback
        'limone@example.com',
        'admin@mdreader.com'
    ];
    const isAdminByEmail = !!(user?.email && adminEmails.includes(user.email));
    const isAdminByRole = userRole === 'admin';
    const isAdmin = isAdminByEmail || isAdminByRole;

    if (isAdmin) {
        navItems.push({ icon: ShieldAlert, label: '관리자', to: '/admin' });
    }

    const goToGrantsSearch = (rawQuery: string) => {
        const query = rawQuery.trim();
        const current = new URLSearchParams(location.search);
        const source = current.get('source');

        const params = new URLSearchParams();
        if (source) params.set('source', source);
        if (query) params.set('q', query);

        const qs = params.toString();
        navigate(qs ? `/grants?${qs}` : '/grants');
    };

    const profileInitial = (user?.displayName || user?.email || 'U').trim().charAt(0).toUpperCase();
    const profileLabel = (user?.displayName || user?.email?.split('@')[0] || '').trim();

    return (
        <div className="min-h-screen bg-slate-50 flex flex-col">
            {/* Top Header (Global) */}
            <header className="bg-white/80 backdrop-blur-md border-b border-white/20 h-16 flex items-center gap-3 px-4 lg:px-6 sticky top-0 z-50 shadow-sm">
                <div className="flex items-center gap-3 shrink-0">
                    {/* Mobile Menu Button */}
                    <button
                        className={clsx("p-2 -ml-2 text-slate-600 hover:bg-slate-100/50 rounded-lg lg:hidden")}
                        onClick={() => setIsMobileMenuOpen(true)}
                        title="메뉴 열기"
                    >
                        <Menu size={24} />
                    </button>

                    <Link to="/" className="flex items-center gap-2 font-bold text-xl text-slate-900 tracking-tight">
                        <img src="/logo-main.png" alt="파디 스카우터" className="w-8 h-8 rounded-lg shadow-sm object-cover" />
                        <span className="hidden sm:inline bg-clip-text text-transparent bg-gradient-to-r from-slate-900 to-slate-700">파디 스카우터</span>
                        <span className="hidden md:inline text-xs font-semibold text-slate-500">지원사업 스카우터</span>
                    </Link>
                </div>

                <div className="flex-1 lg:hidden" />

                <div className="hidden lg:flex items-center gap-4 flex-1 px-4">
                    <nav className="flex items-center gap-1">
                        {navItems.map((item) => (
                            <Link
                                key={`top-${item.to}`}
                                to={item.to}
                                className={clsx(
                                    "px-3 py-2 rounded-xl text-sm font-semibold transition-colors",
                                    isNavActive(item.to)
                                        ? "bg-primary-100 text-primary-700"
                                        : "text-slate-600 hover:bg-slate-100/60 hover:text-slate-900"
                                )}
                            >
                                {item.label}
                            </Link>
                        ))}
                    </nav>

                    <form
                        className="flex items-center gap-2 flex-1 max-w-xl"
                        onSubmit={(e) => {
                            e.preventDefault();
                            goToGrantsSearch(headerSearch);
                        }}
                    >
                        <div className="flex items-center gap-2 rounded-xl px-3 py-2">
                            <Search size={18} className="text-slate-400" />
                            <input
                                value={headerSearch}
                                onChange={(e) => setHeaderSearch(e.target.value)}
                                placeholder="키워드로 공고 빠른 검색"
                                className="w-full bg-transparent outline-none text-sm text-slate-700 placeholder:text-slate-400"
                            />
                            <button
                                type="submit"
                                className="px-3 py-2 rounded-xl text-sm font-semibold transition-colors text-slate-600 hover:bg-slate-100/60 hover:text-slate-900"
                            >
                                검색
                            </button>
                        </div>
                    </form>
                </div>

                <div className="flex items-center gap-2 sm:gap-4 shrink-0">
                    <button
                        className="p-2 text-slate-600 hover:bg-slate-100/50 rounded-lg lg:hidden"
                        onClick={() => setIsMobileSearchOpen(true)}
                        title="공고 검색"
                    >
                        <Search size={20} />
                    </button>

                    {user && (
                        <div className="relative">
                            <button
                                className="p-2 text-slate-600 hover:bg-slate-100/50 rounded-lg"
                                onClick={() => setIsNotificationMenuOpen(!isNotificationMenuOpen)}
                                title="알림"
                            >
                                <Bell size={20} />
                            </button>
                            {isNotificationMenuOpen && (
                                <>
                                    <div
                                        className="fixed inset-0 z-40"
                                        onClick={() => setIsNotificationMenuOpen(false)}
                                    />
                                    <div className="absolute right-0 mt-2 w-80 max-w-[calc(100vw-2rem)] bg-white rounded-2xl shadow-xl border border-slate-100 overflow-hidden z-50">
                                        <div className="px-4 py-3 border-b border-slate-50">
                                            <p className="text-sm font-extrabold text-slate-900">알림</p>
                                            <p className="text-xs text-slate-500">마감 임박 / 새로운 매칭 알림은 준비 중입니다.</p>
                                        </div>
                                        <div className="px-4 py-4 text-sm text-slate-600">
                                            <div className="rounded-xl bg-slate-50 border border-slate-100 p-3">
                                                <p className="font-semibold text-slate-800">알림 기능 안내</p>
                                                <p className="mt-1 text-xs text-slate-500">곧 마감 임박, 신규 공고 매칭, 결제/크레딧 관련 알림을 제공할 예정입니다.</p>
                                            </div>
                                        </div>
                                    </div>
                                </>
                            )}
                        </div>
                    )}

                    {/* User Profile / Login */}
                    {user ? (
                        <div className="relative">
                            <button
                                onClick={() => setIsProfileMenuOpen(!isProfileMenuOpen)}
                                className="flex items-center gap-2 p-1.5 pr-3 rounded-full border border-slate-200 bg-white hover:bg-slate-50 transition-colors shadow-sm cursor-pointer"
                            >
                                {user.photoURL ? (
                                    <img
                                        src={user.photoURL}
                                        alt="프로필"
                                        className="w-8 h-8 rounded-full object-cover border border-slate-200"
                                        referrerPolicy="no-referrer"
                                    />
                                ) : (
                                    <div className="w-8 h-8 bg-slate-100 text-slate-700 rounded-full flex items-center justify-center font-bold text-sm border border-slate-200">
                                        {profileInitial}
                                    </div>
                                )}
                                {profileLabel && (
                                    <span className="text-sm font-medium text-slate-700 hidden sm:block">
                                        {profileLabel}
                                    </span>
                                )}
                            </button>

                            {/* Profile Dropdown */}
                            {isProfileMenuOpen && (
                                <>
                                    <div
                                        className="fixed inset-0 z-40"
                                        onClick={() => setIsProfileMenuOpen(false)}
                                    />
                                    <div className="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-xl border border-slate-100 py-1 z-50 animate-in fade-in slide-in-from-top-2 duration-200">
                                        <div className="px-4 py-3 border-b border-slate-50">
                                            <p className="text-sm font-bold text-slate-900">내 계정</p>
                                            <p className="text-xs text-slate-500 truncate">{user.email}</p>
                                        </div>
                                        <Link
                                            to="/grants?source=user-upload"
                                            className="flex items-center gap-2 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 hover:text-primary-600 transition-colors"
                                            onClick={() => setIsProfileMenuOpen(false)}
                                        >
                                            <LayoutDashboard size={16} />
                                            내 분석 내역
                                        </Link>
                                        <Link
                                            to="/profile"
                                            className="flex items-center gap-2 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 hover:text-primary-600 transition-colors"
                                            onClick={() => setIsProfileMenuOpen(false)}
                                        >
                                            <FileText size={16} />
                                            기업 프로필
                                        </Link>
                                        <button
                                            className="w-full flex items-center gap-2 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 hover:text-primary-600 transition-colors text-left"
                                            onClick={() => {
                                                setIsProfileMenuOpen(false);
                                                window.location.href = '/profile';
                                            }}
                                        >
                                            <UserCircle size={16} />
                                            설정
                                        </button>
                                        <div className="border-t border-slate-50 my-1"></div>
                                        <button
                                            onClick={() => {
                                                auth.signOut();
                                                setIsProfileMenuOpen(false);
                                            }}
                                            className="w-full flex items-center gap-2 px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors text-left"
                                        >
                                            <LogOut size={16} />
                                            로그아웃
                                        </button>
                                    </div>
                                </>
                            )}
                        </div>
                    ) : (
                        <Link to="/login" className="px-4 py-2 bg-slate-900 text-white rounded-xl text-sm font-semibold hover:bg-slate-800 transition-colors shadow-sm">
                            로그인
                        </Link>
                    )}
                </div>
            </header>

            {isMobileSearchOpen && (
                <div className="fixed inset-0 z-50 flex items-start justify-center bg-black/30 backdrop-blur-sm p-4">
                    <div className="w-full max-w-md bg-white rounded-2xl shadow-2xl border border-white/40 overflow-hidden">
                        <div className="px-4 py-3 border-b border-slate-100 flex items-center justify-between">
                            <p className="text-sm font-extrabold text-slate-900">공고 검색</p>
                            <button
                                className="p-2 -mr-2 text-slate-400 hover:text-slate-600"
                                onClick={() => setIsMobileSearchOpen(false)}
                                aria-label="검색 닫기"
                            >
                                <X size={20} />
                            </button>
                        </div>
                        <form
                            className="p-4"
                            onSubmit={(e) => {
                                e.preventDefault();
                                setIsMobileSearchOpen(false);
                                goToGrantsSearch(headerSearch);
                            }}
                        >
                            <div className="flex items-center gap-2 rounded-2xl bg-slate-50 border border-slate-200 px-3 py-2">
                                <Search size={18} className="text-slate-400" />
                                <input
                                    value={headerSearch}
                                    onChange={(e) => setHeaderSearch(e.target.value)}
                                    placeholder="키워드를 입력하세요"
                                    className="w-full bg-transparent outline-none text-sm text-slate-700 placeholder:text-slate-400"
                                    autoFocus
                                />
                            </div>
                            <button
                                type="submit"
                                className="mt-3 w-full py-2.5 rounded-xl bg-slate-900 text-white text-sm font-bold hover:bg-slate-800 transition-colors"
                            >
                                검색
                            </button>
                        </form>
                    </div>
                </div>
            )}

            <div className="flex flex-1 overflow-hidden relative bg-slate-50">
                {/* Sidebar Navigation */}
                <aside className={clsx(
                    "w-64 bg-white/80 backdrop-blur-xl border-r border-white/20 flex-col hidden lg:flex shadow-[4px_0_24px_-12px_rgba(0,0,0,0.1)] z-10"
                )}>
                    <nav className="flex-1 p-4 space-y-2">
                        {navItems.map((item) => (
                            <SidebarItem
                                key={item.to}
                                {...item}
                                active={isNavActive(item.to)}
                            />
                        ))}
                    </nav>

                    <div className="p-4 border-t border-slate-100/50">
                        <div className="bg-gradient-to-br from-slate-50 to-white rounded-2xl p-4 border border-white/50 shadow-sm">
                            <h4 className="font-semibold text-slate-900 text-sm mb-1">도움이 필요하신가요?</h4>
                            <p className="text-xs text-slate-500 mb-3">전문 컨설턴트와 상담해보세요.</p>
                            <button className="w-full py-2 bg-white border border-slate-200 text-slate-700 text-xs font-medium rounded-xl hover:bg-slate-100 hover:border-slate-300 hover:text-slate-900 transition-colors shadow-sm cursor-pointer">
                                고객센터 문의
                            </button>
                        </div>
                    </div>
                </aside>

                {/* Mobile Menu Overlay */}
                {isMobileMenuOpen && (
                    <div className="fixed inset-0 z-50 flex">
                        <div className="fixed inset-0 bg-black/20 backdrop-blur-sm" onClick={() => setIsMobileMenuOpen(false)} />
                        <div className="relative w-72 bg-white/90 backdrop-blur-xl h-full shadow-2xl flex flex-col animate-in slide-in-from-left duration-200 border-r border-white/20">
                            <div className="h-16 flex items-center justify-between px-6 border-b border-slate-100/50">
                                <span className="font-bold text-lg text-slate-900">메뉴</span>
                                <button onClick={() => setIsMobileMenuOpen(false)} className="p-2 -mr-2 text-slate-400 hover:text-slate-600" aria-label="메뉴 닫기">
                                    <X size={24} />
                                </button>
                            </div>
                            <nav className="flex-1 p-4 space-y-2">
                                {navItems.map((item) => (
                                    <SidebarItem
                                        key={item.to}
                                        {...item}
                                        active={isNavActive(item.to)}
                                        onClick={() => setIsMobileMenuOpen(false)}
                                    />
                                ))}
                            </nav>
                            {user && (
                                <div className="p-4 border-t border-slate-100/50">
                                    <button onClick={() => auth.signOut()} className="flex items-center gap-3 px-4 py-3 text-slate-600 hover:bg-red-50 hover:text-red-600 rounded-xl w-full transition-colors cursor-pointer">
                                        <LogOut size={20} />
                                        <span className="font-medium">로그아웃</span>
                                    </button>
                                </div>
                            )}
                        </div>
                    </div>
                )}

                {/* Main Content Area */}
                <main className={clsx(
                    "flex-1 overflow-hidden relative transition-all duration-300",
                    viewMode === 'mobile'
                        ? "flex justify-center items-stretch bg-slate-100 p-0"
                        : "flex justify-center items-start bg-slate-50 p-4"
                )}>
                    <div className={clsx(
                        "transition-all duration-300 flex flex-col",
                        viewMode === 'mobile'
                            ? "w-full h-full overflow-hidden relative bg-white border border-slate-200"
                            : "h-full w-full max-w-7xl mx-auto"
                    )}>

                        {/* Content Scroll Area */}
                        <div className={clsx(
                            "flex-1 scrollbar-hide",
                            viewMode === 'mobile'
                                ? "pt-3 px-0 pb-0 bg-white"
                                : "bg-slate-50",
                            // Chat 페이지(/)에서는 내부 스크롤을 사용하므로 Layout 스크롤을 막음 (Chrome 이슈 해결)
                            location.pathname === '/' ? "overflow-hidden" : "overflow-y-auto"
                        )}>
                            <Outlet />
                        </div>

                        {/* Mobile Bottom Nav */}
                        {viewMode === 'mobile' && (
                            <div className="bg-white border-t border-slate-200 px-6 py-4 flex justify-between items-center shrink-0 z-40 pb-8">
                                {navItems.map((item) => {
                                    const Icon = item.icon;
                                    const isActive = isNavActive(item.to);
                                    return (
                                        <Link key={item.to} to={item.to} className="flex flex-col items-center gap-1.5 group">
                                            <div className={clsx(
                                                "p-1.5 rounded-xl transition-all duration-300",
                                                isActive ? "bg-primary-100 text-primary-600 shadow-inner" : "text-slate-400 group-hover:text-slate-600"
                                            )}>
                                                <Icon size={24} className={clsx("transition-transform duration-300", isActive && "scale-110")} />
                                            </div>
                                            <span className={clsx("text-[10px] font-medium transition-colors", isActive ? "text-primary-600" : "text-slate-400")}>
                                                {item.label}
                                            </span>
                                        </Link>
                                    )
                                })}
                            </div>
                        )}
                    </div>
                </main>
            </div>
        </div>
    );
}
