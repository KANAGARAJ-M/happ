import 'package:flutter/material.dart';
import 'package:happ/core/models/emergency_alert.dart';
import 'package:happ/core/providers/emergency_provider.dart';
import 'package:happ/ui/screens/emergency/emergency_contacts_screen.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/ui/screens/emergency/emergency_alert_screen.dart';

class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FloatingActionButton(
            heroTag: 'sos_button',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 8,
            onPressed: () => _showEmergencyOptions(context),
            child: const Icon(
              Icons.emergency,
              size: 30,
            ),
          ),
        );
      },
    );
  }

  void _showEmergencyOptions(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        width: size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Emergency Options',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildEmergencyButton(
              context,
              icon: Icons.medical_services,
              label: 'Medical Emergency',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyAlertScreen(
                      initialType: EmergencyType.medical,
                      userId: user.id,
                      userName: user.name,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildEmergencyButton(
              context,
              icon: Icons.car_crash,
              label: 'Report Accident',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyAlertScreen(
                      initialType: EmergencyType.accident,
                      userId: user.id,
                      userName: user.name,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildEmergencyButton(
              context,
              icon: Icons.phone_in_talk,
              label: 'Call Emergency Services',
              color: Colors.blue,
              onTap: () async {
                Navigator.pop(context);
                final emergencyProvider = Provider.of<EmergencyProvider>(
                  context,
                  listen: false,
                );
                await emergencyProvider.callEmergencyServices();
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmergencyContactsScreen(),
                  ),
                );
              },
              child: const Text('Manage Emergency Contacts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}