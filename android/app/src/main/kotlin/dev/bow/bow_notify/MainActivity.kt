package dev.bow.bow_notify

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Kênh "bow" mức ưu tiên CAO: thông báo "cần bạn duyệt" phải hiện nổi + rung, không lặng lẽ nằm trong khay.
        // Kênh mặc định của FCM chỉ ở mức thường. Tạo lại kênh đã có là vô hại.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("bow", "Bow", NotificationManager.IMPORTANCE_HIGH)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
