import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/utils/file_usage_detector.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/method_name_generator.dart';
import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/request_params.dart';
import 'package:swagen/utils/resolve_component_parameter.dart';
import 'package:swagen/utils/string_case.dart';

class DatasourceGenerator {
  final Set<String> _imports = {};
  final Map<String, Map<String, dynamic>> _inlineSchemas = {};
  final String projectName;

  Set<String> get usedImports => _imports;
  Map<String, Map<String, dynamic>> get inlineSchemas => _inlineSchemas;

  DatasourceGenerator(this.projectName);

  void resetImports() {
    _imports.clear();
  }

  String generatorDataSource(
    Map<String, dynamic> paths,
    String? baseUrl,
    Map<String, dynamic> components,
    SwaggerParser parser,
    String featureName,
  ) {
    bool needsFile = false;

    paths.forEach((path, methods) {
      methods.forEach((_, details) {
        if (useFile(details, components, _imports)) {
          needsFile = true;
        }
      });
    });

    final abstractClass = _generateAbstractClass(paths, components);
    final implClass = _generateImplClass(paths, baseUrl, components, parser);
    final imports = _generateImports(needsFile, featureName);

    return "$imports\n\n$abstractClass\n\n$implClass";
  }

  String _generateImports(bool needsFile, String featureName) {
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
    buffer.writeln("import 'package:$projectName/core/error/exception.dart';");
    if (_imports.isNotEmpty) {
      for (var imp in _imports) {
        buffer.writeln(
          "import 'package:$projectName/features/$featureName/data/models/${imp.snakeCase}.dart';",
        );
      }
    }

    return buffer.toString();
  }

  String _generateAbstractClass(
    Map<String, dynamic> paths,
    Map<String, dynamic> components,
  ) {
    final schemas = components['schemas'];

    final buffer = StringBuffer();

    buffer.writeln("abstract class RemoteDataSource {");

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final funcName = generateMethodName(
          method,
          path,
          details['operationId'],
        );
        final returnType = _extractReturnType(details, path);

        final rawParams = (details['parameters'] as List?) ?? [];
        final params = resolveParameters(rawParams, components);

        final pathParams = params.where((p) => p['in'] == 'path').toList();
        final queryParams = params.where((p) => p['in'] == 'query').toList();

        final bodyParams = extractRequestParams(details, schemas, _imports);

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
    Map<String, dynamic> components,
    SwaggerParser parser,
  ) {
    final schemas = components['schemas'] ?? {};

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
        final funcName = generateMethodName(
          method,
          path,
          details['operationId'],
        );
        final returnType = _extractReturnType(details, path);
        final returnStatement = _generateReturnStatement(returnType);

        final rawParams = (details['parameters'] as List?) ?? [];
        final params = resolveParameters(rawParams, components);

        final pathParams = params.where((p) => p['in'] == 'path').toList();
        final queryParams = params.where((p) => p['in'] == 'query').toList();

        final bodyParams = extractRequestParams(details, schemas, _imports);

        String? contentType;

        final requestBody = details['requestBody'];
        if (requestBody != null) {
          final content = requestBody['content'];

          if (content != null) {
            if (content['multipart/form-data'] != null) {
              contentType = 'multipart/form-data';
            } else if (content['application/x-www-form-urlencoded'] != null) {
              contentType = 'application/x-www-form-urlencoded';
            } else if (content['application/json'] != null) {
              contentType = 'application/json';
            }
          }
        }

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

        final queryMap =
            queryParams.isNotEmpty
                ? '''
    final uri = Uri.parse('\$BASE_URL$replacedPath').replace(
      queryParameters: {
        ${queryParams.map((p) {
                  final name = p['name'];
                  return "if ($name != null) '$name': $name.toString(),";
                }).join('\n        ')}
      },
    );
'''
                : '''
    final uri = Uri.parse('\$BASE_URL$replacedPath');
''';

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
    $queryMap
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
    if ($f != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          '$f',
          $f.path,
          filename: $f.path.split('/').last,
        ),
      );
    }
''',
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
    $queryMap
    final response = await client.${method.toLowerCase()}(
      uri,
      headers: await _getHeaders(
        withAuth: $secured,
        ${contentType == 'application/x-www-form-urlencoded' ? 'isFormUrlEncoded: true,' : ''}
      ),
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

  String _extractReturnType(Map<String, dynamic> details, [String? path]) {
    final responses = details['responses'] as Map<String, dynamic>?;
    final okResponse =
        responses?['200'] ??
        responses?['201'] ??
        responses?['202'] ??
        responses?['204'];

    if (okResponse == null) return 'dynamic';

    final content = okResponse['content']?['application/json']?['schema'];

    String buildBaseName(String? path) {
      if (path == null || path.isEmpty) return 'Generic';

      final cleanPath = path.capitalize
          .split('/')
          .where((segment) => segment.isNotEmpty && !segment.startsWith('{'))
          .join('');

      return cleanPath.isNotEmpty ? cleanPath.pascalCase : 'Generic';
    }

    if (content == null) {
      final baseName = buildBaseName(path).pascalCase;
      final className = '${baseName}Response';
      _imports.add(className);
      return className;
    }

    if (content['\$ref'] != null) {
      final ref = content['\$ref'].split('/').last;
      final responseName = asResponse(ref);
      _imports.add(responseName);
      return responseName;
    }

    if (content['type'] == 'array' && content['items']?['\$ref'] != null) {
      final ref = content['items']['\$ref'].split('/').last;
      final wrapperName =
          '${ref.toString().pascalCase.pluralToSingular}ListResponse';
      _imports.add(wrapperName);
      return wrapperName;
    }

    if (content['type'] == 'object' && content['properties'] != null) {
      final baseName = buildBaseName(path).pascalCase;
      final className = '${baseName}Response';

      _imports.add(className);

      _inlineSchemas[className] = {
        'type': 'object',
        'properties': content['properties'],
      };
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
}
