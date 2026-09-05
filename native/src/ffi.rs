use image::{
    DynamicImage, ImageError, ImageFormat, codecs::jpeg::JpegEncoder, imageops::FilterType,
};
use std::{
    borrow::Cow,
    ffi::{CStr, CString},
    os::raw::c_char,
    path::Path,
    slice,
};

#[cfg(target_arch = "wasm32")]
use std::alloc::{Layout, alloc, dealloc};

/// Error code returned through `out_error` pointers and as the result of
/// operations that don't return a handle.
#[allow(dead_code)]
#[repr(u32)]
pub enum ImageErrorCode {
    /// The operation succeeded.
    Success = 0,
    /// The provided path is empty, malformed, or refers to a non-existent file.
    InvalidPath = 1,
    /// The image format is not recognised or not supported by this build.
    UnsupportedFormat = 2,
    /// The image bytes are corrupt or do not match the expected format.
    DecodingError = 3,
    /// Encoding the image to the requested format failed.
    EncodingError = 4,
    /// An underlying I/O operation (read/write) failed.
    IoError = 5,
    /// Width, height, or crop bounds are zero or exceed the image.
    InvalidDimensions = 6,
    /// A handle or output pointer was null, or the image has been freed.
    InvalidPointer = 7,
    /// A scalar parameter (e.g. JPEG quality, blur sigma) is out of range.
    InvalidParameter = 8,
    /// An unclassified error occurred.
    Unknown = 99,
}

/// Image container format used for both decoding and encoding.
#[allow(dead_code)]
#[repr(u32)]
pub enum ImageFormatEnum {
    /// Portable Network Graphics — lossless, alpha supported.
    Png = 0,
    /// JPEG — lossy, no alpha. Quality is configurable on encode.
    Jpeg = 1,
    /// Graphics Interchange Format — palette-based, supports animation
    /// (single-frame only via this API).
    Gif = 2,
    /// WebP — lossy or lossless, alpha supported.
    WebP = 3,
    /// Windows Bitmap — uncompressed, large files.
    Bmp = 4,
    /// Windows Icon — multi-resolution container.
    Ico = 5,
    /// Tagged Image File Format — typically lossless.
    Tiff = 6,
}

