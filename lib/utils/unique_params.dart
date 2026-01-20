String makeUniqueParamName(String name, Set<String> usedNames) {
  if (!usedNames.contains(name)) {
    usedNames.add(name);
    return name;
  }

  int i = 1;
  String newName;
  do {
    newName = '${name}_$i';
    i++;
  } while (usedNames.contains(newName));

  usedNames.add(newName);
  return newName;
}
