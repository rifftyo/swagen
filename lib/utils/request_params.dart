import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/string_map.dart';

List<String> extractRequestParams(
  Map<String, dynamic> details,
  Map<String, dynamic> componentsSchemas,
  Set<String> imports,
) {
  final bodyParams = <String>[];

  final requestBody = details['requestBody'];
  if (requestBody == null) return bodyParams;

  final content = asStringMap(requestBody['content']);

  final appJson = asStringMap(content?['application/json']);
  final appForm = asStringMap(content?['application/x-www-form-urlencoded']);
  final multipartForm = asStringMap(content?['multipart/form-data']);

  dynamic schema;

  if (appJson != null) {
    schema = appJson['schema'];
  } else if (appForm != null) {
    schema = appForm['schema'];
  } else if (multipartForm != null) {
    schema = multipartForm['schema'];
  }

  if (schema == null || schema is bool) return bodyParams;

  if (schema['\$ref'] != null) {
    final refName = schema['\$ref'].split('/').last;

    final refSchema = componentsSchemas[refName];

    if (refSchema != null && refSchema['properties'] != null) {
      final props = asStringMap(refSchema['properties']) ?? {};
      final required = (refSchema['required'] as List?)?.cast<String>() ?? [];

      props.forEach((name, propSchema) {
        final isRequired = required.contains(name);

        if (propSchema['format'] == 'binary') {
          bodyParams.add("File${isRequired ? '' : '?'} $name");
          return;
        }

        if (propSchema['type'] == 'array') {
          final items = asStringMap(propSchema['items']);

          if (items?['\$ref'] != null) {
            final refName = items!['\$ref'].split('/').last;
            imports.add(refName);
            bodyParams.add(
              "${isRequired ? 'List<$refName>' : 'List<$refName>?'} $name",
            );
            return;
          }

          final itemType = mapType(items);
          bodyParams.add(
            "${isRequired ? 'List<$itemType>' : 'List<$itemType>?'} $name",
          );
          return;
        }

        if (propSchema['\$ref'] != null) {
          final refName = propSchema['\$ref'].split('/').last;
          imports.add(refName);

          bodyParams.add("${isRequired ? refName : '$refName?'} $name");
          return;
        }

        final type = mapType(propSchema);
        bodyParams.add("${isRequired ? type : '$type?'} $name");
      });
    }
  } else if (schema['properties'] != null) {
    final props = asStringMap(schema['properties']) ?? {};
    final required = (schema['required'] as List?)?.cast<String>() ?? [];

    props.forEach((name, propSchema) {
      final isRequired = required.contains(name);

      if (propSchema['format'] == 'binary') {
        bodyParams.add("File${isRequired ? '' : '?'} $name");
      } else {
        final type = mapType(propSchema);
        bodyParams.add("${isRequired ? type : '$type?'} $name");
      }
    });
  }

  return bodyParams;
}
