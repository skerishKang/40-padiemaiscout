import React, { useState, useEffect } from 'react';
import { Outlet, Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, MessageSquare, FileText, Menu, X, UserCircle, Smartphone, Monitor, LogIn, LogOut, CreditCard, ShieldAlert } from 'lucide-react';
import { onAuthStateChanged, type User } from 'firebase/auth';
import { auth } from '../lib/firebase';
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
    const [isProfileMenuOpen, setIsProfileMenuOpen] = useState(false);
    const [viewMode, setViewMode] = useState<'desktop' | 'mobile'>('desktop');
    const [user, setUser] = useState<User | null>(null);
    const location = useLocation();

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
            setUser(currentUser);
        });
        return () => unsubscribe();
    }, []);

    const navItems = [
        { icon: MessageSquare, label: '스카우터', to: '/' },
        { icon: LayoutDashboard, label: '공고', to: '/grants' },
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
    const isAdmin = user?.email && [
        'padiemipu@gmail.com',
        'paidemipu@gmail.com', // Typo fallback
        'limone@example.com',
        'admin@mdreader.com'
    ].includes(user.email);

    if (isAdmin) {
        navItems.push({ icon: ShieldAlert, label: '관리자', to: '/admin' });
    }

    return (
        <div className="min-h-screen bg-slate-50 flex flex-col">
            {/* Top Header (Global) */}
            <header className="bg-white/80 backdrop-blur-md border-b border-white/20 h-16 flex items-center justify-between px-4 lg:px-6 sticky top-0 z-50 shadow-sm">
                <div className="flex items-center gap-3">
                    {/* Mobile Menu Button */}
                    <button
                        className={clsx("p-2 -ml-2 text-slate-600 hover:bg-slate-100/50 rounded-lg lg:hidden", viewMode === 'mobile' && "!block")}
                        onClick={() => setIsMobileMenuOpen(true)}
                        title="메뉴 열기"
                    >
                        <Menu size={24} />
                    </button>

                    <Link to="/" className="flex items-center gap-2 font-bold text-xl text-slate-900 tracking-tight">
                        <img src="/logo-main.png" alt="padiemaiscout" className="w-8 h-8 rounded-lg shadow-sm object-cover" />
                        <span className="hidden sm:inline bg-clip-text text-transparent bg-gradient-to-r from-slate-900 to-slate-700">padiemaiscout</span>
                    </Link>
                </div>

                <div className="flex items-center gap-2 sm:gap-4">
                    {/* View Mode Toggle */}
                    <div className="hidden lg:flex items-center bg-slate-100/50 backdrop-blur-sm rounded-xl p-1 border border-white/20 shadow-inner">
                        <button
                            onClick={() => setViewMode('desktop')}
                            className={clsx(
                                "flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-300 cursor-pointer",
                                viewMode === 'desktop'
                                    ? "bg-white text-slate-900 shadow-sm ring-1 ring-black/5"
                                    : "text-slate-500 hover:text-slate-700"
                            )}
                        >
                            <Monitor size={16} />
                            Desktop
                        </button>
                        <button
                            onClick={() => setViewMode('mobile')}
                            className={clsx(
                                "flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all duration-300 cursor-pointer",
                                viewMode === 'mobile'
                                    ? "bg-white text-slate-900 shadow-sm ring-1 ring-black/5"
                                    : "text-slate-500 hover:text-slate-700"
                            )}
                        >
                            <Smartphone size={16} />
                            Mobile
                        </button>
                    </div>

                    <div className="h-6 w-px bg-slate-200 hidden lg:block" />

                    {/* User Profile / Login */}
                    {user ? (
                        <div className="relative">
                            <button
                                onClick={() => setIsProfileMenuOpen(!isProfileMenuOpen)}
                                className="flex items-center gap-2 p-1.5 pr-3 rounded-full border border-white/20 bg-white/50 hover:bg-white/80 transition-all backdrop-blur-sm shadow-sm cursor-pointer"
                            >
                                <div className="w-8 h-8 bg-gradient-to-br from-primary-100 to-primary-200 text-primary-700 rounded-full flex items-center justify-center shadow-inner">
                                    <UserCircle size={20} />
                                </div>
                                <span className="text-sm font-medium text-slate-700 hidden sm:block">
                                    {user.email?.split('@')[0]}
                                </span>
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
                                            to="/profile"
                                            className="flex items-center gap-2 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 hover:text-primary-600 transition-colors"
                                            onClick={() => setIsProfileMenuOpen(false)}
                                        >
                                            <FileText size={16} />
                                            기업 정보 설정
                                        </Link>
                                        <button
                                            className="w-full flex items-center gap-2 px-4 py-2.5 text-sm text-slate-700 hover:bg-slate-50 hover:text-primary-600 transition-colors text-left"
                                            onClick={() => {
                                                setIsProfileMenuOpen(false);
                                                // Navigate to profile or a dedicated settings modal in future
                                                window.location.href = '/profile';
                                            }}
                                        >
                                            <UserCircle size={16} />
                                            개인 정보 설정
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
                        <Link to="/login" className="flex items-center gap-2 px-4 py-2 bg-slate-900 text-white rounded-xl text-sm font-medium hover:bg-slate-800 transition-all shadow-lg shadow-slate-900/20">
                            <LogIn size={16} />
                            <span className="hidden sm:inline">로그인</span>
                        </Link>
                    )}
                </div>
            </header>

            <div className="flex flex-1 overflow-hidden relative bg-slate-50/50">
                {/* Sidebar Navigation */}
                <aside className={clsx(
                    "w-64 bg-white/80 backdrop-blur-xl border-r border-white/20 flex-col hidden lg:flex shadow-[4px_0_24px_-12px_rgba(0,0,0,0.1)] z-10",
                    viewMode === 'mobile' && "!hidden"
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
                        ? "flex justify-center items-center bg-gradient-to-br from-sky-200 via-rose-200 to-amber-200 p-4"
                        : "flex justify-center items-start bg-gradient-to-br from-sky-100 via-rose-100 to-amber-100 p-8"
                )}>
                    <div className={clsx(
                        "transition-all duration-300 flex flex-col",
                        viewMode === 'mobile'
                            ? "w-full max-w-md h-full rounded-3xl overflow-hidden relative bg-white/70 border border-white/40 backdrop-blur-2xl shadow-[0_32px_80px_rgba(15,23,42,0.65)]"
                            : "h-full w-full max-w-7xl mx-auto"
                    )}>

                        {/* Content Scroll Area */}
                        <div className={clsx(
                            "flex-1 scrollbar-hide",
                            viewMode === 'mobile'
                                ? "pt-6 px-0 pb-0 bg-transparent"
                                : "bg-slate-50/30",
                            // Chat 페이지(/)에서는 내부 스크롤을 사용하므로 Layout 스크롤을 막음 (Chrome 이슈 해결)
                            location.pathname === '/' ? "overflow-hidden" : "overflow-y-auto"
                        )}>
                            <Outlet />
                        </div>

                        {/* Mobile Bottom Nav */}
                        {viewMode === 'mobile' && (
                            <div className="bg-white/25 backdrop-blur-2xl border-t border-white/40 px-6 py-4 flex justify-between items-center shrink-0 z-40 pb-8">
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
