import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:happ/core/models/appointment.dart';
import 'package:happ/core/services/notification_service.dart';
import 'package:intl/intl.dart';
class AppointmentProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
          .orderBy('date', descending: false)
          .get();

      _appointments = querySnapshot.docs.map((doc) {
        final data = doc.data();
        print('Raw appointment data: $data'); // Debug print
        final appointment = Appointment.fromJson({...data, 'id': doc.id});
        print('Parsed appointment date: ${appointment.date}'); // Debug date
        print('Parsed appointment reason: "${appointment.reason}"'); // Debug reason
        return appointment;
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
          .orderBy('date', descending: false)  // Changed from appointmentDate to date
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
        patientName: appointment.patientName,
        doctorName: appointment.doctorName,
        date: appointment.date,          // Changed from appointmentDate to date
        timeSlot: appointment.timeSlot,
        reason: appointment.reason,      // Changed from notes to reason
        status: appointment.status,
        createdAt: appointment.createdAt,
        updatedAt: appointment.updatedAt,
      );
      
      // Send notification to the doctor
      final notificationService = NotificationService();
      await notificationService.sendAppointmentNotification(
        userId: appointment.doctorId,
        title: 'New Appointment Request',
        body: '${appointment.patientName} has requested an appointment on ${DateFormat('MMM d, yyyy').format(appointment.date)} at ${appointment.timeSlot}',
        additionalData: {
          'type': 'appointment_request',
          'appointmentId': docRef.id,
        },
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
      // First update the database with server timestamp
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Get the updated document to ensure we have the latest data
      final docSnapshot = await _firestore.collection('appointments').doc(appointmentId).get();
      if (!docSnapshot.exists) {
        return false;
      }
      
      // Create updated appointment with fresh data
      final data = docSnapshot.data()!;
      final updatedAppointment = Appointment.fromJson({...data, 'id': appointmentId});
      
      // Update the local appointment list
      final index = _appointments.indexWhere((a) => a.id == appointmentId);
      if (index != -1) {
        _appointments[index] = updatedAppointment;
      } else {
        _appointments.add(updatedAppointment);
      }
      
      // Send notifications
      final notificationService = NotificationService();
      
      // For confirmed appointments, notify the patient
      if (status == 'confirmed') {
        await notificationService.sendAppointmentNotification(
          userId: updatedAppointment.patientId,
          title: 'Appointment Confirmed',
          body: 'Your appointment with Dr. ${updatedAppointment.doctorName} on ${DateFormat('MMM d, yyyy').format(updatedAppointment.date)} at ${updatedAppointment.timeSlot} has been confirmed.',
          additionalData: {
            'type': 'appointment_confirmed',
            'appointmentId': appointmentId,
          },
        );
      }
      // For cancelled or rejected appointments, notify the affected party
      else if (status == 'cancelled' || status == 'rejected') {
        final title = status == 'cancelled' ? 'Appointment Cancelled' : 'Appointment Rejected';
        
        // If cancelled by doctor, notify patient
        if (updatedAppointment.doctorId == _auth.currentUser?.uid) {
          await notificationService.sendAppointmentNotification(
            userId: updatedAppointment.patientId,
            title: title,
            body: 'Your appointment with Dr. ${updatedAppointment.doctorName} on ${DateFormat('MMM d, yyyy').format(updatedAppointment.date)} has been $status.',
            additionalData: {
              'type': 'appointment_$status',
              'appointmentId': appointmentId,
            },
          );
        }
        // If cancelled by patient, notify doctor
        else {
          await notificationService.sendAppointmentNotification(
            userId: updatedAppointment.doctorId,
            title: title,
            body: 'Appointment with ${updatedAppointment.patientName} on ${DateFormat('MMM d, yyyy').format(updatedAppointment.date)} has been $status.',
            additionalData: {
              'type': 'appointment_$status',
              'appointmentId': appointmentId,
            },
          );
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating appointment status: $e');
      return false;
    }
  }
}