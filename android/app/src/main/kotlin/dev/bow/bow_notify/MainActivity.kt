package dev.bow.bow_notify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (không phải FlutterActivity): hộp xác thực vân tay của local_auth cần một FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    /**
     * Ba kênh, mỗi kênh một âm riêng (tool/make_sounds.py) — nghe là biết agent đang CHỜ, đã XONG hay LỖI.
     * Android khoá âm theo kênh ngay lúc tạo: đổi âm thì phải đổi cả ID kênh ở đây lẫn `channel_id` server gửi
     * (bow-agent, src/core/fcm.ts).
     */
    private val channels = listOf(
        Triple("bow_ask", "Bow · đang chờ bạn", R.raw.bow_ask),
        Triple("bow_done", "Bow · đã xong", R.raw.bow_done),
        Triple("bow_fail", "Bow · lượt chạy lỗi", R.raw.bow_fail),
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val manager = getSystemService(NotificationManager::class.java)
        manager.deleteNotificationChannel("bow") // kênh của bản 1.0 (âm mặc định của máy)
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        for ((id, name, sound) in channels) {
            // Mức ưu tiên CAO: "đang chờ bạn" phải hiện nổi + kêu, không lặng lẽ nằm trong khay. Tạo lại kênh đã có là vô hại.
            val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
            channel.setSound(Uri.parse("android.resource://$packageName/$sound"), audio)
            channel.enableVibration(true)
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * `bow/notify` → `show`: tự dựng thông báo khi app ĐANG MỞ. Lúc đó FCM chỉ giao tin cho app chứ hệ điều hành
     * không hiện gì — không kêu, không hiện nổi; bản 1.0 vì thế "bắn thử mà không nghe tiếng".
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bow/notify").setMethodCallHandler { call, result ->
            if (call.method != "show") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val requested = call.argument<String>("channel")
            val channel = if (channels.any { it.first == requested }) requested else "bow_ask"
            val open = PendingIntent.getActivity(this, 0, packageManager.getLaunchIntentForPackage(packageName), PendingIntent.FLAG_IMMUTABLE)
            val note = Notification.Builder(this, channel)
                .setSmallIcon(R.drawable.ic_stat_bow)
                .setColor(getColor(R.color.bow_accent))
                .setContentTitle(call.argument<String>("title"))
                .setContentText(call.argument<String>("body"))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            // Cùng tag ⇒ thay thông báo cũ của cùng lượt chạy, như khi hệ điều hành tự dựng.
            getSystemService(NotificationManager::class.java).notify(call.argument<String>("tag"), 0, note)
            result.success(null)
        }
    }
}
