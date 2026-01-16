// ignore_for_file: avoid_print

import 'dart:io';
import 'package:swagen/parser/datasource_generator.dart';
import 'package:swagen/parser/entitiy_generator.dart';
import 'package:swagen/parser/exception_generator.dart';
import 'package:swagen/parser/failure_generator.dart';
import 'package:swagen/parser/mapper_generator.dart';
import 'package:swagen/parser/model_generator.dart';
import 'package:swagen/parser/repository_generator.dart';
import 'package:swagen/parser/repository_impl_generator.dart';
import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/utils/code_formatter.dart';
import 'package:swagen/utils/dependency_installer.dart';
import 'package:swagen/utils/entity_helper.dart';
import 'package:swagen/utils/group_by_tag.dart';
import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/package_reader.dart';
import 'package:swagen/utils/string_case.dart';

Future<void> runConvertCommand(List<String> args) async {
  if (args.isEmpty) {
    print('❌ Please provide swagger file');
    print('Example: swagen convert swagger.json');
    return;
  }

  final inputPath = args[0];

  if (!inputPath.startsWith('http://') &&
      !inputPath.startsWith('https://') &&
      !File(inputPath).existsSync()) {
    print('❌ File "$inputPath" not found. Please check the path.');
    return;
  }

  await installDependencies([
    'http',
    'equatable',
    'dartz',
    'flutter_secure_storage',
  ]);

  final packageIndex = args.indexOf('--package');
  final packageName =
      packageIndex != -1 ? args[packageIndex + 1] : getPackageName();

  final SwaggerParser parser;

  if (inputPath.startsWith('http://') || inputPath.startsWith('https://')) {
    parser = await SwaggerParser.fromUrl(inputPath);
  } else {
    parser = SwaggerParser.fromFile(inputPath);
  }

  final components = parser.getComponents();
  final schemas = parser.getSchemas();
  final paths = parser.getPaths();
  final baseUrl = parser.getBaseUrl();

  schemas.addAll(parser.extractInlineResponseSchemas());

  final modelGenerator = ModelGenerator();
  final datasourceGenerator = DatasourceGenerator(packageName);
  final repositoryGenerator = RepositoryGenerator(packageName);
  final repositoryImplGenerator = RepositoryImplGenerator(packageName);
  final mapperGenerator = MapperGenerator();

  // Group paths by tag
  final groupedPaths = groupPathsByTag(paths);

  // Generate core files
  Directory('lib/core/error').createSync(recursive: true);
  ExceptionGenerator().generate('lib/core/error/exception.dart');
  FailureGenerator().generate('lib/core/error/failure.dart');

  // Generate per feature
  for (final entry in groupedPaths.entries) {
    final featureName = entry.key.toLowerCase();
    final featureDir = 'lib/features/$featureName';
    final pathsForFeature = entry.value;
    final usedEntities = <String>{};

    datasourceGenerator.resetImports();

    // Data Layer
    final dataDir = '$featureDir/data';
    final modelsDir = '$dataDir/models';
    final datasourceDir = '$dataDir/datasources';
    final dataRepoDir = '$dataDir/repositories';

    // Domain Layer
    final domainDir = '$featureDir/domain';
    final entitiesDir = '$domainDir/entities';
    final domainRepoDir = '$domainDir/repositories';
    final mapperDir = '$dataDir/mappers';

    // Create directories
    Directory(modelsDir).createSync(recursive: true);
    Directory(datasourceDir).createSync(recursive: true);
    Directory(dataRepoDir).createSync(recursive: true);
    Directory(domainRepoDir).createSync(recursive: true);
    Directory(entitiesDir).createSync(recursive: true);
    Directory(mapperDir).createSync(recursive: true);

    // Generate datasource
    final datasourceCode = datasourceGenerator.generatorDataSource(
      pathsForFeature,
      baseUrl,
      components,
      parser,
      featureName,
    );
    generateDatasource(outputPath: datasourceDir, code: datasourceCode);

    schemas.addAll(datasourceGenerator.inlineSchemas);

    for (var usedModel in datasourceGenerator.usedImports) {
      final schemaKey = usedModel.replaceAll('Response', '');
      if (schemas.containsKey(schemaKey)) {
        schemas[usedModel] = schemas[schemaKey]!;
      }
    }

    // Generate models
    generateModels(
      usedModels: datasourceGenerator.usedImports,
      schemas: schemas,
      generator: modelGenerator,
      outputPath: modelsDir,
    );

    // Generate repositories
    generateRepositories(
      groupedPaths: {featureName: pathsForFeature},
      packageName: packageName,
      repoGen: repositoryGenerator,
      implGen: repositoryImplGenerator,
      components: components,
      domainPath: domainRepoDir,
      dataPath: dataRepoDir,
      usedEntities: usedEntities,
    );

    // Generate entities
    generateEntities(
      usedEntities: usedEntities,
      schemas: schemas,
      outputPath: entitiesDir,
    );

    // Generate mappers
    generateMappers(
      usedEntities: usedEntities,
      schemas: schemas,
      featureName: featureName,
      packageName: packageName,
      mapperDir: mapperDir,
      mapperGenerator: mapperGenerator,
    );
  }

  print('\n🚀 Swagger converted successfully into Clean Architecture!');

  await formatGeneratedCode();
}

