use fast_image_resize as fir;
use image::{
    DynamicImage, ImageBuffer, ImageDecoder, ImageError, ImageFormat, ImageReader, Limits, Pixel,
    imageops::FilterType, metadata::Orientation,
};
use std::{
    borrow::Cow,
    ffi::CStr,
    io::{BufRead, Cursor, Seek},
    os::raw::c_char,
    path::Path,
    slice,
};

#[cfg(target_arch = "wasm32")]
use std::alloc::{Layout, alloc, dealloc};

/// Result of every fallible Pixer function; outputs are written through
/// out-parameters only on `Success`.
#[derive(Debug)]
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
    #[allow(dead_code)] // Dart's fallback for unrecognised codes.
    Unknown = 99,
}

/// Image container format used for both decoding and encoding.
#[derive(Clone, Copy)]
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

impl TryFrom<u32> for ImageFormatEnum {
    type Error = ImageErrorCode;

    fn try_from(value: u32) -> Result<Self, Self::Error> {
        [
            Self::Png,
            Self::Jpeg,
            Self::Gif,
            Self::WebP,
            Self::Bmp,
            Self::Ico,
            Self::Tiff,
        ]
        .into_iter()
        .find(|format| *format as u32 == value)
        .ok_or(ImageErrorCode::InvalidParameter)
    }
}

/// Pass as the `format` of `pixer_load_from_memory` to detect it from the bytes.
pub const PIXER_FORMAT_DETECT: u32 = 0xFFFF_FFFF;

/// Sampling filter used when resizing.
///
/// Quality and cost roughly increase from top to bottom; `Lanczos3` is the
/// default and produces the sharpest results, `Nearest` is the fastest.
#[derive(Clone, Copy)]
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

    fn into_resize_alg(self) -> fir::ResizeAlg {
        use fir::FilterType as F;
        match self {
            Self::Nearest => fir::ResizeAlg::Nearest,
            Self::Triangle => fir::ResizeAlg::Convolution(F::Bilinear),
            Self::CatmullRom => fir::ResizeAlg::Convolution(F::CatmullRom),
            Self::Gaussian => fir::ResizeAlg::Convolution(F::Gaussian),
            Self::Lanczos3 => fir::ResizeAlg::Convolution(F::Lanczos3),
        }
    }
}

impl TryFrom<i64> for FilterTypeEnum {
    type Error = ImageErrorCode;

