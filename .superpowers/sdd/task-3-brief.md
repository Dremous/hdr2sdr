# Task 3: UI 三态自适应布局 + ParamPanel 移动端适配

**Files:**
- Modify: lib/pages/home_page.dart
- Modify: lib/pages/param_panel.dart

**Interfaces:**
- _LayoutMode 三态: desktopWide (>900), desktopNarrow (600-900), mobile (≤600)
- Mobile 用 DefaultTabController + TabBar + TabBarView 切换 4 Tab
- ParamPanel 移动端编码器下拉包括 h264Hardware / h265Hardware

- [ ] Step 1: home_page.dart 改为三态布局
  - 添加 enum _LayoutMode { desktopWide, desktopNarrow, mobile }
  - build 中用 LayoutBuilder + constraints.maxWidth 判断
  - mobile 模式: DefaultTabController(length:4) + AppBar with TabBar + TabBarView
  - Tab 0: 文件(ScrollView + DropZone + file list + output dir)
  - Tab 1: 参数(ParamPanel)
  - Tab 2: 预览(PreviewPanel)
  - Tab 3: 进度 + 开始按钮

- [ ] Step 2: ParamPanel 增加移动端硬件编码选项
  - import 'dart:io' show Platform
  - 编码器下拉: 移动端显示全部 EncoderType, 桌面端只显示 0-2

- [ ] Step 3: flutter analyze 验证 (0 errors)

- [ ] Step 4: git add + commit
