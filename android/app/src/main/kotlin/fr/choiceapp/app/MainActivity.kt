package fr.choiceapp.app

import io.flutter.embedding.android.FlutterFragmentActivity
import androidx.multidex.MultiDex
import android.content.Context
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Let the geolocator plugin handle permission results (Flutter does this automatically now)
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
}
