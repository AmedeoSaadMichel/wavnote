// File: services/location/geolocation_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('$_tag: ❌ Location services are disabled');
        return _getFallbackAddress();
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('$_tag: ❌ Location permissions are denied');
          return _getFallbackAddress();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('$_tag: ❌ Location permissions are permanently denied');
        return _getFallbackAddress();
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('$_tag: 📍 Location: ${position.latitude}, ${position.longitude}');

      // Convert coordinates to address
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
      print('$_tag: ❌ Error getting location: $e');
      return _getFallbackAddress();
    }
  }

  /// Format placemark into a clean address string
  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];

    // Add street name and number (e.g., "Via Cerlini 19")
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      addressParts.add(placemark.street!);
    } else {
      // Fallback: use thoroughfare + subThoroughfare
      if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
        String street = placemark.thoroughfare!;
        if (placemark.subThoroughfare != null && placemark.subThoroughfare!.isNotEmpty) {
          street = '$street ${placemark.subThoroughfare}';
        }
        addressParts.add(street);
      }
    }

    // Add locality (city name) if available
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }

    // If we have address parts, join them
    if (addressParts.isNotEmpty) {
      return addressParts.join(', ');
    }

    // Last resort: use administrative area
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

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