import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WatchLaterButton extends StatefulWidget {
  final String videoId;

  const WatchLaterButton({super.key, required this.videoId});

  @override
  State<WatchLaterButton> createState() => _WatchLaterButtonState();
}

class _WatchLaterButtonState extends State<WatchLaterButton> {
  bool isInWatchlist = false;
  bool isLoading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    fetchWatchlistStatus();
  }

  Future<void> fetchWatchlistStatus() async {
    userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    final List<dynamic> watchlist = doc.data()?['watchlist'] ?? [];
    setState(() {
      isInWatchlist = watchlist.contains(widget.videoId);
      isLoading = false;
    });
  }

  Future<void> toggleWatchlist() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in.')),
      );
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      if (isInWatchlist) {
        await userRef.update({
          'watchlist': FieldValue.arrayRemove([widget.videoId])
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from Watch Later')),
        );
      } else {
        await userRef.update({
          'watchlist': FieldValue.arrayUnion([widget.videoId])
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Watch Later')),
        );
      }

      setState(() {
        isInWatchlist = !isInWatchlist;
      });
    } catch (e) {
      print('❌ Error updating watchlist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating watchlist: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const CircularProgressIndicator();

    return Column(
      children: [
        IconButton(
          icon: Icon(
            isInWatchlist ? Icons.check : Icons.add,
            color: Colors.white,
            size: 34,
          ),
          onPressed: toggleWatchlist,
        ),
        const SizedBox(height: 12),
        const Text(
          "Watch Later",
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
      ],
    );
  }
}
