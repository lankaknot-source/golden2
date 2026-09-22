import 'package:equatable/equatable.dart';

// Matches care2's SubscriptionPlan exactly
// Collection: subscription_plans
class SubscriptionPlan extends Equatable {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> assignedCaregivers;
  final int timestamp;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    this.description = '',
    required this.price,
    this.assignedCaregivers = const [],
    this.timestamp = 0,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map, String id) {
    return SubscriptionPlan(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      assignedCaregivers: List<String>.from(map['assignedCaregivers'] as List? ?? []),
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'price': price,
        'assignedCaregivers': assignedCaregivers,
        'timestamp': timestamp,
      };

  @override
  List<Object?> get props => [id, title, description, price, assignedCaregivers, timestamp];
}
