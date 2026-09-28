import 'package:pixer/pixer.dart';

void main() {
  final image = Pixer.fromFile('assets/image.png');
  final thumbnail = image.resize(100, 100);
  thumbnail.saveToFile('assets/thumbnail.png');
}