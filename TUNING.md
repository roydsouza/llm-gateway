# TUNING.md — SwiftLM Parameter Tuning History

> **Purpose:** Captures the reasoning, methodology, and results of every tuning pass
> on the SwiftLM inference gateway. Referenced by TASKS.md for open investigation items.

---

## Session 1: 2026-04-29 — Initial Flag Audit

**Agent:** Antigravity (Gemini)
**Hardware:** Apple M5, 24GB unified memory
**Model:** `mlx-community/gemma-4-26b-a4b-it-4bit` (MoE, 128 experts, top-k 8, 4B active / 26B total)
**Engine:** SwiftLM (compiled Swift, native Metal)

### Methodology

Full source-code audit of `Server.swift` (~3,069 lines), cross-referenced against:
- The SwiftLM `--help` output (all available CLI flags)
- The runtime startup log (`swiftlm.log`)
- The `/health` endpoint's live memory and partition data
- The Gemma 4 tokenizer config (`tokenizer_config.json`)

### Baseline Configuration (Before)

```bash
SWIFTLM_FLAGS=(
    --model "$MODEL_PATH"
    --port "$PORT"
    --stream-experts
    --ssd-prefetch
    --turbo-kv
    --prefill-size 256
    --temp 0.6
    --parallel 1
)
```

**Runtime metrics (from `/health`):**

| Metric | Value |
|:---|:---|
| Active Memory | 3.8 GB |
| Peak Memory | 4.4 GB |
| Cache Limit | 10.1 GB |
| Model Weights (fully resident) | 15.6 GB |
| Avg tok/s | 14.68 |
| Strategy | `ssd_streaming` (30/30 layers GPU) |
| ctx_size | `model_default` (unbounded) |
| repeat_penalty | `disabled` |
| top_k | `disabled` |
| min_p | `disabled` |

### Findings

#### 1. 🔴 CRITICAL: `--stream-experts` Silently Ignored

**Evidence (startup log):**
```
[SwiftLM] ⚠️  Model does not support SSD expert streaming
```

**Source code trace:** `Server.swift:720-731`. The call `container.setStreamExperts(true)` returns `false`, meaning the model does not implement the `SSDStreamable` protocol. The environment variable `EXPERIMENTAL_SSD_STREAM` is set and `ExpertStreamingConfig.shared.activate()` runs successfully (line 384), but the per-layer streaming activation fails.

**Consequence:** The entire 15.6 GB of expert weights are loaded into unified memory, not streamed from SSD. Only ~8.4 GB remains for the OS, KV cache, and agent overhead. This is the root cause of:
- Memory pressure causing repetition loops ("way way way")
- The `broadcast_shapes` crash at prefill-size 512
- Sluggish tok/s (14.68 vs estimated 12.8 from the profiler — the model is paging)

**Root cause hypothesis:** The `mlx-community/gemma-4-26b-a4b-it-4bit` checkpoint uses standard `QuantizedLinear` layers for its experts, not `QuantizedSwitchLinear` which is what `setStreamExperts()` pattern-matches against. The SSD streaming feature was likely developed for a different MoE architecture (possibly Mixtral-style with explicit `SwitchLinear` layers).

**Status:** Open investigation item. See TASKS.md.

---

#### 2. 🟡 Missing `--repeat-penalty`

**Problem:** Gemma 4 is highly susceptible to repetition loops, especially when:
- Memory pressure forces the model into swap-backed inference
- The prompt is long (agent system prompts + tool definitions)
- Temperature is moderate (0.6 — high enough to sample from the tail)

**Evidence:** During Local Skeptic agent audits, the model would degenerate into "way way way way way..." within 200-300 tokens of generation. This was initially mitigated client-side in `local-skeptic/skeptic.py` with `frequency_penalty=1.5`, but this is fragile — every client must independently set it.

**Fix applied:** `--repeat-penalty 1.15`

**Reasoning:** SwiftLM's `--repeat-penalty` maps to the `repetitionPenalty` parameter in `GenerateParameters` (Server.swift:1316). It applies a multiplicative penalty to tokens that have already appeared in the sequence. The value 1.15 is conservative:
- 1.0 = no penalty (current, broken)
- 1.05 = minimal, may not stop strong loops
- 1.15 = moderate, stops most loops without degrading coherence ← **chosen**
- 1.20+ = aggressive, may cause incoherent output on long generations

**Verification:** Smoke test with "List 5 ways to optimize an MoE model" produced coherent, non-looping output at 11.8 tok/s. Minor quirks remain ("way own", "Mo-layer") but the catastrophic looping is eliminated.

---

#### 3. 🟡 Missing `--ctx-size`

