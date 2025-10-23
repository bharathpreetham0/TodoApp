#!/bin/bash

# Smart Notes AI - Quick Start Script
# This script helps you get started with development

set -e

echo "🧠 Smart Notes AI - Development Setup"
echo "======================================"
echo ""

# Check Flutter installation
echo "📱 Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    exit 1
fi

flutter --version
echo "✅ Flutter found"
echo ""

# Check Dart
echo "🎯 Checking Dart installation..."
if ! command -v dart &> /dev/null; then
    echo "❌ Dart is not installed"
    exit 1
fi

dart --version
echo "✅ Dart found"
echo ""

# Install dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Run Flutter doctor
echo "🔍 Running Flutter doctor..."
flutter doctor
echo ""

# Generate database code
echo "🗄️  Generating database code..."
dart run build_runner build --delete-conflicting-outputs
echo "✅ Database code generated"
echo ""

# Check for AI model
echo "🤖 Checking for AI model..."
if [ ! -f "assets/models/phi-3-mini.Q4_K_M.gguf" ]; then
    echo "⚠️  AI model not found!"
    echo ""
    echo "To download the model (~2.3GB), run:"
    echo "  mkdir -p assets/models"
    echo "  cd assets/models"
    echo "  wget https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf -O phi-3-mini.Q4_K_M.gguf"
    echo ""
else
    echo "✅ AI model found"
fi
echo ""

# Check for llama.cpp
echo "🔧 Checking for llama.cpp..."
if [ ! -d "native/llama.cpp" ]; then
    echo "⚠️  llama.cpp not found!"
    echo ""
    echo "To clone llama.cpp, run:"
    echo "  git clone https://github.com/ggerganov/llama.cpp.git native/llama.cpp"
    echo ""
    echo "Then build native libraries following SETUP.md"
    echo ""
else
    echo "✅ llama.cpp found"
fi
echo ""

# Summary
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo "1. Download the AI model (if not already done)"
echo "2. Build llama.cpp native libraries (see SETUP.md)"
echo "3. Run the app: flutter run"
echo ""
echo "For detailed instructions, see:"
echo "  - SETUP.md for installation"
echo "  - DEVELOPMENT.md for development guide"
echo "  - README.md for project overview"
echo ""
echo "Happy coding! 🚀"