    fn try_from(value: i64) -> Result<Self, Self::Error> {
        [
            Self::Nearest,
            Self::Triangle,
            Self::CatmullRom,
            Self::Gaussian,
            Self::Lanczos3,
        ]
        .into_iter()
        .find(|filter| *filter as i64 == value)
        .ok_or(ImageErrorCode::InvalidParameter)
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

// Keep the handwritten wasm32 memory accessors in wasm_runtime.dart in sync.
#[cfg(target_arch = "wasm32")]
const _: () = {
    use std::mem::{align_of, offset_of, size_of};
    assert!(size_of::<usize>() == 4);
    assert!(size_of::<ImageMetadata>() == 12);
    assert!(offset_of!(ImageMetadata, width) == 0);
    assert!(offset_of!(ImageMetadata, height) == 4);
    assert!(offset_of!(ImageMetadata, color_type) == 8);
    assert!(size_of::<PixerOperation>() == 48);
    assert!(align_of::<PixerOperation>() == 8);
    assert!(offset_of!(PixerOperation, kind) == 0);
    assert!(offset_of!(PixerOperation, arg0) == 8);
    assert!(offset_of!(PixerOperation, arg1) == 16);
    assert!(offset_of!(PixerOperation, arg2) == 24);
    assert!(offset_of!(PixerOperation, arg3) == 32);
    assert!(offset_of!(PixerOperation, scalar) == 40);
};

/// Stable operation identifiers shared by the native and Dart batch APIs.
///
/// Each variant documents how it reads the `PixerOperation` slots; unused
/// slots are ignored.
#[derive(Clone, Copy)]
#[repr(u32)]
pub enum PixerOperationKind {
    /// Fit within `arg0` x `arg1`, preserving aspect ratio. `arg2`: `FilterTypeEnum`.
    Resize = 0,
    /// Resize to exactly `arg0` x `arg1`. `arg2`: `FilterTypeEnum`.
    ResizeExact = 1,
    /// `arg0`, `arg1`: origin; `arg2`, `arg3`: width and height.
    Crop = 2,
    Rotate90 = 3,
    Rotate180 = 4,
    Rotate270 = 5,
    FlipHorizontal = 6,
    FlipVertical = 7,
    /// Gaussian blur, `scalar`: sigma (zero or a positive normal f32).
    Blur = 8,
    /// `arg0`: i32 offset added to color channels, preserving alpha.
    Brightness = 9,
    /// `scalar`: finite f32 contrast around the midpoint; 0 is neutral.
    Contrast = 10,
    Grayscale = 11,
    Invert = 12,
}

impl TryFrom<u32> for PixerOperationKind {
    type Error = ImageErrorCode;

    fn try_from(value: u32) -> Result<Self, Self::Error> {
        [
            Self::Resize,
            Self::ResizeExact,
            Self::Crop,
            Self::Rotate90,
            Self::Rotate180,
            Self::Rotate270,
            Self::FlipHorizontal,
            Self::FlipVertical,
            Self::Blur,
            Self::Brightness,
            Self::Contrast,
            Self::Grayscale,
            Self::Invert,
        ]
        .into_iter()
        .find(|kind| *kind as u32 == value)
        .ok_or(ImageErrorCode::InvalidParameter)
    }
}

/// A batch operation decoded from its `PixerOperation` slots and validated.
enum Op {
    Resize {
        width: u32,
        height: u32,
        filter: FilterTypeEnum,
        exact: bool,
    },
    Crop {
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    },
    Rotate90,
    Rotate180,
    Rotate270,
    FlipHorizontal,
    FlipVertical,
    Blur(f32),
    Brighten(i32),
    Contrast(f32),
    Grayscale,
    Invert,
}

impl TryFrom<&PixerOperation> for Op {
    type Error = ImageErrorCode;

    fn try_from(op: &PixerOperation) -> Result<Self, Self::Error> {
        Ok(match PixerOperationKind::try_from(op.kind)? {
            kind @ (PixerOperationKind::Resize | PixerOperationKind::ResizeExact) => Op::Resize {
                width: slot_u32(op.arg0, false)?,
                height: slot_u32(op.arg1, false)?,
                filter: FilterTypeEnum::try_from(op.arg2)?,
                exact: matches!(kind, PixerOperationKind::ResizeExact),
            },
            PixerOperationKind::Crop => Op::Crop {
                x: slot_u32(op.arg0, true)?,
                y: slot_u32(op.arg1, true)?,
                width: slot_u32(op.arg2, false)?,
                height: slot_u32(op.arg3, false)?,
            },
            PixerOperationKind::Rotate90 => Op::Rotate90,
            PixerOperationKind::Rotate180 => Op::Rotate180,
            PixerOperationKind::Rotate270 => Op::Rotate270,
            PixerOperationKind::FlipHorizontal => Op::FlipHorizontal,
            PixerOperationKind::FlipVertical => Op::FlipVertical,
            PixerOperationKind::Blur => Op::Blur(blur_sigma(op.scalar)?),
            PixerOperationKind::Brightness => {
                let value = i32::try_from(op.arg0).map_err(|_| ImageErrorCode::InvalidParameter)?;
                // Integer images have at most 16 bits per channel. Larger offsets
                // already saturate; cap them before the dependency's i32 addition.
                Op::Brighten(value.clamp(-65535, 65535))
            }
            PixerOperationKind::Contrast => {
                if !op.scalar.is_finite() || op.scalar.abs() > f32::MAX as f64 {
                    return Err(ImageErrorCode::InvalidParameter);
                }
                Op::Contrast(op.scalar as f32)
            }
            PixerOperationKind::Grayscale => Op::Grayscale,
            PixerOperationKind::Invert => Op::Invert,
        })
    }
}

impl Op {
    fn apply(&self, image: &DynamicImage) -> Result<DynamicImage, ImageErrorCode> {
        Ok(match *self {
            Op::Resize {
                width,
                height,
                filter,
                exact,
            } => {
                if exact {
                    resize_exact(image, width, height, filter)
                } else if (width, height) == (image.width(), image.height()) {
                    image.clone()
                } else {
                    let (width, height) =
                        fit_dimensions(image.width(), image.height(), width, height);
                    resize_exact(image, width, height, filter)
                }
            }
            Op::Crop {
                x,
                y,
                width,
                height,
            } => {
                let fits = x.checked_add(width).is_some_and(|max| max <= image.width())
                    && y.checked_add(height)
                        .is_some_and(|max| max <= image.height());
                if !fits {
                    return Err(ImageErrorCode::InvalidDimensions);
                }
                image.crop_imm(x, y, width, height)
            }
            Op::Rotate90 => image.rotate90(),
            Op::Rotate180 => image.rotate180(),
            Op::Rotate270 => image.rotate270(),
            Op::FlipHorizontal => image.fliph(),
            Op::FlipVertical => image.flipv(),
            Op::Blur(0.0) => image.clone(),
            Op::Blur(sigma) => image.blur(sigma),
            Op::Brighten(value) => image.brighten(value),
            Op::Contrast(c) => image.adjust_contrast(c),
            Op::Grayscale => image.grayscale(),
            Op::Invert => {
                let mut image = image.clone();
                image.invert();
                image
            }
        })
    }
}

impl From<ImageError> for ImageErrorCode {
    fn from(error: ImageError) -> Self {
        match error {
            ImageError::Decoding(_) => Self::DecodingError,
            ImageError::Encoding(_) => Self::EncodingError,
            ImageError::IoError(_) => Self::IoError,
            ImageError::Limits(_) => Self::InvalidDimensions,
            ImageError::Unsupported(_) => Self::UnsupportedFormat,
            ImageError::Parameter(_) => Self::InvalidParameter,
        }
    }
}

fn status(result: Result<(), ImageErrorCode>) -> ImageErrorCode {
    result.err().unwrap_or(ImageErrorCode::Success)
}

fn image_ref<'a>(handle: *const ImageHandle) -> Option<&'a DynamicImage> {
    unsafe { (handle as *const DynamicImage).as_ref() }
}

fn into_handle(img: DynamicImage) -> *mut ImageHandle {
    Box::into_raw(Box::new(img)) as *mut ImageHandle
}

/// Writes through an optional out-pointer.
fn write<T>(ptr: *mut T, value: T) {
    if let Some(slot) = unsafe { ptr.as_mut() } {
        *slot = value;
    }
}

fn c_path<'a>(ptr: *const c_char) -> Result<&'a Path, ImageErrorCode> {
    if ptr.is_null() {
        return Err(ImageErrorCode::InvalidPointer);
    }
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map(Path::new)
        .map_err(|_| ImageErrorCode::InvalidPath)
}

fn get_metadata(img: &DynamicImage) -> ImageMetadata {
    use image::ColorType::*;
    let color_type = match img.color() {
        L8 | L16 => 0,
        La8 | La16 => 1,
        Rgb8 | Rgb16 | Rgb32F => 2,
        _ => 3,
    };
    ImageMetadata {
        width: img.width(),
        height: img.height(),
        color_type,
    }
}

fn encode_image(
    image: &DynamicImage,
    format: ImageFormatEnum,
    jpeg_quality: u8,
) -> Result<Vec<u8>, ImageErrorCode> {
    let mut buffer = Vec::new();
    match format {
        ImageFormatEnum::Jpeg => {
            if !(1..=100).contains(&jpeg_quality) {
                return Err(ImageErrorCode::InvalidParameter);
            }
            #[cfg(feature = "jpeg")]
            image.write_with_encoder(image::codecs::jpeg::JpegEncoder::new_with_quality(
                &mut buffer,
                jpeg_quality,
            ))?;
            #[cfg(not(feature = "jpeg"))]
            return Err(ImageErrorCode::UnsupportedFormat);
        }
        format => image.write_to(
            &mut std::io::Cursor::new(&mut buffer),
            format.into_image_format(),
        )?,
    }
    Ok(buffer)
}

/// Largest size within `max_width` x `max_height` with the source aspect ratio,
/// matching `image::DynamicImage::resize`.
fn fit_dimensions(width: u32, height: u32, max_width: u32, max_height: u32) -> (u32, u32) {
    let ratio = f64::min(
        f64::from(max_width) / f64::from(width),
        f64::from(max_height) / f64::from(height),
    );
    let scale = |side: u32| ((f64::from(side) * ratio).round() as u64).max(1);
    let (new_width, new_height) = (scale(width), scale(height));
    if new_width > u64::from(u32::MAX) {
        let ratio = f64::from(u32::MAX) / f64::from(width);
        (
            u32::MAX,
            ((f64::from(height) * ratio).round() as u32).max(1),
        )
    } else if new_height > u64::from(u32::MAX) {
        let ratio = f64::from(u32::MAX) / f64::from(height);
        (((f64::from(width) * ratio).round() as u32).max(1), u32::MAX)
    } else {
        (new_width as u32, new_height as u32)
    }
}

fn resize_exact(
    image: &DynamicImage,
    width: u32,
    height: u32,
    filter: FilterTypeEnum,
) -> DynamicImage {
    use fir::pixels::{U8, U8x2, U8x3, U8x4};
    let options = fir::ResizeOptions::new().resize_alg(filter.into_resize_alg());
    // Only 8-bit layouts use the SIMD resizer; instantiating it for every
    // layout would add megabytes to the binary for rarely used formats.
    let resized = match image {
        DynamicImage::ImageLuma8(buffer) => {
            resize_buffer::<_, U8>(buffer, width, height, &options).map(DynamicImage::ImageLuma8)
        }
        DynamicImage::ImageLumaA8(buffer) => {
            resize_buffer::<_, U8x2>(buffer, width, height, &options).map(DynamicImage::ImageLumaA8)
        }
        DynamicImage::ImageRgb8(buffer) => {
            resize_buffer::<_, U8x3>(buffer, width, height, &options).map(DynamicImage::ImageRgb8)
        }
        DynamicImage::ImageRgba8(buffer) => {
            resize_buffer::<_, U8x4>(buffer, width, height, &options).map(DynamicImage::ImageRgba8)
        }
        _ => None,
    };
    resized.unwrap_or_else(|| image.resize_exact(width, height, filter.into_filter_type()))
}

fn resize_buffer<Px, P>(
    source: &ImageBuffer<Px, Vec<u8>>,
    width: u32,
    height: u32,
    options: &fir::ResizeOptions,
) -> Option<ImageBuffer<Px, Vec<u8>>>
where
    Px: Pixel<Subpixel = u8>,
    P: fir::PixelTrait,
{
    let source_view =
        fir::images::TypedImageRef::<P>::from_buffer(source.width(), source.height(), source)
            .ok()?;
    let mut resized = ImageBuffer::new(width, height);
    let mut resized_view =
        fir::images::TypedImage::<P>::from_buffer(width, height, &mut resized).ok()?;
    fir::Resizer::new()
        .resize_typed(&source_view, &mut resized_view, options)
        .ok()?;
    Some(resized)
}

fn slot_u32(value: i64, allow_zero: bool) -> Result<u32, ImageErrorCode> {
    let value = u32::try_from(value).map_err(|_| ImageErrorCode::InvalidDimensions)?;
    if !allow_zero && value == 0 {
        return Err(ImageErrorCode::InvalidDimensions);
    }
    Ok(value)
}

fn blur_sigma(scalar: f64) -> Result<f32, ImageErrorCode> {
    if !scalar.is_finite() || scalar < 0.0 || scalar > f32::MAX as f64 {
        return Err(ImageErrorCode::InvalidParameter);
    }
    if scalar == 0.0 {
        return Ok(0.0);
    }
    // Check after narrowing: tiny f64 values become subnormal or zero f32s,
    // which make the blur kernel panic.
    let sigma = scalar as f32;
    if !sigma.is_normal() {
        return Err(ImageErrorCode::InvalidParameter);
    }
    Ok(sigma)
}

/// Errors carry the index of the failing operation.
fn apply_operations<'a>(
    source: &'a DynamicImage,
    operations: &[PixerOperation],
) -> Result<Cow<'a, DynamicImage>, (usize, ImageErrorCode)> {
    // Decode everything up front so a bad argument fails before any pixel work.
    let ops = operations
        .iter()
        .enumerate()
        .map(|(index, op)| Op::try_from(op).map_err(|code| (index, code)))
        .collect::<Result<Vec<_>, _>>()?;

