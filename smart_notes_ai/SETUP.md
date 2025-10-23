# Smart Notes AI - Setup Guide

## 🚀 Quick Start

### 1. Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** 3.16.0 or higher
- **Dart SDK** 3.2.0 or higher
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **Git**
- At least **5GB free disk space** (for model and dependencies)

### 2. Clone and Install Dependencies

```bash
# Clone the repository
git clone <your-repo-url>
cd smart_notes_ai

# Install Flutter dependencies
flutter pub get

# Verify Flutter installation
flutter doctor -v
```

### 3. Download AI Model

The app requires a quantized LLM model for on-device AI features.

#### Option A: Phi-3-mini (Recommended)

```bash
# Create models directory
mkdir -p assets/models

# Download Phi-3-mini Q4_K_M quantized model (~2.3GB)
cd assets/models
wget https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf -O phi-3-mini.Q4_K_M.gguf
```

#### Option B: Llama-3.2 1B (Lightweight alternative)

```bash
cd assets/models
wget https://huggingface.co/QuantFactory/Meta-Llama-3.2-1B-Instruct-GGUF/resolve/main/Meta-Llama-3.2-1B-Instruct.Q4_K_M.gguf -O llama-3.2-1b.Q4_K_M.gguf
```

### 4. Build llama.cpp Native Libraries

#### Android

```bash
# Install Android NDK if not already installed
# Set ANDROID_NDK environment variable

# Clone llama.cpp
git clone https://github.com/ggerganov/llama.cpp.git native/llama.cpp
cd native/llama.cpp

# Build for Android ARM64
mkdir build-android && cd build-android
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DLLAMA_BUILD_EXAMPLES=OFF

make -j4

# Copy library to Android jniLibs
mkdir -p ../../../android/app/src/main/jniLibs/arm64-v8a
cp libllama.so ../../../android/app/src/main/jniLibs/arm64-v8a/

# Also build for other ABIs if needed (armeabi-v7a, x86_64)
```

#### iOS

```bash
cd native/llama.cpp

# Build for iOS
mkdir build-ios && cd build-ios
cmake .. \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DLLAMA_BUILD_EXAMPLES=OFF

make -j4

# Create iOS framework
# TODO: Package as .framework or .xcframework
```

### 5. Generate Database Code

The app uses Drift for database management with code generation:

```bash
# Generate database files
dart run build_runner build --delete-conflicting-outputs
```

### 6. Run the App

#### Android

```bash
# List available devices
flutter devices

# Run on connected device/emulator
flutter run --release

# Or specific device
flutter run -d <device-id> --release
```

#### iOS

```bash
# Open iOS project in Xcode (optional)
open ios/Runner.xcworkspace

# Run on simulator/device
flutter run -d <device-id> --release
```

## 🔧 Configuration

### Model Selection

Edit `lib/native/llama_ffi.dart` to change the model:

```dart
Future<String> _getModelPath() async {
  final appDir = await getApplicationDocumentsDirectory();
  // Change filename to use different model
  final modelPath = p.join(appDir.path, 'models', 'phi-3-mini.Q4_K_M.gguf');
  return modelPath;
}
```

### Database Location

The SQLite database is stored in the app's documents directory:
- Android: `/data/data/com.yourapp.smart_notes_ai/files/smart_notes.db`
- iOS: `~/Library/Application Support/smart_notes.db`

### Encryption Settings

Edit `lib/services/encryption/encryption_service.dart` to adjust encryption parameters:

```dart
// Change key size (128, 192, or 256 bits)
_masterKey = encrypt.Key.fromSecureRandom(32); // 32 bytes = 256 bits

// Adjust PBKDF2 iterations
Future<encrypt.Key> deriveKeyFromPassword(
  String password,
  String salt, {
  int iterations = 10000, // Increase for more security
})
```

## 🧪 Testing

### Unit Tests

```bash
flutter test
```

### Integration Tests

```bash
flutter test integration_test
```

### Performance Testing

```bash
# Run with performance profiling
flutter run --profile --trace-skia
```

## 📦 Building for Production

### Android APK

```bash
# Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)

```bash
# Build App Bundle
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS IPA

```bash
# Build for App Store
flutter build ios --release

# Archive in Xcode
open ios/Runner.xcworkspace
# Product > Archive
```

## 🐛 Troubleshooting

### Model Not Found Error

```
Error: Model file not found at: /path/to/model.gguf
```

**Solution**: Ensure the model is downloaded and placed in `assets/models/` directory.

### llama.cpp Library Not Found

```
Error: Failed to load dynamic library 'libllama.so'
```

**Solution**: Rebuild llama.cpp native libraries and ensure they're in the correct directory.

### Database Migration Errors

```
Error: Migration failed
```

**Solution**: Clear app data or uninstall/reinstall during development:
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Notification Permission Denied

**Android**: Check `AndroidManifest.xml` for notification permissions.
**iOS**: Check Info.plist for notification usage description.

### Slow AI Performance

**Solutions**:
1. Use a smaller model (Llama-3.2 1B instead of Phi-3-mini)
2. Reduce `maxTokens` parameter in AI service calls
3. Increase quantization (Q2_K instead of Q4_K_M)
4. Test on physical device instead of emulator

## 📱 App Size Optimization

### Reduce APK Size

```bash
# Build split APKs per ABI
flutter build apk --split-per-abi --release

# This creates separate APKs:
# - app-armeabi-v7a-release.apk (~50MB)
# - app-arm64-v8a-release.apk (~55MB)
# - app-x86_64-release.apk (~60MB)
```

### Model Compression

Consider using more aggressive quantization:
- Q4_K_M: ~2.3GB (current)
- Q3_K_M: ~1.8GB (smaller, less accurate)
- Q2_K: ~1.2GB (smallest, lowest quality)

## 🔐 Security Checklist

Before releasing:

- [ ] Remove all debug logs
- [ ] Enable ProGuard/R8 obfuscation (Android)
- [ ] Remove test credentials
- [ ] Verify encryption is working
- [ ] Test biometric authentication
- [ ] Review network permissions (should be none!)
- [ ] Test on clean device
- [ ] Verify no data leaks

## 📊 Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| App Launch | < 2s | Cold start |
| Note Creation | < 100ms | Without AI |
| AI Summarization | < 5s | Phi-3-mini on mid-range device |
| Search Query | < 1s | Full-text search |
| Database Query | < 50ms | Typical query |
| Memory Usage | < 500MB | Without AI model loaded |
| APK Size | < 100MB | With model, per ABI |

## 🆘 Support

For issues and questions:

1. Check this guide first
2. Review [Flutter documentation](https://flutter.dev/docs)
3. Check [llama.cpp issues](https://github.com/ggerganov/llama.cpp/issues)
4. Review Drift database docs

## 📚 Additional Resources

- [Flutter Best Practices](https://flutter.dev/docs/development/ui/layout/best-practices)
- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)
- [Drift Database Guide](https://drift.simonbinder.eu/docs/getting-started/)
- [Android App Security](https://developer.android.com/topic/security/best-practices)
- [iOS Security](https://developer.apple.com/security/)
