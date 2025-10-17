import 'dart:typed_data';
import 'package:flutter_gemma/flutter_gemma.dart';

class GemmaService {
  static const String modelUrl =
      'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task';
  static const String modelFilename = 'gemma-3n-E4B-it-int4.task';
  static const String huggingFaceToken = '';

  InferenceModel? _inferenceModel;
  InferenceChat? _chat;

  // Verifica si el modelo ya está descargado
  Future<bool> isModelDownloaded() async {
    try {
      // Intenta inicializar el modelo para ver si está disponible
      await FlutterGemma.getActiveModel(maxTokens: 512);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Descarga el modelo con progreso usando la API de flutter_gemma
  Future<void> downloadModel({
    required Function(double progress) onProgress,
  }) async {
    try {
      var lastProgress = 0.0;
      await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
          .fromNetwork(modelUrl, token: huggingFaceToken)
          .withProgress((downloadProgress) {
            // downloadProgress es un int (porcentaje 0-100)
            lastProgress = downloadProgress / 100.0;
            onProgress(lastProgress);
          })
          .install();

      onProgress(1.0);
    } catch (e) {
      throw Exception('Error al descargar el modelo: $e');
    }
  }

  // Inicializa el modelo y el chat
  Future<void> initializeChat() async {
    try {
      _inferenceModel = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        preferredBackend: PreferredBackend.gpu,
        supportImage: true,
        maxNumImages: 1,
      );

      _chat = await _inferenceModel!.createChat(
        temperature: 0.8,
        randomSeed: 1,
        topK: 40,
        topP: 0.9,
        supportImage: true,
      );
    } catch (e) {
      throw Exception('Error al inicializar el chat: $e');
    }
  }

  // Envía un mensaje con texto y/o imagen
  Stream<String> sendMessage({String? text, Uint8List? imageBytes}) async* {
    if (_chat == null) {
      throw Exception('El chat no está inicializado');
    }

    try {
      Message message;

      if (imageBytes != null) {
        message = Message.withImage(
          text: text ?? "¿Qué ves en esta imagen?",
          imageBytes: imageBytes,
          isUser: true,
        );
      } else {
        message = Message.text(text: text ?? "", isUser: true);
      }

      await _chat!.addQueryChunk(message);

      final responseStream = _chat!.generateChatResponseAsync();

      await for (final response in responseStream) {
        if (response is TextResponse) {
          yield response.token;
        }
      }
    } catch (e) {
      throw Exception('Error al enviar mensaje: $e');
    }
  }

  // Limpia los recursos
  Future<void> dispose() async {
    // InferenceChat no tiene método close, solo se limpia el modelo
    await _inferenceModel?.close();
    _chat = null;
  }
}
