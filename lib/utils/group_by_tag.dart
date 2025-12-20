Map<String, Map<String, dynamic>> groupPathsByTag(Map<String, dynamic> paths) {
  final result = <String, Map<String, dynamic>>{};

  paths.forEach((path, methods) {
    (methods as Map<String, dynamic>).forEach((method, details) {
      final tags = (details['tags'] as List?)?.cast<String>();

      final tag = (tags != null && tags.isNotEmpty) ? tags.first : 'default';

      result.putIfAbsent(tag, () => {});
      result[tag]!.putIfAbsent(path, () => {});
      result[tag]![path][method] = details;
    });
  });

  return result;
}
