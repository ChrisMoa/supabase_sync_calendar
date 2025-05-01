package com.example.supabase_sync_calendar

import android.content.ContentResolver
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.supabase_sync_calendar/file_handler"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Received method call: ${call.method}")
            when (call.method) {
                "readContentUri" -> {
                    val uri = call.argument<String>("uri")
                    if (uri == null) {
                        Log.e(TAG, "URI is null")
                        result.error("INVALID_URI", "URI cannot be null", null)
                        return@setMethodCallHandler
                    }
                    
                    Log.d(TAG, "Attempting to read URI: $uri")
                    try {
                        val content = readContentUri(Uri.parse(uri))
                        Log.d(TAG, "Successfully read content from URI")
                        result.success(content)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error reading URI: ${e.message}", e)
                        result.error("READ_ERROR", e.message, null)
                    }
                }
                else -> {
                    Log.w(TAG, "Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    private fun readContentUri(uri: Uri): String {
        Log.d(TAG, "Opening content resolver for URI: $uri")
        val contentResolver: ContentResolver = context.contentResolver
        val inputStream = contentResolver.openInputStream(uri)
            ?: throw Exception("Could not open input stream for URI: $uri")
        
        Log.d(TAG, "Reading content from input stream")
        return BufferedReader(InputStreamReader(inputStream)).use { reader ->
            reader.readText()
        }
    }
} 