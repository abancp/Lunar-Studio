import 'dart:ffi';
import 'dart:async';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

typedef NativeLoadLLM = Void Function();
typedef NativeGenerate = Void Function(
  Pointer<Utf8>,
  Pointer<NativeFunction<NativeCallback>>,
);

typedef NativeCallback = Void Function(Pointer<Utf8>);

class LLMEngine {
  static final LLMEngine _instance = LLMEngine._internal();
  factory LLMEngine() => _instance;
  LLMEngine._internal();

  late final DynamicLibrary _lib;

  late final void Function() _loadLLM;
  late final void Function(
    Pointer<Utf8>,
    Pointer<NativeFunction<NativeCallback>>,
  ) _generate;

  bool _loaded = false;
  bool _modelLoaded = false;

  void loadLibrary() {
    if (_loaded) return;

    _lib = DynamicLibrary.open("/home/abancp/Projects/localGPT1.0/ui/linux/lib/liblunarstudio.so");

    _loadLLM = _lib
        .lookup<NativeFunction<NativeLoadLLM>>("load_llm")
        .asFunction();

    _generate = _lib
        .lookup<NativeFunction<NativeGenerate>>("generate")
        .asFunction();

    _loaded = true;
  }

  /// Call only once per session.
  void loadModel() {
    loadLibrary();
    if (_modelLoaded) return;
    _loadLLM();
    _modelLoaded = true;
  }

  /// Blocking call — run inside isolate only.
  void generate(String prompt, void Function(String tok) onToken) {
    loadModel(); // ensure model loaded first

    final p = prompt.toNativeUtf8();

    Zone.current.fork(zoneValues: {
      #cb: onToken,
    }).run(() {
      final cbPointer =
          Pointer.fromFunction<NativeCallback>(_tokenTrampoline);

      _generate(p, cbPointer);
    });

    malloc.free(p);
  }

  static void _tokenTrampoline(Pointer<Utf8> ptr) {
    final cb = Zone.current[#cb] as void Function(String);
    cb(ptr.toDartString());
  }
}
