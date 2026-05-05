use crate::api::*;
use image::DynamicImage;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::slice;

// ============================================================================
// Memory Management
// ============================================================================

/// Free a string allocated by Rust
#[unsafe(no_mangle)]
pub extern "C" fn pixer_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Free image data buffer
#[unsafe(no_mangle)]
pub extern "C" fn pixer_free_buffer(ptr: *mut u8, len: usize) {
    if !ptr.is_null() && len > 0 {
        unsafe {
            let _ = Vec::from_raw_parts(ptr, len, len);
        }
    }
}

/// Free an image handle
#[unsafe(no_mangle)]
pub extern "C" fn pixer_free(handle: *mut ImageHandle) {
    if !handle.is_null() {
        unsafe {
            let _ = Box::from_raw(handle as *mut DynamicImage);
        }
    }
}

// ============================================================================
// Image Loading
// ============================================================================

/// Load an image from a file path
/// Returns null on error
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load(path: *const c_char) -> *mut ImageHandle {
    if path.is_null() {
        return std::ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        }
    };

    match load_image(path_str) {
        Ok(img) => Box::into_raw(Box::new(img)) as *mut ImageHandle,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Load an image from memory buffer
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load_from_memory(data: *const u8, len: usize) -> *mut ImageHandle {
    if data.is_null() || len == 0 {
        return std::ptr::null_mut();
    }

    let buffer = unsafe { slice::from_raw_parts(data, len) };

    match load_image_from_memory(buffer) {
        Ok(img) => Box::into_raw(Box::new(img)) as *mut ImageHandle,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Load an image from memory with specific format
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load_from_memory_with_format(
    data: *const u8,
    len: usize,
    format: ImageFormatEnum,
) -> *mut ImageHandle {
    if data.is_null() || len == 0 {
        return std::ptr::null_mut();
    }

    let buffer = unsafe { slice::from_raw_parts(data, len) };

    match load_image_from_memory_with_format(buffer, format.to_image_format()) {
        Ok(img) => Box::into_raw(Box::new(img)) as *mut ImageHandle,
        Err(_) => std::ptr::null_mut(),
    }
}

/// Load an image from a file path with error code output
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load_with_error(
    path: *const c_char,
    out_error: *mut ImageErrorCode,
) -> *mut ImageHandle {
    if path.is_null() {
        if !out_error.is_null() {
            unsafe { *out_error = ImageErrorCode::InvalidPointer };
        }
        return std::ptr::null_mut();
    }

    let path_str = unsafe {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => {
                if !out_error.is_null() {
                    *out_error = ImageErrorCode::InvalidPath;
                }
                return std::ptr::null_mut();
            }
        }
    };

    match load_image(path_str) {
        Ok(img) => {
            if !out_error.is_null() {
                unsafe { *out_error = ImageErrorCode::Success };
            }
            Box::into_raw(Box::new(img)) as *mut ImageHandle
        }
        Err(e) => {
            if !out_error.is_null() {
                unsafe { *out_error = error_to_code(&e) };
            }
            std::ptr::null_mut()
        }
    }
}

/// Load an image from memory buffer with error code output
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load_from_memory_with_error(
    data: *const u8,
    len: usize,
    out_error: *mut ImageErrorCode,
) -> *mut ImageHandle {
    if data.is_null() || len == 0 {
        if !out_error.is_null() {
            unsafe { *out_error = ImageErrorCode::InvalidPointer };
        }
        return std::ptr::null_mut();
    }

    let buffer = unsafe { slice::from_raw_parts(data, len) };

    match load_image_from_memory(buffer) {
        Ok(img) => {
            if !out_error.is_null() {
                unsafe { *out_error = ImageErrorCode::Success };
            }
            Box::into_raw(Box::new(img)) as *mut ImageHandle
        }
        Err(e) => {
            if !out_error.is_null() {
                unsafe { *out_error = error_to_code(&e) };
            }
            std::ptr::null_mut()
        }
    }
}

/// Load an image from memory with specific format and error code output
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load_from_memory_with_format_and_error(
    data: *const u8,
    len: usize,
    format: ImageFormatEnum,
    out_error: *mut ImageErrorCode,
) -> *mut ImageHandle {
    if data.is_null() || len == 0 {
        if !out_error.is_null() {
            unsafe { *out_error = ImageErrorCode::InvalidPointer };
        }
        return std::ptr::null_mut();
    }

    let buffer = unsafe { slice::from_raw_parts(data, len) };

    match load_image_from_memory_with_format(buffer, format.to_image_format()) {
        Ok(img) => {
            if !out_error.is_null() {
                unsafe { *out_error = ImageErrorCode::Success };
            }
            Box::into_raw(Box::new(img)) as *mut ImageHandle
        }
        Err(e) => {
            if !out_error.is_null() {
                unsafe { *out_error = error_to_code(&e) };
            }
            std::ptr::null_mut()
        }
    }
}

// ============================================================================
// Image Saving
// ============================================================================

/// Save an image to a file path
#[unsafe(no_mangle)]
pub extern "C" fn pixer_save(handle: *const ImageHandle, path: *const c_char) -> ImageErrorCode {
    if handle.is_null() || path.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let path_str = unsafe {
        match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return ImageErrorCode::InvalidPath,
        }
    };

    match save_image(img, path_str) {
        Ok(_) => ImageErrorCode::Success,
        Err(e) => error_to_code(&e),
    }
}

/// Write an image to a buffer in the specified format
/// Caller must free the buffer using pixer_free_buffer
#[unsafe(no_mangle)]
pub extern "C" fn pixer_write_to(
    handle: *const ImageHandle,
    format: ImageFormatEnum,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> ImageErrorCode {
    if handle.is_null() || out_data.is_null() || out_len.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    let img = unsafe { &*(handle as *const DynamicImage) };

    match write_to(img, format.to_image_format()) {
        Ok(buffer) => {
            let mut boxed = buffer.into_boxed_slice();
            let len = boxed.len();
            let ptr = boxed.as_mut_ptr();
            std::mem::forget(boxed);

            unsafe {
                *out_data = ptr;
                *out_len = len;
            }
            ImageErrorCode::Success
        }
        Err(e) => error_to_code(&e),
    }
}

/// Write an image to a JPEG buffer with the specified quality.
/// Caller must free the buffer using pixer_free_buffer.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_write_to_with_quality(
    handle: *const ImageHandle,
    format: ImageFormatEnum,
    quality: u8,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> ImageErrorCode {
    if handle.is_null() || out_data.is_null() || out_len.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    if !matches!(format, ImageFormatEnum::Jpeg) || !(1..=100).contains(&quality) {
        return ImageErrorCode::InvalidParameter;
    }

    let img = unsafe { &*(handle as *const DynamicImage) };

    match write_to_jpeg_with_quality(img, quality) {
        Ok(buffer) => {
            let mut boxed = buffer.into_boxed_slice();
            let len = boxed.len();
            let ptr = boxed.as_mut_ptr();
            std::mem::forget(boxed);

            unsafe {
                *out_data = ptr;
                *out_len = len;
            }
            ImageErrorCode::Success
        }
        Err(e) => error_to_code(&e),
    }
}

// ============================================================================
// Image Information
// ============================================================================

/// Get image metadata
#[unsafe(no_mangle)]
pub extern "C" fn pixer_get_metadata(
    handle: *const ImageHandle,
    out_metadata: *mut ImageMetadata,
) -> ImageErrorCode {
    if handle.is_null() || out_metadata.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let metadata = get_metadata(img);

    unsafe {
        *out_metadata = metadata;
    }

    ImageErrorCode::Success
}

// ============================================================================
// Image Transformations
// ============================================================================

/// Resize an image
#[unsafe(no_mangle)]
pub extern "C" fn pixer_resize(
    handle: *const ImageHandle,
    width: u32,
    height: u32,
    filter: FilterTypeEnum,
) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let resized = resize(img, width, height, filter.to_filter_type());

    Box::into_raw(Box::new(resized)) as *mut ImageHandle
}

/// Resize an image to exact dimensions
#[unsafe(no_mangle)]
pub extern "C" fn pixer_resize_exact(
    handle: *const ImageHandle,
    width: u32,
    height: u32,
    filter: FilterTypeEnum,
) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let resized = resize_exact(img, width, height, filter.to_filter_type());

    Box::into_raw(Box::new(resized)) as *mut ImageHandle
}

