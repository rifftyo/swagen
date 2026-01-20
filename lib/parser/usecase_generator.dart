import 'package:swagen/utils/dartz_import_helper.dart';
import 'package:swagen/utils/string_case.dart';

class UseCaseGenerator {
  final String projectName;

  UseCaseGenerator(this.projectName);

  String generate({
    required String featureName,
    required String repositoryName,
    required String methodName,
    required String returnType,
    required List<String> parameters,
    required Set<String> usedEntities,
    required bool needsFile,
  }) {
    final className = methodName.pascalCase;
    final paramsSignature = parameters.join(', ');
    final paramsCall = parameters.map((p) => p.split(' ').last).join(', ');

    final buffer = StringBuffer();

    if (needsFile) {
      buffer.writeln("import 'dart:io';");
    }

    buffer.writeln(dartzImport(usedEntities));
    buffer.writeln("import 'package:$projectName/core/error/failure.dart';");

    final usedInUseCase = <String>{};

    for (final entity in usedEntities) {
      if (returnType.contains(entity)) {
        usedInUseCase.add(entity);
      }
    }

    for (final param in parameters) {
      for (final entity in usedEntities) {
        if (param.contains(entity)) {
          usedInUseCase.add(entity);
        }
      }
    }

    for (final entity in usedInUseCase) {
      buffer.writeln(
        "import 'package:$projectName/features/$featureName/domain/entities/${entity.snakeCase}.dart';",
      );
    }

    buffer.writeln(
      "import 'package:$projectName/features/$featureName/domain/repositories/${repositoryName.snakeCase}.dart';\n",
    );

    buffer.writeln('class $className {');
    buffer.writeln('  final $repositoryName repository;\n');
    buffer.writeln('  $className(this.repository);\n');
    buffer.writeln(
      '  Future<Either<Failure, $returnType>> execute($paramsSignature) {',
    );
    buffer.writeln('    return repository.$methodName($paramsCall);');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }
}
