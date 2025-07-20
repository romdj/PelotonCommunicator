import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ptt_service.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PTTService(),
      child: MaterialApp(
        title: 'Peloton Communicator',
        theme: ThemeData(primarySwatch: Colors.deepOrange),
        home: const HomeScreen(),
      ),
    );
  }
}
