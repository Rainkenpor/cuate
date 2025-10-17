import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cuate/services/gemma_service.dart';
import 'package:cuate/services/speech_service.dart';
import 'package:cuate/models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final GemmaService gemmaService;

  const ChatScreen({super.key, required this.gemmaService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SpeechService _speechService = SpeechService();
  final ImagePicker _imagePicker = ImagePicker();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  Uint8List? _selectedImageBytes;
  String _currentAiResponse = '';

  @override
  void initState() {
    super.initState();
    _speechService.initialize();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      text:
          '¡Hola! Soy tu asistente visual. Puedo ayudarte describiendo imágenes, respondiendo preguntas y más. Puedes escribir, hablar o enviar imágenes.',
      isUser: false,
    );
    setState(() {
      _messages.add(welcomeMessage);
    });
    _speechService.speak(welcomeMessage.text);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechService.stopListening(
        onStatus: (isListening) {
          setState(() {
            _isListening = isListening;
          });
        },
      );
    } else {
      try {
        await _speechService.startListening(
          onResult: (text) {
            setState(() {
              _textController.text = text;
            });
          },
          onStatus: (isListening) {
            setState(() {
              _isListening = isListening;
            });
          },
        );
      } catch (e) {
        _showError('Error al iniciar reconocimiento de voz: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final imageBytes = _selectedImageBytes;

    if (text.isEmpty && imageBytes == null) {
      return;
    }

    // Agregar mensaje del usuario
    final userMessage = ChatMessage(
      text: text.isNotEmpty ? text : '[Imagen enviada]',
      isUser: true,
      imageBytes: imageBytes,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _currentAiResponse = '';
      _textController.clear();
      _selectedImageBytes = null;
    });

    _scrollToBottom();

    // Crear mensaje de IA vacío que se irá llenando
    final aiMessage = ChatMessage(text: '', isUser: false);

    setState(() {
      _messages.add(aiMessage);
    });

    try {
      // Recibir respuesta de la IA en streaming
      await for (final token in widget.gemmaService.sendMessage(
        text: text.isNotEmpty ? text : null,
        imageBytes: imageBytes,
      )) {
        setState(() {
          _currentAiResponse += token;
          // Actualizar el último mensaje (el de la IA)
          _messages[_messages.length - 1] = ChatMessage(
            text: _currentAiResponse,
            isUser: false,
            timestamp: aiMessage.timestamp,
          );
        });
        _scrollToBottom();
      }

      // Leer la respuesta completa en voz alta
      if (_currentAiResponse.isNotEmpty) {
        await _speechService.speak(_currentAiResponse);
      }
    } catch (e) {
      _showError('Error al enviar mensaje: $e');
      // Eliminar el mensaje de IA vacío si hubo error
      setState(() {
        _messages.removeLast();
      });
    } finally {
      setState(() {
        _isLoading = false;
        _currentAiResponse = '';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speechService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuate - Asistente Visual'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () {
              _speechService.stop();
            },
            tooltip: 'Detener lectura',
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // Preview de imagen seleccionada
          if (_selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade200,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Imagen seleccionada')),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedImageBytes = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Barra de entrada
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_camera),
                  onPressed: _isLoading ? null : _showImageSourceDialog,
                  color: Colors.purple.shade700,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    enabled: !_isLoading,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Colors.purple.shade700,
                  ),
                  onPressed: _isLoading ? null : _toggleListening,
                ),
                IconButton(
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                  color: Colors.purple.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: message.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.imageBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    message.imageBytes!,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? Colors.purple.shade700
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        color: message.isUser ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