    let mut current = Cow::Borrowed(source);
    for (index, op) in ops.iter().enumerate() {
        current = Cow::Owned(op.apply(current.as_ref()).map_err(|code| (index, code))?);
    }
    Ok(current)
}

/// Applies a batch and hands the result to the terminal step `finish`.
///
/// `out_failed_index` receives the failing operation's index, or
/// `operation_count` when the terminal step (or argument checking) failed.
fn run_batch(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    out_failed_index: *mut usize,
    finish: impl FnOnce(Cow<'_, DynamicImage>) -> Result<(), ImageErrorCode>,
) -> ImageErrorCode {
    write(out_failed_index, operation_count);
    let Some(source) = image_ref(handle) else {
        return ImageErrorCode::InvalidPointer;
    };
    let operations = match (operations.is_null(), operation_count) {
        (_, 0) => &[][..],
        (true, _) => return ImageErrorCode::InvalidPointer,
        (false, count) => unsafe { slice::from_raw_parts(operations, count) },
    };
    status(
        apply_operations(source, operations)
            .map_err(|(index, code)| {
                write(out_failed_index, index);
                code
            })
            .and_then(finish),
    )
}

/// Decodes under `image`'s default memory limits, then rotates or flips the
/// pixels upright according to the EXIF orientation.
fn decode<R: BufRead + Seek>(reader: ImageReader<R>) -> Result<DynamicImage, ImageErrorCode> {
    let mut decoder = reader.into_decoder()?;
    Limits::default().reserve(decoder.total_bytes())?;
    // Malformed EXIF must not make otherwise valid pixels unreadable.
    let orientation = decoder.orientation().unwrap_or(Orientation::NoTransforms);
    let mut image = DynamicImage::from_decoder(decoder)?;
    image.apply_orientation(orientation);
    Ok(image)
}

fn load(
    out_image: *mut *mut ImageHandle,
    decode: impl FnOnce() -> Result<DynamicImage, ImageErrorCode>,
) -> ImageErrorCode {
    let Some(out) = (unsafe { out_image.as_mut() }) else {
        return ImageErrorCode::InvalidPointer;
    };
    *out = std::ptr::null_mut();
    status(decode().map(|image| *out = into_handle(image)))
}

// ============================================================================
// Memory Management
// ============================================================================

/// ABI contract version. Increment for incompatible signatures, layouts, or IDs.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_abi_version() -> u32 {
    2
}

