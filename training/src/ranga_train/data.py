"""Dataset loading and conversion for FunctionGemma SFT."""

from __future__ import annotations

import json
import random
from copy import deepcopy
from pathlib import Path
from typing import Any

from datasets import Dataset

RANGA_TOOL_ORDER = [
    "getCurrentLocation",
    "getInsuranceCoverageBlock",
    "getNearbyHospitals",
    "searchHospitalsByCondition",
    "rankHospitalsByPriorityAndCost",
]

HOSPITAL_KEEP_FIELDS = (
    "id",
    "name",
    "lat",
    "lng",
    "averageCostRwf",
    "emergencyUnit",
    "acceptedInsurance",
)


def load_jsonl(path: Path | str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records


def load_tools(path: Path | str) -> list[dict[str, Any]]:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def map_system_to_developer(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """FunctionGemma expects a developer turn instead of system."""
    mapped: list[dict[str, Any]] = []
    for message in messages:
        item = deepcopy(message)
        if item.get("role") == "system":
            item["role"] = "developer"
        mapped.append(item)
    return mapped


def _compact_hospital(hospital: dict[str, Any]) -> dict[str, Any]:
    return {key: hospital[key] for key in HOSPITAL_KEEP_FIELDS if key in hospital}


def truncate_tool_payload(
    tool_name: str,
    content: str,
    *,
    max_hospitals: int = 2,
) -> str:
    """Shrink large hospital lists so trajectories fit GPU memory."""
    if not content:
        return content

    try:
        payload = json.loads(content)
    except json.JSONDecodeError:
        return content

    if tool_name in {"getNearbyHospitals", "searchHospitalsByCondition"} and "results" in payload:
        compact_results = []
        for entry in payload["results"][:max_hospitals]:
            compact = deepcopy(entry)
            if "hospital" in compact:
                compact["hospital"] = _compact_hospital(compact["hospital"])
            compact_results.append(compact)
        payload["results"] = compact_results
        payload["truncated"] = True

    if tool_name == "rankHospitalsByPriorityAndCost" and "rankedResults" in payload:
        payload["rankedResults"] = payload["rankedResults"][:max_hospitals]
        payload["truncated"] = True

    return json.dumps(payload, ensure_ascii=False)


def compact_messages(
    messages: list[dict[str, Any]],
    *,
    max_hospitals: int = 2,
) -> list[dict[str, Any]]:
    compacted: list[dict[str, Any]] = []
    for message in messages:
        item = deepcopy(message)
        if item.get("role") == "tool" and item.get("content"):
            item["content"] = truncate_tool_payload(
                item.get("name", ""),
                item["content"],
                max_hospitals=max_hospitals,
            )
        compacted.append(item)
    return compacted


def extract_tool_sequence(messages: list[dict[str, Any]]) -> list[str]:
    sequence: list[str] = []
    for message in messages:
        for call in message.get("tool_calls") or []:
            sequence.append(call["function"]["name"])
    return sequence


def infer_pipeline(tool_sequence: list[str]) -> str:
    if "searchHospitalsByCondition" in tool_sequence:
        return "condition"
    if "getNearbyHospitals" in tool_sequence:
        return "nearby"
    return "unknown"


def to_sft_record(
    record: dict[str, Any],
    *,
    max_hospitals: int = 2,
    role_style: str = "functiongemma",
) -> dict[str, Any]:
    messages = record["messages"]
    if role_style == "functiongemma":
        messages = map_system_to_developer(messages)
    messages = compact_messages(messages, max_hospitals=max_hospitals)
    return {"messages": messages, "tools": record["tools"]}


def prepare_sft_dataset(
    sft_path: Path | str,
    *,
    train_split: float = 0.9,
    seed: int = 42,
    max_hospitals: int = 2,
    role_style: str = "functiongemma",
) -> dict[str, Dataset]:
    """Load Ranga SFT JSONL and split into train/validation HF datasets."""
    records = load_jsonl(sft_path)
    converted = [
        to_sft_record(record, max_hospitals=max_hospitals, role_style=role_style)
        for record in records
    ]
    dataset = Dataset.from_list(converted)
    split = dataset.train_test_split(
        test_size=round(1 - train_split, 2),
        seed=seed,
        shuffle=True,
    )
    return {"train": split["train"], "validation": split["test"]}


def prepare_eval_records(
    eval_path: Path | str,
    tools_path: Path | str,
) -> list[dict[str, Any]]:
    """Load held-out eval queries with expected tool-call sequences."""
    tools = load_tools(tools_path)
    records = load_jsonl(eval_path)
    for record in records:
        record.setdefault("tools", tools)
    return records


def estimate_char_length(record: dict[str, Any]) -> int:
    return sum(len(str(message.get("content") or "")) for message in record["messages"])


def summarize_dataset(records: list[dict[str, Any]]) -> dict[str, Any]:
    pipelines = [infer_pipeline(extract_tool_sequence(record["messages"])) for record in records]
    lengths = [estimate_char_length(record) for record in records]
    return {
        "count": len(records),
        "nearby": pipelines.count("nearby"),
        "condition": pipelines.count("condition"),
        "avg_chars": round(sum(lengths) / max(len(lengths), 1)),
        "max_chars": max(lengths) if lengths else 0,
    }


def shuffle_records(records: list[dict[str, Any]], seed: int = 42) -> list[dict[str, Any]]:
    copied = records.copy()
    random.Random(seed).shuffle(copied)
    return copied
