package com.vincent.taper

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    // Channel for Dart -> Android timezone lookup.
    // We return an IANA ID (e.g. "Europe/Amsterdam"), which the timezone
    // package can resolve via tz.getLocation(...).
    private val timezoneChannel = "com.vincent.taper/timezone"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, timezoneChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getLocalTimezone" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }
    }
}
