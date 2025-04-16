import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/user.dart';
import 'package:intl/intl.dart';

class PatientMedicalProfileScreen extends StatefulWidget {
  final User patient;
  
  const PatientMedicalProfileScreen({super.key, required this.patient});

  @override
  State<PatientMedicalProfileScreen> createState() => _PatientMedicalProfileScreenState();
}

class _PatientMedicalProfileScreenState extends State<PatientMedicalProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patient.name}\'s Medical Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic patient information
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient Information', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    _buildInfoRow('Name', widget.patient.name),
                    if (widget.patient.dob != null)
                      _buildInfoRow('Date of Birth', DateFormat('MMM d, yyyy').format(widget.patient.dob!)),
                    if (widget.patient.age != null)
                      _buildInfoRow('Age', '${widget.patient.age} years'),
                    if (widget.patient.bloodGroup != null && widget.patient.bloodGroup!.isNotEmpty)
                      _buildInfoRow('Blood Group', widget.patient.bloodGroup!),
                    if (widget.patient.height != null)
                      _buildInfoRow('Height', '${widget.patient.height} cm'),
                    if (widget.patient.weight != null)
                      _buildInfoRow('Weight', '${widget.patient.weight} kg'),
                    if (widget.patient.emergencyContact != null && widget.patient.emergencyContact!.isNotEmpty)
                      _buildInfoRow('Emergency Contact', widget.patient.emergencyContact!),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Detected medical conditions
            Card(
              elevation: 2,
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_services, 
                          color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Detected Medical Conditions', 
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary
                          )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Show allergies
                    if (widget.patient.allergies != null && widget.patient.allergies!.isNotEmpty) ...[
                      Text('Allergies:', 
                        style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.patient.allergies!.split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .map((allergy) => Chip(
                            label: Text(allergy),
                            backgroundColor: Colors.red[100],
                            labelStyle: const TextStyle(color: Colors.red),
                          )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Show medical conditions from Firestore
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.patient.id)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const Text('No medical conditions found');
                        }
                        
                        final data = snapshot.data!.data() as Map<String, dynamic>;
                        List<String> conditions = [];
                        
                        if (data.containsKey('medicalConditions') && data['medicalConditions'] is List) {
                          conditions = List<String>.from(data['medicalConditions']);
                        }
                        
                        if (conditions.isEmpty) {
                          return const Text('No known medical conditions');
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Medical Conditions:', 
                              style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: conditions.map((condition) => Chip(
                                label: Text(condition),
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer
                                ),
                              )).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Medical history entries
            Text('Medical History Timeline', 
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.patient.id)
                  .collection('medicalHistory')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No medical history entries found'),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Format timestamp
                    String dateStr = 'Unknown date';
                    if (data['createdAt'] is Timestamp) {
                      final timestamp = data['createdAt'] as Timestamp;
                      dateStr = DateFormat('MMM d, yyyy').format(timestamp.toDate());
                    }
                    
                    // Extract conditions and allergies
                    List<String> conditions = [];
                    List<String> allergies = [];
                    
                    if (data.containsKey('conditions') && data['conditions'] is List) {
                      conditions = List<String>.from(data['conditions']);
                    }
                    
                    if (data.containsKey('allergies') && data['allergies'] is List) {
                      allergies = List<String>.from(data['allergies']);
                    }
                    
                    // Was this automatic or manual?
                    final bool automatic = data['automatic'] ?? false;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: automatic 
                            ? Colors.blue[100] 
                            : Colors.green[100],
                          child: Icon(
                            automatic ? Icons.auto_awesome : Icons.edit_note,
                            color: automatic ? Colors.blue : Colors.green,
                          ),
                        ),
                        title: Text(dateStr),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (automatic)
                              const Text('Automatically detected from records', 
                                style: TextStyle(fontStyle: FontStyle.italic)),
                            if (conditions.isNotEmpty)
                              Text('Conditions: ${conditions.join(", ")}'),
                            if (allergies.isNotEmpty)
                              Text('Allergies: ${allergies.join(", ")}'),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}