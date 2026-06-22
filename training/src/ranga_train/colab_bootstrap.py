"""Shared Colab bootstrap snippet (imported by notebooks or copied inline)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from ranga_train.colab_paths import require_dataset, resolve_project_paths
from ranga_train.data import load_jsonl, prepare_eval_records, summarize_dataset
from ranga_train.evaluate import evaluate_model
from ranga_train.inference import make_generate_fn

DEFAULT_CAPSTONE_ROOT = "/content/drive/MyDrive/capstone"


def bootstrap_colab(
    *,
    mount_drive: bool = True,
    capstone_root: str = DEFAULT_CAPSTONE_ROOT,
) -> dict[str, Path]:
    """Mount Drive, wire imports, validate dataset, return path dict."""
    if mount_drive:
        from google.colab import drive

        drive.mount("/content/drive")

    capstone = Path(capstone_root)
    training_dir = capstone / "training"
    sys.path.insert(0, str(training_dir / "src"))

    paths = resolve_project_paths(capstone_root=capstone)
    require_dataset(paths)

    reports_dir = paths["training_dir"] / "results" / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    os.chdir(paths["training_dir"])

    return {
        **paths,
        "reports_dir": reports_dir,
        "sft_records": load_jsonl(paths["dataset_dir"] / "ranga_sft_500.jsonl"),
        "eval_records": prepare_eval_records(
            paths["dataset_dir"] / "ranga_eval_50.jsonl",
            paths["dataset_dir"] / "ranga_tools.json",
        ),
    }


def print_bootstrap_summary(paths: dict) -> None:
    print("Capstone root:", paths["repo_root"])
    print("Training dir:", paths["training_dir"])
    print("Dataset dir:", paths["dataset_dir"])
    print("Dataset summary:", summarize_dataset(paths["sft_records"]))
    print("Held-out eval queries:", len(paths["eval_records"]))
