import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:background_downloader/background_downloader.dart';
import 'model_download_service.dart';

class GemmaService {
  static const String modelUrl =
      'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task';
  static const String modelFilename = 'gemma-3n-E4B-it-int4.task';
  static const String huggingFaceToken = '';

  InferenceModel? _inferenceModel;
  InferenceChat? _chat;
  final ModelDownloadService _downloadService = ModelDownloadService();

  /// Inicializa el servicio de descarga
  Future<void> initializeDownloadService() async {
    await _downloadService.initialize();
  }

  /// Verifica si el modelo ya está descargado
  Future<bool> isModelDownloaded() async {
    return await _downloadService.isModelDownloaded();
  }

  /// Obtiene el progreso actual de descarga
  Future<double> getDownloadProgress() async {
    return await _downloadService.getDownloadProgress();
  }

  /// Descarga el modelo con soporte de persistencia y reanudación
  /// La descarga continuará incluso si se pierde la conexión
  Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(TaskStatus status) onStatusChange,
  }) async {
    try {
      await _downloadService.downloadModel(
        onProgress: onProgress,
        onStatusChange: onStatusChange,
      );
    } catch (e) {
      throw Exception('Error al descargar el modelo: $e');
    }
  }

  /// Pausa la descarga actual
  Future<bool> pauseDownload() async {
    return await _downloadService.pauseDownload();
  }

  /// Reanuda la descarga pausada
  Future<bool> resumeDownload() async {
    return await _downloadService.resumeDownload();
  }

  /// Cancela la descarga
  Future<bool> cancelDownload() async {
    return await _downloadService.cancelDownload();
  }

  /// Obtiene el estado actual de la descarga
  TaskStatus? getDownloadStatus() {
    return _downloadService.getCurrentStatus();
  }

  /// Instala el modelo en flutter_gemma desde el archivo descargado
  Future<void> installModelFromFile() async {
    try {
      final modelPath = await _downloadService.getModelPath();

      if (modelPath == null || !await File(modelPath).exists()) {
        throw Exception('El archivo del modelo no existe');
      }

      // Instalar el modelo desde el archivo local
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(modelPath).install();

      print('Modelo instalado exitosamente desde: $modelPath');
    } catch (e) {
      throw Exception('Error al instalar el modelo: $e');
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
