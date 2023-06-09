import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
const kGoogleApiKey = 'AIzaSyAlLKG3vH8o0g7035q33C1PV9mRWzuK1nU';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _controller;
  final Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  LatLng? _currentLocation;
  LatLng? _destination;
  bool _showSatelliteView = false;
  PolylinePoints polylinePoints = PolylinePoints();
  Map<PolylineId, Polyline> polylines = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _getCurrentLocation();
    super.initState();
  }

  Future<void> _getPolyline() async {
    List<LatLng> polylineCoordinates = [];

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      kGoogleApiKey,
      PointLatLng(_currentLocation!.latitude, _currentLocation!.longitude),
      PointLatLng(_destination!.latitude, _destination!.longitude),
      travelMode: TravelMode.driving,
    );
    print("********************${result.points}");
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(
          LatLng(point.latitude, point.longitude),
        );
      });
    } else {
      print(result.errorMessage);
    }
    _addPolyLine(polylineCoordinates);
  }

  _addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 8,
    );
    polylines[id] = polyline;
    setState(() {});
  }

  Future<List<LatLng>> getRouteCoordinates(
      LatLng origin, LatLng destination) async {
    List<LatLng> polylineCoordinates = [];

    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao',
      PointLatLng(origin.latitude, origin.longitude),
      PointLatLng(destination.latitude, destination.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }
    return polylineCoordinates;
  }

  Future<void> _searchLocation(String searchQuery) async {
    if (searchQuery.isNotEmpty) {
      List<Location> locations =
          await locationFromAddress(searchQuery.toLowerCase());
      if (locations.isNotEmpty) {
        setState(() {
          _destination = LatLng(locations[0].latitude, locations[0].longitude);
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: _destination!,
              infoWindow: const InfoWindow(title: 'Destination'),
            ),
          );
        });
        _moveCameraToDestination();
      } else {
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Not Found'),
              content: const Text('Unable to find the specified location.'),
              actions: [
                ElevatedButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(
      () {
        _currentLocation = LatLng(position.latitude, position.longitude);
        print("------------------------------------ $_currentLocation");
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _currentLocation!,
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        );
      },
    );
  }

  void _moveCameraToDestination() {
    final CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
            _currentLocation!.latitude < _destination!.latitude
                ? _currentLocation!.latitude
                : _destination!.latitude,
            _currentLocation!.longitude < _destination!.longitude
                ? _currentLocation!.longitude
                : _destination!.longitude),
        northeast: LatLng(
            _currentLocation!.latitude > _destination!.latitude
                ? _currentLocation!.latitude
                : _destination!.latitude,
            _currentLocation!.longitude > _destination!.longitude
                ? _currentLocation!.longitude
                : _destination!.longitude),
      ),
      100.0,
    );
    _controller!.animateCamera(cameraUpdate);
  }

  Future<void> _getDistance() async {
    if (_currentLocation != null && _destination != null) {
      final distance = Geolocator.distanceBetween(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
          _destination!.latitude,
          _destination!.longitude);
      double distanceInKm = distance / 1000;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Distance'),
            content: Text('${distanceInKm.toStringAsFixed(2)} km'),
            actions: [
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please set a destination location.'),
            actions: [
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _navigateToDestination() async {
    if (_destination != null) {
      final url = 'https://www.google.com/maps/dir/?api=1&destination=' +
          _destination!.latitude.toString() +
          ',' +
          _destination!.longitude.toString();
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: const Text('Unable to navigate.'),
              actions: [
                ElevatedButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: const Text('Please set a destination location.'),
            actions: [
              ElevatedButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _toggleSatelliteView() {
    setState(() {
      _showSatelliteView = !_showSatelliteView;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Google Maps"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _controller = controller;
            },
            markers: _markers,
            compassEnabled: true,
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(0, 0),
              zoom: 14,
            ),
            polylines: Set<Polyline>.of(polylines.values),
            mapType: _showSatelliteView ? MapType.satellite : MapType.normal,
            myLocationEnabled: true,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  contentPadding: const EdgeInsets.only(top: 15, left: 10),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        _searchLocation(_searchController.text);
                      }
                      ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Row(
              children: [
                const SizedBox(width: 10.0),
                FloatingActionButton(
                  onPressed: _toggleSatelliteView,
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(width: 10.0),
                FloatingActionButton(
                  child: const Icon(Icons.directions),
                  onPressed: ()
                      {
                        _getPolyline();
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(builder: (context) => PolylineScreen()),
                    // );
                  },
                ),
                const SizedBox(width: 10.0),
                FloatingActionButton(
                  onPressed: _getDistance,
                  child: const Icon(Icons.navigation),
                ),
                const SizedBox(width: 10.0),
                FloatingActionButton(
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.location_searching),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
