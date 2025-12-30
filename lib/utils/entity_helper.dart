import 'package:swagen/utils/string_map.dart';

bool isDomainEntity(String name, Map<String, dynamic> schema) {
  final lower = name.toLowerCase();

  if (lower.contains('request') || lower.contains('dto')) {
    return false;
  }

  if (schema['type'] != 'object' || schema['properties'] == null) {
    return false;
  }

  final props = schema['properties'] as Map<String, dynamic>;

  if (props.length == 1 && props.containsKey('message')) {
    return false;
  }

  return true;
}

String resolveEntityName(String schemaName) {
  if (schemaName.endsWith('Response')) {
    return schemaName.replaceFirst('Response', '');
  }
  return schemaName;
}

Set<String> resolveEntityDependencies(
  String entityName,
  Map<String, dynamic> schemas,
  Set<String> visited,
) {
  if (visited.contains(entityName)) return {};

  visited.add(entityName);

  final schema = schemas[entityName];
  if (schema == null) return {};

  final props = asStringMap(schema['properties']) ?? {};
  final deps = <String>{};

  for (final value in props.values) {
    if (value['\$ref'] != null) {
      final ref = value['\$ref'].split('/').last;
      deps.add(ref);
      deps.addAll(resolveEntityDependencies(ref, schemas, visited));
    }

    if (value['type'] == 'array') {
      final items = value['items'];
      if (items != null && items['\$ref'] != null) {
        final ref = items['\$ref'].split('/').last;
        deps.add(ref);
        deps.addAll(resolveEntityDependencies(ref, schemas, visited));
      }
    }
  }

  return deps;
}
