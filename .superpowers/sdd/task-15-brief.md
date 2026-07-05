### Task 15: Flutter UI �?预览面板

**Files:**
- Create: `lib/pages/preview_panel.dart`

- [ ] **Step 1: 创建 lib/pages/preview_panel.dart`

```dart
import 'dart:typed_data';
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
                      Text('选择文件后显示预�?,
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/pages/preview_panel.dart
git commit -m "feat: 添加预览面板页面"
```

---

