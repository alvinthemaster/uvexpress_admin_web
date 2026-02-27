import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'passenger' | 'conductor' | 'driver'
  final bool isRestricted;
  final bool isEmailVerified;
  final String? profileImageUrl;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isRestricted,
    required this.isEmailVerified,
    this.profileImageUrl,
    this.lastLogin,
    required this.createdAt,
    this.updatedAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      name: (data['name'] ?? data['fullName'] ?? data['displayName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: (data['phone'] ?? data['phoneNumber'] ?? data['contactNumber'] ?? '').toString(),
      role: (data['role'] ?? data['userType'] ?? 'passenger').toString(),
      isRestricted: _parseBool(data['isRestricted'] ?? data['isDisabled'] ?? data['isBanned']) ?? false,
      isEmailVerified: _parseBool(data['isEmailVerified'] ?? data['emailVerified']) ?? false,
      profileImageUrl: data['profileImageUrl'] ?? data['photoURL'],
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ??
          (data['lastSignIn'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['dateCreated'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isRestricted': isRestricted,
      'isEmailVerified': isEmailVerified,
      'profileImageUrl': profileImageUrl,
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isRestricted,
    bool? isEmailVerified,
    String? profileImageUrl,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isRestricted: isRestricted ?? this.isRestricted,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }

  static const Map<String, int> roleColors = {
    'passenger': 0xFF1976D2,
    'conductor': 0xFF388E3C,
    'driver': 0xFFF57C00,
  };

  String get displayRole => role.isNotEmpty
      ? role[0].toUpperCase() + role.substring(1)
      : 'Passenger';
}
