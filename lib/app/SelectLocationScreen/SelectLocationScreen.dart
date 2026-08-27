import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  State<SelectLocationScreen> createState() =>
      _SelectLocationScreenState();
}

class _SelectLocationScreenState
    extends State<SelectLocationScreen> {
  GoogleMapController? _mapController;

  // Default location.
  // This will be replaced by the user's current location.
  LatLng _selectedLocation =
  const LatLng(17.385044, 78.486671);

  String _selectedAddress =
      'Select your location';

  bool _isLoadingLocation = true;
  bool _isGettingAddress = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ============================================================
  // GET CURRENT LOCATION
  // ============================================================

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      // Check location service
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _selectedAddress =
          'Please enable location service';
        });

        await _showLocationServiceDialog();
        return;
      }

      // Check permission
      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _selectedAddress =
          'Location permission is required';
        });

        return;
      }

      // Get current position
      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _selectedLocation =
            currentLocation;
        _isLoadingLocation = false;
      });

      // Move map camera
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: currentLocation,
              zoom: 16,
            ),
          ),
        );
      }

      // Get address
      await _getAddressFromLocation(
        currentLocation,
      );
    } catch (e) {
      debugPrint(
        'Current location error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoadingLocation = false;
        _selectedAddress =
        'Unable to get current location';
      });
    }
  }

  // ============================================================
  // MAP CREATED
  // ============================================================

  void _onMapCreated(
      GoogleMapController controller,
      ) {
    _mapController = controller;

    // If current location was already loaded,
    // move camera to it.
    if (!_isLoadingLocation) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedLocation,
            zoom: 16,
          ),
        ),
      );
    }
  }

  // ============================================================
  // MAP TAP
  // ============================================================

  Future<void> _onMapTapped(
      LatLng position,
      ) async {
    setState(() {
      _selectedLocation = position;
      _isGettingAddress = true;
      _selectedAddress =
      'Getting address...';
    });

    await _getAddressFromLocation(
      position,
    );
  }

  // ============================================================
  // REVERSE GEOCODING
  // ============================================================

  Future<void> _getAddressFromLocation(
      LatLng position,
      ) async {
    try {
      if (mounted) {
        setState(() {
          _isGettingAddress = true;
        });
      }

      final placemarks =
      await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        if (!mounted) return;

        setState(() {
          _selectedAddress =
          'Address not found';
          _isGettingAddress = false;
        });

        return;
      }

      final place = placemarks.first;

      final List<String> addressParts =
      <String>[];

      // Building / house
      if ((place.name ?? '')
          .trim()
          .isNotEmpty) {
        addressParts.add(
          place.name!.trim(),
        );
      }

      // Street
      if ((place.street ?? '')
          .trim()
          .isNotEmpty) {
        final street =
        place.street!.trim();

        if (!addressParts.contains(
          street,
        )) {
          addressParts.add(street);
        }
      }

      // Sub-locality
      if ((place.subLocality ?? '')
          .trim()
          .isNotEmpty) {
        addressParts.add(
          place.subLocality!.trim(),
        );
      }

      // Locality / city
      if ((place.locality ?? '')
          .trim()
          .isNotEmpty) {
        addressParts.add(
          place.locality!.trim(),
        );
      }

      // Administrative area / state
      if ((place.administrativeArea ?? '')
          .trim()
          .isNotEmpty) {
        addressParts.add(
          place.administrativeArea!.trim(),
        );
      }

      // Postal code
      if ((place.postalCode ?? '')
          .trim()
          .isNotEmpty) {
        addressParts.add(
          place.postalCode!.trim(),
        );
      }

      // Country
      if ((place.country ?? '')
          .trim()
          .isNotEmpty) {
        addressParts.add(
          place.country!.trim(),
        );
      }

      final address =
      addressParts.join(', ');

      if (!mounted) return;

      setState(() {
        _selectedAddress =
        address.isNotEmpty
            ? address
            : 'Address not found';

        _isGettingAddress = false;
      });
    } catch (e) {
      debugPrint(
        'Reverse geocoding error: $e',
      );

      if (!mounted) return;

      setState(() {
        _selectedAddress =
        'Unable to get address';
        _isGettingAddress = false;
      });
    }
  }

  // ============================================================
  // CURRENT LOCATION BUTTON
  // ============================================================

  Future<void> _goToCurrentLocation() async {
    await _getCurrentLocation();

    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _selectedLocation,
            zoom: 17,
          ),
        ),
      );
    }
  }

  // ============================================================
  // CONFIRM LOCATION
  // ============================================================

  void _confirmLocation() {
    if (_isGettingAddress) {
      Get.snackbar(
        'Please wait',
        'Getting the selected address...',
        snackPosition:
        SnackPosition.BOTTOM,
      );

      return;
    }

    if (_selectedAddress.isEmpty ||
        _selectedAddress ==
            'Address not found' ||
        _selectedAddress ==
            'Unable to get address') {
      Get.snackbar(
        'Location required',
        'Please select a valid location',
        snackPosition:
        SnackPosition.BOTTOM,
      );

      return;
    }

    Get.back(
      result: <String, dynamic>{
        'address': _selectedAddress,
        'latitude':
        _selectedLocation.latitude,
        'longitude':
        _selectedLocation.longitude,
      },
    );
  }

  // ============================================================
  // LOCATION SERVICE DIALOG
  // ============================================================

  Future<void>
  _showLocationServiceDialog() async {
    if (!mounted) return;

    await Get.dialog(
      AlertDialog(
        title: const Text(
          'Location Required',
        ),
        content: const Text(
          'Please enable location services '
              'to select your current location.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text(
              'Cancel',
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();

              await Geolocator.openLocationSettings();
            },
            child: const Text(
              'Open Settings',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Location',
        ),
        centerTitle: true,
      ),

      body: Stack(
        children: [
          // ======================================================
          // GOOGLE MAP
          // ======================================================

          GoogleMap(
            initialCameraPosition:
            CameraPosition(
              target: _selectedLocation,
              zoom: 14,
            ),

            onMapCreated:
            _onMapCreated,

            onTap:
            _onMapTapped,

            myLocationEnabled: true,
            myLocationButtonEnabled: false,

            zoomControlsEnabled: false,

            mapToolbarEnabled: false,

            markers: {
              Marker(
                markerId:
                const MarkerId(
                  'selected_location',
                ),
                position:
                _selectedLocation,
                draggable: false,
              ),
            },
          ),

          // ======================================================
          // LOADING LOCATION
          // ======================================================

          if (_isLoadingLocation)
            Container(
              color: Colors.black
                  .withOpacity(0.15),
              child: const Center(
                child:
                CircularProgressIndicator(),
              ),
            ),

          // ======================================================
          // CURRENT LOCATION BUTTON
          // ======================================================

          Positioned(
            right: 16,
            top: 16,
            child: Material(
              elevation: 4,
              borderRadius:
              BorderRadius.circular(
                12,
              ),
              child: InkWell(
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
                onTap:
                _goToCurrentLocation,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // BOTTOM LOCATION CARD
          // ======================================================

          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding:
              const EdgeInsets.all(
                16,
              ),
              decoration:
              BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(
                  18,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 15,
                    spreadRadius: 1,
                    offset:
                    const Offset(0, 4),
                    color: Colors.black
                        .withOpacity(0.15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 22,
                        color:
                        Colors.red,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child: _isGettingAddress
                            ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child:
                              CircularProgressIndicator(
                                strokeWidth:
                                2,
                              ),
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Text(
                              'Getting address...',
                            ),
                          ],
                        )
                            : Text(
                          _selectedAddress,
                          maxLines: 3,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                    style:
                    const TextStyle(
                      fontSize: 12,
                      color:
                      Colors.grey,
                    ),
                  ),

                  Text(
                    'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                    style:
                    const TextStyle(
                      fontSize: 12,
                      color:
                      Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  SizedBox(
                    width:
                    double.infinity,
                    height: 48,
                    child:
                    ElevatedButton(
                      onPressed:
                      _isGettingAddress
                          ? null
                          : _confirmLocation,
                      child: const Text(
                        'Confirm Location',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}