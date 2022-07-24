import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:english_sub/textselection_controler.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_service/audio_service.dart';
import 'utils.dart';
import 'audio_common.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryFlutter.init((opt) {
    opt.dsn =
        'https://8564b9f502a3468da69c7048a814d877@o1332335.ingest.sentry.io/6596802';
    opt.tracesSampleRate = 1.0;
  },
      appRunner: () => runApp(MaterialApp(
              home: Scaffold(
            body: InitScreen(),
            appBar: AppBar(),
          ))));
}

class InitScreen extends StatefulWidget {
  const InitScreen({Key? key}) : super(key: key);

  @override
  _InitScreenState createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  late Uint8List audiobyte;
  late List<String> srttxt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        children: [
          ElevatedButton(
              onPressed: () async {
                try {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();
                  audiobyte = result!.files.first.bytes!;
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            content: Text(audiobyte.length.toString()),
                          ));
                } catch (e) {
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            content: Text(e.toString()),
                          ));
                }
              },
              child: Text('audio')),
          ElevatedButton(
              onPressed: () async {
                try {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();
                  srttxt = utf8.decode(result!.files.first.bytes!).split('\n');
                } catch (e) {
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                            content: Text(e.toString()),
                          ));
                }
              },
              child: Text('srt')),
          ElevatedButton(
              child: Text('select'),
              onPressed: () async {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => Scaffold(
                              body: MyApp(
                                audiobyte: audiobyte,
                                srttxt: srttxt,
                              ),
                              appBar: AppBar(),
                            )));
              }),
        ],
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  MyApp({Key? key, required this.audiobyte, required this.srttxt})
      : super(key: key);
  Uint8List audiobyte;
  List<String> srttxt;

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late MyAudioHandler? _audioHandler;
  late ScrollController _scrollController;
  late SrtTime _srttime;

  Duration _position = Duration(seconds: 0);
  bool init = false;
  int gidx = 0;
  int maxginx = 0;

  //config
  double height = 80;
  int t_padding = 4;
  int duration_sec = 1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    Future(() async {
      try {
        _audioHandler = await AudioService.init(
            builder: () => MyAudioHandler(bytes: widget.audiobyte),
            config: AudioServiceConfig(
                androidNotificationChannelId: 'com.nw.english_sub',
                androidNotificationChannelDescription: 'music playback',
                androidNotificationOngoing: true),
            cacheManager: null);
        _srttime = await readsrt(widget.srttxt);
        AudioService.position.listen((Duration position) {
          setState(() {
            _position = position;
            //scroll
            // print("${_srttime.timelist[gidx + 1].inMilliseconds},${_position.inMilliseconds}");
            if (_srttime.timelist[gidx + 1].inMilliseconds <
                _position.inMilliseconds) {
              gidx += 1;
              maxginx = max(maxginx, gidx);
              _scrollController.animateTo((gidx - t_padding) * height,
                  duration: Duration(seconds: duration_sec),
                  curve: Curves.ease);
            }
          });
        });
        setState(() {
          init = true;
        });
      } catch (e) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  content: Text(e.toString()),
                ));
      }
    });
  }

  void seek(Duration position, {int? idx}) {
    _position = position;
    _audioHandler!.seek(position);
    if (idx != null) {
      gidx = idx;
      maxginx = max(maxginx, gidx);
      _scrollController.animateTo((idx - t_padding) * height,
          duration: Duration(seconds: 1), curve: Curves.ease);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // pick mp3
    // read srt
    // prepare playing
    // animatedlistview
    return init
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedList(
                    controller: _scrollController,
                    itemBuilder: (context, idx, animation) {
                      bool isshow = idx <= maxginx;
                      bool isjust = isshow &&
                          (_srttime.timelist[idx + 1].inMilliseconds >
                              _position.inMilliseconds) &&
                          (_srttime.timelist[idx].inMilliseconds <
                              _position.inMilliseconds);
                      return SizedBox(
                        height: height,
                        child: Card(
                          child: GestureDetector(
                            onTap: () async {
                              if (gidx - idx <= t_padding)
                                _audioHandler!.seek(_srttime.timelist[idx]);
                              else
                                seek(_srttime.timelist[idx], idx: idx);
                              _audioHandler!.play();
                              // print(_srttime.timelist[idx]);
                              // print(_srttime.strlist[idx]);
                            },
                            child: ListTile(
                              tileColor:
                                  isjust ? Colors.lightGreenAccent : null,
                              title: SelectableText(
                                isshow ? _srttime.strlist[idx] : '',
                                onSelectionChanged: (t, c) {
                                  if (c == SelectionChangedCause.longPress)
                                    _audioHandler!.pause();
                                },
                                selectionControls:
                                    MyMaterialTextSelectionControls(),
                              ),
                              trailing: Icon(Icons.play_arrow),
                            ),
                          ),
                        ),
                      );
                    },
                    initialItemCount: _srttime.timelist.length,
                  ),
                ),
                SeekBar(
                    duration: _srttime.timelist.last,
                    position: _position,
                    onChangeEnd: (newposition) {
                      //TODO find nearest idx
                      seek(newposition);
                    }),
                Align(
                    alignment: Alignment.center,
                    child: ControllerButtons(audioHandler: _audioHandler!)),
              ],
            ),
          )
        : Center(
            child: Text("LOADING AUDIO AND SCRIPT"),
          );
  }
}
