import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/ui/screens/doctor/patient_records_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null || currentUser.role != 'doctor') {
      return const Center(child: Text('Only doctors can view patients'));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Patients'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              // Add style for text color
              style: const TextStyle(color: Colors.black), 
              decoration: InputDecoration(
                hintText: 'Search patients...',
                // Set icon color
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]), 
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      // Set icon color
                      icon: Icon(Icons.clear, color: Colors.grey[600]), 
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No patients found'));
          }
          
          // Filter patients based on search query
          final allPatients = snapshot.data!.docs.map((doc) {
            final patientData = doc.data() as Map<String, dynamic>;
            return User.fromJson({'id': doc.id, ...patientData});
          }).toList();
          
          final filteredPatients = _searchQuery.isEmpty 
              ? allPatients 
              : allPatients.where((patient) => 
                  patient.name.toLowerCase().contains(_searchQuery) ||
                  patient.email.toLowerCase().contains(_searchQuery)).toList();
          
          if (filteredPatients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No patients match "$_searchQuery"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPatients.length,
            itemBuilder: (context, index) {
              final patient = filteredPatients[index];
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(patient.name.substring(0, 1)),
                  ),
                  title: Text(patient.name),
                  subtitle: Text(patient.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientRecordsScreen(patient: patient),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}