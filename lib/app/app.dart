import 'package:flutter/material.dart';

/// Root widget. Theme and router are wired in M1/M2; for now it shows a
/// placeholder so the bootstrap path can be verified on device.
class HaraPlayApp extends StatelessWidget {
  const HaraPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'HaraPlay',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'HaraPlay',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
