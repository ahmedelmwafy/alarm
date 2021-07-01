import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:alarm/buttons.dart';
import 'package:alarm/const.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path_provider/path_provider.dart';

class Mp3Page extends StatefulWidget {
  @override
  _Mp3PageState createState() => _Mp3PageState();
}

class _Mp3PageState extends State<Mp3Page> {
  AudioPlayer _player;
  ReceivePort _port = ReceivePort();

  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
      children: List.generate(
    mp3FilesName['audios'].length,
    (index) => AudioSource.uri(Uri.parse(mp3FilesName['audios'][index]
        // audio[index],
        )),
  ));

  // ignore: unused_field
  int _addedCount = 0;
  getPermissions() async {
    await Permission.storage.request();
  }

  @override
  void initState() {
    FlutterDownloader.registerCallback(downloadCallback);

    super.initState();

    _player = AudioPlayer();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      setState(() {});
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
    _player.dispose();
    super.dispose();
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port');
    send.send([id, status, progress]);
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
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView.builder(
              itemCount: mp3FilesName.length,
              itemBuilder: (BuildContext context, int index) {
                return Column(
                  children: [
                    ControlButtons(_player),
                    StreamBuilder<Duration>(
                      stream: _player.durationStream,
                      builder: (context, snapshot) {
                        final duration = snapshot.data ?? Duration.zero;
                        return StreamBuilder<PositionData>(
                          stream: Rx.combineLatest2<Duration, Duration,
                                  PositionData>(
                              _player.positionStream,
                              _player.bufferedPositionStream,
                              (position, bufferedPosition) =>
                                  PositionData(position, bufferedPosition)),
                          builder: (context, snapshot) {
                            final positionData = snapshot.data ??
                                PositionData(Duration.zero, Duration.zero);
                            var position =
                                positionData.position ?? Duration.zero;
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
                    Container(
                      height: 250,
                      child: StreamBuilder<SequenceState>(
                        stream: _player.sequenceStateStream,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final sequence = state?.sequence ?? [];
                          return ReorderableListView(
                            onReorder: (int oldIndex, int newIndex) {
                              if (oldIndex < newIndex) newIndex--;
                              _playlist.move(oldIndex, newIndex);
                            },
                            children: [
                              for (var i = 0; i < sequence.length; i++)
                                Dismissible(
                                  key: ValueKey(sequence[i]),
                                  background: Container(
                                    color: Colors.redAccent,
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child:
                                          Icon(Icons.delete, color: Colors.red),
                                    ),
                                  ),
                                  onDismissed: (dismissDirection) {
                                    _playlist.removeAt(i);
                                  },
                                  child: Material(
                                    color: i == state.currentIndex
                                        ? Colors.grey.shade300
                                        : null,
                                    child: ListTile(
                                      title:
                                          Text(mp3FilesName['titles'][index]),
                                      onTap: () {
                                        _player.seek(Duration.zero, index: i);
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
/*
 GestureDetector(
                              onLongPress: () async {
                                final appPath =
                                    await getApplicationDocumentsDirectory();

                                final path = Directory(appPath.path + '/alarm');
                                await Permission.storage.request();
                                // var path = Directory('storage/emulated/0/quraan');
                                if (await path.exists() == false) {
                                  path.create();
                                }
                                await FlutterDownloader.enqueue(
                                  url:
                                      'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
                                  savedDir: path.path,
                                  // savedDir: 'Locations/On  My iPhone//',
                                  showNotification: true,
                                  openFileFromNotification: false,
                                ).then((value) {
                                  Fluttertoast.showToast(
                                    msg: 'جاري التحميل',
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.SNACKBAR,
                                    backgroundColor: Colors.blueGrey,
                                    textColor: Colors.white,
                                    fontSize: 16.0,
                                  );
                                });
                              },
                              child: ListTile(
                                title: Text("mp3FilesName['titles']"),
                                onTap: () {
                                  _player.seek(Duration.zero, index: i);
                                },
                              ),
                            ),
*/
/*
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
  
*/
// String imgUrl = "https://drive.google.com/file/d/$fileId/view";

// downloadFile(String url) async {
//   await Permission.storage.request();
//   var appPath = await getTemporaryDirectory();
//   var path = Directory('storage/emulated/0/alarm');

//   if (await path.exists() == true) {
//   } else {
//     await path.create(recursive: true);
//   }
//   final taskId = await FlutterDownloader.enqueue(
//     url: url,
//     savedDir: 'storage/emulated/0/alarm',
//     showNotification: true,
//     openFileFromNotification: true,
//   );
// }

// File checkIfExist(String url) {
//   final fileName = url.substring(url.lastIndexOf('/') + 1);
//   var path = Directory('storage/emulated/0/alarm/');
//   String pathFile = path.path + fileName;
//   return File(pathFile);
// }
Map<String, dynamic> mp3FilesName = {
  'audios': [
    'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
    'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
    'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
    'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
  ],
  'titles': [
    'ahmed',
    'sds',
    'ah',
    'mohamed',
  ]
};
// List audio = [
//   'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
//   'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
//   'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
//   'https://drive.google.com/uc?export=view&id=11aylWzziqph_iXBJC8_IWksadcrcX6Px',
// ];
