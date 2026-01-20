import 'package:swagen/utils/entity_helper.dart';
import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/string_case.dart';

class ModelGenerator {
  final Set<String> _imports = {};
  final Set<String> _entityImports = {};

  final Set<String> generatedEntities;

  ModelGenerator({required this.generatedEntities});

  Set<String> get usedImports => _imports;

  String generateClass(String name, Map<String, dynamic> schema) {
    final props = schema['properties'] as Map<String, dynamic>;
    final buffer = StringBuffer();

    // import references
    props.forEach((key, value) {
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          final ref = items['\$ref'].split('/').last;
          _imports.add(asResponse(ref));
        }
      } else if (value['\$ref'] != null) {
        final ref = value['\$ref'].split('/').last;
        _imports.add(asResponse(ref));
      }
    });

    // entity import
    final entityName = resolveEntityName(name);
    final hasEntity = entityExists(entityName); // <-- cek entity ada atau tidak
    if (hasEntity && entityName != name) _entityImports.add(entityName);

    buffer.writeln('class $name {');

    // fields
    props.forEach((key, value) {
      String type;
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          type = 'List<${asResponse(items['\$ref'].split('/').last)}>';
        } else {
          type = 'List<${mapType(items)}>';
        }
      } else if (value['\$ref'] != null) {
        type = asResponse(value['\$ref'].split('/').last);
      } else {
        type = mapType(value);
      }
      buffer.writeln('  final $type ${key.camelCase};');
    });

    buffer.writeln();

    // constructor
    buffer.write('  const $name({');
    props.forEach((key, _) => buffer.write('required this.${key.camelCase}, '));
    buffer.writeln('});\n');

    // fromJson
    buffer.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return $name(');
    props.forEach((key, value) {
      final fieldName = key.camelCase;
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          final ref = asResponse(items['\$ref'].split('/').last);
          buffer.writeln(
            "      $fieldName: (json['$key'] as List).map((e) => $ref.fromJson(e)).toList(),",
          );
        } else {
          buffer.writeln(
            "      $fieldName: (json['$key'] as List).map((e) => e as ${mapType(items)}).toList(),",
          );
        }
      } else if (value['\$ref'] != null) {
        final ref = asResponse(value['\$ref'].split('/').last);
        buffer.writeln(
          "      $fieldName: $ref.fromJson(json['$key'] as Map<String, dynamic>),",
        );
      } else {
        buffer.writeln("      $fieldName: json['$key'],");
      }
    });
    buffer.writeln('    );');
    buffer.writeln('  }\n');

    // toJson
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    props.forEach((key, value) {
      final fieldName = key.camelCase;
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          buffer.writeln(
            "      '$fieldName': $fieldName.map((e) => e.toJson()).toList(),",
          );
        } else {
          buffer.writeln("      '$fieldName': $fieldName,");
        }
      } else if (value['\$ref'] != null) {
        buffer.writeln("      '$fieldName': $fieldName.toJson(),");
      } else {
        buffer.writeln("      '$fieldName': $fieldName,");
      }
    });
    buffer.writeln('    };');
    buffer.writeln('  }\n');

    // fromEntity & toEntity hanya dibuat jika entity ada
    if (hasEntity) {
      // fromEntity
      buffer.writeln('  factory $name.fromEntity($entityName entity) {');
      buffer.writeln('    return $name(');
      props.forEach((key, value) {
        final fieldName = key.camelCase;
        if (value['type'] == 'array' && value['items']?['\$ref'] != null) {
          final ref = asResponse(value['items']['\$ref'].split('/').last);
          buffer.writeln(
            "      $fieldName: entity.$fieldName.map((e) => $ref.fromEntity(e)).toList(),",
          );
        } else if (value['\$ref'] != null) {
          final ref = asResponse(value['\$ref'].split('/').last);
          buffer.writeln(
            "      $fieldName: $ref.fromEntity(entity.$fieldName),",
          );
        } else {
          buffer.writeln("      $fieldName: entity.$fieldName,");
        }
      });
      buffer.writeln('    );');
      buffer.writeln('  }\n');

      // toEntity
      buffer.writeln('  $entityName toEntity() {');
      buffer.writeln('    return $entityName(');
      props.forEach((key, value) {
        final fieldName = key.camelCase;
        if (value['type'] == 'array' && value['items']?['\$ref'] != null) {
          buffer.writeln(
            "      $fieldName: $fieldName.map((e) => e.toEntity()).toList(),",
          );
        } else if (value['\$ref'] != null) {
          buffer.writeln("      $fieldName: $fieldName.toEntity(),");
        } else {
          buffer.writeln("      $fieldName: $fieldName,");
        }
      });
      buffer.writeln('    );');
      buffer.writeln('  }\n');
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  bool entityExists(String entityName) {
    return generatedEntities.contains(entityName);
  }

  String generateWithImports(
    String schemaName,
    Map<String, dynamic> schema,
    String featureName,
    String projectName,
  ) {
    _imports.clear();
    _entityImports.clear();

    final className = asResponse(schemaName);
    final classCode = generateClass(className, schema);

    final buffer = StringBuffer();

    for (var imp in _imports) {
      buffer.writeln("import '${imp.snakeCase}.dart';");
    }

    for (var entity in _entityImports) {
      buffer.writeln(
        "import 'package:$projectName/features/$featureName/domain/entities/${entity.snakeCase}.dart';",
      );
    }

    if (_imports.isNotEmpty || _entityImports.isNotEmpty) buffer.writeln();

    buffer.writeln(classCode);
    return buffer.toString();
  }
}
