import 'package:flutter/material.dart';

enum LegalDocumentType {
  privacyPolicy,
  termsOfService,
}

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final LegalDocumentType documentType;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.documentType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last Updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _getDocumentContent(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Settings'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDocumentContent() {
    switch (documentType) {
      case LegalDocumentType.privacyPolicy:
        return _privacyPolicyText;
      case LegalDocumentType.termsOfService:
        return _termsOfServiceText;
    }
  }

  // Privacy Policy Text
  static const String _privacyPolicyText = '''
# PRIVACY POLICY

## INTRODUCTION

MedicoLegal Records App ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application (the "App").

Please read this Privacy Policy carefully. By accessing or using the App, you acknowledge that you have read, understood, and agree to be bound by all the terms of this Privacy Policy.

## INFORMATION WE COLLECT

### Personal Information
- Name, email address, and phone number
- Date of birth and age
- Medical and health information
- Patient ID or other identifiers
- Professional information (for doctors)
- Login credentials

### Technical Information
- Device information (model, operating system)
- App usage data
- IP address
- Biometric authentication data (if enabled)

## HOW WE USE YOUR INFORMATION

- Provide, maintain, and improve the App
- Create and manage user accounts
- Process and manage medical records
- Facilitate appointments between patients and doctors
- Send notifications about appointments, medications, and lab results
- Authenticate users and secure account access
- Comply with legal obligations

## DATA SECURITY

We implement appropriate technical and organizational measures to protect the security of your personal information. However, please be aware that no method of transmission over the internet or electronic storage is 100% secure, and we cannot guarantee absolute security.

### Security Measures
- Encryption of sensitive data
- Secure authentication procedures including biometric options
- Regular security assessments
- Access controls and permissions

## DATA SHARING AND DISCLOSURE

### With Your Consent
- Patient data is shared with doctors only with explicit patient consent
- Medical professionals can access patient records based on permissions granted by patients

### Service Providers
We may share information with third-party vendors who assist us in providing the services, such as:
- Cloud storage providers
- Authentication services
- Analytics providers

These providers have access to your information only to perform these tasks on our behalf and are obligated to not disclose or use it for any other purpose.

### Legal Compliance
We may disclose your information if required to do so by law or in response to valid requests by public authorities.

## YOUR RIGHTS

Depending on your location, you may have rights regarding your personal information, including:
- Access to your personal information
- Correction of inaccurate or incomplete information
- Deletion of your information
- Restriction or objection to processing
- Data portability

To exercise these rights, contact us using the information provided at the end of this policy.

## CHILDREN'S PRIVACY

The App is not intended for children under 18 years of age. We do not knowingly collect information from children under 18. Parents or guardians may provide and manage information for minors.

## CHANGES TO THIS PRIVACY POLICY

We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.

## CONTACT US

If you have questions or concerns about this Privacy Policy, please contact us at:
- Email: support@medicolegalrecords.com
- Phone: 1-800-MED-RECS
''';

  // Terms of Service Text
  static const String _termsOfServiceText = '''
# TERMS OF SERVICE

## AGREEMENT TO TERMS

These Terms of Service constitute a legally binding agreement between you and MedicoLegal Records App regarding your use of our mobile application (the "App").

By accessing or using the App, you acknowledge that you have read, understood, and agree to be bound by these Terms. If you do not agree to these Terms, please do not use the App.

## ACCOUNT REGISTRATION

### User Types
The App offers two primary user types:
- **Patient**: Individuals seeking to manage their medical records and healthcare information
- **Doctor**: Licensed healthcare professionals providing medical services

### Registration Requirements
- You must provide accurate, current, and complete information during registration
- Doctors must provide valid professional credentials and may require admin verification
- You are responsible for maintaining the confidentiality of your account credentials
- You are responsible for all activities under your account

## ACCEPTABLE USE

You agree to use the App only for its intended purposes and in accordance with these Terms and applicable laws and regulations.

### Prohibited Activities
You shall not:
- Use the App in any way that violates applicable laws or regulations
- Attempt to gain unauthorized access to any portion of the App
- Interfere with the proper working of the App
- Submit false or misleading information
- Upload malicious code or content
- Impersonate any person or entity

## MEDICAL DISCLAIMER

The App is not intended to replace professional medical advice, diagnosis, or treatment. Always seek the advice of qualified healthcare providers for medical concerns.

### For Patients
- Information available through the App is for informational purposes only
- The App does not provide medical advice or diagnosis
- Never disregard professional medical advice because of something you have read on the App

### For Doctors
- You are responsible for maintaining professional standards of care
- You confirm that all information provided is accurate and up-to-date
- You agree to use the App as a supplement to, not a replacement for, proper medical practice

## INTELLECTUAL PROPERTY

The App and its content, features, and functionality are owned by MedicoLegal Records App and are protected by copyright, trademark, and other intellectual property laws.

### Limited License
We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for its intended purpose, subject to these Terms.

## PRIVACY

Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference.

## TERMINATION

We reserve the right to terminate or suspend your account and access to the App at our sole discretion, without notice, for any reason, including if you violate these Terms.

## DISCLAIMER OF WARRANTIES

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED.

## LIMITATION OF LIABILITY

TO THE MAXIMUM EXTENT PERMITTED BY LAW, IN NO EVENT SHALL MEDICOLEGAL RECORDS APP BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF OR RELATED TO YOUR USE OF THE APP.

## INDEMNIFICATION

You agree to indemnify and hold harmless MedicoLegal Records App and its officers, directors, employees, and agents from any claims, liabilities, damages, losses, and expenses arising out of or related to your use of the App.

## GOVERNING LAW

These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law principles.

## CHANGES TO TERMS

We reserve the right to modify these Terms at any time. We will provide notice of significant changes by posting the updated Terms on the App and updating the "Last Updated" date.

## CONTACT US

If you have questions or concerns about these Terms, please contact us at:
- Email: support@medicolegalrecords.com
- Phone: 1-800-MED-RECS
''';
}