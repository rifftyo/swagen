import 'package:swagen/utils/string_case.dart';

String generateMethodName(String method, String path, String? operationId) {
  if (operationId != null && operationId.isNotEmpty) {
    return operationId.camelCase;
  }

  var cleanPath =
      path.split('/').where((p) => p.isNotEmpty).map((p) {
        if (p.startsWith('{') && p.endsWith('}')) {
          return 'By${p.substring(1, p.length - 1).pascalCase}';
        }
        return p.pascalCase;
      }).join();

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
