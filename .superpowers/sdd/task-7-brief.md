# Task 7: 交叉编译脚本 + CI 工作流

**Files:**
- Create: `native/build_android.sh`
- Create: `native/build_ios.sh`
- Create: `native/toolchain-android.cmake`
- Create: `ios/hdr_converter.podspec`
- Modify: `.github/workflows/ci.yml`

- [ ] Step 1: native/build_android.sh — NDK 交叉编译脚本（arm64-v8a/x86_64）
- [ ] Step 2: native/build_ios.sh — iOS arm64 静态库编译脚本
- [ ] Step 3: native/toolchain-android.cmake — NDK CMake 工具链
- [ ] Step 4: ios/hdr_converter.podspec — CocoaPod 包装 libhdr_converter.a
- [ ] Step 5: ci.yml 末尾追加 android-build 和 ios-build job（仅 workflow_dispatch 触发）
- [ ] Step 6: git add + commit
