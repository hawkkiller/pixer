import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:pixer/src/hook/targets.dart';
import 'package:pixer/src/hook/version.dart';

Uri downloadUri(String target) =>
    Uri.parse('https://github.com/hawkkiller/pixer/releases/download/$version/$target');

final _httpClient = HttpClient();

/// Downloads the asset for the given target OS and architecture.
Future<File> downloadAsset({
  required OS targetOS,
  required Architecture targetArchitecture,
  required IOSSdk? iOSSdk,
  required Directory outputDirectory,
}) async {
  try {
    final targetName = targetOS.dylibFileName(
      createTargetName(targetOS, targetArchitecture, iOSSdk),
    );

    final uri = downloadUri(targetName);
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw ArgumentError('The request to $uri failed.');
    }

    final library = File.fromUri(outputDirectory.uri.resolve(targetName));
    await library.create();
    await response.pipe(library.openWrite());

    return library;
  } finally {
    _httpClient.close();
  }
}

String createTargetName(OS targetOS, Architecture targetArchitecture, IOSSdk? iOSSdk) {
  final buffer = StringBuffer('pixer_');

  final supportedTarget = getNameForTarget(targetOS, targetArchitecture, iOSSdk);
  buffer.write(supportedTarget);
  return buffer.toString();
}

/// Computes the MD5 hash of the given [assetFile].
Future<String> hashAsset(File assetFile) async {
  final fileHash = md5.convert(await assetFile.readAsBytes()).toString();
  return fileHash;
}
