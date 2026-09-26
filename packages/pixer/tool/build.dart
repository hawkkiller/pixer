// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:code_assets/code_assets.dart';
import 'package:pixer/src/hook/get_android_compiler_config.dart';
import 'package:pixer/src/hook/local_build.dart';
import 'package:pixer/src/hook/target_versions.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  final (os: os, architecture: architecture, iOSSdk: iOSSdk) = parseArguments(args);
  final input = createBuildInput(os, architecture, iOSSdk);
  final output = BuildOutputBuilder();
  await runLocalBuild(input, output);
}

({String architecture, String os, String? iOSSdk}) parseArguments(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'architecture',
      abbr: 'a',
      allowed: Architecture.values.map((a) => a.name),
      mandatory: true,
    )
    ..addOption('os', abbr: 'o', allowed: OS.values.map((a) => a.name), mandatory: true)
    ..addOption(
      'iossdk',
      abbr: 'i',
      allowed: IOSSdk.values.map((a) => a.type),
      help: 'Required if OS is iOS.',
    );
  final argResults = parser.parse(args);

  final os = argResults.option('os');
  final architecture = argResults.option('architecture');
  final iOSSdk = argResults.option('iossdk');
  if (os == null || architecture == null || (os == OS.iOS.name && iOSSdk == null)) {
    print(parser.usage);
    exit(1);
  }
  return (os: os, architecture: architecture, iOSSdk: iOSSdk);
}

BuildInput createBuildInput(String osString, String architecture, String? iOSSdk) {
  final packageRoot = Platform.script.resolve('..');
  final outputDirectoryShared = packageRoot.resolve('.dart_tool/pixer/shared/');
  final outputFile = packageRoot.resolve('.dart_tool/pixer/output.json');

  final os = OS.fromString(osString);
  final architectureEnum = Architecture.fromString(architecture);
  final inputBuilder = BuildInputBuilder()
    ..setupShared(
      packageRoot: packageRoot,
      packageName: 'pixer',
      outputFile: outputFile,
      outputDirectoryShared: outputDirectoryShared,
    )
    ..config.setupBuild(linkingEnabled: false)
    ..addExtension(
      CodeAssetExtension(
        targetArchitecture: architectureEnum,
        targetOS: os,
        linkModePreference: LinkModePreference.dynamic,
        android: os != OS.android ? null : AndroidCodeConfig(targetNdkApi: androidTargetNdkApi),
        iOS: os != OS.iOS
            ? null
            : IOSCodeConfig(targetSdk: IOSSdk.fromString(iOSSdk!), targetVersion: iOSTargetVersion),
        macOS: MacOSCodeConfig(targetVersion: macOSTargetVersion),
        cCompiler: os != OS.android ? null : getAndroidCompilerConfig(architectureEnum),
      ),
    );

  return inputBuilder.build();
}
