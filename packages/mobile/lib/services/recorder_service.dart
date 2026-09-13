import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Wraps microphone capture + local playback for the PTT loopback POC.
/// Press → [startRecording]. Release → [stopAndPlayback] which stops the
/// recorder and immediately plays the clip back through the device speaker.
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _currentPath;

  Future<void> startRecording() async {
    if (await _recorder.isRecording()) return;
    if (!await _recorder.hasPermission()) {
      debugPrint('RecorderService: microphone permission denied');
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ptt_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentPath = path;

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    debugPrint('RecorderService: recording → $path');
  }

  Future<void> stopAndPlayback() async {
    if (!await _recorder.isRecording()) return;
    final path = await _recorder.stop();
    final clip = path ?? _currentPath;
    _currentPath = null;
    if (clip == null) return;

    final file = File(clip);
    if (!await file.exists() || await file.length() == 0) {
      debugPrint('RecorderService: empty clip, skipping playback');
      return;
    }

    debugPrint('RecorderService: playing back $clip');
    await _player.stop();
    await _player.play(DeviceFileSource(clip));
  }

  Future<void> dispose() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    await _player.dispose();
  }
}
