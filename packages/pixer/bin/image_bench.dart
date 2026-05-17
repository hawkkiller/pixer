import 'dart:io';

import 'package:image/image.dart' as imag;

void main() async {
  final command = imag.Command()
    ..decodeJpgFile('assets/example_img.jpg')
    ..copyResize(width: 3840, height: 2160, interpolation: imag.Interpolation.cubic)
    ..encodePng();
  
  await command.execute();
  final pngBytes = command.outputBytes!;
  File('example_img2.png').writeAsBytesSync(pngBytes);
}
