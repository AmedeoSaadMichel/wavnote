// File: domain/repositories/i_location_repository.dart
abstract class ILocationRepository {
  /// Get current location and convert to address
  Future<String> getCurrentAddress();

  /// Get simplified address for recording names (street name + number only)
  Future<String> getRecordingLocationName();

  /// Check if location permissions are available
  Future<bool> hasLocationPermission();

  /// Request location permissions
  Future<bool> requestLocationPermission();
}
