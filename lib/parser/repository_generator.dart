import 'package:swagen/utils/dartz_import_helper.dart';
import 'package:swagen/utils/file_usage_detector.dart';
import 'package:swagen/utils/method_name_generator.dart';
import 'package:swagen/utils/parameter_generator.dart';
import 'package:swagen/utils/repository_return_type.dart';
import 'package:swagen/utils/string_case.dart';

class RepositoryGenerator {
  final String projectName;

  RepositoryGenerator(this.projectName);

  RepositoryGenerateResult generateRepository(
    String className,
    Map<String, dynamic> paths,
    Map<String, dynamic> components,
  ) {
    final buffer = StringBuffer();

    bool needsFile = false;
    final Set<String> usedEntities = {};
    final schemas = components['schemas'] ?? {};

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        repositoryReturnType(details, usedEntities, schemas);
        generateParameters(details, components, usedEntities);

        if (useFile(details, components, usedEntities)) {
          needsFile = true;
        }
      });
    });

    if (needsFile) {
      buffer.writeln("import 'dart:io';");
    }

    buffer.writeln(dartzImport(usedEntities));
    buffer.writeln("import 'package:$projectName/core/error/failure.dart';");

    for (final entity in usedEntities) {
      final featureFolder = className.snakeCase;
      buffer.writeln(
        "import 'package:$projectName/features/$featureFolder/domain/entities/${entity.snakeCase}.dart';",
      );
    }

    buffer.writeln();
    buffer.writeln('abstract class ${className}Repository {');

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final funcName = generateMethodName(
          method,
          path,
          details['operationId'],
        );

        final returnType = repositoryReturnType(details, usedEntities, schemas);
        final params = generateParameters(details, components, usedEntities);

        buffer.writeln(
          '  Future<Either<Failure, $returnType>> $funcName($params);',
        );
      });
    });

    buffer.writeln('}');
    return RepositoryGenerateResult(buffer.toString(), usedEntities);
  }
}

class RepositoryGenerateResult {
  final String code;
  final Set<String> usedEntities;

  RepositoryGenerateResult(this.code, this.usedEntities);
}