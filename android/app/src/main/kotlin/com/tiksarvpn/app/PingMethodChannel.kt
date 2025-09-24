package com.tiksarvpn.app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

class PingMethodChannel(private val context: Context) : MethodCallHandler {
    private val pingService = PingService(context)
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val activePingJobs = mutableMapOf<String, Job>()
    private var methodChannel: MethodChannel? = null

    companion object {
        const val CHANNEL = "com.tiksarvpn.app/ping"

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            val handler = PingMethodChannel(context)
            handler.methodChannel = channel
            channel.setMethodCallHandler(handler)
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "pingHost" -> {
                handlePingHost(call, result)
            }
            "pingMultipleHosts" -> {
                handlePingMultipleHosts(call, result)
            }
            "startContinuousPing" -> {
                handleStartContinuousPing(call, result)
            }
            "stopContinuousPing" -> {
                handleStopContinuousPing(call, result)
            }
            "getNetworkType" -> {
                result.success(pingService.getNetworkType())
            }
            "cleanup" -> {
                cleanup()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handlePingHost(call: MethodCall, result: Result) {
        val host = call.argument<String>("host")
        val port = call.argument<Int>("port") ?: 80
        val timeoutMs = call.argument<Int>("timeoutMs") ?: 5000
        val useIcmp = call.argument<Boolean>("useIcmp") ?: true
        val useTcp = call.argument<Boolean>("useTcp") ?: true

        if (host == null) {
            result.error("INVALID_ARGUMENT", "Host is required", null)
            return
        }

        scope.launch {
            try {
                val pingResult = pingService.pingHost(host, port, timeoutMs, useIcmp, useTcp)
                result.success(pingResultToMap(pingResult))
            } catch (e: Exception) {
                result.error("PING_ERROR", "Failed to ping host: ${e.message}", null)
            }
        }
    }

    private fun handlePingMultipleHosts(call: MethodCall, result: Result) {
        val hostsData = call.argument<List<Map<String, Any>>>("hosts")
        val timeoutMs = call.argument<Int>("timeoutMs") ?: 5000
        val useIcmp = call.argument<Boolean>("useIcmp") ?: true
        val useTcp = call.argument<Boolean>("useTcp") ?: true

        if (hostsData == null) {
            result.error("INVALID_ARGUMENT", "Hosts list is required", null)
            return
        }

        scope.launch {
            try {
                val hosts = hostsData.mapNotNull { hostMap ->
                    val host = hostMap["host"] as? String
                    val port = (hostMap["port"] as? Number)?.toInt() ?: 80
                    if (host != null) host to port else null
                }

                val results = pingService.pingMultipleHosts(hosts, timeoutMs, useIcmp, useTcp)
                val resultMap = results.mapValues { (_, pingResult) ->
                    pingResultToMap(pingResult)
                }
                result.success(resultMap)
            } catch (e: Exception) {
                result.error("PING_ERROR", "Failed to ping multiple hosts: ${e.message}", null)
            }
        }
    }

    private fun handleStartContinuousPing(call: MethodCall, result: Result) {
        val host = call.argument<String>("host")
        val port = call.argument<Int>("port") ?: 80
        val intervalMs = call.argument<Long>("intervalMs") ?: 5000L
        val pingId = call.argument<String>("pingId")

        if (host == null || pingId == null) {
            result.error("INVALID_ARGUMENT", "Host and pingId are required", null)
            return
        }

        try {
            // Stop existing ping if any
            activePingJobs[pingId]?.cancel()

            // Start new continuous ping
            val job = pingService.startContinuousPing(host, port, intervalMs) { pingResult ->
                // Send results back to Flutter via method channel
                scope.launch {
                    try {
                        methodChannel?.invokeMethod(
                            "onContinuousPingResult",
                            mapOf(
                                "pingId" to pingId,
                                "result" to pingResultToMap(pingResult)
                            )
                        )
                    } catch (e: Exception) {
                        // Handle error silently to avoid breaking the ping loop
                    }
                }
            }

            activePingJobs[pingId] = job
            result.success(true)
        } catch (e: Exception) {
            result.error("PING_ERROR", "Failed to start continuous ping: ${e.message}", null)
        }
    }

    private fun handleStopContinuousPing(call: MethodCall, result: Result) {
        val pingId = call.argument<String>("pingId")

        if (pingId == null) {
            result.error("INVALID_ARGUMENT", "PingId is required", null)
            return
        }

        try {
            activePingJobs[pingId]?.cancel()
            activePingJobs.remove(pingId)
            result.success(true)
        } catch (e: Exception) {
            result.error("PING_ERROR", "Failed to stop continuous ping: ${e.message}", null)
        }
    }

    private fun pingResultToMap(pingResult: PingResult): Map<String, Any?> {
        return mapOf(
            "success" to pingResult.success,
            "latency" to pingResult.latency,
            "method" to pingResult.method,
            "error" to pingResult.error,
            "timestamp" to pingResult.timestamp
        )
    }

    private fun cleanup() {
        // Cancel all active ping jobs
        activePingJobs.values.forEach { it.cancel() }
        activePingJobs.clear()
        
        // Cancel the coroutine scope
        scope.cancel()
        
        // Cleanup ping service
        pingService.cleanup()
    }
}
