import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:videos_alarm_app/components/app_style.dart';
import 'package:videos_alarm_app/screens/user_chat.dart';

const Color kBackgroundColor = Color(0xFF121212);
const Color kSurfaceColor = Color(0xFF1E1E1E);
const Color kPrimaryColor = Color(0xFF8A2BE2);
const Color kWhiteColor = Colors.white;
const Color kTextColor = Color(0xFFE0E0E0);
const Color kHintTextColor = Colors.grey;
const Color kSuccessColor = Colors.greenAccent;
const Color kErrorColor = Colors.redAccent;

class SupportPage extends StatelessWidget {
  final String? calledFrom;

  const SupportPage({super.key, this.calledFrom});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: calledFrom == 'settings'
            ? AppBar(
                foregroundColor: Colors.white,
                backgroundColor: blackColor,
                elevation: 2,
                centerTitle: true,
                title: Text(
                  "Support Center",
                ),
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                child: _buildCustomTabBar(),
              ),
              const SizedBox(height: 16),
              const Expanded(
                child: TabBarView(
                  children: [
                    _RaiseTicketForm(),
                    _MyTicketsList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TabBar(
        labelColor: kWhiteColor,
        unselectedLabelColor: kHintTextColor,
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 16),
        indicator: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(30),
        ),
        indicatorPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded),
                SizedBox(width: 8),
                Text('Raise Ticket'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded),
                SizedBox(width: 8),
                Text('My Tickets'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat.yMMMd().add_jm().format(timestamp.toDate());
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status.toLowerCase()) {
      case 'open':
        chipColor = Colors.green;
        break;
      case 'in-progress':
        chipColor = Colors.orangeAccent;
        break;
      case 'closed':
        chipColor = Colors.blueGrey;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2.0),
    );
  }
}

void _showThemedSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message,
          style: const TextStyle(
              color: kBackgroundColor, fontWeight: FontWeight.bold)),
      backgroundColor: isError ? kErrorColor : kSuccessColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class _RaiseTicketForm extends StatefulWidget {
  const _RaiseTicketForm();

  @override
  State<_RaiseTicketForm> createState() => __RaiseTicketFormState();
}

class __RaiseTicketFormState extends State<_RaiseTicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;
  final List<String> _categories = [
    'Technical Issue',
    'Billing Inquiry',
    'General Question',
    'Feedback'
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showThemedSnackBar(context, 'Please select a category.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to submit a ticket.');
      }
      final ticketsCollection =
          FirebaseFirestore.instance.collection('tickets');
      final newTicketRef = ticketsCollection.doc();
      final descriptionText = _descriptionController.text.trim();
      await newTicketRef.set({
        'ticketId': newTicketRef.id,
        'userId': user.uid,
        'name': user.displayName ?? 'User',
        'subject': _subjectController.text.trim(),
        'description': descriptionText,
        'category': _selectedCategory,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await newTicketRef.collection('messages').add({
        'text': descriptionText,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': user.uid,
        'senderRole': 'user',
      });
      if (mounted) {
        _showThemedSnackBar(context, 'Ticket submitted successfully!');
        _formKey.currentState!.reset();
        _subjectController.clear();
        _descriptionController.clear();
        setState(() => _selectedCategory = null);
      }
    } catch (e) {
      if (mounted) {
        _showThemedSnackBar(context, 'Failed to submit ticket: $e',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kHintTextColor),
      prefixIcon: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12.0),
        child: Icon(icon, color: kHintTextColor),
      ),
      filled: true,
      fillColor: kSurfaceColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _subjectController,
                  decoration: _buildInputDecoration(
                      'Subject', Icons.short_text_rounded),
                  style: const TextStyle(color: kTextColor),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Please enter a subject.'
                      : null,
                ),
                const SizedBox(height: 20.0),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration:
                      _buildInputDecoration('Category', Icons.category_rounded),
                  dropdownColor: kSurfaceColor,
                  style: const TextStyle(color: kTextColor),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                  items: _categories
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  validator: (v) =>
                      v == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: 20.0),
                Stack(
                  children: [
                    TextFormField(
                      controller: _descriptionController,
                      style: const TextStyle(color: kTextColor),
                      maxLines: 6,
                      validator: (v) => v == null || v.trim().length < 20
                          ? 'Description must be at least 20 characters.'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: const TextStyle(color: kHintTextColor),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: kSurfaceColor,
                        contentPadding:
                            const EdgeInsets.fromLTRB(48, 20, 12, 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: kPrimaryColor, width: 2),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 14,
                      top: 20,
                      child: Icon(Icons.description_rounded,
                          color: kHintTextColor),
                    ),
                  ],
                ),
                const SizedBox(height: 30.0),
                _buildSubmitButton(),
              ],
            ),
          ),
          const SizedBox(height: 30.0),
          const Text(
            'In-Progress Tickets',
            style: TextStyle(
              color: kWhiteColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16.0),
          user == null
              ? const Center(
                  child: Text(
                    "Please log in to see your in-progress tickets.",
                    style: TextStyle(color: kHintTextColor, fontSize: 16),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tickets')
                      .where('userId', isEqualTo: user.uid)
                      .where('status', isEqualTo: 'in-progress')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: kPrimaryColor),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: const TextStyle(color: kErrorColor),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 32),
                            Text(
                              "No tickets are currently in progress.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: kHintTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final tickets = snapshot.data!.docs;
                    // Sort client-side
                    tickets.sort((a, b) => (b['createdAt'] as Timestamp)
                        .compareTo(a['createdAt'] as Timestamp));

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tickets.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        final data = ticket.data() as Map<String, dynamic>;
                        final subject = data['subject'] ?? 'No Subject';

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserChatPage(
                                  ticketId: ticket.id,
                                  ticketSubject: subject,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kSurfaceColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subject,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: kWhiteColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SupportPage()._buildStatusChip(
                                        data['status'] ?? 'unknown'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Category: ${data['category']}',
                                  style: TextStyle(
                                    color: kTextColor.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Created: ${SupportPage()._formatTimestamp(data['createdAt'])}',
                                  style: const TextStyle(
                                    color: kHintTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading
              ? [Colors.grey, Colors.grey]
              : [kPrimaryColor, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitTicket,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: kWhiteColor,
                  strokeWidth: 3,
                ),
              )
            : const Text('Submit Ticket', style: TextStyle(color: kWhiteColor)),
      ),
    );
  }
}

class _MyTicketsList extends StatelessWidget {
  const _MyTicketsList();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text(
          "Please log in to see your tickets.",
          style: TextStyle(color: kHintTextColor, fontSize: 16),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryColor),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: kErrorColor),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 80, color: kHintTextColor),
                SizedBox(height: 16),
                Text(
                  "No Tickets Found",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Raise a new ticket to get started.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: kHintTextColor),
                ),
              ],
            ),
          );
        }

        final tickets = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: tickets.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            final data = ticket.data() as Map<String, dynamic>;
            final subject = data['subject'] ?? 'No Subject';

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserChatPage(
                      ticketId: ticket.id,
                      ticketSubject: subject,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurfaceColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: kWhiteColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SupportPage()
                            ._buildStatusChip(data['status'] ?? 'unknown'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Category: ${data['category']}',
                      style: TextStyle(
                        color: kTextColor.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Created: ${SupportPage()._formatTimestamp(data['createdAt'])}',
                      style: const TextStyle(
                        color: kHintTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
