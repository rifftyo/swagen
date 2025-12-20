import 'package:swagen/utils/camel_case_convert.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/request_params.dart';
import 'package:swagen/utils/string_case.dart';

class RepositoryImplGenerator {
  final String projectName;

  RepositoryImplGenerator(this.projectName);

  String generateRepositoryImpl(
    String className,
    Map<String, dynamic> paths,
    Map<String, dynamic> componentsSchemas,
  ) {
    final buffer = StringBuffer();
    final imports = <String>{};

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        _extractReturnType(details, imports);
        _generateParameters(details, componentsSchemas, imports);
      });
    });

    buffer.writeln("import 'dart:io';");

    buffer.writeln("import 'package:dartz/dartz.dart';");
    buffer.writeln("import 'package:$projectName/common/failure.dart';");
    buffer.writeln("import 'package:$projectName/common/exception.dart';");
    buffer.writeln(
      "import 'package:$projectName/data/datasources/remote_data_source.dart';",
    );

    final repoFile = '${className.snakeCase}_repository.dart';
    buffer.writeln(
      "import 'package:$projectName/domain/repositories/$repoFile';",
    );

    for (final imp in imports) {
      buffer.writeln(
        "import 'package:$projectName/data/models/${imp.toLowerCase()}.dart';",
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
        final funcName = _generateMethodName(
          method,
          path,
          details['operationId'],
        );

        final returnType = _extractReturnType(details, imports);
        final params = _generateParameters(details, componentsSchemas, imports);

        final paramNames = params
            .split(',')
            .map((e) => e.trim().split(' ').last)
            .where((e) => e.isNotEmpty)
            .join(', ');

        buffer.writeln();
        buffer.writeln('  @override');
        buffer.writeln(
          '  Future<Either<Failure, $returnType>> $funcName($params) async {',
        );
        buffer.writeln('    try {');
        buffer.writeln(
          '      final response = await remoteDataSource.$funcName($paramNames);',
        );
        buffer.writeln('      return right(response);');
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

  String _generateParameters(
    Map<String, dynamic> details,
    Map<String, dynamic> componentsSchemas,
    Set<String> imports,
  ) {
    final params = (details['parameters'] as List?) ?? [];
    final pathParams = params.where((p) => p['in'] == 'path');
    final queryParams = params.where((p) => p['in'] == 'query');

    final bodyParams = extractRequestParams(
      details,
      componentsSchemas,
      imports,
    );

    return [
      ...pathParams.map((p) {
        final type = mapType(p['schema']);
        return '$type ${p['name']}';
      }),
      ...queryParams.map((p) {
        final type = mapType(p['schema']);
        return p['required'] == true
            ? '$type ${p['name']}'
            : '$type? ${p['name']}';
      }),
      ...bodyParams,
    ].join(', ');
  }

  String _generateMethodName(String method, String path, String? operationId) {
    if (operationId != null && operationId.isNotEmpty) {
      return camelCaseConvert(operationId);
    }

    final cleanPath =
        path
            .replaceAll(RegExp(r'[{}]'), '')
            .split('/')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join();

    return switch (method.toLowerCase()) {
      'get' => 'get$cleanPath',
      'post' => 'create$cleanPath',
      'put' => 'update$cleanPath',
      'delete' => 'delete$cleanPath',
      _ => '${method.toLowerCase()}$cleanPath',
    };
  }

  String _extractReturnType(Map<String, dynamic> details, Set<String> imports) {
    final responses = details['responses'];
    final ok = responses?['200'] ?? responses?['201'] ?? responses?['202'];
    if (ok == null) return 'void';

    final schema = ok['content']?['application/json']?['schema'];
    if (schema == null) return 'Unit';

    if (schema['\$ref'] != null) {
      final model = schema['\$ref'].split('/').last;
      imports.add(model);
      return model;
    }

    if (schema['type'] == 'array' && schema['items']?['\$ref'] != null) {
      final model = schema['items']['\$ref'].split('/').last;
      imports.add(model);
      return 'List<$model>';
    }

    return mapType(schema);
  }
}
