class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // e.g., 'doctor', 'patient'
  final bool emailVerified;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.emailVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      emailVerified: json['emailVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'emailVerified': emailVerified,
    };
  }
}
