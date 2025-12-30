import 'package:swagen/utils/request_params.dart';

bool useFile(
  Map<String, dynamic> details,
  Map<String, dynamic> componentsSchemas,
  Set<String> imports,
) {
  bool usesFile = false;

  final bodyParams = extractRequestParams(details, componentsSchemas, imports);

  for (final param in bodyParams) {
    if (param.contains('File')) {
      usesFile = true;
    }
  }
  return usesFile;
}
