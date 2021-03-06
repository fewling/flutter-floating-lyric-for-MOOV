import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lyric.dart';
import '../ui/lyric_window.dart';
import '../models/song.dart';
import 'song_box.dart';

class WindowController extends GetxController {
  // singleton constructor
  factory WindowController() => _instance;
  static final WindowController _instance = WindowController._();
  WindowController._();

  void init() {
    SharedPreferences.getInstance().then((value) {
      _prefs = value;

      _textColor.value = _prefs!.getInt('color') == null
          ? Colors.deepPurple.shade300
          : Color(_prefs!.getInt('color')!);

      _backgroundOpcity.value = _prefs!.getDouble('opacity') == null
          ? 0.0
          : _prefs!.getDouble('opacity')!;
    });
  }

  // non-reactive properties
  final _songBox = SongBox();
  final _lyricWindow = LyricWindow();
  var _playingSong = Song();
  var _millisLyric = <Map<int, String>>[];
  SharedPreferences? _prefs;

  // reactive properties:
  final _displayingTitle = ''.obs;
  final _displayingLyric = ''.obs;
  final _isShowingWindow = false.obs;
  final _shouldShowWindow = false.obs;
  final _textColor = Colors.deepPurple.shade300.obs;
  final _backgroundOpcity = 0.0.obs;

  // getters
  String get displayingTitle => _displayingTitle.value;
  String get displayingLyric => _displayingLyric.value;
  Color get textColor => _textColor.value;
  double get backgroundOpcity => _backgroundOpcity.value;
  bool get isShowingWindow => _isShowingWindow.value;
  bool get shouldShowWindow => _shouldShowWindow.value;

  // setters
  set song(Song song) {
    log('set song: $song, \nplayingSong: $_playingSong');

    // update lyric list when song changed:
    if (_playingSong.title != song.title) {
      _millisLyric = _updateLyricList(song);
      _displayingTitle.value = '${song.artist} - ${song.title}';
    }

    _playingSong = song;
    _updateWindow();
  }

  set textColor(Color color) {
    _textColor.value = color;
    _prefs?.setInt('color', color.value);
    _updateWindow(uiUpdate: true);
  }

  set backgroundOpcity(double opacity) {
    _backgroundOpcity.value = opacity;
    _prefs?.setDouble('opacity', opacity);
    _updateWindow(uiUpdate: true);
  }

  set isShowingWindow(bool isShowing) => _isShowingWindow.value = isShowing;

  set shouldShowWindow(bool shouldShow) {
    _shouldShowWindow.value = shouldShow;
    shouldShow ? _showWindow() : _closeWindow();
  }

  // methods
  void _showWindow() => _lyricWindow.show();

  void _closeWindow() {
    _playingSong = Song();
    _lyricWindow.close();
  }

  void _updateWindow({bool uiUpdate = false}) {
    if (!shouldShowWindow) return;

    if (uiUpdate) {
      _lyricWindow.update();
    } else if (_millisLyric.isNotEmpty) {
      final currentDuration = int.parse(_playingSong.currentDuration);
      log(_millisLyric.length.toString());

      for (final lyric in _millisLyric.reversed) {
        final timeKey = lyric.keys.first;
        if (currentDuration >= timeKey - 500) {
          var content = lyric[timeKey];

          if (_displayingLyric.value != content && content != null) {
            _displayingLyric.value = content;
            _lyricWindow.update();
          }
          break;
        }
      }
    } else if (_displayingLyric.value != 'No Lyric') {
      _displayingLyric.value = 'No Lyric';
      _lyricWindow.update();
    }
  }

  List<Map<int, String>> _updateLyricList(Song song) {
    final lyricList = <Map<int, String>>[];

    final artist = song.artist;
    final title = song.title;
    final key = '$artist - $title';

    if (!_songBox.hasKey(key)) return [];

    final lyric = Lyric.fromMap((_songBox.getSongMap(key)));
    const pattern = r'[0-9]{2}:[0-9]{2}.[0-9]{2}';
    final regExp = RegExp(pattern);

    for (final line in lyric.content) {
      Iterable<RegExpMatch> matches = regExp.allMatches(line);

      for (final m in matches) {
        final l = m.input;

        final lastBracketIndex = l.lastIndexOf(']') + 1;
        final content = l.substring(lastBracketIndex);
        String time = l.substring(0, lastBracketIndex);

        while (time.contains(']')) {
          final index = time.indexOf(']') + 1;
          final t = time.substring(0, index);

          final minute = int.parse(t.substring(1, 3));
          final second = int.parse(t.substring(4, 6));
          final millis = int.parse(t.substring(7, 9));

          final millisTime = minute * 60 * 1000 + second * 1000 + millis;
          lyricList.add({millisTime: content});
          time = time.replaceRange(0, index, '');
        }
      }
    }

    lyricList.sort((a, b) => a.keys.first.compareTo(b.keys.first));
    return lyricList;
  }
}
