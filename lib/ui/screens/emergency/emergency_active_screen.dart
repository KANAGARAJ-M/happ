import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/providers/emergency_provider.dart';
import 'package:happ/ui/screens/home_screen.dart';

class EmergencyActiveScreen extends StatefulWidget {
  final EmergencyAlert alert;
  
  const EmergencyActiveScreen({
    super.key,
    required this.alert,
  });

  @override
  State<EmergencyActiveScreen> createState() => _EmergencyActiveScreenState();
}

class _EmergencyActiveScreenState extends State<EmergencyActiveScreen> {
  late GoogleMapController _mapController;
  bool _isMapInitialized = false;
  bool _isCancelling = false;
  final Set<Marker> _markers = {};
  
  @override
  Widget build(BuildContext context) {
    final lat = widget.alert.location.latitude;
    final lng = widget.alert.location.longitude;
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Emergency Alert Active'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // Remove back button
        ),
        body: Column(
          children: [
            Container(
              color: Colors.red,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.emergency,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Alert: ${_getEmergencyTypeText(widget.alert.type)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Emergency services and contacts have been notified.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng),
                          zoom: 15,
                        ),
                        markers: _markers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _isMapInitialized = true;
                          
                          // Add marker for emergency location
                          setState(() {
                            _markers.add(
                              Marker(
                                markerId: const MarkerId('emergency_location'),
                                position: LatLng(lat, lng),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
                                infoWindow: const InfoWindow(
                                  title: 'Emergency Location',
                                ),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What to do next:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoItem(
                            Icons.check_circle,
                            'Stay calm and wait for emergency services to arrive.',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            Icons.medical_services,
                            'If possible, prepare your medical information for emergency responders.',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoItem(
                            Icons.phone,
                            'Keep your phone accessible to receive calls from emergency services or contacts.',
                          ),
                          const SizedBox(height: 24),
                          if (widget.alert.additionalInfo != null &&
                              widget.alert.additionalInfo!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Additional Information:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(widget.alert.additionalInfo!),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isCancelling 
                                  ? null 
                                  : _cancelEmergencyAlert,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: _isCancelling 
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.red,
                                      ),
                                    )
                                  : const Icon(Icons.cancel),
                              label: Text(
                                _isCancelling 
                                    ? 'Cancelling...' 
                                    : 'Cancel Emergency Alert',
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getEmergencyTypeText(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return 'Medical';
      case EmergencyType.accident:
        return 'Accident';
      case EmergencyType.other:
        return 'Other';
    }
  }
  
  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
  
  Future<void> _cancelEmergencyAlert() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Emergency Alert?'),
        content: const Text(
          'Are you sure you want to cancel this emergency alert? '
          'This will notify all contacts that the emergency has been resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isCancelling = true;
              });
              
              final emergencyProvider = Provider.of<EmergencyProvider>(
                context, 
                listen: false,
              );
              
              final success = await emergencyProvider.cancelEmergencyAlert(
                widget.alert.id,
              );
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency alert cancelled successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                // Navigate to home screen
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                  (route) => false,
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to cancel emergency alert'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {
                  _isCancelling = false;
                });
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}