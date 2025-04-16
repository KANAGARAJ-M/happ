import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/models/user.dart';
import 'package:happ/core/providers/auth_provider.dart';
import 'package:happ/core/providers/appointment_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';

class BookAppointmentScreen extends StatefulWidget {
  final User? selectedDoctor; // Make selectedDoctor optional

  const BookAppointmentScreen({super.key, this.selectedDoctor});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  User? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableTimeSlots = [];
  bool _isLoading = false;
  bool _isLoadingDoctors = false;
  bool _isLoadingTimeSlots = false;
  String? _errorMessage;
  List<User> _availableDoctors = [];
  
  // Calendar format
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _selectedDoctor = widget.selectedDoctor;
    
    // If no doctor was pre-selected, load the list of doctors
    if (_selectedDoctor == null) {
      _loadDoctors();
    } else {
      _loadAvailableTimeSlots();
    }
  }
  
  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _isLoadingDoctors = true;
    });
    
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();
          
      final doctors = querySnapshot.docs.map((doc) {
        return User.fromJson({'id': doc.id, ...doc.data()});
      }).toList();
      
      setState(() {
        _availableDoctors = doctors;
        _isLoadingDoctors = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load doctors: $e';
        _isLoadingDoctors = false;
      });
    }
  }
  
  Future<void> _loadAvailableTimeSlots() async {
    setState(() {
      _isLoadingTimeSlots = true;
      _selectedTimeSlot = null;
    });
    
    try {
      // This could fetch actual time slots from Firestore,
      // checking which slots are already booked
      await Future.delayed(const Duration(milliseconds: 300)); // Simulate network delay
      
      final now = DateTime.now();
      final isToday = _selectedDate.year == now.year && 
                     _selectedDate.month == now.month && 
                     _selectedDate.day == now.day;
      
      // Example time slots
      List<String> allTimeSlots = [
        '9:00 AM - 9:30 AM',
        '9:30 AM - 10:00 AM',
        '10:00 AM - 10:30 AM',
        '10:30 AM - 11:00 AM',
        '11:00 AM - 11:30 AM',
        '11:30 AM - 12:00 PM',
        '1:00 PM - 1:30 PM',
        '1:30 PM - 2:00 PM',
        '2:00 PM - 2:30 PM',
        '2:30 PM - 3:00 PM',
        '3:00 PM - 3:30 PM',
        '3:30 PM - 4:00 PM',
        '4:00 PM - 4:30 PM',
        '4:30 PM - 5:00 PM',
      ];
      
      // Filter out past time slots if the selected date is today
      if (isToday) {
        final currentHour = now.hour;
        final currentMinute = now.minute;
        
        allTimeSlots = allTimeSlots.where((slot) {
          final startHour = int.parse(slot.split(':')[0]);
          final isPm = slot.contains('PM') && startHour != 12;
          final hour24 = isPm ? startHour + 12 : startHour;
          
          // For simplicity, we'll just compare hours
          return hour24 > currentHour || (hour24 == currentHour && currentMinute < 30);
        }).toList();
      }
      
      if (mounted) {
        setState(() {
          _availableTimeSlots = allTimeSlots;
          _isLoadingTimeSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading time slots: $e';
          _isLoadingTimeSlots = false;
        });
      }
    }
  }
  
  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTimeSlot == null) {
      setState(() {
        _errorMessage = 'Please select a time slot';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
      
      final currentUser = authProvider.currentUser!;
      
      final appointment = Appointment(
        id: '',
        patientId: currentUser.id,
        doctorId: _selectedDoctor!.id,
        patientName: currentUser.name,
        doctorName: _selectedDoctor!.name,
        date: _selectedDate,
        timeSlot: _selectedTimeSlot!,
        reason: _reasonController.text.trim(),
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final result = await appointmentProvider.requestAppointment(appointment);
      
      if (result != null) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment request sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to book appointment';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }
  
  bool _isDateSelectable(DateTime day) {
    // Allow only future dates (including today)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Only allow bookings for the next 30 days
    final maxDate = today.add(const Duration(days: 30));
    
    // Don't allow weekends (Sat = 6, Sun = 7)
    final bool isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    
    return !day.isBefore(today) && !day.isAfter(maxDate) && !isWeekend;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedDoctor != null 
            ? 'Book with Dr. ${_selectedDoctor!.name.split(' ')[0]}'
            : 'Book Appointment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // If no doctor is selected, show doctor selection
                    if (_selectedDoctor == null) ...[
                      Text('Select Doctor', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _isLoadingDoctors
                          ? const Center(child: CircularProgressIndicator())
                          : _availableDoctors.isEmpty
                              ? const Center(child: Text('No doctors available'))
                              : DropdownButtonFormField<User>(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  value: _selectedDoctor,
                                  hint: const Text('Select a doctor'),
                                  isExpanded: true,
                                  onChanged: (User? newValue) {
                                    setState(() {
                                      _selectedDoctor = newValue;
                                    });
                                    if (newValue != null) {
                                      _loadAvailableTimeSlots();
                                    }
                                  },
                                  items: _availableDoctors.map<DropdownMenuItem<User>>((User doctor) {
                                    return DropdownMenuItem<User>(
                                      value: doctor,
                                      child: Text(doctor.name + (doctor.specialization != null 
                                          ? ' (${doctor.specialization})' 
                                          : '')),
                                    );
                                  }).toList(),
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select a doctor';
                                    }
                                    return null;
                                  },
                                ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Doctor info card
                    if (_selectedDoctor != null) ...[
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                radius: 24,
                                child: Text(
                                  _selectedDoctor!.name.substring(0, 1),
                                  style: const TextStyle(color: Colors.white, fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedDoctor!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _selectedDoctor!.specialization ?? 'General Practitioner',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Step 1: Select date
                    const Text(
                      'Step 1: Select Date',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: TableCalendar(
                        firstDay: DateTime.now(),
                        lastDay: DateTime.now().add(const Duration(days: 30)),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        enabledDayPredicate: _isDateSelectable,
                        selectedDayPredicate: (day) {
                          return isSameDay(_selectedDate, day);
                        },
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDate = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          _loadAvailableTimeSlots();
                        },
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        calendarStyle: const CalendarStyle(
                          outsideDaysVisible: false,
                        ),
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonDecoration: BoxDecoration(
                            color: Colors.blue.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Step 2: Select time slot
                    const Text(
                      'Step 2: Select Time Slot',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingTimeSlots
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _availableTimeSlots.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No available time slots for the selected date.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableTimeSlots.map((slot) {
                                  final isSelected = _selectedTimeSlot == slot;
                                  return ChoiceChip(
                                    label: Text(slot),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedTimeSlot = selected ? slot : null;
                                      });
                                    },
                                    backgroundColor: Colors.grey[200],
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.black,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  );
                                }).toList(),
                              ),
                    const SizedBox(height: 24),
                    
                    // Step 3: Reason for appointment
                    const Text(
                      'Step 3: Reason for Appointment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        hintText: 'Briefly describe your symptoms or reason for visit',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a reason';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Book button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _bookAppointment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: const Text('Book Appointment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}