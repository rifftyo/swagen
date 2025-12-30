#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'package:swagen/commands/clean_architecture.dart';
import 'package:swagen/commands/convert_command.dart';
import 'package:swagen/commands/help_command.dart';
import 'package:swagen/commands/version_command.dart';

void main(List<String> args) {
  if (args.isEmpty || args.contains('help')) {
    runHelpCommand();
    return;
  }

  if (args.contains('--version') || args.contains('-v')) {
    runVersionCommand();
    return;
  }

  if (args.contains('cleanarch')) {
    generateCleanArchitectureFolders();
    return;
  }

  switch (args.first) {
    case 'convert':
      runConvertCommand(args.sublist(1));
      break;
    default:
      print('❌ Unknown command');
      runHelpCommand();
  }
}
