"""Experiment configuration for Ranga FunctionGemma fine-tuning."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class TrainConfig:
    """Hyperparameters and paths for supervised fine-tuning."""

    base_model: str = "google/functiongemma-270m-it"
    dataset_dir: Path = field(default_factory=lambda: Path("../dataset/ranga_output"))
    checkpoint_dir: Path = field(default_factory=lambda: Path("results/checkpoints"))
    reports_dir: Path = field(default_factory=lambda: Path("results/reports"))

    learning_rate: float = 5e-5
    num_train_epochs: int = 6
    per_device_train_batch_size: int = 2
    per_device_eval_batch_size: int = 2
    max_length: int = 2048
    gradient_accumulation_steps: int = 4
    warmup_ratio: float = 0.05
    weight_decay: float = 0.01
    seed: int = 42

    train_split: float = 0.9
    max_hospitals_in_tool_payload: int = 2
    push_to_hub: bool = False

    sft_file: str = "ranga_sft_500.jsonl"
    eval_file: str = "ranga_eval_50.jsonl"
    tools_file: str = "ranga_tools.json"

    @property
    def sft_path(self) -> Path:
        return self.dataset_dir / self.sft_file

    @property
    def eval_path(self) -> Path:
        return self.dataset_dir / self.eval_file

    @property
    def tools_path(self) -> Path:
        return self.dataset_dir / self.tools_file
