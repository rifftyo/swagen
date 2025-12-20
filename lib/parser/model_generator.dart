import 'package:swagen/utils/map_type.dart';

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
          _imports.add(ref);
        }
      } else if (value['\$ref'] != null) {
        final ref = value['\$ref'].split('/').last;
        _imports.add(ref);
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
          type = 'List<$ref>';
        } else {
          type = 'List<${mapType(items)}>';
        }
        buffer.writeln('  final $type $key;');
      } else if (value['\$ref'] != null) {
        final ref = value['\$ref'].split('/').last;
        type = ref;
        buffer.writeln('  final $type $key;');
      } else {
        type = mapType(value);
        buffer.writeln('  final $type $key;');
      }
    });

    buffer.writeln();

    // constructor
    buffer.write('  const $name({');
    props.forEach((key, _) => buffer.write('required this.$key, '));
    buffer.writeln('});');

    buffer.writeln();

    // fromJson
    buffer.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return $name(');
    props.forEach((key, value) {
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          final ref = items['\$ref'].split('/').last;
          buffer.writeln(
            "      $key: (json['$key'] as List).map((e) => $ref.fromJson(e)).toList(),",
          );
        } else {
          final itemType = mapType(items);
          buffer.writeln(
            "      $key: (json['$key'] as List).map((e) => e as $itemType).toList(),",
          );
        }
      } else {
        buffer.writeln("      $key: json['$key'],");
      }
    });
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln();

    // toJson
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    return {');
    props.forEach((key, value) {
      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          buffer.writeln("      '$key': $key.map((e) => e.toJson()).toList(),");
        } else {
          buffer.writeln("      '$key': $key,");
        }
      } else {
        buffer.writeln("      '$key': $key,");
      }
    });
    buffer.writeln('    };');
    buffer.writeln('  }');

    buffer.writeln('}');
    return buffer.toString();
  }

  String generateWithImports(String name, Map<String, dynamic> schema) {
    _imports.clear();
    final classCode = generateClass(name, schema);
    final buffer = StringBuffer();

    if (_imports.isNotEmpty) {
      for (var imp in _imports) {
        final fileName = imp.toLowerCase();
        if (fileName != name.toLowerCase()) {
          buffer.writeln("import '$fileName.dart';");
        }
      }
      buffer.writeln();
    }

    buffer.writeln(classCode);

    return buffer.toString();
  }
}
