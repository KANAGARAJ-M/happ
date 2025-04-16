import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/models/user.dart';

class AppointmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Book a new appointment
  Future<Appointment?> bookAppointment(Appointment appointment) async {
    try {
      final docRef = await _firestore.collection('appointments').add(appointment.toJson());
      return appointment.copyWith(id: docRef.id);
    } catch (e) {
      print('Error booking appointment: $e');
      return null;
    }
  }

  // Get patient's appointments
  Stream<List<Appointment>> getPatientAppointments(String patientId) {
    return _firestore
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Get doctor's appointments
  Stream<List<Appointment>> getDoctorAppointments(String doctorId) {
    return _firestore
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Update appointment status
  Future<bool> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      print('Error updating appointment status: $e');
      return false;
    }
  }

  // Cancel appointment
  Future<bool> cancelAppointment(String appointmentId) async {
    return updateAppointmentStatus(appointmentId, 'cancelled');
  }

  // Get available doctors
  Future<List<User>> getAvailableDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();
      
      return querySnapshot.docs
          .map((doc) => User.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting available doctors: $e');
      return [];
    }
  }

  // Get doctor's availability (time slots)
  Future<List<String>> getDoctorAvailability(String doctorId, DateTime date) async {
    try {
      // You would typically get this from doctor's settings
      // For simplicity, we'll return standard slots
      final allTimeSlots = [
        '09:00 AM - 09:30 AM',
        '09:30 AM - 10:00 AM',
        '10:00 AM - 10:30 AM',
        '10:30 AM - 11:00 AM',
        '11:00 AM - 11:30 AM',
        '11:30 AM - 12:00 PM',
        '02:00 PM - 02:30 PM',
        '02:30 PM - 03:00 PM',
        '03:00 PM - 03:30 PM',
        '03:30 PM - 04:00 PM',
        '04:00 PM - 04:30 PM',
        '04:30 PM - 05:00 PM',
      ];
      
      // Convert date to string format (YYYY-MM-DD)
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Get booked appointments for this doctor on this date
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .where('date', isGreaterThanOrEqualTo: DateTime(date.year, date.month, date.day))
          .where('date', isLessThan: DateTime(date.year, date.month, date.day + 1))
          .where('status', whereIn: ['pending', 'approved'])
          .get();
      
      // Get booked time slots
      final bookedTimeSlots = querySnapshot.docs
          .map((doc) => doc.data()['timeSlot'] as String)
          .toList();
      
      // Return available time slots (all slots minus booked slots)
      return allTimeSlots.where((slot) => !bookedTimeSlots.contains(slot)).toList();
    } catch (e) {
      print('Error getting doctor availability: $e');
      return [];
    }
  }
}