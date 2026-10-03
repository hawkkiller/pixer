import 'package:pixer/pixer.dart';

void main() {
  final image = Pixer.fromFile('assets/image.png');
  image
      .flipHorizontal()
      .blur(2)
      .rotate180()
      .brightness(20)
      .resize(100, 100)
      .saveToFile('assets/thumbnail.png');
  image.dispose();
}
