// class RepositoryGenerator {
//   final Set<String> _imports = {};
//   final String projectName;

//   Set<String> get usedImports => _imports;

//   RepositoryGenerator(this.projectName);

//   String _generateImports() {
//     final buffer = StringBuffer();

//     buffer.writeln("import 'dart:io';");

//     buffer.writeln();

//     buffer.writeln("import 'package:dartz/dartz.dart';");
//     buffer.writeln("import 'package:$projectName/common/failure.dart';");
//     if (_imports.isNotEmpty) {
//       for (var imp in _imports) {
//         buffer.writeln(
//           "import 'package:$projectName/data/models/${imp.toLowerCase()}.dart';",
//         );
//       }
//     }

//     return buffer.toString();
//   }

//   Map<String, String> generateRepositories(Map<String, dynamic> paths) {
//     final Map<String, List<_RepoMethod>> groupedByTag = {};

//     paths.forEach((path, methods) {
//       if (methods is! Map) return;

//       methods.forEach((httpMethod, detail) {
//         final tags = detail['tags'] as List?;
//         if (tags == null || tags.isEmpty) return;

//         final tag = tags.first.toString();
//         groupedByTag.putIfAbsent(tag, () => []);

//         final methodName = detail['operationId'];
//         final responseSchema = _extractResponseSchmea(detail);

//         if (responseSchema != null) {
//           _imports.add(responseSchema);
//         }

//         groupedByTag[tag]!.add(
//           _RepoMethod(name: methodName, returnType: responseSchema ?? 'void'),
//         );
//       });
//     });

//     final Map<String, String> result = {};

//     groupedByTag.forEach((tag, methods) {
//       final className = '${tag}Repository';

//       final buffer = StringBuffer();
//       buffer.write(_generateImports());

//       buffer.writeln('abstract class $className {');

//       for (var m in methods) {
//         buffer.writeln(
//           '    Future<Either<Failure, ${m.returnType}>> ${m.name}();',
//         );
//       }

//       buffer.writeln('}');
//       result[tag.toLowerCase()] = buffer.toString();
//     });

//     return result;
//   }

//   String? _extractResponseSchmea(Map<String, dynamic> detail) {
//     final responses = detail['responses'];
//     if (responses is! Map) return null;

//     for (var res in responses.values) {
//       final content = res['content'];
//       if (content == null) continue;

//       final json = content['application/json'];
//       if (json == null) continue;

//       final schema = json['schema'];
//       if (schema == null) continue;

//       if (schema['\$ref'] != null) {
//         return schema['\$ref'].toString().split('/').last;
//       }
//     }

//     return null;
//   }
// }

// class _RepoMethod {
//   final String name;
//   final String returnType;

//   _RepoMethod({required this.name, required this.returnType});
// }
