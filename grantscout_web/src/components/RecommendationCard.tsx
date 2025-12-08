import { Building2, MapPin, ArrowRight, CheckCircle2 } from 'lucide-react';

interface Grant {
    id: string;
    title: string;
    department: string;
    endDate: string;
    views: number;
    tags?: string[];
    matchReason?: string[]; // Why this was recommended
}

interface RecommendationCardProps {
    grant: Grant;
    onClick: () => void;
    onAskAi?: () => void;
}

export default function RecommendationCard({ grant, onClick, onAskAi }: RecommendationCardProps) {
    // Calculate D-Day
    const today = new Date();
    const end = new Date(grant.endDate);
    let diffDays: number | null = null;
    let dDay: string;
    let isDateValid = !isNaN(end.getTime());
    if (isDateValid) {
        const diffTime = end.getTime() - today.getTime();
        diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        dDay = diffDays > 0 ? `D-${diffDays}` : (diffDays === 0 ? 'D-Day' : '마감');
    } else {
        // 날짜 형식이 아닐 경우(예: '상시')에는 그대로 표시하거나 기본값 사용
        dDay = grant.endDate || '상시';
    }

    return (
        <div
            onClick={onClick}
            className="min-w-[300px] md:min-w-[350px] bg-gradient-to-br from-white to-blue-50 rounded-2xl p-6 border border-blue-100 shadow-sm hover:shadow-md transition-all cursor-pointer relative overflow-hidden group snap-center"
        >
            {/* Decorative Background */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-blue-100 rounded-full -mr-16 -mt-16 opacity-50 blur-2xl group-hover:bg-blue-200 transition-colors"></div>

            <div className="relative z-10">
                {/* Header: Badges */}
                <div className="flex items-center gap-2 mb-4">
                    <span className="px-3 py-1 bg-blue-600 text-white text-xs font-bold rounded-full shadow-sm">
                        추천
                    </span>
                    <span
                        className={`px-2 py-1 text-xs font-bold rounded-full ${
                            isDateValid && diffDays !== null && diffDays <= 7
                                ? 'bg-red-100 text-red-600'
                                : 'bg-slate-100 text-slate-600'
                        }`}
                    >
                        {dDay}
                    </span>
                </div>

                {/* Title */}
                <h3 className="text-xl font-bold text-slate-900 mb-2 line-clamp-2 h-14 leading-snug">
                    {grant.title}
                </h3>

                {/* Meta Info */}
                <div className="flex items-center gap-3 text-sm text-slate-500 mb-6">
                    <span className="flex items-center gap-1">
                        <Building2 size={14} /> {grant.department}
                    </span>
                    <span className="flex items-center gap-1">
                        <MapPin size={14} /> 전국
                    </span>
                </div>

                {/* Match Reasons (Why this is for you) */}
                <div className="space-y-2 mb-6">
                    {grant.matchReason && grant.matchReason.length > 0 ? (
                        grant.matchReason.map((reason, idx) => (
                            <div key={idx} className="flex items-center gap-2 text-sm text-blue-800 bg-white/60 px-2 py-1 rounded-lg w-fit">
                                <CheckCircle2 size={14} className="text-blue-600" />
                                <span>{reason}</span>
                            </div>
                        ))
                    ) : (
                        <div className="flex items-center gap-2 text-sm text-blue-800 bg-white/60 px-2 py-1 rounded-lg w-fit">
                            <CheckCircle2 size={14} className="text-blue-600" />
                            <span>회원님 업종과 일치</span>
                        </div>
                    )}
                </div>

                {/* Footer Action */}
                <div className="flex items-center justify-between pt-4 border-t border-blue-100/50">
                    <span className="text-xs text-slate-400">
                        ~ {grant.endDate} 마감
                    </span>
                    <div className="flex items-center gap-2">
                        {onAskAi && (
                            <button
                                type="button"
                                onClick={(e) => {
                                    e.stopPropagation();
                                    onAskAi();
                                }}
                                className="px-2 py-1 rounded-full bg-blue-50 text-blue-600 text-[11px] font-semibold border border-blue-100 hover:bg-blue-100"
                            >
                                AI 분석
                            </button>
                        )}
                        <div className="w-8 h-8 rounded-full bg-white flex items-center justify-center text-blue-600 shadow-sm group-hover:scale-110 transition-transform">
                            <ArrowRight size={16} />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