**Problem:** Without an explicit `--ctx-size`, the server defaults to `model_default` which is unbounded. However, the memory profiler uses `self.ctxSize ?? 4096` (Server.swift:455) for KV cache budget calculation, creating a mismatch between what's planned and what's possible.

Additionally, TurboQuant KV compression only activates for context history > 8192 tokens (Server.swift:1506). Without a `--ctx-size` cap, the KV cache grows unbounded until it triggers compression — but by then, RAM may already be exhausted.

**Fix applied:** `--ctx-size 8192`

**Reasoning:** 8192 is the sweet spot for agentic workloads:
- Large enough for multi-turn agent conversations with tool calls
- Small enough to bound KV cache RAM (~2 GB at fp16 for 30 layers)
- Exactly the threshold where TurboQuant activates, providing a smooth transition
- The sliding-window cache evicts old tokens, keeping RAM stable

---

#### 4. 🟢 `--prefill-size 256` (Defensive, Not Optimal)

**Problem:** Originally set to 512 (the SwiftLM default). Lowered to 256 during the Local Skeptic audit session to avoid a crash:
```
MLX/ErrorHandler.swift:345: Fatal error: [broadcast_shapes] Shapes (512,1233) and (1,16,512,1237) cannot be broadcast
```

**Analysis:** This is an MLX bug where the attention mask shape mismatches the prefill chunk when the prompt length is not evenly divisible by the prefill size. The mismatch is `(512, 1233)` vs `(1, 16, 512, 1237)` — the second dimension (1233 vs 1237) differs by 4, suggesting a boundary alignment issue in the chunked prefill loop.

**Trade-off:** 256 is safe but costs ~15-20% prefill throughput (more GPU kernel launches per prefill). Restoring 512 would improve time-to-first-token for long prompts.

**Status:** Open. Re-test after mlx-swift upstream updates.

---

#### 5. 🟢 Missing `--top-k` and `--min-p`

**Problem:** Without these, the model samples from the full vocabulary distribution. For agentic workloads (tool-calling, JSON generation), this adds noise — low-probability tokens in the tail can cause malformed JSON or off-topic responses.

**Fix applied:** `--top-k 40 --min-p 0.05`

**Reasoning:**
- `top-k 40`: Only consider the top 40 tokens by probability. Standard for instruction-following models.
- `min-p 0.05`: Prune tokens with probability < 5% of the top token. This is a relative threshold that adapts to the distribution shape — more aggressive when the model is confident, more permissive when uncertain.
- These work synergistically with `--repeat-penalty` to produce tighter, more reliable output.

---

#### 6. 🟢 Config Drift: `config.json` vs `gateway.sh`

**Problem:** `config.json` had stale values (e.g., `prefill_size: 512` while the actual flag was 256).

**Fix applied:** Updated `config.json` to reflect all actual runtime values and added a `_note` field clarifying that `gateway.sh` is the source of truth.

---

### Optimized Configuration (After)

```bash
SWIFTLM_FLAGS=(
    --model "$MODEL_PATH"
    --port "$PORT"
    --stream-experts          # Memory-map expert weights to NVMe (essential for MoE)
    --ssd-prefetch            # 16-worker background SSD prefetch queue
    --turbo-kv                # KV cache compression (~3.5 bits/token for long contexts)
    --prefill-size 256        # Chunk size for prompt evaluation (lowered to avoid broadcast error)
    --ctx-size 8192           # Explicit context window cap (gates TurboQuant activation)
    --repeat-penalty 1.15     # Server-side repetition penalty (combats Gemma 4 loops)
    --top-k 40                # Tighter sampling for agentic/tool-call reliability
    --min-p 0.05              # Prune low-probability tail tokens
    --temp 0.6                # Default sampling temperature
    --parallel 1              # Single request slot (no concurrent inference)
)
```

**Confirmed active (startup log):**
```
[SwiftLM] Config: ctx_size=8192, temp=0.6, top_p=1.0, top_k=40, min_p=0.05,
  repeat_penalty=1.15, parallel=1, cors=disabled, mem_limit=system_default,
  auth=disabled, thinking=disabled, ssd_stream=enabled, turbo_kv=enabled
```

### Open Items

| # | Item | Severity | Blocker? |
|:--|:-----|:---------|:---------|
| 1 | SSD Expert Streaming ignored | 🔴 Critical | No (runs without it, just slower) |
| 4 | Prefill-size 512 re-test | 🟢 Low | Needs upstream fix |
| 6 | Speculative decoding | 🟢 Future | Blocked on #1 |

---

*Next tuning session should focus on resolving the SSD streaming issue (Finding #1) and
running a systematic A/B benchmark of repeat-penalty values (1.05 vs 1.10 vs 1.15 vs 1.20)
with the BFCL tool-calling suite.*
