// ignore_for_file: avoid_print

import 'dart:io';
import 'package:swagen/parser/datasource_generator.dart';
import 'package:swagen/parser/entitiy_generator.dart';
import 'package:swagen/parser/exception_generator.dart';
import 'package:swagen/parser/failure_generator.dart';
import 'package:swagen/parser/injector_generator.dart';
import 'package:swagen/parser/injectore_core_generator.dart';
import 'package:swagen/parser/model_generator.dart';
import 'package:swagen/parser/provider_generator.dart';
import 'package:swagen/parser/repository_generator.dart';
import 'package:swagen/parser/repository_impl_generator.dart';
import 'package:swagen/parser/state_generator.dart';
import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/parser/usecase_generator.dart';
import 'package:swagen/utils/code_formatter.dart';
import 'package:swagen/utils/dependency_installer.dart';
import 'package:swagen/utils/entity_helper.dart';
import 'package:swagen/utils/file_usage_detector.dart';
import 'package:swagen/utils/group_by_tag.dart';
import 'package:swagen/utils/method_name_generator.dart';
import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/package_reader.dart';
import 'package:swagen/utils/parameter_generator.dart';
import 'package:swagen/utils/repository_return_type.dart';
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
    'get_it',
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

  final datasourceGenerator = DatasourceGenerator(packageName);
  final repositoryGenerator = RepositoryGenerator(packageName);
  final repositoryImplGenerator = RepositoryImplGenerator(packageName);
  final useCaseGenerator = UseCaseGenerator(packageName);
  final providerGenerator = ProviderGenerator(packageName);

  // Group paths by tag
  final groupedPaths = groupPathsByTag(paths);

  // Generate core files
  Directory('lib/core/error').createSync(recursive: true);
  ExceptionGenerator().generate('lib/core/error/exception.dart');
  FailureGenerator().generate('lib/core/error/failure.dart');
  Directory('lib/core/state').createSync(recursive: true);
  StateGenerator().generate('lib/core/state/request_state.dart');

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
    final usecaseDir = '$domainDir/usecases';
    // Presentation Layer
    final presentationDir = '$featureDir/presentation';
    final providerDir = '$presentationDir/providers';

    // Create directories
    Directory(modelsDir).createSync(recursive: true);
    Directory(datasourceDir).createSync(recursive: true);
    Directory(dataRepoDir).createSync(recursive: true);
    Directory(domainRepoDir).createSync(recursive: true);
    Directory(entitiesDir).createSync(recursive: true);
    Directory(usecaseDir).createSync(recursive: true);
    Directory(providerDir).createSync(recursive: true);

    // Generate datasource
    final datasourceCode = datasourceGenerator.generatorDataSource(
      pathsForFeature,
      baseUrl,
      components,
      parser,
      featureName,
    );
    generateDatasource(
      outputPath: datasourceDir,
      code: datasourceCode,
      featureName: featureName,
    );

    schemas.addAll(datasourceGenerator.inlineSchemas);

    for (var usedModel in datasourceGenerator.usedImports) {
      final schemaKey = usedModel.replaceAll('Response', '');
      if (schemas.containsKey(schemaKey)) {
        schemas[usedModel] = schemas[schemaKey]!;
      }
    }

    // Generate repositories
    generateRepositories(
      groupedPaths: {featureName: pathsForFeature},
      packageName: packageName,
      featureName: featureName,
      repoGen: repositoryGenerator,
      implGen: repositoryImplGenerator,
      components: components,
      domainPath: domainRepoDir,
      dataPath: dataRepoDir,
      usedEntities: usedEntities,
    );

    // Generate entities
    final entities = generateEntities(
      usedEntities: usedEntities,
      schemas: schemas,
      outputPath: entitiesDir,
    );

    final modelGenerator = ModelGenerator(generatedEntities: entities);

    // Generate models
    generateModels(
      usedModels: datasourceGenerator.usedImports,
      schemas: schemas,
      generator: modelGenerator,
      outputPath: modelsDir,
      projetName: packageName,
      featureName: featureName,
    );

    // Generate use cases
    generateUseCases(
      featureName: featureName,
      pathsForFeature: pathsForFeature,
      components: components,
      usedEntities: usedEntities,
      packageName: packageName,
      usecaseDir: usecaseDir,
      providerDir: providerDir,
      useCaseGenerator: useCaseGenerator,
      providerGenerator: providerGenerator,
    );
  }

  // Generate injectors
  final injectorFeatures = collectInjectorFeatures(groupedPaths);

  generateInjectors(
    packageName: packageName,
    injectorFeatures: injectorFeatures,
  );

  print('\n🚀 Swagger converted successfully into Clean Architecture!');

  await formatGeneratedCode();
}

