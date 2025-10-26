// Stub for web platform - FFI not available on web
export 'llama_ffi_stub.dart'
  if (dart.library.ffi) 'llama_ffi_native.dart';
