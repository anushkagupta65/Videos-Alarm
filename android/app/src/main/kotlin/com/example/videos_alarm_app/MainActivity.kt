package com.videosalarm.app

import android.os.Bundle
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var logger: AppEventsLogger

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FacebookSdk.setApplicationId(getString(R.string.facebook_app_id))
        FacebookSdk.sdkInitialize(applicationContext)
        logger = AppEventsLogger.newLogger(this)
        logSentFriendRequestEvent() // Test the event log
    }

    /**
     * Logs a custom "sentFriendRequest" event.
     */
    fun logSentFriendRequestEvent() {
        logger.logEvent("sentFriendRequest")
    }
}