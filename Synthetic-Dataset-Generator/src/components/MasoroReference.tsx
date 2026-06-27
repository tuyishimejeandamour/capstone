import React from "react";
import { APPROVED_FACILITIES, INSURANCE_SCHEMES } from "../data";
import { Building2, ShieldCheck, Phone, Mail, MapPin } from "lucide-react";

export default function MasoroReference() {
  return (
    <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl p-6 shadow-lg">
      <div className="flex items-center gap-3 mb-4 pb-3 border-b border-white/10">
        <Building2 className="w-5 h-5 text-indigo-400" />
        <div>
          <h4 className="text-sm font-bold text-white">Masoro Catchment Approved Reference Table</h4>
          <p className="text-xs text-slate-400">Only these 10 facilities are approved for Ranga routing training.</p>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="border-b border-white/10 text-[10px] font-bold font-mono text-slate-300 uppercase tracking-wider bg-white/5">
              <th className="py-2.5 px-3">ID / Facility Name</th>
              <th className="py-2.5 px-3">Type</th>
              <th className="py-2.5 px-3">District</th>
              <th className="py-2.5 px-3">Distance</th>
              <th className="py-2.5 px-3">Contacts</th>
              <th className="py-2.5 px-3">Insurance Match</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-white/5 text-xs">
            {APPROVED_FACILITIES.map((fac) => (
              <tr key={fac.id} className="hover:bg-white/5 transition-colors">
                <td className="py-3 px-3">
                  <div className="font-semibold text-slate-200">{fac.name}</div>
                  <div className="text-[10px] text-slate-400 font-mono">id: {fac.id}</div>
                </td>
                <td className="py-3 px-3 text-slate-300 font-medium">{fac.healthcareType}</td>
                <td className="py-3 px-3 text-slate-400">{fac.district}</td>
                <td className="py-3 px-3 font-mono text-indigo-300 font-semibold">{fac.distanceKm} km</td>
                <td className="py-3 px-3 space-y-0.5">
                  <div className="text-[10px] text-slate-400 flex items-center gap-1 font-mono">
                    <Phone className="w-3 h-3 text-slate-500" />
                    {fac.phone}
                  </div>
                  <div className="text-[10px] text-slate-400 flex items-center gap-1 font-mono">
                    <Mail className="w-3 h-3 text-slate-500" />
                    {fac.email}
                  </div>
                </td>
                <td className="py-3 px-3">
                  <div className="flex gap-1.5 flex-wrap">
                    {fac.acceptedInsurance.map((ins) => (
                      <span
                        key={ins}
                        className="text-[9px] font-bold font-mono px-1.5 py-0.2 rounded-sm uppercase tracking-wide bg-emerald-500/20 text-emerald-300 border border-emerald-500/30"
                      >
                        {ins}
                      </span>
                    ))}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Insurance Scheme Quick Ref */}
      <div className="mt-6 pt-5 border-t border-white/10">
        <h5 className="text-xs font-bold text-slate-200 mb-3 flex items-center gap-2">
          <ShieldCheck className="w-4 h-4 text-indigo-400" />
          Insurance Scheme Configuration Rules
        </h5>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {INSURANCE_SCHEMES.map((scheme) => (
            <div key={scheme.name} className="p-4 bg-white/5 rounded-xl border border-white/10">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-slate-200">{scheme.name} Insurance</span>
                <span className="text-[10px] font-mono bg-indigo-500/20 text-indigo-300 px-2 py-0.5 rounded-full font-bold border border-indigo-500/30">
                  networkKey: {scheme.networkKey}
                </span>
              </div>
              <p className="text-xs text-slate-300 mb-2 leading-relaxed">
                <span className="font-semibold text-slate-400">Limits: </span>
                {scheme.limits}
              </p>
              <div className="text-[11px] text-slate-400 leading-relaxed bg-black/40 p-2.5 rounded-lg border border-white/5">
                <span className="font-semibold text-slate-300">Strict Rules: </span>
                {scheme.policyNotes}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
