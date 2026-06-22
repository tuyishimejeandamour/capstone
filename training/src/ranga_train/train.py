"""Supervised fine-tuning entry point for Ranga FunctionGemma."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, set_seed
from trl import SFTConfig, SFTTrainer

from ranga_train.config import TrainConfig
from ranga_train.data import prepare_eval_records, prepare_sft_dataset


def _resolve_hf_token(token: str | None) -> str | None:
    if token:
        return token
    try:
        from huggingface_hub import HfFolder

        return HfFolder.get_token()
    except Exception:
        return None


def build_model_and_tokenizer(config: TrainConfig, token: str | None = None):
    hf_token = _resolve_hf_token(token)
    model = AutoModelForCausalLM.from_pretrained(
        config.base_model,
        dtype="auto",
        device_map="auto",
        attn_implementation="eager",
        token=hf_token,
    )
    tokenizer = AutoTokenizer.from_pretrained(config.base_model, token=hf_token)
    return model, tokenizer


def build_trainer(
    config: TrainConfig,
    model,
    tokenizer,
    datasets: dict[str, Any],
) -> SFTTrainer:
    torch_dtype = model.dtype
    training_args = SFTConfig(
        output_dir=str(config.checkpoint_dir),
        max_length=config.max_length,
        packing=False,
        num_train_epochs=config.num_train_epochs,
        per_device_train_batch_size=config.per_device_train_batch_size,
        per_device_eval_batch_size=config.per_device_eval_batch_size,
        gradient_accumulation_steps=config.gradient_accumulation_steps,
        gradient_checkpointing=True,
        optim="adamw_torch_fused",
        logging_steps=10,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="eval_loss",
        greater_is_better=False,
        learning_rate=config.learning_rate,
        warmup_ratio=config.warmup_ratio,
        weight_decay=config.weight_decay,
        lr_scheduler_type="cosine",
        fp16=torch_dtype == torch.float16,
        bf16=torch_dtype == torch.bfloat16,
        push_to_hub=config.push_to_hub,
        report_to=["tensorboard"],
        seed=config.seed,
    )

    return SFTTrainer(
        model=model,
        args=training_args,
        train_dataset=datasets["train"],
        eval_dataset=datasets["validation"],
        processing_class=tokenizer,
    )


def save_training_curves(trainer: SFTTrainer, output_path: Path) -> dict[str, list[float]]:
    log_history = trainer.state.log_history
    curves = {
        "train_loss": [entry["loss"] for entry in log_history if "loss" in entry],
        "eval_loss": [entry["eval_loss"] for entry in log_history if "eval_loss" in entry],
        "epoch_train": [entry["epoch"] for entry in log_history if "loss" in entry],
        "epoch_eval": [entry["epoch"] for entry in log_history if "eval_loss" in entry],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(curves, handle, indent=2)
    return curves


def run_training(config: TrainConfig | None = None) -> tuple[SFTTrainer, dict[str, Any]]:
    config = config or TrainConfig()
    config.checkpoint_dir.mkdir(parents=True, exist_ok=True)
    config.reports_dir.mkdir(parents=True, exist_ok=True)

    set_seed(config.seed)
    datasets = prepare_sft_dataset(
        config.sft_path,
        train_split=config.train_split,
        seed=config.seed,
        max_hospitals=config.max_hospitals_in_tool_payload,
    )
    eval_records = prepare_eval_records(config.eval_path, config.tools_path)

    model, tokenizer = build_model_and_tokenizer(config)
    trainer = build_trainer(config, model, tokenizer, datasets)
    trainer.train()
    trainer.save_model()

    curves_path = config.reports_dir / "training_curves.json"
    curves = save_training_curves(trainer, curves_path)

    metadata = {
        "base_model": config.base_model,
        "train_records": len(datasets["train"]),
        "validation_records": len(datasets["validation"]),
        "held_out_eval_records": len(eval_records),
        "checkpoint_dir": str(config.checkpoint_dir),
        "curves_path": str(curves_path),
    }
    with open(config.reports_dir / "run_metadata.json", "w", encoding="utf-8") as handle:
        json.dump(metadata, handle, indent=2)

    return trainer, metadata


if __name__ == "__main__":
    run_training()
