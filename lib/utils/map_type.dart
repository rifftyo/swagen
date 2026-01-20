import 'package:swagen/utils/string_map.dart';

String mapType(Map<String, dynamic>? schema) {
  if (schema == null) return 'dynamic';

  if (schema['\$ref'] != null) {
    return schema['\$ref'].split('/').last;
  }

  final type = schema['type'];

  switch (type) {
    case 'string':
      switch (schema['format']) {
        case 'date-time':
          return 'DateTime';
        case 'binary':
          return 'File';
        default:
          return 'String';
      }

    case 'integer':
      return 'int';
    case 'boolean':
      return 'bool';

    case 'number':
      return 'double';

    case 'array':
      final items = asStringMap(schema['items']);
      return 'List<${mapType(items)}>';

    case 'object':
      if (schema['additionalProperties'] != null) {
        final additional = asStringMap(schema['additionalProperties']);
        return 'Map<String, ${mapType(additional)}>';
      }
      return 'Map<String, dynamic>';

    default:
      return 'dynamic';
  }
}
