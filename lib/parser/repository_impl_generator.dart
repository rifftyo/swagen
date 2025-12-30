import 'package:swagen/parser/entitiy_generator.dart';
import 'package:swagen/utils/method_name_generator.dart';
import 'package:swagen/utils/parameter_generator.dart';
import 'package:swagen/utils/repository_return_type.dart';
import 'package:swagen/utils/string_case.dart';

class RepositoryImplGenerator {
  final String projectName;

  RepositoryImplGenerator(this.projectName);

  String generateRepositoryImpl(
    String className,
    Map<String, dynamic> paths,
    Map<String, dynamic> components,
  ) {
    final buffer = StringBuffer();

    final imports = <String>{};
    final featureFolder = className.snakeCase;
    final schemas = components['schemas'];

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        repositoryReturnType(details, imports, schemas);
        generateParameters(details, components, imports);
      });
    });

    buffer.writeln("import 'dart:io';");

    buffer.writeln("import 'package:dartz/dartz.dart';");
    buffer.writeln("import 'package:$projectName/core/error/failure.dart';");
    buffer.writeln("import 'package:$projectName/core/error/exception.dart';");
    buffer.writeln(
      "import 'package:$projectName/features/$featureFolder/data/datasources/remote_data_source.dart';",
    );

    final repoFile = '${className.snakeCase}_repository.dart';
    buffer.writeln(
      "import 'package:$projectName/features/$featureFolder/domain/repositories/$repoFile';",
    );

    for (final imp in imports) {
      buffer.writeln(
        "import 'package:$projectName/features/$featureFolder/domain/entities/${imp.snakeCase}.dart';",
      );
    }

    for (final imp in imports) {
      buffer.writeln(
        "import 'package:$projectName/features/$featureFolder/data/mappers/${imp.snakeCase}_response_mapper.dart';",
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

        final returnType = repositoryReturnType(details, imports, schemas);
        final params = generateParameters(details, components, imports);

        final paramNames = params
            .split(',')
            .map((e) => e.trim().split(' ').last)
            .where((e) => e.isNotEmpty)
            .join(', ');

        final isListResponse = _isListResponse(returnType);
        final paginated = isPaginatedResponse(details);

        final responseSchema =
            details['responses']?['200']?['content']?['application/json']?['schema'];

        buffer.writeln();
        buffer.writeln('  @override');
        buffer.writeln(
          '  Future<Either<Failure, $returnType>> $funcName($params) async {',
        );
        buffer.writeln('    try {');
        buffer.writeln(
          '      final response = await remoteDataSource.$funcName($paramNames);',
        );

        if (isListResponse) {
          if (paginated) {
            buffer.writeln(
              '      return right(response.data.map((e) => e.toEntity()).toList());',
            );
          } else {
            buffer.writeln(
              '      return right(response.items.map((e) => e.toEntity()).toList());',
            );
          }
        } else if (_isPrimitive(returnType)) {
          final ref = responseSchema['\$ref'].split('/').last;
          final field = _getPrimaryField(ref, schemas);

          buffer.writeln('      return right(response.$field);');
        } else {
          buffer.writeln('      return right(response.toEntity());');
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

  bool _isListResponse(String returnType) {
    return returnType.startsWith('List');
  }

  bool _isPrimitive(String type) {
    return ['String', 'int', 'double', 'bool'].contains(type);
  }

  String _getPrimaryField(String schemaName, Map<String, dynamic> schemas) {
    final schema = schemas[schemaName];
    final props = schema?['properties'] as Map<String, dynamic>?;

    if (props == null || props.isEmpty) {
      throw Exception('Schema $schemaName has no properties');
    }

    return props.keys.first.camelCase;
  }
}
