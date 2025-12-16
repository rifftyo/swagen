String camelCaseConvert(String text) {
  return text.replaceAllMapped(
    RegExp(r'_(\w)'),
    (m) => m.group(1)!.toUpperCase(),
  );
}
