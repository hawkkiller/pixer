use image::{
    DynamicImage, ImageError, ImageFormat, codecs::jpeg::JpegEncoder, imageops::FilterType,
};
use std::{
    ffi::{CStr, CString},
    os::raw::c_char,
    path::Path,
    slice,
};

#[allow(dead_code)]
#[repr(u32)]
pub enum ImageErrorCode {
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
}

#[allow(dead_code)]
#[repr(u32)]
pub enum ImageFormatEnum {
    Png = 0,
    Jpeg = 1,
    Gif = 2,
    WebP = 3,
    Bmp = 4,
    Ico = 5,
    Tiff = 6,
}

impl ImageFormatEnum {
    fn to_image_format(self) -> ImageFormat {
        match self {
            Self::Png => ImageFormat::Png,
            Self::Jpeg => ImageFormat::Jpeg,
            Self::Gif => ImageFormat::Gif,
            Self::WebP => ImageFormat::WebP,
            Self::Bmp => ImageFormat::Bmp,
            Self::Ico => ImageFormat::Ico,
            Self::Tiff => ImageFormat::Tiff,
        }
    }
}

#[allow(dead_code)]
#[repr(u32)]
pub enum FilterTypeEnum {
    Nearest = 0,
    Triangle = 1,
    CatmullRom = 2,
    Gaussian = 3,
    Lanczos3 = 4,
}

impl FilterTypeEnum {
    fn to_filter_type(self) -> FilterType {
        match self {
            Self::Nearest => FilterType::Nearest,
            Self::Triangle => FilterType::Triangle,
            Self::CatmullRom => FilterType::CatmullRom,
            Self::Gaussian => FilterType::Gaussian,
            Self::Lanczos3 => FilterType::Lanczos3,
        }
    }
}

#[repr(C)]
pub struct ImageHandle {
    _private: [u8; 0],
}

#[repr(C)]
pub struct ImageMetadata {
    pub width: u32,
    pub height: u32,
    pub color_type: u8,
}

fn handle_cast(handle: *const ImageHandle) -> Option<&'static DynamicImage> {
    if handle.is_null() {
        None
    } else {
        Some(unsafe { &*(handle as *const DynamicImage) })
    }
}

fn into_handle(img: DynamicImage) -> *mut ImageHandle {
    Box::into_raw(Box::new(img)) as *mut ImageHandle
}

fn set_error(out_error: *mut ImageErrorCode, error: ImageErrorCode) {
    if !out_error.is_null() {
        unsafe {
            *out_error = error;
        }
    }
}

fn cstr_to_str(ptr: *const c_char) -> Result<String, ImageErrorCode> {
    if ptr.is_null() {
        return Err(ImageErrorCode::InvalidPointer);
    }
    unsafe {
        CStr::from_ptr(ptr)
            .to_str()
            .map(|s| s.to_owned())
            .map_err(|_| ImageErrorCode::InvalidPath)
    }
}

fn buffer_output(buffer: Vec<u8>, out_data: *mut *mut u8, out_len: *mut usize) {
    let mut boxed = buffer.into_boxed_slice();
    unsafe {
        *out_len = boxed.len();
        *out_data = boxed.as_mut_ptr();
    }
    std::mem::forget(boxed);
}

fn error_to_code(err: &ImageError) -> ImageErrorCode {
    match err {
        ImageError::Decoding(_) => ImageErrorCode::DecodingError,
        ImageError::Encoding(_) => ImageErrorCode::EncodingError,
        ImageError::IoError(_) => ImageErrorCode::IoError,
        ImageError::Limits(_) => ImageErrorCode::InvalidDimensions,
        ImageError::Unsupported(_) => ImageErrorCode::UnsupportedFormat,
        ImageError::Parameter(_) => ImageErrorCode::InvalidParameter,
    }
}

fn get_metadata(img: &DynamicImage) -> ImageMetadata {
    let color_type = match img.color() {
        image::ColorType::L8 | image::ColorType::L16 => 0,
        image::ColorType::La8 | image::ColorType::La16 => 1,
        image::ColorType::Rgb8 | image::ColorType::Rgb16 | image::ColorType::Rgb32F => 2,
        image::ColorType::Rgba8 | image::ColorType::Rgba16 | image::ColorType::Rgba32F => 3,
        _ => 3,
    };
    ImageMetadata {
        width: img.width(),
        height: img.height(),
        color_type,
    }
}

