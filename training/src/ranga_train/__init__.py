"""Ranga FunctionGemma fine-tuning and evaluation toolkit."""

from ranga_train.colab_paths import require_dataset, resolve_project_paths
from ranga_train.config import TrainConfig
from ranga_train.data import load_jsonl, prepare_sft_dataset
from ranga_train.evaluate import EvaluationReport, evaluate_model
from ranga_train.gemma4 import Gemma4ProductionConfig, prepare_gemma4_sft_dataset

__all__ = [
    "TrainConfig",
    "Gemma4ProductionConfig",
    "load_jsonl",
    "prepare_sft_dataset",
    "prepare_gemma4_sft_dataset",
    "EvaluationReport",
    "evaluate_model",
    "resolve_project_paths",
    "require_dataset",
]
