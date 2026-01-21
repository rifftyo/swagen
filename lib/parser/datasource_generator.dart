import 'package:swagen/parser/swagger_parser.dart';
import 'package:swagen/utils/file_usage_detector.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/method_name_generator.dart';
import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/request_params.dart';
import 'package:swagen/utils/resolve_component_parameter.dart';
import 'package:swagen/utils/string_case.dart';
import 'package:swagen/utils/unique_params.dart';

class DatasourceGenerator {
  final Map<String, Map<String, dynamic>> _inlineSchemas = {};
  final String projectName;
  final Set<String> _usedModels = {};
  final Set<String> _collectedModels = {};

  Set<String> get usedImports => _usedModels;
  Map<String, Map<String, dynamic>> get inlineSchemas => _inlineSchemas;

  DatasourceGenerator(this.projectName);

  void resetImports() {
    _usedModels.clear();
  }

  bool isSdkImport(String name) {
    return name.contains(':');
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
        if (useFile(details, components, _usedModels)) {
          needsFile = true;
        }
      });
    });

    final abstractClass = _generateAbstractClass(
      paths,
      components,
      featureName,
    );
    final implClass = _generateImplClass(
      paths,
      baseUrl,
      components,
      parser,
      featureName,
    );
    final imports = _generateImports(needsFile, featureName);

    return "$imports\n\n$abstractClass\n\n$implClass";
  }

  String _generateImports(bool needsFile, String featureName) {
    final buffer = StringBuffer();

    buffer.writeln("// ignore_for_file: constant_identifier_names");

    buffer.writeln();

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

    if (_usedModels.isNotEmpty) {
      for (var model in _usedModels) {
        if (isSdkImport(model)) continue;

        if (_collectedModels.contains(model)) {
          buffer.writeln(
            "import 'package:$projectName/features/$featureName/domain/entities/${model.snakeCase}.dart';",
          );
        } else {
          buffer.writeln(
            "import 'package:$projectName/features/$featureName/data/models/${model.snakeCase}.dart';",
          );
        }
      }
    }

    return buffer.toString();
  }

  String _generateAbstractClass(
    Map<String, dynamic> paths,
    Map<String, dynamic> components,
    String featureName,
  ) {
    final schemas = components['schemas'];
    final buffer = StringBuffer();
    final List<String> methodSignatures = [];
    final List<String> returnTypes = [];

    buffer.writeln(
      "abstract class ${featureName.capitalize}RemoteDataSource {",
    );

    paths.forEach((path, methods) {
      methods.forEach((method, details) {
        final funcName = generateMethodName(
          method,
          path,
          details['operationId'],
        );
        final returnType = _extractReturnType(details, path);
        returnTypes.add(returnType);

        final rawParams = (details['parameters'] as List?) ?? [];
        final params = resolveParameters(rawParams, components);

        final pathParams = params.where((p) => p['in'] == 'path').toList();
        final queryParams = params.where((p) => p['in'] == 'query').toList();
        final bodyParams = extractRequestParams(
          details,
          schemas,
          _collectedModels,
        );

        final usedNames = <String>{};

        final dartParams = [
          ...pathParams.map((p) {
            final schema = p['schema'] as Map<String, dynamic>?;
            final type = mapType(schema);
            final name = makeUniqueParamName(p['name'], usedNames);
            return "$type $name";
          }),
          ...queryParams.map((p) {
            final schema = p['schema'] as Map<String, dynamic>?;
            final type = mapType(schema);
            final isRequired = p['required'] == true;
            final name = makeUniqueParamName(p['name'], usedNames);
            return isRequired ? "$type $name" : "$type? $name";
          }),
          ...bodyParams.map((p) {
            final paramName = p.split(' ').last.replaceAll('?', '');
            final uniqueName = makeUniqueParamName(paramName, usedNames);
            return p.replaceFirst(paramName, uniqueName);
          }),
        ].join(", ");

        methodSignatures.add(dartParams);
        buffer.writeln("  Future<$returnType> $funcName($dartParams);");
      });
    });

    final Set<String> actuallyUsedModels = {};
    for (final model in _collectedModels) {
      final regex = RegExp(r'\b' + model + r'\b');
      final usedInParams = methodSignatures.any((sig) => regex.hasMatch(sig));
      final usedInReturn = returnTypes.any((ret) => regex.hasMatch(ret));

      if (usedInParams || usedInReturn) {
        actuallyUsedModels.add(model);
      }
    }

    _usedModels.clear();
    _usedModels.addAll(actuallyUsedModels);

    buffer.writeln("}");
    return buffer.toString();
  }

  String _generateImplClass(
    Map<String, dynamic> paths,
    String? baseUrl,
    Map<String, dynamic> components,
    SwaggerParser parser,
    String featureName,
  ) {
    final schemas = components['schemas'] ?? {};

    final buffer = StringBuffer();

    buffer.writeln(
      "class ${featureName.capitalize}RemoteDataSourceImpl implements ${featureName.capitalize}RemoteDataSource {",
    );
    buffer.writeln("  static const BASE_URL = '${baseUrl ?? ''}';");
    buffer.writeln("  static const tokenKey = 'access_token';");
    buffer.writeln();
    buffer.writeln("  final http.Client client;");
    buffer.writeln("  final FlutterSecureStorage storage;");
    buffer.writeln();
    buffer.writeln(
      "  ${featureName.capitalize}RemoteDataSourceImpl({required this.client, required this.storage});",
    );

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
    Future<dynamic> _handleResponse(http.Response response) async {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return null;
        }
        return jsonDecode(response.body);
      } else {
        if (response.body.isNotEmpty) {
          final jsonMap = jsonDecode(response.body);
          throw ServerException(jsonMap['message'] ?? 'Unknown Error');
        }
        throw ServerException('Unknown Error');
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

        final bodyParams = extractRequestParams(details, schemas, _usedModels);

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

        final usedNames = <String>{};

        final dartParams = [
          ...pathParams.map((p) {
            final schema = p['schema'] as Map<String, dynamic>?;
            final type = mapType(schema);
            final name = makeUniqueParamName(p['name'], usedNames);
            return "$type $name";
          }),
          ...queryParams.map((p) {
            final schema = p['schema'] as Map<String, dynamic>?;
            final type = mapType(schema);
            final isRequired = p['required'] == true;
            final name = makeUniqueParamName(p['name'], usedNames);
            return isRequired ? "$type $name" : "$type? $name";
          }),
          ...bodyParams.map((p) {
            final paramName = p.split(' ').last.replaceAll('?', '');
            final uniqueName = makeUniqueParamName(paramName, usedNames);
            return p.replaceFirst(paramName, uniqueName);
          }),
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
          bool isSchemaObjectBody = false;

          // 🔥 DETEKSI BODY MODEL
          if (bodyParams.length == 1) {
            final param = bodyParams.first;
            final type = param.split(' ').first;

            // Jika tipe adalah MODEL, ubah entity -> Response -> JSON
            if (_usedModels.contains(type)) {
              isSchemaObjectBody = true;
              final name = param.split(' ').last.replaceAll('?', '');
              bodyString =
                  "jsonEncode(${type}Response.fromEntity($name).toJson())";
            }
          }

          if (!isSchemaObjectBody && bodyParams.isNotEmpty) {
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
      return 'void';
    }

    if (content['\$ref'] != null) {
      final ref = content['\$ref'].split('/').last;
      final responseName = asResponse(ref);
      _usedModels.add(responseName);
      return responseName;
    }

    if (content['type'] == 'array' && content['items']?['\$ref'] != null) {
      final ref = content['items']['\$ref'].split('/').last;
      final wrapperName =
          '${ref.toString().pascalCase.pluralToSingular}ListResponse';
      _usedModels.add(wrapperName);
      return wrapperName;
    }

    if (content['type'] == 'object' && content['properties'] != null) {
      final baseName = buildBaseName(path).pascalCase;
      final className = '${baseName}Response';

      _usedModels.add(className);

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
      final type = valueSchema['type'];

      if (type == 'integer') {
        return 'Map<String, int>';
      } else if (type == 'string') {
        return 'Map<String, String>';
      } else if (type == 'boolean') {
        return 'Map<String, bool>';
      }

      final valueType = mapType(valueSchema['schema']);
      return 'Map<String, $valueType>';
    }

    if (content['type'] != null) {
      return mapType(content);
    }

    return 'dynamic';
  }
}
