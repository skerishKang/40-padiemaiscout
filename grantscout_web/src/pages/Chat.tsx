import React, { useState, useRef, useEffect } from 'react';
import { Send, Paperclip, User, Loader2, FileText, X, Sparkles } from 'lucide-react';
import { geminiService } from '../services/GeminiService';
import mammoth from 'mammoth';
import { clsx } from 'clsx';

const PROMPT_TEMPLATE_STORAGE_KEY = 'padiem_prompt_template_v1';

const DEFAULT_PROMPT_TEMPLATE = `당신은 국내 기업의 정부지원사업/지자체 공고를 분석해주는 전문 컨설턴트입니다.

목표:
- 첨부된 공고문/문서의 핵심을 빠르게 요약합니다.
- 우리 기업이 해당 공고에 지원할 수 있는지 가능성을 평가합니다.
- 준비해야 할 서류, 핵심 평가 포인트, 주의사항을 제안합니다.

스타일:
- 짧고 명확하게, 항목별(불릿/번호)로 정리합니다.
- 어려운 행정/법률 용어는 쉬운 말로 풀어서 설명합니다.
- 근거가 되는 문장이나 조건이 있으면 같이 언급합니다.

응답 형식:
1. 공고 핵심 요약
2. 우리 기업 지원 가능성 (높음/보통/낮음 + 이유)
3. 준비해야 할 것
4. 추가로 체크해야 할 리스크`;

interface Message {
    id: string;
    role: 'user' | 'ai';
    text: string;
    attachment?: {
        name: string;
        type: string;
    };
    timestamp: Date;
}

