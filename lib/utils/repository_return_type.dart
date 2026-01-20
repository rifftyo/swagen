import 'package:swagen/utils/entity_helper.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/string_map.dart';

ReturnTypeResult repositoryReturnTypeResult(
  Map<String, dynamic> details,
  Map<String, dynamic> componentsSchemas,
) {
  final entities = <String>{};

  final responses = asStringMap(details['responses']);
  if (responses == null) {
    return ReturnTypeResult(type: 'Unit', entities: {}, needsMapper: false);
  }

  final ok = responses['200'] ?? responses['201'] ?? responses['202'];
  final okMap = asStringMap(ok);
  final content = asStringMap(okMap?['content']);
  final appJson = asStringMap(content?['application/json']);
  final schema = asStringMap(appJson?['schema']);

  if (schema == null) {
    return ReturnTypeResult(type: 'Unit', entities: {}, needsMapper: false);
  }

  if (schema['\$ref'] != null) {
    final model = schema['\$ref'].split('/').last;
    final resolved = asStringMap(componentsSchemas[model]);

    if (isSinglePrimitiveWrapper(resolved)) {
      final prop = asStringMap(
        asStringMap(resolved!['properties'])!.values.first,
      );
      final fieldName = asStringMap(resolved['properties'])!.keys.first;
      return ReturnTypeResult(
        type: mapType(prop),
        entities: {},
        needsMapper: true,
        firstField: fieldName,
      );
    }

    final entity = resolveEntityName(model);
    entities.add(entity);

    String? listField;
    String? firstField;

    final props = asStringMap(resolved?['properties']);
    if (props != null) {
      for (final entry in props.entries) {
        final propMap = asStringMap(entry.value);
        if (propMap != null) {
          if (propMap['type'] == 'array' && listField == null) {
            listField = entry.key;
          }
          firstField ??= entry.key;
        }
      }
    }

    return ReturnTypeResult(
      type: entity,
      entities: entities,
      needsMapper: true,
      listField: listField,
      firstField: firstField,
    );
  }

  if (schema['type'] == 'array') {
    final items = asStringMap(schema['items']);

    if (items?['\$ref'] != null) {
      final entity = resolveEntityName(items!['\$ref'].split('/').last);
      entities.add(entity);

      return ReturnTypeResult(
        type: 'List<$entity>',
        entities: entities,
        needsMapper: true,
      );
    }

    return ReturnTypeResult(
      type: 'List<${mapType(items)}>',
      entities: {},
      needsMapper: false,
    );
  }

  if (schema['type'] == 'object') {
    final props = asStringMap(schema['properties']);
    String? listField;
    String? firstField;

    if (props != null) {
      String? metaField;
      props.forEach((key, value) {
        final propMap = asStringMap(value);
        if (propMap == null) return;

        if (propMap['type'] == 'array' && propMap['items']?['\$ref'] != null) {
          final listEntity = resolveEntityName(
            propMap['items']['\$ref'].split('/').last,
          );
          entities.add(listEntity);
          listField ??= key;
          firstField ??= key;
        }

        if (propMap['\$ref'] != null) {
          final entity = resolveEntityName(propMap['\$ref'].split('/').last);
          entities.add(entity);
          if (key == 'meta') metaField = key;
          firstField ??= key;
        }
      });

      if (listField != null && metaField != null) {
        final wrapperEntity = '${entities.first}s';
        return ReturnTypeResult(
          type: wrapperEntity,
          entities: {...entities, wrapperEntity},
          needsMapper: true,
          listField: listField,
          firstField: firstField,
        );
      }
    }

    return ReturnTypeResult(
      type: 'Map<String, dynamic>',
      entities: {},
      needsMapper: false,
    );
  }

  return ReturnTypeResult(
    type: mapType(schema),
    entities: {},
    needsMapper: false,
  );
}

bool isSinglePrimitiveWrapper(Map<String, dynamic>? schema) {
  if (schema == null) return false;

  final props = asStringMap(schema['properties']);
  if (props == null || props.length != 1) return false;

  final value = asStringMap(props.values.first);
  if (value == null) return false;

  return value['type'] != null && value['\$ref'] == null;
}

class ReturnTypeResult {
  final String type;
  final Set<String> entities;
  final bool needsMapper;
  final String? listField;
  final String? firstField;

  ReturnTypeResult({
    required this.type,
    required this.entities,
    required this.needsMapper,
    this.listField,
    this.firstField,
  });
}
