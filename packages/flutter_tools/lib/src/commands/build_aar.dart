// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';


import '../android/android_sdk.dart';
import '../android/gradle.dart';
import '../base/common.dart';
import '../build_info.dart';
import '../project.dart';
import '../runner/flutter_command.dart' show FlutterCommandResult;
import 'build.dart';

class BuildAarCommand extends BuildSubCommand {
  BuildAarCommand({bool verboseHelp = false}) {
    addBuildModeFlags(verboseHelp: verboseHelp);
    usesPubOption();
    usesBuildNumberOption();
    usesBuildNameOption();
    requiresPubspecYaml();

    argParser
      ..addFlag('track-widget-creation', negatable: false, hide: !verboseHelp)
      ..addFlag('build-shared-library',
        negatable: false,
        help: 'Whether to prefer compiling to a *.so file (android only).',
      )
      ..addOption('target-platform',
        defaultsTo: 'android-arm',
        allowed: <String>['android-arm', 'android-arm64', 'android-x86', 'android-x64']);
  }

  @override
  final String name = 'aar';

  @override
  final String description = 'Build an Android AAR file from your module or plugin.\n\n'
    'This command can build debug and release versions of your application. \'debug\' builds support '
    'debugging and a quick development cycle. \'release\' builds don\'t support debugging and are '
    'suitable for deploying Maven repositories.';

  @override
  Future<FlutterCommandResult> runCommand() async {
    if (androidSdk == null)
      throwToolExit('No Android SDK found. Try setting the ANDROID_SDK_ROOT environment variable.');

    final FlutterProject project = await FlutterProject.current();
    if (project.isModule) {
      throwToolExit('Not implemented');
    } else if  (project.manifest.isPlugin) {
      await buildPluginAAR(plugin: project, buildInfo: getBuildInfo());
    } else {
      throwToolExit('Only Module or Plugin projects can be built as an AAR.');
    }
    androidSdk.reinitialize();
    return null;
  }
}
