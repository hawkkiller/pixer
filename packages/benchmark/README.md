# Benchmarks

Compares `pixer` (Rust-backed) with the pure Dart `image` package.

## Running Benchmarks

```bash
dart run bin/main.dart
```

Results are printed and saved to `benchmark_results.json`.

For the memory benchmark:

```bash
dart run bin/memory.dart [--runs 3]
```

It builds an AOT executable first, then saves results to `memory_results.json`.

## Benchmark Results

![pixer vs image benchmark](chart.png)

_Last updated: October 4, 2026. Apple M4 Pro (12 cores), Dart 3.13.0, pixer built from source._

Times are per operation, in milliseconds.

| Operation                         | pixer | image   | Speedup   |
| --------------------------------- | ----- | ------- | --------- |
| **Resize to 800x600**             | 1.1   | 334.7   | **307x**  |
| **Resize to 1280x720**            | 1.4   | 645.1   | **466x**  |
| **Resize to 3840x2160**           | 3.5   | 5,868.9 | **1684x** |
| **Load (decode JPEG)**            | 6.1   | 65.0    | **10.6x** |
| **Encode JPEG (quality 85)**      | 17.4  | 83.6    | **4.8x**  |
| **Rotate 90°**                    | 1.3   | 30.4    | **24.0x** |
| **Flip Horizontal**               | 1.4   | 36.9    | **26.9x** |
| **Decode, upscale to 4K, encode** | 63.0  | 6,260.7 | **99.4x** |

The input is a Full HD (1920x1080) JPEG decoded from memory. Resizes produce exact dimensions with a
cubic filter in both libraries (`FilterTypeEnum.CatmullRom` and `Interpolation.cubic`).

### Notes

- Resize gains come from SIMD and from splitting large images across CPU cores.
- Load and encode are bound by the JPEG codecs, so gains there are smaller.
- Numbers depend on the CPU and core count, so rerun on your target hardware.

## Memory Results

_Last updated: October 8, 2026. Linux x86_64 cloud VM (4 cores), Dart 3.13.5, pixer built from source._

Each operation starts from the same Full HD JPEG bytes, so resizes and encodes include the decode.
Values are in MB.

| Operation                         | pixer peak RSS | image peak RSS | Ratio    | pixer Dart heap | image Dart heap |
| --------------------------------- | -------------- | -------------- | -------- | --------------- | --------------- |
| **Decode JPEG**                   | 9.0            | 41.6           | **4.6x** | ~0              | 55.4            |
| **Resize to 800x600**             | 13.6           | 50.1           | **3.7x** | ~0              | 48.1            |
| **Resize to 3840x2160**           | 44.7           | 72.6           | **1.6x** | ~0              | 50.2            |
| **Encode JPEG (quality 85)**      | 9.2            | 47.2           | **5.1x** | 0.5             | 14.0            |
| **Decode, upscale to 4K, encode** | 44.7           | 79.2           | **1.8x** | 1.2             | 77.3            |

- **Peak RSS** is how far the process's peak resident memory rose during the operation: everything
  the OS sees, including pixer's native buffers and worker threads. Each case runs once in a fresh
  AOT process (median of 3). On Linux the kernel's peak is reset just before the operation, so the
  value is exact; elsewhere it is a lower bound.
- **Dart heap** is the bytes the operation allocated on the Dart heap, read through the VM service
  from a JIT process. Pixer keeps pixels in native memory, so it only allocates the encoded output
  there; `image` allocates every pixel buffer and its decoder's working memory on the GC heap.
- The result sizes match: a decoded Full HD image is 5.9 MB and a 4K one 23.7 MB in both libraries.
  The gap is working memory. It is largest for decode and encode and shrinks for 4K output, where
  the result itself dominates.
- `image` numbers vary by a few MB between runs because they depend on when the GC runs.