void generateModels({
  required Set<String> usedModels,
  required Map<String, dynamic> schemas,
  required ModelGenerator generator,
  required String outputPath,
}) {
  final generated = <String>{};

  void generateRecursive(String modelName) {
    final schemaKey =
        schemas.containsKey(modelName) ? modelName : stripResponse(modelName);

    if (generated.contains(modelName) || !schemas.containsKey(schemaKey)) {
      return;
    }

    generated.add(modelName);

    final code = generator.generateWithImports(modelName, schemas[schemaKey]!);

    File('$outputPath/${modelName.snakeCase}.dart').writeAsStringSync(code);

    final deps = generator.usedImports.toList();
    for (final dep in deps) {
      generateRecursive(dep);
    }
  }

  for (final model in usedModels) {
    generateRecursive(asResponse(model));
  }

  print('✅ Models generated at $outputPath');
}

void generateDatasource({required String outputPath, required String code}) {
  Directory(outputPath).createSync(recursive: true);
  File('$outputPath/remote_data_source.dart').writeAsStringSync(code);
  print('✅ RemoteDataSource generated at $outputPath');
}

void generateEntities({
  required Set<String> usedEntities,
  required Map<String, dynamic> schemas,
  required String outputPath,
}) {
  final generator = EntityGenerator();
  final generated = <String>{};

  void generateRecursive(String entityName) {
    if (generated.contains(entityName)) return;
    generated.add(entityName);

    final schemaKey = schemas.keys.firstWhere(
      (k) => resolveEntityName(k) == entityName,
      orElse: () => '',
    );

    if (schemaKey.isEmpty) return;

    final schema = schemas[schemaKey]!;

    if (!isDomainEntity(schemaKey, schema)) return;

    final deps = resolveEntityDependencies(schemaKey, schemas, {});
    for (final dep in deps) {
      generateRecursive(dep);
    }

    final code = generator.generateEntity(entityName, schema);
    File('$outputPath/${entityName.snakeCase}.dart').writeAsStringSync(code);
  }

  for (final entity in usedEntities) {
    generateRecursive(entity);
  }

  print('✅ Entities generated at $outputPath');
}

void generateRepositories({
  required Map<String, Map<String, dynamic>> groupedPaths,
  required String packageName,
  required RepositoryGenerator repoGen,
  required RepositoryImplGenerator implGen,
  required Map<String, dynamic> components,
  required String domainPath,
  required String dataPath,
  required Set<String> usedEntities,
}) {
  for (final entry in groupedPaths.entries) {
    final className =
        entry.key == 'default' ? packageName.pascalCase : entry.key.pascalCase;

    final repoResult = repoGen.generateRepository(
      className,
      entry.value,
      components,
    );

    usedEntities.addAll(repoResult.usedEntities);

    final implCode = implGen.generateRepositoryImpl(
      className,
      entry.value,
      components,
    );

    File(
      '$domainPath/${className.snakeCase}_repository.dart',
    ).writeAsStringSync(repoResult.code);

    File(
      '$dataPath/${className.snakeCase}_repository.dart',
    ).writeAsStringSync(implCode);
  }

  print('✅ Repositories generated');
}

void generateMappers({
  required Set<String> usedEntities,
  required Map<String, dynamic> schemas,
  required String featureName,
  required String packageName,
  required String mapperDir,
  required MapperGenerator mapperGenerator,
}) {
  final generated = <String>{};

  void generateRecursive(String schemaName) {
    final responseName = asResponse(schemaName);

    if (generated.contains(responseName)) return;
    if (!schemas.containsKey(schemaName)) return;

    generated.add(responseName);

    final schema = schemas[schemaName]!;
    final props = schema['properties'] as Map<String, dynamic>? ?? {};

    for (final value in props.values) {
      if (value['\$ref'] != null) {
        generateRecursive(value['\$ref'].split('/').last);
      } else if (value['type'] == 'array' && value['items']?['\$ref'] != null) {
        generateRecursive(value['items']['\$ref'].split('/').last);
      }
    }

    final code = mapperGenerator.generateWithImports(
      schemaName,
      schema,
      featureName,
      packageName,
    );

    File(
      '$mapperDir/${responseName.snakeCase}_mapper.dart',
    ).writeAsStringSync(code);
  }

  for (final entity in usedEntities) {
    final schemaKey = schemas.keys.firstWhere(
      (k) => resolveEntityName(k) == entity,
      orElse: () => '',
    );

    if (schemaKey.isNotEmpty) {
      generateRecursive(schemaKey);
    }
  }

  print('✅ Mappers generated at $mapperDir');
}
