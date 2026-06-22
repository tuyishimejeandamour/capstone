"""Gemma 4 E2B production training and LiteRT-LM mobile export helpers."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from datasets import Dataset

from ranga_train.data import compact_messages, load_jsonl, to_sft_record

# Matches app/lib/services/gemma_service.dart
BASE_MODEL_ID = "google/gemma-4-E2B-it"
LITERT_TEMPLATE_REPO = "litert-community/gemma-4-E2B-it-litert-lm"
LITERT_EXPORT_TEMPLATE = "litert-community/gemma-4-E2B-it-litert-lm"
FLUTTER_MODEL_FILENAME = "gemma-model.litertlm"
FLUTTER_MAX_CONTEXT_TOKENS = 2048
FLUTTER_MAX_GENERATION_TOKENS = 512


@dataclass
class Gemma4ProductionConfig:
    """Hyperparameters tuned for Colab L4/A100 and on-device E2B deployment."""

    base_model: str = BASE_MODEL_ID
    dataset_dir: Path = field(default_factory=lambda: Path("../dataset/ranga_output"))
    checkpoint_dir: Path = field(default_factory=lambda: Path("results/gemma4_e2b_checkpoints"))
    merged_dir: Path = field(default_factory=lambda: Path("results/gemma4_e2b_merged"))
    export_dir: Path = field(default_factory=lambda: Path("results/gemma4_e2b_litertlm"))
    reports_dir: Path = field(default_factory=lambda: Path("results/reports"))

    max_seq_length: int = 2048
    lora_r: int = 16
    lora_alpha: int = 16
    lora_dropout: float = 0.0
    learning_rate: float = 2e-4
    num_train_epochs: int = 3
    per_device_train_batch_size: int = 1
    gradient_accumulation_steps: int = 8
    warmup_ratio: float = 0.03
    seed: int = 42
    train_split: float = 0.9
    max_hospitals_in_tool_payload: int = 2

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


def to_gemma4_sft_record(
    record: dict,
    *,
    max_hospitals: int = 2,
) -> dict:
    """Keep native Gemma 4 `system` role; only compact tool payloads."""
    messages = compact_messages(record["messages"], max_hospitals=max_hospitals)
    return {"messages": messages, "tools": record["tools"]}


def prepare_gemma4_sft_dataset(
    sft_path: Path | str,
    *,
    train_split: float = 0.9,
    seed: int = 42,
    max_hospitals: int = 2,
) -> dict[str, Dataset]:
    records = load_jsonl(sft_path)
    converted = [
        to_gemma4_sft_record(record, max_hospitals=max_hospitals) for record in records
    ]
    dataset = Dataset.from_list(converted)
    split = dataset.train_test_split(
        test_size=round(1 - train_split, 2),
        seed=seed,
        shuffle=True,
    )
    return {"train": split["train"], "validation": split["test"]}


def litert_export_command(merged_model_dir: Path | str, output_dir: Path | str) -> str:
    """Shell command to produce a Flutter-compatible `.litertlm` bundle."""
    return (
        "litert-torch export_hf "
        f"--model={merged_model_dir} "
        f"--output_dir={output_dir} "
        "--externalize_embedder "
        f"--jinja_chat_template_override={LITERT_EXPORT_TEMPLATE}"
    )


def flutter_integration_notes(export_path: Path | str) -> str:
    return f"""Flutter deployment checklist (Android):

1. Upload `{Path(export_path).name}` to Hugging Face (or your CDN).
2. Update `app/lib/services/gemma_service.dart`:
   - `_modelUrl` → your hosted `.litertlm` URL
   - Local filename stays `{FLUTTER_MODEL_FILENAME}`
3. First launch downloads ~2.4 GB; app installs via `FlutterGemma.installModel(... fileType: litertlm)`.
4. Match runtime limits already in the app:
   - `maxTokens={FLUTTER_MAX_CONTEXT_TOKENS}`
   - generation cap `{FLUTTER_MAX_GENERATION_TOKENS}` tokens (thermal safeguard)
5. iOS currently uses Gemma 3 1B MediaPipe — Gemma 4 `.litertlm` is Android-only until LiteRT-LM Swift ships.

Important: merge LoRA into base weights before export. LiteRT-LM does not hot-swap LoRA on Gemma 4 published graphs.
"""
