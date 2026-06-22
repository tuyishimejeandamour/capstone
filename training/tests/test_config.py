from __future__ import annotations

from pathlib import Path

from ranga_train.config import TrainConfig


def test_default_paths_resolve():
    config = TrainConfig(dataset_dir=Path("../dataset/ranga_output"))
    assert config.sft_file == "ranga_sft_500.jsonl"
    assert config.eval_file == "ranga_eval_50.jsonl"
    assert str(config.sft_path).endswith("ranga_sft_500.jsonl")


def test_training_defaults_are_reproducible():
    config = TrainConfig()
    assert config.seed == 42
    assert config.max_length == 2048
    assert config.num_train_epochs == 6
