#!/usr/bin/env python3
"""Generate deterministic mock eval artifacts for diagrams and report drafting.

The training notebooks are the source of truth for real evaluation. This helper
mirrors the notebook report shape so you can draft tables, traces, and charts
before running an actual model.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
DEFAULT_EVAL_PATH = ROOT.parent / "dataset" / "ranga_output" / "ranga_eval_20.csv"
DEFAULT_OUTPUT_DIR = ROOT / "results" / "simulated_eval"

METRIC_LABELS = [
    ("Tool Order Accuracy (TOA)", "tool_order_accuracy"),
    ("Pipeline Selection Accuracy (PSA)", "pipeline_accuracy"),
    ("First Tool Accuracy (FTA)", "first_tool_accuracy"),
    ("Rank Tool Invocation Rate (RTIR)", "rank_tool_rate"),
    ("Insurance Argument Accuracy (IAA)", "insurance_argument_accuracy"),
    ("Mean Completion Rate (MCR)", "mean_completion_rate"),
    ("Functional Pass Rate (FPR)", "functional_pass_rate"),
    ("Argument Accuracy", "argument_accuracy"),
    ("Extra Tool Rate", "extra_tool_rate"),
    ("Early Stop Rate", "early_stop_rate"),
    ("Rank Skip Rate", "rank_skip_rate"),
]

VALID_TOOL_NAMES = {
    "getCurrentLocation",
    "getInsuranceCoverageBlock",
    "getNearbyHospitals",
    "searchHospitalsByCondition",
    "rankHospitalsByPriorityAndCost",
}

DEFAULT_TOOL = "getCurrentLocation"
PIPELINE_TOOLS = {
    "nearby": ["getCurrentLocation", "getInsuranceCoverageBlock", "getNearbyHospitals", "rankHospitalsByPriorityAndCost"],
    "condition": ["getCurrentLocation", "getInsuranceCoverageBlock", "searchHospitalsByCondition", "rankHospitalsByPriorityAndCost"],
}


@dataclass
class StepPrediction:
    index: int
    expected_tool: str
    predicted_tool: str | None
    raw_output: str
    correct: bool
    extra_calls: int = 0
    hallucinated: bool = False


@dataclass
class EvalCaseResult:
    query: str
    expected_pipeline: str
    predicted_pipeline: str
    expected_tools: list[str]
    predicted_tools: list[str]
    tool_order_correct: bool
    pipeline_correct: bool
    insurance_correct: bool | None
    search_arg_correct: bool | None
    completion_rate: float
    functional_pass: bool
    failure_class: str
    metadata: dict[str, Any] = field(default_factory=dict)
    steps: list[StepPrediction] = field(default_factory=list)


@dataclass
class EvaluationReport:
    model_label: str
    tier: str
    num_cases: int
    tool_order_accuracy: float
    pipeline_accuracy: float
    first_tool_accuracy: float
    rank_tool_rate: float
    insurance_argument_accuracy: float
    mean_completion_rate: float
    functional_pass_rate: float
    argument_accuracy: float
    extra_tool_rate: float
    early_stop_rate: float
    rank_skip_rate: float
    step_accuracies: list[float] = field(default_factory=list)
    per_case: list[EvalCaseResult] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    def summary_dict(self) -> dict[str, Any]:
        data = self.to_dict()
        data.pop("per_case", None)
        return data

    def comparison_table(self, baseline: "EvaluationReport") -> list[dict[str, Any]]:
        rows = []
        for label, key in METRIC_LABELS:
            before = getattr(baseline, key)
            after = getattr(self, key)
            rows.append(
                {
                    "metric": label,
                    "baseline": round(before, 4),
                    "finetuned": round(after, 4),
                    "absolute_gain": round(after - before, 4),
                    "relative_gain_pct": round(((after - before) / before * 100) if before else 0, 2),
                }
            )
        return rows


@dataclass
class EvalRow:
    query: str
    tools_json: str
    expected_pipeline: str
    expected_tool_calls_json: str
    service: str
    insurance: str
    severity: str
    marker: str
    top_hospital: str
    top_price_rwf: str
    score: str
    label: str


def parse_json_list(text: str) -> list[Any]:
    value = json.loads(text)
    return value if isinstance(value, list) else []


def load_eval_rows(path: Path, limit: int | None = None) -> list[EvalRow]:
    rows: list[EvalRow] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle, delimiter="\t")
        for raw in reader:
            if len(raw) < 12:
                continue
            rows.append(
                EvalRow(
                    query=raw[0],
                    tools_json=raw[1],
                    expected_pipeline=raw[2],
                    expected_tool_calls_json=raw[3],
                    service=raw[4],
                    insurance=raw[5],
                    severity=raw[6],
                    marker=raw[7],
                    top_hospital=raw[8],
                    top_price_rwf=raw[9],
                    score=raw[10],
                    label=raw[11],
                )
            )
            if limit is not None and len(rows) >= limit:
                break
    return rows


def infer_pipeline(predicted_tools: list[str]) -> str:
    if "searchHospitalsByCondition" in predicted_tools:
        return "condition"
    if "getNearbyHospitals" in predicted_tools:
        return "nearby"
    return "unknown"


def _reached_search(tools: list[str]) -> bool:
    return "getNearbyHospitals" in tools or "searchHospitalsByCondition" in tools


def _functional_pass(case: EvalCaseResult) -> bool:
    rank_reached = "rankHospitalsByPriorityAndCost" in case.predicted_tools
    return case.tool_order_correct and case.pipeline_correct and rank_reached


def classify_failure(case: EvalCaseResult) -> str:
    if case.functional_pass:
        return "pass"
    if not case.predicted_tools:
        if any(step.hallucinated for step in case.steps):
            return "hallucinated_tool"
        return "no_tool_call"
    if case.predicted_tools[0] != DEFAULT_TOOL:
        return "wrong_first_tool"
    if case.insurance_correct is False:
        return "wrong_insurance_arg"
    if _reached_search(case.predicted_tools) and "rankHospitalsByPriorityAndCost" not in case.predicted_tools:
        return "skipped_rank"
    if not case.pipeline_correct and len(case.predicted_tools) >= 3:
        return "wrong_pipeline"
    if case.predicted_tools != case.expected_tools:
        return "stopped_early"
    return "stopped_early"


def _check_search_args(expected: dict[str, Any], predicted: dict[str, Any] | None) -> bool | None:
    if not predicted:
        return None
    exp_args = expected.get("arguments", {})
    got_args = predicted.get("arguments", {})
    name = expected.get("name")
    if name == "getNearbyHospitals":
        return "lat" in got_args and "lng" in got_args
    if name == "searchHospitalsByCondition":
        exp_cond = str(exp_args.get("condition", "")).lower()
        got_cond = str(got_args.get("condition", "")).lower()
        return bool(got_cond) and (exp_cond in got_cond or got_cond in exp_cond or got_cond == exp_cond)
    return None


def mock_tool_response(tool_name: str, arguments: dict[str, Any] | None = None) -> str:
    arguments = arguments or {}
    if tool_name == "getCurrentLocation":
        payload = {"lat": -1.9695, "lng": 30.1589}
    elif tool_name == "getInsuranceCoverageBlock":
        scheme = arguments.get("insurance", "Britam")
        payload = {"providerName": scheme, "networkKey": str(scheme).lower().replace(" ", ""), "copayPercent": 10.0, "requiresReferral": False}
    elif tool_name in {"getNearbyHospitals", "searchHospitalsByCondition"}:
        payload = {
            "results": [
                {
                    "hospital": {"id": "node/demo", "name": "Demo Hospital", "servicesPrices": {"General Consultation": 10000}},
                    "distanceKm": 1.2,
                    "isInNetwork": True,
                }
            ]
        }
    elif tool_name == "rankHospitalsByPriorityAndCost":
        payload = {"rankedResults": [{"result": {"hospital": {"id": "node/demo"}}, "score": 88.0, "estimatedCopayRwf": 1000}]}
    else:
        payload = {"status": "ok"}
    return json.dumps(payload, ensure_ascii=False)


def serialize_tool_call(name: str, arguments: dict[str, Any] | None = None) -> str:
    arguments = arguments or {}
    return f"<function_call name={name}>{json.dumps(arguments, ensure_ascii=False)}</function_call>"


def pick_error_mode(profile: str, rng: random.Random) -> str:
    if profile == "baseline":
        modes = [
            ("correct", 0.28),
            ("wrong_first_tool", 0.22),
            ("wrong_insurance_arg", 0.18),
            ("skipped_rank", 0.15),
            ("stopped_early", 0.12),
            ("hallucinated_tool", 0.05),
        ]
    else:
        modes = [
            ("correct", 0.86),
            ("wrong_first_tool", 0.03),
            ("wrong_insurance_arg", 0.03),
            ("skipped_rank", 0.03),
            ("stopped_early", 0.03),
            ("hallucinated_tool", 0.02),
        ]
    roll = rng.random()
    total = 0.0
    for mode, weight in modes:
        total += weight
        if roll <= total:
            return mode
    return modes[0][0]


def simulate_case(row: EvalRow, *, profile: str, index: int, seed: int) -> EvalCaseResult:
    rng = random.Random(seed + index * 97)
    expected_tool_calls = parse_json_list(row.expected_tool_calls_json)
    expected_tools = [str(call.get("name", "")) for call in expected_tool_calls]
    mode = pick_error_mode(profile, rng)

    predicted_tools = list(expected_tools)
    predicted_tool_calls = [json.loads(json.dumps(call)) for call in expected_tool_calls]

    if mode == "wrong_first_tool":
        wrong_first = "searchHospitalsByCondition" if row.expected_pipeline == "nearby" else "getNearbyHospitals"
        if predicted_tools:
            predicted_tools[0] = wrong_first
            predicted_tool_calls[0]["name"] = wrong_first
    elif mode == "wrong_insurance_arg" and len(predicted_tool_calls) > 1:
        second_args = predicted_tool_calls[1].setdefault("arguments", {})
        current = str(second_args.get("insurance", row.insurance))
        replacement = "Britam" if current.lower() != "britam" else "RSSB"
        second_args["insurance"] = replacement
    elif mode == "skipped_rank" and predicted_tools:
        if predicted_tools[-1] == "rankHospitalsByPriorityAndCost":
            predicted_tools.pop()
            predicted_tool_calls.pop()
    elif mode == "stopped_early" and len(predicted_tools) > 2:
        keep = 2 if row.expected_pipeline == "nearby" else 3
        predicted_tools = predicted_tools[:keep]
        predicted_tool_calls = predicted_tool_calls[:keep]
    elif mode == "hallucinated_tool":
        predicted_tools.append("lookupNearbyFastestRoute")
        predicted_tool_calls.append({"name": "lookupNearbyFastestRoute", "arguments": {"limit": 3}})

    if mode == "correct":
        if predicted_tool_calls and len(predicted_tool_calls) > 1 and predicted_tool_calls[1].get("name") == "getInsuranceCoverageBlock":
            predicted_tool_calls[1].setdefault("arguments", {})["insurance"] = row.insurance

    steps: list[StepPrediction] = []
    insurance_correct: bool | None = None
    search_arg_correct: bool | None = None

    for step_index, expected in enumerate(expected_tool_calls, start=1):
        if step_index > len(predicted_tool_calls):
            break
        predicted = predicted_tool_calls[step_index - 1]
        predicted_name = str(predicted.get("name"))
        expected_name = str(expected.get("name"))
        raw_output = serialize_tool_call(predicted_name, predicted.get("arguments", {}))
        hallucinated = predicted_name not in VALID_TOOL_NAMES
        extra_calls = 1 if hallucinated else 0
        steps.append(
            StepPrediction(
                index=step_index,
                expected_tool=expected_name,
                predicted_tool=predicted_name,
                raw_output=raw_output,
                correct=predicted_name == expected_name,
                extra_calls=extra_calls,
                hallucinated=hallucinated,
            )
        )

        if expected_name == "getInsuranceCoverageBlock" and predicted:
            exp = str(expected.get("arguments", {}).get("insurance", row.insurance))
            got = str(predicted.get("arguments", {}).get("insurance", ""))
            insurance_correct = got.lower() == exp.lower() if exp else None
        if expected_name in {"getNearbyHospitals", "searchHospitalsByCondition"}:
            search_arg_correct = _check_search_args(expected, predicted)

    predicted_pipeline = infer_pipeline(predicted_tools)
    case = EvalCaseResult(
        query=row.query,
        expected_pipeline=row.expected_pipeline,
        predicted_pipeline=predicted_pipeline,
        expected_tools=expected_tools,
        predicted_tools=predicted_tools,
        tool_order_correct=predicted_tools == expected_tools,
        pipeline_correct=predicted_pipeline == row.expected_pipeline,
        insurance_correct=insurance_correct,
        search_arg_correct=search_arg_correct,
        completion_rate=len(predicted_tools) / max(len(expected_tools), 1),
        functional_pass=False,
        failure_class="",
        metadata={
            "service": row.service,
            "insurance": row.insurance,
            "severity": row.severity,
            "marker": row.marker,
            "top_hospital": row.top_hospital,
            "top_price_rwf": row.top_price_rwf,
            "score": row.score,
            "label": row.label,
            "mode": mode,
        },
        steps=steps,
    )
    case.functional_pass = _functional_pass(case)
    case.failure_class = classify_failure(case)
    return case


def aggregate_report(model_label: str, tier: str, cases: list[EvalCaseResult]) -> EvaluationReport:
    n = len(cases)
    ins = [case.insurance_correct for case in cases if case.insurance_correct is not None]
    search = [case.search_arg_correct for case in cases if case.search_arg_correct is not None]
    arg_scores = [score for score in ins + search if score is not None]

    step_accuracies: list[float] = []
    for step_idx in range(4):
        correct = sum(1 for case in cases if len(case.steps) > step_idx and case.steps[step_idx].correct)
        step_accuracies.append(correct / max(n, 1))

    return EvaluationReport(
        model_label=model_label,
        tier=tier,
        num_cases=n,
        tool_order_accuracy=sum(case.tool_order_correct for case in cases) / max(n, 1),
        pipeline_accuracy=sum(case.pipeline_correct for case in cases) / max(n, 1),
        first_tool_accuracy=sum(case.predicted_tools[:1] == case.expected_tools[:1] for case in cases) / max(n, 1),
        rank_tool_rate=sum("rankHospitalsByPriorityAndCost" in case.predicted_tools for case in cases) / max(n, 1),
        insurance_argument_accuracy=(sum(ins) / max(len(ins), 1)) if ins else 0.0,
        mean_completion_rate=sum(case.completion_rate for case in cases) / max(n, 1),
        functional_pass_rate=sum(case.functional_pass for case in cases) / max(n, 1),
        argument_accuracy=(sum(arg_scores) / max(len(arg_scores), 1)) if arg_scores else 0.0,
        extra_tool_rate=sum(any(step.extra_calls > 0 for step in case.steps) for case in cases) / max(n, 1),
        early_stop_rate=sum(case.completion_rate < 1.0 and not case.functional_pass for case in cases) / max(n, 1),
        rank_skip_rate=sum(_reached_search(case.predicted_tools) and "rankHospitalsByPriorityAndCost" not in case.predicted_tools for case in cases) / max(n, 1),
        step_accuracies=step_accuracies,
        per_case=cases,
    )


def run_simulation(rows: list[EvalRow], *, seed: int, tier: str = "standard") -> dict[str, EvaluationReport]:
    baseline_cases = [simulate_case(row, profile="baseline", index=i, seed=seed) for i, row in enumerate(rows)]
    finetuned_cases = [simulate_case(row, profile="finetuned", index=i, seed=seed + 17) for i, row in enumerate(rows)]
    return {
        "baseline": aggregate_report("simulated_baseline", tier, baseline_cases),
        "finetuned": aggregate_report("simulated_finetuned", tier, finetuned_cases),
    }


def row_to_category(row: EvalRow) -> str:
    label = row.label.lower()
    if "correct" in label:
        return "correct"
    if "tool" in label:
        return "tool-policy"
    return row.service or "other"


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + "\n")


def format_markdown_table(rows: list[dict[str, Any]], headers: list[str]) -> str:
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(str(row.get(header, "")) for header in headers) + " |")
    return "\n".join(lines)


def format_comparison_markdown(report: EvaluationReport, baseline: EvaluationReport) -> str:
    rows = report.comparison_table(baseline)
    return format_markdown_table(rows, ["metric", "baseline", "finetuned", "absolute_gain", "relative_gain_pct"])


def build_trace(case: EvalCaseResult, *, title: str) -> str:
    lines = [f"### {title}", ""]
    lines.append(f"Query: {case.query}")
    lines.append(f"Expected pipeline: {case.expected_pipeline}")
    lines.append(f"Predicted pipeline: {case.predicted_pipeline}")
    lines.append("")
    lines.append("| Step | Expected tool | Predicted tool | Status |")
    lines.append("| --- | --- | --- | --- |")
    for step in case.steps:
        status = "pass" if step.correct else "fail"
        lines.append(f"| {step.index} | {step.expected_tool} | {step.predicted_tool or ''} | {status} |")
    final_line = case.predicted_tools[-1] if case.predicted_tools else "none"
    lines.extend(
        [
            "",
            f"Final tool reached: {final_line}",
            f"Failure class: {case.failure_class}",
            f"Functional pass: {'yes' if case.functional_pass else 'no'}",
        ]
    )
    return "\n".join(lines)


def build_summary_paragraph(report: EvaluationReport, baseline: EvaluationReport | None = None) -> str:
    if baseline is None:
        return (
            f"{report.model_label} ({report.tier}) simulated eval: FPR {report.functional_pass_rate:.2%}, "
            f"PSA {report.pipeline_accuracy:.2%}, TOA {report.tool_order_accuracy:.2%}, "
            f"rank skip {report.rank_skip_rate:.2%}."
        )
    gain = report.functional_pass_rate - baseline.functional_pass_rate
    return (
        f"{report.model_label} ({report.tier}) simulated eval improved FPR from {baseline.functional_pass_rate:.2%} "
        f"to {report.functional_pass_rate:.2%} (+{gain:.2%}), with PSA at {report.pipeline_accuracy:.2%} and "
        f"rank skip {report.rank_skip_rate:.2%}."
    )


def save_eval_artifacts(report: EvaluationReport, out_dir: Path, baseline: EvaluationReport | None = None) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    prefix = f"{report.model_label}_{report.tier}"

    (out_dir / f"{prefix}_summary.json").write_text(json.dumps(report.summary_dict(), indent=2), encoding="utf-8")
    write_jsonl(out_dir / f"{prefix}_per_case.jsonl", [asdict(case) for case in report.per_case])

    failures = [case for case in report.per_case if case.failure_class != "pass"]
    write_jsonl(out_dir / f"{prefix}_failures.jsonl", [asdict(case) for case in failures])

    failure_rows = [
        {
            "query": case.query,
            "failure_class": case.failure_class,
            "expected_pipeline": case.expected_pipeline,
            "predicted_pipeline": case.predicted_pipeline,
            "predicted_tools": ", ".join(case.predicted_tools),
        }
        for case in failures
    ]
    write_csv(
        out_dir / f"{prefix}_failures.csv",
        failure_rows,
        ["query", "failure_class", "expected_pipeline", "predicted_pipeline", "predicted_tools"],
    )

    category_rows: dict[str, dict[str, Any]] = {}
    for case in report.per_case:
        key = row_to_category(
            EvalRow(
                query=case.query,
                tools_json="[]",
                expected_pipeline=case.expected_pipeline,
                expected_tool_calls_json="[]",
                service=str(case.metadata.get("service", "other")),
                insurance=str(case.metadata.get("insurance", "")),
                severity=str(case.metadata.get("severity", "")),
                marker=str(case.metadata.get("marker", "")),
                top_hospital=str(case.metadata.get("top_hospital", "")),
                top_price_rwf=str(case.metadata.get("top_price_rwf", "")),
                score=str(case.metadata.get("score", "")),
                label=str(case.metadata.get("label", "")),
            )
        )
        bucket = category_rows.setdefault(
            key,
            {"category": key, "cases": 0, "functional_passes": 0, "pipeline_correct": 0, "tool_order_correct": 0},
        )
        bucket["cases"] += 1
        bucket["functional_passes"] += int(case.functional_pass)
        bucket["pipeline_correct"] += int(case.pipeline_correct)
        bucket["tool_order_correct"] += int(case.tool_order_correct)

    category_csv_rows = [
        {
            "category": row["category"],
            "cases": row["cases"],
            "functional_pass_rate": round(row["functional_passes"] / max(row["cases"], 1), 4),
            "pipeline_accuracy": round(row["pipeline_correct"] / max(row["cases"], 1), 4),
            "tool_order_accuracy": round(row["tool_order_correct"] / max(row["cases"], 1), 4),
        }
        for row in sorted(category_rows.values(), key=lambda item: item["category"])
    ]
    write_csv(
        out_dir / f"{prefix}_by_category.csv",
        category_csv_rows,
        ["category", "cases", "functional_pass_rate", "pipeline_accuracy", "tool_order_accuracy"],
    )

    (out_dir / f"{prefix}_summary.md").write_text(build_summary_paragraph(report, baseline), encoding="utf-8")


def save_comparison_artifacts(out_dir: Path, baseline: EvaluationReport, finetuned: EvaluationReport) -> None:
    comparison_rows = finetuned.comparison_table(baseline)
    write_csv(
        out_dir / "comparison_table.csv",
        comparison_rows,
        ["metric", "baseline", "finetuned", "absolute_gain", "relative_gain_pct"],
    )
    (out_dir / "comparison_table.md").write_text(
        format_comparison_markdown(finetuned, baseline),
        encoding="utf-8",
    )


def save_traces(out_dir: Path, report: EvaluationReport, count: int) -> None:
    traces = [build_trace(case, title=f"Trace {idx + 1}: {case.metadata.get('label', 'eval')}") for idx, case in enumerate(report.per_case[:count])]
    (out_dir / "inference_traces.md").write_text("\n\n---\n\n".join(traces), encoding="utf-8")


def save_chart(out_dir: Path, baseline: EvaluationReport, finetuned: EvaluationReport) -> None:
    try:
        import matplotlib.pyplot as plt
    except Exception:
        return

    labels = [label for label, _ in METRIC_LABELS if label in {"Tool Order Accuracy (TOA)", "Pipeline Selection Accuracy (PSA)", "Functional Pass Rate (FPR)", "Rank Skip Rate"}]
    keys = [key for label, key in METRIC_LABELS if label in {"Tool Order Accuracy (TOA)", "Pipeline Selection Accuracy (PSA)", "Functional Pass Rate (FPR)", "Rank Skip Rate"}]
    baseline_values = [getattr(baseline, key) for key in keys]
    finetuned_values = [getattr(finetuned, key) for key in keys]

    x = range(len(labels))
    width = 0.35
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.bar([i - width / 2 for i in x], baseline_values, width, label="baseline")
    ax.bar([i + width / 2 for i in x], finetuned_values, width, label="finetuned")
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels, rotation=20, ha="right")
    ax.set_ylim(0, 1)
    ax.legend()
    ax.set_title("Simulated eval comparison")
    fig.tight_layout()
    fig.savefig(out_dir / "comparison_metrics.png", dpi=160)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(range(1, 5), baseline.step_accuracies, marker="o", label="baseline")
    ax.plot(range(1, 5), finetuned.step_accuracies, marker="o", label="finetuned")
    ax.set_xticks([1, 2, 3, 4])
    ax.set_xlabel("Step")
    ax.set_ylabel("Accuracy")
    ax.set_ylim(0, 1)
    ax.legend()
    ax.set_title("Simulated step-wise accuracy")
    fig.tight_layout()
    fig.savefig(out_dir / "step_accuracies.png", dpi=160)
    plt.close(fig)


def build_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate mock eval artifacts for diagram drafting.")
    parser.add_argument("--eval-path", type=Path, default=DEFAULT_EVAL_PATH, help="Path to ranga_eval_20.csv")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR, help="Directory for generated artifacts")
    parser.add_argument("--limit", type=int, default=20, help="How many eval rows to simulate")
    parser.add_argument("--seed", type=int, default=42, help="Deterministic seed for the mock predictions")
    parser.add_argument("--tier", type=str, default="standard", help="Tier label to embed in output filenames")
    parser.add_argument("--trace-count", type=int, default=3, help="How many inference traces to export")
    return parser.parse_args()


def main() -> None:
    args = build_args()
    rows = load_eval_rows(args.eval_path, limit=args.limit)
    if not rows:
        raise SystemExit(f"No eval rows loaded from {args.eval_path}")

    reports = run_simulation(rows, seed=args.seed, tier=args.tier)
    baseline = reports["baseline"]
    finetuned = reports["finetuned"]

    args.output_dir.mkdir(parents=True, exist_ok=True)
    save_eval_artifacts(baseline, args.output_dir, baseline=None)
    save_eval_artifacts(finetuned, args.output_dir, baseline=baseline)
    save_comparison_artifacts(args.output_dir, baseline, finetuned)
    save_traces(args.output_dir, finetuned, args.trace_count)
    save_chart(args.output_dir, baseline, finetuned)

    print(format_comparison_markdown(finetuned, baseline))
    print()
    print(build_summary_paragraph(finetuned, baseline))
    print()
    print(f"Wrote artifacts to {args.output_dir}")


if __name__ == "__main__":
    main()