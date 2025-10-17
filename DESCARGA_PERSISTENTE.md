# Sistema de Descarga Persistente

## Descripción General

Se ha implementado un sistema robusto de descarga persistente para el modelo Gemma que garantiza que la descarga continúe incluso si:

- Se pierde la conexión a internet
- La aplicación se cierra
- El dispositivo se reinicia
- Hay interrupciones temporales

## Características Principales

### 1. **Persistencia de Estado**
- El progreso de descarga se guarda automáticamente en SharedPreferences
- El ID de la tarea se mantiene para poder reanudar descargas interrumpidas
- La ruta del archivo descargado se guarda para verificación posterior

### 2. **Reintentos Automáticos**
- Configurado con 10 reintentos automáticos
- Espera inteligente entre reintentos
- Manejo de errores de red temporal

### 3. **Descarga en Segundo Plano**
- Usa `background_downloader` para descargas persistentes
- Continúa descargando aunque la app esté en segundo plano
- Compatible con Android e iOS

### 4. **Control Manual**
- Botón de **Pausar/Reanudar** para control del usuario
- Botón de **Cancelar** con confirmación
- Indicador de progreso en tiempo real

### 5. **Reanudación Automática**
- Al abrir la app, detecta descargas en progreso
- Restaura el progreso guardado
- Continúa desde donde se quedó

## Arquitectura

### Servicios Implementados

#### `ModelDownloadService`
Servicio dedicado a manejar la descarga del modelo con persistencia:

```dart
class ModelDownloadService {
  // Inicialización del servicio
  Future<void> initialize()
  
  // Verificar si está descargado
  Future<bool> isModelDownloaded()
  
  // Iniciar descarga con callbacks
  Future<void> downloadModel({
    required Function(double progress) onProgress,
    required Function(TaskStatus status) onStatusChange,
  })
  
  // Control de descarga
  Future<bool> pauseDownload()
  Future<bool> resumeDownload()
  Future<bool> cancelDownload()
}
```

#### `GemmaService` (Actualizado)
Integra el `ModelDownloadService` y maneja la IA:

```dart
class GemmaService {
  // Inicializar servicio de descarga
  Future<void> initializeDownloadService()
  
  // Descargar modelo con persistencia
  Future<void> downloadModel({...})
  
  // Instalar modelo desde archivo descargado
  Future<void> installModelFromFile()
  
  // Controles de descarga
  Future<bool> pauseDownload()
  Future<bool> resumeDownload()
  Future<bool> cancelDownload()
}
```

## Flujo de Descarga

1. **Inicio de la App** (`SplashScreen`)
   ```
   ├─ Inicializar servicio de descarga
   ├─ Verificar modelo descargado
   ├─ Si no está descargado:
   │  ├─ Restaurar progreso guardado
   │  ├─ Iniciar/continuar descarga
   │  └─ Mostrar controles (pausar/cancelar)
   └─ Si está descargado:
      ├─ Instalar modelo en flutter_gemma
      └─ Inicializar chat
   ```

2. **Durante la Descarga**
   ```
   ├─ Actualizar progreso en tiempo real
   ├─ Guardar estado cada actualización
   ├─ Mostrar estado actual
   └─ Permitir pausa/cancelación
   ```

3. **Manejo de Interrupciones**
   ```
   Conexión perdida →
   ├─ background_downloader intenta reintentar
   ├─ Estado se guarda automáticamente
   └─ Al reconectar, continúa descarga
   
   App cerrada →
   ├─ Descarga continúa en segundo plano
   └─ Al reabrir, restaura estado
   ```

## Estados de Descarga

El sistema maneja los siguientes estados (`TaskStatus`):

- **enqueued**: En cola para descarga
- **running**: Descargando activamente
- **paused**: Pausado por el usuario
- **waitingToRetry**: Esperando para reintentar después de un error
- **complete**: Descarga completada exitosamente
- **failed**: Fallo permanente
- **canceled**: Cancelado por el usuario
- **notFound**: Tarea no encontrada

## Almacenamiento Local

### Ubicación del Modelo
```
<ApplicationSupportDirectory>/models/gemma-3n-E4B-it-int4.task
```

### Datos en SharedPreferences
- `model_download_id`: ID de la tarea de descarga
- `model_download_progress`: Progreso actual (0.0 - 1.0)
- `model_path`: Ruta del archivo descargado
- `model_is_downloaded`: Bandera de descarga completa

## Configuración

### Variables Importantes en `ModelDownloadService`

```dart
static const String modelUrl = '...'; // URL de Hugging Face
static const String modelFilename = '...'; // Nombre del archivo
static const String huggingFaceToken = ''; // Token opcional
```

### Parámetros de Descarga

```dart
DownloadTask(
  retries: 10,              // Número de reintentos
  allowPause: true,         // Permitir pausar
  requiresWiFi: false,      // Descargar en cualquier red
  updates: Updates.statusAndProgress, // Recibir actualizaciones
)
```

## Uso

### Verificar si el Modelo Está Descargado

```dart
final gemmaService = GemmaService();
await gemmaService.initializeDownloadService();
final isDownloaded = await gemmaService.isModelDownloaded();
```

### Descargar el Modelo

```dart
await gemmaService.downloadModel(
  onProgress: (progress) {
    print('Progreso: ${(progress * 100).toInt()}%');
  },
  onStatusChange: (status) {
    print('Estado: $status');
  },
);
```

### Pausar/Reanudar

```dart
// Pausar
await gemmaService.pauseDownload();

// Reanudar
await gemmaService.resumeDownload();
```

### Cancelar

```dart
await gemmaService.cancelDownload();
```

## Beneficios

✅ **Confiabilidad**: Descarga completada incluso con conexión inestable  
✅ **Experiencia de Usuario**: Control total sobre la descarga  
✅ **Eficiencia**: No recomienza desde cero  
✅ **Persistencia**: Sobrevive a cierres de app y reinicios  
✅ **Transparencia**: Feedback en tiempo real del progreso  

## Consideraciones

- El modelo tiene un tamaño considerable (~3.8GB), por lo que la descarga puede tardar
- Se recomienda descargar con WiFi para ahorrar datos móviles
- El espacio de almacenamiento debe ser suficiente antes de iniciar
- Los reintentos automáticos ayudan con conexiones inestables

## Permisos Necesarios

### Android
El paquete `background_downloader` maneja automáticamente los permisos necesarios.

### iOS
No se requieren permisos adicionales para descargas en segundo plano.

## Troubleshooting

### La descarga no continúa después de cerrar la app
- Verificar que el servicio se inicialice correctamente
- Revisar que no se hayan limpiado los datos de la app

### La descarga falla repetidamente
- Verificar conexión a internet
- Verificar espacio de almacenamiento disponible
- Revisar que la URL del modelo sea correcta
- Verificar token de Hugging Face si es necesario

### El modelo no se instala después de descargar
- Verificar que el archivo existe en la ruta guardada
- Revisar logs de flutter_gemma
- Intentar reinstalar el modelo

## Próximas Mejoras

- [ ] Notificaciones push cuando la descarga se complete
- [ ] Opción de descargar solo en WiFi
- [ ] Estimación de tiempo restante
- [ ] Velocidad de descarga en tiempo real
- [ ] Compresión del modelo para reducir tamaño
