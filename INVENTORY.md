# Model Inventory

**Hardware:** Apple M5, 24GB unified memory
**Engine:** SwiftLM (compiled Swift, native Metal)
**Policy:** MoE models only. Dense models are not permitted.

## Active Model

| Model | Architecture | Params (Total / Active) | Disk | HF Cache Path |
|:---|:---|:---|:---|:---|
| **qwen3.5-35b-a3b-4bit** | Gated DeltaNet + MoE (256 experts) | 35B / 3B active | 20 GB | `~/.cache/huggingface/hub/models--mlx-community--Qwen3.5-35B-A3B-4bit` |
| **gemma-4-26b-a4b-it-4bit** | MoE (128 experts, top-k 8) | 26B / 4B active | 15 GB | `~/.cache/huggingface/hub/models--mlx-community--gemma-4-26b-a4b-it-4bit` |

### SwiftLM Flags for This Model
```bash
--thinking          # Enable native reasoning mode (Qwen 3.5 specific)
--stream-experts    # Memory-map expert weights to NVMe
--ssd-prefetch      # 16-worker background SSD prefetch
--turbo-kv          # KV cache compression (~3.5 bits/token)
```

## Offloaded (Historical)

| Model | Date | Reason | Architecture |
|:---|:---|:---|:---|
| Qwen3-Coder-32B-Instruct-4bit | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| Qwen3-32B-Instruct-4bit | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| Qwen3-14B-MLX | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| DeepSeek-8B-MLX-Q4 | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| Qwen2.5-Coder-7B-Instruct-8bit | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| Qwen3.6-27B-4bit | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| Mistral-Small-3.2-24B-Instruct-2506-4bit | 2026-04-28 | Dense model. MoE-only policy. | Dense |
| Qwen3.5-122B-A10B-4bit | 2026-04-28 | Consolidation. Gemma 4 selected as primary. | MoE |
| Hermes-3-8B-GGUF | 2026-04-26 | Replaced by SwiftLM MLX variant. | Dense |
| Phi-3.5-mini-GGUF | 2026-04-26 | Outperformed by Qwen2.5-7B on MLX. | Dense |

## Adding New Models

1. Model must be MoE architecture with SwiftLM-compatible MLX format.
2. Benchmark with `./gateway.sh` and record results in `BENCHMARKS.md`.
3. Update this file with the new model details.
