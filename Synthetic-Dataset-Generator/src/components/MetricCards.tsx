import React from "react";
import { DatasetSample, ValidationReport } from "../types";
import { APPROVED_FACILITIES, validateSample } from "../data";
import { CheckCircle2, AlertTriangle, ShieldCheck, HeartPulse, Building2, BarChart2 } from "lucide-react";

interface MetricCardsProps {
  samples: DatasetSample[];
}

export default function MetricCards({ samples }: MetricCardsProps) {
  const total = samples.length;
  
  // Calculate validation stats
  let validCount = 0;
  let invalidCount = 0;
  let totalErrors = 0;
  let totalWarnings = 0;

  samples.forEach((sample) => {
    const report = validateSample(sample);
    if (report.isValid) {
      validCount++;
    } else {
      invalidCount++;
    }
    report.errors.forEach((e) => {
      if (e.type === "error") totalErrors++;
      if (e.type === "warning") totalWarnings++;
    });
  });

  const passRate = total > 0 ? Math.round((validCount / total) * 100) : 100;

  // Calculate insurance stats
  let britamCount = 0;
  let oldMutualCount = 0;

  samples.forEach((sample) => {
    const contentStr = JSON.stringify(sample.messages).toLowerCase();
    if (contentStr.includes("britam")) britamCount++;
    if (contentStr.includes("old mutual") || contentStr.includes("oldmutual")) oldMutualCount++;
  });

  // Calculate top recommended approved hospitals
  const hospitalCounts: Record<string, number> = {};
  samples.forEach((sample) => {
    const contentStr = JSON.stringify(sample.messages).toLowerCase();
    APPROVED_FACILITIES.forEach((h) => {
      if (contentStr.includes(h.name.toLowerCase())) {
        hospitalCounts[h.name] = (hospitalCounts[h.name] || 0) + 1;
      }
    });
  });

  const topHospitals = Object.entries(hospitalCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3);

  return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      {/* Total Samples Card */}
      <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-5 shadow-lg flex items-center justify-between">
        <div>
          <span className="text-[10px] uppercase tracking-widest text-slate-400 font-bold font-mono">Dataset Size</span>
          <h3 className="text-3xl font-extrabold text-white mt-1">{total}</h3>
          <p className="text-xs text-slate-400 mt-1">Generated rows in current batch</p>
        </div>
        <div className="p-3 bg-blue-500/10 border border-blue-500/20 text-blue-400 rounded-xl">
          <BarChart2 className="w-6 h-6" />
        </div>
      </div>

      {/* Validation Pass Rate Card */}
      <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-5 shadow-lg flex items-center justify-between">
        <div>
          <span className="text-[10px] uppercase tracking-widest text-slate-400 font-bold font-mono">Workflow Lint Status</span>
          <div className="flex items-baseline gap-2 mt-1">
            <h3 className="text-3xl font-extrabold text-white">{passRate}%</h3>
            <span className="text-xs font-semibold text-slate-400">compliant</span>
          </div>
          <p className="text-xs text-slate-400 mt-1">
            <span className="text-green-400 font-bold">{validCount} passed</span> • <span className="text-red-400 font-bold">{invalidCount} broken</span>
          </p>
        </div>
        <div className={`p-3 rounded-xl border ${passRate === 100 && total > 0 ? "bg-emerald-500/10 border-emerald-500/20 text-emerald-400" : "bg-amber-500/10 border-amber-500/20 text-amber-400"}`}>
          {passRate === 100 && total > 0 ? <CheckCircle2 className="w-6 h-6" /> : <AlertTriangle className="w-6 h-6" />}
        </div>
      </div>

      {/* Insurance Schemes Balance */}
      <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-5 shadow-lg flex items-center justify-between">
        <div>
          <span className="text-[10px] uppercase tracking-widest text-slate-400 font-bold font-mono">Insurance Mix</span>
          <div className="flex gap-4 mt-2">
            <div>
              <span className="text-xs text-slate-400 font-medium">Britam</span>
              <p className="text-lg font-bold text-white">{britamCount}</p>
            </div>
            <div className="border-l border-white/10 h-8 self-center" />
            <div>
              <span className="text-xs text-slate-400 font-medium">Old Mutual</span>
              <p className="text-lg font-bold text-white">{oldMutualCount}</p>
            </div>
          </div>
          <p className="text-[10px] text-slate-400 mt-1">Goal is ~50% balanced distribution</p>
        </div>
        <div className="p-3 bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 rounded-xl">
          <ShieldCheck className="w-6 h-6" />
        </div>
      </div>

      {/* Top Hospital Referrals */}
      <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-5 shadow-lg flex items-center justify-between">
        <div>
          <span className="text-[10px] uppercase tracking-widest text-slate-400 font-bold font-mono">Top Referrals</span>
          {topHospitals.length > 0 ? (
            <div className="mt-1 space-y-0.5">
              {topHospitals.map(([name, count]) => (
                <div key={name} className="flex justify-between text-xs text-slate-300 gap-2">
                  <span className="truncate max-w-[130px] font-medium">{name}</span>
                  <span className="font-mono text-slate-400 font-semibold">x{count}</span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-xs text-slate-400 mt-2">No hospital mentions recorded</p>
          )}
        </div>
        <div className="p-3 bg-rose-500/10 border border-rose-500/20 text-rose-400 rounded-xl">
          <Building2 className="w-6 h-6" />
        </div>
      </div>
    </div>
  );
}
