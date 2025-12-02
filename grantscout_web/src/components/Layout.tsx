import React, { useState } from 'react';
import { Outlet, Link, useLocation } from 'react-router-dom';
import { LayoutDashboard, MessageSquare, FileText, Menu, X, UserCircle, Smartphone, Monitor, LogIn, LogOut } from 'lucide-react';
import { clsx } from 'clsx';
import { auth } from '../lib/firebase';

const SidebarItem = ({ icon: Icon, label, to, active, onClick }: { icon: React.ElementType, label: string, to: string, active: boolean, onClick?: () => void }) => (
    <Link
        to={to}
        onClick={onClick}
        className={clsx(
            "flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 group border-l-4",
            active
                ? "bg-primary-50 text-primary-700 shadow-sm border-primary-500"
                : "text-slate-600 hover:bg-slate-100 hover:text-primary-600 border-transparent"
        )}
    >
        <Icon size={20} className={clsx("transition-transform group-hover:scale-110", active ? "text-primary-600" : "text-slate-400 group-hover:text-primary-600")} />
        <span className="font-semibold">{label}</span>
    </Link>
);

export default function Layout() {
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const [viewMode, setViewMode] = useState<'desktop' | 'mobile'>('desktop');
    const location = useLocation();

    const navItems = [
        { icon: LayoutDashboard, label: '공고', to: '/dashboard' },
        { icon: MessageSquare, label: '스카우터', to: '/' },
        { icon: FileText, label: '기업', to: '/profile' },
    ];

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
                        <img src="/logo-main.png" alt="PadiemScout" className="w-8 h-8 rounded-lg shadow-sm object-cover" />
                        <span className="hidden sm:inline bg-clip-text text-transparent bg-gradient-to-r from-slate-900 to-slate-700">PadiemScout</span>
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
                    {auth.currentUser ? (
                        <Link to="/profile" className="flex items-center gap-2 p-1.5 pr-3 rounded-full border border-white/20 bg-white/50 hover:bg-white/80 transition-all backdrop-blur-sm shadow-sm">
                            <div className="w-8 h-8 bg-gradient-to-br from-primary-100 to-primary-200 text-primary-700 rounded-full flex items-center justify-center shadow-inner">
                                <UserCircle size={20} />
                            </div>
                            <span className="text-sm font-medium text-slate-700 hidden sm:block">
                                {auth.currentUser.email?.split('@')[0]}
                            </span>
                        </Link>
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
                                active={location.pathname === item.to}
                            />
                        ))}
                    </nav>

                    <div className="p-4 border-t border-slate-100/50">
                        <div className="bg-gradient-to-br from-slate-50 to-white rounded-2xl p-4 border border-white/50 shadow-sm">
                            <h4 className="font-semibold text-slate-900 text-sm mb-1">도움이 필요하신가요?</h4>
                            <p className="text-xs text-slate-500 mb-3">전문 컨설턴트와 상담해보세요.</p>
                            <button className="w-full py-2 bg-white border border-slate-200 text-slate-700 text-xs font-medium rounded-xl hover:bg-slate-50 transition-colors shadow-sm">
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
                                <button onClick={() => setIsMobileMenuOpen(false)} className="p-2 -mr-2 text-slate-400 hover:text-slate-600">
                                    <X size={24} />
                                </button>
                            </div>
                            <nav className="flex-1 p-4 space-y-2">
                                {navItems.map((item) => (
                                    <SidebarItem
                                        key={item.to}
                                        {...item}
                                        active={location.pathname === item.to}
                                        onClick={() => setIsMobileMenuOpen(false)}
                                    />
                                ))}
                            </nav>
                            {auth.currentUser && (
                                <div className="p-4 border-t border-slate-100/50">
                                    <button onClick={() => auth.signOut()} className="flex items-center gap-3 px-4 py-3 text-slate-600 hover:bg-red-50 hover:text-red-600 rounded-xl w-full transition-colors">
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
                    viewMode === 'mobile' ? "flex justify-center items-center bg-gradient-to-br from-sky-200 via-rose-200 to-amber-200 p-8" : "bg-slate-50/50"
                )}>
                    <div className={clsx(
                        "transition-all duration-300 flex flex-col",
                        viewMode === 'mobile'
                            ? "w-[375px] h-[812px] rounded-[40px] overflow-hidden relative bg-white/15 border border-white/40 backdrop-blur-2xl shadow-[0_32px_80px_rgba(15,23,42,0.65)]"
                            : "h-full w-full max-w-7xl mx-auto p-4 lg:p-6 bg-white shadow-2xl"
                    )}>

                        {/* Content Scroll Area */}
                        <div className={clsx(
                            "flex-1 overflow-y-auto scrollbar-hide",
                            viewMode === 'mobile'
                                ? "pt-6 px-0 pb-0 bg-transparent"
                                : "bg-slate-50/30"
                        )}>
                            <Outlet />
                        </div>

                        {/* Mobile Bottom Nav */}
                        {viewMode === 'mobile' && (
                            <div className="bg-white/25 backdrop-blur-2xl border-t border-white/40 px-6 py-4 flex justify-between items-center shrink-0 z-40 pb-8">
                                {navItems.map((item) => {
                                    const Icon = item.icon;
                                    const isActive = location.pathname === item.to;
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
