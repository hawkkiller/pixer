use image::{
    DynamicImage, ImageError, ImageFormat, codecs::jpeg::JpegEncoder, imageops::FilterType,
};
use std::path::Path;

/// Error codes for image operations
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
/// Image format enum for encoding/decoding
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
    pub fn to_image_format(&self) -> ImageFormat {
        match self {
            ImageFormatEnum::Png => ImageFormat::Png,
            ImageFormatEnum::Jpeg => ImageFormat::Jpeg,
            ImageFormatEnum::Gif => ImageFormat::Gif,
            ImageFormatEnum::WebP => ImageFormat::WebP,
            ImageFormatEnum::Bmp => ImageFormat::Bmp,
            ImageFormatEnum::Ico => ImageFormat::Ico,
            ImageFormatEnum::Tiff => ImageFormat::Tiff,
        }
    }

    pub fn from_image_format(format: ImageFormat) -> Option<Self> {
        match format {
            ImageFormat::Png => Some(ImageFormatEnum::Png),
            ImageFormat::Jpeg => Some(ImageFormatEnum::Jpeg),
            ImageFormat::Gif => Some(ImageFormatEnum::Gif),
            ImageFormat::WebP => Some(ImageFormatEnum::WebP),
            ImageFormat::Bmp => Some(ImageFormatEnum::Bmp),
            ImageFormat::Ico => Some(ImageFormatEnum::Ico),
            ImageFormat::Tiff => Some(ImageFormatEnum::Tiff),
            _ => None,
        }
    }
}

#[allow(dead_code)]
/// Filter type for resizing operations
#[repr(u32)]
pub enum FilterTypeEnum {
    Nearest = 0,
    Triangle = 1,
    CatmullRom = 2,
    Gaussian = 3,
    Lanczos3 = 4,
}

impl FilterTypeEnum {
    pub fn to_filter_type(&self) -> FilterType {
        match self {
            FilterTypeEnum::Nearest => FilterType::Nearest,
            FilterTypeEnum::Triangle => FilterType::Triangle,
            FilterTypeEnum::CatmullRom => FilterType::CatmullRom,
            FilterTypeEnum::Gaussian => FilterType::Gaussian,
            FilterTypeEnum::Lanczos3 => FilterType::Lanczos3,
        }
    }
}

#[allow(dead_code)]
/// Opaque handle to an image
#[repr(C)]
pub struct ImageHandle {
    _private: [u8; 0],
}

/// Image metadata structure
#[repr(C)]
pub struct ImageMetadata {
    pub width: u32,
    pub height: u32,
    pub color_type: u8, // 0=L, 1=La, 2=Rgb, 3=Rgba
}

#[allow(dead_code)]
/// Result structure for operations returning image data
#[repr(C)]
pub struct ImageDataResult {
    pub data: *mut u8,
    pub len: usize,
    pub error_code: ImageErrorCode,
}

/// Load an image from a file path
pub fn load_image(path: &str) -> Result<DynamicImage, ImageError> {
    image::open(Path::new(path))
}

/// Load an image from memory buffer
pub fn load_image_from_memory(data: &[u8]) -> Result<DynamicImage, ImageError> {
    image::load_from_memory(data)
}

/// Load an image from memory with specific format
pub fn load_image_from_memory_with_format(
    data: &[u8],
    format: ImageFormat,
) -> Result<DynamicImage, ImageError> {
    image::load_from_memory_with_format(data, format)
}

/// Save an image to a file path
pub fn save_image(img: &DynamicImage, path: &str) -> Result<(), ImageError> {
    img.save(Path::new(path))
}

/// Encode an image to a specific format in memory
pub fn write_to(img: &DynamicImage, format: ImageFormat) -> Result<Vec<u8>, ImageError> {
    let mut buffer = Vec::new();
    img.write_to(&mut std::io::Cursor::new(&mut buffer), format)?;
    Ok(buffer)
}

/// Encode an image to JPEG in memory with an explicit quality value.
pub fn write_to_jpeg_with_quality(img: &DynamicImage, quality: u8) -> Result<Vec<u8>, ImageError> {
    let mut buffer = Vec::new();
    img.write_with_encoder(JpegEncoder::new_with_quality(&mut buffer, quality))?;
    Ok(buffer)
}

