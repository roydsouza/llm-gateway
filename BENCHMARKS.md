# Benchmarks

Performance data for SwiftLM on Apple M5 (24GB unified memory).

## Benchmarking Protocol

1. **Zero-Background:** All background services terminated before testing.
2. **Warm-Up:** A silent dummy generation executed before timed runs to isolate JIT/startup overhead.
3. **Isolated:** SwiftLM started as a transient process, terminated and port released after data collection.
4. **Environment:** All browsers, Electron apps, and other GPU consumers closed.

---

## SwiftLM Leaderboard

### Gemma 4 MoE (26B-A4B-IT, 4-bit)

| Date | Profile | Tokens/sec | TTFT | VRAM | Context | Notes |
|:---|:---|:---|:---|:---|:---|:---|
| 2026-04-29 | **TurboQuant** | 17.07 t/s | 15.01s | 5.5 GB | 8k | `--stream-experts --turbo-kv` |
| 2026-04-29 | **Prefetch** | 13.31 t/s | 3.73s | 5.6 GB | 8k | `--stream-experts --ssd-prefetch` |

> [!TIP]
> For Gemma 4 MoE on M5 24GB, use **Prefetch** for interactive chat (low TTFT). Use **TurboQuant** for batch processing (high throughput).

### Historical (Dense Models, Pre-Consolidation)

| Date | Model | Tokens/sec | TTFT (t/s) | VRAM | Notes |
|:---|:---|:---|:---|:---|:---|
| 2026-04-27 | Qwen3-Coder-32B (dense) | 7.15 t/s | 1420 t/s | 23.8 GB | Swap-assisted, 24GB limit |
| 2026-04-27 | Qwen3-32B-Instruct (dense) | 7.22 t/s | 1450 t/s | 23.9 GB | Swap-assisted, 24GB limit |
| 2026-04-26 | Qwen3-14B-MLX (Q4, dense) | 15.25 t/s | 1459 t/s | 10.1 GB | Isolated |
| 2026-04-26 | DeepSeek-R1-8B (Q4, dense) | 27.73 t/s | 3846 t/s | 6.0 GB | Isolated |
| 2026-04-26 | Qwen2.5-7B (8-bit, dense) | 27.60 t/s | 4197 t/s | 5.4 GB | Isolated |

---

## Historical Engine Comparison (Reference Only)

These results are from the multi-engine era (pre-consolidation). Preserved for reference.

### Standalone: DeepSeek-R1-8B (Q8) — 2026-04-24

| Engine | Prompt Processing (t/s) | Text Generation (t/s) | VRAM (GB) |
|:---|:---|:---|:---|
| **SwiftLM** | **3846** | **27.73** | **6.0** |
| llama.cpp-metal | 460 | 15.27 | 7.95 |
| mlx-lm | 671 | 15.02 | 8.96 |
| oMLX | 128 | 14.64 | 9.0 |
| vllm-mlx | — | 13.90 | 9.0 |

**SwiftLM conclusion:** ~80% generation lead over llama.cpp and mlx-lm. Lowest VRAM footprint. Clear winner for Apple Silicon.

### Concurrent: Qwen2.5-7B + DeepSeek-8B — 2026-04-24

| Engine | Total Concurrent TPS | Contention Penalty | VRAM |
|:---|:---|:---|:---|
| **SwiftLM** | **39.12** | **-29%** | 10.5 GB |
| vllm-mlx | 36.46 | -32% | 11.5 GB |
| mlx-lm | 32.72 | -38% | 11.5 GB |
| llama.cpp-metal | 31.81 | -41% | 11.0 GB |

---

## Future: Qualitative Evaluation Framework

Adapted from the former `llm-proving-ground`. To be implemented as real benchmarks (see TASKS.md).

| Dimension | Weight | Harness | What It Tests |
|:---|:---|:---|:---|
| **Logic/Reasoning** | 40% | MT-Bench (Mini) | 10 multi-turn questions graded by the active model |
| **Tool/Agentic** | 30% | BFCL (Lite) | 5 function-calling scenarios (JSON tool invocation) |
| **Coding** | 30% | Antigravity-Diff | 5 code-refactoring tasks (must pass linter/compiler) |
