import 'package:swagen/utils/map_type.dart';
import 'package:swagen/utils/request_params.dart';
import 'package:swagen/utils/resolve_component_parameter.dart';
import 'package:swagen/utils/unique_params.dart';

ParameterGenerateResult generateParameters(
  Map<String, dynamic> details,
  Map<String, dynamic> components,
) {
  final usedEntities = <String>{};

  final schemas = components['schemas'] ?? {};

  final rawParams = (details['parameters'] as List?) ?? [];
  final params = resolveParameters(rawParams, components);
  final pathParams = params.where((p) => p['in'] == 'path').toList();
  final queryParams = params.where((p) => p['in'] == 'query').toList();

  final bodyParams = extractRequestParams(details, schemas, usedEntities);

  final usedNames = <String>{};

  final dartParams = [
    ...pathParams.map((p) {
      final schema = p['schema'] as Map<String, dynamic>?;
      final type = mapType(schema);
      final name = makeUniqueParamName(p['name'], usedNames);
      return "$type $name";
    }),
    ...queryParams.map((p) {
      final schema = p['schema'] as Map<String, dynamic>?;
      final type = mapType(schema);
      final isRequired = p['required'] == true;
      final name = makeUniqueParamName(p['name'], usedNames);
      return isRequired ? "$type $name" : "$type? $name";
    }),
    ...bodyParams.map((p) {
      final paramName = p.split(' ').last.replaceAll('?', '');
      final uniqueName = makeUniqueParamName(paramName, usedNames);
      return p.replaceFirst(paramName, uniqueName);
    }),
  ].join(", ");

  return ParameterGenerateResult(dartParams, usedEntities);
}

class ParameterGenerateResult {
  final String params;
  final Set<String> usedEntities;
  final Set<String> usedModels;

  ParameterGenerateResult(
    this.params,
    this.usedEntities, [
    Set<String>? usedModels,
  ]) : usedModels = usedModels ?? {};
}
