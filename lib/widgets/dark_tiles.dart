import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// flutter_map's dark-mode matrix: colors inverted, then the hue turned by 180 degrees.
/// It turns the white fill of minor roads black on a near-black ground, so the passes
/// below put the roads back.
const darkTileFilter = ColorFilter.matrix(<double>[
  0.574, -1.43, -0.144, 0, 255, //
  -0.426, -0.43, -0.144, 0, 255, //
  -0.426, -1.43, 0.856, 0, 255, //
  0, 0, 0, 1, 0, //
]);

/// Near-white pixels of the light tile (minor roads, label halos) as a cool grey,
/// everything else black. Blue weighs most so the pale-yellow fill OSM gives school and
/// hospital grounds stays below the threshold.
final minorRoadFilter = _lift(
  weights: (0.3, 0.3, 0.4),
  threshold: 0.965,
  gain: 28,
  color: (0.30, 0.33, 0.38),
);

/// Yellow and orange road fills (secondary and primary roads) as a dim amber,
/// everything else black: red plus green minus blue separates them from land.
final majorRoadFilter = _lift(
  weights: (1, 1, -1),
  threshold: 1.15,
  gain: 20,
  color: (0.42, 0.36, 0.16),
);

/// A matrix giving `color * clamp(gain * (weights . rgb - threshold))`, rgb in 0..1.
ColorFilter _lift({
  required (double, double, double) weights,
  required double threshold,
  required double gain,
  required (double, double, double) color,
}) {
  List<double> row(double c) => [
        gain * weights.$1 * c,
        gain * weights.$2 * c,
        gain * weights.$3 * c,
        0,
        -gain * threshold * 255 * c,
      ];
  return ColorFilter.matrix([
    ...row(color.$1),
    ...row(color.$2),
    ...row(color.$3),
    0, 0, 0, 1, 0, //
  ]);
}

/// OpenStreetMap tiles, darkened once when each tile is decoded.
///
/// A [ColorFiltered] over the tile layer costs an offscreen pass of the whole map on
/// every frame, a raster-cache fill each time the map settles, and a larger rotated pass
/// in heading-up; on the A6+ that showed as 20-60 ms raster frames. A darkened copy of
/// each tile is drawn like any image instead. Downloading stays with
/// [NetworkTileProvider], so the User-Agent [TileLayer] sets and the cancelling of
/// obsolete requests still apply.
class DarkTileProvider extends TileProvider {
  DarkTileProvider() : this._(<String, String>{});

  // One headers map for both: TileLayer writes the User-Agent into this provider's map,
  // and the inner provider must send it.
  DarkTileProvider._(Map<String, String> headers)
      : _network = NetworkTileProvider(headers: headers),
        super(headers: headers);

  final NetworkTileProvider _network;

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) =>
      _DarkTileImage(
        _network.getImageWithCancelLoadingSupport(
          coordinates,
          options,
          cancelLoading,
        ),
      );

  @override
  void dispose() {
    unawaited(_network.dispose());
    super.dispose();
  }
}

/// The darkened image of one tile. Its cache key is the network tile's, so the image
/// cache holds only the dark copy; the light one is released after darkening.
@immutable
class _DarkTileImage extends ImageProvider<_DarkTileImage> {
  const _DarkTileImage(this.light);

  final ImageProvider<Object> light;

  @override
  Future<_DarkTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _DarkTileImage key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(_load(key, decode));

  Future<ImageInfo> _load(_DarkTileImage key, ImageDecoderCallback decode) async {
    try {
      final lightKey = await light.obtainKey(ImageConfiguration.empty);
      // Loads without the image cache, which keeps only the darkened copy.
      // ignore: invalid_use_of_protected_member
      final image = await _firstFrame(light.loadImage(lightKey, decode));
      try {
        return ImageInfo(image: _darken(image), debugLabel: '$light');
      } finally {
        image.dispose();
      }
    } catch (_) {
      // A failed tile must not stay cached, so flutter_map can request it again.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  static Future<ui.Image> _firstFrame(ImageStreamCompleter completer) {
    final result = Completer<ui.Image>();
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!result.isCompleted) result.complete(info.image.clone());
        info.dispose();
        completer.removeListener(listener);
      },
      onError: (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
        completer.removeListener(listener);
      },
    );
    completer.addListener(listener);
    return result.future;
  }

  /// Draws the tile once through [darkTileFilter], then lightens it with the two road
  /// passes. The copy is rasterized on the raster thread, three 256 px passes per tile
  /// when it is decoded instead of a full-map pass per frame.
  static ui.Image _darken(ui.Image image) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint()..colorFilter = darkTileFilter);
    for (final roads in [minorRoadFilter, majorRoadFilter]) {
      canvas.drawImage(
        image,
        Offset.zero,
        Paint()
          ..colorFilter = roads
          ..blendMode = BlendMode.lighten,
      );
    }
    final picture = recorder.endRecording();
    final dark = picture.toImageSync(image.width, image.height);
    picture.dispose();
    return dark;
  }

  @override
  bool operator ==(Object other) =>
      other is _DarkTileImage && other.light == light;

  @override
  int get hashCode => Object.hash(_DarkTileImage, light);
}
