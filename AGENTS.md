# Pixer

Pixer is a cross-platform library for image manipulation: resize, crop, rotate, create thumbnails, combine images, and more.
It uses Rust's image crate via FFI to provide high-performance image processing.

## Project Structure

- `/native` - Rust crate (pixer) with image processing logic
- `/packages/pixer` - Main Dart package with FFI bindings
- `/packages/benchmarks` - Performance benchmarks
- `/packages/upscale_flutter` - Flutter demo app

## Useful Commands

```bash
# Build native library locally
# Examples: -omacos -aarm64, -olinux -ax64, -oandroid -aarm64
dart tool/build.dart -o<os> -a<arch>
# Generate FFI bindings (after changing native/src/ffi.rs)
dart run ffigen --config ffigen.yaml
```

## Release

1. Push changes via PR to `main`
2. Tag and push: `git tag pixer-assets-v1.0.0 && git push origin pixer-assets-v1.0.0`
3. CI builds all platforms and creates GitHub Release

## Changelog

- Do not modify entries for already released versions. A version heading like `## 0.0.4` means that version is released.
- Put new changes under `## Unreleased`. If there is no `Unreleased` section, add one above the latest version.

## Architecture

- Rust code in `native/src/`: `lib.rs` (entry), `api.rs` (image ops), `ffi.rs` (C-compatible API)
- Dart bindings generated via ffigen into `lib/src/bindings/`
- Native assets delivered via Dart build hooks (see `hook/` directory)
