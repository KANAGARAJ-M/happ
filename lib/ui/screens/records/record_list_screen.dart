import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';
import 'package:happ/ui/widgets/filter_chip_list.dart';

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
    final records = recordsProvider.records;

    final filteredRecords =
        _selectedCategory == 'all'
            ? records
            : records.where((r) => r.category == _selectedCategory).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Records', style: Theme.of(context).textTheme.headlineMedium),
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

          const SizedBox(height: 16),

          // Records list
          Expanded(
            child:
                filteredRecords.isEmpty
                    ? const Center(child: Text('No records found'))
                    : ListView.builder(
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  record.category == 'doctor'
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.amber.withOpacity(0.2),
                              child: Icon(
                                record.category == 'doctor'
                                    ? Icons.medical_services
                                    : Icons.gavel,
                                color:
                                    record.category == 'doctor'
                                        ? Colors.blue
                                        : Colors.amber,
                              ),
                            ),
                            title: Text(record.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: ${record.formattedDate}'),
                                if (record.tags.isNotEmpty)
                                  Text(
                                    'Tags: ${record.tags.take(3).join(", ")}${record.tags.length > 3 ? "..." : ""}',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: record.tags.isNotEmpty,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              NavigationService.navigateTo(
                                RecordDetailScreen(record: record),
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
