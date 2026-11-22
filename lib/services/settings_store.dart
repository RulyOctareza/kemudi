import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/car_video.dart';

/// Settings and the last played video, kept across restarts.
class SettingsStore {
  SettingsStore(this._prefs);

  static Future<SettingsStore> load() async =>
      SettingsStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _kQuality = 'quality';
  static const _kAutoplay = 'autoplay';
  static const _kLastVideo = 'last_video';
  static const _kLastPosition = 'last_position_seconds';
  static const _kSearchHistory = 'search_history';

  /// As many as fit in front of the category chips without pushing them off screen.
  static const maxSearchHistory = 3;

  String? get quality => _prefs.getString(_kQuality);

  Future<void> setQuality(String label) => _prefs.setString(_kQuality, label);

  bool get autoplay => _prefs.getBool(_kAutoplay) ?? true;

  Future<void> setAutoplay(bool enabled) => _prefs.setBool(_kAutoplay, enabled);

  CarVideo? get lastVideo {
    final raw = _prefs.getString(_kLastVideo);
    if (raw == null) return null;
    try {
      return CarVideo.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (e) {
      // A corrupt entry only costs the resume chip; never block startup on it.
      debugPrint('Ignoring unreadable last video: $e');
      return null;
    }
  }

  /// The driver's own YouTube searches, newest first.
  List<String> get searchHistory =>
      _prefs.getStringList(_kSearchHistory) ?? const [];

  Future<void> addSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) return Future.value();
    final history = [
      text,
      for (final old in searchHistory)
        if (old.toLowerCase() != text.toLowerCase()) old,
    ];
    return _prefs.setStringList(
      _kSearchHistory,
      history.take(maxSearchHistory).toList(),
    );
  }

  Duration get lastPosition =>
      Duration(seconds: _prefs.getInt(_kLastPosition) ?? 0);

  Future<void> setLastVideo(CarVideo video) =>
      _prefs.setString(_kLastVideo, jsonEncode(video.toJson()));

  Future<void> setLastPosition(Duration position) =>
      _prefs.setInt(_kLastPosition, position.inSeconds);
}
