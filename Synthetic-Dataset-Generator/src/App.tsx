import React, { useState, useEffect } from "react";
import { DatasetSample, ValidationError } from "./types";
import { APPROVED_FACILITIES, validateSample } from "./data";
import SampleModal from "./components/SampleModal";
import SampleInspector from "./components/SampleInspector";
import LinterReport from "./components/LinterReport";
import MasoroReference from "./components/MasoroReference";
import { motion, AnimatePresence } from "motion/react";
import {
  Sparkles,
  Download,
  Upload,
  Clipboard,
  Trash2,
  Plus,
  Search,
  Filter,
  CheckCircle,
  AlertTriangle,
  HelpCircle,
  Eye,
  Settings,
  Database,
  Building2,
  RefreshCw,
  LayoutGrid,
  BookOpen,
  Code,
  Terminal,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ArrowRight,
  GitBranch,
  Trash,
  Send,
  User,
  ExternalLink,
  RotateCcw
} from "lucide-react";

const PROGRESS_MESSAGES = [
  "Initializing synthetic agent generators...",
  "Injecting ALU Masoro catchment coordinates (~ -1.9695, 30.1589)...",
  "Fusing Old Mutual corporate and Britam inpatient RWF schedules...",
  "Applying strict routing guidelines (Location -> Insurance -> Search -> Rank)...",
  "Validating hospital names against approved Ndera & Kanombe facilities...",
  "Structuring dialogue turns into Gemma chat SFT templates...",
  "Compiling finalized JSONL output streams..."
];

