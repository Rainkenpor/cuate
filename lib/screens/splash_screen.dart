import 'package:flutter/material.dart';
import 'package:cuate/services/gemma_service.dart';
import 'package:cuate/screens/chat_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final GemmaService _gemmaService = GemmaService();
  double _downloadProgress = 0.0;
  String _statusMessage = 'Iniciando...';
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Verificando modelo...';
      });

      final isDownloaded = await _gemmaService.isModelDownloaded();

      if (!isDownloaded) {
        setState(() {
          _statusMessage = 'Descargando modelo de IA...';
        });

        await _gemmaService.downloadModel(
          onProgress: (progress) {
            setState(() {
              _downloadProgress = progress;
            });
          },
        );
      } else {
        setState(() {
          _downloadProgress = 1.0;
        });
      }

      setState(() {
        _statusMessage = 'Inicializando modelo...';
      });

      await _gemmaService.initializeChat();

      setState(() {
        _statusMessage = '¡Listo!';
      });

      // Esperar un momento antes de navegar
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ChatScreen(gemmaService: _gemmaService),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _statusMessage = 'Error al inicializar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade700, Colors.blue.shade500],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cuate',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Asistente Visual con IA',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 60),
                  if (!_hasError) ...[
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _downloadProgress = 0.0;
                        });
                        _initializeApp();
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
