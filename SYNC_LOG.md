# SYNC_LOG — llm-gateway

> **Purpose:** Session history for the llm-gateway inference hub.

---

## 2026-04-29 — SwiftLM Flag Audit & Optimization

### What Was Accomplished
- **Audited** all SwiftLM CLI flags against `Server.swift` source code (~3,069 lines).
- **Discovered** that `--stream-experts` is silently ignored for the Gemma 4 checkpoint — the model's 15.6 GB weights are fully resident in RAM, not SSD-streamed. This is the root cause of memory pressure and repetition loops.
- **Applied** 4 new server-side flags: `--repeat-penalty 1.15`, `--ctx-size 8192`, `--top-k 40`, `--min-p 0.05`.
- **Synced** `config.json` with actual runtime values and documented it as metadata-only.
- **Created** `TUNING.md` to capture the full reasoning and methodology for future reference.
- **Verified** optimized config via smoke test: coherent output at 11.8 tok/s, no repetition loops.

### Key Metrics (After)
| Metric | Before | After |
|:---|:---|:---|
| repeat_penalty | disabled | 1.15 |
| ctx_size | unbounded | 8192 |
| top_k | disabled | 40 |
| min_p | disabled | 0.05 |
| Looping behavior | Severe ("way way way") | Eliminated |

### Open Items
- 🔴 SSD Expert Streaming needs investigation (would free ~12 GB RAM)
- 🟢 `--prefill-size 512` re-test after mlx-swift update
- 🟢 Speculative decoding (blocked on SSD fix)

---

## 2026-04-28 — Major Consolidation (local-llms → llm-gateway)

### What Was Accomplished
- **Renamed** `local-llms/` → `llm-gateway/` for clarity.
- **Removed** all inference engines except **SwiftLM** (llama.cpp, mlx-lm, omlx, vllm-mlx all deleted).
- **Uninstalled** Ollama (Homebrew) and mlx_lm (pip) from the system.
- **Purged** all dense models (~80GB from HF cache, ~45GB local copies).
- **Purged** non-Gemma MoE models (Qwen3.5-122B, Qwen3.5-35B — ~84GB from HF cache).
- **Removed** 3 git submodules: `event-horizon-core` (Go daemon), `llm-factory`, `llm-proving-ground`.
- **Removed** `openrouter/`, `local-llm-cache/`, `inference-engines/` wrapper directories.
- **Created** `gateway.sh` shell wrapper (start/stop/status/info/build).
- **Consolidated** all scattered benchmark files into single `BENCHMARKS.md`.
- **Created** lean `INVENTORY.md`, `TASKS.md`, `README.md`, `CLAUDE.md`, `config.json`.
- **Adopted MoE-only policy**: Only MoE models permitted. Dense models banned.

### Architecture (After)
- **Engine**: SwiftLM (compiled Swift binary, direct serving, no proxy)
- **Model**: Gemma 4 26B-A4B-IT (MoE, 128 experts, 4B active)
- **Port**: 8000 (direct SwiftLM serving)
- **Files**: 9 files + 1 directory (swiftlm/)

### Disk Impact
- ~164 GB reclaimed from model purge
- ~1.6 GB reclaimed from removing Go daemon + Python deps
- Total reclaimed: **~166 GB**

---

## 2026-04-26 — SwiftLM + MoE Investigation (Pre-Consolidation)

- Benchmarked Qwen3-32B series. Used SwiftLM's Zero-Python architecture.
- Confirmed `--turbo-kv` mandatory for >14B models.
- Confirmed `--stream-experts` for MoE models enables >100B inference via NVMe.
- Created 4-tier architecture (Gateway, Cache, Engines, Proving Ground) — now simplified.

---

## 2026-04-30 — Git Repository Initialization

### What Was Accomplished
- **Initialized** new git repository in `llm-gateway/`.
- **Converted** `swiftlm/` into a git submodule pointing to `SharpAI/swiftlm`.
- **Preserved** local audit remediations (swap monitoring, MoE-aware memory budgeting) within the submodule.
- **Pushed** initial commit to `https://github.com/roydsouza/llm-gateway`.
- **Verified** build integrity with the new submodule structure.
