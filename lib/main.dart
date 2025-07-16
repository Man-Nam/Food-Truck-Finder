import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:url_launcher/url_launcher.dart'; // Still needed if you use launchUrl elsewhere, otherwise can be removed if only AboutScreen uses it
import 'package:foodtrucktracker/about.dart'; // NEW: Import the AboutScreen from its separate file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Truck Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FoodTruckMapScreen(),
    );
  }
}

class FoodTruckMapScreen extends StatefulWidget {
  const FoodTruckMapScreen({super.key});

  @override
  State<FoodTruckMapScreen> createState() => _FoodTruckMapScreenState();
}

class _FoodTruckMapScreenState extends State<FoodTruckMapScreen> {
  GoogleMapController? mapController;
  final Map<MarkerId, Marker> _markers = {};
  LatLng? _currentLocation;
  bool _isLoading = true;

  // IMPORTANT: For Android Emulator, use 10.0.2.2 to connect to host machine's localhost.
  // For iOS Simulator, 'http://localhost:8000/api' might work, or use your local IP.
  // For physical devices, you MUST use your host machine's actual local IP address (e.g., http://192.168.1.X:8000/api)
  final String _apiUrl = 'http://10.0.2.2:8000/api'; // FIXED: This should be the base API URL

  @override
  void initState() {
    super.initState();
    _checkLocationPermissionAndFetchTrucks();
  }

  Future<void> _checkLocationPermissionAndFetchTrucks() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
      });
      _showPermissionDeniedForeverDialog();
      return;
    }

    _determinePosition();
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Denied'),
        content: const Text(
            'Location access is required to show food trucks near you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Denied Forever'),
        content: const Text(
            'Location access has been permanently denied. Please enable it in your device settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings(); // Opens app settings for user to enable
            },
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _determinePosition() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      // Animate camera only if mapController is available
      if (mapController != null) {
        mapController?.animateCamera(CameraUpdate.newLatLng(_currentLocation!));
      }
      _fetchFoodTrucks();
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
      // Handle error, e.g., show a message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location.')),
      );
    }
  }

  Future<void> _fetchFoodTrucks() async {
    try {
      // Corrected URL: now it will be http://10.0.2.2:8000/api/foodtrucks
      final response = await http.get(Uri.parse('$_apiUrl/foodtrucks'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _markers.clear();
        for (var truckData in data) {
          final FoodTruck truck = FoodTruck.fromJson(truckData);
          await _addFoodTruckMarker(truck);
        }
        setState(() {}); // Rebuild to show new markers
      } else {
        print('Failed to load food trucks: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load food trucks.')),
        );
      }
    } catch (e) {
      print('Error fetching food trucks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error connecting to server.')),
      );
    }
  }

  Future<void> _addFoodTruckMarker(FoodTruck truck) async {
    // Determine the marker icon
    BitmapDescriptor markerIcon;
    if (truck.markerIconUrl != null && truck.markerIconUrl!.isNotEmpty) {
      try {
        // Fetch image bytes from the network
        final http.Response response = await http.get(Uri.parse(truck.markerIconUrl!));
        if (response.statusCode == 200) {
          final ui.Codec codec = await ui.instantiateImageCodec(response.bodyBytes, targetWidth: 80); // Adjust size as needed
          final ui.FrameInfo fi = await codec.getNextFrame();
          final ui.Image image = fi.image;
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            markerIcon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
          } else {
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange); // Fallback if byteData is null
          }
        } else {
          print('Failed to load custom marker icon from URL: ${truck.markerIconUrl!} status: ${response.statusCode}');
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange); // Fallback
        }
      } catch (e) {
        print('Error loading custom marker icon for ${truck.name}: $e');
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange); // Fallback to default
      }
    } else {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }

    final MarkerId markerId = MarkerId(truck.id.toString());
    final Marker marker = Marker(
      markerId: markerId,
      position: LatLng(truck.latitude, truck.longitude),
      icon: markerIcon,
      infoWindow: InfoWindow(
        title: truck.name,
        snippet:
        'Type: ${truck.type}\nLast Reported: ${DateFormat('MMM dd, yyyy HH:mm').format(truck.lastReportedAt)}\nReported by: ${truck.reportedByUserName}',
      ),
      onTap: () {
        // You can add more detailed info or actions here
      },
    );
    _markers[markerId] = marker;
  }

  Future<void> _reportFoodTruckLocation(LatLng location) async {
    TextEditingController nameController = TextEditingController();
    TextEditingController typeController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Food Truck Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Food Truck Name'),
              ),
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Food Type (e.g., Burger, Taco)'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description (Optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              Text('Lat: ${location.latitude.toStringAsFixed(6)}'),
              Text('Long: ${location.longitude.toStringAsFixed(6)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || typeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and Type are required.')),
                );
                return;
              }

              // For demonstration, we're not using a real user ID.
              // In a production app, you'd integrate with an authentication system
              // (e.g., Firebase Auth, Laravel Passport/Sanctum) to get the actual user ID.
              // For now, the backend might assign a default or anonymous user.
              final response = await http.post(
                Uri.parse('$_apiUrl/foodtrucks/report'), // This will now correctly be /api/foodtrucks/report
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'name': nameController.text,
                  'type': typeController.text,
                  'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                  // 'user_id': 1, // Uncomment and replace with actual authenticated user ID if implemented
                }),
              );

              if (response.statusCode == 201) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Food truck reported successfully!')),
                );
                Navigator.of(context).pop();
                _fetchFoodTrucks(); // Refresh markers
              } else {
                print('Failed to report food truck: ${response.body}');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to report food truck.')),
                );
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Truck Finder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline), // About icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchFoodTrucks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        onMapCreated: (controller) {
          mapController = controller;
          if (_currentLocation != null) {
            mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
            );
          }
        },
        initialCameraPosition: CameraPosition(
          target: _currentLocation ?? const LatLng(3.1390, 101.6869), // Default to Kuala Lumpur if no location
          zoom: 12.0,
        ),
        markers: Set<Marker>.of(_markers.values),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onLongPress: _reportFoodTruckLocation, // Long press to report
        zoomControlsEnabled: true, // Zoom buttons are enabled
        mapToolbarEnabled: false,   // Hides the directions and Google Maps app buttons
      ),
    );
  }
}

// FoodTruck Model for parsing JSON from API
class FoodTruck {
  final int id;
  final String name;
  final String type;
  final String? description;
  final double latitude;
  final double longitude;
  final DateTime lastReportedAt;
  final String? reportedByUserName;
  final String? markerIconUrl;

  FoodTruck({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.lastReportedAt,
    this.reportedByUserName,
    this.markerIconUrl,
  });

  factory FoodTruck.fromJson(Map<String, dynamic> json) {
    return FoodTruck(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      description: json['description'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      lastReportedAt: DateTime.parse(json['last_reported_at']),
      reportedByUserName: json['reported_by'] != null ? json['reported_by']['name'] : 'Anonymous',
      markerIconUrl: json['marker_icon_url'],
    );
  }
}
