import Foundation
import Flutter
import BackgroundTasks

/// iOS 后台转换服务 - 使用 BGTaskScheduler 注册后台任务
/// 注意：iOS 后台执行限制严格，实际转换在前台完成，此处仅注册占位
class BackgroundService {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "hdr2sdr/background",
            binaryMessenger: messenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "startConversion":
                self?.scheduleBackgroundTask()
                result(true)
            case "cancelConversion":
                BGTaskScheduler.shared.cancel(
                    taskRequestWithIdentifier: "com.example.hdr2sdr.conversion"
                )
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// 在应用启动时注册 BGTaskScheduler 任务处理
    static func registerTaskHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.example.hdr2sdr.conversion",
            using: nil
        ) { task in
            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(
            identifier: "com.example.hdr2sdr.conversion"
        )
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("BGTaskScheduler submit failed: \(error)")
        }
    }
}
