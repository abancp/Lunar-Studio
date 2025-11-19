// lib/src/ffi/llm_worker.dart

import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

typedef NativeLoadLLM = Void Function();
typedef NativeGenerateFn = Void Function(
  Pointer<Utf8>,
  Pointer<NativeFunction<NativeTokenCallback>>,
);
typedef NativeTokenCallback = Void Function(Pointer<Utf8>);

late DynamicLibrary _lib;
late void Function() _load;
late void Function(
  Pointer<Utf8>,
  Pointer<NativeFunction<NativeTokenCallback>>,
) _gen;

SendPort? _currentReplyPort;
int _currentId = -1;

// Pre-allocated callback pointer (avoid re-creating on each call)
late Pointer<NativeFunction<NativeTokenCallback>> _callbackPtr;

void _tokenTrampoline(Pointer<Utf8> ptr) {
  final tok = ptr.toDartString();
  _currentReplyPort?.send({
    'cmd': 'token',
    'id': _currentId,
    'token': tok,
  });
}

void llmWorkerEntry(SendPort engineSendPort) async {
  final port = ReceivePort();
  engineSendPort.send(port.sendPort);

  // Pre-allocate callback pointer once
  _callbackPtr = Pointer.fromFunction<NativeTokenCallback>(_tokenTrampoline);

  await for (final msg in port) {
    final cmd = msg['cmd'];

    if (cmd == 'init') {
      final libPath = msg['path'] as String;
      final replyPort = msg['reply'] as SendPort;

      try {
        _lib = DynamicLibrary.open(libPath);
        _load = _lib.lookup<NativeFunction<NativeLoadLLM>>("load_llm").asFunction();
        _gen = _lib.lookup<NativeFunction<NativeGenerateFn>>("generate").asFunction();
        _load();
        replyPort.send({'cmd': 'ready'});
      } catch (e, st) {
        replyPort.send({'cmd': 'error', 'error': '$e\n$st'});
      }
    }

    if (cmd == 'generate') {
      _currentId = msg['id'] as int;
      _currentReplyPort = msg['reply'] as SendPort;

      final prompt = msg['prompt'] as String;
      final p = prompt.toNativeUtf8();

      try {
        _gen(p, _callbackPtr);  // Reuse pre-allocated callback
      } catch (e) {
        // Silent error handling, send error token if needed
      }

      malloc.free(p);

      _currentReplyPort!.send({'cmd': 'done', 'id': _currentId});
      _currentReplyPort = null;
    }
  }
}