impl ImageFormatEnum {
    fn into_image_format(self) -> ImageFormat {
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

/// Sampling filter used when resizing.
///
/// Quality and cost roughly increase from top to bottom; `Lanczos3` is the
/// default and produces the sharpest results, `Nearest` is the fastest.
#[allow(dead_code)]
#[repr(u32)]
pub enum FilterTypeEnum {
    /// Nearest-neighbour. Fastest, blocky output. Good for pixel art.
    Nearest = 0,
    /// Linear (a.k.a. bilinear). Cheap, slightly blurry.
    Triangle = 1,
    /// Catmull-Rom cubic. Sharper than `Triangle`, can ring on edges.
    CatmullRom = 2,
    /// Gaussian. Soft output, useful for downscaling without aliasing.
    Gaussian = 3,
    /// Lanczos with `a = 3`. Highest quality, slowest. Default.
    Lanczos3 = 4,
}

impl FilterTypeEnum {
    fn into_filter_type(self) -> FilterType {
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

/// One operation in a batch. Arguments are interpreted according to `kind`.
#[repr(C)]
pub struct PixerOperation {
    pub kind: u32,
    pub arg0: i64,
    pub arg1: i64,
    pub arg2: i64,
    pub arg3: i64,
    pub scalar: f64,
}

/// Stable operation identifiers shared by the native and Dart batch APIs.
#[derive(Clone, Copy)]
#[repr(u32)]
pub enum PixerOperationKind {
    Resize = 0,
    ResizeExact = 1,
    Crop = 2,
    Rotate90 = 3,
    Rotate180 = 4,
    Rotate270 = 5,
    FlipHorizontal = 6,
    FlipVertical = 7,
    Blur = 8,
    Brightness = 9,
    Contrast = 10,
    Grayscale = 11,
    Invert = 12,
}

impl TryFrom<u32> for PixerOperationKind {
    type Error = ImageErrorCode;

    fn try_from(value: u32) -> Result<Self, Self::Error> {
        match value {
            value if value == Self::Resize as u32 => Ok(Self::Resize),
            value if value == Self::ResizeExact as u32 => Ok(Self::ResizeExact),
            value if value == Self::Crop as u32 => Ok(Self::Crop),
            value if value == Self::Rotate90 as u32 => Ok(Self::Rotate90),
            value if value == Self::Rotate180 as u32 => Ok(Self::Rotate180),
            value if value == Self::Rotate270 as u32 => Ok(Self::Rotate270),
            value if value == Self::FlipHorizontal as u32 => Ok(Self::FlipHorizontal),
            value if value == Self::FlipVertical as u32 => Ok(Self::FlipVertical),
            value if value == Self::Blur as u32 => Ok(Self::Blur),
            value if value == Self::Brightness as u32 => Ok(Self::Brightness),
            value if value == Self::Contrast as u32 => Ok(Self::Contrast),
            value if value == Self::Grayscale as u32 => Ok(Self::Grayscale),
            value if value == Self::Invert as u32 => Ok(Self::Invert),
            _ => Err(ImageErrorCode::InvalidParameter),
        }
    }
}

struct BatchError {
    index: usize,
    code: ImageErrorCode,
}

fn with_image<R>(handle: *const ImageHandle, f: impl FnOnce(&DynamicImage) -> R) -> Option<R> {
    if handle.is_null() {
        None
    } else {
        let img = unsafe { &*(handle as *const DynamicImage) };
        Some(f(img))
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

fn encode_image(
    image: &DynamicImage,
    format: ImageFormatEnum,
    jpeg_quality: u8,
) -> Result<Vec<u8>, ImageErrorCode> {
    match format {
        ImageFormatEnum::Jpeg => {
            if !(1..=100).contains(&jpeg_quality) {
                return Err(ImageErrorCode::InvalidParameter);
            }
            write_to_jpeg_with_quality(image, jpeg_quality).map_err(|error| error_to_code(&error))
        }
        format => {
            let mut cursor = std::io::Cursor::new(Vec::new());
            image
                .write_to(&mut cursor, format.into_image_format())
                .map_err(|error| error_to_code(&error))?;
            Ok(cursor.into_inner())
        }
    }
}

fn batch_u32(value: i64, allow_zero: bool) -> Result<u32, ImageErrorCode> {
    let value = u32::try_from(value).map_err(|_| ImageErrorCode::InvalidDimensions)?;
    if !allow_zero && value == 0 {
        return Err(ImageErrorCode::InvalidDimensions);
    }
    Ok(value)
}

fn batch_filter(value: i64) -> Result<FilterType, ImageErrorCode> {
    let filter = match value {
        0 => FilterTypeEnum::Nearest,
        1 => FilterTypeEnum::Triangle,
        2 => FilterTypeEnum::CatmullRom,
        3 => FilterTypeEnum::Gaussian,
        4 => FilterTypeEnum::Lanczos3,
        _ => return Err(ImageErrorCode::InvalidParameter),
    };
    Ok(filter.into_filter_type())
}

fn apply_operation(
    image: &DynamicImage,
    operation: &PixerOperation,
) -> Result<DynamicImage, ImageErrorCode> {
    match PixerOperationKind::try_from(operation.kind)? {
        kind @ (PixerOperationKind::Resize | PixerOperationKind::ResizeExact) => {
            let width = batch_u32(operation.arg0, false)?;
            let height = batch_u32(operation.arg1, false)?;
            let filter = batch_filter(operation.arg2)?;
            if matches!(kind, PixerOperationKind::Resize) {
                Ok(image.resize(width, height, filter))
            } else {
                Ok(image.resize_exact(width, height, filter))
            }
        }
        PixerOperationKind::Crop => {
            let x = batch_u32(operation.arg0, true)?;
            let y = batch_u32(operation.arg1, true)?;
            let width = batch_u32(operation.arg2, false)?;
            let height = batch_u32(operation.arg3, false)?;
            let max_x = x
                .checked_add(width)
                .ok_or(ImageErrorCode::InvalidDimensions)?;
            let max_y = y
                .checked_add(height)
                .ok_or(ImageErrorCode::InvalidDimensions)?;
            if max_x > image.width() || max_y > image.height() {
                return Err(ImageErrorCode::InvalidDimensions);
            }
            Ok(image.crop_imm(x, y, width, height))
        }
        PixerOperationKind::Rotate90 => Ok(image.rotate90()),
        PixerOperationKind::Rotate180 => Ok(image.rotate180()),
        PixerOperationKind::Rotate270 => Ok(image.rotate270()),
        PixerOperationKind::FlipHorizontal => Ok(image.fliph()),
        PixerOperationKind::FlipVertical => Ok(image.flipv()),
        PixerOperationKind::Blur => {
            if !operation.scalar.is_finite()
                || operation.scalar < 0.0
                || operation.scalar > f32::MAX as f64
            {
                return Err(ImageErrorCode::InvalidParameter);
            }
            Ok(image.blur(operation.scalar as f32))
        }
        PixerOperationKind::Brightness => {
            let value =
                i32::try_from(operation.arg0).map_err(|_| ImageErrorCode::InvalidParameter)?;
            Ok(image.brighten(value))
        }
        PixerOperationKind::Contrast => {
            if !operation.scalar.is_finite()
                || operation.scalar < f32::MIN as f64
                || operation.scalar > f32::MAX as f64
            {
                return Err(ImageErrorCode::InvalidParameter);
            }
            Ok(image.adjust_contrast(operation.scalar as f32))
        }
        PixerOperationKind::Grayscale => Ok(DynamicImage::ImageLuma8(image.to_luma8())),
        PixerOperationKind::Invert => {
            let mut image = image.clone();
            image.invert();
            Ok(image)
        }
    }
}

fn operation(kind: PixerOperationKind) -> PixerOperation {
    PixerOperation {
        kind: kind as u32,
        arg0: 0,
        arg1: 0,
        arg2: 0,
        arg3: 0,
        scalar: 0.0,
    }
}

fn apply_single(handle: *const ImageHandle, operation: PixerOperation) -> *mut ImageHandle {
    with_image(handle, |image| {
        apply_operation(image, &operation)
            .map(into_handle)
            .unwrap_or(std::ptr::null_mut())
    })
    .unwrap_or(std::ptr::null_mut())
}

fn apply_operations<'a>(
    source: &'a DynamicImage,
    operations: &[PixerOperation],
) -> Result<Cow<'a, DynamicImage>, BatchError> {
    let mut current = Cow::Borrowed(source);
    for (index, operation) in operations.iter().enumerate() {
        current = Cow::Owned(
            apply_operation(current.as_ref(), operation)
                .map_err(|code| BatchError { index, code })?,
        );
    }
    Ok(current)
}

unsafe fn batch_inputs<'a>(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
) -> Result<(&'a DynamicImage, &'a [PixerOperation]), ImageErrorCode> {
    if handle.is_null() || (operations.is_null() && operation_count != 0) {
        return Err(ImageErrorCode::InvalidPointer);
    }

    let source = unsafe { &*(handle as *const DynamicImage) };
    let operations = if operation_count == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(operations, operation_count) }
    };
    Ok((source, operations))
}

fn set_failed_index(out_failed_index: *mut usize, index: usize) {
    if !out_failed_index.is_null() {
        unsafe {
            *out_failed_index = index;
        }
    }
}

fn batch_error(error: BatchError, out_failed_index: *mut usize) -> ImageErrorCode {
    set_failed_index(out_failed_index, error.index);
    error.code
}

// ============================================================================
// Memory Management
// ============================================================================

/// Allocate aligned linear memory for WebAssembly callers.
#[cfg(target_arch = "wasm32")]
#[unsafe(no_mangle)]
pub extern "C" fn pixer_alloc(size: usize, alignment: usize) -> *mut u8 {
    let Ok(layout) = Layout::from_size_align(size, alignment) else {
        return std::ptr::null_mut();
    };
    unsafe { alloc(layout) }
}

/// Free linear memory allocated by `pixer_alloc`.
#[cfg(target_arch = "wasm32")]
#[unsafe(no_mangle)]
pub extern "C" fn pixer_dealloc(ptr: *mut u8, size: usize, alignment: usize) {
    if ptr.is_null() {
        return;
    }
    if let Ok(layout) = Layout::from_size_align(size, alignment) {
        unsafe { dealloc(ptr, layout) };
    }
}

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

