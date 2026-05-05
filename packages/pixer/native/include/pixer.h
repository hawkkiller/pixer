#ifndef FAST_IMAGE_H
#define FAST_IMAGE_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Filter type for resizing operations
 */
enum FilterTypeEnum
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  Nearest = 0,
  Triangle = 1,
  CatmullRom = 2,
  Gaussian = 3,
  Lanczos3 = 4,
};
#ifndef __cplusplus
typedef uint32_t FilterTypeEnum;
#endif // __cplusplus

/**
 * Error codes for image operations
 */
enum ImageErrorCode
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  Success = 0,
  InvalidPath = 1,
  UnsupportedFormat = 2,
  DecodingError = 3,
  EncodingError = 4,
  IoError = 5,
  InvalidDimensions = 6,
  InvalidPointer = 7,
  InvalidParameter = 8,
  Unknown = 99,
};
#ifndef __cplusplus
typedef uint32_t ImageErrorCode;
#endif // __cplusplus

/**
 * Image format enum for encoding/decoding
 */
enum ImageFormatEnum
#ifdef __cplusplus
  : uint32_t
#endif // __cplusplus
 {
  Png = 0,
  Jpeg = 1,
  Gif = 2,
  WebP = 3,
  Bmp = 4,
  Ico = 5,
  Tiff = 6,
};
#ifndef __cplusplus
typedef uint32_t ImageFormatEnum;
#endif // __cplusplus

/**
 * Opaque handle to an image
 */
typedef struct ImageHandle {
  uint8_t _private[0];
} ImageHandle;

/**
 * Image metadata structure
 */
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
 * Caller must free the buffer using pixer_free_buffer.
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
 * Resize an image
 */
struct ImageHandle *pixer_resize(const struct ImageHandle *handle,
                                 uint32_t width,
                                 uint32_t height,
                                 FilterTypeEnum filter);

/**
 * Resize an image to exact dimensions
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
 * Blur an image
 */
struct ImageHandle *pixer_blur(const struct ImageHandle *handle, float sigma);

/**
 * Brighten the pixels of an image
 */
struct ImageHandle *pixer_brighten(const struct ImageHandle *handle, int32_t value);

/**
 * Adjust contrast
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
