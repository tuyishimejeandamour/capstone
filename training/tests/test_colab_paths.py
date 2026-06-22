from __future__ import annotations

from pathlib import Path

from ranga_train.colab_paths import (
    DRIVE_CAPSTONE_ROOT,
    require_dataset,
    resolve_project_paths,
)


def test_resolve_from_explicit_capstone_root():
    repo = Path(__file__).resolve().parents[2]
    paths = resolve_project_paths(capstone_root=repo)
    assert paths["repo_root"] == repo.resolve()
    assert paths["training_dir"] == (repo / "training").resolve()
    assert (paths["dataset_dir"] / "ranga_sft_500.jsonl").exists()


def test_resolve_from_training_notebooks_dir():
    training = Path(__file__).resolve().parents[1]
    paths = resolve_project_paths(training / "notebooks")
    assert paths["training_dir"].name == "training"
    assert paths["dataset_dir"].name == "ranga_output"


def test_drive_capstone_constant():
    assert str(DRIVE_CAPSTONE_ROOT).endswith("MyDrive/capstone")


def test_require_dataset_with_real_repo():
    repo_paths = resolve_project_paths(Path(__file__).resolve().parents[2])
    if (repo_paths["dataset_dir"] / "ranga_sft_500.jsonl").exists():
        require_dataset(repo_paths)
