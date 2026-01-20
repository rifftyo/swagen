extension StringCaseExtension on String {
  String get lowerCamelCase {
    if (isEmpty) return this;
    return pascalCase[0].toLowerCase() + pascalCase.substring(1);
  }

  String get snakeCase {
    return replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)}_${m.group(2)!.toLowerCase()}',
    ).replaceAll(RegExp(r'[\s\-]+'), '_').toLowerCase();
  }

  String get pascalCase {
    final words = snakeCase.split('_');
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join();
  }

  String get camelCase {
    return replaceAllMapped(RegExp(r'_(\w)'), (m) => m.group(1)!.toUpperCase());
  }

  String get capitalize {
    return isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  }

  String get pluralToSingular {
    if (endsWith('ss')) return this;
    if (endsWith('s')) return substring(0, length - 1);
    return this;
  }
}
