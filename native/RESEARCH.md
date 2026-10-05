# Research notes

Findings behind performance and size decisions. Keep entries short: what was
tried, the numbers, the decision. Measured on Apple M-series unless noted.

## Benchmark methodology (2026-10)

- `packages/benchmark` reports one operation per value (`SingleRun` mixin;
  `benchmark_harness` defaults to 10). Before Oct 2026 it also compared fit
  vs exact resize, Lanczos3 vs cubic, and JPEG q85 vs q100. Both libraries now
  use exact cubic resize, q85, and decode from memory.
- The showcase times decode + resize + JPEG encode. Pixer's advantage is
  ~63x on resize but only ~6–10x on decode and encode, so the full pipeline
  shows ~35x. Neither number is wrong; they measure different things.
- In this workspace, a stale `packages/pixer/.dart_tool/native_assets.yaml`
  overrides the root one, so tests silently load an old binary. Delete
  `packages/pixer/.dart_tool` if rebuilt code seems to have no effect.

## Compiler and FFI flags (2026-10)

- The release profile already uses `opt-level=3`, fat LTO, `codegen-units=1`,
  `panic=abort`. Nothing to gain there.
- `target-cpu`: not portable on x86_64 (breaks older CPUs); arm64 targets
  already assume NEON. PGO: ~5–15% for 13 CI targets of work. Skipped.
- Per-crate `opt-level` overrides are ignored under fat LTO (identical bytes).
- FFI copies (~1 ms for a few MB) are negligible next to pixel work.

## Format trimming (2026-10)

- `image` default features pulled in AVIF (`rav1e`), EXR, HDR, QOI, TGA, DDS,
  PNM, Farbfeld and `rayon`, none exposed by Pixer.
- Keeping only the 7 supported formats: macOS arm64 4.87 MB to 1.80 MB,
  x86_64 5.74 MB to 2.09 MB.
- `formats` hook user define builds from source with a subset. Rejected:
  per-format prebuilt presets (2^7 combinations) and link-hook tree shaking
  (needs per-format FFI symbols and a C linker; formats are runtime values).

## Resize: `fast_image_resize` (2026-10)

| Operation | `image` | fir 1 thread | fir + rayon |
| --- | --- | --- | --- |
| 1080p to 4K, Lanczos3 | 90 ms | 37 ms | 7 ms |
| 1080p to 4K, CatmullRom | 76 ms | 16 ms | 3.6 ms |
| 4K to 1080p, Lanczos3 | 59 ms | 13 ms | 3.8 ms |

- Size cost, macOS arm64 / x86_64 / WASM:

  | Variant | arm64 | x86_64 | WASM |
  | --- | --- | --- | --- |
  | Before fir | 1.80 MB | 2.09 MB | 1.70 MB |
  | fir, all pixel types, rayon | 4.13 MB | – | – |
  | fir, 8-bit only, rayon (shipped) | 2.42 MB | 5.13 MB | 2.00 MB |
  | fir, 8-bit only, no rayon | – | 3.78 MB | – |
  | fir, RGB/RGBA only, rayon | – | 3.91 MB | – |

- x86_64 is large because each kernel is compiled as scalar, SSE4.1 and AVX2
  (selected at runtime), SSE4.1 kernels are heavily unrolled (~55–73 KiB each),
  there is one copy per pixel type, and rayon's split views appear to double
  the instantiations. fir is 2.7 MiB of 4.6 MiB `.text` (`cargo bloat`).
- Decision: 8-bit layouts through fir with rayon; 16-bit and float fall back
  to `image`. Alpha is premultiplied (fir default), so output differs slightly.
- Open: patching out fir's SSE4.1 path would cut most of the x86 cost.
  WASM `+simd128` would enable SIMD in browsers but drops Safari < 16.4.

## JPEG encoding: `jpeg-encoder` (2026-10)

4K RGB image, `image` encoder vs `jpeg-encoder` 0.7.1 defaults:

| Quality | `image` | `jpeg-encoder` |
| --- | --- | --- |
| 75 | 1.09 MB, 41.8 dB, 62 ms | 0.91 MB, 39.4 dB, 29 ms |
| 90 | 1.77 MB, 45.3 dB, 60 ms | 1.82 MB, 45.4 dB, 50 ms |
| 100 | 4.25 MB, 50.8 dB, 93 ms | 6.55 MB, 52.2 dB, 91 ms |

- Below quality 90 `jpeg-encoder` switches to 4:2:0 chroma subsampling; its
  speedup comes from that, not a faster encoder. Forced to 4:4:4 it is no
  faster on ARM. Its SIMD is AVX2-only.
- Decision: keep the `image` encoder. Real speedups would need libjpeg-turbo
  (C, cross-compilation cost) or a user-facing chroma subsampling option.
