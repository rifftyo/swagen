extension StringCaseExtension on String {
  String get snakeCase {
    return replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
    ).replaceAll(RegExp(r'[\s\-]+'), '_').toLowerCase();
  }

  String get pascalCase {
    final words = snakeCase.split('_');
    return words.where((w) => w.isNotEmpty).map((w) => w.capitalize).join();
  }

  String get camelCase {
    if (isEmpty) return this;
    final p = pascalCase;
    return p[0].toLowerCase() + p.substring(1);
  }

  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get pluralToSingular {
    if (endsWith('ss')) return this;
    if (endsWith('s')) return substring(0, length - 1);
    return this;
  }
}
