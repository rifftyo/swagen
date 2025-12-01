// ignore_for_file: avoid_print

import 'dart:io';
import 'package:swagen/parser/exception_generator.dart';
import 'package:yaml/yaml.dart';

import 'package:swagen/parser/model_generator.dart';
import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/parser/datasource_generator.dart';

String getPackageName() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    throw Exception("❌ pubspec.yaml not found in project root");
  }
  final yaml = loadYaml(pubspec.readAsStringSync());
  return yaml['name'] ?? 'unknown_package';
}

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run swagger_model <swagger.json>');
    return;
  }

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

  // 1. Generate RemoteDataSource
  final datasourceOutputPath = 'lib/data/datasources';
  Directory(datasourceOutputPath).createSync(recursive: true);

  final datasourceCode = datasourceGenerator.generatorDataSource(
    paths,
    baseUrl,
    schemas,
  );

  final usedModels = datasourceGenerator.usedImports;

  // 2. Generate Model
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

  // 3 Write DataSource
  final datasourceFile = File('$datasourceOutputPath/remote_datasource.dart');
  datasourceFile.writeAsStringSync(datasourceCode);
  print('✅ Generated RemoteDataSource: ${datasourceFile.path}');

  // 4. Generate Exceptions
  exceptionGenerator.generate('lib/common/exception.dart');

  // After generation success
  print('\n🚀 All files have been successfully generated!');
  print('👉 Next steps:');
  print('1. Install required dependencies by running:');
  print('   flutter pub add http');
  print('2. Then run:');
  print('   flutter pub get');

  stdout.write(
    '\n❓ Do you want to install dependencies automatically? (y/n): ',
  );
  final input = stdin.readLineSync()?.toLowerCase();

  if (input == 'y' || input == 'yes') {
    final flutterCmd = Platform.isWindows ? 'flutter.bat' : 'flutter';
    try {
      print('\n⚡ Installing dependencies automatically...');
      final result = Process.runSync(flutterCmd, ['pub', 'add', 'http']);
      print(result.stdout);
      if (result.stderr.toString().isNotEmpty) {
        print('⚠️ Error: ${result.stderr}');
      } else {
        print('✅ Dependencies installed successfully!');
      }
    } catch (e) {
      print('❌ Failed to install dependencies automatically: $e');
    }
  } else {
    print(
      '\n👉 Skipping auto-install. Please install manually with: flutter pub add http',
    );
  }
}
