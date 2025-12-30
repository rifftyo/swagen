extension StringCaseExtension on String {
  String get snakeCase {
    return replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst('_', '');
  }

  String get pascalCase {
    return split(RegExp(r'[_\-\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
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
