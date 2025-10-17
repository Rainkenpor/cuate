import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar la descarga persistente del modelo Gemma
/// Soporta pausas, desconexiones y reanudaciones automáticas
class ModelDownloadService {
  static const String modelUrl =
      'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task';
  static const String modelFilename = 'gemma-3n-E4B-it-int4.task';
  static const String huggingFaceToken = '';

  // Claves para SharedPreferences
  static const String _downloadIdKey = 'model_download_id';
  static const String _downloadProgressKey = 'model_download_progress';
  static const String _modelPathKey = 'model_path';
  static const String _isDownloadedKey = 'model_is_downloaded';

  DownloadTask? _currentTask;
  TaskStatus? _currentStatus;

  /// Inicializa el servicio de descarga
  Future<void> initialize() async {
    // Configurar el FileDownloader
    await FileDownloader().trackTasks();

    // Intentar restaurar descarga en progreso
    await _restoreDownloadIfExists();
  }

  /// Verifica si el modelo ya está completamente descargado
  Future<bool> isModelDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool(_isDownloadedKey) ?? false;

    if (isDownloaded) {
      final modelPath = prefs.getString(_modelPathKey);
      if (modelPath != null && await File(modelPath).exists()) {
        return true;
      } else {
        // Archivo no existe, limpiar estado
        await _clearDownloadState();
        return false;
      }
    }

    return false;
  }

  /// Obtiene el progreso actual de la descarga
  Future<double> getDownloadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_downloadProgressKey) ?? 0.0;
  }

  /// Obtiene la ruta del modelo descargado
  Future<String?> getModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPathKey);
  }

  /// Inicia o reanuda la descarga del modelo
  Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(TaskStatus status) onStatusChange,
  }) async {
    try {
      // Verificar si ya hay una descarga en progreso
      if (_currentTask != null) {
        print('Ya hay una descarga en progreso');
        return;
      }

      // Verificar si el modelo ya está descargado
      if (await isModelDownloaded()) {
        onProgress(1.0);
        onStatusChange(TaskStatus.complete);
        return;
      }

      // Obtener directorio para guardar el modelo
      final directory = await _getModelDirectory();

      // Crear la tarea de descarga
      _currentTask = DownloadTask(
        url: modelUrl,
        filename: modelFilename,
        directory: directory.path,
        baseDirectory: BaseDirectory.applicationSupport,
        updates: Updates.statusAndProgress,
        requiresWiFi: false,
        retries: 10, // Reintentos automáticos
        allowPause: true,
        metaData: 'gemma_model_download',
        headers: huggingFaceToken.isNotEmpty
            ? {'Authorization': 'Bearer $huggingFaceToken'}
            : {},
      );

      // Guardar ID de la tarea
      await _saveDownloadId(_currentTask!.taskId);

      // Iniciar la descarga con listeners usando el método recomendado
      final result = await FileDownloader().enqueue(_currentTask!);
      print('Descarga iniciada: $result');

      // Configurar listener para esta tarea específica
      FileDownloader().updates
          .where((update) => update.task.taskId == _currentTask?.taskId)
          .listen((update) {
            if (update is TaskStatusUpdate) {
              _currentStatus = update.status;
              onStatusChange(update.status);
              _handleStatusUpdate(update);
            } else if (update is TaskProgressUpdate) {
              onProgress(update.progress);
              _saveProgress(update.progress);
            }
          });
    } catch (e) {
      print('Error al iniciar descarga: $e');
      throw Exception('Error al iniciar la descarga del modelo: $e');
    }
  }

  /// Pausa la descarga actual
  Future<bool> pauseDownload() async {
    if (_currentTask == null) return false;

    final success = await FileDownloader().pause(_currentTask!);
    return success;
  }

  /// Reanuda una descarga pausada
  Future<bool> resumeDownload() async {
    if (_currentTask == null) return false;

    final success = await FileDownloader().resume(_currentTask!);
    return success;
  }

  /// Cancela la descarga actual
  Future<bool> cancelDownload() async {
    if (_currentTask == null) return false;

    final success = await FileDownloader().cancel(_currentTask!);
    if (success) {
      await _clearDownloadState();
      _currentTask = null;
    }
    return success;
  }

  /// Obtiene el estado actual de la descarga
  TaskStatus? getCurrentStatus() {
    return _currentStatus;
  }

  /// Maneja las actualizaciones de estado
  void _handleStatusUpdate(TaskStatusUpdate update) async {
    switch (update.status) {
      case TaskStatus.complete:
        await _onDownloadComplete();
        break;
      case TaskStatus.failed:
        await _onDownloadFailed(update);
        break;
      case TaskStatus.canceled:
        await _clearDownloadState();
        break;
      case TaskStatus.paused:
        print('Descarga pausada');
        break;
      case TaskStatus.running:
        print('Descarga en progreso');
        break;
      case TaskStatus.enqueued:
        print('Descarga en cola');
        break;
      case TaskStatus.notFound:
        print('Descarga no encontrada');
        break;
      case TaskStatus.waitingToRetry:
        print('Esperando para reintentar descarga');
        break;
    }
  }

  /// Maneja la finalización exitosa de la descarga
  Future<void> _onDownloadComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final directory = await _getModelDirectory();
    final filePath = '${directory.path}/$modelFilename';

    // Verificar que el archivo existe
    if (await File(filePath).exists()) {
      await prefs.setBool(_isDownloadedKey, true);
      await prefs.setString(_modelPathKey, filePath);
      await prefs.setDouble(_downloadProgressKey, 1.0);
      print('Modelo descargado exitosamente en: $filePath');
    } else {
      print('Error: Archivo de modelo no encontrado después de la descarga');
    }

    _currentTask = null;
  }

  /// Maneja los fallos en la descarga
  Future<void> _onDownloadFailed(TaskStatusUpdate update) async {
    print('Descarga fallida: ${update.exception}');

    // El FileDownloader intentará reintentar automáticamente
    // si configuramos retries > 0
    if (update.exception != null) {
      print('Excepción: ${update.exception}');
    }
  }

  /// Restaura una descarga en progreso si existe
  Future<void> _restoreDownloadIfExists() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadId = prefs.getString(_downloadIdKey);

    if (downloadId != null) {
      // Intentar obtener el estado de la tarea
      final task = await FileDownloader().taskForId(downloadId);
      if (task != null) {
        _currentTask = task as DownloadTask?;
        print('Descarga restaurada: ${task.taskId}');
      }
    }
  }

  /// Guarda el ID de la descarga actual
  Future<void> _saveDownloadId(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadIdKey, taskId);
  }

  /// Guarda el progreso actual
  Future<void> _saveProgress(double progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_downloadProgressKey, progress);
  }

  /// Limpia el estado de descarga guardado
  Future<void> _clearDownloadState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_downloadIdKey);
    await prefs.remove(_downloadProgressKey);
    await prefs.remove(_isDownloadedKey);
    await prefs.remove(_modelPathKey);
  }

  /// Obtiene el directorio donde se guardará el modelo
  Future<Directory> _getModelDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final modelDir = Directory('${appSupportDir.path}/models');

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    return modelDir;
  }

  /// Libera recursos
  void dispose() {
    _currentTask = null;
  }
}
