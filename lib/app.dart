import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/convert_provider.dart';
import 'pages/home_page.dart';

class Hdr2SdrApp extends StatelessWidget {
  const Hdr2SdrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConvertProvider(),
      child: MaterialApp(
        title: 'HDR↔SDR Converter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomePage(),
      ),
    );
  }
}
