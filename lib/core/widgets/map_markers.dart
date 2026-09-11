import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─── Shared map marker rasterization ──────────────────────────────────────────
//
// Canvas-drawn and SVG-rendered BitmapDescriptor builders shared by the
// passenger and conductor map tabs.

/// A filled circle with a coloured stroke — used for route stop markers.
Future<BitmapDescriptor> circleMarkerIcon({
  required Color fill,
  required Color stroke,
  double size = 22,
  double strokeWidth = 2.5,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = size / 2;
  canvas.drawCircle(
    Offset(r, r),
    r - strokeWidth / 2,
    Paint()
      ..color = fill
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    Offset(r, r),
    r - strokeWidth / 2,
    Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Canvas-drawn bus icon — fallback when the SVG capture is unavailable
/// (no widget context needed).
Future<BitmapDescriptor> busMarkerIconFallback(double size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = size / 2;
  canvas.drawCircle(
    Offset(r, r),
    r - 1.5,
    Paint()
      ..color = const Color(0xFF3D3D8F)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    Offset(r, r),
    r - 1.5,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
  final tp = TextPainter(textDirection: ui.TextDirection.ltr);
  tp.text = TextSpan(
    text: String.fromCharCode(Icons.directions_bus_rounded.codePoint),
    style: TextStyle(
      fontSize: size * 0.52,
      fontFamily: Icons.directions_bus_rounded.fontFamily,
      package: Icons.directions_bus_rounded.fontPackage,
      color: Colors.white,
    ),
  );
  tp.layout();
  tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// Renders the custom bus.svg via an offscreen RepaintBoundary.
/// [context] must be mounted (call after at least one await so the widget is
/// in the tree); falls back to [busMarkerIconFallback] on failure.
Future<BitmapDescriptor> busMarkerIconFromSvg(
  BuildContext context,
  double size, {
  String debugTag = '[MAP]',
}) async {
  final completer = Completer<BitmapDescriptor>();
  final key = GlobalKey();
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: -10000,
      child: RepaintBoundary(
        key: key,
        child: BusIconWidget(size: size),
      ),
    ),
  );

  Overlay.of(context).insert(entry);

  // Two frames: first to layout, second to paint the SVG.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 3.0);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          completer.complete(
            data != null
                ? BitmapDescriptor.bytes(
                    data.buffer.asUint8List(),
                    imagePixelRatio: 3.0,
                  )
                : await busMarkerIconFallback(size),
          );
        } else {
          completer.complete(await busMarkerIconFallback(size));
        }
      } catch (e) {
        debugPrint('$debugTag svg icon capture error: $e');
        completer.complete(await busMarkerIconFallback(size));
      } finally {
        entry.remove();
      }
    });
  });

  return completer.future;
}

/// Orange circular pin icon for user-defined custom pins.
Future<BitmapDescriptor> customPinMarkerIcon(double size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final r = size / 2;
  canvas.drawCircle(
    Offset(r, r),
    r - 1.5,
    Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    Offset(r, r),
    r - 1.5,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );
  final tp = TextPainter(textDirection: ui.TextDirection.ltr);
  tp.text = TextSpan(
    text: String.fromCharCode(Icons.location_on_rounded.codePoint),
    style: TextStyle(
      fontSize: size * 0.52,
      fontFamily: Icons.location_on_rounded.fontFamily,
      package: Icons.location_on_rounded.fontPackage,
      color: Colors.white,
    ),
  );
  tp.layout();
  tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

// ─── Offscreen bus icon widget ────────────────────────────────────────────────
// Rendered into a RepaintBoundary to produce the BitmapDescriptor for the map.

class BusIconWidget extends StatelessWidget {
  final double size;
  const BusIconWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF3D3D8F),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.22),
          child: SvgPicture.asset(
            'assets/icons/bus.svg',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
