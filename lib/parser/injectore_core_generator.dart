import 'dart:io';

import 'package:swagen/utils/string_case.dart';

class MainInjectorGenerator {
  final String packageName;

  MainInjectorGenerator(this.packageName);

  void generate(Set<String> features) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:get_it/get_it.dart';");
    buffer.writeln("import 'package:http/http.dart' as http;");
    buffer.writeln(
      "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
    );

    for (final feature in features) {
      buffer.writeln(
        "import 'package:$packageName/features/$feature/injector.dart';",
      );
    }

    buffer.writeln('\nfinal sl = GetIt.instance;\n');
    buffer.writeln('Future<void> initInjector() async {');

    buffer.writeln('// External Dependencies');
    buffer.writeln('  sl.registerLazySingleton(() => http.Client());');
    buffer.writeln('  sl.registerLazySingleton(() => FlutterSecureStorage());');
    buffer.writeln();

    buffer.writeln('// Feature Injectors');
    for (final feature in features) {
      buffer.writeln('  init${feature.pascalCase}Injector();');
    }

    buffer.writeln('}');

    Directory('lib/core/injector').createSync(recursive: true);
    File(
      'lib/core/injector/injector.dart',
    ).writeAsStringSync(buffer.toString());
  }
}
