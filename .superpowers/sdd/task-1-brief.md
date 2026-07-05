# Task 1: 平台目录初始化

**Files:**
- Run: lutter create --project-name hdr2sdr --platforms ios,android .
- Modify: ios/Podfile
- Modify: ndroid/app/build.gradle
- Create: ndroid/app/src/main/jniLibs/arm64-v8a/.gitkeep
- Create: ndroid/app/src/main/jniLibs/x86_64/.gitkeep

- [ ] **Step 1: 运行 flutter create 生成平台目录**

bash:
cd E:\ai\hdr2sdr
flutter create --project-name hdr2sdr --platforms ios,android .

预期：生成 ios/ 和 android/ 目录及全部平台文件，不覆盖 lib/ 目录。

- [ ] **Step 2: 配置 android/app/build.gradle**
在 android { 块内修改/添加 minSdk 24、ndk abiFilters

- [ ] **Step 3: 创建 jniLibs 占位目录**

- [ ] **Step 4: 在 ios/Podfile 追加 FFmpegKit 依赖 (pod 'ffmpeg-kit-ios-full', '~> 6.0')

- [ ] **Step 5: 验证: flutter pub get && flutter analyze

- [ ] **Step 6: 提交
