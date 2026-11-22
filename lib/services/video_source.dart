import '../models/car_video.dart';

/// A page of search results.
class VideoPage {
  const VideoPage(this.videos, {this.cursor});

  final List<CarVideo> videos;

  /// Opaque handle for [VideoSource.nextPage]; null when there are no more results.
  final Object? cursor;

  bool get hasMore => cursor != null;
}

/// Where the feed gets its videos from. Kept apart from YouTubeService so the feed logic
/// can be tested without the network.
abstract interface class VideoSource {
  Future<VideoPage> search(String query);

  Future<VideoPage> nextPage(VideoPage page);
}

/// A failure with a message ready to show the driver.
class YouTubeServiceException implements Exception {
  const YouTubeServiceException(this.message, [this.cause]) : transient = false;

  /// A failure that may pass on its own (no connection, a timeout, the worker died);
  /// playback retries these by itself.
  const YouTubeServiceException.transient(this.message, [this.cause])
      : transient = true;

  final String message;
  final Object? cause;

  /// Whether trying again later may work; false for answers that stay the same
  /// (unavailable, paid or restricted videos).
  final bool transient;

  @override
  String toString() => cause == null ? message : '$message ($cause)';
}
