import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:flutter_geofence/geofence.dart';
import 'package:fl_location/fl_location.dart'
    as fl_location; // Prefixing with `fl_location` to avoid conflict

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location & Camera',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: GeofencingMap(),
    );
  }
}

class GeofencingMap extends StatefulWidget {
  @override
  _GeofencingMapState createState() => _GeofencingMapState();
}

class _GeofencingMapState extends State<GeofencingMap> {
  GoogleMapController? _mapController;
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  LatLng? _center;
  bool _geofenceActive = false;
  late geolocator.Position _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initGeofence();
    _startLocationUpdates();
  }

  // Initialize Geofence listeners for entry and exit
  void _initGeofence() {
    Geofence.initialize();

    // Listening for geofence entry
    Geofence.startListening(GeolocationEvent.entry, (entry) {
      _showAlert("Geofence Alert", "Device has entered the geofence area!");
    });

    // Listening for geofence exit
    Geofence.startListening(GeolocationEvent.exit, (entry) {
      _showAlert("Geofence Alert", "Device has exited the geofence area!");
    });
  }

  // Get current location of the device
  Future<void> _getCurrentLocation() async {
    try {
      // Request location permission if not granted
      geolocator.LocationPermission permission =
          await geolocator.Geolocator.checkPermission();
      if (permission == geolocator.LocationPermission.denied) {
        permission = await geolocator.Geolocator.requestPermission();
      }

      // Fetch the current position
      geolocator.Position position =
          await geolocator.Geolocator.getCurrentPosition(
              desiredAccuracy: geolocator.LocationAccuracy.high);
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _currentPosition = position;
        _addMarker(_center!);
      });
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  // Add a marker at the current location
  void _addMarker(LatLng position) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(position.toString()),
          position: position,
          infoWindow: InfoWindow(title: 'Current Location'),
        ),
      );
    });
  }

  // Add geofence at the current location
  void _addGeofence() {
    if (_center != null) {
      setState(() {
        _circles.add(
          Circle(
            circleId: CircleId(_center.toString()),
            center: _center!,
            radius: 1, // Set to 50 meters for smaller radius
            fillColor: Colors.blue.withOpacity(0.2),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
        _geofenceActive = true;
      });

      Geofence.addGeolocation(
        Geolocation(
          id: "myGeofence",
          latitude: _center!.latitude,
          longitude: _center!.longitude,
          radius: 1, // 50 meters radius
        ),
        GeolocationEvent.entry,
      );

      Geofence.addGeolocation(
        Geolocation(
          id: "myGeofence",
          latitude: _center!.latitude,
          longitude: _center!.longitude,
          radius: 1, // 50 meters radius
        ),
        GeolocationEvent.exit,
      );

      _showAlert("Geofence Added",
          "A geofence has been set around your current location.");
    }
  }

  // Remove the geofence and clear the circles
  void _removeGeofence() {
    setState(() {
      _circles.clear();
      _geofenceActive = false;
    });
    // Geofence.removeGeolocation();
    _showAlert("Geofence Removed", "The geofence has been removed.");
  }

  // Show alert dialog for geofence events
  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Continuous location updates to check if the user is outside the geofence
  void _startLocationUpdates() {
    geolocator.Geolocator.getPositionStream(
      locationSettings: geolocator.LocationSettings(
        accuracy: geolocator.LocationAccuracy.high,
        distanceFilter: 1, // Check location every 10 meters
      ),
    ).listen((geolocator.Position position) {
      // Calculate distance from the geofence center
      double distance = geolocator.Geolocator.distanceBetween(position.latitude,
          position.longitude, _center!.latitude, _center!.longitude);

      if (distance > 1) {
        // If outside geofence radius
        _showAlert("Geofence Alert", "Device has exited the geofence area!");
      }
    });
  }

  @override
  void dispose() {
    Geofence.removeAllGeolocations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Geofencing Map'),
        backgroundColor: Colors.teal,
      ),
      body: _center == null
          ? Center(child: CircularProgressIndicator())
          : GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _center!,
                zoom: 14.0,
              ),
              markers: _markers,
              circles: _circles,
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_geofenceActive)
            FloatingActionButton(
              onPressed: _addGeofence,
              child: Icon(Icons.add_location),
              backgroundColor: Colors.teal,
            ),
          if (_geofenceActive)
            FloatingActionButton(
              onPressed: _removeGeofence,
              child: Icon(Icons.remove_circle_outline),
              backgroundColor: Colors.red,
            ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            child: Icon(Icons.my_location),
            backgroundColor: Colors.teal,
          ),
        ],
      ),
    );
  }
}
