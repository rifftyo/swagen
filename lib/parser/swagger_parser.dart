import 'dart:convert';
import 'dart:io';

class SwaggerParser {
  final Map<String, dynamic> swagger;

  SwaggerParser(this.swagger);

  factory SwaggerParser.fromFile(String path) {
    final content = File(path).readAsStringSync();
    return SwaggerParser(jsonDecode(content));
  }

  Map<String, dynamic> getSchemas() {
    return swagger['components']?['schemas'] ?? {};
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
      final cleanPath = path
          .split('/')
          .where((segment) => segment.isNotEmpty && !segment.startsWith('{'))
          .map(_capitalize)
          .join('');

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
            final listModelName = '${_pluralToSingular(ref)}ListResponse';

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

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _pluralToSingular(String name) {
    if (name.endsWith('s')) {
      return name.substring(0, name.length - 1);
    }
    return name;
  }
}
