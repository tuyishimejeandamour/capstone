# Ranga Model Training

Two Colab notebooks fine-tune the Ranga hospital-navigation assistant on the synthetic dataset in `dataset/ranga_output/`.

## Notebooks

| Notebook | Model | Purpose | Phone deployment |
|---|---|---|---|
| [`notebooks/ranga_functiongemma_finetune.ipynb`](notebooks/ranga_functiongemma_finetune.ipynb) | `google/functiongemma-270m-it` | Research baseline — quantify tool-policy learning | **No** |
| [`notebooks/ranga_gemma4_e2b_production.ipynb`](notebooks/ranga_gemma4_e2b_production.ipynb) | `google/gemma-4-E2B-it` | Production Android bundle | **Yes** → `.litertlm` |

## Mobile target (Flutter)

The Android app loads Gemma 4 E2B via LiteRT-LM:

- File: `gemma-model.litertlm` (~2.4 GB)
- Service: `app/lib/services/gemma_service.dart`
- Runtime: `flutter_gemma` with GPU preferred, 512-token generation cap

The **production notebook** merges LoRA weights and exports `.litertlm` using [Google's Gemma 4 LiteRT guide](https://developers.google.com/edge/litert-lm/models/gemma-4).

## Colab setup (both notebooks)

Open from Google Drive: `My Drive/capstone/training/notebooks/` → **Open with → Google Colaboratory**.

**Run order:**
1. **Install** cell → **Runtime → Restart session**
2. **Colab setup** cell (mounts Drive, `HF_TOKEN`, GPU check, paths)
3. Remaining cells in order

**Drive layout:**

```
My Drive/capstone/
├── training/              ← notebooks, src/, results/
└── dataset/
    └── ranga_output/      ← JSONL training files
```

Add Colab secret **`HF_TOKEN`** (🔑 in left sidebar). Set runtime to **GPU**.

## Evaluation metrics (both notebooks)

| Metric | Definition |
|---|---|
| **TOA** | Exact tool-name sequence match |
| **PSA** | Correct `nearby` vs `condition` path |
| **FTA** | First call is `getCurrentLocation` |
| **RTIR** | Reaches `rankHospitalsByPriorityAndCost` |
| **IAA** | Correct insurance argument on step 2 |
| **MCR** | Fraction of pipeline completed |

Reports are saved under `training/results/reports/`.

## Local development

```bash
cd training
pip install -r requirements.txt
pytest tests/ -v
```

## References

- [Fine-tuning with FunctionGemma](https://ai.google.dev/gemma/docs/functiongemma/finetuning-with-functiongemma)
- [Gemma 4 LiteRT-LM deployment](https://developers.google.com/edge/litert-lm/models/gemma-4)
- [Unsloth Gemma 4 training](https://unsloth.ai/docs/models/gemma-4/train)
- Dataset generator: `dataset/ranga_dataset_gen.ipynb`