/// Pixel-buffer byte length for native memory accounting; zero for a null handle.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_image_byte_length(handle: *const ImageHandle) -> usize {
    image_ref(handle).map_or(0, |image| image.as_bytes().len())
}

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

/// Free a buffer returned by `pixer_batch_encode`.
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
// Loading & Information
// ============================================================================

/// Load an image from a file path into `out_image`, applying its EXIF orientation.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load(
    path: *const c_char,
    out_image: *mut *mut ImageHandle,
) -> ImageErrorCode {
    load(out_image, || {
        decode(ImageReader::open(c_path(path)?).map_err(|_| ImageErrorCode::IoError)?)
    })
}

/// Load an image from memory into `out_image`, applying its EXIF orientation.
///
/// `format` is an `ImageFormatEnum` value, or `PIXER_FORMAT_DETECT`.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_load_from_memory(
    data: *const u8,
    len: usize,
    format: u32,
    out_image: *mut *mut ImageHandle,
) -> ImageErrorCode {
    load(out_image, || {
        if data.is_null() || len == 0 {
            return Err(ImageErrorCode::InvalidPointer);
        }
        let bytes = Cursor::new(unsafe { slice::from_raw_parts(data, len) });
        decode(if format == PIXER_FORMAT_DETECT {
            ImageReader::new(bytes)
                .with_guessed_format()
                .map_err(|_| ImageErrorCode::IoError)?
        } else {
            ImageReader::with_format(
                bytes,
                ImageFormatEnum::try_from(format)?.into_image_format(),
            )
        })
    })
}

