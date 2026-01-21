import 'dart:io';
import 'package:swagen/utils/string_case.dart';

class InjectorGenerator {
  final String packageName;

  InjectorGenerator(this.packageName);

  void generate(Map<String, List<String>> features, String outputPath) {
    final buffer = StringBuffer();

    buffer.writeln('import \'package:get_it/get_it.dart\';');
    buffer.writeln('import \'package:http/http.dart\' as http;');
    buffer.writeln(
      'import \'package:flutter_secure_storage/flutter_secure_storage.dart\';',
    );

    for (final feature in features.entries) {
      final featureName = feature.key.toLowerCase();

      for (final className in feature.value) {
        final usecasePath =
            'lib/features/$featureName/domain/usecases/${className.snakeCase}.dart';
        if (File(usecasePath).existsSync()) {
          buffer.writeln(
            "import 'package:$packageName/features/$featureName/domain/usecases/${className.snakeCase}.dart';",
          );
        }

        final providerPath =
            'lib/features/$featureName/presentation/providers/${className.snakeCase}_provider.dart';
        if (File(providerPath).existsSync()) {
          buffer.writeln(
            'import \'package:$packageName/features/$featureName/presentation/providers/${className.snakeCase}_provider.dart\';',
          );
        }

        final repoDomainPath =
            'lib/features/$featureName/domain/repositories/${featureName}_repository.dart';
        if (File(repoDomainPath).existsSync()) {
          buffer.writeln(
            "import 'package:$packageName/features/$featureName/domain/repositories/${featureName}_repository.dart';",
          );
        }

        final repoImplPath =
            'lib/features/$featureName/data/repositories/${featureName}_repository.dart';
        if (File(repoImplPath).existsSync()) {
          buffer.writeln(
            "import 'package:$packageName/features/$featureName/data/repositories/${featureName}_repository.dart';",
          );
        }

        final dataSourcePath =
            'lib/features/$featureName/data/datasources/${featureName}_remote_data_source.dart';
        if (File(dataSourcePath).existsSync()) {
          buffer.writeln(
            "import 'package:$packageName/features/$featureName/data/datasources/${featureName}_remote_data_source.dart';",
          );
        }
      }
      buffer.writeln();
    }

    buffer.writeln('final sl = GetIt.instance;\n');
    buffer.writeln('void init() {');

    buffer.writeln();

    // ===== REPOSITORY =====
    buffer.writeln('  // repositories');
    for (final feature in features.entries) {
      final featureName = feature.key.toLowerCase();
      final className = featureName.pascalCase;

      final repoDomain = File(
        'lib/features/$featureName/domain/repositories/${featureName}_repository.dart',
      );
      final repoImpl = File(
        'lib/features/$featureName/data/repositories/${featureName}_repository.dart',
      );

      if (repoDomain.existsSync() && repoImpl.existsSync()) {
        buffer.writeln(
          '  sl.registerLazySingleton<${className}Repository>('
          '() => ${className}RepositoryImpl(remoteDataSource: sl()));',
        );
      }
    }

    buffer.writeln();

    // ===== USECASE =====
    buffer.writeln('  // usecases');
    for (final feature in features.entries) {
      final featureName = feature.key.toLowerCase();

      for (final className in feature.value) {
        final usecaseClass = className.pascalCase;

        final usecaseFile = File(
          'lib/features/$featureName/domain/usecases/${className.snakeCase}.dart',
        );

        if (usecaseFile.existsSync()) {
          buffer.writeln(
            '  sl.registerLazySingleton<$usecaseClass>(() => $usecaseClass(sl()));',
          );
        }
      }
    }

    buffer.writeln();

    // ===== PROVIDER =====
    buffer.writeln('  // provider');
    for (final feature in features.entries) {
      final featureName = feature.key.toLowerCase();

      for (final className in feature.value) {
        final providerClass = '${className.pascalCase}Provider';
        final useCaseParamName = '${className.camelCase}UseCase';

        final providerFile = File(
          'lib/features/$featureName/presentation/providers/${className.snakeCase}_provider.dart',
        );

        if (providerFile.existsSync()) {
          buffer.writeln(
            '  sl.registerFactory<$providerClass>(() => '
            '$providerClass($useCaseParamName: sl()));',
          );
        }
      }
    }

    buffer.writeln();

    // ===== REMOTE DATA SOURCE =====
    buffer.writeln('  // data sources');
    for (final feature in features.entries) {
      final featureName = feature.key.toLowerCase();

      final dataSourceFile = File(
        'lib/features/$featureName/data/datasources/${featureName}_remote_data_source.dart',
      );

      if (dataSourceFile.existsSync()) {
        buffer.writeln(
          ' sl.registerLazySingleton<${featureName.pascalCase}RemoteDataSource>(() => ${featureName.pascalCase}RemoteDataSourceImpl(client: sl(), storage: sl()));',
        );
      }
    }

    buffer.writeln();

    // external
    buffer.writeln('sl.registerLazySingleton(() => http.Client());');
    buffer.writeln('sl.registerLazySingleton(() => FlutterSecureStorage());');

    buffer.writeln('}');
    Directory(outputPath).createSync(recursive: true);
    File('$outputPath/injection.dart').writeAsStringSync(buffer.toString());
  }
}
