from __future__ import annotations

import json

from ranga_train.data import (
    compact_messages,
    extract_tool_sequence,
    infer_pipeline,
    load_jsonl,
    map_system_to_developer,
    prepare_eval_records,
    prepare_sft_dataset,
    summarize_dataset,
    to_sft_record,
    truncate_tool_payload,
)
from tests.conftest import FIXTURES


def test_load_jsonl_fixture_count():
    records = load_jsonl(FIXTURES / "sample_sft.jsonl")
    assert len(records) == 2
    assert "messages" in records[0]
    assert "tools" in records[0]


def test_map_system_to_developer():
    messages = [
        {"role": "system", "content": "policy"},
        {"role": "user", "content": "hello"},
    ]
    mapped = map_system_to_developer(messages)
    assert mapped[0]["role"] == "developer"
    assert mapped[1]["role"] == "user"


def test_truncate_hospital_payload():
    payload = json.dumps(
        {
            "results": [
                {"hospital": {"id": "1", "name": "A", "lat": 1, "lng": 2, "extra": "x"}, "distanceKm": 1.0},
                {"hospital": {"id": "2", "name": "B", "lat": 1, "lng": 2, "extra": "y"}, "distanceKm": 2.0},
            ]
        }
    )
    truncated = truncate_tool_payload("getNearbyHospitals", payload, max_hospitals=1)
    data = json.loads(truncated)
    assert len(data["results"]) == 1
    assert "extra" not in data["results"][0]["hospital"]
    assert data["truncated"] is True


def test_extract_tool_sequence_and_pipeline():
    record = load_jsonl(FIXTURES / "sample_sft.jsonl")[0]
    sequence = extract_tool_sequence(record["messages"])
    assert sequence[0] == "getCurrentLocation"
    assert sequence[-1] == "rankHospitalsByPriorityAndCost"
    assert infer_pipeline(sequence) in {"nearby", "condition"}


def test_to_sft_record_reduces_size():
    record = load_jsonl(FIXTURES / "sample_sft.jsonl")[0]
    raw_len = sum(len(str(m.get("content") or "")) for m in record["messages"])
    converted = to_sft_record(record, max_hospitals=1)
    new_len = sum(len(str(m.get("content") or "")) for m in converted["messages"])
    assert new_len <= raw_len
    assert converted["messages"][0]["role"] == "developer"


def test_prepare_sft_dataset_split():
    datasets = prepare_sft_dataset(
        FIXTURES / "sample_sft.jsonl",
        train_split=0.5,
        seed=42,
        max_hospitals=1,
    )
    assert len(datasets["train"]) == 1
    assert len(datasets["validation"]) == 1


def test_prepare_eval_records():
    records = prepare_eval_records(
        FIXTURES / "sample_eval.jsonl",
        FIXTURES / "ranga_tools.json",
    )
    assert len(records) == 3
    assert records[0]["expected_pipeline"] in {"nearby", "condition"}
    assert len(records[0]["expected_tool_calls"]) == 4


def test_summarize_dataset():
    records = load_jsonl(FIXTURES / "sample_sft.jsonl")
    summary = summarize_dataset(records)
    assert summary["count"] == 2
    assert summary["nearby"] + summary["condition"] == 2


def test_compact_messages_preserves_roles():
    record = load_jsonl(FIXTURES / "sample_sft.jsonl")[0]
    compacted = compact_messages(record["messages"], max_hospitals=1)
    assert compacted[0]["role"] == "system"
    assert len(compacted) == len(record["messages"])
