import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/screens/doctor/add_patient_record_screen.dart';
import 'package:intl/intl.dart';

class PatientRecordsScreen extends StatelessWidget {
  final User patient;
  
  const PatientRecordsScreen({Key? key, required this.patient}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${patient.name}\'s Records')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(patient.id)
            .collection('records')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No records found for this patient'));
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              // Convert Firestore timestamp to ISO string
              if (data['createdAt'] is Timestamp) {
                data['createdAt'] = data['createdAt'].toDate().toIso8601String();
              }
              if (data['updatedAt'] is Timestamp) {
                data['updatedAt'] = data['updatedAt'].toDate().toIso8601String();
              }
              if (data['date'] is Timestamp) {
                data['date'] = data['date'].toDate().toIso8601String();
              }
              
              final record = Record.fromJson({...data, 'id': doc.id});
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    record.category == 'doctor' ? Icons.medical_services : Icons.person,
                    color: record.category == 'doctor' ? Colors.blue : Colors.amber,
                  ),
                  title: Text(record.title),
                  subtitle: Text(
                    'Date: ${DateFormat('MMM d, yyyy').format(record.date)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecordDetailScreen(record: record),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPatientRecordScreen(patient: patient),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      ),
    );
  }
}