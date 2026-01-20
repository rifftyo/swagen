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

    final schemas = components['schemas'] ?? {};

    bool needsFile = false;

    final Set<String> collectedEntities = {};

    final List<String> methodSignatures = [];
    final List<String> returnTypes = [];

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        // return type
        final result = repositoryReturnTypeResult(details, schemas, );
        collectedEntities.addAll(result.entities);
        returnTypes.add(result.type);

        // parameters
        final paramResult = generateParameters(details, components);
        collectedEntities.addAll(paramResult.usedEntities);
        methodSignatures.add(paramResult.params);

        // file usage
        if (useFile(details, components, collectedEntities)) {
          needsFile = true;
        }
      });
    });

    final Set<String> actuallyUsedEntities = {};

    for (final entity in collectedEntities) {
      final regex = RegExp(r'\b' + entity + r'\b');

      final usedInParams = methodSignatures.any((sig) => regex.hasMatch(sig));
      final usedInReturn = returnTypes.any((ret) => regex.hasMatch(ret));

      if (usedInParams || usedInReturn) {
        actuallyUsedEntities.add(entity);
      }
    }

    if (needsFile) {
      buffer.writeln("import 'dart:io';");
    }

    buffer.writeln(dartzImport(actuallyUsedEntities));
    buffer.writeln("import 'package:$projectName/core/error/failure.dart';");

    final featureFolder = className.snakeCase;

    for (final entity in actuallyUsedEntities) {
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

        final result = repositoryReturnTypeResult(details, schemas);
        final paramResult = generateParameters(details, components);

        buffer.writeln(
          '  Future<Either<Failure, ${result.type}>> '
          '$funcName(${paramResult.params});',
        );
      });
    });

    buffer.writeln('}');

    return RepositoryGenerateResult(buffer.toString(), actuallyUsedEntities);
  }
}

class RepositoryGenerateResult {
  final String code;
  final Set<String> usedEntities;

  RepositoryGenerateResult(this.code, this.usedEntities);
}