    match image::load_from_memory_with_format(buffer, format.into_image_format()) {
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

    match image::load_from_memory_with_format(buffer, format.into_image_format()) {
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
    if path.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    with_image(handle, |img| {
        match cstr_to_str(path).and_then(|p| img.save(Path::new(&p)).map_err(|e| error_to_code(&e)))
        {
            Ok(_) => ImageErrorCode::Success,
            Err(code) => code,
        }
    })
    .unwrap_or(ImageErrorCode::InvalidPointer)
}

/// Encode an image to a buffer in the specified format.
/// Caller must free the buffer using pixer_free_buffer
#[unsafe(no_mangle)]
pub extern "C" fn pixer_encode(
    handle: *const ImageHandle,
    format: ImageFormatEnum,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> ImageErrorCode {
    if out_data.is_null() || out_len.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    with_image(handle, |img| {
        let result = {
            let mut cursor = std::io::Cursor::new(Vec::new());
            img.write_to(&mut cursor, format.into_image_format())
                .map(|_| cursor.into_inner())
        };
        match result {
            Ok(buffer) => {
                buffer_output(buffer, out_data, out_len);
                ImageErrorCode::Success
            }
            Err(e) => error_to_code(&e),
        }
    })
    .unwrap_or(ImageErrorCode::InvalidPointer)
}

/// Encode an image to a JPEG buffer with the specified quality.
///
/// `quality` must be in `1..=100`. Use `pixer_encode` for other formats.
/// Caller must free the buffer using `pixer_free_buffer`.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_encode_jpeg(
    handle: *const ImageHandle,
    quality: u8,
    out_data: *mut *mut u8,
    out_len: *mut usize,
) -> ImageErrorCode {
    if out_data.is_null() || out_len.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    if !(1..=100).contains(&quality) {
        return ImageErrorCode::InvalidParameter;
    }

    with_image(handle, |img| {
        match write_to_jpeg_with_quality(img, quality) {
            Ok(buffer) => {
                buffer_output(buffer, out_data, out_len);
                ImageErrorCode::Success
            }
            Err(e) => error_to_code(&e),
        }
    })
    .unwrap_or(ImageErrorCode::InvalidPointer)
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
    if out_metadata.is_null() {
        return ImageErrorCode::InvalidPointer;
    }

    let Some(metadata) = with_image(handle, get_metadata) else {
        return ImageErrorCode::InvalidPointer;
    };

    unsafe {
        *out_metadata = metadata;
    }
    ImageErrorCode::Success
}

// ============================================================================
// Batch Processing
// ============================================================================

/// Apply a batch and return the final image. The source image is unchanged.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_batch_to_image(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    out_error: *mut ImageErrorCode,
    out_failed_index: *mut usize,
) -> *mut ImageHandle {
    let (source, operations) = match unsafe { batch_inputs(handle, operations, operation_count) } {
        Ok(inputs) => inputs,
        Err(code) => {
            set_error(out_error, code);
            set_failed_index(out_failed_index, operation_count);
            return std::ptr::null_mut();
        }
    };

    match apply_operations(source, operations) {
        Ok(Cow::Owned(image)) => {
            set_error(out_error, ImageErrorCode::Success);
            set_failed_index(out_failed_index, operation_count);
            into_handle(image)
        }
        Ok(Cow::Borrowed(image)) => {
            set_error(out_error, ImageErrorCode::Success);
            set_failed_index(out_failed_index, operation_count);
            into_handle(image.clone())
        }
        Err(error) => {
            set_error(out_error, batch_error(error, out_failed_index));
            std::ptr::null_mut()
        }
    }
}

/// Apply a batch and encode the final image to a buffer.
/// Caller must free the buffer using `pixer_free_buffer`.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_batch_encode(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    format: ImageFormatEnum,
    jpeg_quality: u8,
    out_data: *mut *mut u8,
    out_len: *mut usize,
    out_failed_index: *mut usize,
) -> ImageErrorCode {
    if out_data.is_null() || out_len.is_null() {
        set_failed_index(out_failed_index, operation_count);
        return ImageErrorCode::InvalidPointer;
    }

    let (source, operations) = match unsafe { batch_inputs(handle, operations, operation_count) } {
        Ok(inputs) => inputs,
        Err(code) => {
            set_failed_index(out_failed_index, operation_count);
            return code;
        }
    };
    let image = match apply_operations(source, operations) {
        Ok(image) => image,
        Err(error) => return batch_error(error, out_failed_index),
    };

    match encode_image(image.as_ref(), format, jpeg_quality) {
        Ok(buffer) => {
            buffer_output(buffer, out_data, out_len);
            set_failed_index(out_failed_index, operation_count);
            ImageErrorCode::Success
        }
        Err(code) => {
            set_failed_index(out_failed_index, operation_count);
            code
        }
    }
}

