import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:swagen/utils/string_case.dart';
import 'package:yaml/yaml.dart';

class SwaggerParser {
  final Map<String, dynamic> swagger;

  SwaggerParser(this.swagger);

  factory SwaggerParser.fromFile(String path) {
    final content = File(path).readAsStringSync();
    if (path.endsWith('.yaml') || path.endsWith('.yml')) {
      final yamlMap = loadYaml(content);
      return SwaggerParser(_convertYamlToMap(yamlMap));
    }

    return SwaggerParser(jsonDecode(content));
  }

  static Future<SwaggerParser> fromUrl(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load swagger from URL (${response.statusCode})',
      );
    }

    return SwaggerParser(_parseContent(response.body, url));
  }

  static Map<String, dynamic> _parseContent(String content, String source) {
    if (source.endsWith('.yaml') || source.endsWith('.yml')) {
      return _convertYamlToMap(loadYaml(content));
    }

    if (content.trim().startsWith('{')) {
      return jsonDecode(content);
    }

    return _convertYamlToMap(loadYaml(content));
  }

  Map<String, dynamic> getComponents() {
    return swagger['components'] ?? {};
  }

  Map<String, dynamic> getSchemas() {
    return getComponents()['schemas'] ?? {};
  }

  Map<String, dynamic> getPaths() {
    return swagger['paths'] ?? {};
  }

  String? getBaseUrl() {
    final servers = swagger['servers'] as List?;
    if (servers != null && servers.isNotEmpty) {
      return servers.first['url'];
    }
    return null;
  }

  bool useSecurity({required Map pathItem, required String method}) {
    final operationSecurity = pathItem[method]?['security'];
    if (operationSecurity is List) {
      return operationSecurity.isNotEmpty;
    }

    final globalSecurity = swagger['security'];
    return globalSecurity is List && globalSecurity.isNotEmpty;
  }

  Map<String, dynamic> extractInlineResponseSchemas() {
    final paths = getPaths();
    final Map<String, dynamic> inlineSchemas = {};

    paths.forEach((path, methods) {
      final cleanPath =
          path
              .split('/')
              .where(
                (segment) => segment.isNotEmpty && !segment.startsWith('{'),
              )
              .join('')
              .capitalize;

      final defaultModelName =
          cleanPath.isNotEmpty ? '${cleanPath}Response' : 'GenericResponse';

      methods.forEach((method, details) {
        final responses = details['responses'] ?? {};
        responses.forEach((code, responseDetail) {
          final schema =
              responseDetail['content']?['application/json']?['schema'];
          final description = responseDetail['description'] ?? '';

          if (schema == null) {
            inlineSchemas[defaultModelName] = {
              "type": "object",
              "properties": {
                "message": {
                  "type": "string",
                  "description":
                      description.isNotEmpty
                          ? description
                          : "Operation completed successfully",
                },
              },
            };
            return;
          }

          if (schema['type'] == 'object' && schema['\$ref'] == null) {
            inlineSchemas[defaultModelName] = schema;
          } else if (schema['type'] == 'array' &&
              schema['items']?['\$ref'] != null) {
            final ref = schema['items']['\$ref'].split('/').last;
            final listModelName =
                '${ref.toString().pluralToSingular}ListResponse';

            inlineSchemas[listModelName] = {
              "type": "object",
              "properties": {
                "items": {
                  "type": "array",
                  "items": {"\$ref": "#/components/schemas/$ref"},
                },
              },
            };
          } else if (schema['type'] == 'array' &&
              schema['items'] != null &&
              schema['items']['\$ref'] == null &&
              schema['items']['type'] == 'object') {
            final listModelName = '${defaultModelName}ItemListResponse';
            final itemModelName = '${defaultModelName}Item';

            inlineSchemas[itemModelName] = schema['items'];
            inlineSchemas[listModelName] = {
              "type": "object",
              "properties": {
                "items": {
                  "type": "array",
                  "items": {"\$ref": "#/components/schemas/$itemModelName"},
                },
              },
            };
          }
        });
      });
    });

    return inlineSchemas;
  }

  static Map<String, dynamic> _convertYamlToMap(YamlMap yamlMap) {
    return _yamlToDart(yamlMap) as Map<String, dynamic>;
  }

  static dynamic _yamlToDart(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map(
          (e) => MapEntry(e.key.toString(), _yamlToDart(e.value)),
        ),
      );
    }
    if (yaml is YamlList) {
      return yaml.map(_yamlToDart).toList();
    }
    return yaml;
  }
}
