import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// flutter_map's dark-mode matrix: colors inverted, then the hue turned by 180 degrees.
const darkTileFilter = ColorFilter.matrix(<double>[
  0.574, -1.43, -0.144, 0, 255, //
  -0.426, -0.43, -0.144, 0, 255, //
  -0.426, -1.43, 0.856, 0, 255, //
  0, 0, 0, 1, 0, //
]);

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

  /// Draws the tile through [darkTileFilter] once. The copy is rasterized on the raster
  /// thread, a single 256 px pass per tile instead of a full-map pass per frame.
  static ui.Image _darken(ui.Image image) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(
      image,
      Offset.zero,
      Paint()..colorFilter = darkTileFilter,
    );
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
