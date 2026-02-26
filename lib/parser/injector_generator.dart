import 'dart:io';
import 'package:swagen/utils/string_case.dart';

class InjectorGenerator {
  final String packageName;

  InjectorGenerator(this.packageName);

  void generateFeatureInjector({
    required String featureName,
    required List<String> classes,
  }) {
    final buffer = StringBuffer();
    final pascalFeature = featureName.pascalCase;

    buffer.writeln("import 'package:get_it/get_it.dart';");

    // ===== IMPORTS =====
    for (final className in classes) {
      final snake = className.snakeCase;

      final usecasePath =
          'lib/features/$featureName/domain/usecases/$snake.dart';
      if (File(usecasePath).existsSync()) {
        buffer.writeln(
          "import 'package:$packageName/features/$featureName/domain/usecases/$snake.dart';",
        );
      }

      final providerPath =
          'lib/features/$featureName/presentation/providers/${snake}_provider.dart';
      if (File(providerPath).existsSync()) {
        buffer.writeln(
          "import 'package:$packageName/features/$featureName/presentation/providers/${snake}_provider.dart';",
        );
      }
    }

    buffer.writeln(
      "import 'package:$packageName/features/$featureName/domain/repositories/${featureName}_repository.dart';",
    );
    buffer.writeln(
      "import 'package:$packageName/features/$featureName/data/repositories/${featureName}_repository.dart';",
    );
    buffer.writeln(
      "import 'package:$packageName/features/$featureName/data/datasources/${featureName}_remote_data_source.dart';",
    );

    buffer.writeln('\nfinal sl = GetIt.instance;\n');
    buffer.writeln('void init${pascalFeature}Injector() {');

    // ===== DATA SOURCE =====
    buffer.writeln('// Data Source');
    buffer.writeln(
      '  sl.registerLazySingleton<${pascalFeature}RemoteDataSource>('
      '() => ${pascalFeature}RemoteDataSourceImpl(client: sl(), storage: sl()));',
    );
    buffer.writeln();

    // ===== REPOSITORY =====
    buffer.writeln('// Repository');
    buffer.writeln(
      '  sl.registerLazySingleton<${pascalFeature}Repository>('
      '() => ${pascalFeature}RepositoryImpl(remoteDataSource: sl()));',
    );
    buffer.writeln();

    buffer.writeln('// UseCase & Provider');
    // ===== USE CASE & PROVIDER =====
    for (final className in classes) {
      final pascal = className.pascalCase;
      final camel = className.camelCase;

      final usecaseFile = File(
        'lib/features/$featureName/domain/usecases/${className.snakeCase}.dart',
      );

      if (usecaseFile.existsSync()) {
        buffer.writeln(
          '  sl.registerLazySingleton<$pascal>(() => $pascal(sl()));',
        );
      }

      final providerFile = File(
        'lib/features/$featureName/presentation/providers/${className.snakeCase}_provider.dart',
      );

      if (providerFile.existsSync()) {
        buffer.writeln(
          '  sl.registerFactory<${pascal}Provider>(() => '
          '${pascal}Provider(${camel}UseCase: sl()));',
        );
      }
    }

    buffer.writeln('}');

    final path = 'lib/features/$featureName/injector.dart';
    Directory('lib/features/$featureName').createSync(recursive: true);
    File(path).writeAsStringSync(buffer.toString());
  }
}
