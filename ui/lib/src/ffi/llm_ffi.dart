import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

typedef NativeLoadLLM = Void Function();
typedef NativeGenerate = Void Function(
  Pointer<Utf8>,
  Pointer<NativeFunction<NativeCallback>>,
);
typedef NativeCallback = Void Function(Pointer<Utf8>);

late DynamicLibrary _lib;
late void Function() _loadLLM;
late void Function(
  Pointer<Utf8>,
  Pointer<NativeFunction<NativeCallback>>,
) _generate;

late SendPort _mainSend;

int _activeId = -1;

void _tokenTrampoline(Pointer<Utf8> ptr) {
  final token = ptr.toDartString();
  _mainSend.send({
    'cmd': 'token',
    'id': _activeId,
    'token': token,
  });
}

void workerMain(SendPort mainSend) async {
  _mainSend = mainSend;

  final receive = ReceivePort();
  mainSend.send(receive.sendPort);

  final cbPtr = Pointer.fromFunction<NativeCallback>(_tokenTrampoline);

  await for (final msg in receive) {
    final cmd = msg['cmd'];

    if (cmd == 'init') {
      final path = msg['path'] as String;
      _lib = DynamicLibrary.open(path);

      _loadLLM = _lib
          .lookup<NativeFunction<NativeLoadLLM>>("load_llm")
          .asFunction();
      _generate = _lib
          .lookup<NativeFunction<NativeGenerate>>("generate")
          .asFunction();

      _loadLLM();
      mainSend.send({'cmd': 'ready'});
    }

    else if (cmd == 'generate') {
      final id = msg['id'] as int;
      final prompt = msg['prompt'] as String;
      _activeId = id;

      final p = prompt.toNativeUtf8();
      _generate(p, cbPtr);
      malloc.free(p);

      mainSend.send({'cmd': 'done', 'id': id});
      _activeId = -1;
    }
  }
}
