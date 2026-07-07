# Ranga Model Training (Google Colab)

All training logic lives **inside the notebooks** — no separate Python package to install.

## Notebooks

| Notebook | Model | Purpose |
|---|---|---|
| [`notebooks/ranga_functiongemma_finetune.ipynb`](notebooks/ranga_functiongemma_finetune.ipynb) | `google/functiongemma-270m-it` | Research baseline (tool-policy metrics) |
| [`notebooks/ranga_gemma4_e2b_production.ipynb`](notebooks/ranga_gemma4_e2b_production.ipynb) | `google/gemma-4-E2B-it` | Production Android → `.litertlm` |

## Google Drive layout

```
My Drive/capstone/
├── training/
│   └── notebooks/          ← open these in Colab
└── dataset/
    └── ranga_output/       ← ranga_sft_500.csv, ranga_eval_20.csv, ranga_tools.json
```

## How to run

1. Right-click notebook in Drive → **Open with → Google Colaboratory**
2. **Runtime → Change runtime type → GPU**
3. Colab secret **`HF_TOKEN`** (Hugging Face token with Gemma license)
4. Run cells in order:
   - **Install** → **Runtime → Restart session**
   - **Ranga helpers** (all utility code)
   - **Colab setup** (mount Drive, load data)
   - Training / eval cells

Results save to `My Drive/capstone/training/results/reports/` on Drive.

## Evaluation tiers

Each notebook runs a **three-tier** functional eval suite (closed-loop, step-wise tool calling):

| Tier | Cases | When to run |
|---|---|---|
| **Smoke** | 7 (5 held-out + 2 real-world) | Right after loading the model (~30s) |
| **Standard** | 20 (`ranga_eval_20.csv`) | Baseline + post-train benchmark |
| **Real-world** | 15 embedded scenarios | Post-train; mirrors Flutter app phrasing |

Real-world scenarios cover colloquial student queries, insurance synonyms (Mutuelle/CBHI, RAMA/RSSB), nearby vs condition routing, and anti-patterns from DPO training (e.g. skipping the rank step).

## Metric glossary

| Metric | Meaning |
|---|---|
| **TOA** | Tool Order Accuracy — full 4-step sequence correct |
| **PSA** | Pipeline Selection Accuracy — nearby vs condition branch |
| **FTA** | First Tool Accuracy — starts with `getCurrentLocation` |
| **RTIR** | Rank Tool Invocation Rate — called `rankHospitalsByPriorityAndCost` |
| **IAA** | Insurance Argument Accuracy — correct scheme in step 2 |
| **MCR** | Mean Completion Rate — fraction of expected steps completed |
| **FPR** | Functional Pass Rate — TOA + PSA + rank reached (headline score) |
| **Rank skip rate** | Reached search but never ranked (DPO anti-pattern) |

Step-wise accuracy (steps 1–4) shows where the model fails in the pipeline.

## Reading eval output

After post-train eval, artifacts are written per tier under `training/results/reports/`:

- `{model}_finetuned_{tier}_summary.json` — aggregate metrics
- `{model}_finetuned_{tier}_per_case.jsonl` — per-query results + failure class
- `{model}_finetuned_{tier}_by_category.csv` — breakdown by scheme, pipeline, service
- `{model}_finetuned_{tier}_failures.csv` — failed cases only (for capstone appendix)
- `{model}_finetuned_{tier}_summary.md` — paste-ready paragraph for your report
- `{model}_metrics.png` / `{model}_steps.png` — baseline vs finetuned charts

**Failure classes:** `wrong_first_tool`, `wrong_pipeline`, `wrong_insurance_arg`, `stopped_early`, `skipped_rank`, `no_tool_call`, `hallucinated_tool`

For diagram drafting before a real run, use [`simulate_eval_outputs.py`](simulate_eval_outputs.py) to generate mock comparison tables, per-case traces, and chart files from `dataset/ranga_output/ranga_eval_20.csv`.

## Export gate (E2B notebook only)

Before `.litertlm` export, the notebook checks:

- Standard FPR ≥ 70%
- PSA relative gain ≥ 15% vs baseline
- Real-world FPR ≥ 80%
- Rank skip rate ≤ 10%

Prints **GO** or **NO-GO**. Export runs only on GO.

## References

- [Fine-tuning with FunctionGemma](https://ai.google.dev/gemma/docs/functiongemma/finetuning-with-functiongemma)
- [Gemma 4 LiteRT-LM deployment](https://developers.google.com/edge/litert-lm/models/gemma-4)
- Dataset generator (`dataset/ranga_dataset_gen.ipynb`) — uses [Qwen3.6-27B-MTP-GGUF](https://huggingface.co/unsloth/Qwen3.6-27B-MTP-GGUF) + [MT Samples](https://huggingface.co/datasets/harishnair04/mtsamples) seeds
- Flutter app: `app/lib/services/gemma_service.dart`
