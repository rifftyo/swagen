String mapType(String? swaggerType, {Map<String, dynamic>? schema}) {
  if (schema?['\$ref'] != null) {
    return schema!['\$ref'].split('/').last;
  }

  switch (swaggerType) {
    case 'string':
      if (schema?['format'] == 'date-time') return 'DateTime';
      return 'String';

    case 'integer':
      return 'int';

    case 'boolean':
      return 'bool';

    case 'number':
      return 'double';

    case 'array':
      final items = schema?['items'] as Map<String, dynamic>?;
      if (items == null) return 'List<dynamic>';
      final itemType = mapType(items['type'], schema: items);
      return 'List<$itemType>';

    case 'object':
      if (schema?['additionalProperties'] != null) {
        final valueSchema =
            schema!['additionalProperties'] as Map<String, dynamic>;
        final valueType = mapType(valueSchema['type'], schema: valueSchema);
        return 'Map<String, $valueType>';
      }

      return 'Map<String, dynamic>';

    default:
      return 'dynamic';
  }
}
