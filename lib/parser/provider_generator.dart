import 'package:swagen/constant/primitive_types.dart';
import 'package:swagen/utils/string_case.dart';

class ProviderGenerator {
  final String projectName;

  ProviderGenerator(this.projectName);

  bool _isVoidOrUnit(String type) => type == 'void' || type == 'Unit';

  bool _isPrimitive(String type) => primitiveTypes.contains(type);

  bool _hasData(String returnType) =>
      !_isVoidOrUnit(returnType) && !_isPrimitive(returnType);

  bool _needsFileImport(List<ProviderParam> params) {
    return params.any((p) => p.type == 'File');
  }

  String? _extractEntity(String returnType) {
    if (_isVoidOrUnit(returnType) || _isPrimitive(returnType)) {
      return null;
    }

    final listMatch = RegExp(r'List<(\w+)>').firstMatch(returnType);
    if (listMatch != null) {
      final innerType = listMatch.group(1)!;
      return _isPrimitive(innerType) ? null : innerType;
    }

    if (!returnType.contains('<')) {
      return returnType;
    }

    return null;
  }

  String generate({
    required String featureName,
    required String usecaseName,
    required String methodName,
    required List<ProviderParam> params,
    required String returnType,
  }) {
    final providerName = '${usecaseName}Provider';
    final useCaseVar = '${usecaseName.camelCase}UseCase';

    final constructorParams = params
        .map((e) => '${e.type} ${e.name}')
        .join(', ');
    final executeParams = params.map((e) => e.name).join(', ');

    final hasData = _hasData(returnType);
    final needsFile = _needsFileImport(params);

    final entityName = _extractEntity(returnType);
    final entityImport =
        entityName == null
            ? ''
            : "import 'package:$projectName/features/$featureName/domain/entities/${entityName.snakeCase}.dart';";

    final dataField =
        hasData
            ? '''

  $returnType? _data;
  $returnType? get data => _data;
'''
            : '';

    final onSuccess =
        hasData
            ? '''
      (data) {
        _state = RequestState.Loaded;
        _data = data;
      },
'''
            : '''
      (_) {
        _state = RequestState.Loaded;
      },
''';

    return '''
import 'package:flutter/material.dart';
${needsFile ? "import 'dart:io';" : ''}
import 'package:$projectName/core/state/request_state.dart';
import 'package:$projectName/features/$featureName/domain/usecases/${usecaseName.snakeCase}.dart';
$entityImport

class $providerName extends ChangeNotifier {
  final $usecaseName $useCaseVar;

  $providerName({required this.$useCaseVar});

  RequestState _state = RequestState.Empty;
  RequestState get state => _state;

  String? _message;
  String? get message => _message;
$dataField
  Future<void> $methodName($constructorParams) async {
    _state = RequestState.Loading;
    _message = null;
    notifyListeners();

    final result = await $useCaseVar.execute($executeParams);

    result.fold(
      (failure) {
        _state = RequestState.Error;
        _message = failure.message;
      },
$onSuccess
    );

    notifyListeners();
  }
}
''';
  }
}

class ProviderParam {
  final String name;
  final String type;

  ProviderParam({required this.name, required this.type});
}
