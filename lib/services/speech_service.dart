import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  bool _isInitialized = false;

  // Inicializa los servicios de voz
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configurar Text to Speech
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    // Inicializar Speech to Text
    _isInitialized = await _speechToText.initialize(
      onError: (error) => print('Error de reconocimiento: $error'),
      onStatus: (status) => print('Estado: $status'),
    );
  }

  // Convierte texto a voz
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    await _flutterTts.speak(text);
  }

  // Detiene la lectura
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  // Inicia el reconocimiento de voz
  Future<void> startListening({
    required Function(String text) onResult,
    required Function(bool isListening) onStatus,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      throw Exception('No se pudo inicializar el reconocimiento de voz');
    }

    onStatus(true);

    await _speechToText.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: 'es_ES',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  // Detiene el reconocimiento de voz
  Future<void> stopListening({
    required Function(bool isListening) onStatus,
  }) async {
    await _speechToText.stop();
    onStatus(false);
  }

  // Verifica si está escuchando
  bool get isListening => _speechToText.isListening;

  // Verifica si está disponible
  bool get isAvailable => _isInitialized;

  // Limpia los recursos
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
  }
}