/// Resize an image (preserves aspect ratio, fits within bounds)
pub fn resize(img: &DynamicImage, width: u32, height: u32, filter: FilterType) -> DynamicImage {
    img.resize(width, height, filter)
}

/// Resize to exact dimensions (ignores aspect ratio)
pub fn resize_exact(
    img: &DynamicImage,
    width: u32,
    height: u32,
    filter: FilterType,
) -> DynamicImage {
    img.resize_exact(width, height, filter)
}

/// Crop an image (immutable)
pub fn crop_imm(img: &DynamicImage, x: u32, y: u32, width: u32, height: u32) -> DynamicImage {
    img.crop_imm(x, y, width, height)
}

/// Rotate an image 90 degrees clockwise
pub fn rotate90(img: &DynamicImage) -> DynamicImage {
    img.rotate90()
}

/// Rotate an image 180 degrees
pub fn rotate180(img: &DynamicImage) -> DynamicImage {
    img.rotate180()
}

/// Rotate an image 270 degrees clockwise
pub fn rotate270(img: &DynamicImage) -> DynamicImage {
    img.rotate270()
}

/// Flip an image horizontally
pub fn fliph(img: &DynamicImage) -> DynamicImage {
    img.fliph()
}

/// Flip an image vertically
pub fn flipv(img: &DynamicImage) -> DynamicImage {
    img.flipv()
}

/// Blur an image
pub fn blur(img: &DynamicImage, sigma: f32) -> DynamicImage {
    img.blur(sigma)
}

/// Brighten the pixels of an image
pub fn brighten(img: &DynamicImage, value: i32) -> DynamicImage {
    img.brighten(value)
}

/// Adjust contrast
pub fn adjust_contrast(img: &DynamicImage, c: f32) -> DynamicImage {
    img.adjust_contrast(c)
}

/// Convert to grayscale
pub fn grayscale(img: &DynamicImage) -> DynamicImage {
    DynamicImage::ImageLuma8(img.to_luma8())
}

/// Invert colors (returns new image)
pub fn invert(img: &DynamicImage) -> DynamicImage {
    let mut cloned = img.clone();
    cloned.invert();
    cloned
}

/// Get image metadata
pub fn get_metadata(img: &DynamicImage) -> ImageMetadata {
    let color_type = match img.color() {
        image::ColorType::L8 | image::ColorType::L16 => 0,
        image::ColorType::La8 | image::ColorType::La16 => 1,
        image::ColorType::Rgb8 | image::ColorType::Rgb16 | image::ColorType::Rgb32F => 2,
        image::ColorType::Rgba8 | image::ColorType::Rgba16 | image::ColorType::Rgba32F => 3,
        _ => 3, // Default to RGBA
    };

    ImageMetadata {
        width: img.width(),
        height: img.height(),
        color_type,
    }
}

/// Guess image format from byte data
pub fn guess_image_format(data: &[u8]) -> Result<ImageFormatEnum, ImageError> {
    let format = image::guess_format(data)?;
    ImageFormatEnum::from_image_format(format)
        .ok_or_else(|| {
            ImageError::Unsupported(image::error::UnsupportedError::from_format_and_kind(
                image::error::ImageFormatHint::Unknown,
                image::error::UnsupportedErrorKind::Format(image::error::ImageFormatHint::Unknown),
            ))
        })
}

/// Convert ImageError to error code
pub fn error_to_code(err: &ImageError) -> ImageErrorCode {
    match err {
        ImageError::Decoding(_) => ImageErrorCode::DecodingError,
        ImageError::Encoding(_) => ImageErrorCode::EncodingError,
        ImageError::IoError(_) => ImageErrorCode::IoError,
        ImageError::Limits(_) => ImageErrorCode::InvalidDimensions,
        ImageError::Unsupported(_) => ImageErrorCode::UnsupportedFormat,
        ImageError::Parameter(_) => ImageErrorCode::InvalidParameter,
    }
}
