/// SenseVoice 模型下载管理器
/// 从 HuggingFace 下载 model.onnx (~90MB) + tokens.txt
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ModelStatus { notDownloaded, downloading, ready, error }

class ModelManager extends ChangeNotifier {
  ModelManager._singleton();
  static final ModelManager I = ModelManager._singleton();

  ModelStatus _status = ModelStatus.notDownloaded;
  double _progress = 0;
  String _err = '';
  String _modelDir = '';

  ModelStatus get status => _status;
  double get progress => _progress;
  String get error => _err;
  String get modelDir => _modelDir;

  Future<void> init() async {
    _modelDir = '${(await getApplicationDocumentsDirectory()).path}/sherpa-models/sense-voice';
    if (File('$_modelDir/model.onnx').existsSync()) {
      _status = ModelStatus.ready; notifyListeners();
    }
  }

  Future<void> download() async {
    if (_status == ModelStatus.downloading) return;
    _status = ModelStatus.downloading; _progress = 0; _err = ''; notifyListeners();

    try {
      final dir = Directory(_modelDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      // tokens.txt (~1KB)
      await _downloadFile(
        'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt',
        '$_modelDir/tokens.txt',
      );

      // model.onnx (~90MB)
      await _downloadFile(
        'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.onnx',
        '$_modelDir/model.onnx',
        isLarge: true,
      );

      _status = ModelStatus.ready; _progress = 1; notifyListeners();
      debugPrint('SenseVoice 模型下载完成');
    } catch (e) {
      _status = ModelStatus.error; _err = e.toString(); notifyListeners();
      debugPrint('模型下载失败: $e');
    }
  }

  Future<void> _downloadFile(String url, String path, {bool isLarge = false}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();

      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');

      final file = File(path);
      final sink = file.openWrite();
      int total = 0, downloaded = 0;

      if (isLarge) {
        final len = resp.contentLength;
        await for (final chunk in resp) {
          sink.add(chunk); downloaded += chunk.length;
          if (len > 0) { _progress = downloaded / len; notifyListeners(); }
        }
      } else {
        await sink.addStream(resp);
      }
      await sink.close();
    } finally { client.close(); }
  }
}
