import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> addresses;
  const MapScreen({required this.addresses});
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final Map<MarkerId, Marker> _markers = {};
  LatLngBounds? _latLngBounds;
  LatLng? _currentLocation;
  bool _locationServiceEnabled = false;
  Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();
  static const String _googleApiKey = 'AIzaSyB7krJjitH00FhPStq5wV_h4taB-0U2-dM';

  @override
  void initState() {
    super.initState();
    _checkLocationServices();
  }

  Future<void> _checkLocationServices() async {
    final serviceStatus = await Geolocator.isLocationServiceEnabled();
    setState(() => _locationServiceEnabled = serviceStatus);
    if (serviceStatus) {
      await _getCurrentLocation();
      _loadMarkers();
    }
  }

  Future<void> _loadMarkers() async {
    _polylines.clear();
    _markers.clear();

    if (widget.addresses.isEmpty) return;

    // 1. Sort addresses by distance from current location
    List<Map<String, dynamic>> sortedAddresses = await _sortAddressesByProximity();

    // 2. Collect all points in order
    List<LatLng> allPoints = [];

    // Add current location if available
    if (_currentLocation != null) {
      allPoints.add(_currentLocation!);
    }

    // Add from points
    for (final address in sortedAddresses) {
      final from = address['from'];
      allPoints.add(LatLng(from['lat'], from['lng']));
      _addAddressMarker(from, 'From ${sortedAddresses.indexOf(address)}');
    }

    // Add to points
    for (final address in sortedAddresses) {
      final to = address['to'];
      allPoints.add(LatLng(to['lat'], to['lng']));
      _addAddressMarker(to, 'To ${sortedAddresses.indexOf(address)}');
    }

    // 3. Calculate route
    if (allPoints.length > 1) {
      await _getCombinedRoute(allPoints);
    }

    _updateCameraPosition(allPoints);
  }

  Future<List<Map<String, dynamic>>> _sortAddressesByProximity() async {
    if (_currentLocation == null) return widget.addresses;

    List<Map<String, dynamic>> addresses = List.from(widget.addresses);

    addresses.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        a['from']['lat'],
        a['from']['lng'],
      );

      double distanceB = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        b['from']['lat'],
        b['from']['lng'],
      );

      return distanceA.compareTo(distanceB);
    });

    return addresses;
  }

  Future<void> _getCombinedRoute(List<LatLng> points) async {
    try {
      final origin = points.first;
      final destination = points.last;
      final waypoints = points.sublist(1, points.length - 1);

      String waypointsParam = '';
      if (waypoints.isNotEmpty) {
        waypointsParam = 'waypoints=optimize:false|${waypoints.map((p) => '${p.latitude},${p.longitude}').join('|')}&';
      }

      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${origin.latitude},${origin.longitude}&'
              'destination=${destination.latitude},${destination.longitude}&'
              '$waypointsParam'
              'key=$_googleApiKey'
      ));

      final data = json.decode(response.body);
      print('Directions API Response: ${response.body}');

      if (data['status'] == 'OK') {
        final points = data['routes'][0]['overview_polyline']['points'];
        final decodedPoints = _polylinePoints.decodePolyline(points);

        setState(() {
          _polylines.add(Polyline(
            polylineId: const PolylineId('main_route'),
            color: Colors.blue,
            width: 4,
            points: decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          ));
        });
      } else {
        print('Directions API Error: ${data['error_message']}');
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  Future<void> _getRouteDirections(LatLng origin, LatLng destination, {required int index}) async {
    try {
      final response = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${origin.latitude},${origin.longitude}&'
              'destination=${destination.latitude},${destination.longitude}&'
              'key=$_googleApiKey'
      ));

      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final points = data['routes'][0]['overview_polyline']['points'];
        final decodedPoints = _polylinePoints.decodePolyline(points);

        final polylineId = PolylineId('route_$index');
        final polyline = Polyline(
          polylineId: polylineId,
          color: Colors.blue,
          width: 4,
          points: decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
        );

        setState(() => _polylines.add(polyline));
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  void _addAddressMarker(Map<String, dynamic> address, String title) {
    final markerId = MarkerId('marker_${UniqueKey()}');
    _markers[markerId] = Marker(
      markerId: markerId,
      position: LatLng(address['lat'], address['lng']),
      infoWindow: InfoWindow(title: title),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _addCurrentLocationMarker();
      });

      if (mapController != null) {
        _updateCameraPosition([_currentLocation!]);
      }
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentLocation == null) return;

    const markerId = MarkerId('current_location');
    _markers[markerId] = Marker(
      markerId: markerId,
      position: _currentLocation!,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'Your Current Location'),
    );
  }

  void _updateCameraPosition(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return;

    setState(() {
      _latLngBounds = LatLngBounds(
        southwest: LatLng(
          coordinates.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
          coordinates.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          coordinates.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
          coordinates.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
        ),
      );
    });

    if (mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(_latLngBounds!, 100),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Rides')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              _loadMarkers();
            },
            markers: Set<Marker>.of(_markers.values),
            polylines: _polylines, // Add this line
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(20.5937, 78.9629),
              zoom: _currentLocation != null ? 12 : 4,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              child: const Icon(Icons.my_location),
              onPressed: () {
                if (_currentLocation != null) {
                  mapController.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 14),
                  );
                }
              },
            ),
          ),
          if (!_locationServiceEnabled)
            const Positioned(
              top: 20,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Enable location services to see your position'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}