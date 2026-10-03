import 'dart:io';

import 'package:pixer/pixer.dart';

void main() async {
  final img = Pixer.fromFile('assets/example_img.jpg');

  // Upscale the image to 3840x2160 and encode it to PNG
  final pngBytes = img.resizeExact(3840, 2160).encode(PixerPngEncoder());
  File('example_img.png').writeAsBytesSync(pngBytes);

  // Dispose the image to release memory
  img.dispose();
}
