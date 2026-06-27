import React, { useState } from "react";
import { DatasetSample } from "../types";
import { X, Save, Edit, Code, MessageCircle, AlertCircle, Sparkles } from "lucide-react";

interface SampleModalProps {
  sample: DatasetSample;
  isOpen: boolean;
  onClose: () => void;
  onSave: (updatedSample: DatasetSample) => void;
  onAutoCorrect?: (sample: DatasetSample, feedback: string) => Promise<void>;
  isAutoCorrecting?: boolean;
}

export default function SampleModal({
  sample,
  isOpen,
  onClose,
  onSave,
  onAutoCorrect,
  isAutoCorrecting
}: SampleModalProps) {
  if (!isOpen) return null;

  const [activeTab, setActiveTab] = useState<"visual" | "text">("visual");
  const [messages, setMessages] = useState(sample.messages);
  const [textVal, setTextVal] = useState(sample.text);
  const [feedback, setFeedback] = useState("");

  const handleSave = () => {
    onSave({
      ...sample,
      messages,
      text: textVal
    });
    onClose();
  };

  const handleMessageChange = (idx: number, content: string) => {
    const updated = [...messages];
    updated[idx] = { ...updated[idx], content };
    setMessages(updated);
  };

  const triggerAIHelp = () => {
    if (onAutoCorrect) {
      onAutoCorrect(sample, feedback);
    }
  };

  return (
    <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-md flex items-center justify-center z-50 p-4">
      <div className="bg-slate-900/90 backdrop-blur-2xl rounded-2xl w-full max-w-4xl max-h-[85vh] shadow-2xl flex flex-col overflow-hidden border border-white/10 text-slate-100">
        {/* Modal Header */}
        <div className="p-6 border-b border-white/10 flex items-center justify-between bg-white/5">
          <div>
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Edit className="w-5 h-5 text-blue-400" />
              SFT Sample Editor & Repair Toolkit
            </h3>
            <p className="text-xs text-slate-400 mt-1">Refine and perfect system turns, workflows, or raw Gemma formatting tags.</p>
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-white/10 rounded-lg text-slate-400 hover:text-white transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* AI Quick Copilot Assist */}
        {onAutoCorrect && (
          <div className="bg-blue-600/10 p-4 border-b border-white/10 flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
            <div className="flex items-center gap-2 text-blue-300 text-xs font-semibold">
              <Sparkles className="w-4 h-4 text-blue-400 animate-pulse" />
              AI Repair Copilot:
            </div>
            <div className="flex-1 flex gap-2">
              <input
                type="text"
                placeholder="Instruct the AI helper to fix specific sections (e.g. 'Use old mutual 15% copay instead', 'Fix hospitals list')"
                className="flex-1 text-xs px-3 py-1.5 bg-black/40 border border-white/10 rounded-lg text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                value={feedback}
                onChange={(e) => setFeedback(e.target.value)}
                disabled={isAutoCorrecting}
              />
              <button
                onClick={triggerAIHelp}
                disabled={isAutoCorrecting}
                className="px-4 py-1.5 bg-blue-600 hover:bg-blue-500 disabled:bg-blue-800 text-white font-semibold text-xs rounded-lg transition-all flex items-center gap-1.5 shadow-lg shadow-blue-500/20 whitespace-nowrap"
              >
                {isAutoCorrecting ? (
                  <>
                    <div className="w-3 h-3 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                    Repairing...
                  </>
                ) : (
                  <>
                    <Sparkles className="w-3.5 h-3.5" />
                    Auto-Correct
                  </>
                )}
              </button>
            </div>
          </div>
        )}

        {/* Tab Navigation */}
        <div className="flex border-b border-white/10 bg-white/5">
          <button
            onClick={() => setActiveTab("visual")}
            className={`px-6 py-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-all ${
              activeTab === "visual" ? "border-blue-500 text-blue-400 bg-blue-500/10" : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            <MessageCircle className="w-4 h-4" />
            Interactive Conversation Turns
          </button>
          <button
            onClick={() => setActiveTab("text")}
            className={`px-6 py-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-all ${
              activeTab === "text" ? "border-blue-500 text-blue-400 bg-blue-500/10" : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            <Code className="w-4 h-4" />
            Raw Gemma Template (Fine-tuning Format)
          </button>
        </div>

        {/* Tab Contents */}
        <div className="flex-1 overflow-y-auto p-6 bg-black/20">
          {activeTab === "visual" ? (
            <div className="space-y-4">
              {messages.map((msg, idx) => (
                <div key={idx} className="bg-white/5 rounded-xl border border-white/10 p-4 shadow-lg">
                  <div className="flex items-center justify-between mb-2">
                    <span
                      className={`text-[9px] font-bold font-mono uppercase tracking-wider px-2 py-0.5 rounded-full ${
                        msg.role === "system"
                          ? "bg-purple-500/20 text-purple-300 border border-purple-500/30"
                          : msg.role === "user"
                          ? "bg-blue-500/20 text-blue-300 border border-blue-500/30"
                          : "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30"
                      }`}
                    >
                      {msg.role}
                    </span>
                    <span className="text-[10px] text-slate-500 font-mono">Turn #{idx + 1}</span>
                  </div>
                  {msg.role === "system" ? (
                    <div className="text-xs text-slate-400 bg-black/40 p-2.5 rounded-lg border border-white/5 font-mono max-h-24 overflow-y-auto">
                      {msg.content}
                    </div>
                  ) : msg.content.trim().startsWith("[") ? (
                    <div>
                      <div className="text-[10px] font-bold text-slate-400 mb-1 font-mono uppercase tracking-wide">Tool Calls (JSON)</div>
                      <textarea
                        className="w-full text-xs font-mono p-3 bg-black/60 text-emerald-300 rounded-lg border border-white/10 focus:outline-none focus:border-blue-500"
                        rows={4}
                        value={msg.content}
                        onChange={(e) => handleMessageChange(idx, e.target.value)}
                      />
                    </div>
                  ) : (
                    <textarea
                      className="w-full text-sm p-3 bg-black/30 text-white rounded-lg border border-white/10 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50"
                      rows={3}
                      value={msg.content}
                      onChange={(e) => handleMessageChange(idx, e.target.value)}
                    />
                  )}
                </div>
              ))}
            </div>
          ) : (
            <div className="h-full flex flex-col min-h-[300px]">
              <div className="flex items-center gap-2 mb-2 p-3 bg-amber-500/10 text-amber-300 rounded-xl border border-amber-500/20 text-xs">
                <AlertCircle className="w-4 h-4 text-amber-400 shrink-0" />
                This contains the final Gemma token structures like &lt;start_of_turn&gt; and &lt;end_of_turn&gt; that are directly passed to the SFT fine-tuning algorithms.
              </div>
              <textarea
                className="flex-1 w-full font-mono text-xs p-4 bg-black/40 text-slate-200 rounded-xl border border-white/10 focus:outline-none focus:ring-2 focus:ring-blue-500"
                value={textVal}
                onChange={(e) => setTextVal(e.target.value)}
                placeholder="Raw dataset text formatting..."
              />
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div className="p-4 bg-white/5 border-t border-white/10 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-white/5 border border-white/10 rounded-xl text-slate-300 font-semibold text-xs hover:bg-white/10 hover:text-white transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs rounded-xl flex items-center gap-1.5 transition-all shadow-lg shadow-blue-500/20"
          >
            <Save className="w-4 h-4" />
            Save Changes
          </button>
        </div>
      </div>
    </div>
  );
}
