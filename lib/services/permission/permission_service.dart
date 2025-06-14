import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionHandler {
  // Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // Request location permission
  static Future<bool> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }

  // Request storage permission
  static Future<bool> requestStoragePermission() async {
    PermissionStatus status = await Permission.storage.request();
    if (status != PermissionStatus.granted) {
      // Try manage external storage for Android 11+
      status = await Permission.manageExternalStorage.request();
    }
    return status == PermissionStatus.granted;
  }

  // Request all permissions
  static Future<Map<String, bool>> requestAllPermissions() async {
    bool microphoneGranted = await requestMicrophonePermission();
    bool locationGranted = await requestLocationPermission();
    bool storageGranted = await requestStoragePermission();

    return {
      'microphone': microphoneGranted,
      'location': locationGranted,
      'storage': storageGranted,
    };
  }

  // Request specific permission (generic method)
  static Future<bool> requestPermission(Permission permission) async {
    PermissionStatus status = await permission.request();
    return status == PermissionStatus.granted;
  }

  // Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    PermissionStatus status = await permission.status;
    return status == PermissionStatus.granted;
  }

  // Open app settings if permission is permanently denied
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

class PermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionScreen({Key? key, required this.onPermissionsGranted}) : super(key: key);

  @override
  _PermissionScreenState createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _microphoneGranted = false;
  bool _locationGranted = false;
  bool _storageGranted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentPermissions();
  }

  Future<void> _checkCurrentPermissions() async {
    _microphoneGranted = await AppPermissionHandler.isPermissionGranted(Permission.microphone);
    _locationGranted = await AppPermissionHandler.isPermissionGranted(Permission.location);
    _storageGranted = await AppPermissionHandler.isPermissionGranted(Permission.storage) ||
        await AppPermissionHandler.isPermissionGranted(Permission.manageExternalStorage);
    setState(() {});
  }

  Future<void> _requestPermission(Permission permission) async {
    setState(() {
      _isLoading = true;
    });

    bool granted = await AppPermissionHandler.requestPermission(permission);

    if (!granted) {
      PermissionStatus status = await permission.status;
      if (status == PermissionStatus.permanentlyDenied) {
        _showPermissionDeniedDialog(permission);
      }
    }

    await _checkCurrentPermissions();
    setState(() {
      _isLoading = false;
    });

    // Check if essential permissions are granted (microphone + storage)
    if (_microphoneGranted && _storageGranted) {
      widget.onPermissionsGranted();
    }
  }

  void _showPermissionDeniedDialog(Permission permission) {
    String permissionName = _getPermissionName(permission);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2D1B69),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Permission Required',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '$permissionName permission is required for the app to function properly. Please enable it in the app settings.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.yellowAccent.withValues( alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Open Settings',
                style: TextStyle(color: Colors.yellowAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return 'Microphone';
      case Permission.location:
        return 'Location';
      case Permission.storage:
      case Permission.manageExternalStorage:
        return 'Storage';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8E2DE2),
              Color(0xFFDA22FF),
              Color(0xFFFF4E50),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40),
                Text(
                  'Permissions Required',
                  style: TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'To provide the best voice memo experience, we need access to the following permissions:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 40),

                // Microphone Permission
                PermissionCard(
                  icon: Icons.mic,
                  title: 'Microphone Access',
                  description: 'Required to record voice memos',
                  isGranted: _microphoneGranted,
                  onTap: () => _requestPermission(Permission.microphone),
                  isLoading: _isLoading,
                  isRequired: true,
                ),
                SizedBox(height: 16),

                // Storage Permission
                PermissionCard(
                  icon: Icons.storage,
                  title: 'Storage Access',
                  description: 'Required to save and manage your voice memos',
                  isGranted: _storageGranted,
                  onTap: () => _requestPermission(Permission.storage),
                  isLoading: _isLoading,
                  isRequired: true,
                ),
                SizedBox(height: 16),

                // Location Permission
                PermissionCard(
                  icon: Icons.location_on,
                  title: 'Location Access',
                  description: 'Optional: Add location data to your recordings',
                  isGranted: _locationGranted,
                  onTap: () => _requestPermission(Permission.location),
                  isLoading: _isLoading,
                  isRequired: false,
                ),

                Spacer(),

                // Continue Button
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_microphoneGranted && _storageGranted)
                        ? widget.onPermissionsGranted
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_microphoneGranted && _storageGranted)
                          ? Colors.yellowAccent
                          : Colors.grey.withValues(alpha:0.3),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue to Voice Memos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Progress indicator
                Center(
                  child: Text(
                    '${(_microphoneGranted ? 1 : 0) + (_storageGranted ? 1 : 0) + (_locationGranted ? 1 : 0)}/3 permissions granted',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isRequired;

  const PermissionCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
    required this.isLoading,
    this.isRequired = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGranted ? null : onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGranted
                ? Colors.green
                : isRequired
                ? Colors.yellowAccent.withValues(alpha:0.5)
                : Colors.white.withValues(alpha:0.3),
            width: 2,
          ),
          boxShadow: isGranted
              ? [BoxShadow(
            color: Colors.green.withValues(alpha:0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          )]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isGranted
                    ? Colors.green
                    : isRequired
                    ? Colors.yellowAccent.withValues(alpha:0.2)
                    : Colors.white.withValues(alpha:0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isGranted ? Icons.check : icon,
                color: isGranted
                    ? Colors.white
                    : isRequired
                    ? Colors.yellowAccent
                    : Colors.white70,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isRequired) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha:0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'REQUIRED',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha:0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'OPTIONAL',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                ),
              )
            else if (!isGranted)
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha:0.5),
                size: 20,
              )
            else
              Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}