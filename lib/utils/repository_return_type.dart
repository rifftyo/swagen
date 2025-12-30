import 'package:swagen/utils/entity_helper.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/string_map.dart';

String repositoryReturnType(
  Map<String, dynamic> details,
  Set<String> usedEntities,
  Map<String, dynamic> componentsSchemas,
) {
  final responses = asStringMap(details['responses']);
  if (responses == null) return 'Unit';

  final ok = responses['200'] ?? responses['201'] ?? responses['202'];

  final okMap = asStringMap(ok);
  if (okMap == null) return 'Unit';

  final content = asStringMap(okMap['content']);
  final appJson = asStringMap(content?['application/json']);
  final schema = asStringMap(appJson?['schema']);

  if (schema == null) return 'Unit';

  // ===== $ref =====
  if (schema['\$ref'] != null) {
    final model = schema['\$ref'].toString().split('/').last;
    final resolvedSchema = asStringMap(componentsSchemas[model]);

    if (isSinglePrimitiveWrapper(resolvedSchema)) {
      final props = asStringMap(resolvedSchema!['properties']);
      final value = asStringMap(props!.values.first);
      return mapType(value);
    }

    final entity = resolveEntityName(model);
    usedEntities.add(entity);
    return entity;
  }

  // ===== array =====
  if (schema['type'] == 'array') {
    final items = asStringMap(schema['items']);
    if (items?['\$ref'] != null) {
      final model = items!['\$ref'].toString().split('/').last;
      final entity = resolveEntityName(model);
      usedEntities.add(entity);
      return 'List<$entity>';
    }
    return 'List<${mapType(items)}>';
  }

  if (schema['type'] == 'object' && schema['properties'] != null) {
    final props = asStringMap(schema['properties']);

    // case: paginated response { data: [], meta: {} }
    if (props?['data'] != null) {
      final dataSchema = asStringMap(props!['data']);

      // data: array of $ref
      if (dataSchema?['type'] == 'array') {
        final items = asStringMap(dataSchema!['items']);
        if (items?['\$ref'] != null) {
          final model = items!['\$ref'].toString().split('/').last;
          final entity = resolveEntityName(model);
          usedEntities.add(entity);

          return 'List<$entity>';
        }
      }
    }
  }

  if (schema['type'] != null) {
    return mapType(schema);
  }

  return 'dynamic';
}

bool isSinglePrimitiveWrapper(Map<String, dynamic>? schema) {
  if (schema == null) return false;

  final props = asStringMap(schema['properties']);
  if (props == null || props.length != 1) return false;

  final value = asStringMap(props.values.first);
  if (value == null) return false;

  return value['type'] != null && value['\$ref'] == null;
}
