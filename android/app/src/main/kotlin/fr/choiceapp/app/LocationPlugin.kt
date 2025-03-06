package fr.choiceapp.app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

/**
 * Plugin natif pour la localisation sur Android
 * Remplace le plugin geolocator avec une implémentation personnalisée
 */
class LocationPlugin(private val activity: Activity, private val flutterEngine: FlutterEngine) {
    private val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fr.choiceapp.app/location")
    private val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "fr.choiceapp.app/location_updates")
    
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null
    
    // Codes de requête pour les permissions
    private val REQUEST_LOCATION_PERMISSION = 1001
    
    init {
        locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        
        // Configuration du canal de méthode
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isLocationServiceEnabled" -> isLocationServiceEnabled(result)
                "checkPermission" -> checkPermission(result)
                "requestPermission" -> requestPermission(result)
                "getCurrentPosition" -> getCurrentPosition(result)
                else -> result.notImplemented()
            }
        }
        
        // Configuration du canal d'événements
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                // À implémenter si vous avez besoin de flux continu de position
            }
            
            override fun onCancel(arguments: Any?) {
                // Nettoyage des ressources
            }
        })
    }
    
    private fun isLocationServiceEnabled(result: MethodChannel.Result) {
        val gpsEnabled = locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) ?: false
        val networkEnabled = locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ?: false
        result.success(gpsEnabled || networkEnabled)
    }
    
    private fun checkPermission(result: MethodChannel.Result) {
        val finePermission = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION
        )
        val coarsePermission = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        
        val permissionResult = when {
            finePermission == PackageManager.PERMISSION_GRANTED -> "whileInUse"
            coarsePermission == PackageManager.PERMISSION_GRANTED -> "whileInUse"
            ActivityCompat.shouldShowRequestPermissionRationale(
                activity,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) -> "denied"
            else -> "deniedForever"
        }
        
        result.success(permissionResult)
    }
    
    private fun requestPermission(result: MethodChannel.Result) {
        val permissions = arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION
        )
        
        // Stocker le résultat pour le traiter dans onRequestPermissionsResult
        pendingPermissionResult = result
        
        ActivityCompat.requestPermissions(
            activity,
            permissions,
            REQUEST_LOCATION_PERMISSION
        )
    }
    
    private fun getCurrentPosition(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error(
                "PERMISSION_DENIED",
                "Location permission not granted",
                null
            )
            return
        }
        
        // Utiliser le fournisseur GPS si disponible, sinon le fournisseur réseau
        val provider = when {
            locationManager?.isProviderEnabled(LocationManager.GPS_PROVIDER) == true -> LocationManager.GPS_PROVIDER
            locationManager?.isProviderEnabled(LocationManager.NETWORK_PROVIDER) == true -> LocationManager.NETWORK_PROVIDER
            else -> null
        }
        
        if (provider == null) {
            result.error(
                "LOCATION_SERVICES_DISABLED",
                "Location services are disabled",
                null
            )
            return
        }
        
        // Obtenir la dernière position connue
        val lastKnownLocation = locationManager?.getLastKnownLocation(provider)
        
        if (lastKnownLocation != null) {
            result.success(mapOf(
                "latitude" to lastKnownLocation.latitude,
                "longitude" to lastKnownLocation.longitude,
                "accuracy" to lastKnownLocation.accuracy.toDouble(),
                "altitude" to lastKnownLocation.altitude,
                "heading" to if (lastKnownLocation.hasBearing()) lastKnownLocation.bearing.toDouble() else null,
                "speed" to if (lastKnownLocation.hasSpeed()) lastKnownLocation.speed.toDouble() else null,
                "timestamp" to lastKnownLocation.time
            ))
            return
        }
        
        // Si aucune position connue, demander une mise à jour unique
        val locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                result.success(mapOf(
                    "latitude" to location.latitude,
                    "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(),
                    "altitude" to location.altitude,
                    "heading" to if (location.hasBearing()) location.bearing.toDouble() else null,
                    "speed" to if (location.hasSpeed()) location.speed.toDouble() else null,
                    "timestamp" to location.time
                ))
                
                // Arrêter d'écouter après avoir obtenu une position
                locationManager?.removeUpdates(this)
            }
            
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            
            override fun onProviderEnabled(provider: String) {}
            
            override fun onProviderDisabled(provider: String) {
                locationManager?.removeUpdates(this)
                result.error(
                    "LOCATION_SERVICES_DISABLED",
                    "Location services are disabled",
                    null
                )
            }
        }
        
        try {
            // Demander une mise à jour unique de la position
            locationManager?.requestSingleUpdate(
                provider,
                locationListener,
                Looper.getMainLooper()
            )
            
            // Configurer un timeout de 15 secondes
            Timer().schedule(object : TimerTask() {
                override fun run() {
                    locationManager?.removeUpdates(locationListener)
                    
                    // Si aucune position n'a été obtenue après 15 secondes, retourner une erreur
                    activity.runOnUiThread {
                        result.error(
                            "LOCATION_TIMEOUT",
                            "Failed to get location within 15 seconds",
                            null
                        )
                    }
                }
            }, 15000)
        } catch (e: Exception) {
            result.error(
                "LOCATION_ERROR",
                e.message,
                null
            )
        }
    }
    
    companion object {
        // Pour stocker le résultat en attente pour la demande de permission
        private var pendingPermissionResult: MethodChannel.Result? = null
        
        // À appeler depuis MainActivity.onRequestPermissionsResult
        fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<out String>,
            grantResults: IntArray
        ) {
            if (requestCode == 1001 && pendingPermissionResult != null) {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    pendingPermissionResult?.success("whileInUse")
                } else {
                    pendingPermissionResult?.success("denied")
                }
                pendingPermissionResult = null
            }
        }
    }
}