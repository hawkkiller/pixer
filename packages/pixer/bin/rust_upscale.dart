import 'dart:io';
import 'dart:typed_data';

import 'package:pixer/pixer.dart';

void main() async {
  final url =
      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8Mnx8bW91bnRhaW58ZW58MHx8MHx8fDA%3D&w=1000&q=80';
  final client = await HttpClient();
  final response = await client.getUrl(Uri.parse(url)).then((req) => req.close());
  final bytes = await response
      .expand((element) => element)
      .toList()
      .then((value) => Uint8List.fromList(value));
  client.close();

  final stopwatch = Stopwatch()..start();
  final image = Pixer.fromMemory(bytes);
  final upscaledImage = image.resize(3840, 2160);
  upscaledImage.saveToFile('upscaled_image.jpg');
  print('Image upscaled in ${stopwatch.elapsedMilliseconds}ms');

  final img = Pixer.fromFile('assets/example_img.jpg');
  final resizedImage = img.resize(3840, 2160);
  final croppedImage = resizedImage.crop(0, 0, 100, 100);
  croppedImage.saveToFile('cropped_image.jpg');
  img.dispose();
  resizedImage.dispose();
  croppedImage.dispose();
}
