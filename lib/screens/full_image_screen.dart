// lib/screens/full_image_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';

class FullImageScreen extends StatelessWidget {
  // 보여줄 사진 파일
  final File imageFile;

  const FullImageScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 뒤로가기 버튼이 있는 간단한 앱바
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // 아이콘 색상을 흰색으로
      ),
      // 배경을 검은색으로 설정
      backgroundColor: Colors.black,
      // 사진을 화면 중앙에 표시
      body: Center(
        // InteractiveViewer를 사용하여 사진 확대/축소/이동 가능하게 함
        child: InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(20.0),
          minScale: 0.1,
          maxScale: 4.0,
          child: Image.file(imageFile),
        ),
      ),
    );
  }
}
