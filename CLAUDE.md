# llm-gateway — Agent Context

## What This Is

`llm-gateway/` is a lean local LLM inference gateway. It runs **SwiftLM** (compiled Swift, native Metal) serving **MoE models only** on Apple M5 24GB.

**There is no Go daemon, no Python code, no multi-engine abstraction.** SwiftLM serves directly on port 8000 with an OpenAI-compatible API.

## Key Facts

| Fact | Value |
|:---|:---|
| Engine | SwiftLM (`./swiftlm/.build/release/swiftlm`) |
| Model | Gemma 4 26B-A4B-IT (MoE, 128 experts, 4B active) |
| Port | 8000 |
| Config | `config.json` |
| Wrapper | `gateway.sh` (start/stop/status/info/build) |
| Model storage | `~/.cache/huggingface/hub/` (HuggingFace cache) |

## Rules

1. **SwiftLM only.** Do not add other inference engines (llama.cpp, mlx-lm, vllm, ollama).
2. **MoE only.** Do not add dense models. All models must use SwiftLM's `--stream-experts` for NVMe expert streaming.
3. **No Python.** This directory uses shell scripts only. No Python benchmarking scripts, no pip dependencies.
4. **No process overhead.** No forge, crucible, analyst-inbox, verdicts. Keep it lean.
5. **Single model at a time.** The M5 has 24GB. One model loaded, one port, one process.
6. **Benchmark before promoting.** New models must be benchmarked and recorded in `BENCHMARKS.md` before replacing the active model.

## File Map

- `gateway.sh` — The only executable. Manages SwiftLM lifecycle.
- `config.json` — Model path, port, SwiftLM flags.
- `BENCHMARKS.md` — All performance data in one place.
- `INVENTORY.md` — What's loaded and what's been offloaded.
- `TASKS.md` — Active work items.
- `swiftlm/` — SwiftLM source repo (built from source with `./gateway.sh build`).
