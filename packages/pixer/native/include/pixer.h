#ifndef FAST_IMAGE_H
#define FAST_IMAGE_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Sampling filter used when resizing.
 *
 * Quality and cost roughly increase from top to bottom; `Lanczos3` is the
 * default and produces the sharpest results, `Nearest` is the fastest.
 */
enum FilterTypeEnum
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  /**
   * Nearest-neighbour. Fastest, blocky output. Good for pixel art.
   */
  Nearest = 0,
  /**
   * Linear (a.k.a. bilinear). Cheap, slightly blurry.
   */
  Triangle = 1,
  /**
   * Catmull-Rom cubic. Sharper than `Triangle`, can ring on edges.
   */
  CatmullRom = 2,
  /**
   * Gaussian. Soft output, useful for downscaling without aliasing.
   */
  Gaussian = 3,
  /**
   * Lanczos with `a = 3`. Highest quality, slowest. Default.
   */
  Lanczos3 = 4,
};
#ifndef __cplusplus
typedef uint32_t FilterTypeEnum;
#endif // __cplusplus

/**
 * Error code returned through `out_error` pointers and as the result of
 * operations that don't return a handle.
 */
enum ImageErrorCode
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  /**
   * The operation succeeded.
   */
  Success = 0,
  /**
   * The provided path is empty, malformed, or refers to a non-existent file.
   */
  InvalidPath = 1,
  /**
   * The image format is not recognised or not supported by this build.
   */
  UnsupportedFormat = 2,
  /**
   * The image bytes are corrupt or do not match the expected format.
   */
  DecodingError = 3,
  /**
   * Encoding the image to the requested format failed.
   */
  EncodingError = 4,
  /**
   * An underlying I/O operation (read/write) failed.
   */
  IoError = 5,
  /**
   * Width, height, or crop bounds are zero or exceed the image.
   */
  InvalidDimensions = 6,
  /**
   * A handle or output pointer was null, or the image has been freed.
   */
  InvalidPointer = 7,
  /**
   * A scalar parameter (e.g. JPEG quality, blur sigma) is out of range.
   */
  InvalidParameter = 8,
  /**
   * An unclassified error occurred.
   */
  Unknown = 99,
};
#ifndef __cplusplus
typedef uint32_t ImageErrorCode;
#endif // __cplusplus

/**
 * Image container format used for both decoding and encoding.
 */
enum ImageFormatEnum
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  /**
   * Portable Network Graphics — lossless, alpha supported.
   */
  Png = 0,
  /**
   * JPEG — lossy, no alpha. Quality is configurable on encode.
   */
  Jpeg = 1,
  /**
   * Graphics Interchange Format — palette-based, supports animation
   * (single-frame only via this API).
   */
  Gif = 2,
  /**
   * WebP — lossy or lossless, alpha supported.
   */
  WebP = 3,
  /**
   * Windows Bitmap — uncompressed, large files.
   */
  Bmp = 4,
  /**
   * Windows Icon — multi-resolution container.
   */
  Ico = 5,
  /**
   * Tagged Image File Format — typically lossless.
   */
  Tiff = 6,
};
#ifndef __cplusplus
typedef uint32_t ImageFormatEnum;
#endif // __cplusplus

typedef struct ImageHandle {
  uint8_t _private[0];
} ImageHandle;

typedef struct ImageMetadata {
  uint32_t width;
  uint32_t height;
  uint8_t color_type;
} ImageMetadata;

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * Free a string allocated by Rust
 */
void pixer_free_string(char *ptr);

/**
 * Free image data buffer
 */
void pixer_free_buffer(uint8_t *ptr, uintptr_t len);

/**
 * Free an image handle
 */
void pixer_free(struct ImageHandle *handle);

/**
 * Load an image from a file path
 * Returns null on error
 */
struct ImageHandle *pixer_load(const char *path);

/**
 * Load an image from memory buffer
 */
struct ImageHandle *pixer_load_from_memory(const uint8_t *data, uintptr_t len);

/**
 * Load an image from memory with specific format
 */
struct ImageHandle *pixer_load_from_memory_with_format(const uint8_t *data,
                                                       uintptr_t len,
                                                       ImageFormatEnum format);

/**
 * Load an image from a file path with error code output
 */
struct ImageHandle *pixer_load_with_error(const char *path, ImageErrorCode *out_error);

/**
 * Load an image from memory buffer with error code output
 */
