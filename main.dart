import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rtmp_broadcaster/camera.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: CameraPage());
  }
}

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;

  bool _isCameraOn = false;
  bool _isStreaming = false;
  bool _isFrontCamera = false;
  bool _isCameraInitialized = false;
  bool _isLoading = false;

  List<CameraDescription> _cameras = [];

  final String rtmpUrl = "rtmp://192.168.31.148:1935/live/stream";

  @override
  void initState() {
    super.initState();
    _fetchCameras();
  }

  Future<void> _fetchCameras() async {
    try {
      _cameras = await availableCameras();
      setState(() {
        _isCameraInitialized = _cameras.isNotEmpty;
      });
    } catch (e) {
      debugPrint("Error fetching cameras: $e");
    }
  }

  CameraDescription? _getFrontCamera() {
    try {
      return _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
    } catch (_) {
      return null;
    }
  }

  CameraDescription? _getBackCamera() {
    try {
      return _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
    } catch (_) {
      return null;
    }
  }

  CameraDescription _getSelectedCamera() {
    if (_isFrontCamera) {
      return _getFrontCamera() ?? _cameras.first;
    } else {
      return _getBackCamera() ?? _cameras.first;
    }
  }

  Future<void> _safeDisposeController() async {
    final old = _controller;
    _controller = null;
    if (old != null) {
      try {
        await old.stopVideoStreaming();
      } catch (_) {}
      try {
        await old.dispose();
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  Future<bool> _initializeControllerWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint("Camera init attempt $attempt — front: $_isFrontCamera");
        _controller = CameraController(
          _getSelectedCamera(),
          ResolutionPreset.medium,
        );
        await _controller!.initialize();
        debugPrint("Camera initialized on attempt $attempt");
        return true;
      } catch (e) {
        debugPrint("Attempt $attempt failed: $e");
        try {
          await _controller?.dispose();
        } catch (_) {}
        _controller = null;
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 400 * attempt + 400));
        }
      }
    }
    return false;
  }

  Future<void> _startStreamingAfterSurfaceReady() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    await completer.future;

    await Future.delayed(const Duration(milliseconds: 500));

    if (_controller == null || !mounted) return;

    try {
      await _controller!.startVideoStreaming(rtmpUrl);
      if (mounted) {
        setState(() => _isStreaming = true);
        debugPrint("RTMP streaming started successfully");
      }
    } catch (e) {
      debugPrint("RTMP stream failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Stream failed — check RTMP server and URL"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  //  START
  Future<void> startStream() async {
    if (_cameras.isEmpty || _isLoading) return;
    setState(() => _isLoading = true);

    await _safeDisposeController();

    final bool initialized = await _initializeControllerWithRetry();

    if (!initialized) {
      setState(() {
        _isCameraOn = false;
        _isStreaming = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Camera failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isCameraOn = true;
      _isLoading = false;
    });

    await _startStreamingAfterSurfaceReady();
  }

  //  STOP
  Future<void> stopStream() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    await _safeDisposeController();

    setState(() {
      _isCameraOn = false;
      _isStreaming = false;
      _isLoading = false;
    });
  }

  Future<void> switchCamera() async {
    if (!_isCameraOn || _isLoading || _cameras.length < 2) return;

    // ✅ FIX 3: Check that the other camera actually exists before switching
    final CameraDescription? targetCamera = _isFrontCamera
        ? _getBackCamera()
        : _getFrontCamera();

    if (targetCamera == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFrontCamera ? "No back camera found" : "No front camera found",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    await _safeDisposeController();

    _isFrontCamera = !_isFrontCamera;

    debugPrint("Switching to ${_isFrontCamera ? 'FRONT' : 'BACK'} camera");

    final bool initialized = await _initializeControllerWithRetry();

    if (!initialized) {
      // ✅ FIX 5: Revert toggle if initialization failed
      _isFrontCamera = !_isFrontCamera;
      setState(() {
        _isCameraOn = false;
        _isStreaming = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to switch camera. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isCameraOn = true;
      _isLoading = false;
      _isStreaming = false; // reset streaming — will restart below
    });

    await _startStreamingAfterSurfaceReady();
  }

  bool get _isControllerReady {
    final CameraController? controller = _controller;
    if (controller == null) return false;
    return controller.value.isInitialized == true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("LIVE STREAMING"),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          //  Show which camera is active in appbar
          if (_isCameraOn)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: Text(
                  _isFrontCamera ? "FRONT" : "BACK",
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ),
          if (_isStreaming)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 12),
                  SizedBox(width: 4),
                  Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),

      backgroundColor: Colors.black,

      body: _isCameraOn && _isControllerReady
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_controller!),
            )
          : Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                    SizedBox(height: 16),
                    Text(
                      _isLoading ? "Starting camera..." : "Camera is OFF",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: 20),

            Text(
              rtmpUrl,
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),

            SizedBox(height: 7),

            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: rtmpUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("RTMP URL copied!"),
                    duration: Duration(seconds: 1),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: Icon(Icons.copy),
              tooltip: "Copy RTMP URL",
            ),

            SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ▶️ START
                ElevatedButton.icon(
                  onPressed: !_isCameraOn && _isCameraInitialized && !_isLoading
                      ? startStream
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(90, 48),
                  ),
                  icon: Icon(Icons.play_arrow),
                  label: Text("Start"),
                ),

                SizedBox(width: 10),

                // ⏹ STOP
                ElevatedButton.icon(
                  onPressed: _isCameraOn && !_isLoading ? stopStream : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: Size(90, 48),
                  ),
                  icon: Icon(Icons.stop),
                  label: Text("Stop"),
                ),

                SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: _isCameraOn && _cameras.length >= 2 && !_isLoading
                      ? switchCamera
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    minimumSize: Size(90, 48),
                  ),
                  icon: Icon(Icons.cameraswitch),
                  label: Text(_isFrontCamera ? "Back" : "Front"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
