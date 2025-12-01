import 'dart:io';

class ExceptionGenerator {
  void generate(String outputDir) {
    final file = File(outputDir);

    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsStringSync('''
class ServerException implements Exception {
  final String message;

  ServerException(this.message);
}
''');
    }
  }
}
