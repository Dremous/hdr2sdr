import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/convert_provider.dart';

class PreviewPanel extends StatelessWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConvertProvider>(
      builder: (context, provider, _) {
        final frame = provider.previewFrame;
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: frame != null
              ? Image.memory(
                  frame,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.movie_outlined,
                          size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 12),
                      Text('预览功能待实现',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
