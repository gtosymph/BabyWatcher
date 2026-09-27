import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../core/alarm_tone.dart';

/// Joue le bip d'alarme en boucle, avec vibration.
class AlarmPlayer {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  String? _path;

  Future<void> play() async {
    if (_playing) return;
    _playing = true;
    _path ??= await _writeTone();
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(1.0);
    await _player.play(DeviceFileSource(_path!));
    _vibrateLoop();
  }

  Future<void> stop() async {
    _playing = false;
    await _player.stop();
  }

  Future<void> _vibrateLoop() async {
    while (_playing) {
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<String> _writeTone() async {
    final file = File('${Directory.systemTemp.path}/babycam_alarm.wav');
    await file.writeAsBytes(buildAlarmWav(), flush: true);
    return file.path;
  }

  Future<void> dispose() async {
    _playing = false;
    await _player.dispose();
  }
}
