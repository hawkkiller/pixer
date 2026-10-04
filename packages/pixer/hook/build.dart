import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:pixer/src/hook/download_asset.dart';
import 'package:pixer/src/hook/hashes.dart';
import 'package:pixer/src/hook/local_build.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final formats = readFormats(input);
    // Prebuilt binaries include every format, so a custom set needs a source build.
    final localBuild = formats != null || (input.userDefines['local_build'] as bool? ?? false);

    final CodeConfig codeConfig;

    try {
      // Skip for web - code config throws on web platform
      codeConfig = input.config.code;
    } catch (_) {
      return;
    }

    if (localBuild) {
      return runLocalBuild(input, output, formats: formats);
    }

    final targetOS = codeConfig.targetOS;
    final targetArchitecture = codeConfig.targetArchitecture;
    final iOSSdk = targetOS == OS.iOS ? codeConfig.iOS.targetSdk : null;
    final outputDirectory = Directory.fromUri(input.outputDirectory);
    final file = await downloadAsset(
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      iOSSdk: iOSSdk,
      outputDirectory: outputDirectory,
    );

    await verifyAssetHash(
      file,
      targetOS: targetOS,
      targetArchitecture: targetArchitecture,
      iOSSdk: iOSSdk,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/bindings/bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: file.uri,
      ),
    );
  });
}

Future<void> verifyAssetHash(
  File asset, {
  required OS targetOS,
  required Architecture targetArchitecture,
  required IOSSdk? iOSSdk,
}) async {
  final hash = await hashAsset(asset);
  final targetName = targetOS.dylibFileName(createTargetName(targetOS, targetArchitecture, iOSSdk));
  final expectedHash = assetHashes[targetName];

  if (hash != expectedHash) {
    throw Exception('Asset hash mismatch: $hash != $expectedHash');
  }
}
