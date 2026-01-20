import 'package:swagen/utils/dartz_import_helper.dart';
import 'package:swagen/utils/method_name_generator.dart';
import 'package:swagen/utils/parameter_generator.dart';
import 'package:swagen/utils/repository_return_type.dart';
import 'package:swagen/utils/string_case.dart';

class RepositoryImplGenerator {
  final String projectName;

  RepositoryImplGenerator(this.projectName);

  bool isDartSdkType(String type) {
    return type.contains(':') || type == 'File' || type == 'DateTime';
  }

  String generateRepositoryImpl(
    String className,
    Map<String, dynamic> paths,
    Map<String, dynamic> components,
  ) {
    final buffer = StringBuffer();

    final usedEntities = <String>{};
    final schemas = components['schemas'] ?? {};
    final featureFolder = className.snakeCase;

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        final result = repositoryReturnTypeResult(details, schemas);
        usedEntities.addAll(result.entities);

        final paramResult = generateParameters(details, components);
        usedEntities.addAll(paramResult.usedEntities);
      });
    });

    buffer.writeln("import 'dart:io';");
    buffer.writeln(dartzImport(usedEntities));
    buffer.writeln("import 'package:$projectName/core/error/failure.dart';");
    buffer.writeln("import 'package:$projectName/core/error/exception.dart';");

    buffer.writeln(
      "import 'package:$projectName/features/$featureFolder/data/datasources/remote_data_source.dart';",
    );

    buffer.writeln(
      "import 'package:$projectName/features/$featureFolder/domain/repositories/${className.snakeCase}_repository.dart';",
    );

    for (final entity in usedEntities) {
      if (isDartSdkType(entity)) continue;

      buffer.writeln(
        "import 'package:$projectName/features/$featureFolder/domain/entities/${entity.snakeCase}.dart';",
      );
    }

    buffer.writeln();
    buffer.writeln(
      'class ${className}RepositoryImpl extends ${className}Repository {',
    );

    buffer.writeln('  final RemoteDataSource remoteDataSource;');
    buffer.writeln();
    buffer.writeln(
      '  ${className}RepositoryImpl({required this.remoteDataSource});',
    );

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final funcName = generateMethodName(
          method,
          path,
          details['operationId'],
        );

        final result = repositoryReturnTypeResult(details, schemas);

        final paramResult = generateParameters(details, components);
        final params = paramResult.params;

        final paramNames = params
            .split(',')
            .map((e) => e.trim().split(' ').last)
            .where((e) => e.isNotEmpty)
            .join(', ');

        buffer.writeln();
        buffer.writeln('  @override');
        buffer.writeln(
          '  Future<Either<Failure, ${result.type}>> $funcName($params) async {',
        );
        buffer.writeln('    try {');

        if (result.type == 'Unit') {
          buffer.writeln(
            '      await remoteDataSource.$funcName($paramNames);',
          );
          buffer.writeln('      return const Right(unit);');
        } else {
          buffer.writeln(
            '      final response = await remoteDataSource.$funcName($paramNames);',
          );

          if (result.needsMapper) {
            if (result.type.startsWith('List')) {
              final listField = result.listField ?? 'items';
              buffer.writeln(
                '      return right(response.$listField.map((e) => e.toEntity()).toList());',
              );
            } else if ([
              'String',
              'int',
              'double',
              'bool',
            ].contains(result.type)) {
              final field = result.firstField ?? 'message';
              buffer.writeln('      return right(response.$field);');
            } else {
              buffer.writeln('      return right(response.toEntity());');
            }
          } else {
            buffer.writeln('      return right(response);');
          }
        }

        buffer.writeln('    } on ServerException catch (e) {');
        buffer.writeln('      return left(ServerFailure(e.message));');
        buffer.writeln('    } on SocketException {');
        buffer.writeln(
          "      return left(ConnectionFailure('Failed to connect to the network'));",
        );
        buffer.writeln('    }');
        buffer.writeln('  }');
      });
    });

    buffer.writeln('}');
    return buffer.toString();
  }
}
