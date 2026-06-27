import React from "react";
import { DatasetSample } from "../types";
import { validateSample } from "../data";
import { ShieldAlert, AlertCircle, CheckCircle, HelpCircle } from "lucide-react";

interface LinterReportProps {
  sample: DatasetSample;
}

export default function LinterReport({ sample }: LinterReportProps) {
  const report = validateSample(sample);

  if (report.isValid && report.errors.length === 0) {
    return (
      <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-5 flex items-start gap-3 shadow-lg backdrop-blur-md">
        <CheckCircle className="w-5 h-5 text-emerald-400 shrink-0 mt-0.5" />
        <div>
          <h5 className="text-sm font-bold text-emerald-300">Perfect SFT Sample</h5>
          <p className="text-xs text-slate-300 mt-1 leading-relaxed">
            This training row strictly follows the Masoro routing workflow, uses approved facilities, retains the matching insurance policy parameters, and matches correct formatting.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-5 shadow-lg">
      <div className="flex items-center justify-between mb-4 pb-3 border-b border-white/10">
        <h4 className="text-sm font-bold text-slate-200 flex items-center gap-2">
          <ShieldAlert className="w-4.5 h-4.5 text-indigo-400" />
          Real-time SFT Lint Report
        </h4>
        <span className="text-[10px] font-bold font-mono px-2.5 py-0.5 rounded-full bg-white/10 text-indigo-300 border border-indigo-500/20 uppercase">
          {report.errors.length} Issues Found
        </span>
      </div>

      <div className="space-y-3">
        {report.errors.map((error, idx) => (
          <div
            key={idx}
            className={`p-3.5 rounded-xl border flex gap-3 ${
              error.type === "error"
                ? "bg-rose-500/10 border-rose-500/20 text-rose-200"
                : "bg-amber-500/10 border-amber-500/20 text-amber-200"
            }`}
          >
            <AlertCircle className={`w-5 h-5 shrink-0 mt-0.5 ${error.type === "error" ? "text-rose-400" : "text-amber-400"}`} />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className={`text-[9px] font-bold font-mono uppercase px-1.5 py-0.2 rounded-sm ${
                  error.type === "error" ? "bg-rose-500/20 text-rose-300 border border-rose-500/30" : "bg-amber-500/20 text-amber-300 border border-amber-500/30"
                }`}>
                  {error.type}
                </span>
                <span className="text-[10px] text-slate-400 font-mono">Rule: {error.ruleId}</span>
              </div>
              <p className="text-xs font-semibold mt-1.5 leading-relaxed">{error.message}</p>
              
              {/* Contextual repair tip */}
              <div className="mt-2 text-[11px] text-slate-400 border-t border-white/5 pt-1.5 flex items-start gap-1">
                <HelpCircle className="w-3.5 h-3.5 text-slate-500 shrink-0 mt-0.5" />
                <span>
                  {error.ruleId === "forbidden-facility" && "Tip: Edit this turn to replace hospitals like CHUK or King Faisal with approved Masoro ones like Caraes Ndera, legacy_clinics, or RMH."}
                  {error.ruleId === "rank-sequence" && "Tip: Swap the ordering of your tool execution so search/nearby outcomes are passed to ranking."}
                  {error.ruleId === "unbalanced-turns" && "Tip: Ensure every assistant tool-call block is followed by a user mock response containing the tool result."}
                  {error.ruleId === "gemma-format" && "Tip: Double-check the 'text' field to make sure it includes the appropriate model start and end tokens."}
                  {error.ruleId === "no-approved-facility" && "Tip: Verify that the final assistant turn explicitly names at least one approved Masoro facility from the list."}
                  {error.ruleId === "insurance-before-location" && "Tip: Adjust the tool call order so GPS lookup precedes insurance policies."}
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