/// Apply a batch and save the final image to a file.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_batch_save(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    path: *const c_char,
    out_failed_index: *mut usize,
) -> ImageErrorCode {
    if path.is_null() {
        set_failed_index(out_failed_index, operation_count);
        return ImageErrorCode::InvalidPointer;
    }

    let (source, operations) = match unsafe { batch_inputs(handle, operations, operation_count) } {
        Ok(inputs) => inputs,
        Err(code) => {
            set_failed_index(out_failed_index, operation_count);
            return code;
        }
    };
    let image = match apply_operations(source, operations) {
        Ok(image) => image,
        Err(error) => return batch_error(error, out_failed_index),
    };
    let path = match cstr_to_str(path) {
        Ok(path) => path,
        Err(code) => {
            set_failed_index(out_failed_index, operation_count);
            return code;
        }
    };

    match image.save(Path::new(&path)) {
        Ok(()) => {
            set_failed_index(out_failed_index, operation_count);
            ImageErrorCode::Success
        }
        Err(error) => {
            set_failed_index(out_failed_index, operation_count);
            error_to_code(&error)
        }
    }
}

// ============================================================================
// Image Transformations
// ============================================================================

/// Resize the image to fit *within* `width` x `height` while preserving
/// aspect ratio.
///
/// The result is at most `width` x `height`; the smaller dimension is scaled
/// proportionally so the image is never distorted. Use `pixer_resize_exact`
/// to force exact dimensions.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_resize(
    handle: *const ImageHandle,
    width: u32,
    height: u32,
    filter: FilterTypeEnum,
) -> *mut ImageHandle {
    apply_single(
        handle,
        PixerOperation {
            arg0: i64::from(width),
            arg1: i64::from(height),
            arg2: filter as u32 as i64,
            ..operation(PixerOperationKind::Resize)
        },
    )
}

