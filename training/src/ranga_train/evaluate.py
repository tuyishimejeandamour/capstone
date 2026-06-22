"""Evaluation metrics and step-wise FunctionGemma inference for Ranga."""

from __future__ import annotations

import json
import re
from dataclasses import asdict, dataclass, field
from typing import Any, Callable

from ranga_train.data import infer_pipeline

FUNCTION_CALL_PATTERN = re.compile(
    r"<start_function_call>call:(?P<name>[A-Za-z0-9_]+)\{(?P<args>.*?)\}<end_function_call>",
    re.DOTALL,
)
ESCAPE_PATTERN = re.compile(r"<escape>(.*?)<escape>", re.DOTALL)


@dataclass
class StepPrediction:
    step: int
    expected_tool: str
    predicted_tool: str | None
    raw_output: str
    correct: bool


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
    completion_rate: float
    steps: list[StepPrediction] = field(default_factory=list)


@dataclass
class EvaluationReport:
    model_label: str
    num_cases: int
    tool_order_accuracy: float
    pipeline_accuracy: float
    first_tool_accuracy: float
    rank_tool_rate: float
    insurance_argument_accuracy: float
    mean_completion_rate: float
    per_case: list[EvalCaseResult] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload.pop("per_case")
        return payload

    def comparison_table(self, baseline: EvaluationReport) -> list[dict[str, Any]]:
        metrics = [
            ("Tool Order Accuracy (TOA)", "tool_order_accuracy"),
            ("Pipeline Selection Accuracy (PSA)", "pipeline_accuracy"),
            ("First Tool Accuracy (FTA)", "first_tool_accuracy"),
            ("Rank Tool Invocation Rate (RTIR)", "rank_tool_rate"),
            ("Insurance Argument Accuracy (IAA)", "insurance_argument_accuracy"),
            ("Mean Completion Rate (MCR)", "mean_completion_rate"),
        ]
        rows = []
        for label, key in metrics:
            before = getattr(baseline, key)
            after = getattr(self, key)
            delta = after - before
            rows.append(
                {
                    "metric": label,
                    "baseline": round(before, 4),
                    "finetuned": round(after, 4),
                    "absolute_gain": round(delta, 4),
                    "relative_gain_pct": round((delta / before * 100) if before else 0.0, 2),
                }
            )
        return rows


def parse_function_calls(text: str) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for match in FUNCTION_CALL_PATTERN.finditer(text):
        args_blob = match.group("args")
        arguments: dict[str, Any] = {}
        for arg_match in re.finditer(r"(\w+):<escape>(.*?)<escape>", args_blob, re.DOTALL):
            key = arg_match.group(1)
            value = arg_match.group(2)
            if key == "insurance":
                arguments[key] = value
            else:
                try:
                    arguments[key] = json.loads(value)
                except json.JSONDecodeError:
                    arguments[key] = value
        calls.append({"name": match.group("name"), "arguments": arguments})
    return calls


def first_function_call(text: str) -> dict[str, Any] | None:
    calls = parse_function_calls(text)
    return calls[0] if calls else None


def tool_names_from_output(text: str) -> list[str]:
    return [call["name"] for call in parse_function_calls(text)]


def insurance_argument_matches(expected: dict[str, Any], predicted: dict[str, Any] | None) -> bool | None:
    expected_value = expected.get("arguments", {}).get("insurance")
    if expected_value is None:
        return None
    if predicted is None:
        return False
    predicted_value = predicted.get("arguments", {}).get("insurance", "")
    return str(predicted_value).lower() == str(expected_value).lower()


def mock_tool_response(tool_name: str, arguments: dict[str, Any] | None = None) -> str:
    """Minimal deterministic tool payloads for closed-loop evaluation."""
    arguments = arguments or {}
    if tool_name == "getCurrentLocation":
        payload = {"lat": -1.9695, "lng": 30.1589}
    elif tool_name == "getInsuranceCoverageBlock":
        scheme = arguments.get("insurance", "CBHI")
        payload = {
            "providerName": scheme,
            "networkKey": scheme.lower().replace(" ", ""),
            "copayPercent": 10.0,
            "requiresReferral": scheme == "CBHI",
        }
    elif tool_name in {"getNearbyHospitals", "searchHospitalsByCondition"}:
        payload = {
            "results": [
                {
                    "hospital": {
                        "id": "node/demo",
                        "name": "Demo Hospital",
                        "lat": -1.97,
                        "lng": 30.16,
                        "averageCostRwf": 15000,
                        "emergencyUnit": True,
                    },
                    "distanceKm": 1.2,
                    "isInNetwork": True,
                }
            ]
        }
    elif tool_name == "rankHospitalsByPriorityAndCost":
        payload = {
            "rankedResults": [
                {
                    "result": {
                        "hospital": {"id": "node/demo", "name": "Demo Hospital"},
                        "distanceKm": 1.2,
                        "isInNetwork": True,
                    },
                    "score": 88.0,
                    "estimatedCopayRwf": 1500,
                }
            ]
        }
    else:
        payload = {"status": "ok"}
    return json.dumps(payload, ensure_ascii=False)


