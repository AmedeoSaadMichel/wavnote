// File: services/location/geolocation_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../domain/repositories/i_location_repository.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failure_types/system_failures.dart';

class GeolocationService implements ILocationRepository {
  static const String _tag = 'GeolocationService';

  @override
  Future<String> getCurrentAddress() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          return _getFallbackAddress();
      }

      if (permission == LocationPermission.deniedForever ||
          !await Geolocator.isLocationServiceEnabled()) {
        return _getFallbackAddress();
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          return _formatAddress(placemarks.first);
        } else {
          return _getFallbackAddress();
        }
      } catch (e) {
        try {
          final osmAddress = await _getOSMAddress(
            position.latitude,
            position.longitude,
          );
          return osmAddress ??
              'Lat ${position.latitude.toStringAsFixed(3)}, Lng ${position.longitude.toStringAsFixed(3)}';
        } catch (osmError) {
          throw NetworkException(
            message: 'Geocoding failed',
            errorType: NetworkErrorType.serverError,
            originalError: osmError,
          );
        }
      }
    } catch (e) {
      if (e is WavNoteException) rethrow;
      throw SystemException(
        message: 'Failed to get location: ${e.toString()}',
        errorType: SystemErrorType.unknown,
        originalError: e,
      );
    }
  }

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
            if (address.containsKey('house_number'))
              road += ' ${address['house_number']}';
            parts.add(road);
          }
          if (address.containsKey('city') || address.containsKey('town')) {
            parts.add(
              address['city'] ?? address['town'] ?? address['village'] ?? '',
            );
          }
          return parts.where((p) => p.isNotEmpty).join(', ');
        }
      }
    } catch (e) {
      debugPrint('$_tag: OSM HTTP request failed: $e');
    }
    return null;
  }

  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];
    if (placemark.thoroughfare != null && placemark.thoroughfare!.isNotEmpty) {
      String street = placemark.thoroughfare!;
      if (placemark.subThoroughfare != null &&
          placemark.subThoroughfare!.isNotEmpty) {
        street = '$street ${placemark.subThoroughfare}';
      }
      addressParts.add(street);
    } else if (placemark.street != null && placemark.street!.isNotEmpty) {
      if (placemark.street != placemark.country &&
          placemark.street != placemark.locality)
        addressParts.add(placemark.street!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty)
      addressParts.add(placemark.locality!);
    return addressParts.isNotEmpty
        ? addressParts.join(', ')
        : _getFallbackAddress();
  }

  String _getFallbackAddress() =>
      'Recording ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

  @override
  Future<String> getRecordingLocationName() async {
    try {
      final fullAddress = await getCurrentAddress();
      if (fullAddress.contains(',')) return fullAddress.split(',').first.trim();
      return fullAddress;
    } catch (e) {
      return _getFallbackAddress();
    }
  }

  @override
  Future<bool> hasLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      return false;
    }
  }
}
