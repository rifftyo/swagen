#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:swagen/parser/exception_generator.dart';
import 'package:swagen/parser/failure_generator.dart';
import 'package:yaml/yaml.dart';

import 'package:swagen/parser/model_generator.dart';
import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/parser/datasource_generator.dart';

const String swagenVersion = '1.0.0';
const String githubUrl = 'https://github.com/rifftyo/swagen';

String getPackageName() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw Exception("❌ pubspec.yaml not found in project root");
  }
  final yaml = loadYaml(pubspec.readAsStringSync());
  return yaml['name'] ?? 'unknown_package';
}

void main(List<String> args) {
  if (args.isEmpty || args.contains('help')) {
    _printHelp();
    return;
  }

  if (args.contains('--version') || args.contains('-v')) {
    print('🚀 swagen version $swagenVersion');
    print('🔗 $githubUrl');
    return;
  }

  if (args.first == 'convert') {
    if (args.length < 2) {
      print('❌ Please provide swagger file');
      print('Example: swagen convert swagger.json');
      return;
    }

    _convertSwagger(args.sublist(1));
    return;
  }

  print('❌ Unknown command');
  _printHelp();
}

void _convertSwagger(List<String> args) {
  final inputPath = args[0];

  final packageIndex = args.indexOf('--package');
  final packageName =
      packageIndex != -1 ? args[packageIndex + 1] : getPackageName();

  final parser = SwaggerParser.fromFile(inputPath);
  final schemas = parser.getSchemas();
  final paths = parser.getPaths();
  final baseUrl = parser.getBaseUrl();

  final inlineSchemas = parser.extractInlineResponseSchemas();
  schemas.addAll(inlineSchemas);

  final modelGenerator = ModelGenerator();
  final datasourceGenerator = DatasourceGenerator(packageName);
  final exceptionGenerator = ExceptionGenerator();
  final failureGenerator = FailureGenerator();

  // Generate RemoteDataSource
  final datasourceOutputPath = 'lib/data/datasources';
  Directory(datasourceOutputPath).createSync(recursive: true);

  final datasourceCode = datasourceGenerator.generatorDataSource(
    paths,
    baseUrl,
    schemas,
    parser,
  );

  final usedModels = datasourceGenerator.usedImports;

  // Generate Models
  final modelOutputPath = 'lib/data/models';
  Directory(modelOutputPath).createSync(recursive: true);

  final generated = <String>{};

  void generateRecursive(String name) {
    if (generated.contains(name) || !schemas.containsKey(name)) return;
    generated.add(name);

    final schema = schemas[name]!;
    final dartCode = modelGenerator.generateWithImports(name, schema);
    final deps = modelGenerator.usedImports;

    final file = File('$modelOutputPath/${name.toLowerCase()}.dart');
    file.writeAsStringSync(dartCode);
    print('✅ Generated Model: ${file.path}');

    for (var dep in deps.toList()) {
      generateRecursive(dep);
    }
  }

  for (var name in usedModels) {
    generateRecursive(name);
  }

  // 3️⃣ Generate Exception & Failure
  exceptionGenerator.generate('lib/common/exception.dart');
  failureGenerator.generate('lib/common/failure.dart');

  // 4️⃣ Write DataSource
  final datasourceFile = File('$datasourceOutputPath/remote_datasource.dart');
  datasourceFile.writeAsStringSync(datasourceCode);
  print('✅ Generated RemoteDataSource: ${datasourceFile.path}');

  // 5️⃣ Format code
  try {
    print('\n🎨 Formatting generated files...');
    final result = Process.runSync('dart', [
      'format',
      datasourceFile.path,
    ], runInShell: true);

    if (result.stderr.toString().isNotEmpty) {
      print('⚠️ Format warning: ${result.stderr}');
    } else {
      print('✅ Formatting completed');
    }
  } catch (e) {
    print('⚠️ Failed to format file: $e');
  }

  // 6️⃣ Summary
  print('\n🚀 Swagger converted successfully!');
  print('📂 Output directories:');
  print('   - lib/data/models');
  print('   - lib/data/datasources');
  print('   - lib/common');

  // 7️⃣ Dependency install prompt
  print('\n📦 Required dependencies:');
  print('  - http');
  print('  - flutter_secure_storage');
  print('  - dartz');
  print('  - equatable');

  stdout.write(
    '\n❓ Do you want to install dependencies automatically? (y/n): ',
  );
  final input = stdin.readLineSync()?.toLowerCase();

  if (input == 'y' || input == 'yes') {
    final flutterCmd = Platform.isWindows ? 'flutter.bat' : 'flutter';

    try {
      print('\n⚡ Installing dependencies...');
      final result = Process.runSync(flutterCmd, [
        'pub',
        'add',
        'http',
        'dartz',
        'equatable',
        'flutter_secure_storage',
      ], runInShell: true);

      print(result.stdout);

      if (result.stderr.toString().isNotEmpty) {
        print('⚠️ Error: ${result.stderr}');
      } else {
        print('✅ Dependencies installed successfully!');
      }
    } catch (e) {
      print('❌ Failed to install dependencies: $e');
    }
  } else {
    print(
      '\n👉 Skipping auto-install.\n'
      'Run manually:\n'
      'flutter pub add http dartz equatable flutter_secure_storage',
    );
  }
}

void _printHelp() {
  print('''
🚀 SWAGEN - Swagger to Flutter Generator

USAGE:
  swagen <command> [options]

COMMANDS:
  convert <swagger.json>   Convert swagger file to Flutter code
  --version, -v            Show swagen version
  help                     Show this help

OPTIONS:
  --package <name>         Custom package name

EXAMPLES:
  swagen convert swagger.json
  swagen convert swagger.json --package my_app
  swagen --version

DOCUMENTATION:
  📘 GitHub: $githubUrl
  🧩 Example Swagger:
  $githubUrl/tree/main/examples

ISSUES & CONTRIBUTIONS:
  $githubUrl/issues
''');
}
