import 'package:app/main.dart';
import 'package:audio_service/audio_service.dart';

class MyAudioHandler extends BaseAudioHandler
    with
        QueueHandler, // mix in default queue callback implementations
        SeekHandler // mix in default seek callback implementations
{
  // The most common callbacks:
  Future<void> play() async {
    staticText = 'playing';

    // All 'play' requests from all origins route to here. Implement this
    // callback to start playing audio appropriate to your app. e.g. music.
  }

  Future<void> pause() async {
    staticText = 'pause';
  }

  Future<void> stop() async {
    staticText = 'stop';
  }

  Future<void> seek(Duration position) async {
    staticText = 'seeking';
  }

  Future<void> skipToQueueItem(int i) async {
    staticText = 'skipping to Queued item';
  }
}