/// Resize the image to exactly `width` x `height`, ignoring aspect ratio.
///
/// May visibly stretch or squash the image.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_resize_exact(
    handle: *const ImageHandle,
    width: u32,
    height: u32,
    filter: FilterTypeEnum,
) -> *mut ImageHandle {
    apply_single(
        handle,
        PixerOperation {
            arg0: i64::from(width),
            arg1: i64::from(height),
            arg2: filter as u32 as i64,
            ..operation(PixerOperationKind::ResizeExact)
        },
    )
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
    apply_single(
        handle,
        PixerOperation {
            arg0: i64::from(x),
            arg1: i64::from(y),
            arg2: i64::from(width),
            arg3: i64::from(height),
            ..operation(PixerOperationKind::Crop)
        },
    )
}

/// Rotate an image 90 degrees clockwise
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate90(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::Rotate90))
}

/// Rotate an image 180 degrees
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate180(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::Rotate180))
}

/// Rotate an image 270 degrees clockwise
#[unsafe(no_mangle)]
pub extern "C" fn pixer_rotate270(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::Rotate270))
}

/// Flip an image horizontally
#[unsafe(no_mangle)]
pub extern "C" fn pixer_fliph(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::FlipHorizontal))
}

/// Flip an image vertically
#[unsafe(no_mangle)]
pub extern "C" fn pixer_flipv(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::FlipVertical))
}

// ============================================================================
// Image Filters & Adjustments
// ============================================================================

/// Apply a Gaussian blur with the given standard deviation in pixels.
///
/// `sigma` must be finite and `>= 0`. `sigma == 0` returns an unchanged copy.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_blur(handle: *const ImageHandle, sigma: f32) -> *mut ImageHandle {
    apply_single(
        handle,
        PixerOperation {
            scalar: f64::from(sigma),
            ..operation(PixerOperationKind::Blur)
        },
    )
}

/// Add `value` to every channel of every pixel.
///
/// Values are clamped per-channel to `[0, 255]`. Negative values darken,
/// positive values brighten. The practical range is roughly `-255..=255`;
/// larger magnitudes simply saturate.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_brighten(handle: *const ImageHandle, value: i32) -> *mut ImageHandle {
    apply_single(
        handle,
        PixerOperation {
            arg0: i64::from(value),
            ..operation(PixerOperationKind::Brightness)
        },
    )
}

/// Adjust contrast around the midpoint.
///
/// `c == 0.0` leaves the image unchanged. Positive values increase contrast,
/// negative values decrease it. `c` must be finite.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_adjust_contrast(handle: *const ImageHandle, c: f32) -> *mut ImageHandle {
    apply_single(
        handle,
        PixerOperation {
            scalar: f64::from(c),
            ..operation(PixerOperationKind::Contrast)
        },
    )
}

/// Convert to grayscale
#[unsafe(no_mangle)]
pub extern "C" fn pixer_grayscale(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::Grayscale))
}

/// Invert colors (returns new image)
#[unsafe(no_mangle)]
pub extern "C" fn pixer_invert(handle: *const ImageHandle) -> *mut ImageHandle {
    apply_single(handle, operation(PixerOperationKind::Invert))
}