export default function App() {
  // Navigation State
  const [activeView, setActiveView] = useState<"overview" | "structure" | "build" | "settings">("overview");

  const [samples, setSamples] = useState<DatasetSample[]>([]);
  const [hasLoadedFromServer, setHasLoadedFromServer] = useState(false);

  // Load samples from the Express backend on mount
  useEffect(() => {
    const loadSamples = async () => {
      try {
        const response = await fetch("/api/dataset");
        const data = await response.json();
        if (data.success && Array.isArray(data.samples)) {
          setSamples(data.samples);
          if (data.samples.length > 0) {
            setSelectedSampleId(data.samples[0].id);
          }
        }
      } catch (err) {
        console.error("Failed to load dataset from server:", err);
      } finally {
        setHasLoadedFromServer(true);
      }
    };
    loadSamples();
  }, []);

  const [selectedSampleId, setSelectedSampleId] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingSample, setEditingSample] = useState<DatasetSample | null>(null);

  // Generation Controls
  const [count, setCount] = useState(5);
  const [insuranceType, setInsuranceType] = useState("");
  const [pipelineType, setPipelineType] = useState("");
  const [customScenario, setCustomScenario] = useState("");

  // UI Status
  const [isLoading, setIsLoading] = useState(false);
  const [loadingProgress, setLoadingProgress] = useState("");
  const [progressIdx, setProgressIdx] = useState(0);
  const [searchQuery, setSearchQuery] = useState("");
  const [filterStatus, setFilterStatus] = useState("all");
  const [successToast, setSuccessToast] = useState("");
  const [isAutoCorrecting, setIsAutoCorrecting] = useState(false);

  // Sidebar Collapsible States
  const [leftCollapsed, setLeftCollapsed] = useState(false);
  const [rightCollapsed, setRightCollapsed] = useState(false);

  // Auto-correct loading tracking by Row ID
  const [repairingIds, setRepairingIds] = useState<Record<string, boolean>>({});

  // Interactive Right Sidebar Prompt / Copilot
  const [repairPrompt, setRepairPrompt] = useState("");

  // Persist samples back to the server whenever modified
  useEffect(() => {
    if (!hasLoadedFromServer) return;
    const saveSamples = async () => {
      try {
        await fetch("/api/dataset/save", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ samples })
        });
      } catch (err) {
        console.error("Failed to save dataset to server:", err);
      }
    };
    saveSamples();
  }, [samples, hasLoadedFromServer]);

  // If samples are loaded and no active sample is selected, auto-select the first one
  useEffect(() => {
    if (samples.length > 0 && !selectedSampleId) {
      setSelectedSampleId(samples[0].id);
    }
  }, [samples, selectedSampleId]);

  // Staggered loading progress messages
  useEffect(() => {
    let interval: any;
    if (isLoading) {
      setProgressIdx(0);
      setLoadingProgress(PROGRESS_MESSAGES[0]);
      interval = setInterval(() => {
        setProgressIdx((prev) => {
          const next = (prev + 1) % PROGRESS_MESSAGES.length;
          setLoadingProgress(PROGRESS_MESSAGES[next]);
          return next;
        });
      }, 2500);
    } else {
      clearInterval(interval);
    }
    return () => clearInterval(interval);
  }, [isLoading]);

  // Self-trigger quick toast
  const triggerToast = (msg: string) => {
    setSuccessToast(msg);
    setTimeout(() => setSuccessToast(""), 3000);
  };

  // Generate synthetic dataset from the Express backend API
  const handleGenerate = async () => {
    setIsLoading(true);
    try {
      const response = await fetch("/api/dataset/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          count,
          insuranceType,
          pipelineType,
          customScenario
        })
      });
      const data = await response.json();
      if (data.success && Array.isArray(data.samples)) {
        // Assign random tracking IDs to each client-side sample
        const parsed = data.samples.map((s: any) => ({
          ...s,
          id: Math.random().toString(36).substr(2, 9)
        }));
        
        // Strictly APPEND new samples, do not replace!
        setSamples((prev) => [...parsed, ...prev]);
        if (parsed.length > 0) {
          setSelectedSampleId(parsed[0].id);
        }
        triggerToast(`Successfully generated ${parsed.length} synthetic examples!`);
      } else {
        alert("Failed: " + (data.error || "Unknown server error"));
      }
    } catch (err: any) {
      alert("Error: " + err.message);
    } finally {
      setIsLoading(false);
    }
  };

  // AI-Assisted Smart Auto-Correction utilizing Gemini backend
  const handleAutoCorrect = async (sample: DatasetSample, feedback: string) => {
    setIsAutoCorrecting(true);
    try {
      const response = await fetch("/api/dataset/correct-sample", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sample, feedback })
      });
      const data = await response.json();
      if (data.success && data.sample) {
        // Keep ID intact
        const corrected = { ...data.sample, id: sample.id };
        setSamples((prev) => prev.map((s) => (s.id === sample.id ? corrected : s)));
        setEditingSample(corrected);
        triggerToast("AI successfully repaired this dialogue!");
      } else {
        alert("Correction failed: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error executing correction: " + err.message);
    } finally {
      setIsAutoCorrecting(false);
    }
  };

  // Real-time automatic row correction
  const handleAutoCorrectRow = async (sample: DatasetSample) => {
    // Add row to repairing states
    setRepairingIds(prev => ({ ...prev, [sample.id]: true }));
    
    // Compute what is missing
    const validation = validateSample(sample);
    const missingErrors = validation.errors.map((e) => `- [${e.ruleId}]: ${e.message}`).join("\n");
    const feedback = `The sample is currently failing these validation rules:\n${missingErrors}\n\nPlease correct the sample specifically targeting these missing parts. Ensure it remains a complete 3-column dialogue (messages, tools, text) with correct order: getCurrentLocation -> getInsuranceCoverageBlock -> search/nearby -> rank, using ONLY the approved hospital list. Use the canonical 5-tool schema: searchHospitalsByCondition requires condition+coverageBlock+lat+lng; getNearbyHospitals requires lat+lng only; coverageBlock has providerName, copayPercent, outpatientCovered.`;

    try {
      const response = await fetch("/api/dataset/correct-sample", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sample, feedback })
      });
      const data = await response.json();
      if (data.success && data.sample) {
        // Replace current solved solution
        const corrected = { ...data.sample, id: sample.id };
        setSamples((prev) => prev.map((s) => (s.id === sample.id ? corrected : s)));
        triggerToast("AI repaired and updated the SFT row successfully!");
      } else {
        alert("AI Repair failed: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error repairing row: " + err.message);
    } finally {
      setRepairingIds(prev => ({ ...prev, [sample.id]: false }));
    }
  };

  // Sidebar direct Repair Copilot function for active row
  const handleSidebarRepair = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedSampleId || !repairPrompt.trim()) return;
    const active = samples.find((s) => s.id === selectedSampleId);
    if (!active) return;

    setIsAutoCorrecting(true);
    try {
      const response = await fetch("/api/dataset/correct-sample", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sample: active, feedback: repairPrompt })
      });
      const data = await response.json();
      if (data.success && data.sample) {
        const corrected = { ...data.sample, id: active.id };
        setSamples((prev) => prev.map((s) => (s.id === active.id ? corrected : s)));
        setRepairPrompt("");
        triggerToast("Repair Copilot has applied the requested changes!");
      } else {
        alert("Repair failed: " + (data.error || "Unknown error"));
      }
    } catch (err: any) {
      alert("Error executing repair: " + err.message);
    } finally {
      setIsAutoCorrecting(false);
    }
  };

  // Manual save edits on SFT dialog modal
  const handleSaveEdit = (updated: DatasetSample) => {
    setSamples((prev) => prev.map((s) => (s.id === updated.id ? updated : s)));
    triggerToast("Sample changes saved.");
  };

  // Import previous dataset lines (JSONL or JSON format)
  const handleImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      try {
        const text = evt.target?.result as string;
        let loaded: DatasetSample[] = [];

        // Check if JSON array
        if (text.trim().startsWith("[")) {
          const parsed = JSON.parse(text);
          loaded = parsed.map((s: any) => ({
            id: s.id || Math.random().toString(36).substr(2, 9),
            messages: s.messages || [],
            tools: s.tools || [],
            text: s.text || ""
          }));
        } else {
          // Assume JSONL line-by-line format
          const lines = text.split("\n").filter((l) => l.trim().length > 0);
          loaded = lines.map((line) => {
            const s = JSON.parse(line);
            return {
              id: s.id || Math.random().toString(36).substr(2, 9),
              messages: s.messages || [],
              tools: s.tools || [],
              text: s.text || ""
            };
          });
        }

        setSamples((prev) => [...loaded, ...prev]);
        if (loaded.length > 0) {
          setSelectedSampleId(loaded[0].id);
        }
        triggerToast(`Successfully imported ${loaded.length} training examples!`);
      } catch (err) {
        alert("Import failed. Make sure the file format is valid JSONL or JSON Array.");
      }
    };
    reader.readAsText(file);
  };

  // Export as strict JSONL format (One complete JSON string per line, no array)
  const handleExportJSONL = () => {
    if (samples.length === 0) return;
    const lines = samples.map((s) => {
      const stripped = {
        messages: s.messages,
        tools: s.tools,
        text: s.text
      };
      return JSON.stringify(stripped);
    });
    const blob = new Blob([lines.join("\n")], { type: "application/jsonl" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `ranga_synthetic_dataset_${Date.now()}.jsonl`;
    a.click();
    triggerToast("Dataset exported as valid SFT JSONL!");
  };

  // Export as full JSON array
  const handleExportJSON = () => {
    if (samples.length === 0) return;
    const stripped = samples.map((s) => ({
      messages: s.messages,
      tools: s.tools,
      text: s.text
    }));
    const blob = new Blob([JSON.stringify(stripped, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `ranga_synthetic_dataset_${Date.now()}.json`;
    a.click();
    triggerToast("Dataset exported as formatted JSON!");
  };

  // Copy minified SFT JSONL block to clipboard
  const copyJSONLToClipboard = () => {
    if (samples.length === 0) return;
    const lines = samples.map((s) => {
      const stripped = { messages: s.messages, tools: s.tools, text: s.text };
      return JSON.stringify(stripped);
    }).join("\n");
    navigator.clipboard.writeText(lines);
    triggerToast("Minified JSONL copied to clipboard!");
  };

  // Delete specific sample
  const handleDelete = (id: string) => {
    setSamples((prev) => prev.filter((s) => s.id !== id));
    if (selectedSampleId === id) {
      setSelectedSampleId(null);
    }
    triggerToast("Sample removed.");
  };

  // Clear all samples from server-side database
  const handleClearDataset = () => {
    if (window.confirm("Are you sure you want to clear all local SFT records? This cannot be undone.")) {
      setSamples([]);
      setSelectedSampleId(null);
      triggerToast("Database reset successfully.");
    }
  };

  // Get active selected sample
  const activeSample = samples.find((s) => s.id === selectedSampleId);

  // Client-side visual filter
  const filteredSamples = samples.filter((sample) => {
    // Check validation status
    const isValid = validateSample(sample).isValid;
    if (filterStatus === "valid" && !isValid) return false;
    if (filterStatus === "broken" && isValid) return false;

    // Search query on patient text concern
    if (searchQuery.trim().length > 0) {
      const q = searchQuery.toLowerCase();
      const matchText = JSON.stringify(sample.messages).toLowerCase();
      return matchText.includes(q);
    }
    return true;
  });

  return (
    <div id="app-root-shell" className="min-h-screen bg-[#0d0c0c] text-neutral-200 flex flex-row font-sans overflow-hidden">
      
      {/* Toast Notification */}
      <AnimatePresence>
        {successToast && (
          <motion.div
            id="toast-popup"
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            className="fixed top-5 left-1/2 -translate-x-1/2 z-50 bg-[#1e1c1b] text-neutral-100 font-semibold text-xs px-5 py-3.5 rounded-xl shadow-2xl flex items-center gap-2 border border-white/10"
          >
            <Sparkles className="w-4 h-4 text-amber-500 animate-pulse" />
            {successToast}
          </motion.div>
        )}
      </AnimatePresence>

      {/* LEFT SIDEBAR: Matches the image's dark, premium rail */}
      <aside 
        id="sidebar-left" 
        className={`${
          leftCollapsed ? "w-16" : "w-64"
        } bg-[#090808] border-r border-neutral-800 flex flex-col justify-between shrink-0 select-none z-10 transition-all duration-300`}
      >
        <div className="flex flex-col">
          {/* Workspace dropdown switcher header */}
          <div id="workspace-header" className="p-4 border-b border-neutral-800/60 flex flex-col gap-3">
            {!leftCollapsed ? (
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  <div className="w-6.5 h-6.5 bg-gradient-to-tr from-amber-600 to-indigo-600 rounded-lg flex items-center justify-center text-white text-xs font-bold font-mono">
                    R
                  </div>
                  <div>
                    <span className="text-[11px] font-bold tracking-wider text-neutral-400 font-mono">WORKSPACE</span>
                    <h4 className="text-xs font-bold text-neutral-200 flex items-center gap-1">
                      Kigali Catchment
                      <ChevronDown className="w-3.5 h-3.5 text-neutral-500" />
                    </h4>
                  </div>
                </div>
                <button
                  id="btn-collapse-left"
                  onClick={() => setLeftCollapsed(true)}
                  className="p-1 hover:bg-neutral-800 rounded text-neutral-400 hover:text-white transition-all"
                  title="Collapse Sidebar"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <div className="flex flex-col items-center gap-3">
                <div className="w-7 h-7 bg-gradient-to-tr from-amber-600 to-indigo-600 rounded-lg flex items-center justify-center text-white text-xs font-bold font-mono shadow-md">
                  R
                </div>
                <button
                  id="btn-expand-left"
                  onClick={() => setLeftCollapsed(false)}
                  className="p-1.5 hover:bg-neutral-800 rounded text-amber-500 hover:text-amber-400 transition-all"
                  title="Expand Sidebar"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            )}
          </div>

          {/* Navigation Items (similar to image) */}
          <nav id="sidebar-nav" className={`p-3 space-y-1.5 mt-4 ${leftCollapsed ? "flex flex-col items-center" : ""}`}>
            <button
              id="nav-btn-overview"
              onClick={() => setActiveView("overview")}
              title="Overview"
              className={`flex items-center rounded-lg text-xs font-semibold transition-all ${
                leftCollapsed 
                  ? "p-2.5 justify-center" 
                  : "w-full justify-between px-3 py-2.5"
              } ${
                activeView === "overview"
                  ? "bg-[#181615] text-white border-l-2 border-amber-500/80 shadow-md"
                  : "text-neutral-400 hover:bg-neutral-900/50 hover:text-neutral-200"
              }`}
            >
              <div className="flex items-center gap-2.5">
                <LayoutGrid className={`w-4 h-4 ${activeView === "overview" ? "text-amber-500" : "text-neutral-500"}`} />
                {!leftCollapsed && <span>Overview</span>}
              </div>
              {!leftCollapsed && (
                <span className="text-[10px] font-mono bg-neutral-800 text-neutral-400 px-1.5 py-0.2 rounded font-bold">
                  {samples.length}
                </span>
              )}
            </button>

            <button
              id="nav-btn-structure"
              onClick={() => setActiveView("structure")}
              title="Guidelines"
              className={`flex items-center gap-2.5 rounded-lg text-xs font-semibold transition-all ${
                leftCollapsed 
                  ? "p-2.5 justify-center" 
                  : "w-full px-3 py-2.5"
              } ${
                activeView === "structure"
                  ? "bg-[#181615] text-white border-l-2 border-amber-500/80 shadow-md"
                  : "text-neutral-400 hover:bg-neutral-900/50 hover:text-neutral-200"
              }`}
            >
              <BookOpen className={`w-4 h-4 ${activeView === "structure" ? "text-amber-500" : "text-neutral-500"}`} />
              {!leftCollapsed && <span>Guidelines</span>}
            </button>

            <button
              id="nav-btn-build"
              onClick={() => setActiveView("build")}
              title="Build Output"
              className={`flex items-center gap-2.5 rounded-lg text-xs font-semibold transition-all ${
                leftCollapsed 
                  ? "p-2.5 justify-center" 
                  : "w-full px-3 py-2.5"
              } ${
                activeView === "build"
                  ? "bg-[#181615] text-white border-l-2 border-amber-500/80 shadow-md"
                  : "text-neutral-400 hover:bg-neutral-900/50 hover:text-neutral-200"
              }`}
            >
              <Code className={`w-4 h-4 ${activeView === "build" ? "text-amber-500" : "text-neutral-500"}`} />
              {!leftCollapsed && <span>Build Output</span>}
            </button>

            <button
              id="nav-btn-settings"
              onClick={() => setActiveView("settings")}
              title="Settings"
              className={`flex items-center gap-2.5 rounded-lg text-xs font-semibold transition-all ${
                leftCollapsed 
                  ? "p-2.5 justify-center" 
                  : "w-full px-3 py-2.5"
              } ${
                activeView === "settings"
                  ? "bg-[#181615] text-white border-l-2 border-amber-500/80 shadow-md"
                  : "text-neutral-400 hover:bg-neutral-900/50 hover:text-neutral-200"
              }`}
            >
              <Settings className={`w-4 h-4 ${activeView === "settings" ? "text-amber-500" : "text-neutral-500"}`} />
              {!leftCollapsed && <span>Settings</span>}
            </button>
          </nav>
        </div>

        {/* Footer info in rail */}
        <div id="sidebar-footer" className="p-4 border-t border-neutral-800/60 bg-neutral-950/20 text-[10px] text-neutral-500 font-mono space-y-1">
          {leftCollapsed ? (
            <div className="flex justify-center text-amber-500">
              <span className="w-1.5 h-1.5 bg-amber-500 rounded-full animate-pulse"></span>
            </div>
          ) : (
            <>
              <div className="flex items-center gap-1.5 text-neutral-400">
                <span className="w-1.5 h-1.5 bg-amber-500 rounded-full animate-pulse"></span>
                <span>Local DB Ready</span>
              </div>
              <p>Kigali Hospital SFT</p>
            </>
          )}
        </div>
      </aside>

      {/* MAIN CONTENT AREA */}
      <main id="main-content-scroll" className="flex-1 flex flex-col min-w-0 bg-[#0d0c0c] relative overflow-y-auto">
        
        {/* Loading overlay */}
        {isLoading && (
          <div id="loading-overlay" className="absolute inset-0 bg-black/80 backdrop-blur-md flex flex-col items-center justify-center z-50 p-6 text-center">
            <div className="relative mb-6">
              <div className="w-16 h-16 border-4 border-amber-500/20 border-t-amber-500 rounded-full animate-spin"></div>
              <Sparkles className="w-6 h-6 text-amber-400 absolute inset-0 m-auto animate-pulse" />
            </div>
            <h3 className="text-sm font-bold text-neutral-100 font-mono animate-pulse uppercase tracking-widest">
              Executing SFT Synthesizer
            </h3>
            <div className="max-w-md mt-4 border border-white/5 bg-white/5 p-4 rounded-xl shadow-2xl">
              <p className="text-xs text-amber-300 font-mono">
                {loadingProgress}
              </p>
              <div className="w-full bg-neutral-800 h-1 rounded-full overflow-hidden mt-3">
                <div 
                  className="bg-amber-500 h-full transition-all duration-700" 
                  style={{ width: `${((progressIdx + 1) / PROGRESS_MESSAGES.length) * 100}%` }}
                ></div>
              </div>
            </div>
          </div>
        )}

        {/* Active View Router */}
        <div id="active-view-container" className="p-6 md:p-8 flex-1 flex flex-col min-h-0">
          
          {/* Header Title bar */}
          <div id="view-header-row" className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-neutral-800 pb-5 mb-6 shrink-0">
            <div>
              <h1 className="text-2xl font-bold text-white tracking-tight font-sans">
                {activeView === "overview" && "SFT Dialogue Workspace"}
                {activeView === "structure" && "Structure & Guidelines"}
                {activeView === "build" && "Build Output (.jsonl)"}
                {activeView === "settings" && "Workspace Settings"}
              </h1>
              <p className="text-xs text-neutral-400 mt-1">
                {activeView === "overview" && "Produce and validate fine-tuning training dataset rows in local storage."}
                {activeView === "structure" && "Strict rules regarding insurance limits and location distances."}
                {activeView === "build" && "Direct JSONL format preview, clipboard copying, and downloads."}
                {activeView === "settings" && "Configure local records, upload previous files, and clear databases."}
              </p>
            </div>

            {/* Quick Export / Utilities */}
            <div className="flex items-center gap-2">
              <button
                id="btn-toggle-inspector-main"
                onClick={() => setRightCollapsed(!rightCollapsed)}
                className={`px-3 py-1.5 border rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                  !rightCollapsed 
                    ? "bg-[#181615] border-amber-500/30 text-amber-500" 
                    : "bg-neutral-900 border-neutral-800 text-neutral-300 hover:text-white hover:bg-neutral-800"
                }`}
                title="Toggle SFT Inspector"
              >
                <GitBranch className="w-3.5 h-3.5" />
                {rightCollapsed ? "Open Inspector" : "Close Inspector"}
              </button>
              <button
                id="btn-copy-main-header"
                onClick={copyJSONLToClipboard}
                disabled={samples.length === 0}
                className="px-3 py-1.5 bg-neutral-900 border border-neutral-800 hover:bg-neutral-800 disabled:opacity-40 text-neutral-300 hover:text-white rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5"
              >
                <Clipboard className="w-3.5 h-3.5" />
                Copy JSONL
              </button>
              <button
                id="btn-export-main-header"
                onClick={handleExportJSONL}
                disabled={samples.length === 0}
                className="px-3 py-1.5 bg-amber-600/90 hover:bg-amber-500 disabled:opacity-40 text-white rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 shadow-lg shadow-amber-600/10"
              >
                <Download className="w-3.5 h-3.5" />
                Export
              </button>
            </div>
          </div>

          {/* OVERVIEW TAB: (Generate & SFT Table, No statistics as requested!) */}
          {activeView === "overview" && (
            <div id="overview-content-block" className="flex-1 flex flex-col gap-6 min-h-0">
              
              {/* Generation Controls Block - Sleek & Compact Dark Design */}
              <div id="generator-settings-card" className="bg-[#121110] border border-neutral-800 p-5 rounded-xl shadow-lg shrink-0">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b border-neutral-800">
                  <Sparkles className="w-4 h-4 text-amber-500" />
                  <h3 className="text-xs font-bold text-neutral-200 uppercase tracking-wider font-mono">
                    Synthetic Training Curation Settings
                  </h3>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Batch count Selection */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-neutral-400 uppercase font-mono tracking-wider block">
                      Dialogue Rows to generate
                    </label>
                    <div className="flex items-center gap-3">
                      <input
                        type="range"
                        min="1"
                        max="20"
                        value={count}
                        onChange={(e) => setCount(parseInt(e.target.value))}
                        className="flex-1 accent-amber-500 h-1 bg-neutral-800 rounded-lg cursor-pointer"
                      />
                      <span className="text-xs font-bold font-mono bg-neutral-900 px-2 py-1 rounded border border-neutral-800 text-amber-500 w-10 text-center">
                        {count}
                      </span>
                    </div>
                  </div>

                  {/* Insurance Target Selection */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-neutral-400 uppercase font-mono tracking-wider block">
                      Insurance Policy Constraint
                    </label>
                    <select
                      value={insuranceType}
                      onChange={(e) => setInsuranceType(e.target.value)}
                      className="w-full text-xs px-3 py-2 bg-neutral-950 border border-neutral-800 rounded-lg text-neutral-200 focus:outline-none focus:border-amber-500/50 font-semibold"
                    >
                      <option value="">Alternate (Britam / Old Mutual)</option>
                      <option value="Britam">Britam (Inpatient 100% No Copay)</option>
                      <option value="Old Mutual">Old Mutual (Outpatient/Inpatient 15% Copay)</option>
                    </select>
                  </div>

                  {/* Workflow Pipeline Focus */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-neutral-400 uppercase font-mono tracking-wider block">
                      Tool Execution Path
                    </label>
                    <select
                      value={pipelineType}
                      onChange={(e) => setPipelineType(e.target.value)}
                      className="w-full text-xs px-3 py-2 bg-neutral-950 border border-neutral-800 rounded-lg text-neutral-200 focus:outline-none focus:border-amber-500/50 font-semibold"
                    >
                      <option value="">Alternate All Scenarios</option>
                      <option value="Condition-search">Condition & Specialty Search Path</option>
                      <option value="Nearby-search">General Nearby Hospital Lookup</option>
                      <option value="Clinic-info">Contact & Detail Verification</option>
                    </select>
                  </div>
                </div>

                {/* Optional Custom Symptoms/Scenario */}
                <div className="mt-4 pt-3 border-t border-neutral-800/40">
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-bold text-neutral-400 uppercase font-mono tracking-wider block flex items-center justify-between">
                      <span>Incorporate Custom Medical Topic / Student Symptom Context</span>
                      <span className="text-[9px] text-neutral-500 italic lowercase font-normal">e.g. mental health, dentist, sport sprain</span>
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. University dental pain, late-night high fever with cough, Old Mutual co-pay limits..."
                      className="w-full text-xs px-3 py-2 bg-neutral-950 border border-neutral-800 rounded-lg text-neutral-200 placeholder-neutral-600 focus:outline-none focus:border-amber-500/50 font-semibold"
                      value={customScenario}
                      onChange={(e) => setCustomScenario(e.target.value)}
                    />
                  </div>
                </div>

                {/* CTA Action button */}
                <div className="mt-4 flex justify-end">
                  <button
                    id="btn-trigger-generation"
                    onClick={handleGenerate}
                    className="px-5 py-2.5 bg-amber-600 hover:bg-amber-500 text-white rounded-lg text-xs font-bold transition-all shadow-lg shadow-amber-600/10 flex items-center gap-2"
                  >
                    <Sparkles className="w-3.5 h-3.5" />
                    Generate SFT Examples (Appends to DB)
                  </button>
                </div>
              </div>

              {/* Table of SFT Content rows - 4-Column Format as requested */}
              <div id="dataset-table-card" className="bg-[#121110] border border-neutral-800 p-5 rounded-xl shadow-lg flex-1 flex flex-col min-h-0">
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 mb-4 shrink-0">
                  <div>
                    <h3 className="text-xs font-bold text-neutral-200 uppercase tracking-wider font-mono">
                      SFT Training Rows Drafts
                    </h3>
                    <p className="text-xs text-neutral-400 mt-1">
                      Draft curated dataset. Selected rows are inspected in the right sidebar.
                    </p>
                  </div>
                  <span className="text-[10px] font-bold bg-neutral-900 border border-neutral-800 text-amber-500 font-mono px-2.5 py-1 rounded-full shrink-0">
                    {filteredSamples.length} rows loaded
                  </span>
                </div>

                {/* Filter and search utilities */}
                <div className="flex flex-col md:flex-row gap-3 mb-4 shrink-0">
                  <div className="relative flex-1">
                    <Search className="w-4 h-4 text-neutral-500 absolute left-3 top-2.5" />
                    <input
                      type="text"
                      placeholder="Search symptom keywords, policies, or hospital names..."
                      className="w-full text-xs pl-9 pr-4 py-2 bg-neutral-950 border border-neutral-800 rounded-lg focus:outline-none focus:border-amber-500/50 text-neutral-200 placeholder-neutral-600 font-medium"
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                    />
                  </div>

                  <div className="flex items-center gap-2">
                    <Filter className="w-4 h-4 text-neutral-500 shrink-0" />
                    <select
                      value={filterStatus}
                      onChange={(e) => setFilterStatus(e.target.value)}
                      className="text-xs px-3 py-2 bg-neutral-950 border border-neutral-800 rounded-lg text-neutral-200 focus:outline-none font-semibold"
                    >
                      <option value="all">All Validation Statuses</option>
                      <option value="valid">Compliant SFT Only</option>
                      <option value="broken">Broken / Lint Issues Only</option>
                    </select>
                  </div>
                </div>

                {/* Responsive 4-Column Table */}
                <div className="flex-1 overflow-y-auto border border-neutral-800 rounded-lg bg-neutral-950/40">
                  <table className="w-full text-left border-collapse text-xs">
                    <thead>
                      <tr className="bg-neutral-900 text-neutral-400 uppercase font-mono tracking-wider border-b border-neutral-800 sticky top-0 z-10">
                        <th className="py-2.5 px-4 font-bold text-neutral-400 w-[45%]">Turn ID & Patient Symptoms</th>
                        <th className="py-2.5 px-4 font-bold text-neutral-400 w-[20%]">Insurance Policy</th>
                        <th className="py-2.5 px-4 font-bold text-neutral-400 w-[20%]">Workflow Quality Status</th>
                        <th className="py-2.5 px-4 font-bold text-neutral-400 text-center w-[15%]">Action of correct</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-neutral-800/60">
                      {filteredSamples.length > 0 ? (
                        filteredSamples.map((sample) => {
                          const validation = validateSample(sample);
                          const userMsg = sample.messages.find((m) => m.role === "user");
                          const caseText = userMsg ? userMsg.content : "No patient symptoms specified";

                          // Insurance tags
                          const isBritam = JSON.stringify(sample.messages).toLowerCase().includes("britam");
                          const isOM = JSON.stringify(sample.messages).toLowerCase().includes("old mutual");

                          const isSelected = sample.id === selectedSampleId;

                          return (
                            <tr
                              key={sample.id}
                              onClick={() => setSelectedSampleId(sample.id)}
                              className={`transition-colors group cursor-pointer ${
                                isSelected 
                                  ? "bg-amber-500/5 hover:bg-amber-500/10 border-l-2 border-l-amber-500" 
                                  : "hover:bg-neutral-900/40"
                              }`}
                            >
                              {/* Column 1: Row index, Hash, Layperson Symptoms */}
                              <td className="py-3 px-4 align-top">
                                <div className="flex items-center gap-2 mb-1">
                                  <span className="text-[10px] font-bold font-mono text-amber-500 bg-amber-500/10 border border-amber-500/20 px-1.5 py-0.2 rounded">
                                    Row #{samples.indexOf(sample) + 1}
                                  </span>
                                  <span className="text-[9px] text-neutral-500 font-mono">
                                    ID: {sample.id}
                                  </span>
                                </div>
                                <p className="text-neutral-200 font-medium line-clamp-1 leading-relaxed">
                                  {caseText}
                                </p>
                              </td>

                              {/* Column 2: Insurance policy type detected */}
                              <td className="py-3 px-4 align-top">
                                <div className="flex flex-col gap-1">
                                  {isBritam && (
                                    <span className="inline-flex text-[9px] font-bold font-mono bg-blue-500/10 text-blue-400 border border-blue-500/20 px-2 py-0.5 rounded uppercase self-start">
                                      Britam
                                    </span>
                                  )}
                                  {isOM && (
                                    <span className="inline-flex text-[9px] font-bold font-mono bg-indigo-500/10 text-indigo-400 border border-indigo-500/20 px-2 py-0.5 rounded uppercase self-start">
                                      Old Mutual
                                    </span>
                                  )}
                                  {!isBritam && !isOM && (
                                    <span className="text-[9px] font-mono text-neutral-500 italic">
                                      No policy
                                    </span>
                                  )}
                                </div>
                              </td>

                              {/* Column 3: Validation SFT compliance status */}
                              <td className="py-3 px-4 align-top">
                                <div className="flex flex-col gap-1">
                                  {validation.isValid ? (
                                    <span className="inline-flex items-center gap-1 text-[9px] font-bold font-mono text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-2 py-0.5 rounded-full uppercase self-start">
                                      <CheckCircle className="w-3 h-3 text-emerald-500" />
                                      Compliant
                                    </span>
                                  ) : (
                                    <div className="space-y-0.5">
                                      <span className="inline-flex items-center gap-1 text-[9px] font-bold font-mono text-rose-400 bg-rose-500/10 border border-rose-500/20 px-2 py-0.5 rounded-full uppercase self-start">
                                        <AlertTriangle className="w-3 h-3 text-rose-500" />
                                        Broken
                                      </span>
                                      {validation.errors.length > 0 && (
                                        <p className="text-[9px] text-rose-300/60 font-mono truncate max-w-[130px]" title={validation.errors[0].message}>
                                          {validation.errors[0].message}
                                        </p>
                                      )}
                                    </div>
                                  )}
                                </div>
                              </td>

                              {/* Column 4: Action of correct */}
                              <td className="py-3 px-4 align-top text-center whitespace-nowrap" onClick={(e) => e.stopPropagation()}>
                                <div className="flex items-center justify-center gap-1.5">
                                  {!validation.isValid ? (
                                    <button
                                      disabled={repairingIds[sample.id]}
                                      onClick={() => handleAutoCorrectRow(sample)}
                                      className={`px-2.5 py-1 rounded text-[10px] font-bold transition-all shadow-sm flex items-center gap-1 ${
                                        repairingIds[sample.id]
                                          ? "bg-amber-500/10 text-amber-300/60 border border-amber-500/10 cursor-not-allowed"
                                          : "bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 border border-amber-500/20 animate-pulse"
                                      }`}
                                    >
                                      {repairingIds[sample.id] ? (
                                        <>
                                          <RefreshCw className="w-2.5 h-2.5 animate-spin" />
                                          Fixing...
                                        </>
                                      ) : (
                                        <>
                                          <Sparkles className="w-2.5 h-2.5" />
                                          Correct
                                        </>
                                      )}
                                    </button>
                                  ) : (
                                    <button
                                      onClick={() => {
                                        setSelectedSampleId(sample.id);
                                        setEditingSample(sample);
                                        setIsModalOpen(true);
                                      }}
                                      className="px-2.5 py-1 bg-neutral-800 hover:bg-neutral-700 text-neutral-300 border border-neutral-700 rounded text-[10px] font-bold transition-all flex items-center gap-1"
                                    >
                                      <Eye className="w-2.5 h-2.5" />
                                      Edit Row
                                    </button>
                                  )}

                                  <button
                                    onClick={() => handleDelete(sample.id)}
                                    className="p-1 hover:bg-rose-500/10 rounded text-neutral-500 hover:text-rose-400 transition-colors"
                                    title="Delete row"
                                  >
                                    <Trash2 className="w-3.5 h-3.5" />
                                  </button>
                                </div>
                              </td>
                            </tr>
                          );
                        })
                      ) : (
                        <tr>
                          <td colSpan={4} className="py-16 text-center text-neutral-500 font-mono">
                            <Database className="w-10 h-10 text-neutral-700 mx-auto mb-3 animate-pulse" />
                            <h4 className="text-xs font-bold text-neutral-400">Database is empty</h4>
                            <p className="text-[11px] text-neutral-500 mt-1 max-w-[280px] mx-auto">
                              Configure settings above and click generate, or import an existing JSONL draft inside Settings.
                            </p>
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          )}

          {/* STRUCTURE TAB: Displays approved reference guidelines table */}
          {activeView === "structure" && (
            <div id="structure-content-block" className="flex-1 overflow-y-auto">
              <MasoroReference />
            </div>
          )}

          {/* BUILD TAB: Raw previews of code output */}
          {activeView === "build" && (
            <div id="build-content-block" className="flex-1 flex flex-col gap-6 min-h-0">
              <div className="bg-[#121110] border border-neutral-800 p-5 rounded-xl shadow-lg flex-1 flex flex-col min-h-0">
                <div className="flex items-center justify-between border-b border-neutral-800 pb-3 mb-4 shrink-0">
                  <div>
                    <h3 className="text-xs font-bold text-neutral-200 uppercase tracking-wider font-mono">
                      Exportable JSONL Stream Code Workspace
                    </h3>
                    <p className="text-[11px] text-neutral-400 mt-1">
                      One complete dialogue sample per line, stripped of temporary workspace IDs to fulfill strict fine-tuning specs.
                    </p>
                  </div>
                  <span className="text-[10px] font-mono font-bold bg-neutral-900 border border-neutral-800 text-amber-500 px-2 py-0.5 rounded">
                    Total Characters: {
                      samples.map(s => JSON.stringify({ messages: s.messages, tools: s.tools, text: s.text })).join("\n").length
                    }
                  </span>
                </div>

                <div className="flex-1 overflow-auto bg-neutral-950 p-4 rounded-lg font-mono text-[11px] text-neutral-300 leading-relaxed border border-neutral-800">
                  {samples.length > 0 ? (
                    <pre className="whitespace-pre-wrap font-mono">
                      {samples.map((s, idx) => {
                        const stripped = { messages: s.messages, tools: s.tools, text: s.text };
                        return (
                          <div key={idx} className="pb-3 border-b border-neutral-900/60 mb-3 last:border-0 last:mb-0">
                            <span className="text-amber-500/80 font-bold block mb-1"># LINE {idx + 1}:</span>
                            {JSON.stringify(stripped)}
                          </div>
                        );
                      })}
                    </pre>
                  ) : (
                    <div className="h-full flex flex-col items-center justify-center text-neutral-500">
                      <Terminal className="w-8 h-8 text-neutral-700 mb-2" />
                      <span>No compiled data rows. Generate training batches to populate.</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* SETTINGS TAB: Workspace imports & storage reset */}
          {activeView === "settings" && (
            <div id="settings-content-block" className="max-w-2xl space-y-6">
              
              {/* Drag-and-Drop file import box */}
              <div className="bg-[#121110] border border-neutral-800 p-5 rounded-xl shadow-lg">
                <h3 className="text-sm font-bold text-neutral-200 mb-1 flex items-center gap-2">
                  <Upload className="w-4 h-4 text-amber-500" />
                  Import Training Dataset File
                </h3>
                <p className="text-xs text-neutral-400 mb-4">
                  Drag and drop or select a previously exported `.jsonl` or `.json` array containing structured turns. Imported data will be appended to server database.
                </p>

                <div className="border-2 border-dashed border-neutral-800 hover:border-neutral-700 bg-neutral-950/40 p-8 rounded-xl text-center cursor-pointer transition-colors relative">
                  <Upload className="w-8 h-8 text-neutral-500 mx-auto mb-3" />
                  <span className="text-xs font-semibold text-neutral-300 block">
                    Click to select file on disk
                  </span>
                  <span className="text-[10px] text-neutral-500 font-mono mt-1 block">
                    Accepts JSON Lines (.jsonl) or standard JSON arrays
                  </span>
                  <input
                    type="file"
                    accept=".json,.jsonl"
                    onChange={handleImport}
                    className="absolute inset-0 opacity-0 cursor-pointer"
                  />
                </div>
              </div>

              {/* Danger Zone: Clear database */}
              <div className="bg-[#121110] border border-red-950 p-5 rounded-xl shadow-lg">
                <h3 className="text-sm font-bold text-red-400 mb-1 flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 text-red-500" />
                  Danger Zone
                </h3>
                <p className="text-xs text-neutral-400 mb-4">
                  Erase all SFT dialogue drafts inside your server-side dataset.json database and start completely fresh.
                </p>

                <button
                  id="btn-danger-reset"
                  onClick={handleClearDataset}
                  className="px-4 py-2 bg-red-950/40 hover:bg-red-950/80 border border-red-900/60 text-red-300 rounded-lg text-xs font-bold transition-all"
                >
                  Reset Database
                </button>
              </div>
            </div>
          )}

        </div>
      </main>

      {/* RIGHT SIDEBAR: Matches the image's "PR #101 Details" sidebar layout */}
      <aside 
        id="sidebar-right-inspector" 
        className={`bg-[#090808] flex flex-col justify-between shrink-0 select-none z-10 transition-all duration-300 border-neutral-800 ${
          rightCollapsed ? "w-0 border-l-0 overflow-hidden" : "w-96 border-l"
        }`}
      >
        
        {/* Sidebar Header details */}
        <div className="p-4 border-b border-neutral-800/60 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <GitBranch className="w-4 h-4 text-amber-500" />
            <h4 className="text-xs font-bold text-neutral-200 uppercase tracking-wider font-mono">
              SFT Row Inspector
            </h4>
          </div>
          <div className="flex items-center gap-1.5">
            {activeSample && (
              <span className="text-[10px] font-mono text-neutral-400 bg-neutral-900 border border-neutral-800 px-2 py-0.5 rounded">
                #{samples.indexOf(activeSample) + 1}
              </span>
            )}
            <button
              id="btn-collapse-right"
              onClick={() => setRightCollapsed(true)}
              className="p-1 hover:bg-neutral-800 rounded text-neutral-400 hover:text-white transition-colors"
              title="Collapse Inspector"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Scrollable details contents */}
        <div className="flex-1 overflow-y-auto p-4 space-y-5">
          {activeSample ? (
            <div className="space-y-5">
              {/* Draft Status card */}
              <div className="bg-neutral-900/50 border border-neutral-800 p-3.5 rounded-lg space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-amber-500 block animate-pulse"></span>
                    <span className="text-[10px] font-bold text-amber-400 uppercase tracking-wide font-mono">
                      Draft Active Trace
                    </span>
                  </div>
                  <span className="text-[9px] text-neutral-500 font-mono">ID: {activeSample.id}</span>
                </div>
                <h3 className="text-xs font-bold text-neutral-100 line-clamp-2">
                  {activeSample.messages.find((m) => m.role === "user")?.content || "No patient symptoms specified."}
                </h3>
                <div className="pt-2 border-t border-neutral-800/60 flex items-center justify-between text-[10px] text-neutral-500 font-mono">
                  <span>Synthesized via Gemini</span>
                  <span className="flex items-center gap-1">
                    <User className="w-3 h-3 text-neutral-600" />
                    Copilot
                  </span>
                </div>
              </div>

              {/* SFT Live Lint Feedback */}
              <div className="space-y-2">
                <h5 className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider font-mono">
                  Real-time Quality Compliance
                </h5>
                <LinterReport sample={activeSample} />
              </div>

              {/* Pipeline step tracing visualizer */}
              <div className="space-y-2">
                <h5 className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider font-mono">
                  Sequence Workflow
                </h5>
                <SampleInspector sample={activeSample} />
              </div>

            </div>
          ) : (
            <div className="h-full flex flex-col items-center justify-center text-center py-20 text-neutral-500">
              <Database className="w-10 h-10 text-neutral-800 mb-3 animate-pulse" />
              <h4 className="text-xs font-bold text-neutral-400">Select an SFT Row to Inspect</h4>
              <p className="text-[10px] text-neutral-500 mt-2 max-w-[200px]">
                Click on any draft row in your dataset table on the left to trace its clinical compliance, view validation errors, and execute repair actions.
              </p>
            </div>
          )}
        </div>

        {/* BOTTOM REPAIR COPILOT: Matches "Ask anything about PR" text area in the image */}
        <div className="p-4 border-t border-neutral-800/60 bg-neutral-950/30">
          {activeSample ? (
            <form onSubmit={handleSidebarRepair} className="space-y-2">
              <div className="flex items-center justify-between text-[10px] text-neutral-400 font-mono px-0.5">
                <span>Ask Repair Copilot to fix row</span>
                <span className="text-neutral-500 text-[9px] italic">Gemini v3.5</span>
              </div>
              <div className="relative">
                <textarea
                  value={repairPrompt}
                  onChange={(e) => setRepairPrompt(e.target.value)}
                  placeholder="e.g. 'Use legacy_clinics instead of King Faisal and set Old Mutual 15% co-pay'..."
                  disabled={isAutoCorrecting}
                  rows={2}
                  className="w-full text-xs p-3 bg-neutral-950 border border-neutral-800 rounded-lg text-neutral-200 placeholder-neutral-600 focus:outline-none focus:border-amber-500/50 resize-none font-semibold leading-relaxed"
                />
                <button
                  type="submit"
                  disabled={isAutoCorrecting || !repairPrompt.trim()}
                  className="absolute bottom-2.5 right-2.5 p-1.5 bg-neutral-900 border border-neutral-800 text-amber-500 hover:text-amber-400 hover:bg-neutral-800 rounded-md transition-colors disabled:opacity-40"
                  title="Submit prompt"
                >
                  {isAutoCorrecting ? (
                    <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                  ) : (
                    <Send className="w-3.5 h-3.5" />
                  )}
                </button>
              </div>
            </form>
          ) : (
            <div className="p-3 bg-neutral-950/20 text-center rounded-lg border border-neutral-900">
              <span className="text-[10px] text-neutral-600 font-mono">
                Select a row to activate Repair Copilot
              </span>
            </div>
          )}
        </div>

      </aside>

      {/* MODAL EDIT DIALOG OVERLAY */}
      {editingSample && (
        <SampleModal
          sample={editingSample}
          isOpen={isModalOpen}
          onClose={() => {
            setIsModalOpen(false);
            setEditingSample(null);
          }}
          onSave={handleSaveEdit}
          onAutoCorrect={handleAutoCorrect}
          isAutoCorrecting={isAutoCorrecting}
        />
      )}

    </div>
  );
}
