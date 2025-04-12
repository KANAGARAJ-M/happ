import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/core/services/permission_service.dart';
import 'package:happ/ui/screens/splash_screen.dart';

class PermissionsScreen extends StatefulWidget {
  final bool isOnboarding;

  const PermissionsScreen({super.key, this.isOnboarding = true});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final List<Permission> _permissions = [
    Permission.camera,
    Permission.storage,
    // Permission.biometrics,
  ];

  final Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};

    for (var permission in _permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      _permissionStatuses.addAll(statuses);
      _isLoading = false;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    setState(() => _isLoading = true);

    final status = await PermissionService.requestPermission(permission);

    setState(() {
      _permissionStatuses[permission] = status;
      _isLoading = false;
    });
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);

    final statuses = await PermissionService.requestRequiredPermissions();

    setState(() {
      _permissionStatuses.addAll(statuses);
      _isLoading = false;
    });
  }

  void _continueToApp() {
    if (widget.isOnboarding) {
      NavigationService.navigateToReplacement(const SplashScreen());
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Permissions'),
        backgroundColor: Theme.of(context).primaryColor,
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isOnboarding
                          ? 'Welcome to MedicoLegal Records!'
                          : 'Manage Permissions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The app needs the following permissions to function properly:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // List all permissions
                    ..._permissions.map(
                      (permission) => _buildPermissionCard(permission),
                    ),

                    const SizedBox(height: 24),
                    if (widget.isOnboarding) ...[
                      ElevatedButton(
                        onPressed: _requestAllPermissions,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Allow All Permissions'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _continueToApp,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Continue to App'),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildPermissionCard(Permission permission) {
    final status = _permissionStatuses[permission] ?? PermissionStatus.denied;
    final isGranted = status.isGranted;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPermissionIcon(permission),
                  color: isGranted ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    PermissionService.getPermissionFriendlyName(permission),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isGranted ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isGranted ? 'Granted' : 'Required',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(PermissionService.getPermissionDescription(permission)),
            const SizedBox(height: 12),
            if (!isGranted)
              OutlinedButton(
                onPressed: () => _requestPermission(permission),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
                child: Text(
                  status.isPermanentlyDenied
                      ? 'Open Settings'
                      : 'Grant Permission',
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return Icons.camera_alt;
      case Permission.storage:
        return Icons.folder;
      // case Permission.biometrics:
        // return Icons.fingerprint;
      case Permission.location:
        return Icons.location_on;
      default:
        return Icons.security;
    }
  }
}
