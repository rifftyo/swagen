// ignore_for_file: avoid_print

import 'package:swagen/constant/constant.dart';

void runHelpCommand() {
  print('''
🚀 SWAGEN - Swagger to Flutter Generator

USAGE:
  swagen <command> [options]

COMMANDS:
  convert <swagger.json>   Convert swagger file to Flutter code
  --version, -v            Show swagen version
  help                     Show this help

OPTIONS:
  --package <name>         Custom package name

EXAMPLES:
  swagen convert swagger.json
  swagen convert swagger.json --package my_app
  swagen --version

DOCUMENTATION:
  📘 GitHub: $githubUrl

ISSUES & CONTRIBUTIONS:
  $githubUrl/issues
''');
}
