# Tasks

- [x] **SwiftLM Parameter Tuning** — Investigate optimal SwiftLM flags for Gemma 4 MoE on M5 24GB.
      Flags to tune: `--stream-experts`, `--ssd-prefetch`, `--turbo-kv`, `--prefill-size`,
      `--parallel`, `--ctx-size`, `--gpu-layers`, `--mem-limit`, `--thinking`.
      Goal: maximize throughput (t/s) and minimize TTFT for Hermes Agent workloads.
- [ ] **MoE LLM Alternatives** — Investigate MoE models better suited for Hermes Agent on M5 24GB.
      Requirements: strong tool-calling, structured JSON output, multi-step reasoning,
      SwiftLM-compatible (MLX format), fits within 24GB with `--stream-experts`.
- [/] **Hermes Agent Benchmarks** — Design and implement real benchmarks for the Hermes Agent workload.
      Framework: BFCL tool-calling, JSON schema compliance, MT-Bench reasoning, Antigravity-Diff coding.
      (Inspired by the qualitative framework from the former llm-proving-ground.)
- [x] **Evaluate Qwen3.5-35B-A3B** — Test as a potential successor to Gemma 4 for the
      Local Skeptic role.
- [x] **Evaluate Qwen3.6-35B-A3B** — Migrate from 3.5 to 3.6 for improved agentic performance
      and longer native context support.
      Rationale: 3B active params (vs 26B/4B), Gated DeltaNet (RNN-hybrid) for long-context
      efficiency, native thinking mode support (`--thinking`), and diverse architecture
      biases for adversarial auditing.
      **Result:** ~11.5 t/s throughput on M5 24GB. Validated SSD streaming parity.
- [ ] **OpenRouter Integration** — Investigate OpenRouter as a cloud fallback for models too large for local inference.

## SwiftLM Optimization Tasks (from 2026-04-29 audit)

- [x] **🔴 Fix SSD Expert Streaming** — Verified and active for Qwen 3.5. Added architectural warnings for Gemma 4.
      **Status:** Hardened. SwiftLM now detects `QuantizedSwitchLinear` layers correctly.
- [x] **🔴 Implement Qwen 3.5 Audit Remediations** — Added swap monitoring, MoE-aware memory budgeting (2GB safety buffer), and enhanced SSD diagnostics.
- [x] **🟡 Add `--repeat-penalty 1.15`** — Server-side repetition penalty to combat
      Gemma 4's "way way way" looping. Currently mitigated only in client code (fragile).
      Test with values 1.05, 1.10, 1.15, 1.20 to find the sweet spot that stops loops
      without degrading coherence. Document results in BENCHMARKS.md.
- [x] **🟡 Add `--ctx-size 8192`** — Explicit context window cap. Without it, the memory
      profiler defaults to 4096 for budget calculation while the model allows 128K, creating
      a mismatch. Also gates TurboQuant activation (compresses > 8192 tokens).
- [ ] **🟢 Re-test `--prefill-size 512`** — Was lowered to 256 to avoid a `broadcast_shapes`
      crash in MLX attention. Check if upstream mlx-swift has fixed this bug. Restoring 512
      would recover ~15-20% prefill throughput.
- [x] **🟢 Add `--top-k 40 --min-p 0.05`** — Tighter sampling for agentic workloads.
      Reduces tail distribution noise, improving tool-call JSON reliability.
- [ ] **🟢 Investigate Speculative Decoding** — SwiftLM supports `--draft-model` and `--dflash`.
      Find a small draft model sharing Gemma 4's tokenizer. Blocked on fixing SSD streaming
      first (combined footprint would exceed 70% RAM budget).
- [x] **🟢 Sync `config.json`** — Update `config.json` to reflect actual runtime flags
      (prefill_size=256, add repeat_penalty, ctx_size) or document it as metadata-only.
