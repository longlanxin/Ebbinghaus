# 使用GitHub Actions自动编译APK（推荐）

## 最简单的APK获取方式 - 无需安装任何工具

### 步骤1：在GitHub上创建仓库
1. 访问 https://github.com/new
2. 仓库名称：`ebbinghaus_memory_helper`
3. 选择 "Public"（免费）
4. 点击 "Create repository"

### 步骤2：上传代码
1. 在仓库页面点击 "uploading an existing file"
2. 将 `ebbinghaus_memory_helper.zip` 中的所有文件上传到仓库
3. 或者使用以下命令：

```bash
cd ebbinghaus_memory_helper
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/你的用户名/ebbinghaus_memory_helper.git
git push -u origin main
```

### 步骤3：触发编译
1. 进入仓库的 "Actions" 标签页
2. 点击 "Build APK" 工作流
3. 点击 "Run workflow" 按钮
4. 等待约 5-10 分钟

### 步骤4：下载APK
1. 编译完成后，进入 "Actions" 页面
2. 点击最新的工作流运行记录
3. 在 "Artifacts" 部分找到：
   - `release-apk` - 通用APK（适用于所有Android设备，约 25-30MB）
   - `split-apks` - 分架构APK（更小，选择适合您设备的版本）
4. 点击下载ZIP，解压即可获得APK

### 支持的设备架构
- `app-arm64-v8a-release.apk` - 大多数现代手机（推荐）
- `app-armeabi-v7a-release.apk` - 较旧的32位手机
- `app-x86_64-release.apk` - 模拟器或x86设备

## 如何确定手机架构
在手机上安装 "Device Info HW" 或类似APP，查看 "CPU" 或 "Processor" 信息：
- 包含 "arm64" → 下载 arm64-v8a 版本
- 包含 "armv7" 或 "armeabi" → 下载 armeabi-v7a 版本
