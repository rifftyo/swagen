import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/string_case.dart';
import 'package:swagen/utils/string_map.dart';

List<String> extractRequestParams(
  Map<String, dynamic> details,
  Map<String, dynamic> componentsSchemas,
  Set<String> imports, [
  Set<String>? usedModels,
]) {
  final bodyParams = <String>[];
  usedModels ??= <String>{};

  final requestBody = details['requestBody'];
  if (requestBody == null) return bodyParams;

  final content = asStringMap(requestBody['content']);
  if (content == null) return bodyParams;

  // =========================
  // 🔥 MULTIPART / FORM-DATA
  // =========================
  final multipart = asStringMap(content['multipart/form-data']);
  if (multipart != null) {
    final schema = asStringMap(multipart['schema']);
    final properties = asStringMap(schema?['properties']) ?? {};

    for (final entry in properties.entries) {
      final name = entry.key;
      final prop = asStringMap(entry.value);

      if (prop?['format'] == 'binary') {
        // FILE PARAM
        imports.add('dart:io');
        bodyParams.add('File $name');
      } else {
        final type = mapType(prop);
        bodyParams.add('$type $name');
      }
    }

    return bodyParams;
  }

  // =========================
  // 🟢 APPLICATION / JSON
  // =========================
  final appJson = asStringMap(content['application/json']);
  final schema = asStringMap(appJson?['schema']);
  if (schema == null) return bodyParams;

  if (schema['\$ref'] != null) {
    final refName = schema['\$ref'].split('/').last;
    final refSchema = asStringMap(componentsSchemas[refName]);

    if (refSchema != null &&
        isPrimitiveOnlySchema(refSchema, componentsSchemas)) {
      final properties = asStringMap(refSchema['properties']) ?? {};
      final required = (refSchema['required'] as List?)?.cast<String>() ?? [];

      properties.forEach((name, propSchema) {
        final prop = asStringMap(propSchema);
        final isRequired = required.contains(name);
        final type = mapType(prop);
        bodyParams.add('${isRequired ? type : '$type?'} $name');
      });

      return bodyParams;
    }

    imports.add(refName);
    usedModels.add(refName);
    bodyParams.add('$refName ${refName.toString().camelCase}');
    return bodyParams;
  }

  return bodyParams;
}

bool isPrimitiveOnlySchema(
  Map<String, dynamic> schema,
  Map<String, dynamic> componentsSchemas,
) {
  final properties = asStringMap(schema['properties']);
  if (properties == null) return true;

  for (final prop in properties.values) {
    final propSchema = asStringMap(prop);

    if (propSchema?['\$ref'] != null) return false;

    if (propSchema?['type'] == 'array' &&
        asStringMap(propSchema?['items'])?['\$ref'] != null) {
      return false;
    }
  }

  return true;
}
