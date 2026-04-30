# LLM Gateway — SwiftLM on Apple M5

Local LLM inference gateway powered by [SwiftLM](https://github.com/nicklacosa/SwiftLM), optimized for Mixture-of-Experts models on Apple Silicon M5 (24GB unified memory).

## Quick Start

```bash
./gateway.sh start     # Launch Gemma 4 MoE on port 8000
./gateway.sh status    # Check running state
./gateway.sh stop      # Gracefully shut down
./gateway.sh info      # Profile VRAM requirements (dry-run)
./gateway.sh build     # Rebuild SwiftLM from source
```

## Architecture

**Single engine, single model, zero Python.**

| Component | Detail |
|:---|:---|
| **Engine** | SwiftLM (compiled Swift, native Metal) |
| **Model** | Gemma 4 26B-A4B-IT (MoE: 128 experts, 4B active) |
| **API** | OpenAI-compatible (`/v1/chat/completions`) |
| **Port** | 8000 |
| **Hardware** | Apple M5, 24GB unified memory |

### MoE Strategy

SwiftLM's `--stream-experts` flag memory-maps expert weights to NVMe, loading only the active experts into VRAM per token. Combined with `--ssd-prefetch` (16-worker background prefetch) and `--turbo-kv` (3.5-bit KV cache compression), this enables large MoE models to run efficiently within 24GB.

## Directory Structure

```
llm-gateway/
├── README.md          # This file
├── CLAUDE.md          # Agent instructions
├── BENCHMARKS.md      # Performance leaderboard
├── INVENTORY.md       # Model registry
├── TASKS.md           # Active work items
├── SYNC_LOG.md        # Session history
├── config.json        # SwiftLM configuration
├── gateway.sh         # Start/stop/status wrapper
└── swiftlm/           # SwiftLM source (built from source)
```

Model weights live in `~/.cache/huggingface/hub/` and are referenced by path in `config.json`.

## Key Links

- [BENCHMARKS.md](./BENCHMARKS.md) — Performance data
- [INVENTORY.md](./INVENTORY.md) — Active model registry
- [TASKS.md](./TASKS.md) — Work items
