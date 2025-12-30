import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/request_params.dart';
import 'package:swagen/utils/resolve_component_parameter.dart';
import 'package:swagen/utils/string_map.dart';

String generateParameters(
  Map<String, dynamic> details,
  Map<String, dynamic> components,
  Set<String> usedEntities,
) {
  final schemas = components['schemas'] ?? {};

  final rawParams = (details['parameters'] as List?) ?? [];
  final params = resolveParameters(rawParams, components);
  final pathParams = params.where((p) => p['in'] == 'path').toList();
  final queryParams = params.where((p) => p['in'] == 'query').toList();

  final bodyParams = extractRequestParams(details, schemas, usedEntities);

  final dartParams = [
    ...pathParams.map((p) {
      final schema = asStringMap(p['schema']);
      final type = mapType(schema);
      final name = p['name'];
      return "$type $name";
    }),
    ...queryParams.map((p) {
      final schema = asStringMap(p['schema']);
      final type = mapType(schema);
      final name = p['name'];
      final isRequired = p['required'] == true;

      return isRequired ? "$type $name" : "$type? $name";
    }),
    ...bodyParams,
  ].join(", ");

  return dartParams;
}
