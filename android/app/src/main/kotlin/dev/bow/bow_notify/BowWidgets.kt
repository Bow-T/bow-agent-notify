package dev.bow.bow_notify

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.text.Html
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget màn hình chính. Phần này CHỈ VẼ: mọi chữ, mọi nút đều do Dart tính sẵn rồi ghi vào vùng dữ liệu của widget
 * (lib/src/models/widget_snapshot.dart → lib/src/services/home_widget_service.dart); khoá `w_*` ở hai bên phải khớp.
 * Cú chạm vào nút được chuyển về Dart (isolate nền) — Kotlin không tự duyệt gì, không giữ khoá, không gọi mạng.
 */
internal object BowWidget {
    private const val REFRESH = "bownotify://widget/refresh"

    /** Dữ liệu cũ hơn ngần này mà không có thông báo nào gọi dậy thì nhờ Dart đọc lại. */
    private const val STALE_MS = 10 * 60 * 1000L

    fun text(data: SharedPreferences, key: String): String = data.getString(key, null).orEmpty()

    fun on(data: SharedPreferences, key: String): Boolean = text(data, key) == "1"

    fun open(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("bownotify://widget/open"))

    fun background(context: Context, uri: String): PendingIntent =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uri))

    fun refresh(context: Context): PendingIntent = background(context, REFRESH)

    /**
     * Widget được vẽ lại theo lịch của hệ điều hành (30 phút) hoặc sau khi máy khởi động lại: dữ liệu cũ thì nhờ Dart
     * đọc lại. Mốc `w_updated_ms` do Dart ghi mỗi lần đọc ⇒ lần vẽ lại do chính Dart gây ra không gọi tiếp (không lặp).
     */
    fun refreshIfStale(context: Context, data: SharedPreferences) {
        val machines = text(data, "w_machines").toIntOrNull() ?: 0
        val updated = text(data, "w_updated_ms").toLongOrNull() ?: 0L
        if (machines > 0 && System.currentTimeMillis() - updated > STALE_MS) {
            runCatching { refresh(context).send() }
        }
    }

    fun icon(kind: String): Int = when (kind) {
        "approval" -> R.drawable.w_shield
        "question" -> R.drawable.w_chat
        "reply", "done" -> R.drawable.w_success
        "fatal" -> R.drawable.w_error
        "agent" -> R.drawable.w_agent
        else -> R.drawable.w_logo_mark
    }
}

