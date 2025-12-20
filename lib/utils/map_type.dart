String mapType(Map<String, dynamic>? schema) {
  if (schema == null) return 'dynamic';

  if (schema['\$ref'] != null) {
    return schema['\$ref'].split('/').last;
  }

  final type = schema['type'];

  switch (type) {
    case 'string':
      if (schema['format'] == 'date-time') return 'DateTime';
      if (schema['format'] == 'binary') return 'File';
      return 'String';

    case 'integer':
      return 'int';

    case 'boolean':
      return 'bool';

    case 'number':
      return 'double';

    case 'array':
      final items = schema['items'] as Map<String, dynamic>?;
      return 'List<${mapType(items)}>';

    case 'object':
      if (schema['additionalProperties'] != null) {
        return 'Map<String, ${mapType(schema['additionalProperties'])}>';
      }
      return 'Map<String, dynamic>';

    default:
      return 'dynamic';
  }
}
