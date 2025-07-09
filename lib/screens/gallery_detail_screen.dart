// lib/screens/gallery_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:test/models/photo_item.dart';

class GalleryDetailScreen extends StatelessWidget {
  final String tag; // 그룹의 태그 이름 (예: "고양이")
  final List<PhotoItem> photos; // 해당 그룹의 사진 목록

  const GalleryDetailScreen({
    super.key,
    required this.tag,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tag), // 앱바에 태그 이름 표시
      ),
      // 사진들을 격자 형태로 보여주는 GridView
      body: GridView.builder(
        padding: const EdgeInsets.all(8.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 한 줄에 2개의 이미지 표시
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.0),
            child: Image.file(photo.imageFile, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}
