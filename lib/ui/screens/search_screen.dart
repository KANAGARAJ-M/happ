import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/providers/records_provider.dart';
import 'package:happ/core/services/navigation_service.dart';
import 'package:happ/ui/screens/records/record_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordsProvider = Provider.of<RecordsProvider>(context);
    final searchResults =
        _query.isEmpty ? [] : recordsProvider.search(_query);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Records',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title, description, or tags',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon:
                  _query.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _query = '';
                          });
                        },
                      )
                      : null,
            ),
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
          ),

          const SizedBox(height: 16),

          Expanded(
            child:
                _query.isEmpty
                    ? const Center(
                      child: Text('Enter a search term to find records'),
                    )
                    : searchResults.isEmpty
                    ? const Center(
                      child: Text('No records found matching your search'),
                    )
                    : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final record = searchResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  record.category == 'medical'
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.amber.withOpacity(0.2),
                              child: Icon(
                                record.category == 'medical'
                                    ? Icons.medical_services
                                    : Icons.gavel,
                                color:
                                    record.category == 'medical'
                                        ? Colors.blue
                                        : Colors.amber,
                              ),
                            ),
                            title: Text(record.title),
                            subtitle: Text(
                              'Category: ${record.categoryName} • Date: ${record.formattedDate}',
                            ),
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
