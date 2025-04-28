class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final int durationInDays;
  final String price; 

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.durationInDays,
    required this.price,
  });

  static final List<SubscriptionPlan> _plans = [
    SubscriptionPlan(
      id: 'vip_plan_id',
      name: 'Premium Plan',
      description: 'Access to standard videos.',
      durationInDays: 30,
      price: '\$4.99',
    ),
    SubscriptionPlan(
      id: 'com.videosalarm.subscription.premium',
      name: 'Premium Plan',
      description: 'Access to all videos with premium features.',
      durationInDays: 365,
      price: '\$49.99', 
    ),
  ];

  static SubscriptionPlan? getById(String id) {
    try {
      return _plans.firstWhere((plan) => plan.id == id);
    } catch (e) {
      print("Subscription plan with ID $id not found: $e"); // Log if not found
      return null; // Return null if not found
    }
  }

  static String getDescriptionById(String id) {
    SubscriptionPlan? plan = getById(id);
    return plan?.description ?? 'No active subscription';
  }
}



