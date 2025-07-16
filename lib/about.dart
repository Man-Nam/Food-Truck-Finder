// File: lib/about_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final String githubUrl = 'https://github.com/your-username/Food-Truck-Finder'; // Replace with your GitHub URL

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(githubUrl);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Food Truck Finder'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Food Truck Finder',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            const Text(
              'Version: 1.0.0',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'Developers:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(' - Muhammad Afiq Arif bin Mohd Idris(2023197509)', style: TextStyle(fontSize: 16)),
            const Text(' - Muhammad Farhan bin Izazul(2023371819)', style: TextStyle(fontSize: 16)),
            const Text(' - Muhammad Afiq Haikal Bin Amirul(2023141367)', style: TextStyle(fontSize: 16)),
            const Text(' - Muhammad Aiman Fakhry Bin Mohamed Radzi(2023516205)', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Text(
              'Information:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'This mobile application implements a crowdsourced food truck location reporting system. Users can view real-time food truck locations on a map and report new sightings. The backend is powered by Laravel, providing a robust API for data management.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'Copyright Statement:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              '© 2025 Food Truck Finder. All rights reserved.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              'Application Website:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            InkWell(
              onTap: _launchUrl,
              child: Text(
                githubUrl,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
