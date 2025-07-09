import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:test/models/photo_item.dart';
import 'package:test/screens/gallery_detail_screen.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isLoading = false;
  final Map<String, List<PhotoItem>> _groupedPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _downloadAndExtractModel() async {
    const zipUrl = 'http://192.168.18.124:8000/download-model/'; // 실제 주소로 바꿔야 함

    try {
      final response = await http.get(Uri.parse(zipUrl));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final zipPath = '${dir.path}/mobilenet.zip';
        final zipFile = File(zipPath);
        await zipFile.writeAsBytes(response.bodyBytes);

        // 압축 해제
        final bytes = zipFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);

        for (final file in archive) {
          final filename = file.name;
          final outFile = File('${dir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }

        print("✅ 모델 다운로드 및 압축 해제 완료");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('모델 다운로드 및 압축 해제 완료')));

        // 모델 다시 로딩 시도
        await _loadModel();
      } else {
        throw Exception("서버 오류: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ 다운로드 실패: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모델 다운로드 실패')));
    }
  }

  Future<void> _loadModel() async {
    setState(() => _isLoading = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/mobilenet.tflite');

      if (!await modelFile.exists()) {
        throw Exception("모델 파일 없음. 다운로드 버튼을 눌러주세요.");
      }

      _interpreter = await Interpreter.fromFile(modelFile);

      // labels.txt는 assets에서 로딩 (또는 zip에 포함할 수도 있음)
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.split('\n');
    } catch (e) {
      print("모델 로딩 실패: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모델 로딩 실패')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAnalyzeImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    setState(() => _isLoading = true);

    for (var file in pickedFiles) {
      final imageFile = File(file.path);
      await _predict(imageFile);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _predict(File imageFile) async {
    if (_interpreter == null || _labels == null) return;

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];

    final image = img.decodeImage(await imageFile.readAsBytes())!;
    final resizedImage = img.copyResize(
      image,
      width: inputWidth,
      height: inputHeight,
    );
    final imageBytes = resizedImage.getBytes();
    final float32Bytes = Float32List(1 * inputWidth * inputHeight * 3);

    int bufferIndex = 0;
    for (int i = 0; i < imageBytes.length; i += 3) {
      float32Bytes[bufferIndex++] = (imageBytes[i] - 127.5) / 127.5;
      float32Bytes[bufferIndex++] = (imageBytes[i + 1] - 127.5) / 127.5;
      float32Bytes[bufferIndex++] = (imageBytes[i + 2] - 127.5) / 127.5;
    }

    final inputBuffer = float32Bytes.reshape(inputShape);
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outputBuffer = List.filled(
      outputShape[0] * outputShape[1],
      0.0,
    ).reshape(outputShape);

    _interpreter!.run(inputBuffer, outputBuffer);

    final outputList = outputBuffer[0] as List<double>;
    double maxScore = 0;
    int maxIndex = -1;
    for (int i = 0; i < outputList.length; i++) {
      if (outputList[i] > maxScore) {
        maxScore = outputList[i];
        maxIndex = i;
      }
    }

    final newPhoto = PhotoItem(
      imageFile: imageFile,
      bestTag: _labels![maxIndex],
      confidence: maxScore,
    );

    setState(() {
      _groupedPhotos.putIfAbsent(newPhoto.bestTag, () => []).add(newPhoto);
    });
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedTags = _groupedPhotos.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('IntelliGallery'), centerTitle: true),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _groupedPhotos.isEmpty
            ? const Text(
                '아래 버튼을 눌러 사진들을 선택하세요.',
                style: TextStyle(fontSize: 18),
              )
            : ListView.builder(
                itemCount: sortedTags.length,
                itemBuilder: (context, index) {
                  final tag = sortedTags[index];
                  final photos = _groupedPhotos[tag]!;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              GalleryDetailScreen(tag: tag, photos: photos),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, photoIndex) {
                              final photo = photos[photoIndex];
                              return Padding(
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: photoIndex == photos.length - 1
                                      ? 16
                                      : 0,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    photo.imageFile,
                                    width: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: _isLoading ? null : _pickAndAnalyzeImages,
            label: const Text('사진 추가'),
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _downloadAndExtractModel,
            label: const Text('모델 다운로드'),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
    );
  }
}
