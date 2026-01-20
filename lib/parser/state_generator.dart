import 'dart:io';

class StateGenerator {
  void generate(String outputPath) {
    final content = '''
// ignore: constant_identifier_names
enum RequestState {
  Empty,
  Loading,
  Loaded,
  Error,
}
''';

    File(outputPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
}