/// Get image metadata
#[unsafe(no_mangle)]
pub extern "C" fn pixer_get_metadata(
    handle: *const ImageHandle,
    out_metadata: *mut ImageMetadata,
) -> ImageErrorCode {
    let Some(out) = (unsafe { out_metadata.as_mut() }) else {
        return ImageErrorCode::InvalidPointer;
    };
    let Some(image) = image_ref(handle) else {
        return ImageErrorCode::InvalidPointer;
    };
    *out = get_metadata(image);
    ImageErrorCode::Success
}

// ============================================================================
// Batch Processing
// ============================================================================

/// Apply a batch and write the final image to `out_image`. The source image
/// is unchanged.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_batch_to_image(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    out_image: *mut *mut ImageHandle,
    out_failed_index: *mut usize,
) -> ImageErrorCode {
    write(out_image, std::ptr::null_mut());
    run_batch(
        handle,
        operations,
        operation_count,
        out_failed_index,
        |image| {
            let out = unsafe { out_image.as_mut() }.ok_or(ImageErrorCode::InvalidPointer)?;
            *out = into_handle(image.into_owned());
            Ok(())
        },
    )
}

/// Apply a batch and encode the final image. `format` is an `ImageFormatEnum`
/// value; `jpeg_quality` (1..=100) is read only for JPEG.
/// Caller must free the buffer using `pixer_free_buffer`.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_batch_encode(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    format: u32,
    jpeg_quality: u8,
    out_data: *mut *mut u8,
    out_len: *mut usize,
    out_failed_index: *mut usize,
) -> ImageErrorCode {
    write(out_data, std::ptr::null_mut());
    write(out_len, 0);
    run_batch(
        handle,
        operations,
        operation_count,
        out_failed_index,
        |image| {
            let (Some(out_data), Some(out_len)) =
                (unsafe { (out_data.as_mut(), out_len.as_mut()) })
            else {
                return Err(ImageErrorCode::InvalidPointer);
            };
            let buffer = encode_image(&image, ImageFormatEnum::try_from(format)?, jpeg_quality)?;
            let buffer = Box::into_raw(buffer.into_boxed_slice());
            *out_len = buffer.len();
            *out_data = buffer as *mut u8;
            Ok(())
        },
    )
}

