import 'package:swagen/utils/camel_case_convert.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/request_params.dart';

class RepositoryGenerator {
  final String projectName;

  RepositoryGenerator(this.projectName);

  String generateRepository(
    String className,
    Map<String, dynamic> paths,
    Map<String, dynamic> componentsSchemas,
  ) {
    final buffer = StringBuffer();
    final imports = <String>{};
    bool needsFile = false;

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        _extractReturnType(details, path, imports);
        _generateParameters(details, componentsSchemas, imports);
        if (_useFile(details, componentsSchemas, imports)) {
          needsFile = true;
        }
      });
    });

    if (needsFile) {
      buffer.writeln("import 'dart:io';");
    }

    buffer.writeln("import 'package:dartz/dartz.dart';");
    buffer.writeln("import 'package:$projectName/common/failure.dart';");

    for (var imp in imports) {
      buffer.writeln(
        "import 'package:$projectName/data/models/${imp.toLowerCase()}.dart';",
      );
    }

    buffer.writeln();
    buffer.writeln('abstract class ${className}Repository {');

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final funcName = _generateMethodName(
          method,
          path,
          details['operationId'],
        );

        final returnType = _extractReturnType(details, path, imports);
        final params = _generateParameters(details, componentsSchemas, imports);

        buffer.writeln(
          '  Future<Either<Failure, $returnType>> $funcName($params);',
        );
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
    final pathParams = params.where((p) => p['in'] == 'path').toList();
    final queryParams = params.where((p) => p['in'] == 'query').toList();

    final bodyParams = extractRequestParams(
      details,
      componentsSchemas,
      imports,
    );

    final dartParams = [
      ...pathParams.map((p) {
        final schema = p['schema'] as Map<String, dynamic>?;
        final type = mapType(schema);
        final name = p['name'];
        return "$type $name";
      }),
      ...queryParams.map((p) {
        final schema = p['schema'] as Map<String, dynamic>?;
        final type = mapType(schema);
        final name = p['name'];
        final isRequired = p['required'] == true;

        return isRequired ? "$type $name" : "$type? $name";
      }),
      ...bodyParams,
    ].join(", ");

    return dartParams;
  }

  bool _useFile(
    Map<String, dynamic> details,
    Map<String, dynamic> componentsSchemas,
    Set<String> imports,
  ) {
    bool usesFile = false;

    final bodyParams = extractRequestParams(
      details,
      componentsSchemas,
      imports,
    );

    for (final param in bodyParams) {
      if (param.contains('File')) {
        usesFile = true;
      }
    }
    return usesFile;
  }

  String _generateMethodName(String method, String path, String? operationId) {
    if (operationId != null && operationId.isNotEmpty) {
      return camelCaseConvert(operationId);
    }

    final cleanPath =
        path
            .replaceAll(RegExp(r'\{|\}'), '')
            .split('/')
            .where((e) => e.isNotEmpty)
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join();

    switch (method.toLowerCase()) {
      case 'get':
        return 'get$cleanPath';
      case 'post':
        return 'create$cleanPath';
      case 'put':
        return 'update$cleanPath';
      case 'delete':
        return 'delete$cleanPath';
      default:
        return '${method.toLowerCase()}$cleanPath';
    }
  }

  String _extractReturnType(
    Map<String, dynamic> details,
    String path,
    Set<String> imports,
  ) {
    final responses = details['responses'] as Map<String, dynamic>?;
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

    if (schema['type'] != null) {
      return mapType(schema);
    }

    return 'dynamic';
  }
}