/** Widget "Chờ bạn duyệt" (4×2): thẻ đang chờ kèm nút, hoặc "không có gì chờ". */
class PendingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, widgetData, appWidgetManager.getAppWidgetOptions(id)))
        }
        BowWidget.refreshIfStale(context, widgetData)
    }

    /** Người dùng kéo giãn widget: cao hơn thì hiện thêm dòng của lệnh. */
    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        appWidgetManager.updateAppWidget(appWidgetId, render(context, HomeWidgetPlugin.getData(context), newOptions))
    }

    private fun render(context: Context, data: SharedPreferences, options: Bundle?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_pending)
        views.setOnClickPendingIntent(android.R.id.background, BowWidget.open(context))
        views.setOnClickPendingIntent(R.id.refresh, BowWidget.refresh(context))
        views.setTextViewText(R.id.host, BowWidget.text(data, "w_host"))
        val badge = BowWidget.text(data, "w_badge")
        views.setTextViewText(R.id.badge, badge)
        views.setViewVisibility(R.id.badge, if (badge.isEmpty()) View.GONE else View.VISIBLE)

        val hasCard = BowWidget.on(data, "w_card")
        views.setViewVisibility(R.id.card, if (hasCard) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.empty, if (hasCard) View.GONE else View.VISIBLE)
        if (!hasCard) {
            // Chưa có dữ liệu nào (widget được thêm trước khi mở app lần đầu) thì dùng chữ tĩnh.
            views.setImageViewResource(R.id.empty_icon, BowWidget.icon(BowWidget.text(data, "w_empty_icon")))
            views.setTextViewText(R.id.empty_title, BowWidget.text(data, "w_empty_title").ifEmpty { context.getString(R.string.widget_setup_title) })
            views.setTextViewText(R.id.empty_sub, BowWidget.text(data, "w_empty_sub").ifEmpty { context.getString(R.string.widget_setup_sub) })
            return views
        }

        views.setImageViewResource(R.id.kind_icon, BowWidget.icon(BowWidget.text(data, "w_kind")))
        views.setTextViewText(R.id.label, BowWidget.text(data, "w_label"))
        views.setViewVisibility(R.id.risky, if (BowWidget.on(data, "w_risky")) View.VISIBLE else View.GONE)
        // Lệnh → ô chữ đều nét, nguyên từng ký tự. Lời agent (thẻ trả lời) → ô văn xuôi, dựng từ HTML rút gọn do Dart đổi
        // từ Markdown (đậm, nghiêng, code, gạch đầu dòng).
        val html = BowWidget.text(data, "w_html")
        val body = if (html.isEmpty()) R.id.text else R.id.prose
        views.setViewVisibility(R.id.text, if (html.isEmpty()) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.prose, if (html.isEmpty()) View.GONE else View.VISIBLE)
        views.setTextViewText(
            body,
            if (html.isEmpty()) BowWidget.text(data, "w_text") else Html.fromHtml(html, Html.FROM_HTML_MODE_COMPACT),
        )
        // Ô lệnh chiếm phần còn lại của widget: hiện vừa đủ số dòng lọt trong đó (mỗi dòng ~16 dp; phần cố định — đầu
        // widget, tên tác vụ, hàng nút, lề — ~136 dp). Launcher báo chiều cao theo cặp min / max: màn DỌC dùng max.
        val portrait = context.resources.configuration.orientation != Configuration.ORIENTATION_LANDSCAPE
        val height = options
            ?.getInt(if (portrait) AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            ?.takeIf { it > 0 } ?: 150
        views.setInt(body, "setMaxLines", ((height - 136) / 16).coerceIn(1, 12))

        val busy = BowWidget.on(data, "w_busy")
        views.setViewVisibility(R.id.actions, if (busy) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.sending, if (busy) View.VISIBLE else View.GONE)
        val ref = BowWidget.text(data, "w_ref")
        listOf(R.id.btn0, R.id.btn1, R.id.btn2).forEachIndexed { index, button ->
            val title = BowWidget.text(data, "w_a${index}_title")
            if (title.isEmpty()) {
                views.setViewVisibility(button, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(button, View.VISIBLE)
            views.setTextViewText(button, title)
            // Nút "mở app" (thao tác rủi ro phải qua vân tay, câu hỏi dài) → mở app; nút còn lại → gửi quyết định qua Dart.
            val action = Uri.encode(BowWidget.text(data, "w_a${index}_id"))
            views.setOnClickPendingIntent(
                button,
                if (BowWidget.on(data, "w_a${index}_opens")) BowWidget.open(context)
                else BowWidget.background(context, "bownotify://widget/act?$ref&a=$action"),
            )
        }
        return views
    }
}

/** Widget "Trạng thái" (viên thuốc 2×1): mấy việc đang chờ / đang nghe mấy máy. Chạm là mở app. */
class StatusWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_status)
        views.setOnClickPendingIntent(android.R.id.background, BowWidget.open(context))
        views.setImageViewResource(R.id.status_icon, BowWidget.icon(BowWidget.text(widgetData, "w_status_icon")))
        views.setTextViewText(R.id.status_title, BowWidget.text(widgetData, "w_status_title").ifEmpty { context.getString(R.string.widget_setup_title) })
        views.setTextViewText(R.id.status_sub, BowWidget.text(widgetData, "w_status_sub").ifEmpty { context.getString(R.string.widget_setup_sub) })
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
        BowWidget.refreshIfStale(context, widgetData)
    }
}