/// Apply a batch and save the final image to a file; the extension picks the format.
#[unsafe(no_mangle)]
pub extern "C" fn pixer_batch_save(
    handle: *const ImageHandle,
    operations: *const PixerOperation,
    operation_count: usize,
    path: *const c_char,
    out_failed_index: *mut usize,
) -> ImageErrorCode {
    run_batch(
        handle,
        operations,
        operation_count,
        out_failed_index,
        |image| Ok(image.save(c_path(path)?)?),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn blur_rejects_subnormal_and_underflowing_scalars() {
        for scalar in [1e-40, 1e-50] {
            let op = PixerOperation {
                kind: PixerOperationKind::Blur as u32,
                arg0: 0,
                arg1: 0,
                arg2: 0,
                arg3: 0,
                scalar,
            };
            assert!(matches!(
                Op::try_from(&op),
                Err(ImageErrorCode::InvalidParameter)
            ));
        }
    }

    #[test]
    fn resize_matches_image_crate_dimensions() {
        let images = [
            DynamicImage::new_rgb8(192, 108),
            DynamicImage::new_rgba8(7, 3),
            DynamicImage::new_luma16(1000, 1),
        ];
        for image in &images {
            for (width, height) in [(48, 32), (384, 216), (1, 1), (5, 10_000), (7, 3)] {
                let op = Op::Resize {
                    width,
                    height,
                    filter: FilterTypeEnum::Lanczos3,
                    exact: false,
                };
                let resized = op.apply(image).unwrap();
                let expected = image.resize(width, height, FilterType::Nearest);
                assert_eq!(
                    (resized.width(), resized.height(), resized.color()),
                    (expected.width(), expected.height(), expected.color()),
                    "{:?} {}x{} into {width}x{height}",
                    image.color(),
                    image.width(),
                    image.height(),
                );
            }
        }
    }

    #[cfg(feature = "jpeg")]
    #[test]
    fn load_applies_exif_orientation() {
        use image::ImageEncoder;
        // Little-endian TIFF with one IFD entry: Orientation (0x0112) = 6, rotate 90° clockwise.
        let exif = vec![
            b'I', b'I', 42, 0, 8, 0, 0, 0, // header, first IFD at offset 8
            1, 0, // one entry
            0x12, 0x01, 3, 0, 1, 0, 0, 0, 6, 0, 0, 0, // tag, SHORT, count 1, value 6
            0, 0, 0, 0, // no next IFD
        ];
        let mut jpeg = Vec::new();
        let mut encoder = image::codecs::jpeg::JpegEncoder::new(&mut jpeg);
        encoder.set_exif_metadata(exif).unwrap();
        encoder
            .write_image(&[0; 4 * 2 * 3], 4, 2, image::ExtendedColorType::Rgb8)
            .unwrap();

        let mut handle = std::ptr::null_mut();
        let code =
            pixer_load_from_memory(jpeg.as_ptr(), jpeg.len(), PIXER_FORMAT_DETECT, &mut handle);
        assert!(matches!(code, ImageErrorCode::Success), "{code:?}");
        let image = image_ref(handle).unwrap();
        assert_eq!((image.width(), image.height()), (2, 4));
        pixer_free(handle);
    }

    #[test]
    fn memory_accounting_uses_actual_channel_storage() {
        for (image, expected) in [
            (DynamicImage::new_rgba8(3, 2), 24),
            (DynamicImage::new_rgba16(3, 2), 48),
            (DynamicImage::new_rgb32f(3, 2), 72),
            (DynamicImage::new_rgba32f(3, 2), 96),
        ] {
            let handle = into_handle(image);
            assert_eq!(pixer_image_byte_length(handle), expected);
            pixer_free(handle);
        }
        assert_eq!(pixer_image_byte_length(std::ptr::null()), 0);
    }
}
