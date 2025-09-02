import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:videos_alarm_app/screens/Vid_controller.dart';

class TVVideoPreviewDialog extends StatefulWidget {
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? duration;
  final String? releaseYear;
  final String? cbfc;
  final String? starcast;

  const TVVideoPreviewDialog({
    Key? key,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.duration,
    this.releaseYear,
    this.cbfc,
    this.starcast,
  }) : super(key: key);

  @override
  _TVVideoPreviewDialogState createState() => _TVVideoPreviewDialogState();
}

class _TVVideoPreviewDialogState extends State<TVVideoPreviewDialog> {
  final FocusNode _cancelFocusNode = FocusNode();
  final FocusNode _playFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus on the "Cancel" button when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cancelFocusNode.requestFocus();
      print("Initial focus requested for Cancel button");
    });

    // Debug focus changes
    _cancelFocusNode.addListener(() {
      print("Cancel button focus changed: ${_cancelFocusNode.hasFocus}");
    });
    _playFocusNode.addListener(() {
      print("Play button focus changed: ${_playFocusNode.hasFocus}");
    });
  }

  @override
  void dispose() {
    _cancelFocusNode.dispose();
    _playFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final VideoController videoController = Get.put(VideoController());

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth * 0.5;
    final dialogHeight = screenHeight * 0.75;

    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          print("Raw key pressed: ${event.logicalKey.debugName}");
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 22, 21, 21),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.thumbnailUrl != null &&
                        widget.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        widget.thumbnailUrl!,
                        width: double.infinity,
                        height: dialogHeight * 0.5,
                        fit: BoxFit.fill,
                        errorBuilder: (ctx, err, stack) => Container(
                          color: Colors.grey[850],
                          height: dialogHeight * 0.4,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: dialogHeight * 0.4,
                        color: Colors.grey[850],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title ?? "Untitled",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (widget.releaseYear != null &&
                      widget.releaseYear!.isNotEmpty)
                    _TVInfoPill(label: widget.releaseYear!),
                  if (widget.releaseYear != null &&
                      widget.releaseYear!.isNotEmpty &&
                      widget.cbfc != null &&
                      widget.cbfc!.isNotEmpty)
                    const SizedBox(width: 12),
                  if (widget.cbfc != null && widget.cbfc!.isNotEmpty)
                    _TVInfoPill(label: widget.cbfc!),
                  if ((widget.releaseYear != null &&
                              widget.releaseYear!.isNotEmpty ||
                          widget.cbfc != null && widget.cbfc!.isNotEmpty) &&
                      widget.duration != null &&
                      widget.duration!.isNotEmpty)
                    const SizedBox(width: 12),
                  if (widget.duration != null && widget.duration!.isNotEmpty)
                    _TVInfoPill(label: widget.duration!),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.description ?? "",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.starcast != null && widget.starcast!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cast: ",
                      style: TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 1),
                        fontSize: 8,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.starcast!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _TVButton(
                    text: "Cancel",
                    focusNode: _cancelFocusNode,
                    onPressed: () {
                      print("Cancel button pressed");
                      Navigator.of(context).pop(false);
                    },
                    isPrimary: false,
                  ),
                  const SizedBox(width: 16),
                  _TVButton(
                    text: widget.title == "Streaming Soon" ? "Soon" : "Play",
                    icon: Icons.play_arrow,
                    focusNode: _playFocusNode,
                    onPressed: () {
                      print("Play button pressed");
                      Navigator.of(context).pop(true);
                    },
                    isPrimary: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVInfoPill extends StatelessWidget {
  final String label;

  const _TVInfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 165, 165, 165).withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 8,
        ),
      ),
    );
  }
}

class _TVButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final FocusNode focusNode;

  const _TVButton({
    required this.text,
    this.icon,
    required this.onPressed,
    required this.isPrimary,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      canRequestFocus: true,
      onKeyEvent: (node, event) {
        print("Button key event for $text: ${event.logicalKey.debugName}");
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.accept)) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPrimary
                  ? Colors.blueAccent[400]!.withOpacity(0.8)
                  : Colors.black.withOpacity(0.7),
              foregroundColor: isPrimary ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: isFocused ? Colors.white : Colors.white30,
                  width: isFocused ? 1.5 : 1,
                ),
              ),
              elevation: isFocused ? 6 : 2,
              minimumSize: const Size(60, 20),
            ),
            onPressed: () {
              print("Button tapped: $text");
              onPressed();
            },
            child: Row(
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    size: 12,
                    color: isPrimary ? Colors.white : Colors.white70,
                  ),
                if (icon != null) const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
