import 'dart:typed_data';

class ChatMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
