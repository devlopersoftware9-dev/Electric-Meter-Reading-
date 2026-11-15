import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/meter_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MeterStore.instance.load();
  runApp(const BijliMeterApp());
}

class BijliMeterApp extends StatelessWidget {
  const BijliMeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bijli Meter',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