struct ImageHandle *pixer_load_from_memory_with_error(const uint8_t *data,
                                                      uintptr_t len,
                                                      ImageErrorCode *out_error);

/**
 * Load an image from memory with specific format and error code output
 */
struct ImageHandle *pixer_load_from_memory_with_format_and_error(const uint8_t *data,
                                                                 uintptr_t len,
                                                                 ImageFormatEnum format,
                                                                 ImageErrorCode *out_error);

/**
 * Save an image to a file path
 */
ImageErrorCode pixer_save(const struct ImageHandle *handle, const char *path);

/**
 * Write an image to a buffer in the specified format
 * Caller must free the buffer using pixer_free_buffer
 */
ImageErrorCode pixer_write_to(const struct ImageHandle *handle,
                              ImageFormatEnum format,
                              uint8_t **out_data,
                              uintptr_t *out_len);

/**
 * Write an image to a JPEG buffer with the specified quality.
 *
 * `quality` must be in `1..=100`; `format` must be `Jpeg`. Use
 * `pixer_write_to` for other formats. Caller must free the buffer using
 * `pixer_free_buffer`.
 */
ImageErrorCode pixer_write_to_with_quality(const struct ImageHandle *handle,
                                           ImageFormatEnum format,
                                           uint8_t quality,
                                           uint8_t **out_data,
                                           uintptr_t *out_len);

/**
 * Get image metadata
 */
ImageErrorCode pixer_get_metadata(const struct ImageHandle *handle,
                                  struct ImageMetadata *out_metadata);

/**
 * Resize the image to fit *within* `width` x `height` while preserving
 * aspect ratio.
 *
 * The result is at most `width` x `height`; the smaller dimension is scaled
 * proportionally so the image is never distorted. Use `pixer_resize_exact`
 * to force exact dimensions.
 */
struct ImageHandle *pixer_resize(const struct ImageHandle *handle,
                                 uint32_t width,
                                 uint32_t height,
                                 FilterTypeEnum filter);

/**
 * Resize the image to exactly `width` x `height`, ignoring aspect ratio.
 *
 * May visibly stretch or squash the image.
 */
struct ImageHandle *pixer_resize_exact(const struct ImageHandle *handle,
                                       uint32_t width,
                                       uint32_t height,
                                       FilterTypeEnum filter);

/**
 * Crop an image (immutable)
 */
struct ImageHandle *pixer_crop_imm(const struct ImageHandle *handle,
                                   uint32_t x,
                                   uint32_t y,
                                   uint32_t width,
                                   uint32_t height);

/**
 * Rotate an image 90 degrees clockwise
 */
struct ImageHandle *pixer_rotate90(const struct ImageHandle *handle);

/**
 * Rotate an image 180 degrees
 */
struct ImageHandle *pixer_rotate180(const struct ImageHandle *handle);

/**
 * Rotate an image 270 degrees clockwise
 */
struct ImageHandle *pixer_rotate270(const struct ImageHandle *handle);

/**
 * Flip an image horizontally
 */
struct ImageHandle *pixer_fliph(const struct ImageHandle *handle);

/**
 * Flip an image vertically
 */
struct ImageHandle *pixer_flipv(const struct ImageHandle *handle);

/**
 * Apply a Gaussian blur with the given standard deviation in pixels.
 *
 * `sigma` must be finite and `>= 0`. `sigma == 0` returns an unchanged copy.
 */
struct ImageHandle *pixer_blur(const struct ImageHandle *handle, float sigma);

/**
 * Add `value` to every channel of every pixel.
 *
 * Values are clamped per-channel to `[0, 255]`. Negative values darken,
 * positive values brighten. The practical range is roughly `-255..=255`;
 * larger magnitudes simply saturate.
 */
struct ImageHandle *pixer_brighten(const struct ImageHandle *handle, int32_t value);

/**
 * Adjust contrast around the midpoint.
 *
 * `c == 0.0` leaves the image unchanged. Positive values increase contrast,
 * negative values decrease it. `c` must be finite.
 */
struct ImageHandle *pixer_adjust_contrast(const struct ImageHandle *handle, float c);

/**
 * Convert to grayscale
 */
struct ImageHandle *pixer_grayscale(const struct ImageHandle *handle);

/**
 * Invert colors (returns new image)
 */
struct ImageHandle *pixer_invert(const struct ImageHandle *handle);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  /* FAST_IMAGE_H */
