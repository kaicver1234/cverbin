package com.tiksarvpn.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import kotlinx.coroutines.*
import java.io.IOException
import java.net.*
import java.util.concurrent.TimeUnit
import kotlin.system.measureTimeMillis

data class PingResult(
    val success: Boolean,
    val latency: Long,
    val method: String,
    val error: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

class PingService(private val context: Context) {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    companion object {
        private const val DEFAULT_TIMEOUT_MS = 5000
        private const val TCP_TIMEOUT_MS = 3000
        private const val ICMP_TIMEOUT_MS = 5000
        private const val MAX_RETRIES = 3
        private const val PACKET_SIZE = 32
        private const val PING_COUNT = 4
    }

    /**
     * Performs a comprehensive ping test using multiple methods
     * Returns the best result from available methods
     */
    suspend fun pingHost(
        host: String,
        port: Int = 80,
        timeoutMs: Int = DEFAULT_TIMEOUT_MS,
        useIcmp: Boolean = true,
        useTcp: Boolean = true
    ): PingResult = withContext(Dispatchers.IO) {
        if (!isNetworkAvailable()) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "network_check",
                error = "No network connection available"
            )
        }

        val results = mutableListOf<Deferred<PingResult>>()

        // Add ICMP ping if enabled
        if (useIcmp) {
            results.add(async { icmpPing(host, timeoutMs) })
        }

        // Add TCP ping if enabled
        if (useTcp) {
            results.add(async { tcpPing(host, port, timeoutMs) })
        }

        // Add system ping as fallback
        results.add(async { systemPing(host, timeoutMs) })

        try {
            // Wait for all ping methods to complete
            val allResults = results.awaitAll()
            
            // Return the best successful result (lowest latency)
            val successfulResults = allResults.filter { it.success }
            
            return@withContext if (successfulResults.isNotEmpty()) {
                successfulResults.minByOrNull { it.latency } ?: allResults.first()
            } else {
                // If no method succeeded, return the last attempted result
                allResults.lastOrNull() ?: PingResult(
                    success = false,
                    latency = -1,
                    method = "no_methods",
                    error = "All ping methods failed"
                )
            }
        } catch (e: Exception) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "exception",
                error = "Ping operation failed: ${e.message}"
            )
        }
    }

    /**
     * ICMP ping implementation using InetAddress.isReachable()
     * This is the most accurate method for measuring network latency
     */
    private suspend fun icmpPing(host: String, timeoutMs: Int): PingResult = withContext(Dispatchers.IO) {
        try {
            val address = InetAddress.getByName(host)
            var totalTime = 0L
            var successCount = 0
            val pingCount = minOf(PING_COUNT, 3) // Limit for faster response

            repeat(pingCount) { attempt ->
                try {
                    val startTime = System.nanoTime()
                    val isReachable = address.isReachable(timeoutMs / pingCount)
                    val endTime = System.nanoTime()
                    
                    if (isReachable) {
                        val latency = TimeUnit.NANOSECONDS.toMillis(endTime - startTime)
                        totalTime += latency
                        successCount++
                    }
                    
                    // Small delay between attempts
                    if (attempt < pingCount - 1) {
                        delay(100)
                    }
                } catch (e: Exception) {
                    // Continue with next attempt
                }
            }

            return@withContext if (successCount > 0) {
                PingResult(
                    success = true,
                    latency = totalTime / successCount,
                    method = "icmp"
                )
            } else {
                PingResult(
                    success = false,
                    latency = -1,
                    method = "icmp",
                    error = "Host not reachable via ICMP"
                )
            }
        } catch (e: Exception) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "icmp",
                error = "ICMP ping failed: ${e.message}"
            )
        }
    }

    /**
     * TCP ping implementation using socket connection
     * This measures the time to establish a TCP connection
     */
    private suspend fun tcpPing(host: String, port: Int, timeoutMs: Int): PingResult = withContext(Dispatchers.IO) {
        var socket: Socket? = null
        try {
            val address = InetAddress.getByName(host)
            val socketAddress = InetSocketAddress(address, port)
            
            val latency = measureTimeMillis {
                socket = Socket()
                socket?.connect(socketAddress, minOf(timeoutMs, TCP_TIMEOUT_MS))
            }

            return@withContext PingResult(
                success = true,
                latency = latency,
                method = "tcp"
            )
        } catch (e: SocketTimeoutException) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "tcp",
                error = "TCP connection timeout"
            )
        } catch (e: ConnectException) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "tcp",
                error = "TCP connection refused"
            )
        } catch (e: Exception) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "tcp",
                error = "TCP ping failed: ${e.message}"
            )
        } finally {
            try {
                socket?.close()
            } catch (e: Exception) {
                // Ignore close errors
            }
        }
    }

    /**
     * System ping implementation using Runtime.exec()
     * This uses the system's native ping command
     */
    private suspend fun systemPing(host: String, timeoutMs: Int): PingResult = withContext(Dispatchers.IO) {
        try {
            val pingCount = 2 // Reduced for faster response
            val timeoutSeconds = (timeoutMs / 1000).coerceAtLeast(1)
            
            val process = Runtime.getRuntime().exec(
                arrayOf(
                    "ping",
                    "-c", pingCount.toString(),
                    "-W", timeoutSeconds.toString(),
                    host
                )
            )

            val finished = process.waitFor(timeoutMs.toLong(), TimeUnit.MILLISECONDS)
            
            if (!finished) {
                process.destroyForcibly()
                return@withContext PingResult(
                    success = false,
                    latency = -1,
                    method = "system",
                    error = "System ping timeout"
                )
            }

            if (process.exitValue() == 0) {
                // Parse ping output to extract average latency
                val output = process.inputStream.bufferedReader().readText()
                val latency = parsePingOutput(output)
                
                return@withContext PingResult(
                    success = latency > 0,
                    latency = latency,
                    method = "system"
                )
            } else {
                return@withContext PingResult(
                    success = false,
                    latency = -1,
                    method = "system",
                    error = "System ping failed with exit code ${process.exitValue()}"
                )
            }
        } catch (e: Exception) {
            return@withContext PingResult(
                success = false,
                latency = -1,
                method = "system",
                error = "System ping failed: ${e.message}"
            )
        }
    }

    /**
     * Parse ping command output to extract latency
     */
    private fun parsePingOutput(output: String): Long {
        try {
            // Look for patterns like "time=XX.X ms" or "avg/max/min = XX.X/YY.Y/ZZ.Z"
            val timePattern = Regex("""time=(\d+(?:\.\d+)?)""")
            val avgPattern = Regex("""=\s*(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)""")
            
            // Try to find individual ping times first
            val timeMatches = timePattern.findAll(output)
            if (timeMatches.any()) {
                val times = timeMatches.map { it.groupValues[1].toDouble() }.toList()
                return times.average().toLong()
            }
            
            // Try to find average from statistics line
            val avgMatch = avgPattern.find(output)
            if (avgMatch != null) {
                // min/avg/max format
                return avgMatch.groupValues[2].toDouble().toLong()
            }
            
            return -1
        } catch (e: Exception) {
            return -1
        }
    }

    /**
     * Batch ping multiple hosts
     */
    suspend fun pingMultipleHosts(
        hosts: List<Pair<String, Int>>,
        timeoutMs: Int = DEFAULT_TIMEOUT_MS,
        useIcmp: Boolean = true,
        useTcp: Boolean = true
    ): Map<String, PingResult> = withContext(Dispatchers.IO) {
        val jobs = hosts.map { (host, port) ->
            async {
                val key = "$host:$port"
                key to pingHost(host, port, timeoutMs, useIcmp, useTcp)
            }
        }
        jobs.awaitAll().toMap()
    }

    /**
     * Continuous ping monitoring
     */
    fun startContinuousPing(
        host: String,
        port: Int = 80,
        intervalMs: Long = 5000,
        onResult: (PingResult) -> Unit
    ): Job {
        return scope.launch {
            while (isActive) {
                try {
                    val result = pingHost(host, port)
                    onResult(result)
                    delay(intervalMs)
                } catch (e: CancellationException) {
                    break
                } catch (e: Exception) {
                    onResult(
                        PingResult(
                            success = false,
                            latency = -1,
                            method = "continuous",
                            error = "Continuous ping error: ${e.message}"
                        )
                    )
                    delay(intervalMs)
                }
            }
        }
    }

    /**
     * Check if network is available
     */
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        return try {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Get network type information
     */
    fun getNetworkType(): String {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        return try {
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            
            when {
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Cellular"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                else -> "Unknown"
            }
        } catch (e: Exception) {
            "Unknown"
        }
    }

    /**
     * Cleanup resources
     */
    fun cleanup() {
        scope.cancel()
    }
}
