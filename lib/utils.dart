import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:typed_data';

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  Uint8List bytes;

  MyAudioHandler({required this.bytes}) {
    // _player.setFilePath(this.path);
    _player.setAudioSource(BufferAudioSource(bytes));
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  final _player = AudioPlayer();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

Future<SrtTime> readsrt(List<String> line) async {
  int mode = 0;
  List<String> strret = [];
  List<Duration> timeret = [];
  for (String str in line) {
    if ((mode == 0) && RegExp(r'^\d+$').hasMatch(str)) {
      mode = 1;
      strret.add('');
    } else if (mode == 1) {
      var datetime = DateTime.parse('19700101 ' + str.split(' ').first);
      timeret.add(Duration(
          hours: datetime.hour,
          minutes: datetime.minute,
          seconds: datetime.second,
          milliseconds: datetime.millisecond));
      mode = 2;
    } else if (mode >= 2) {
      strret[strret.length - 1] += (mode == 2) ? str : '\n' + str;
      mode += 1;
    }
    if (str == '') mode = 0;
  }
  assert(strret.length == timeret.length);
  return SrtTime(strlist: strret, timelist: timeret);
}

class SrtTime {
  List<String> strlist;
  List<Duration> timelist;

  SrtTime({required this.strlist, required this.timelist}) {
    assert(strlist.length == timelist.length);
  }
}
class BufferAudioSource extends StreamAudioSource {
  Uint8List _buffer;

  BufferAudioSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) {
    start = start ?? 0;
    end = end ?? _buffer.length;

    return Future.value(
      StreamAudioResponse(
        sourceLength: _buffer.length,
        contentLength: end - start,
        offset: start,
        contentType: 'audio/mpeg',
        stream:
        Stream.value(List<int>.from(_buffer.skip(start).take(end - start))),
      ),
    );
  }
}