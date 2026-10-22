package com.babywolf.phone_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    // Práctica 1: puente Bluetooth clásico (SPP) hacia el ESP32.
    private val spp = SppBridge(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        spp.registrar(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        spp.cerrar()
        super.onDestroy()
    }
}
