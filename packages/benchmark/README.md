# Benchmarks

Comprehensive benchmarks comparing `pixer` (Rust-backed) with the pure Dart `image` package.

## Running Benchmarks

```bash
dart run bin/main.dart
```

## Benchmark Results

_Last updated: May 17, 2026_

| Operation            | pixer (μs) | image (μs) | Speedup   |
| -------------------- | ---------- | ---------- | --------- |
| **Resize 800x600**   | 149,562    | 3,211,790  | **21.5x** |
| **Resize 1920x1080** | 864        | 4,941      | **5.7x**  |
| **Resize 3840x2160** | 903,944    | 56,847,694 | **62.9x** |
| **Load**             | 59,613     | 633,168    | **10.6x** |
| **Encode JPEG**      | 201,714    | 1,211,010  | **6.0x**  |
| **Rotate 90°**       | 16,463     | 305,783    | **18.6x** |
| **Flip Horizontal**  | 13,892     | 377,647    | **27.2x** |

Note: Image given as input for all operations is a Full HD (1920x1080) JPEG image.

### Key Findings

- **Massive 4K Performance**: `pixer` is **62.9x faster** at resizing 4K images
- **Consistent Advantages**: Speedups range from 5.7x to 62.9x across all operations
- **Memory Efficient**: Rust-backed implementation with proper resource management
- **Production Ready**: Significant performance gains for real-world image processing tasks

## Expected Results

`pixer` should demonstrate significant performance advantages, especially for:

- Large image resizing (4K)
- Encoding operations
- Batch transformations

The Rust-backed implementation typically shows 5-60x performance improvements depending on the operation.
