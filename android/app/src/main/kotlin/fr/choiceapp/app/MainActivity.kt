package fr.choiceapp.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import androidx.multidex.MultiDex
import android.content.Context
import android.os.Bundle

class MainActivity : FlutterFragmentActivity() {
    // Notre plugin de localisation personnalisé
    private var locationPlugin: LocationPlugin? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Initialiser les plugins Flutter auto-générés
        // Note: Cela n'inclura pas geolocator car nous l'avons retiré des dépendances
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Initialiser notre plugin de localisation personnalisé
        locationPlugin = LocationPlugin(this, flutterEngine)
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        // Déléguer le résultat à notre plugin de localisation
        LocationPlugin.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
}