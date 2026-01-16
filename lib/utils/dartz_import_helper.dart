String dartzImport(Set<String> usedEntities) {
  final hasOrder = usedEntities.any((e) => e.toLowerCase() == 'order');

  if (hasOrder) {
    return "import 'package:dartz/dartz.dart' hide Order;";
  }

  return "import 'package:dartz/dartz.dart';";
}
