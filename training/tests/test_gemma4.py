from __future__ import annotations

from ranga_train.data import load_jsonl, to_sft_record
from ranga_train.gemma4 import (
    BASE_MODEL_ID,
    FLUTTER_MODEL_FILENAME,
    prepare_gemma4_sft_dataset,
    to_gemma4_sft_record,
)
from tests.conftest import FIXTURES


def test_gemma4_record_keeps_system_role():
    record = load_jsonl(FIXTURES / "sample_sft.jsonl")[0]
    gemma4 = to_gemma4_sft_record(record, max_hospitals=1)
    functiongemma = to_sft_record(record, max_hospitals=1)
    assert gemma4["messages"][0]["role"] == "system"
    assert functiongemma["messages"][0]["role"] == "developer"


def test_prepare_gemma4_sft_dataset():
    datasets = prepare_gemma4_sft_dataset(
        FIXTURES / "sample_sft.jsonl",
        train_split=0.5,
        seed=42,
        max_hospitals=1,
    )
    assert len(datasets["train"]) == 1
    assert datasets["train"][0]["messages"][0]["role"] == "system"


def test_mobile_constants():
    assert BASE_MODEL_ID == "google/gemma-4-E2B-it"
    assert FLUTTER_MODEL_FILENAME == "gemma-model.litertlm"
