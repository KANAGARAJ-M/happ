import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final Color badgeColor;
  final Color textColor;
  final double position;
  
  const NotificationBadge({
    super.key,
    required this.child,
    this.badgeColor = Colors.red,
    this.textColor = Colors.white,
    this.position = 12.0,
  });
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseAuth.instance.currentUser != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (count > 0)
              Positioned(
                right: -position / 2,
                top: -position / 2,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: count > 9 ? BorderRadius.circular(8.0) : null,
                    color: badgeColor,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}