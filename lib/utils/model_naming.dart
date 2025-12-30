const String responseSuffix = 'Response';

String asResponse(String name) {
  return name.endsWith(responseSuffix) ? name : '$name$responseSuffix';
}

String stripResponse(String name) =>
    name.endsWith(responseSuffix)
        ? name.substring(0, name.length - responseSuffix.length)
        : name;

String asEntity(String responseName) {
  return responseName.replaceAll('Response', '');
}
