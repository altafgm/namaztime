package com.salahtime.maniyars

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import kotlin.math.roundToInt

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        PrayerScheduleData.recomputeFromStoredSchedule(context, prefs)
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_LAST_PRAYER_NAME = "flutter.widget_last_prayer_name"
        const val KEY_LAST_PRAYER_TIME = "flutter.widget_last_prayer_time"
        const val KEY_NEXT_PRAYER_NAME = "flutter.widget_next_prayer_name"
        const val KEY_NEXT_PRAYER_TIME = "flutter.widget_next_prayer_time"

        /** Fallback width (dp) when the launcher reports no widget options. */
        private const val FALLBACK_WIDTH_DP = 120

        /** Recomputes the stored last/next values (offline) and redraws every widget. */
        fun refreshAll(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            PrayerScheduleData.recomputeFromStoredSchedule(context, prefs)
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, PrayerWidgetProvider::class.java)
            )
            for (id in ids) {
                updateWidget(context, manager, id)
            }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val lastName = prefs.getString(KEY_LAST_PRAYER_NAME, "—") ?: "—"
            val lastTime = prefs.getString(KEY_LAST_PRAYER_TIME, "--:--") ?: "--:--"
            val nextName = prefs.getString(KEY_NEXT_PRAYER_NAME, "—") ?: "—"
            val nextTime = prefs.getString(KEY_NEXT_PRAYER_TIME, "--:--") ?: "--:--"

            // The widget can be resized on both axes (see prayer_widget_info.xml),
            // so every size is derived from the space the launcher gave it. At the
            // default 2x1 footprint WidgetSizing returns a scale of exactly 1.0,
            // which is the same size the layout has always used.
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val metrics = WidgetSizing.metricsFor(
                currentSizeDp(context, options),
                defaultFootprintDp(options),
            )
            val fontScale = context.resources.configuration.fontScale
            // Build the RemoteViews, then set each label. The time period is a
            // separate view so its size cannot be overridden by the main time.
            val views = RemoteViews(context.packageName, R.layout.prayer_widget_layout)
            views.setTextViewText(R.id.last_prayer_name, lastName)
            views.setTextViewText(R.id.next_prayer_name, nextName)

            fun setTime(valueId: Int, periodId: Int, raw: String) {
                // The marker is split off on any kind of space: the two code paths
                // that write this string do not agree on the separator, and a
                // marker left in the digits view would be drawn at the full time
                // size (see WidgetTimeText).
                val parts = WidgetTimeText.split(raw)
                views.setTextViewText(valueId, parts.digits)
                views.setTextViewText(periodId, parts.period)

                // Only a widget that was resized can ever need the digits shrunk:
                // at the default footprint the time has always been drawn at its
                // full size.
                val timeSp = if (metrics.scale > 1f) {
                    WidgetSizing.fitTimeToWidthSp(
                        parts.digits.length,
                        parts.period.length,
                        metrics.columnWidthDp,
                        metrics.timeSp,
                        metrics.periodSp,
                        fontScale,
                    )
                } else {
                    metrics.timeSp
                }
                views.setFloat(valueId, "setTextSize", timeSp)
                views.setFloat(
                    periodId,
                    "setTextSize",
                    WidgetSizing.periodSpFor(timeSp, metrics.timeSp, metrics.periodSp),
                )
            }
            setTime(R.id.last_prayer_time, R.id.last_prayer_period, lastTime)
            setTime(R.id.next_prayer_time, R.id.next_prayer_period, nextTime)

            fitNameToColumn(views, R.id.last_prayer_name, lastName.length, metrics, fontScale)
            fitNameToColumn(views, R.id.next_prayer_name, nextName.length, metrics, fontScale)
            views.setFloat(R.id.widget_title, "setTextSize", metrics.dividerSp)

            // Keep the side padding proportional to everything else.
            val sidePaddingPx =
                (metrics.horizontalPaddingDp * context.resources.displayMetrics.density).roundToInt()
            views.setViewPadding(R.id.widget_root, sidePaddingPx, 0, sidePaddingPx, 0)

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        /**
         * Scales a widget label down (sp) so it fits on a single line within the
         * column without ellipsizing. `metrics.nameSp` is the size for the widget's
         * current size (12sp at the default footprint); the shrink formula itself
         * is unchanged from the original implementation.
         */
        private fun fitNameToColumn(
            views: RemoteViews,
            viewId: Int,
            textLength: Int,
            metrics: WidgetSizing.Metrics,
            fontScale: Float,
        ) {
            views.setFloat(
                viewId,
                "setTextSize",
                WidgetSizing.fitNameToWidthSp(
                    textLength,
                    metrics.columnWidthDp,
                    metrics.nameSp,
                    metrics.minNameSp,
                    fontScale,
                ),
            )
        }

        /**
         * Size the launcher currently gives this widget, in dp. Portrait uses the
         * "min" bounds and landscape the "max" ones, which is how the launcher
         * reports the widget size for the current orientation.
         */
        private fun currentSizeDp(context: Context, options: Bundle): WidgetSizing.SizeDp {
            val landscape =
                context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
            val widthKey = if (landscape) {
                AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH
            } else {
                AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
            }
            val heightKey = if (landscape) {
                AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
            } else {
                AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
            }
            return WidgetSizing.SizeDp(
                options.getInt(widthKey, FALLBACK_WIDTH_DP).toFloat(),
                options.getInt(heightKey, 0).toFloat(),
            )
        }

        /**
         * Smallest size the launcher offers for this widget, i.e. the untouched 2x1
         * footprint. Using it as the scaling baseline keeps a default widget at
         * scale 1.0 whatever the launcher's grid looks like. Returns null before
         * API 31 and for launchers that do not report resize sizes.
         */
        private fun defaultFootprintDp(options: Bundle): WidgetSizing.SizeDp? {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
            val sizes: List<SizeF>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                options.getParcelableArrayList(
                    AppWidgetManager.OPTION_APPWIDGET_SIZES,
                    SizeF::class.java,
                )
            } else {
                @Suppress("DEPRECATION")
                options.getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            }
            val smallest = sizes
                ?.filter { it.width > 0f && it.height > 0f }
                ?.minByOrNull { it.width * it.height }
                ?: return null
            return WidgetSizing.SizeDp(smallest.width, smallest.height)
        }
    }
}
