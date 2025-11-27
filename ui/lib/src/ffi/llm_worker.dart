// lib/src/ffi/llm_worker.dart

import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart';

typedef NativeLoadLLM = Void Function(Pointer<Utf8>);
typedef DartLoadLLM = void Function(Pointer<Utf8>);

typedef NativeGenerateFn =
    Void Function(Pointer<Utf8>, Pointer<NativeFunction<NativeTokenCallback>>);
typedef DartGenerateFn =
    void Function(Pointer<Utf8>, Pointer<NativeFunction<NativeTokenCallback>>);

typedef NativeTokenCallback = Void Function(Pointer<Utf8>);

final class ChatEntryC extends Struct {
  external Pointer<Utf8> role;
  external Pointer<Utf8> message;
}

final class ChatArrayC extends Struct {
  external Pointer<ChatEntryC> items;

  @Uint64()
  external int size;
}

typedef NativeGetContext = ChatArrayC Function();
typedef DartGetContext = ChatArrayC Function();

typedef NativeFreeContext = Void Function(ChatArrayC);
typedef DartFreeContext = void Function(ChatArrayC);

late DynamicLibrary _lib;

late DartLoadLLM _load;
late DartGenerateFn _gen;

late DartGetContext _getContext;

SendPort? _currentReplyPort;
int _currentId = -1;

late Pointer<NativeFunction<NativeTokenCallback>> _callbackPtr;

void _tokenTrampoline(Pointer<Utf8> ptr) {
  final tok = ptr.toDartString();
  _currentReplyPort?.send({'cmd': 'token', 'id': _currentId, 'token': tok});
}

void llmWorkerEntry(SendPort engineSendPort) async {
  final port = ReceivePort();
  engineSendPort.send(port.sendPort);

  _callbackPtr = Pointer.fromFunction<NativeTokenCallback>(_tokenTrampoline);

  await for (final msg in port) {
    final cmd = msg['cmd'];

    if (cmd == 'init') {
      final replyPort = msg['reply'] as SendPort;
      final libPath = msg['path'] as String;

      try {
        _lib = DynamicLibrary.open(libPath);
        replyPort.send({'cmd': 'ready'});
      } catch (e, st) {
        replyPort.send({'cmd': 'error', 'error': '$e\n$st'});
      }
    }

    if (cmd == 'load') {
      final replyPort = msg['reply'] as SendPort;
      final modelPath = msg['path'] as String;

      try {
        _load = _lib
            .lookup<NativeFunction<NativeLoadLLM>>('load_llm')
            .asFunction();
        _gen = _lib
            .lookup<NativeFunction<NativeGenerateFn>>('generate')
            .asFunction();

        // Look up context functions
        _getContext = _lib
            .lookup<NativeFunction<NativeGetContext>>('get_context_c')
            .asFunction();
        // _freeContext = _lib
        //     .lookup<NativeFunction<NativeFreeContext>>('free_context_c')
        //     .asFunction();

        _load(modelPath.toNativeUtf8());
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
        _gen(p, _callbackPtr);
      } catch (_) {}

      malloc.free(p);

      _currentReplyPort!.send({'cmd': 'done', 'id': _currentId});
      _currentReplyPort = null;
    }

    if (cmd == 'get_context') {
      final replyPort = msg['reply'] as SendPort;
      final reqId = msg['id'];

      ChatArrayC ctx;
      try {
        ctx = _getContext();
      } catch (e, st) {
        replyPort.send({
          'cmd': 'error',
          'error': 'get_context_c failed: $e\n$st',
        });
        continue;
      }

      final count = ctx.size;
      final ptr = ctx.items;
      final List<Map<String, String>> result = [];

      try {
        for (int i = 0; i < count; i++) {
          final entry = ptr.elementAt(i).ref;

          final rolePtr = entry.role;
          final msgPtr = entry.message;

          final role = rolePtr == nullptr ? '' : rolePtr.toDartString();
          final message = msgPtr == nullptr ? '' : msgPtr.toDartString();

          result.add({'role': role, 'message': message});
        }
      } catch (e, st) {
        // try {
        //   // _freeContext(ctx);
        // } catch (_) {}
        debugPrint(e.toString());
        debugPrint(st.toString());
        replyPort.send({
          'cmd': 'error',
          'error': 'context conversion failed: $e\n$st',
        });
        continue;
      }

      // Free native memory
      // try {
      //   // _freeContext(ctx);
      // } catch (e) {}

      replyPort.send({'cmd': 'context', 'id': reqId, 'context': result});
    }
  }
}
