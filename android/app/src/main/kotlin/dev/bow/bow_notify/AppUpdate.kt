package dev.bow.bow_notify

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

/**
 * Cài bản mới của CHÍNH app này từ file APK mà Dart đã tải về + kiểm xong (lib/src/services/update_service.dart).
 * Phần này chỉ đưa file cho trình cài đặt của Android rồi báo lại kết quả — không tải gì, không tự cài: Android LUÔN
 * hiện hộp hỏi người dùng, và chỉ cho cài đè khi bản mới ký cùng khoá với bản đang cài.
 */
internal object AppUpdate {
    const val CHANNEL = "dev.bow.bow_notify/update"

    private val main = Handler(Looper.getMainLooper())

    /** Lời gọi `install` đang chờ trình cài đặt trả lời. */
    private var waiting: MethodChannel.Result? = null

    fun install(context: Context, path: String?, result: MethodChannel.Result) {
        val apk = path?.let(::File)
        if (apk == null || !apk.isFile) {
            result.success(mapOf("status" to "failed", "message" to "no file"))
            return
        }
        // Bấm cài lại khi lần trước chưa có trả lời (hộp của máy bị đóng mà không báo): lần trước coi như đã huỷ.
        // Trả lời NGAY tại đây (đang ở luồng giao diện) — xếp hàng qua `finish` thì nó chạy sau dòng gán bên dưới
        // và huỷ nhầm chính lần mới này.
        waiting?.success(mapOf("status" to "cancelled", "message" to null))
        waiting = result
        val app = context.applicationContext
        // Chép 30–40 MB vào phiên cài đặt: không làm trên luồng giao diện.
        thread {
            try {
                val installer = app.packageManager.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                // Phiên này chỉ nhận APK của đúng app này — file mang tên gói khác là bị từ chối.
                params.setAppPackageName(app.packageName)
                val id = installer.createSession(params)
                installer.openSession(id).use { session ->
                    session.openWrite("bow-notify.apk", 0, apk.length()).use { out ->
                        apk.inputStream().use { it.copyTo(out) }
                        session.fsync(out)
                    }
                    // Kết quả về InstallStatusReceiver. Intent ĐÍCH DANH + receiver không exported: chỉ hệ thống (qua
                    // PendingIntent này) gửi tới được; FLAG_MUTABLE vì hệ thống điền kết quả vào extras.
                    val status = PendingIntent.getBroadcast(
                        app,
                        id,
                        Intent(app, InstallStatusReceiver::class.java),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                    )
                    session.commit(status.intentSender)
                }
            } catch (e: Exception) {
                finish("failed", e.message)
            }
        }
    }

    /** Trả kết quả về Dart (một lần cho mỗi lời gọi). */
    fun finish(status: String, message: String?) {
        main.post {
            waiting?.success(mapOf("status" to status, "message" to message))
            waiting = null
        }
    }
}

/** Trình cài đặt báo về đây: cần người dùng xác nhận → mở hộp của máy; còn lại là kết quả cuối. */
class InstallStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                try {
                    // Hộp "Cập nhật ứng dụng này?" của Android (lần đầu: hỏi cho app quyền cài ứng dụng trước).
                    context.startActivity(confirm!!.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } catch (e: Exception) {
                    AppUpdate.finish("failed", e.message)
                }
            }
            PackageInstaller.STATUS_SUCCESS -> AppUpdate.finish("done", message)
            PackageInstaller.STATUS_FAILURE_ABORTED -> AppUpdate.finish("cancelled", message)
            PackageInstaller.STATUS_FAILURE_CONFLICT -> AppUpdate.finish("conflict", message)
            PackageInstaller.STATUS_FAILURE_STORAGE -> AppUpdate.finish("storage", message)
            else -> AppUpdate.finish("failed", message)
        }
    }
}
