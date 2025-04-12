import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:happ/core/services/permission_service.dart';

class PermissionRequest extends StatelessWidget {
  final Permission permission;
  final String title;
  final String message;
  final Widget child;
  final Function() onGranted;
  final Function()? onDenied;

  const PermissionRequest({
    super.key,
    required this.permission,
    required this.title,
    required this.message,
    required this.child,
    required this.onGranted,
    this.onDenied,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final status = await permission.status;

        if (status.isGranted) {
          onGranted();
          return;
        }

        final granted = await PermissionService.showPermissionDialog(
          context,
          permission,
          title,
          message,
        );

        if (granted) {
          onGranted();
        } else if (onDenied != null) {
          onDenied!();
        }
      },
      child: child,
    );
  }
}
