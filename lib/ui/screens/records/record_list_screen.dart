import 'package:flutter/material.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/ui/screens/records/add_record_screen.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/widgets/filter_chip_list.dart';
import 'package:intl/intl.dart';

class RecordListScreen extends StatefulWidget {
  const RecordListScreen({super.key});

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen> {
  String _selectedCategory = 'all';
  final List<String> _categories = ['all', 'doctor', 'patient'];

  @override
  Widget build(BuildContext context) {
    final recordsProvider = Provider.of<RecordsProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final records = recordsProvider.records;

    // Debug print to check if records are being loaded
    print('Records count: ${records.length}');

    final filteredRecords =
        _selectedCategory == 'all'
            ? records
            : records.where((r) => r.category == _selectedCategory).toList();

    // Debug print to check filtered records
    print('Filtered records count: ${filteredRecords.length}');

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Records',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // Filter chips
            FilterChipList(
              selected: _selectedCategory,
              options: {
                'all': 'All Records',
                'doctor': 'Doctor',
                'patient': 'Patient',
              },
              onSelected: (value) {
                setState(() => _selectedCategory = value);
              },
            ),

            const SizedBox(height: 8),

            // Combined privacy message
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                authProvider.currentUser?.role == 'doctor'
                    ? 'All patient records are private and only visible to you and the respective patients under your care.'
                    : 'Your medical records are private and only visible to you and your healthcare providers.',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Records list - make sure this is properly expanded
            Expanded(
              child:
                  filteredRecords.isEmpty
                      ? const Center(child: Text('No records found'))
                      : ListView.builder(
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              title: Text(record.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.description.length > 60
                                        ? '${record.description.substring(0, 60)}...'
                                        : record.description,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: ${DateFormat('MMM d, yyyy').format(record.date)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (record.createdBy != null &&
                                      record.createdBy !=
                                          authProvider.currentUser?.id)
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
                                    builder:
                                        (context) =>
                                            RecordDetailScreen(record: record),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          NavigationService.navigateTo(const AddRecordScreen());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
