import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happ/core/models/appointment.dart';

class AppointmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Appointment> _appointments = [];
  bool _isLoading = false;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;

  Future<void> fetchDoctorAppointments(String doctorId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('appointmentDate', descending: false)
          .get();

      _appointments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Appointment.fromJson({...data, 'id': doc.id});
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching doctor appointments: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPatientAppointments(String patientId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('appointmentDate', descending: false)
          .get();

      _appointments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Appointment.fromJson({...data, 'id': doc.id});
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching patient appointments: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Appointment?> requestAppointment(Appointment appointment) async {
    try {
      final docRef = await _firestore.collection('appointments').add(appointment.toJson());
      
      final newAppointment = Appointment(
        id: docRef.id,
        doctorId: appointment.doctorId,
        patientId: appointment.patientId,
        appointmentDate: appointment.appointmentDate,
        status: appointment.status,
        notes: appointment.notes,
        createdAt: appointment.createdAt,
        updatedAt: appointment.updatedAt,
      );
      
      _appointments.add(newAppointment);
      notifyListeners();
      return newAppointment;
    } catch (e) {
      print('Error requesting appointment: $e');
      return null;
    }
  }

  Future<bool> updateAppointmentStatus(String appointmentId, String status) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': DateTime.now(),
      });
      
      // Update local list
      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index != -1) {
        final updatedAppointment = Appointment(
          id: _appointments[index].id,
          doctorId: _appointments[index].doctorId,
          patientId: _appointments[index].patientId,
          appointmentDate: _appointments[index].appointmentDate,
          status: status,
          notes: _appointments[index].notes,
          createdAt: _appointments[index].createdAt,
          updatedAt: DateTime.now(),
        );
        
        _appointments[index] = updatedAppointment;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      print('Error updating appointment status: $e');
      return false;
    }
  }
}