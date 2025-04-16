import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/models/record.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/screens/doctor/add_patient_record_screen.dart';
import 'package:intl/intl.dart';
import 'package:happ/ui/screens/doctor/scan_document_screen.dart';
import 'package:happ/ui/screens/patient/patient_profile_screen.dart'; // Add this import

class PatientRecordsScreen extends StatefulWidget {
  final User patient;
  
  const PatientRecordsScreen({super.key, required this.patient});

  @override
  State<PatientRecordsScreen> createState() => _PatientRecordsScreenState();
}

class _PatientRecordsScreenState extends State<PatientRecordsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.patient.name),
            if (widget.patient.patientId != null)
              Text(
                'ID: ${widget.patient.patientId}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPatientRecordScreen(patient: widget.patient),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Records', icon: Icon(Icons.folder)),
            Tab(text: 'Profile', icon: Icon(Icons.person)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Records Tab
          _buildRecordsTab(),
          
          // Profile Tab
          PatientProfileScreen(patient: widget.patient, viewOnly: true),
        ],
      ),
      floatingActionButton: _tabController.index == 0 
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScanDocumentScreen(patient: widget.patient),
                  ),
                );
              },
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan Document'),
            )
          : null,
    );
  }
  
  Widget _buildRecordsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patient.id)
          .collection('records')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No records available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final record = Record.fromJson({...data, 'id': doc.id});

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(record.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date: ${DateFormat('MMM d, yyyy').format(record.date)}'),
                    if (record.createdBy != null && record.createdBy != widget.patient.id)
                      Text(
                        'Added by healthcare provider',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                  ],
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
    );
  }
}