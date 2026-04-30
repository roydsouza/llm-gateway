### `/Users/rds/.cache/huggingface/hub/models--mlx-community--gemma-4-26b-a4b-it-4bit/snapshots/695690b33533b1f8b0395c1d6b4f00dc411353ef` — Context & Memory Profile

Context depths tested: 512,4096,8192

| Configuration | Context Size | TTFT | Generation Speed | Model Size | Active RAM (OS) | GPU_Alloc (virtual) | GPU_InUse peak (physical) |
|---|---|---|---|---|---|---|---|
| SSD Stream | 512 | 9.33s | 13.71 tok/s | N/A | 4.5 GB | 6.0 GB | 4.6 GB |
| SSD Stream | 4096 | 8.14s | 12.35 tok/s | N/A | 7.1 GB | 7.9 GB | 5.3 GB |
| SSD Stream | 8192 | 8.62s | 12.83 tok/s | N/A | 9.1 GB | 9.8 GB | 5.8 GB |
| SSD + TurboQuant | 512 | 5.99s | 14.06 tok/s | N/A | 4.6 GB | 6.2 GB | 4.7 GB |
| SSD + TurboQuant | 4096 | 9.79s | 16.90 tok/s | N/A | 6.6 GB | 7.3 GB | 5.4 GB |
| SSD + TurboQuant | 8192 | 15.01s | 17.07 tok/s | N/A | 6.8 GB | 7.5 GB | 5.5 GB |
| SSD + 16-Worker Prefetch | 512 | 1.25s | 13.39 tok/s | N/A | 4.5 GB | 5.3 GB | 4.6 GB |
| SSD + 16-Worker Prefetch | 4096 | 3.57s | 12.52 tok/s | N/A | 6.9 GB | 7.6 GB | 5.6 GB |
| SSD + 16-Worker Prefetch | 8192 | 3.73s | 13.31 tok/s | N/A | 8.5 GB | 9.3 GB | 5.6 GB |

> **Active RAM (OS)**: Memory wired into physical RAM by macOS (from server log).
> **GPU_Alloc (virtual)**: Total GPU address-space allocation including SSD-backed pages — the TRUE memory demand, can exceed physical RAM.
> **GPU_InUse peak (physical)**: Peak physical RAM occupied by the GPU during the entire request (prefill + generation), sampled every 0.5 s. This is the real active footprint — for SSD-streaming configs it reflects the high-water mark while layers are being read, not a post-generation snapshot.
