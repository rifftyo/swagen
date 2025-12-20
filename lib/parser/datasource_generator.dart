import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/utils/camel_case_convert.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/request_params.dart';

class DatasourceGenerator {
  final Set<String> _imports = {};
  final String projectName;

  Set<String> get usedImports => _imports;

  DatasourceGenerator(this.projectName);

  String generatorDataSource(
    Map<String, dynamic> paths,
    String? baseUrl,
    Map<String, dynamic> componentsSchemas,
    SwaggerParser parser,
  ) {
    bool needsFile = false;

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        if (_useFile(details, componentsSchemas, _imports)) {
          needsFile = true;
        }
      });
    });

    final abstractClass = _generateAbstractClass(paths, componentsSchemas);
    final implClass = _generateImplClass(
      paths,
      baseUrl,
      componentsSchemas,
      parser,
    );
    final imports = _generateImports(needsFile);

    return "$imports\n\n$abstractClass\n\n$implClass";
  }

  String _generateImports(bool needsFile) {
    final buffer = StringBuffer();

    buffer.writeln("import 'dart:convert';");

    if (needsFile) {
      buffer.writeln("import 'dart:io';");
    }

    buffer.writeln("import 'package:http/http.dart' as http;");
    buffer.writeln(
      "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
    );
    buffer.writeln();
    buffer.writeln("import 'package:$projectName/common/exception.dart';");
    if (_imports.isNotEmpty) {
      for (var imp in _imports) {
        buffer.writeln(
          "import 'package:$projectName/data/models/${imp.toLowerCase()}.dart';",
        );
      }
    }

    return buffer.toString();
  }

  String _generateAbstractClass(
    Map<String, dynamic> paths,
    Map<String, dynamic> componentsSchemas,
  ) {
    final buffer = StringBuffer();

    buffer.writeln("abstract class RemoteDataSource {");

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final funcName = _generateMethodName(
          method,
          path,
          details['operationId'],
        );
        final returnType = _extractReturnType(details, path);

        final params = (details['parameters'] as List?) ?? [];
        final pathParams = params.where((p) => p['in'] == 'path').toList();
        final queryParams = params.where((p) => p['in'] == 'query').toList();

        final bodyParams = extractRequestParams(
          details,
          componentsSchemas,
          _imports,
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

        buffer.writeln("  Future<$returnType> $funcName($dartParams);");
      });
    });

    buffer.writeln("}");

    return buffer.toString();
  }

  String _generateImplClass(
    Map<String, dynamic> paths,
    String? baseUrl,
    Map<String, dynamic> componentsSchemas,
    SwaggerParser parser,
  ) {
    final buffer = StringBuffer();

    buffer.writeln("class RemoteDataSourceImpl implements RemoteDataSource {");
    buffer.writeln("  static const BASE_URL = '${baseUrl ?? ''}';");
    buffer.writeln("  static const tokenKey = 'access_token';");
    buffer.writeln();
    buffer.writeln("  final http.Client client;");
    buffer.writeln("  final FlutterSecureStorage storage;");
    buffer.writeln();
    buffer.writeln("  RemoteDataSourceImpl(this.client, this.storage);");

    buffer.writeln();
    buffer.writeln('''
  Future<Map<String, String>> _getHeaders({
    bool withAuth = false,
    bool isMultipart = false,
    bool isFormUrlEncoded = false,
  }) async {
    final headers = <String, String>{};

    if (!isMultipart) {
      if (isFormUrlEncoded) {
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
      } else {
        headers['Content-Type'] = 'application/json';
      }
    }

    if (withAuth) {
      final token = await storage.read(key: tokenKey);
      if (token != null) {
        headers['Authorization'] = 'Bearer \$token';
      }
    }

    return headers;
  }
''');
    buffer.writeln('''
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final jsonMap = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonMap;
    } else {
      final errorMessage = jsonMap['message'] ?? 'Unknown Error';
      throw ServerException(errorMessage);
    }
  }
''');
    buffer.writeln();
    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final secured = parser.useSecurity(pathItem: methods, method: method);
        final funcName = _generateMethodName(
          method,
          path,
          details['operationId'],
        );
        final returnType = _extractReturnType(details, path);
        final returnStatement = _generateReturnStatement(returnType);

        final params = (details['parameters'] as List?) ?? [];
        final pathParams = params.where((p) => p['in'] == 'path').toList();
        final queryParams = params.where((p) => p['in'] == 'query').toList();

        final bodyParams = extractRequestParams(
          details,
          componentsSchemas,
          _imports,
        );
        String? contentType;

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

        String replacedPath = path;
        for (var p in pathParams) {
          replacedPath = replacedPath.replaceAll(
            "{${p['name']}}",
            "\$${p['name']}",
          );
        }

        final queryString =
            queryParams.isNotEmpty
                ? "?${queryParams.map((p) => "${p['name']}=\$${p['name']}").join("&")}"
                : "";

        if (contentType == 'multipart/form-data') {
          final fields =
              bodyParams
                  .where((bp) => !bp.contains('File'))
                  .map((bp) => bp.split(' ').last.replaceAll('?', ''))
                  .toList();

          final files =
              bodyParams
                  .where((bp) => bp.contains('File'))
                  .map((bp) => bp.split(' ').last.replaceAll('?', ''))
                  .toList();

          final hasFields = fields.isNotEmpty;
          final hasFiles = files.isNotEmpty;

          buffer.writeln('''
  @override
  Future<$returnType> $funcName($dartParams) async {
    final uri = Uri.parse('\$BASE_URL$replacedPath$queryString');
    final request = http.MultipartRequest('${method.toUpperCase()}', uri);
    final headers = await _getHeaders(
      withAuth: $secured,
      isMultipart: true,
    );
    request.headers.addAll(headers);
''');

          if (hasFields) {
            buffer.writeln('''
    request.fields.addAll({
      ${fields.map((f) => "'$f': $f,").join('\n      ')}
    });
''');
          }

          if (hasFiles) {
            buffer.writeln(
              files
                  .map(
                    (f) => '''
    request.files.add(
      await http.MultipartFile.fromPath(
        '$f',
        $f.path,
        filename: $f.path.split('/').last,
      ),
    );''',
                  )
                  .join('\n'),
            );
          }

          buffer.writeln('''
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    $returnStatement
  }
''');
        } else {
          String bodyString = '';
          if (bodyParams.isNotEmpty) {
            final bodyMap = bodyParams
                .map((bp) {
                  final paramName = bp.split(' ').last.replaceAll('?', '');
                  return "'$paramName': $paramName";
                })
                .join(",");

            if (contentType == 'application/json') {
              bodyString = "jsonEncode({$bodyMap})";
            } else if (contentType == 'application/x-www-form-urlencoded') {
              bodyString = "{$bodyMap}";
            }
          }

          buffer.writeln('''
  @override
  Future<$returnType> $funcName($dartParams) async {
    final response = await client.${method.toLowerCase()}(
      Uri.parse('\$BASE_URL$replacedPath$queryString'),
      headers: await _getHeaders(
        withAuth: $secured,
        ${contentType == 'application/x-www-form-urlencoded' ? 'isFormUrlEncoded: true,' : ''}),
        ${bodyString.isNotEmpty ? 'body: $bodyString,' : ''}
    );
    $returnStatement
  }
''');
        }
      });
    });
    buffer.writeln("}");

    return buffer.toString();
  }

  String _generateReturnStatement(String returnType) {
    final isList = returnType.startsWith('List<');
    final isVoid = returnType == 'void';
    final isMap = returnType.startsWith('Map<');
    final isPrimitive = const {
      'String',
      'int',
      'bool',
      'double',
      'num',
      'dynamic',
    }.contains(returnType);

    if (isVoid) {
      return '''
    await _handleResponse(response);
    return;
''';
    }

    if (isPrimitive) {
      return '''
    final result = await _handleResponse(response);
    return result as $returnType;
''';
    }

    if (isList) {
      final itemType = returnType.substring(5, returnType.length - 1);

      return '''
    final jsonMap = await _handleResponse(response);
    return (jsonMap as List)
        .map((e) => $itemType.fromJson(e))
        .toList();
''';
    }

    if (isMap) {
      final valueType =
          returnType.substring(4, returnType.length - 1).split(',')[1].trim();

      return '''
    final result = await _handleResponse(response);
    return Map<String, $valueType>.from(
      (result as Map).map(
        (k, v) => MapEntry(k.toString(), v as $valueType),
      ),
    );
''';
    }

    return '''
    final jsonMap = await _handleResponse(response);
    return $returnType.fromJson(jsonMap);
''';
  }

  String _generateMethodName(String method, String path, String? operationId) {
    if (operationId != null && operationId.isNotEmpty) {
      return camelCaseConvert(operationId);
    }

    var cleanPath =
        path
            .replaceAll(RegExp(r'\{|\}'), '')
            .split('/')
            .where((p) => p.isNotEmpty)
            .map((p) => p[0].toUpperCase() + p.substring(1))
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
      case 'patch':
        return 'patch$cleanPath';
      default:
        return '${method.toLowerCase()}$cleanPath';
    }
  }

  String _extractReturnType(Map<String, dynamic> details, [String? path]) {
    final responses = details['responses'] as Map<String, dynamic>?;
    final okResponse =
        responses?['200'] ??
        responses?['201'] ??
        responses?['202'] ??
        responses?['204'];

    if (okResponse == null) return 'dynamic';

    final content = okResponse['content']?['application/json']?['schema'];

    String capitalize(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

    String pluralToSingular(String name) =>
        name.endsWith('s') ? name.substring(0, name.length - 1) : name;

    String buildBaseName(String? path) {
      if (path == null || path.isEmpty) return 'Generic';

      final cleanPath = path
          .split('/')
          .where((segment) => segment.isNotEmpty && !segment.startsWith('{'))
          .map(capitalize)
          .join('');

      return cleanPath.isNotEmpty ? cleanPath : 'Generic';
    }

    if (content == null) {
      final baseName = buildBaseName(path);
      final className = '${baseName}Response';
      _imports.add(className);
      return className;
    }

    if (content['\$ref'] != null) {
      final ref = content['\$ref'].split('/').last;
      _imports.add(ref);
      return ref;
    }

    if (content['type'] == 'array' && content['items']?['\$ref'] != null) {
      final ref = content['items']['\$ref'].split('/').last;
      final wrapperName = '${pluralToSingular(ref)}ListResponse';
      _imports.add(wrapperName);
      return wrapperName;
    }

    if (content['type'] == 'object' && content['properties'] != null) {
      final baseName = buildBaseName(path);
      final className = '${baseName}Response';
      _imports.add(className);
      return className;
    }

    if (content['type'] == 'object' &&
        content['additionalProperties'] != null) {
      final valueSchema =
          content['additionalProperties'] as Map<String, dynamic>;

      final valueType = mapType(valueSchema['schema']);

      return 'Map<String, $valueType>';
    }

    if (content['type'] != null) {
      return mapType(content);
    }

    return 'dynamic';
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
}