/// Crop an image (immutable)
#[unsafe(no_mangle)]
pub extern "C" fn pixer_crop_imm(
    handle: *const ImageHandle,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let cropped = crop_imm(img, x, y, width, height);

    Box::into_raw(Box::new(cropped)) as *mut ImageHandle
}

/// Rotate an image 90 degrees clockwise
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate90(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let rotated = rotate90(img);

    Box::into_raw(Box::new(rotated)) as *mut ImageHandle
}

/// Rotate an image 180 degrees
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate180(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let rotated = rotate180(img);

    Box::into_raw(Box::new(rotated)) as *mut ImageHandle
}

/// Rotate an image 270 degrees clockwise
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate270(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let rotated = rotate270(img);

    Box::into_raw(Box::new(rotated)) as *mut ImageHandle
}

/// Flip an image horizontally
#[unsafe(no_mangle)]
pub extern "C" fn pixer_fliph(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let flipped = fliph(img);

    Box::into_raw(Box::new(flipped)) as *mut ImageHandle
}

/// Flip an image vertically
#[unsafe(no_mangle)]
pub extern "C" fn pixer_flipv(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let flipped = flipv(img);

    Box::into_raw(Box::new(flipped)) as *mut ImageHandle
}

// ============================================================================
// Image Filters & Adjustments
// ============================================================================

/// Blur an image
#[unsafe(no_mangle)]
pub extern "C" fn pixer_blur(handle: *const ImageHandle, sigma: f32) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let blurred = blur(img, sigma);

    Box::into_raw(Box::new(blurred)) as *mut ImageHandle
}

/// Brighten the pixels of an image
#[unsafe(no_mangle)]
pub extern "C" fn pixer_brighten(handle: *const ImageHandle, value: i32) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let adjusted = brighten(img, value);

    Box::into_raw(Box::new(adjusted)) as *mut ImageHandle
}

/// Adjust contrast
#[unsafe(no_mangle)]
pub extern "C" fn pixer_adjust_contrast(handle: *const ImageHandle, c: f32) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let adjusted = adjust_contrast(img, c);

    Box::into_raw(Box::new(adjusted)) as *mut ImageHandle
}

/// Convert to grayscale
#[unsafe(no_mangle)]
pub extern "C" fn pixer_grayscale(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let gray = grayscale(img);

    Box::into_raw(Box::new(gray)) as *mut ImageHandle
}

/// Invert colors (returns new image)
#[unsafe(no_mangle)]
pub extern "C" fn pixer_invert(handle: *const ImageHandle) -> *mut ImageHandle {
    if handle.is_null() {
        return std::ptr::null_mut();
    }

    let img = unsafe { &*(handle as *const DynamicImage) };
    let inverted = invert(img);

    Box::into_raw(Box::new(inverted)) as *mut ImageHandle
}
