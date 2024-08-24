import 'dart:async'; // Import the dart async package for Timer

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class Mapp extends StatefulWidget {
  const Mapp({super.key});

  @override
  State<Mapp> createState() => _MappState();
}

class _MappState extends State<Mapp> {
  User? user = FirebaseAuth.instance.currentUser; // Current user
  LatLng? _currentLocation; // Stores the current location of the device
  double _zoomLevel = 9.2; // Initial zoom level for the map
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance
  Timer? _locationTimer; // Timer to periodically update location

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Get the initial location when the widget is created
    _startLocationUpdates(); // Start the timer for periodic updates
  }

  @override
  void dispose() {
    _locationTimer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  // Method to get the current location of the device
  Future<void> _getCurrentLocation() async {
    Location location =
    Location(); // Location instance for accessing device location

    // Check if location services are enabled
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return; // If location services are not enabled, exit the method
      }
    }

    // Check if location permissions are granted
    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return; // If location permissions are not granted, exit the method
      }
    }

    // Get the current location data
    final locationData = await location.getLocation();
    setState(() {
      _currentLocation =
          LatLng(locationData.latitude!, locationData.longitude!);
      _zoomLevel = 15.0; // Set a higher zoom level when location is found
    });

    // Update the location in Firestore
    _updateLocationInFirebase(locationData.latitude!, locationData.longitude!);
  }

  // Method to start the periodic location updates
  void _startLocationUpdates() {
    // Schedule a location update every minute (60 seconds)
    _locationTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _getCurrentLocation(); // Fetch and update location every minute
    });
  }

  // Method to update the location in Firestore
  Future<void> _updateLocationInFirebase(
      double latitude, double longitude) async {
    try {
      await _firestore.collection('users').doc(user?.uid).update({
        'latitude': latitude, // Update the latitude field
        'longitude': longitude, // Update the longitude field
        'timestamp': FieldValue
            .serverTimestamp(), // Update the timestamp field with server time
      });
      print('Location data updated in Firebase');
    } catch (e) {
      print('Error updating location data: $e'); // Print any errors that occur
    }
  }

  // Method to build the markers for the map
  Future<List<Marker>> _buildMarkers() async {
    List<Marker> markers = []; // List to hold the markers

    try {
      // Get all documents from the "users" collection
      QuerySnapshot querySnapshot = await _firestore.collection('users').get();

      // Iterate over each document in the collection
      for (var doc in querySnapshot.docs) {
        if (doc.id != user?.uid) {
          // Exclude current user's document
          final data =
          doc.data() as Map<String, dynamic>; // Get the document data
          final latitude = data['latitude']; // Get the latitude field
          final longitude = data['longitude']; // Get the longitude field
          final name = data['name']; // Get the name field
          final timestamp = data['timestamp']
              ?.toDate(); // Get the timestamp field and convert it to DateTime

          // Check if latitude and longitude are not null
          if (latitude != null && longitude != null) {
            // Create a marker for each user location
            markers.add(
              Marker(
                point: LatLng(latitude, longitude), // Set the marker position
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.red, size: 40), // Marker icon
                    Text(
                      name ??
                          'Unknown', // Display the name or 'Unknown' if null
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      timestamp != null
                          ? '${timestamp.year}-${timestamp.month}-${timestamp.day} ${timestamp.hour}:${timestamp.minute}' // Format the timestamp
                          : 'No Date', // Display 'No Date' if timestamp is null
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching markers: $e'); // Print any errors that occur
    }

    return markers; // Return the list of markers
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _currentLocation == null
          ? Center(
          child:
          CircularProgressIndicator()) // Show a loading indicator if location is not available
          : FutureBuilder<List<Marker>>(
        future: _buildMarkers(), // Call the method to build markers
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child:
                CircularProgressIndicator()); // Show loading indicator while fetching markers
          }

          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Error fetching markers')); // Show error message if fetching markers fails
          }

          List<Marker> markers =
          snapshot.data!; // Get the list of markers from snapshot

          return FlutterMap(
            options: MapOptions(
              initialCenter:
              _currentLocation!, // Center the map on the current location
              initialZoom: _zoomLevel,

              // Set the initial zoom level
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
                maxZoom: 19, // Maximum zoom level for the map
              ),
              MarkerLayer(
                markers: markers, // Add the retrieved markers to the map
              ),
              CurrentLocationLayer(), // Layer to show the current location marker
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                        Uri.parse('https://openstreetmap.org/copyright')),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}