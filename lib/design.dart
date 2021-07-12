import 'dart:isolate';
import 'dart:ui';
import 'package:alarm/buttons.dart';
import 'package:alarm/const.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';

class Mp3Page extends StatefulWidget {
  @override
  _Mp3PageState createState() => _Mp3PageState();
}

class _Mp3PageState extends State<Mp3Page> {
  AudioPlayer _player;
  ReceivePort _port = ReceivePort();

  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: [
  AudioSource.uri(Uri.parse('https://example.com/track1.mp3')),
  AudioSource.uri(Uri.parse('https://example.com/track2.mp3')),
  AudioSource.uri(Uri.parse('https://example.com/track3.mp3')),
  AudioSource.uri(Uri.parse('https://example.com/track4.mp3')),
  AudioSource.uri(Uri.parse('https://example.com/track5.mp3')),
  ]
    
    );

  // ignore: unused_field
  int _addedCount = 0;
  getPermissions() async {
    await Permission.storage.request();
  }

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
    _port.listen((dynamic data) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    _player.dispose();
    super.dispose();
  }

  _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    try {
      await _player.setAudioSource(_playlist);
    } catch (e) {
      // catch load errors: 404, invalid url ...
      print("An error occured $e");
    }
  }

  // @override
  // void dispose() {
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey,
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              itemCount: 2,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  onTap: () {
                    // _player.seek(Duration.zero, index: i);
                  },
                  title: Text('audio'),
                );
                // Container(
                //   height: 250,
                //   child: StreamBuilder<SequenceState>(
                //     stream: _player.sequenceStateStream,
                //     builder: (context, snapshot) {
                //       final state = snapshot.data;
                //       final sequence = state?.sequence ?? [];
                //       return ReorderableListView(
                //         onReorder: (int oldIndex, int newIndex) {
                //           if (oldIndex < newIndex) newIndex--;
                //           _playlist.move(oldIndex, newIndex);
                //         },
                //         children: [
                //           for (var i = 0; i < sequence.length; i++)
                //             Dismissible(
                //               key: ValueKey(sequence[i]),
                //               onDismissed: (dismissDirection) {
                //                 _playlist.removeAt(i);
                //               },
                //               child: Material(
                //                 color: i == state.currentIndex
                //                     ? Colors.grey.shade300
                //                     : null,
                //                 child: ListTile(
                //                   title: Text(mp3FilesName['titles'][index]),
                //                   onTap: () {
                //                     _player.seek(Duration.zero, index: i);
                //                   },
                //                 ),
                //               ),
                //             ),
                //         ],
                //       );
                //     },
                //   ),
                // );
              },
            ),
          ),
          Column(
            children: [
              ControlButtons(_player),
              StreamBuilder<Duration>(
                stream: _player.durationStream,
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;
                  return StreamBuilder<PositionData>(
                    stream: Rx.combineLatest2<Duration, Duration, PositionData>(
                        _player.positionStream,
                        _player.bufferedPositionStream,
                        (position, bufferedPosition) =>
                            PositionData(position, bufferedPosition)),
                    builder: (context, snapshot) {
                      final positionData = snapshot.data ??
                          PositionData(Duration.zero, Duration.zero);
                      var position = positionData.position ?? Duration.zero;
                      if (position > duration) {
                        position = duration;
                      }
                      var bufferedPosition =
                          positionData.bufferedPosition ?? Duration.zero;
                      if (bufferedPosition > duration) {
                        bufferedPosition = duration;
                      }
                      return SeekBar(
                        duration: duration,
                        position: position,
                        bufferedPosition: bufferedPosition,
                        onChangeEnd: (newPosition) {
                          _player.seek(newPosition);
                        },
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  StreamBuilder<LoopMode>(
                    stream: _player.loopModeStream,
                    builder: (context, snapshot) {
                      final loopMode = snapshot.data ?? LoopMode.off;
                      const icons = [
                        Icon(Icons.repeat, color: Colors.grey),
                        Icon(Icons.repeat, color: Colors.orange),
                        Icon(Icons.repeat_one, color: Colors.orange),
                      ];
                      const cycleModes = [
                        LoopMode.off,
                        LoopMode.all,
                        LoopMode.one,
                      ];
                      final index = cycleModes.indexOf(loopMode);
                      return IconButton(
                        icon: icons[index],
                        onPressed: () {
                          _player.setLoopMode(cycleModes[
                              (cycleModes.indexOf(loopMode) + 1) %
                                  cycleModes.length]);
                        },
                      );
                    },
                  ),
                  Expanded(
                    child: Text(
                      "Playlist",
                      style: Theme.of(context).textTheme.headline6,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  StreamBuilder<bool>(
                    stream: _player.shuffleModeEnabledStream,
                    builder: (context, snapshot) {
                      final shuffleModeEnabled = snapshot.data ?? false;
                      return IconButton(
                        icon: shuffleModeEnabled
                            ? Icon(Icons.shuffle, color: Colors.orange)
                            : Icon(Icons.shuffle, color: Colors.grey),
                        onPressed: () async {
                          final enable = !shuffleModeEnabled;
                          if (enable) {
                            await _player.shuffle();
                          }
                          await _player.setShuffleModeEnabled(enable);
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          )
        ]),
      ),
    );
  }
}

