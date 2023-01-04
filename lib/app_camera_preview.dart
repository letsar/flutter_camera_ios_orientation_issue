// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget showing a live camera preview.
class AppCameraPreview extends StatelessWidget {
  /// Creates a preview widget for the given camera controller.
  const AppCameraPreview(
    this.controller, {
    Key? key,
  }) : super(key: key);

  /// The controller for the camera that the preview is shown for.
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return controller.value.isInitialized
        ? ValueListenableBuilder<CameraValue>(
            valueListenable: controller,
            builder: (BuildContext context, Object? value, Widget? child) {
              return AspectRatio(
                aspectRatio: _isLandscape()
                    ? controller.value.aspectRatio
                    : (1 / controller.value.aspectRatio),
                child: _RotatePreview(
                  deviceOrientation: _getApplicableOrientation(),
                  child: controller.buildPreview(),
                ),
              );
            },
          )
        : const SizedBox();
  }

  bool _isLandscape() {
    final orientation = _getApplicableOrientation();
    return orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
  }

  DeviceOrientation _getApplicableOrientation() {
    return controller.value.isRecordingVideo
        ? controller.value.recordingOrientation!
        : (controller.value.previewPauseOrientation ??
            controller.value.lockedCaptureOrientation ??
            controller.value.deviceOrientation);
  }
}

class _RotatePreview extends StatelessWidget {
  const _RotatePreview({
    required this.deviceOrientation,
    required this.child,
  });

  final DeviceOrientation deviceOrientation;
  final Widget child;

  int _getIosQuarterTurns(DeviceOrientation orientation) {
    final Map<DeviceOrientation, int> turns = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeRight: 1,
      DeviceOrientation.portraitDown: 2,
      DeviceOrientation.landscapeLeft: 3,
    };
    return turns[orientation]!;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return child;
    }

    return RotatedBox(
      quarterTurns: _getIosQuarterTurns(deviceOrientation),
      child: child,
    );
  }
}
