// lib/models/photo_item.dart

import 'dart:io';

class PhotoItem {
  final File imageFile; // 사진 파일
  final String bestTag; // 가장 확률이 높은 태그
  final double confidence; // 해당 태그의 신뢰도

  PhotoItem({
    required this.imageFile,
    required this.bestTag,
    required this.confidence,
  });
}