def build_step_messages(
    system_prompt: str,
    user_query: str,
    history: list[dict[str, Any]],
    *,
    prompt_role: str = "developer",
) -> list[dict[str, Any]]:
    messages: list[dict[str, Any]] = [
        {"role": prompt_role, "content": system_prompt},
        {"role": "user", "content": user_query},
    ]
    messages.extend(history)
    return messages


def evaluate_case(
    *,
    user_query: str,
    expected_tool_calls: list[dict[str, Any]],
    expected_pipeline: str,
    expected_scheme: str | None,
    system_prompt: str,
    tools: list[dict[str, Any]],
    generate_fn: Callable[..., str],
    max_new_tokens: int = 256,
    prompt_role: str = "developer",
) -> EvalCaseResult:
    history: list[dict[str, Any]] = []
    predicted_tools: list[str] = []
    steps: list[StepPrediction] = []
    insurance_correct: bool | None = None

    for index, expected in enumerate(expected_tool_calls, start=1):
        messages = build_step_messages(
            system_prompt, user_query, history, prompt_role=prompt_role
        )
        raw_output = generate_fn(messages=messages, tools=tools, max_new_tokens=max_new_tokens)
        predicted = first_function_call(raw_output)
        predicted_name = predicted["name"] if predicted else None
        expected_name = expected["name"]
        steps.append(
            StepPrediction(
                step=index,
                expected_tool=expected_name,
                predicted_tool=predicted_name,
                raw_output=raw_output,
                correct=predicted_name == expected_name,
            )
        )
        if predicted_name:
            predicted_tools.append(predicted_name)

        if expected_name == "getInsuranceCoverageBlock":
            insurance_correct = insurance_argument_matches(expected, predicted)

        if predicted_name != expected_name:
            break

        call_id = f"eval_call_{index}"
        history.extend(
            [
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [
                        {
                            "id": call_id,
                            "type": "function",
                            "function": {
                                "name": predicted_name,
                                "arguments": predicted.get("arguments", {}) if predicted else {},
                            },
                        }
                    ],
                },
                {
                    "role": "tool",
                    "tool_call_id": call_id,
                    "name": predicted_name,
                    "content": mock_tool_response(
                        predicted_name,
                        predicted.get("arguments") if predicted else {},
                    ),
                },
            ]
        )

    predicted_pipeline = infer_pipeline(predicted_tools)
    completion_rate = len(predicted_tools) / max(len(expected_tool_calls), 1)

    return EvalCaseResult(
        query=user_query,
        expected_pipeline=expected_pipeline,
        predicted_pipeline=predicted_pipeline,
        expected_tools=[item["name"] for item in expected_tool_calls],
        predicted_tools=predicted_tools,
        tool_order_correct=predicted_tools == [item["name"] for item in expected_tool_calls],
        pipeline_correct=predicted_pipeline == expected_pipeline,
        insurance_correct=insurance_correct,
        completion_rate=completion_rate,
        steps=steps,
    )


def aggregate_report(model_label: str, cases: list[EvalCaseResult]) -> EvaluationReport:
    count = len(cases)
    if count == 0:
        return EvaluationReport(
            model_label=model_label,
            num_cases=0,
            tool_order_accuracy=0.0,
            pipeline_accuracy=0.0,
            first_tool_accuracy=0.0,
            rank_tool_rate=0.0,
            insurance_argument_accuracy=0.0,
            mean_completion_rate=0.0,
            per_case=[],
        )

    insurance_scores = [case.insurance_correct for case in cases if case.insurance_correct is not None]

    return EvaluationReport(
        model_label=model_label,
        num_cases=count,
        tool_order_accuracy=sum(case.tool_order_correct for case in cases) / count,
        pipeline_accuracy=sum(case.pipeline_correct for case in cases) / count,
        first_tool_accuracy=sum(
            1 for case in cases if case.predicted_tools[:1] == case.expected_tools[:1]
        )
        / count,
        rank_tool_rate=sum(
            "rankHospitalsByPriorityAndCost" in case.predicted_tools for case in cases
        )
        / count,
        insurance_argument_accuracy=sum(1 for value in insurance_scores if value) / max(
            len(insurance_scores), 1
        ),
        mean_completion_rate=sum(case.completion_rate for case in cases) / count,
        per_case=cases,
    )


def evaluate_model(
    *,
    model_label: str,
    eval_records: list[dict[str, Any]],
    system_prompt: str,
    generate_fn: Callable[..., str],
    max_cases: int | None = None,
    prompt_role: str = "developer",
) -> EvaluationReport:
    selected = eval_records[:max_cases] if max_cases else eval_records
    cases: list[EvalCaseResult] = []
    for record in selected:
        cases.append(
            evaluate_case(
                user_query=record["query"],
                expected_tool_calls=record["expected_tool_calls"],
                expected_pipeline=record["expected_pipeline"],
                expected_scheme=record.get("expected_scheme"),
                system_prompt=system_prompt,
                tools=record["tools"],
                generate_fn=generate_fn,
                prompt_role=prompt_role,
            )
        )
    return aggregate_report(model_label, cases)
