List<Map<String, dynamic>> resolveParameters(
  List rawParams,
  Map<String, dynamic> components,
) {
  final parameters = components['parameters'] ?? {};

  return rawParams.map<Map<String, dynamic>>((p) {
    if (p['\$ref'] != null) {
      final name = p['\$ref'].split('/').last;
      final resolved = parameters[name];
      if (resolved == null) {
        throw Exception('Parameter $name not found in components');
      }
      return Map<String, dynamic>.from(resolved);
    }
    return Map<String, dynamic>.from(p);
  }).toList();
}
