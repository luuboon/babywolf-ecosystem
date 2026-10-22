package com.babywolf.phone_app

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.util.UUID

/**
 * Práctica 1 — Bluetooth clásico (SPP) con el ESP32.
 *
 * El firmware usa BluetoothSerial, que es Bluetooth CLÁSICO con el perfil
 * SPP (puerto serie), no BLE. Flutter no lo trae de fábrica y los plugins
 * de terceros para SPP están abandonados, así que este puente usa directo la
 * API de Android: un socket RFCOMM con el UUID estándar de SPP.
 *
 * Canales:
 *  - MethodChannel "babywolf/spp": estado, emparejados, conectar, desconectar.
 *  - EventChannel "babywolf/spp/lineas": cada línea que manda el ESP32.
 */
class SppBridge(private val activity: Activity) {

    companion object {
        /** UUID estándar del perfil Serial Port (SPP). */
        val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private const val CODIGO_PERMISO = 7101
    }

    private val principal = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    @Volatile
    private var socket: BluetoothSocket? = null

    fun registrar(messenger: BinaryMessenger) {
        MethodChannel(messenger, "babywolf/spp").setMethodCallHandler { call, result ->
            when (call.method) {
                "estado" -> result.success(estado())
                "emparejados" -> emparejados(result)
                "conectar" -> conectar(call.argument<String>("direccion"), result)
                "desconectar" -> {
                    cerrar()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "babywolf/spp/lineas").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            },
        )
    }

    private fun adaptador(): BluetoothAdapter? =
        (activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    /** En Android 12+ (API 31) conectar requiere BLUETOOTH_CONNECT en tiempo de ejecución. */
    private fun tienePermiso(): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    private fun pedirPermiso() {
        if (Build.VERSION.SDK_INT >= 31) {
            activity.requestPermissions(
                arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN),
                CODIGO_PERMISO,
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun estado(): String {
        val a = adaptador() ?: return "sin_bluetooth"
        if (!tienePermiso()) return "sin_permiso"
        if (!a.isEnabled) return "apagado"
        return if (socket?.isConnected == true) "conectado" else "listo"
    }

    @SuppressLint("MissingPermission")
    private fun emparejados(result: MethodChannel.Result) {
        val a = adaptador()
        if (a == null) {
            result.error("SIN_BLUETOOTH", "Este dispositivo no tiene Bluetooth.", null)
            return
        }
        if (!tienePermiso()) {
            pedirPermiso()
            result.error("SIN_PERMISO", "Concede el permiso de Bluetooth y vuelve a intentar.", null)
            return
        }
        if (!a.isEnabled) {
            result.error("APAGADO", "Activa el Bluetooth del teléfono.", null)
            return
        }
        val lista = a.bondedDevices.map { d ->
            mapOf("nombre" to (d.name ?: "Sin nombre"), "direccion" to d.address)
        }
        result.success(lista)
    }

    @SuppressLint("MissingPermission")
    private fun conectar(direccion: String?, result: MethodChannel.Result) {
        val a = adaptador()
        if (a == null || direccion.isNullOrBlank()) {
            result.error("ARGUMENTO", "Dirección Bluetooth inválida.", null)
            return
        }
        if (!tienePermiso()) {
            pedirPermiso()
            result.error("SIN_PERMISO", "Concede el permiso de Bluetooth y vuelve a intentar.", null)
            return
        }
        cerrar()
        // connect() bloquea: se hace en un hilo aparte y la respuesta vuelve
        // al hilo principal, que es el único que puede hablar con Flutter.
        Thread {
            try {
                val dispositivo = a.getRemoteDevice(direccion)
                val s = dispositivo.createRfcommSocketToServiceRecord(SPP_UUID)
                s.connect()
                socket = s
                principal.post { result.success(true) }
                leer(s)
            } catch (e: IOException) {
                principal.post {
                    result.error("CONEXION", "No fue posible conectar con el dispositivo.", null)
                }
            } catch (e: IllegalArgumentException) {
                principal.post { result.error("ARGUMENTO", "Dirección Bluetooth inválida.", null) }
            } catch (e: SecurityException) {
                principal.post {
                    result.error("SIN_PERMISO", "Concede el permiso de Bluetooth y vuelve a intentar.", null)
                }
            }
        }.start()
    }

    /** Lee línea por línea (el ESP32 usa println, que termina en \r\n). */
    private fun leer(s: BluetoothSocket) {
        try {
            val lector = BufferedReader(InputStreamReader(s.inputStream))
            while (true) {
                val linea = lector.readLine() ?: break
                val limpia = linea.trim()
                if (limpia.isNotEmpty()) {
                    principal.post { sink?.success(limpia) }
                }
            }
        } catch (e: IOException) {
            // Se cortó la conexión: el ESP32 se apagó o salió de rango.
        } finally {
            if (socket === s) socket = null
            principal.post { sink?.success("__DESCONECTADO__") }
        }
    }

    fun cerrar() {
        try {
            socket?.close()
        } catch (e: IOException) {
            // Ya estaba cerrado.
        }
        socket = null
    }
}