fn write_to_jpeg_with_quality(img: &DynamicImage, quality: u8) -> Result<Vec<u8>, ImageError> {
    let mut buffer = Vec::new();
    img.write_with_encoder(JpegEncoder::new_with_quality(&mut buffer, quality))?;
    Ok(buffer)
}

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

    match cstr_to_str(path)
        .and_then(|p| image::open(Path::new(&p)).map_err(|_| ImageErrorCode::InvalidPath))
    {
        Ok(img) => into_handle(img),
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
    match image::load_from_memory(buffer) {
        Ok(img) => into_handle(img),
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

    match image::load_from_memory_with_format(buffer, format.to_image_format()) {
        Ok(img) => into_handle(img),
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
        set_error(out_error, ImageErrorCode::InvalidPointer);
        return std::ptr::null_mut();
    }

    match cstr_to_str(path).and_then(|p| image::open(Path::new(&p)).map_err(|e| error_to_code(&e)))
    {
        Ok(img) => {
            set_error(out_error, ImageErrorCode::Success);
            into_handle(img)
        }
        Err(code) => {
            set_error(out_error, code);
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
        set_error(out_error, ImageErrorCode::InvalidPointer);
        return std::ptr::null_mut();
    }

    let buffer = unsafe { slice::from_raw_parts(data, len) };

    match image::load_from_memory(buffer) {
        Ok(img) => {
            set_error(out_error, ImageErrorCode::Success);
            into_handle(img)
        }
        Err(e) => {
            set_error(out_error, error_to_code(&e));
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
        set_error(out_error, ImageErrorCode::InvalidPointer);
        return std::ptr::null_mut();
    }

    let buffer = unsafe { slice::from_raw_parts(data, len) };

    match image::load_from_memory_with_format(buffer, format.to_image_format()) {
        Ok(img) => {
            set_error(out_error, ImageErrorCode::Success);
            into_handle(img)
        }
        Err(e) => {
            set_error(out_error, error_to_code(&e));
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
    let Some(img) = handle_cast(handle) else {
        return ImageErrorCode::InvalidPointer;
    };
    if path.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    match cstr_to_str(path).and_then(|p| img.save(Path::new(&p)).map_err(|e| error_to_code(&e))) {
        Ok(_) => ImageErrorCode::Success,
        Err(code) => code,
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
    let Some(img) = handle_cast(handle) else {
        return ImageErrorCode::InvalidPointer;
    };
    if out_data.is_null() || out_len.is_null() {
        return ImageErrorCode::InvalidPointer;
    }
    match {
        let mut cursor = std::io::Cursor::new(Vec::new());
        img.write_to(&mut cursor, format.to_image_format())
            .map(|_| cursor.into_inner())
    } {
        Ok(buffer) => {
            buffer_output(buffer, out_data, out_len);
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
    let Some(img) = handle_cast(handle) else {
        return ImageErrorCode::InvalidPointer;
    };
    if out_data.is_null() || out_len.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    if !matches!(format, ImageFormatEnum::Jpeg) || !(1..=100).contains(&quality) {
        return ImageErrorCode::InvalidParameter;
    }

    match write_to_jpeg_with_quality(img, quality) {
        Ok(buffer) => {
            buffer_output(buffer, out_data, out_len);
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
    let Some(img) = handle_cast(handle) else {
        return ImageErrorCode::InvalidPointer;
    };
    if out_metadata.is_null() {
        return ImageErrorCode::InvalidPointer;
    }
    unsafe {
        *out_metadata = get_metadata(img);
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
    handle_cast(handle)
        .map(|img| into_handle(img.resize(width, height, filter.to_filter_type())))
        .unwrap_or(std::ptr::null_mut())
}

/// Resize an image to exact dimensions
#[unsafe(no_mangle)]
pub extern "C" fn pixer_resize_exact(
    handle: *const ImageHandle,
    width: u32,
    height: u32,
    filter: FilterTypeEnum,
) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.resize_exact(width, height, filter.to_filter_type())))
        .unwrap_or(std::ptr::null_mut())
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
    handle_cast(handle)
        .map(|img| into_handle(img.crop_imm(x, y, width, height)))
        .unwrap_or(std::ptr::null_mut())
}

/// Rotate an image 90 degrees clockwise
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate90(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.rotate90()))
        .unwrap_or(std::ptr::null_mut())
}

/// Rotate an image 180 degrees
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate180(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.rotate180()))
        .unwrap_or(std::ptr::null_mut())
}

/// Rotate an image 270 degrees clockwise
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate270(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.rotate270()))
        .unwrap_or(std::ptr::null_mut())
}

/// Flip an image horizontally
#[unsafe(no_mangle)]
pub extern "C" fn pixer_fliph(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.fliph()))
        .unwrap_or(std::ptr::null_mut())
}

/// Flip an image vertically
#[unsafe(no_mangle)]
pub extern "C" fn pixer_flipv(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.flipv()))
        .unwrap_or(std::ptr::null_mut())
}

// ============================================================================
// Image Filters & Adjustments
// ============================================================================

/// Blur an image
#[unsafe(no_mangle)]
pub extern "C" fn pixer_blur(handle: *const ImageHandle, sigma: f32) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.blur(sigma)))
        .unwrap_or(std::ptr::null_mut())
}

/// Brighten the pixels of an image
#[unsafe(no_mangle)]
pub extern "C" fn pixer_brighten(handle: *const ImageHandle, value: i32) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.brighten(value)))
        .unwrap_or(std::ptr::null_mut())
}

/// Adjust contrast
#[unsafe(no_mangle)]
pub extern "C" fn pixer_adjust_contrast(handle: *const ImageHandle, c: f32) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(img.adjust_contrast(c)))
        .unwrap_or(std::ptr::null_mut())
}

/// Convert to grayscale
#[unsafe(no_mangle)]
pub extern "C" fn pixer_grayscale(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| into_handle(DynamicImage::ImageLuma8(img.to_luma8())))
        .unwrap_or(std::ptr::null_mut())
}

/// Invert colors (returns new image)
#[unsafe(no_mangle)]
pub extern "C" fn pixer_invert(handle: *const ImageHandle) -> *mut ImageHandle {
    handle_cast(handle)
        .map(|img| {
            let mut cloned = img.clone();
            cloned.invert();
            into_handle(cloned)
        })
        .unwrap_or(std::ptr::null_mut())
}
