import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/string_case.dart';

class EntityGenerator {
  String generateEntity(String name, Map<String, dynamic> schema) {
    final props = schema['properties'] as Map<String, dynamic>;
    final buffer = StringBuffer();
    final imports = <String>{};

    props.forEach((key, value) {
      if (value['\$ref'] != null) {
        final ref = value['\$ref'].split('/').last;
        imports.add(ref);
      }

      if (value['type'] == 'array') {
        final items = value['items'];
        if (items != null && items['\$ref'] != null) {
          final ref = items['\$ref'].split('/').last;
          imports.add(ref);
        }
      }
    });

    for (final imp in imports) {
      buffer.writeln("import '${imp.snakeCase}.dart';");
    }

    if (imports.isNotEmpty) buffer.writeln();

    buffer.writeln('class $name {');

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
      } else if (value['\$ref'] != null) {
        type = value['\$ref'].split('/').last;
      } else {
        type = mapType(value);
      }

      buffer.writeln('  final $type ${key.camelCase};');
    });

    buffer.writeln();
    buffer.write('  const $name({');
    props.forEach((key, _) {
      buffer.write('required this.${key.camelCase}, ');
    });
    buffer.writeln('});');

    buffer.writeln('}');
    return buffer.toString();
  }
}
