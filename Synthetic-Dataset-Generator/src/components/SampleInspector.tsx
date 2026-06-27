import React from "react";
import { DatasetSample, Message } from "../types";
import { CheckCircle2, XCircle, ArrowDown, MapPin, Shield, Search, TrendingUp, Sparkles, MessageSquare } from "lucide-react";

interface SampleInspectorProps {
  sample: DatasetSample;
}

export default function SampleInspector({ sample }: SampleInspectorProps) {
  // Parse elements to represent the pipeline
  let symptomText = "Unknown symptoms";
  let locationData = "Not fetched";
  let insuranceData = "Not verified";
  let searchResults: any[] = [];
  let rankedResults: any[] = [];
  let finalRecommendation = "No final recommendation turn";

  // Scan messages to populate pipeline
  sample.messages.forEach((msg, idx) => {
    // Layperson Symptoms
    if (msg.role === "user" && idx === 1) {
      symptomText = msg.content;
    }

    // getCurrentLocation Call & Response
    if (msg.role === "assistant" && msg.content.includes("getCurrentLocation")) {
      const next = sample.messages[idx + 1];
      if (next && next.role === "user") {
        locationData = next.content;
      }
    }

    // getInsuranceCoverageBlock
    if (msg.role === "assistant" && msg.content.includes("getInsuranceCoverageBlock")) {
      const next = sample.messages[idx + 1];
      if (next && next.role === "user") {
        try {
          const parsed = JSON.parse(next.content);
          const provider = parsed.providerName || parsed.networkKey || parsed.insurance || parsed.provider || parsed.name || parsed.network || "Verified Insurance";
          let copay = parsed.copayPercent !== undefined ? parsed.copayPercent : (parsed.copay !== undefined ? parsed.copay : (parsed.copayment !== undefined ? parsed.copayment : (parsed.co_pay !== undefined ? parsed.co_pay : undefined)));
          
          if (copay === undefined && typeof parsed === "object") {
            const copayKey = Object.keys(parsed).find(k => k.toLowerCase().includes("copay") || k.toLowerCase().includes("co_pay") || k.toLowerCase().includes("co-pay"));
            if (copayKey) {
              copay = parsed[copayKey];
            }
          }
          
          if (copay === undefined) {
            insuranceData = typeof parsed === "string" ? parsed : JSON.stringify(parsed);
          } else {
            insuranceData = `${provider} (Copay: ${copay}%)`;
          }
        } catch {
          insuranceData = next.content;
        }
      }
    }

    // searchHospitalsByCondition or getNearbyHospitals
    if (msg.role === "assistant" && (msg.content.includes("searchHospitalsByCondition") || msg.content.includes("getNearbyHospitals"))) {
      const next = sample.messages[idx + 1];
      if (next && next.role === "user") {
        try {
          const parsed = JSON.parse(next.content);
          if (Array.isArray(parsed)) {
            searchResults = parsed;
          } else if (parsed && typeof parsed === "object") {
            searchResults = parsed.results || parsed.hospitals || parsed.data || parsed.facilities || (Array.isArray(parsed.response) ? parsed.response : []) || [];
            if (searchResults.length === 0) {
              const arrayKey = Object.keys(parsed).find(k => Array.isArray(parsed[k]));
              if (arrayKey) {
                searchResults = parsed[arrayKey];
              } else {
                searchResults = [parsed];
              }
            }
          } else {
            searchResults = [parsed];
          }
        } catch {
          searchResults = [next.content];
        }
      }
    }

    // rankHospitalsByPriorityAndCost
    if (msg.role === "assistant" && msg.content.includes("rankHospitalsByPriorityAndCost")) {
      const next = sample.messages[idx + 1];
      if (next && next.role === "user") {
        try {
          const parsed = JSON.parse(next.content);
          if (Array.isArray(parsed)) {
            rankedResults = parsed;
          } else if (parsed && typeof parsed === "object") {
            rankedResults = parsed.rankedResults || parsed.results || parsed.ranking || parsed.ranked || parsed.data || [];
            if (rankedResults.length === 0) {
              const arrayKey = Object.keys(parsed).find(k => Array.isArray(parsed[k]));
              if (arrayKey) {
                rankedResults = parsed[arrayKey];
              } else {
                rankedResults = [parsed];
              }
            }
          } else {
            rankedResults = [parsed];
          }
        } catch {
          rankedResults = [next.content];
        }
      }
    }
  });

  // Final recommendation is usually the last model response
  const lastMsg = sample.messages[sample.messages.length - 1];
  if (lastMsg && lastMsg.role === "assistant") {
    finalRecommendation = lastMsg.content;
  }

  // Helpers to format hospital results beautifully
  const formatHospitalName = (r: any): string => {
    if (!r) return "Hospital";
    if (typeof r === "string") return r;
    const val = r.result || r.hospital || r;
    if (typeof val === "string") return val;
    if (val && typeof val === "object") {
      return val.name || val.hospitalName || val.hospital?.name || val.facilityName || JSON.stringify(val);
    }
    return r.name || r.hospitalName || "Hospital";
  };

  const formatCopay = (r: any): string => {
    if (!r) return "0";
    let val = r.estimatedCopayRwf !== undefined ? r.estimatedCopayRwf : (r.copay !== undefined ? r.copay : (r.estimatedCopay !== undefined ? r.estimatedCopay : undefined));
    if (val === undefined && typeof r === "object") {
      const copayKey = Object.keys(r).find(k => k.toLowerCase().includes("copay") || k.toLowerCase().includes("co_pay"));
      if (copayKey) val = r[copayKey];
    }
    return val !== undefined ? String(val) : "0";
  };

  const steps = [
    {
      title: "Step 1: Patient Symptoms Input",
      desc: symptomText,
      icon: MessageSquare,
      color: "border-blue-500/20 bg-blue-500/10 text-blue-400",
      status: symptomText !== "Unknown symptoms"
    },
    {
      title: "Step 2: Get Location (getCurrentLocation)",
      desc: locationData,
      icon: MapPin,
      color: "border-emerald-500/20 bg-emerald-500/10 text-emerald-400",
      status: locationData !== "Not fetched"
    },
    {
      title: "Step 3: Lookup Insurance Coverage",
      desc: insuranceData,
      icon: Shield,
      color: "border-indigo-500/20 bg-indigo-500/10 text-indigo-400",
      status: insuranceData !== "Not verified"
    },
    {
      title: "Step 4: Search Match (searchHospitalsByCondition)",
      desc: searchResults.length > 0 
        ? `Found ${searchResults.length} approved facilities: ${searchResults.map(r => formatHospitalName(r)).join(", ")}`
        : "No results parsed",
      icon: Search,
      color: "border-amber-500/20 bg-amber-500/10 text-amber-400",
      status: searchResults.length > 0
    },
    {
      title: "Step 5: Rank Facilities & Cost (rankHospitalsByPriorityAndCost)",
      desc: rankedResults.length > 0 
        ? `Ranked: ${rankedResults.map(r => `${formatHospitalName(r)} (Estimated Copay: ${formatCopay(r)} RWF)`).join(" -> ")}`
        : "No rankings computed",
      icon: TrendingUp,
      color: "border-purple-500/20 bg-purple-500/10 text-purple-400",
      status: rankedResults.length > 0
    },
    {
      title: "Step 6: Final Recommendation Output",
      desc: finalRecommendation,
      icon: Sparkles,
      color: "border-rose-500/20 bg-rose-500/10 text-rose-400",
      status: finalRecommendation !== "No final recommendation turn"
    }
  ];

  return (
    <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-6 shadow-lg">
      <h4 className="text-sm font-bold text-slate-200 mb-4 font-mono uppercase tracking-widest">
        Pipeline Workflow Verification Trace
      </h4>
      <div className="space-y-4">
        {steps.map((step, idx) => {
          const Icon = step.icon;
          return (
            <div key={idx} className="relative">
              {/* Vertical connector line */}
              {idx < steps.length - 1 && (
                <div className="absolute left-6 top-12 bottom-0 w-0.5 bg-white/10 -mb-4 z-0 flex items-center justify-center">
                  <ArrowDown className="w-3.5 h-3.5 text-indigo-400 absolute -bottom-3 bg-slate-900 py-0.5" />
                </div>
              )}

              <div className="relative z-10 flex gap-4 items-start bg-white/5 p-4 rounded-xl border border-white/10 hover:border-white/20 shadow-lg transition-all duration-300">
                <div className={`p-3 rounded-xl border ${step.color} shrink-0`}>
                  <Icon className="w-5 h-5" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between gap-2">
                    <h5 className="text-xs font-bold text-white">{step.title}</h5>
                    <div>
                      {step.status ? (
                        <span className="inline-flex items-center gap-1 text-[9px] font-bold text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-2 py-0.5 rounded-full font-mono uppercase">
                          <CheckCircle2 className="w-3 h-3" />
                          Complete
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 text-[9px] font-bold text-rose-400 bg-rose-500/10 border border-rose-500/20 px-2 py-0.5 rounded-full font-mono uppercase">
                          <XCircle className="w-3 h-3 animate-pulse" />
                          Missing
                        </span>
                      )}
                    </div>
                  </div>
                  <p className="text-xs text-slate-300 mt-2 whitespace-pre-line leading-relaxed font-mono bg-black/30 p-2.5 rounded-lg border border-white/5">
                    {step.desc}
                  </p>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
