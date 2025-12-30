import 'package:swagen/utils/model_naming.dart';
import 'package:swagen/utils/string_case.dart';

class MapperGenerator {
  final Set<String> _imports = {};

  Set<String> get usedImports => _imports;

  String generateMapper(String responseName, Map<String, dynamic> schema) {
    _imports.clear();

    final entityName = asEntity(responseName);
    final props = schema['properties'] as Map<String, dynamic>;

    final buffer = StringBuffer();

    buffer.writeln('extension ${responseName}Mapper on $responseName {');
    buffer.writeln('  $entityName toEntity() {');
    buffer.writeln('    return $entityName(');

    props.forEach((key, value) {
      final fieldName = key.camelCase;
      if (value['\$ref'] != null) {
        final ref = value['\$ref'].toString().split('/').last;
        final responseRef = asResponse(ref);
        _imports.add(responseRef);
        buffer.writeln('      $fieldName: $fieldName.toEntity(),');
      } else if (value['type'] == 'array' && value['items']?['\$ref'] != null) {
        final ref = value['items']['\$ref'].split('/').last;
        final responseRef = asResponse(ref);
        _imports.add(responseRef);
        buffer.writeln(
          '      $fieldName: $fieldName.map((e) => e.toEntity()).toList(),',
        );
      } else {
        buffer.writeln('      $fieldName: $fieldName,');
      }
    });

    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  String generateWithImports(
    String schemaName,
    Map<String, dynamic> schema,
    String featureName,
    String projectName,
  ) {
    final responseName = asResponse(schemaName);
    final mapperCode = generateMapper(responseName, schema);

    final buffer = StringBuffer();

    buffer.writeln(
      "import 'package:$projectName/features/$featureName/data/models/${responseName.snakeCase}.dart';",
    );
    buffer.writeln(
      "import 'package:$projectName/features/$featureName/domain/entities/${asEntity(responseName).snakeCase}.dart';",
    );

    for (final imp in _imports) {
      buffer.writeln(
        "import 'package:$projectName/features/$featureName/data/mappers/${imp.snakeCase}_mapper.dart';",
      );
    }

    buffer.writeln();
    buffer.writeln(mapperCode);

    return buffer.toString();
  }
}
