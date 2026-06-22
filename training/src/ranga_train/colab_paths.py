"""Resolve repository paths when running in Colab or locally."""

from __future__ import annotations

from pathlib import Path

# Standard Google Drive layout for this project:
#   My Drive/capstone/training/
#   My Drive/capstone/dataset/ranga_output/
DRIVE_CAPSTONE_ROOT = Path("/content/drive/MyDrive/capstone")


def _find_dataset_dir(dataset_parent: Path) -> Path:
    """Resolve dataset output folder (supports ranga_output/ or flat dataset/)."""
    candidates = [
        dataset_parent / "ranga_output",
        dataset_parent,
    ]
    for candidate in candidates:
        if (candidate / "ranga_sft_500.jsonl").exists():
            return candidate.resolve()
    return (dataset_parent / "ranga_output").resolve()


def resolve_project_paths(
    start: Path | None = None,
    *,
    capstone_root: Path | str | None = None,
) -> dict[str, Path]:
    """Find training/, dataset/, and capstone root."""
    if capstone_root is not None:
        root = Path(capstone_root).resolve()
        training_dir = root / "training"
        dataset_dir = _find_dataset_dir(root / "dataset")
        return {
            "repo_root": root,
            "training_dir": training_dir.resolve(),
            "dataset_dir": dataset_dir,
        }

    if DRIVE_CAPSTONE_ROOT.exists() and (DRIVE_CAPSTONE_ROOT / "training").exists():
        return resolve_project_paths(capstone_root=DRIVE_CAPSTONE_ROOT)

    cwd = (start or Path.cwd()).resolve()
    search_roots = [cwd, cwd.parent, cwd.parent.parent, cwd.parent.parent.parent]

    for root in search_roots:
        training_dir = root / "training"
        dataset_dir = _find_dataset_dir(root / "dataset")
        if (training_dir / "src/ranga_train").exists() and (
            dataset_dir / "ranga_sft_500.jsonl"
        ).exists():
            return {
                "repo_root": root.resolve(),
                "training_dir": training_dir.resolve(),
                "dataset_dir": dataset_dir,
            }

        if root.name == "training" and (root / "src/ranga_train").exists():
            repo_root = root.parent
            dataset_dir = _find_dataset_dir(repo_root / "dataset")
            if (dataset_dir / "ranga_sft_500.jsonl").exists():
                return {
                    "repo_root": repo_root.resolve(),
                    "training_dir": root.resolve(),
                    "dataset_dir": dataset_dir,
                }

    repo_root = cwd.parent.parent if cwd.name == "notebooks" else cwd.parent
    return {
        "repo_root": repo_root.resolve(),
        "training_dir": (repo_root / "training").resolve(),
        "dataset_dir": _find_dataset_dir(repo_root / "dataset"),
    }


def require_dataset(paths: dict[str, Path]) -> None:
    required = [
        paths["dataset_dir"] / "ranga_sft_500.jsonl",
        paths["dataset_dir"] / "ranga_eval_50.jsonl",
        paths["dataset_dir"] / "ranga_tools.json",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError(
            "Missing Ranga dataset files. Expected Google Drive layout:\n"
            "  /content/drive/MyDrive/capstone/dataset/ranga_output/\n"
            "    - ranga_sft_500.jsonl\n"
            "    - ranga_eval_50.jsonl\n"
            "    - ranga_tools.json\n"
            "Missing:\n" + "\n".join(f"  - {path}" for path in missing)
        )
