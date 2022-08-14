import 'package:app/classes/my_audio_handler.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

String staticText = "unaffected";

// MaterialColor themeColor = MaterialColor(0x);
// var a = Color.fromARGB(255, 0, 96, 100);
// var c = Colors.cyan.shade900;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peloton Communicator',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.cyan,
      ),
      home: const MyHomePage(title: 'Peloton Communicator - List of Groups'),
    );
  }
}

MyAudioHandler audioHandler = MyAudioHandler();

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  bool speaking = false;
  bool keyPressed = false;
  bool playing = false;
  bool recording = false;

  String? _message;

  String _defineText() {
    return speaking ? "speaking" : "listening";
  }

  String _showKeyPress() {
    return keyPressed ? "" : "N/A";
  }

  void _handleKeyEvent(RawKeyEvent event) {
    setState(() {
      if (event.logicalKey == LogicalKeyboardKey.keyQ) {
        _message = 'Pressed the "Q" key!';
      } else if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
          event.logicalKey == LogicalKeyboardKey.mediaPlay) {
        _message = 'Pressed the "media" key!';
      } else if (event.logicalKey ==
          LogicalKeyboardKey
              .audioVolumeUp /*|| event.logicalKey == LogicalKeyboardKey.volum */) {
        _message = 'Pressed the "volume up" key!';
      } else {
        _message =
            'Event: ${event.logicalKey.keyId.toRadixString(16)} || ${event.logicalKey.debugName}';

        if (_defineText() == "never happening") {
          if (kReleaseMode) {
            'Not a Q: Pressed 0x${event.logicalKey.keyId.toRadixString(16)}';
          } else {
            // The debugName will only print useful information in debug mode.
            _message = 'Not a Q: Pressed ${event.logicalKey.debugName}';
          }
        }
      }
    });
  }

  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text('${_defineText()} ${_showKeyPress()} ${widget.title}'),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.

        child: Container(
          child: GestureDetector(
              onLongPress: () {
                // print("speaking");
                setState(() {
                  speaking = true;
                  playing = false;
                  recording = true;
                  print(_defineText());
                });
              },
              onLongPressUp: () {
                setState(() {
                  speaking = false;
                  playing = true;
                  recording = false;
                  print(_defineText());
                });
              },
              child: Column(
                children: [
                  const Image(
                    image: AssetImage("assets/images/hektor_me.jpg"),
                  ),
                  DefaultTextStyle(
                    style: textTheme.headline4!,
                    child: Text('Microphone status: $recording'),
                  ),
                  DefaultTextStyle(
                    style: textTheme.headline4!,
                    child: Text('Speaker status: $playing'),
                  ),
                  DefaultTextStyle(
                    style: textTheme.headline4!,
                    child: Text('Audio handler status: $staticText'),
                  ),
                  DefaultTextStyle(
                    style: textTheme.headline4!,
                    //   child: AnimatedBuilder(
                    //     animation: _focusNode,
                    //     builder: (BuildContext context, Widget? child) {
                    //       if (!_focusNode.hasFocus) {
                    //         return GestureDetector(
                    //           onTap: () {
                    //             FocusScope.of(context).requestFocus(_focusNode);
                    //           },
                    //           child: const Text('Tap to focus'),
                    //         );
                    //       }
                    //       return Text(_message ?? 'Press a key');
                    //     },
                    //   ),
                    // ),
                    child: RawKeyboardListener(
                      focusNode: _focusNode,
                      onKey: _handleKeyEvent,
                      child: AnimatedBuilder(
                        animation: _focusNode,
                        builder: (BuildContext context, Widget? child) {
                          if (!_focusNode.hasFocus) {
                            return GestureDetector(
                              onTap: () {
                                FocusScope.of(context).requestFocus(_focusNode);
                              },
                              child: const Text('Tap to focus'),
                            );
                          }
                          return Text(_message ?? 'Press a key');
                        },
                      ),
                    ),
                  ),
                ],
              )),
        ),
      ),

      //   floatingActionButton: FloatingActionButton(
      //     // foregroundColor: Colors.lime,
      //     splashColor: Colors.lime,
      //     onPressed: _incrementCounter,
      //     tooltip: 'Speak',
      //     child: const Icon(Icons.mic, color: Colors.amber),
      //   ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