void generateModels({
  required Set<String> usedModels,
  required Map<String, dynamic> schemas,
  required ModelGenerator generator,
  required String outputPath,
  required String projetName,
  required String featureName,
}) {
  final generated = <String>{};

  void generateRecursive(String modelName) {
    final schemaKey =
        schemas.containsKey(modelName) ? modelName : stripResponse(modelName);

    if (generated.contains(modelName) || !schemas.containsKey(schemaKey)) {
      return;
    }

    generated.add(modelName);

    final code = generator.generateWithImports(
      modelName,
      schemas[schemaKey]!,
      featureName,
      projetName,
    );

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

void generateDatasource({
  required String outputPath,
  required String code,
  required String featureName,
}) {
  Directory(outputPath).createSync(recursive: true);
  File(
    '$outputPath/${featureName}_remote_data_source.dart',
  ).writeAsStringSync(code);
  print('✅ RemoteDataSource generated at $outputPath');
}

Set<String> generateEntities({
  required Set<String> usedEntities,
  required Map<String, dynamic> schemas,
  required String outputPath,
}) {
  final generator = EntityGenerator();
  final generated = <String>{};

  void generateRecursive(String entityName) {
    if (generated.contains(entityName)) return;

    final schemaKey = schemas.keys.firstWhere(
      (k) => resolveEntityName(k) == entityName,
      orElse: () => '',
    );

    if (schemaKey.isEmpty) return;

    final schema = schemas[schemaKey]!;

    // ⛔ FILTER DOMAIN ENTITY
    if (!isDomainEntity(schemaKey, schema)) return;

    generated.add(entityName);

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
  return generated;
}

void generateRepositories({
  required Map<String, Map<String, dynamic>> groupedPaths,
  required String packageName,
  required String featureName,
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
      featureName,
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

void generateUseCases({
  required String featureName,
  required Map<String, dynamic> pathsForFeature,
  required Map<String, dynamic> components,
  required Set<String> usedEntities,
  required String packageName,
  required String usecaseDir,
  required String providerDir,
  required UseCaseGenerator useCaseGenerator,
  required ProviderGenerator providerGenerator,
}) {
  final repositoryClassName =
      featureName == 'default'
          ? packageName.pascalCase
          : featureName.pascalCase;

  final repositoryName = '${repositoryClassName}Repository';

  pathsForFeature.forEach((path, methods) {
    methods.forEach((method, details) {
      final methodName = generateMethodName(
        method,
        path,
        details['operationId'],
      );

      final result = repositoryReturnTypeResult(
        details,
        components['schemas'] ?? {},
      );

      usedEntities.addAll(result.entities);

      final returnType = result.type;

      final paramResult = generateParameters(details, components);
      usedEntities.addAll(paramResult.usedEntities);

      final paramsList =
          paramResult.params.isEmpty
              ? <String>[]
              : paramResult.params.split(', ');

      final needsFile = useFile(details, components, usedEntities);

      final usecaseCode = useCaseGenerator.generate(
        featureName: featureName,
        repositoryName: repositoryName,
        methodName: methodName,
        returnType: returnType,
        parameters: paramsList,
        usedEntities: usedEntities,
        needsFile: needsFile,
      );

      final providerParams =
          paramResult.params.isEmpty
              ? <ProviderParam>[]
              : paramResult.params.split(', ').map((p) {
                final parts = p.split(' ');
                return ProviderParam(type: parts[0], name: parts[1]);
              }).toList();

      final providerCode = providerGenerator.generate(
        featureName: featureName,
        usecaseName: methodName.pascalCase,
        methodName: methodName,
        params: providerParams,
        returnType: returnType,
      );

      File(
        '$providerDir/${methodName.snakeCase}_provider.dart',
      ).writeAsStringSync(providerCode);

      File(
        '$usecaseDir/${methodName.snakeCase}.dart',
      ).writeAsStringSync(usecaseCode);
    });
  });
}

Map<String, List<String>> collectInjectorFeatures(
  Map<String, Map<String, dynamic>> groupedPaths,
) {
  final injectorFeatures = <String, List<String>>{};

  for (final entry in groupedPaths.entries) {
    final featureName = entry.key.toLowerCase();
    final pathsForFeature = entry.value;
    final classes = <String>[];

    pathsForFeature.forEach((path, methods) {
      methods.forEach((method, details) {
        final methodName = generateMethodName(
          method,
          path,
          details['operationId'],
        );
        classes.add(methodName);
      });
    });

    injectorFeatures[featureName] = classes;
  }

  return injectorFeatures;
}

void generateInjectors({
  required String packageName,
  required Map<String, List<String>> injectorFeatures,
}) {
  final injectorGenerator = InjectorGenerator(packageName);

  for (final entry in injectorFeatures.entries) {
    injectorGenerator.generateFeatureInjector(
      featureName: entry.key,
      classes: entry.value,
    );
  }

  MainInjectorGenerator(packageName).generate(injectorFeatures.keys.toSet());
}
