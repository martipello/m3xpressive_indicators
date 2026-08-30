import 'package:flutter/material.dart';
import 'package:m3xpressive_indicators/m3xpressive_indicators.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'm3xpressive_indicators example',
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatelessWidget {
  const ExampleHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('m3xpressive_indicators')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Circular — loading'),
              const SizedBox(height: 8),
              const M3XCircularWavyProgressIndicator(size: 96),
              const SizedBox(height: 32),
              const Text('Circular — determinate (40%)'),
              const SizedBox(height: 8),
              const M3XCircularWavyProgressIndicator(value: 0.4, size: 96),
              const SizedBox(height: 32),
              const Text('Circular — indeterminate (vibes-accurate, rotating)'),
              const SizedBox(height: 8),
              const M3XCircularWavyLoadingIndicator(size: 96),
              const SizedBox(height: 32),
              const Text('Linear — loading'),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: M3XLinearWavyProgressIndicator(),
              ),
              const SizedBox(height: 32),
              const Text('Linear — determinate (40%)'),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: M3XLinearWavyProgressIndicator(value: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
