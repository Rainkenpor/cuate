import 'package:flutter/material.dart';
import 'package:background_downloader/background_downloader.dart';
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
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _statusMessage = 'Inicializando servicio de descarga...';
      });

      // Inicializar el servicio de descarga
      await _gemmaService.initializeDownloadService();

      setState(() {
        _statusMessage = 'Verificando modelo...';
      });

      // Verificar el progreso guardado
      final savedProgress = await _gemmaService.getDownloadProgress();
      if (savedProgress > 0) {
        setState(() {
          _downloadProgress = savedProgress;
        });
      }

      final isDownloaded = await _gemmaService.isModelDownloaded();

      if (!isDownloaded) {
        setState(() {
          _statusMessage = 'Descargando modelo de IA...';
        });

        // Iniciar descarga con soporte de persistencia
        await _gemmaService.downloadModel(
          onProgress: (progress) {
            setState(() {
              _downloadProgress = progress;
            });
          },
          onStatusChange: (status) {
            setState(() {
              _updateStatusMessage(status);
            });

            // Si la descarga se completa, instalar el modelo
            if (status == TaskStatus.complete) {
              _installAndInitialize();
            }
          },
        );
      } else {
        setState(() {
          _downloadProgress = 1.0;
          _statusMessage = 'Modelo ya descargado';
        });
        await _initializeChat();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _statusMessage = 'Error al inicializar';
      });
    }
  }

  void _updateStatusMessage(TaskStatus status) {
    switch (status) {
      case TaskStatus.enqueued:
        _statusMessage = 'Descarga en cola...';
        break;
      case TaskStatus.running:
        _statusMessage = 'Descargando modelo de IA...';
        _isPaused = false;
        break;
      case TaskStatus.complete:
        _statusMessage = 'Descarga completada';
        break;
      case TaskStatus.failed:
        _statusMessage = 'Error en la descarga';
        _hasError = true;
        break;
      case TaskStatus.paused:
        _statusMessage = 'Descarga pausada';
        _isPaused = true;
        break;
      case TaskStatus.canceled:
        _statusMessage = 'Descarga cancelada';
        break;
      case TaskStatus.waitingToRetry:
        _statusMessage = 'Reintentando descarga...';
        break;
      case TaskStatus.notFound:
        _statusMessage = 'Descarga no encontrada';
        break;
    }
  }

  Future<void> _installAndInitialize() async {
    try {
      setState(() {
        _statusMessage = 'Instalando modelo...';
      });

      await _gemmaService.installModelFromFile();
      await _initializeChat();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _statusMessage = 'Error al instalar el modelo';
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
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
        _statusMessage = 'Error al inicializar el chat';
      });
    }
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      final success = await _gemmaService.resumeDownload();
      if (success) {
        setState(() {
          _isPaused = false;
          _statusMessage = 'Reanudando descarga...';
        });
      }
    } else {
      final success = await _gemmaService.pauseDownload();
      if (success) {
        setState(() {
          _isPaused = true;
          _statusMessage = 'Descarga pausada';
        });
      }
    }
  }

  Future<void> _cancelDownload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar descarga'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar la descarga? '
          'Perderás el progreso actual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _gemmaService.cancelDownload();
      setState(() {
        _downloadProgress = 0.0;
        _statusMessage = 'Descarga cancelada';
        _hasError = true;
        _errorMessage = 'La descarga fue cancelada por el usuario';
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
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          // Mostrar botones solo durante la descarga
                          if (_downloadProgress > 0 &&
                              _downloadProgress < 1.0) ...[
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _togglePause,
                                  icon: Icon(
                                    _isPaused ? Icons.play_arrow : Icons.pause,
                                  ),
                                  label: Text(
                                    _isPaused ? 'Reanudar' : 'Pausar',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.purple.shade700,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: _cancelDownload,
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('Cancelar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'La descarga continuará aunque pierdas conexión',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
