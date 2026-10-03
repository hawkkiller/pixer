#ifndef FAST_IMAGE_H
#define FAST_IMAGE_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Pass as the `format` of `pixer_load_from_memory` to detect it from the bytes.
 */
#define PIXER_FORMAT_DETECT 4294967295

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
 * Result of every fallible Pixer function; outputs are written through
 * out-parameters only on `Success`.
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

/**
 * Stable operation identifiers shared by the native and Dart batch APIs.
 *
 * Each variant documents how it reads the `PixerOperation` slots; unused
 * slots are ignored.
 */
enum PixerOperationKind
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  /**
   * Fit within `arg0` x `arg1`, preserving aspect ratio. `arg2`: `FilterTypeEnum`.
   */
  Resize = 0,
  /**
   * Resize to exactly `arg0` x `arg1`. `arg2`: `FilterTypeEnum`.
   */
  ResizeExact = 1,
  /**
   * `arg0`, `arg1`: origin; `arg2`, `arg3`: width and height.
   */
  Crop = 2,
  Rotate90 = 3,
  Rotate180 = 4,
  Rotate270 = 5,
  FlipHorizontal = 6,
  FlipVertical = 7,
  /**
   * Gaussian blur, `scalar`: sigma (zero or a positive normal f32).
   */
  Blur = 8,
  /**
   * `arg0`: i32 offset added to color channels, preserving alpha.
   */
  Brightness = 9,
  /**
   * `scalar`: finite f32 contrast around the midpoint; 0 is neutral.
   */
  Contrast = 10,
  Grayscale = 11,
  Invert = 12,
};
#ifndef __cplusplus
typedef uint32_t PixerOperationKind;
#endif // __cplusplus

typedef struct ImageHandle {
  uint8_t _private[0];
} ImageHandle;

typedef struct ImageMetadata {
  uint32_t width;
  uint32_t height;
  uint8_t color_type;
} ImageMetadata;

/**
 * One operation in a batch. Arguments are interpreted according to `kind`.
 */
typedef struct PixerOperation {
  uint32_t kind;
  int64_t arg0;
  int64_t arg1;
  int64_t arg2;
  int64_t arg3;
  double scalar;
} PixerOperation;

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * ABI contract version. Increment for incompatible signatures, layouts, or IDs.
 */
uint32_t pixer_abi_version(void);

/**
 * Pixel-buffer byte length for native memory accounting; zero for a null handle.
 */
uintptr_t pixer_image_byte_length(const struct ImageHandle *handle);

/**
 * Free a buffer returned by `pixer_batch_encode`.
 */
void pixer_free_buffer(uint8_t *ptr, uintptr_t len);

/**
 * Free an image handle
 */
void pixer_free(struct ImageHandle *handle);

/**
 * Load an image from a file path into `out_image`.
 */
ImageErrorCode pixer_load(const char *path, struct ImageHandle **out_image);

/**
 * Load an image from memory into `out_image`.
 *
 * `format` is an `ImageFormatEnum` value, or `PIXER_FORMAT_DETECT`.
 */
ImageErrorCode pixer_load_from_memory(const uint8_t *data,
                                      uintptr_t len,
                                      uint32_t format,
                                      struct ImageHandle **out_image);

/**
 * Get image metadata
 */
ImageErrorCode pixer_get_metadata(const struct ImageHandle *handle,
                                  struct ImageMetadata *out_metadata);

/**
 * Apply a batch and write the final image to `out_image`. The source image
 * is unchanged.
 */
ImageErrorCode pixer_batch_to_image(const struct ImageHandle *handle,
                                    const struct PixerOperation *operations,
                                    uintptr_t operation_count,
                                    struct ImageHandle **out_image,
                                    uintptr_t *out_failed_index);

/**
 * Apply a batch and encode the final image. `format` is an `ImageFormatEnum`
 * value; `jpeg_quality` (1..=100) is read only for JPEG.
 * Caller must free the buffer using `pixer_free_buffer`.
 */
ImageErrorCode pixer_batch_encode(const struct ImageHandle *handle,
                                  const struct PixerOperation *operations,
                                  uintptr_t operation_count,
                                  uint32_t format,
                                  uint8_t jpeg_quality,
                                  uint8_t **out_data,
                                  uintptr_t *out_len,
                                  uintptr_t *out_failed_index);

/**
 * Apply a batch and save the final image to a file; the extension picks the format.
 */
ImageErrorCode pixer_batch_save(const struct ImageHandle *handle,
                                const struct PixerOperation *operations,
                                uintptr_t operation_count,
                                const char *path,
                                uintptr_t *out_failed_index);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  /* FAST_IMAGE_H */
