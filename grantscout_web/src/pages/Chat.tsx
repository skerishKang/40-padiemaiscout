import React, { useState, useRef, useEffect } from 'react';
import { Send, Paperclip, User, Loader2, FileText, X, Sparkles } from 'lucide-react';
import { geminiService } from '../services/GeminiService';
import mammoth from 'mammoth';
import { clsx } from 'clsx';

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
            text: '안녕하세요! PadiemScoutAI입니다. 🕵️‍♂️\n\n복잡한 공고문, PDF만 올려주세요.\nAI가 3초 만에 핵심만 요약하고 우리 기업 지원 가능 여부를 알려드립니다.\n\nPDF 외에도 이미지나 다른 문서도 분석 가능합니다. 더 정확한 분석을 위해서는 [내 프로필]에서 기업 정보를 입력해주세요!',
            timestamp: new Date(),
        }
    ]);
    const [input, setInput] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [attachedFile, setAttachedFile] = useState<{ file: File, preview?: string } | null>(null);
    const messagesEndRef = useRef<HTMLDivElement>(null);
    const fileInputRef = useRef<HTMLInputElement>(null);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    };

    useEffect(() => {
        scrollToBottom();
    }, [messages]);

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
            let prompt = input;
            let fileData = undefined;

            if (attachedFile) {
                const fileType = attachedFile.file.type;
                if (fileType === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
                    const extractedText = await extractTextFromDocx(attachedFile.file);
                    prompt = `${prompt}\n\n[Attached Document Content]:\n${extractedText}`;
                } else {
                    const base64 = await convertFileToBase64(attachedFile.file);
                    fileData = {
                        mimeType: fileType,
                        data: base64
                    };
                }
            }

            const responseText = await geminiService.generateContent(prompt, fileData);

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
        <div className="flex flex-col h-full bg-white lg:rounded-2xl lg:shadow-xl lg:border border-slate-200 overflow-hidden relative">
            {/* Chat Header (Optional, mostly for mobile view context) */}
            <div className="bg-white/80 backdrop-blur-md p-4 border-b border-slate-100 flex items-center gap-2 absolute top-0 left-0 right-0 z-10 lg:hidden">
                <Sparkles size={18} className="text-primary-600" />
                <span className="font-bold text-slate-800">AI 분석 챗봇</span>
            </div>

            {/* Messages Area */}
            <div className="flex-1 overflow-y-auto p-4 space-y-6 pt-16 lg:pt-6 bg-slate-50/50">
                {messages.map((msg) => (
                    <div key={msg.id} className={`flex gap-4 ${msg.role === 'user' ? 'flex-row-reverse' : ''} animate-in fade-in slide-in-from-bottom-2 duration-300`}>
                        <div className={clsx(
                            "w-10 h-10 rounded-full flex items-center justify-center shrink-0 shadow-lg border-2 border-white overflow-hidden",
                            msg.role === 'ai' ? "bg-white" : "bg-white text-slate-600"
                        )}>
                            {msg.role === 'ai' ? (
                                <img src="/bot_avatar.png" alt="AI" className="w-full h-full object-cover" />
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
                                    ? "bg-primary-600/90 text-white rounded-2xl rounded-tr-none shadow-primary-500/20"
                                    : "bg-white/80 text-slate-800 rounded-2xl rounded-tl-none border border-white/40 shadow-slate-200/50"
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
                            <img src="/bot_avatar.png" alt="AI" className="w-full h-full object-cover" />
                        </div>
                        <div className="bg-white/80 backdrop-blur-md p-4 rounded-2xl rounded-tl-none border border-white/40 shadow-sm flex items-center gap-3">
                            <Loader2 size={18} className="animate-spin text-primary-600" />
                            <span className="text-sm text-slate-500 font-medium">문서를 분석하고 있습니다...</span>
                        </div>
                    </div>
                )}
                <div ref={messagesEndRef} />
            </div>

            {/* Input Area */}
            <div className="p-4 bg-white/80 backdrop-blur-xl border-t border-white/20">
                <div className="max-w-4xl mx-auto">
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
                                placeholder="궁금한 점을 물어보거나 공고문을 올려주세요..."
                                className="w-full bg-transparent border-none focus:outline-none resize-none max-h-32 text-sm"
                                rows={1}
                                style={{ minHeight: '24px' }}
                            />
                        </div>
                        <button
                            onClick={handleSend}
                            disabled={(!input.trim() && !attachedFile) || isLoading}
                            className="p-3 bg-primary-600 text-white rounded-xl hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-primary-200 mb-[2px]"
                        >
                            <Send size={20} />
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
