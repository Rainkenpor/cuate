# Instrucciones de Configuración - Cuate

## Configuración Completa para Android e iOS

### Android

#### 1. Actualizar minSdk
El archivo ya está configurado, pero verifica que en `android/app/build.gradle.kts`:
```kotlin
minSdk = 26
```

#### 2. Permisos
Los permisos ya están agregados en `android/app/src/main/AndroidManifest.xml`.

#### 3. Compilar para Android
```bash
flutter build apk
# o para release
flutter build apk --release
```

### iOS

#### 1. Actualizar versión mínima de iOS
Edita `ios/Podfile` y asegúrate de tener:
```ruby
platform :ios, '15.0'
```

#### 2. Instalar pods
```bash
cd ios
pod install
cd ..
```

#### 3. Permisos
Los permisos ya están agregados en `ios/Runner/Info.plist`.

#### 4. Compilar para iOS
```bash
flutter build ios
```

## Primera Ejecución

### Descarga del Modelo

En la primera ejecución, la app descargará el modelo Gemma 3 Nano:
- **Tamaño**: ~6.5 GB
- **Tiempo estimado**: 10-30 minutos (dependiendo de la conexión)
- **Progreso**: Se muestra una barra de progreso en la pantalla

**IMPORTANTE**: Asegúrate de tener:
- ✅ Conexión a Internet estable
- ✅ Al menos 7 GB de espacio libre
- ✅ El dispositivo conectado a WiFi (recomendado)
- ✅ Batería suficiente o dispositivo conectado a la corriente

### ¿Qué pasa si la descarga falla?

Si la descarga se interrumpe:
1. La app mostrará un botón "Reintentar"
2. Puedes cerrar y volver a abrir la app
3. La descarga se reanudará automáticamente

## Solución de Problemas

### Error: "No se pudo inicializar el modelo"

**Causa**: El modelo no se descargó correctamente o está corrupto.

**Solución**:
1. Desinstala la app
2. Vuelve a instalarla
3. Asegúrate de tener una buena conexión a Internet

### Error: "No se puede acceder a la cámara/micrófono"

**Causa**: No se otorgaron los permisos necesarios.

**Solución en Android**:
1. Ve a Configuración > Aplicaciones > Cuate
2. Permisos
3. Activa Cámara, Micrófono, Almacenamiento

**Solución en iOS**:
1. Ve a Configuración > Cuate
2. Activa todos los permisos necesarios

### El reconocimiento de voz no funciona

**Causa**: El servicio de reconocimiento de voz no está disponible o configurado.

**Solución en Android**:
- Asegúrate de tener Google app instalada y actualizada
- Ve a Configuración > Apps > Google > Permisos > Micrófono (activar)

**Solución en iOS**:
- Ve a Configuración > General > Teclado > Dictado (activar)
- Otorga permisos de micrófono a la app

### La app es muy lenta

**Causas posibles**:
- Dispositivo con poca RAM (< 4 GB)
- Muchas apps abiertas en segundo plano
- Primer uso (el modelo se está cargando en memoria)

**Soluciones**:
1. Cierra otras aplicaciones
2. Reinicia el dispositivo
3. Espera unos segundos después de abrir la app
4. Considera usar un dispositivo con más RAM

### La síntesis de voz no suena

**Solución en Android**:
1. Ve a Configuración > Accesibilidad > Salida de texto a voz
2. Asegúrate de que haya un motor TTS instalado (Google Text-to-Speech)
3. Descarga voces en español si no están instaladas

**Solución en iOS**:
1. Ve a Configuración > Accesibilidad > Contenido Hablado
2. Activa "Hablar Selección" y "Hablar Pantalla"
3. Descarga voces en español si no están disponibles

## Comandos Útiles

### Limpiar y reconstruir el proyecto
```bash
flutter clean
flutter pub get
flutter run
```

### Ver logs en tiempo real
```bash
# Android
flutter logs

# O específicamente:
adb logcat | grep Flutter
```

### Verificar dependencias
```bash
flutter pub outdated
flutter pub upgrade
```

### Compilar versión de release
```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Verificar la Instalación

Ejecuta estos comandos para verificar que todo está correctamente configurado:

```bash
# Verificar Flutter
flutter doctor -v

# Verificar dependencias
flutter pub get

# Analizar el código
flutter analyze

# Ejecutar tests (si los hay)
flutter test
```

## Recursos Adicionales

- **Documentación de Flutter**: https://flutter.dev/docs
- **flutter_gemma**: https://pub.dev/packages/flutter_gemma
- **Gemma AI**: https://ai.google.dev/gemma
- **Artículo base**: https://medium.com/@vogelcsongorbenedek/using-gemma-for-flutter-apps-91f746e3347c

## Soporte

Si encuentras problemas que no puedes resolver:
1. Revisa los issues en el repositorio de GitHub
2. Abre un nuevo issue con:
   - Descripción detallada del problema
   - Logs de error
   - Versión de Flutter y Dart
   - Modelo de dispositivo
   - Pasos para reproducir el error

## Notas de Desarrollo

### Estructura del Proyecto
```
lib/
├── main.dart                 # Punto de entrada
├── models/                   # Modelos de datos
├── screens/                  # Pantallas de la UI
└── services/                 # Lógica de negocio
    ├── gemma_service.dart   # IA
    └── speech_service.dart  # Voz
```

### Próximos Pasos de Desarrollo
Si quieres contribuir o extender la funcionalidad:

1. **Agregar más idiomas**: Edita `speech_service.dart` líneas 12 y 75
2. **Cambiar el modelo**: Edita `gemma_service.dart` línea 5-6
3. **Personalizar UI**: Edita los archivos en `screens/`
4. **Agregar persistencia**: Considera usar `sqflite` o `hive`

---

**¡Disfruta usando Cuate! 🎉**
