// File: services/location/geolocation_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:io';

/// Service for handling geolocation and address lookup
///
/// Provides methods to get current location and convert coordinates
/// to human-readable addresses for recording names.
class GeolocationService {
  static const String _tag = 'GeolocationService';

  /// Get current location and convert to address
  /// Returns address string like "Via Cerlini 19, Milano" or fallback
  Future<String> getCurrentAddress() async {
    try {
      print('$_tag: 📍 Getting current location...');

      // Check location permissions first, even if service appears disabled
      print('$_tag: 🔍 Checking location permissions...');
      LocationPermission permission = await Geolocator.checkPermission();
      print('$_tag: 🔍 Current permission status: $permission');

      if (permission == LocationPermission.denied) {
        print('$_tag: ✋ Permission is denied, requesting it now...');
        permission = await Geolocator.requestPermission();
        print('$_tag: 📢 Result of permission request: $permission');

        if (permission == LocationPermission.denied) {
          print('$_tag: ❌ Location permissions are still denied after request');
          return _getFallbackAddress();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('$_tag: ❌ Location permissions are permanently denied');
        return _getFallbackAddress();
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('$_tag: ❌ Location services are disabled');
        return _getFallbackAddress();
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('$_tag: 📍 Location: ${position.latitude}, ${position.longitude}');

      try {
        // Convert coordinates to address using the native package
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final address = _formatAddress(placemarks.first);
          print('$_tag: 📍 Address: $address');
          return address;
        } else {
          print('$_tag: ❌ No address found for coordinates');
          return _getFallbackAddress();
        }
      } catch (e) {
        print('$_tag: ⚠️ Error in native reverse geocoding: $e');

        // Strategy B: The native iOS/macOS geocoder often crashes inside the dart package
        // with "Null check operator used on a null value".
        // Let's use OpenStreetMap Nominatim API as a reliable fallback!
        try {
          print(
            '$_tag: 🌐 Attempting OSM fallback for Lat ${position.latitude}, Lng ${position.longitude}',
          );
          final osmAddress = await _getOSMAddress(
            position.latitude,
            position.longitude,
          );
          if (osmAddress != null && osmAddress.isNotEmpty) {
            print('$_tag: 📍 OSM Address: $osmAddress');
            return osmAddress;
          }
        } catch (osmError) {
          print('$_tag: ❌ OSM fallback also failed: $osmError');
        }

        // If even the fallback fails, return coordinates
        return 'Lat ${position.latitude.toStringAsFixed(3)}, Lng ${position.longitude.toStringAsFixed(3)}';
      }
    } catch (e) {
      print('$_tag: ❌ Error getting location: $e');
      return _getFallbackAddress();
    }
  }

  /// Request OSM Nominatim for address directly (bypass platform specific bugs)
  Future<String?> _getOSMAddress(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );

      final request = await HttpClient().getUrl(url);
      request.headers.add('User-Agent', 'WavNote/1.0 Flutter App');
      final response = await request.close();

      if (response.statusCode == 200) {
        final stringData = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = json.decode(stringData);

        if (data.containsKey('address')) {
          final address = data['address'] as Map<String, dynamic>;
          List<String> parts = [];

          if (address.containsKey('road')) {
            String road = address['road'];
            if (address.containsKey('house_number')) {
              road += ' ${address['house_number']}';
            }
            parts.add(road);
          }

          if (address.containsKey('city') ||
              address.containsKey('town') ||
              address.containsKey('village')) {
            parts.add(address['city'] ?? address['town'] ?? address['village']);
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
          return data['display_name']; // Fallback to full OSM string
        }
      }
    } catch (e) {
      print('$_tag: OSM HTTP request failed: $e');
    }
    return null;
  }

  /// Format placemark into a clean address string
  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];

    // Log the placemark to see what we actually get from Apple
    print(
      '$_tag: 📍 Placemark details: '
      'street=${placemark.street}, '
      'thoroughfare=${placemark.thoroughfare}, '
      'subThoroughfare=${placemark.subThoroughfare}, '
      'locality=${placemark.locality}, '
      'subLocality=${placemark.subLocality}, '
      'name=${placemark.name}',
    );

    // Strategy 1: Thoroughfare + SubThoroughfare (Usually the cleanest "Street Name Number")
    if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
      String street = placemark.thoroughfare!;
      if (placemark.subThoroughfare != null &&
          placemark.subThoroughfare!.isNotEmpty) {
        street = '$street ${placemark.subThoroughfare}';
      }
      addressParts.add(street);
    }
    // Strategy 2: Use "street" if thoroughfare is empty
    else if (placemark.street != null && placemark.street!.isNotEmpty) {
      // Apple sometimes returns the full address in 'street' or just the street name
      // or sometimes even just the country. We only use it if it's not a generic fallback.
      if (placemark.street != placemark.country &&
          placemark.street != placemark.locality) {
        addressParts.add(placemark.street!);
      }
    }
    // Strategy 3: Use "name" which is sometimes the point of interest or street
    else if (placemark.name != null && placemark.name!.isNotEmpty) {
      if (placemark.name != placemark.country &&
          placemark.name != placemark.locality) {
        addressParts.add(placemark.name!);
      }
    }

    // Add locality (city name) if available
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    } else if (placemark.subLocality != null &&
        placemark.subLocality!.isNotEmpty) {
      addressParts.add(placemark.subLocality!);
    }

    // If we have address parts, join them
    if (addressParts.isNotEmpty) {
      return addressParts.join(', ');
    }

    // Last resort: use administrative area
    if (placemark.administrativeArea != null &&
        placemark.administrativeArea!.isNotEmpty) {
      return placemark.administrativeArea!;
    }

    // Ultimate fallback
    return _getFallbackAddress();
  }

  /// Get fallback address when location is not available
  String _getFallbackAddress() {
    final now = DateTime.now();
    return 'Recording ${now.day}/${now.month}/${now.year}';
  }

  /// Get simplified address for recording names (street name + number only)
  Future<String> getRecordingLocationName() async {
    try {
      final fullAddress = await getCurrentAddress();

      // Extract just the street name and number (first part before comma)
      if (fullAddress.contains(',')) {
        final streetPart = fullAddress.split(',').first.trim();
        if (streetPart.isNotEmpty) {
          return streetPart;
        }
      }

      return fullAddress;
    } catch (e) {
      print('$_tag: ❌ Error getting recording location name: $e');
      return _getFallbackAddress();
    }
  }

  /// Check if location permissions are available
  Future<bool> hasLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      print('$_tag: ❌ Error checking location permission: $e');
      return false;
    }
  }

  /// Request location permissions
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      print('$_tag: ❌ Error requesting location permission: $e');
      return false;
    }
  }
}
