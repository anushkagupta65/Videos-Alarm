import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:videos_alarm_app/Controller/Sub_controller.dart';


class SubscriptionPlanCard extends StatefulWidget {
  final String planId;
  final VoidCallback onSubscribe;

  const SubscriptionPlanCard({Key? key, required this.planId, required this.onSubscribe})
      : super(key: key);

  @override
  _SubscriptionPlanCardState createState() => _SubscriptionPlanCardState();
}

class _SubscriptionPlanCardState extends State<SubscriptionPlanCard> {
  String? _planName;
  String? _price;
  String? _description;
  bool _isLoading = true;
  double _elevation = 5; // Reduced default elevation
  bool _isHovered = false;
  bool _isButtonPressed = false;

  final SubscriptionController subscriptionController = Get.find<SubscriptionController>();

  @override
  void initState() {
    super.initState();

    // Load the details immediately, but show a placeholder until they're available.
    _planName = 'Loading...';
    _price = 'Loading...';
    _description = 'Loading...';
    _loadPlanDetails();  // Start loading the actual data.
  }

  Future<void> _loadPlanDetails() async {
    try {
      final productDetails =
          subscriptionController.productDetailsMap.value[widget.planId];

      if (mounted) {
        setState(() {
          _planName = productDetails?.title ?? 'Unavailable';
          _price = productDetails?.price ?? 'Unavailable';
          _description = productDetails?.description ?? 'Unavailable';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading plan details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _planName = 'Error';
          _price = 'Error';
          _description = 'Failed to load data';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: MouseRegion(
          onEnter: (_) {
            if (mounted) {
              setState(() {
                _isHovered = true;
                _elevation = 8; // Slightly increased elevation on hover
              });
            }
          },
          onExit: (_) {
            if (mounted) {
              // Check if the widget is still in the tree
              setState(() {
                _isHovered = false;
                _elevation = 5; // Restore default elevation
              });
            }
          },
          child: Material(
            elevation: _elevation,
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[900], // Dark background color for the card
            child: Container(
              decoration: BoxDecoration(
                // Removed LinearGradient for a solid dark background
                // gradient: const LinearGradient(
                //   colors: [
                //     Color.fromARGB(255, 99, 29, 70),
                //     Color.fromARGB(255, 33, 30, 42),
                //   ],
                //   begin: Alignment.topLeft,
                //   end: Alignment.bottomRight,
                // ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedOpacity(
                      opacity: _isHovered ? 0.8 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        child: Text(
                          '${_price != 'Error' && _price != 'Loading...'
                                  ? _price
                                  : (_price == 'Loading...' ? 'Loading...' : 'Unavailable')}/Only',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedOpacity(
                      opacity: _isHovered ? 0.8 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: Center(
                        child: Text(
                          _description == 'Loading...' ? 'Loading description...' : _description ?? 'Unavailable description', // Show a placeholder while loading.
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTapDown: (_) {
                        if (mounted) {
                          setState(() {
                            _isButtonPressed = true;
                          });
                        }
                      },
                      onTapUp: (_) {
                        if (mounted) {
                          setState(() {
                            _isButtonPressed = false;
                          });
                        }
                      },
                      onTap: _isLoading || _planName == 'Error' || _description == 'Error' ? null : widget.onSubscribe,
                      child: AnimatedScale(
                        scale: _isButtonPressed ? 0.95 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: _isLoading || _planName == 'Error' || _description == 'Error' ? null : widget.onSubscribe,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: _isLoading || _planName == 'Error' || _description == 'Error' ? Colors.grey[700] : const Color.fromARGB(255, 89, 80, 215),
                            shadowColor: Colors.black.withOpacity(0.3),
                            elevation: 3,
                          ),
                          child: Text(
                            _isLoading ? 'Loading...' : _planName == 'Error' || _description == 'Error' ? 'Error' : 'Subscribe Now',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}