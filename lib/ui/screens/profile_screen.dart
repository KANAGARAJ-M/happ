import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/ui/screens/auth/login_screen.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/core/services/biometric_auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isBiometricsEnabled = false;
  bool _isBiometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(
      text: authProvider.currentUser?.name ?? '',
    );
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await BiometricAuthService.isBiometricsAvailable();
    final isEnabled = await BiometricAuthService.isBiometricsEnabled();

    if (mounted) {
      setState(() {
        _isBiometricsAvailable = isAvailable;
        _isBiometricsEnabled = isEnabled;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.updateProfile(
          name: _nameController.text.trim(),
        );

        if (success && mounted) {
          setState(() {
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      NavigationService.navigateToAndClearStack(const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final recordsProvider = Provider.of<RecordsProvider>(context);
    final user = authProvider.currentUser;

    if (user == null) {
      return const Center(child: Text('Please sign in'));
    }

    final totalRecords = recordsProvider.records.length;
    final doctorRecords =
        recordsProvider.records.where((r) => r.category == 'doctor').length;
    final patientRecords =
        recordsProvider.records.where((r) => r.category == 'patient').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text('My Profile', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 24),

          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isEditing)
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    _nameController.text = user.name;
                                  });
                                },
                                child: const Text('CANCEL'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _updateProfile,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('SAVE'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('EDIT PROFILE'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text('Account Stats', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildStatRow('Total Records', totalRecords.toString()),
                  const Divider(),
                  _buildStatRow('Medical Records', doctorRecords.toString()),
                  const Divider(),
                  _buildStatRow('Legal Records', patientRecords.toString()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          if (_isBiometricsAvailable)
            SwitchListTile(
              title: const Text('Use Biometric Authentication'),
              subtitle: const Text(
                'Sign in with fingerprint or face recognition',
              ),
              value: _isBiometricsEnabled,
              onChanged: (value) async {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                if (value) {
                  // Enable biometrics
                  if (authProvider.currentUser != null) {
                    final success = await BiometricAuthService.enableBiometrics(
                      authProvider.currentUser!.id,
                    );
                    if (mounted) {
                      setState(() {
                        _isBiometricsEnabled = success;
                      });
                    }
                  }
                } else {
                  // Disable biometrics
                  final success =
                      await BiometricAuthService.disableBiometrics();
                  if (mounted) {
                    setState(() {
                      _isBiometricsEnabled = !success;
                    });
                  }
                }
              },
            ),

          // const SizedBox(height: 24),
          // ElevatedButton.icon(
          //   onPressed: _signOut,
          //   icon: const Icon(Icons.logout),
          //   label: const Text('SIGN OUT'),
          //   style: ElevatedButton.styleFrom(
          //     minimumSize: const Size.fromHeight(50),
          //     backgroundColor: Colors.redAccent,
          //   ),
          // ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await authProvider.signOut();

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
