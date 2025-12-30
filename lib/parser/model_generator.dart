import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/string_case.dart';

class ModelGenerator {
  final Set<String> _imports = {};

  Set<String> get usedImports => _imports;

  String generateClass(String name, Map<String, dynamic> schema) {
    final props = schema['properties'] as Map<String, dynamic>;
    final buffer = StringBuffer();

    // import
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

    buffer.writeln('class $name {');

    // field
    props.forEach((key, value) {
      String type;
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          final ref = items['\$ref'].split('/').last;
          type = 'List<${asResponse(ref)}>';
        } else {
          type = 'List<${mapType(items)}>';
        }
        final fieldName = key.camelCase;
        buffer.writeln('  final $type $fieldName;');
      } else if (value['\$ref'] != null) {
        final ref = value['\$ref'].split('/').last;
        type = asResponse(ref);
        final fieldName = key.camelCase;
        buffer.writeln('  final $type $fieldName;');
      } else {
        type = mapType(value);
        final fieldName = key.camelCase;
        buffer.writeln('  final $type $fieldName;');
      }
    });

    buffer.writeln();

    // constructor
    buffer.write('  const $name({');
    props.forEach((key, _) => buffer.write('required this.${key.camelCase}, '));
    buffer.writeln('});');

    buffer.writeln();

    // fromJson
    buffer.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return $name(');
    props.forEach((key, value) {
      final fieldName = key.camelCase;
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          final ref = items['\$ref'].split('/').last;
          buffer.writeln(
            "      $fieldName: (json['$key'] as List)"
            ".map((e) => ${asResponse(ref)}.fromJson(e))"
            ".toList(),",
          );
        } else if (value['\$ref'] != null) {
          final ref = value['\$ref'].split('/').last;
          final responseRef = asResponse(ref);
          buffer.writeln(
            "      $fieldName: $responseRef.fromJson(json['$key'] as Map<String, dynamic>),",
          );
        } else {
          final itemType = mapType(items);
          buffer.writeln(
            "      $fieldName: (json['$key'] as List).map((e) => e as $itemType).toList(),",
          );
        }
      } else if (value['\$ref'] != null) {
        final ref = asResponse(value['\$ref'].toString().split('/').last);
        buffer.writeln(
          "      $fieldName: $ref.fromJson(json['$key'] as Map<String, dynamic>),",
        );
      } else {
        buffer.writeln("      $fieldName: json['$key'],");
      }
    });
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln();

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
        buffer.writeln("      '$key': $fieldName.toJson(),");
      } else {
        buffer.writeln("      '$key': $fieldName,");
      }
    });
    buffer.writeln('    };');
    buffer.writeln('  }');

    buffer.writeln('}');
    return buffer.toString();
  }

  String generateWithImports(String schemaName, Map<String, dynamic> schema) {
    _imports.clear();

    final className = asResponse(schemaName);
    final classCode = generateClass(className, schema);

    final buffer = StringBuffer();

    if (_imports.isNotEmpty) {
      for (var imp in _imports) {
        buffer.writeln("import '${imp.snakeCase}.dart';");
      }
      buffer.writeln();
    }

    buffer.writeln(classCode);
    return buffer.toString();
  }
}
