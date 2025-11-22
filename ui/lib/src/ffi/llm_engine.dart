import 'dart:async';
import 'dart:isolate';
import 'package:flutter/cupertino.dart';

import 'llm_worker.dart';

class LLMEngine {
  static final LLMEngine _i = LLMEngine._internal();
  factory LLMEngine() => _i;
  static bool isModelLoaded = false;
  static bool modelLoading = false;
  LLMEngine._internal();

  late SendPort _workerSend;
  bool _ready = false;

  Future<void> init(String libpath) async {
    try {
      debugPrint("[Engine] : C++ Lib initing..");
      final rp = ReceivePort();
      await Isolate.spawn(llmWorkerEntry, rp.sendPort, debugName: "LLMWorker");
      _workerSend = await rp.first as SendPort;
      print("[Engine] Worker sendPort acquired.");

      final replyPort = ReceivePort();
      _workerSend.send({
        'cmd': 'init',
        'path': libpath,
        'reply': replyPort.sendPort,
      });

      await for (final msg in replyPort) {
        // print("[Engine] init message: $msg");
        if (msg["cmd"] == "ready") {
          print("[Library] READY ✔");
          _ready = true;
          replyPort.close();
          break;
        }
        if (msg["cmd"] == "error") {
          replyPort.close();
          throw Exception(msg["error"]);
        }
      }
    } catch (e) {
      debugPrint("Error while initing : $e");
    }
  }

  Future<void> load(String modelpath) async {
    try {
      debugPrint("Model Loading , already Loading : $modelLoading ");
      if (modelLoading) return;
      modelLoading = true;
      print("[Engine] Starting worker isolate...");
      // final rp = ReceivePort();
      // await Isolate.spawn(llmWorkerEntry, rp.sendPort, debugName: "LLMWorker");
      // _workerSend = await rp.first as SendPort;
      // print("[Engine] Worker sendPort acquired.");

      final replyPort = ReceivePort();
      _workerSend.send({
        'cmd': 'load',
        'path': modelpath,
        'reply': replyPort.sendPort,
      });

      await for (final msg in replyPort) {
        // print("[Engine] init message: $msg");
        if (msg["cmd"] == "ready") {
          print("[Engine] READY ✔");
          _ready = true;
          replyPort.close();
          break;
        }
        if (msg["cmd"] == "error") {
          replyPort.close();
          throw Exception(msg["error"]);
        }
      }
      isModelLoaded = true;
    } catch (e) {
      debugPrint("Error while loading model : $e");
    } finally {
      modelLoading = false;
    }
  }

  Future<void> generate(
    String prompt,
    void Function(String tok) onToken,
  ) async {
    debugPrint(
      "Engine Ready : $_ready \n isModelLoaded $isModelLoaded \n Model Loading : $modelLoading",
    );
    if (!_ready || !isModelLoaded || modelLoading) {
      throw StateError("Engine not ready");
    }
    // print("[Engine] generate() → $prompt");

    final id = DateTime.now().microsecondsSinceEpoch;
    final rp = ReceivePort();

    late StreamSubscription sub;
    sub = rp.listen((msg) {
      // print("[Engine] Received: $msg");
      final cmd = msg["cmd"];

      if (cmd == "token" && msg["id"] == id) {
        // print("[Engine] Token: '${msg["token"]}'");
        onToken(msg["token"]);
      }

      if (cmd == "done" && msg["id"] == id) {
        // print("[Engine] DONE id=$id");
        sub.cancel();
        rp.close();
      }
    });

    _workerSend.send({
      'cmd': 'generate',
      'id': id,
      'prompt': prompt,
      'reply': rp.sendPort, // ← KEY: pass the reply port
    });
  }
}
