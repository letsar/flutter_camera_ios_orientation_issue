import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_camera_ios_orientation_issue/app_camera_preview.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? controller;
  StreamSubscription<NativeDeviceOrientation>? subscription;
  DeviceOrientation deviceOrientation = DeviceOrientation.portraitUp;
  XFile? imageFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    subscription = NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen(onOrientationChanged);
    selectBackCamera();
  }

  void selectBackCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhereOrNull(
        (camera) => camera.lensDirection == CameraLensDirection.back);
    if (backCamera != null) {
      onNewCameraSelected(backCamera);
    }
  }

  void onOrientationChanged(NativeDeviceOrientation orientation) {
    deviceOrientation = () {
      switch (orientation) {
        case NativeDeviceOrientation.portraitUp:
          return DeviceOrientation.portraitUp;
        case NativeDeviceOrientation.portraitDown:
          return DeviceOrientation.portraitDown;
        case NativeDeviceOrientation.landscapeLeft:
          return DeviceOrientation.landscapeLeft;
        case NativeDeviceOrientation.landscapeRight:
          return DeviceOrientation.landscapeRight;
        case NativeDeviceOrientation.unknown:
          return DeviceOrientation.portraitUp;
      }
    }();

    final cameraController = controller;

    if (cameraController != null) {
      cameraController.lockCaptureOrientation(deviceOrientation);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    final CameraController? oldController = controller;
    if (oldController != null) {
      // `controller` needs to be set to null before getting disposed,
      // to avoid a race condition when we use the controller that is being
      // disposed. This happens when camera permission dialog shows up,
      // which triggers `didChangeAppLifecycleState`, which disposes and
      // re-creates the controller.
      controller = null;
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await cameraController.initialize();
    } on Exception catch (e) {
      debugPrint(e.toString());
    }

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraController = controller;
    if (cameraController == null) {
      return const Scaffold();
    }

    final localImageFile = imageFile;
    final image = localImageFile != null
        ? Image.file(
            File(localImageFile.path),
            fit: BoxFit.cover,
          )
        : const SizedBox();

    final cameraView = AppCameraPreview(cameraController);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          cameraView,
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                deviceOrientation.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SizedBox(
                height: 100,
                child: image,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          imageFile = await cameraController.takePicture();
          if (mounted) {
            setState(() {});
          }
        },
        child: const Icon(Icons.camera),
      ),
    );
  }
}
