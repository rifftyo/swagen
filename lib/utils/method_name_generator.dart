import 'package:swagen/utils/string_case.dart';

String generateMethodName(String method, String path, String? operationId) {
  if (operationId != null && operationId.isNotEmpty) {
    return (operationId.camelCase);
  }

  var cleanPath =
      path
          .replaceAll(RegExp(r'\{|\}'), '')
          .split('/')
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join();

  switch (method.toLowerCase()) {
    case 'get':
      return 'get$cleanPath';
    case 'post':
      return 'create$cleanPath';
    case 'put':
      return 'update$cleanPath';
    case 'delete':
      return 'delete$cleanPath';
    case 'patch':
      return 'patch$cleanPath';
    default:
      return '${method.toLowerCase()}$cleanPath';
  }
}
