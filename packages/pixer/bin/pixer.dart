import 'dart:io';

import 'package:pixer/src/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
