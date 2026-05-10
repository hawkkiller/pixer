import 'dart:io';

import 'package:ffigen/ffigen.dart';

const _leafSymbols = {'pixer_free_string', 'pixer_free_buffer', 'pixer_free', 'pixer_get_metadata'};

void main() {
  final packageDir = File.fromUri(Platform.script).absolute.parent.parent.uri;
  final header = packageDir.resolve('native/include/pixer.h');
  final output = packageDir.resolve('lib/src/bindings/bindings.dart');

  final generator = FfiGenerator(
    headers: Headers(
      entryPoints: [header],
      include: (candidate) => _sameFile(candidate, header),
      compilerOptions: _macOSCompilerOptions(),
    ),
    output: Output(
      dartFile: output,
      preamble: '''
// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names
''',
      commentType: const CommentType(CommentStyle.any, CommentLength.full),
      style: const NativeExternalBindings(),
    ),
    functions: Functions(
      include: Declarations.includeAll,
      isLeaf: (declaration) => _leafSymbols.contains(declaration.originalName),
    ),
    structs: const Structs(
      include: Declarations.includeAll,
      dependencies: CompoundDependencies.full,
    ),
    enums: const Enums(include: Declarations.includeAll),
    unions: const Unions(include: Declarations.includeAll, dependencies: CompoundDependencies.full),
    unnamedEnums: const UnnamedEnums(include: Declarations.includeAll),
    globals: const Globals(include: Declarations.includeAll),
    macros: const Macros(include: Declarations.includeAll),
    typedefs: const Typedefs(include: Declarations.includeAll),
  );

  generator.generate();
}

List<String>? _macOSCompilerOptions() {
  if (!Platform.isMacOS) return null;

  final result = Process.runSync('xcrun', ['--sdk', 'macosx', '--show-sdk-path']);
  if (result.exitCode != 0) return null;

  final sdkPath = (result.stdout as String).trim();
  if (sdkPath.isEmpty) return null;

  return ['-isysroot', sdkPath];
}

bool _sameFile(Uri left, Uri right) => _absolutePath(left) == _absolutePath(right);

String _absolutePath(Uri uri) => File.fromUri(uri).absolute.path;
