import 'package:cloud_firestore/cloud_firestore.dart';

class Discount {
  final String id;
  final String name;
  final String description;
  final String type; // percentage, fixed
  final double value;
  final List<String> eligibility;
  final List<String> applicableRoutes;
  final DateTime validFrom;
  final DateTime validTo;
  final int maxUsage;
  final int currentUsage;
  final bool isActive;
  final DateTime createdAt;

  Discount({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.eligibility,
    required this.applicableRoutes,
    required this.validFrom,
    required this.validTo,
    required this.maxUsage,
    required this.currentUsage,
    required this.isActive,
    required this.createdAt,
  });

  factory Discount.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Discount(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'percentage',
      value: (data['value'] ?? 0).toDouble(),
      eligibility: List<String>.from(data['eligibility'] ?? []),
      applicableRoutes: List<String>.from(data['applicableRoutes'] ?? []),
      validFrom: (data['validFrom'] as Timestamp?)?.toDate() ?? DateTime.now(),
      validTo: (data['validTo'] as Timestamp?)?.toDate() ?? DateTime.now(),
      maxUsage: data['maxUsage'] ?? 0,
      currentUsage: data['currentUsage'] ?? 0,
      isActive: data['isActive'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'type': type,
      'value': value,
      'eligibility': eligibility,
      'applicableRoutes': applicableRoutes,
      'validFrom': Timestamp.fromDate(validFrom),
      'validTo': Timestamp.fromDate(validTo),
      'maxUsage': maxUsage,
      'currentUsage': currentUsage,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Discount copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    double? value,
    List<String>? eligibility,
    List<String>? applicableRoutes,
    DateTime? validFrom,
    DateTime? validTo,
    int? maxUsage,
    int? currentUsage,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Discount(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      eligibility: eligibility ?? this.eligibility,
      applicableRoutes: applicableRoutes ?? this.applicableRoutes,
      validFrom: validFrom ?? this.validFrom,
      validTo: validTo ?? this.validTo,
      maxUsage: maxUsage ?? this.maxUsage,
      currentUsage: currentUsage ?? this.currentUsage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  double calculateDiscountAmount(double baseAmount) {
    if (!isActive) return 0.0;

    switch (type) {
      case 'percentage':
        return baseAmount * (value / 100);
      case 'fixed':
        return value;
      default:
        return 0.0;
    }
  }
}
