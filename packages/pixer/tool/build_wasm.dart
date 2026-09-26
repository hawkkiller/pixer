import 'dart:io';

Future<void> main(List<String> arguments) async {
  final packageDirectory = File.fromUri(Platform.script).absolute.parent.parent;
  final repositoryDirectory = packageDirectory.parent.parent;
  final nativeDirectory = Directory.fromUri(
    repositoryDirectory.uri.resolve('native/'),
  );
  final output = arguments.isEmpty
      ? File.fromUri(packageDirectory.uri.resolve('assets/pixer.wasm'))
      : File(arguments.single).absolute;

  final process = await Process.start(
    'cargo',
    ['build', '--release', '--target', 'wasm32-unknown-unknown'],
    workingDirectory: nativeDirectory.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) exit(exitCode);

  await output.parent.create(recursive: true);
  await File.fromUri(
    nativeDirectory.uri.resolve(
      'target/wasm32-unknown-unknown/release/pixer.wasm',
    ),
  ).copy(output.path);
  stdout.writeln('Built ${output.path}');
}