export default function Chat() {
    const [messages, setMessages] = useState<Message[]>([
        {
            id: 'welcome',
            role: 'ai',
            text: '안녕하세요!\nPadiemScoutAI입니다. 🕵️‍♂️\n\n복잡한 공고문,\nPDF만 올려주세요.\n\nAI가 3초 만에 핵심만 요약하고 우리 기업 지원 가능 여부를 알려드립니다.\n\nPDF 외에도 이미지나 다른 문서도 분석 가능합니다. 더 정확한 분석을 위해서는 [내 프로필]에서 기업 정보를 입력해주세요!',
            timestamp: new Date(),
        }
    ]);
    const [input, setInput] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [attachedFile, setAttachedFile] = useState<{ file: File, preview?: string } | null>(null);
    const [promptTemplate, setPromptTemplate] = useState<string>(() => {
        if (typeof window === 'undefined') return DEFAULT_PROMPT_TEMPLATE;
        const saved = window.localStorage.getItem(PROMPT_TEMPLATE_STORAGE_KEY);
        return saved || DEFAULT_PROMPT_TEMPLATE;
    });
    const [isPromptSettingsOpen, setIsPromptSettingsOpen] = useState(false);
    const messagesEndRef = useRef<HTMLDivElement>(null);
    const fileInputRef = useRef<HTMLInputElement>(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

    useEffect(() => {
        if (typeof window === 'undefined') return;
        window.localStorage.setItem(PROMPT_TEMPLATE_STORAGE_KEY, promptTemplate);
    }, [promptTemplate]);

    const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setAttachedFile({ file });
    };

    const clearFile = () => {
        setAttachedFile(null);
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    const convertFileToBase64 = (file: File): Promise<string> => {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.readAsDataURL(file);
            reader.onload = () => {
                const result = reader.result as string;
                const base64 = result.split(',')[1];
                resolve(base64);
            };
            reader.onerror = error => reject(error);
        });
    };

    const extractTextFromDocx = async (file: File): Promise<string> => {
        const arrayBuffer = await file.arrayBuffer();
        const result = await mammoth.extractRawText({ arrayBuffer });
        return result.value;
    };

    const handleSend = async () => {
        if ((!input.trim() && !attachedFile) || isLoading) return;

        const userMessage: Message = {
            id: Date.now().toString(),
            role: 'user',
            text: input,
            attachment: attachedFile ? { name: attachedFile.file.name, type: attachedFile.file.type } : undefined,
            timestamp: new Date(),
        };

        setMessages(prev => [...prev, userMessage]);
        setInput('');
        setIsLoading(true);

        try {
            let userPrompt = input.trim();
            let fileData = undefined as { mimeType: string; data: string } | undefined;
            let docText: string | undefined;

            if (attachedFile) {
                const fileType = attachedFile.file.type;
                if (fileType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
                    const extractedText = await extractTextFromDocx(attachedFile.file);
                    docText = extractedText;
                } else {
                    const base64 = await convertFileToBase64(attachedFile.file);
                    fileData = {
                        mimeType: fileType,
                        data: base64
                    };
                }
            }

            if (!userPrompt) {
                userPrompt = "첨부한 문서를 분석해서 핵심 내용과 우리 기업의 지원 적합성을 요약해줘.";
            }

            let finalPromptBody = userPrompt;

            if (docText) {
                finalPromptBody = `${userPrompt}\n\n[첨부 문서 내용]\n${docText}`;
            }

            const template = promptTemplate.trim();
            const finalPrompt = template
                ? `${template}\n\n---\n\n사용자 질문:\n${finalPromptBody}`
                : finalPromptBody;

            const responseText = await geminiService.generateContent(finalPrompt, fileData);

            const aiMessage: Message = {
                id: (Date.now() + 1).toString(),
                role: 'ai',
                text: responseText,
                timestamp: new Date(),
            };

            setMessages(prev => [...prev, aiMessage]);
        } catch (error) {
            console.error("Chat Error:", error);
            const errorMessage: Message = {
                id: (Date.now() + 1).toString(),
                role: 'ai',
                text: "죄송합니다. 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
                timestamp: new Date(),
            };
            setMessages(prev => [...prev, errorMessage]);
        } finally {
            setIsLoading(false);
            setAttachedFile(null);
            if (fileInputRef.current) fileInputRef.current.value = '';
        }
    };

    return (
        <div className="flex flex-col h-full bg-transparent lg:rounded-3xl lg:shadow-[0_24px_60px_-24px_rgba(15,23,42,0.65)] lg:border border-white/40 overflow-hidden relative">
            {/* Chat Header (Optional, mostly for mobile view context) */}
            <div className="bg-white/80 backdrop-blur-md p-4 border-b border-slate-100 flex items-center gap-2 absolute top-0 left-0 right-0 z-10 lg:hidden">
                <Sparkles size={18} className="text-primary-600" />
                <span className="font-bold text-slate-800">AI 분석 챗봇</span>
            </div>

            {/* Messages Area */}
            <div className="flex-1 overflow-y-auto p-4 space-y-6 pt-16 lg:pt-6 bg-transparent">
                {messages.map((msg) => (
                    <div key={msg.id} className={`flex gap-4 ${msg.role === 'user' ? 'flex-row-reverse' : ''} animate-in fade-in slide-in-from-bottom-2 duration-300`}>
                        <div className={clsx(
                            "w-10 h-10 rounded-full flex items-center justify-center shrink-0 shadow-lg border-2 border-white overflow-hidden",
                            msg.role === 'ai' ? "bg-white" : "bg-white text-slate-600"
                        )}>
                            {msg.role === 'ai' ? (
                                <img src="/logo-bot.png" alt="AI" className="w-full h-full object-cover" />
                            ) : (
                                <User size={20} />
                            )}
                        </div>
                        <div className={`max-w-[85%] lg:max-w-[75%] space-y-2`}>
                            {msg.attachment && (
                                <div className="flex items-center gap-3 p-3 bg-white/80 backdrop-blur-sm border border-white/40 rounded-xl text-sm text-slate-600 shadow-sm">
                                    <div className="p-2 bg-primary-50 rounded-lg text-primary-600">
                                        <FileText size={18} />
                                    </div>
                                    <span className="truncate max-w-[180px] font-medium">{msg.attachment.name}</span>
                                </div>
                            )}
                            <div className={clsx(
                                "p-4 text-sm leading-relaxed whitespace-pre-wrap shadow-sm backdrop-blur-md",
                                msg.role === 'user'
                                    ? "bg-blue-600 text-white rounded-2xl rounded-tr-none shadow-primary-500/20"
                                    : "bg-white/60 text-slate-800 rounded-2xl rounded-tl-none border border-white/40 shadow-slate-200/50"
                            )}>
                                {msg.text}
                            </div>
                            <div className={`text-[10px] text-slate-400 font-medium px-1 ${msg.role === 'user' ? 'text-right' : ''}`}>
                                {msg.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </div>
                        </div>
                    </div>
                ))}
                {isLoading && (
                    <div className="flex gap-4 animate-pulse">
                        <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center shadow-lg border-2 border-white overflow-hidden">
                            <img src="/logo-bot.png" alt="AI" className="w-full h-full object-cover" />
                        </div>
                        <div className="bg-white/60 backdrop-blur-md p-4 rounded-2xl rounded-tl-none border border-white/40 shadow-sm flex items-center gap-3">
                            <Loader2 size={18} className="animate-spin text-primary-600" />
                            <span className="text-sm text-slate-500 font-medium">문서를 분석하고 있습니다...</span>
                        </div>
                    </div>
                )}
                <div ref={messagesEndRef} />
            </div>

            {/* Input Area */}
            <div className="p-4 bg-white/30 backdrop-blur-xl border-t border-white/20">
                <div className="max-w-4xl mx-auto">
                    <div className="flex items-center justify-between mb-3">
                        <span className="text-[11px] text-slate-400 hidden sm:inline">
                            공고문이나 자료를 첨부하면 더 정확한 분석이 가능합니다.
                        </span>
                        <button
                            type="button"
                            onClick={() => setIsPromptSettingsOpen(true)}
                            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full border border-primary-100 bg-primary-50 text-[11px] font-medium text-primary-700 hover:bg-primary-100 hover:border-primary-200"
                        >
                            <Sparkles size={14} className="text-primary-500" />
                            프롬프트 설정
                        </button>
                    </div>
                    {attachedFile && (
                        <div className="flex items-center gap-3 mb-3 p-2 pl-3 bg-primary-50 text-primary-700 rounded-xl text-sm w-fit border border-primary-100 animate-in slide-in-from-bottom-2">
                            <FileText size={16} />
                            <span className="truncate max-w-[200px] font-medium">{attachedFile.file.name}</span>
                            <button onClick={clearFile} className="p-1 hover:bg-primary-100 rounded-full transition-colors" title="파일 삭제">
                                <X size={14} />
                            </button>
                        </div>
                    )}
                    <div className="flex gap-2 items-end">
                        <button
                            onClick={() => fileInputRef.current?.click()}
                            className="p-3 text-slate-400 hover:text-primary-600 hover:bg-primary-50 rounded-xl transition-colors mb-[2px]"
                            title="파일 첨부"
                        >
                            <Paperclip size={22} />
                        </button>
                        <input
                            type="file"
                            ref={fileInputRef}
                            onChange={handleFileSelect}
                            className="hidden"
                            accept=".pdf,.doc,.docx,.hwp,.hwpx,.jpg,.jpeg,.png"
                        />
                        <div className="flex-1 bg-slate-50 border border-slate-200 rounded-2xl px-4 py-3 focus-within:ring-2 focus-within:ring-primary-100 focus-within:border-primary-300 transition-all">
                            <textarea
                                value={input}
                                onChange={(e) => setInput(e.target.value)}
                                onKeyPress={(e) => {
                                    if (e.key === 'Enter' && !e.shiftKey) {
                                        e.preventDefault();
                                        handleSend();
                                    }
                                }}
                                placeholder="메시지를 입력해 주세요..."
                                className="w-full bg-transparent border-none focus:outline-none resize-none max-h-32 text-sm appearance-none"
                                rows={1}
                                style={{ minHeight: '24px' }}
                            />
                        </div>
                        <button
                            onClick={handleSend}
                            disabled={(!input.trim() && !attachedFile) || isLoading}
                            className="flex shrink-0 items-center gap-2 px-4 py-3 bg-blue-600 text-white rounded-full hover:bg-blue-700 disabled:opacity-40 cursor-pointer disabled:cursor-default transition-all shadow-md shadow-blue-200 mb-[2px]"
                        >
                            <span className="text-sm font-semibold">전송</span>
                            <Send size={18} />
                        </button>
                    </div>
                </div>
            </div>
            {isPromptSettingsOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
                    <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 p-6 space-y-4">
                        <div className="flex items-center justify-between gap-2">
                            <div>
                                <h2 className="text-base font-semibold text-slate-900">프롬프트 템플릿 설정</h2>
                                <p className="mt-1 text-xs text-slate-500">
                                    잘 모르겠으면 기본값을 그대로 사용해도 충분합니다. AI가 공고를 분석할 때 항상 이 지침을 참고합니다.
                                </p>
                            </div>
                            <button
                                type="button"
                                onClick={() => setIsPromptSettingsOpen(false)}
                                className="p-1.5 rounded-full text-slate-400 hover:text-slate-600 hover:bg-slate-100"
                                title="닫기"
                            >
                                <X size={16} />
                            </button>
                        </div>

                        <textarea
                            value={promptTemplate}
                            onChange={(e) => setPromptTemplate(e.target.value)}
                            className="w-full min-h-[180px] text-sm rounded-xl border border-slate-200 p-3 focus:outline-none focus:ring-2 focus:ring-primary-100 focus:border-primary-300 resize-vertical"
                        />

                        <div className="flex items-center justify-between gap-2 pt-1">
                            <button
                                type="button"
                                onClick={() => setPromptTemplate(DEFAULT_PROMPT_TEMPLATE)}
                                className="text-[11px] text-slate-500 hover:text-primary-600"
                            >
                                기본 템플릿으로 되돌리기
                            </button>
                            <div className="flex gap-2">
                                <button
                                    type="button"
                                    onClick={() => setIsPromptSettingsOpen(false)}
                                    className="px-3 py-1.5 rounded-lg border border-slate-200 text-xs font-medium text-slate-600 hover:bg-slate-50"
                                >
                                    닫기
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setIsPromptSettingsOpen(false)}
                                    className="px-3 py-1.5 rounded-lg bg-primary-600 text-xs font-medium text-white hover:bg-primary-700"
                                >
                                    저장
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
