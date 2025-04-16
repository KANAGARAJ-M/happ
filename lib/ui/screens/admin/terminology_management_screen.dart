import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/auth_provider.dart';

class TerminologyManagementScreen extends StatefulWidget {
  const TerminologyManagementScreen({super.key});

  @override
  State<TerminologyManagementScreen> createState() =>
      _TerminologyManagementScreenState();
}

class _TerminologyManagementScreenState
    extends State<TerminologyManagementScreen> {
  final _termController = TextEditingController();
  final _simplifiedController = TextEditingController();
  final _definitionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _selectedCategory = 'general';

  final List<String> _categories = [
    'general',
    'cardiovascular',
    'respiratory',
    'gastrointestinal',
    'neurological',
    'musculoskeletal',
    'dermatological',
    'psychiatric',
    'endocrine',
    'ophthalmology', // Eye related terms
    'otolaryngology', // Ear, nose, and throat
    'hematology', // Blood related terms
    'nephrology', // Kidney related terms
    'urology', // Urinary tract
    'rheumatology', // Autoimmune and inflammatory conditions
    'obstetrics', // Pregnancy and childbirth
    'gynecology', // Female reproductive system
    'pediatrics', // Child healthcare
    'immunology', // Immune system
    'oncology', // Cancer related terms
    'infectious_disease', // Infection related terms
    'pharmacology', // Medication related terms
    'radiology', // Imaging and diagnostic radiology
    'surgery', // Surgical terms
    'dental', // Dental/oral health
    'genetic', // Genetic conditions
    'geriatric', // Elderly care
    'nutritional', // Nutrition related
    'emergency_medicine', // Emergency and trauma
    'pathology', // Disease processes
    'preventive', // Preventive medicine
  ];

  @override
  void dispose() {
    _termController.dispose();
    _simplifiedController.dispose();
    _definitionController.dispose();
    super.dispose();
  }

  Future<void> _addTerm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('medical_terminology').add({
        'term': _termController.text.trim(),
        'simplified': _simplifiedController.text.trim(),
        'definition': _definitionController.text.trim(),
        'category': _selectedCategory,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term added successfully')),
        );

        // Clear the form
        _termController.clear();
        _simplifiedController.clear();
        _definitionController.clear();
        setState(() => _selectedCategory = 'general');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding term: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTerm(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('medical_terminology')
          .doc(id)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Term deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting term: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;

    // Check if user has admin rights
    if (currentUser == null || currentUser.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('Access denied. Admin rights required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Medical Terminology Management')),
      body: Column(
        children: [
          // Form to add new terms
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _termController,
                    decoration: const InputDecoration(
                      labelText: 'Medical Term',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a medical term';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _simplifiedController,
                    decoration: const InputDecoration(
                      labelText: 'Simplified Term',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a simplified term';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _definitionController,
                    decoration: const InputDecoration(
                      labelText: 'Definition',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a definition';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _addTerm,
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Add Term'),
                  ),
                ],
              ),
            ),
          ),

          // List of existing terms
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('medical_terminology')
                      .orderBy('term')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No medical terms found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(data['term'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Simplified: ${data['simplified'] ?? ''}'),
                          Text('Category: ${data['category'] ?? 'general'}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTerm(doc.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
