package com.example.medicine_reminder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.os.Environment
import android.content.ContentValues
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import android.net.Uri
import java.io.IOException
import android.content.Intent
import android.provider.DocumentsContract

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.medicine_reminder/backup"
    private val PICK_JSON_FILE_REQUEST_CODE = 42
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: "backup.json"
                    val content = call.argument<String>("content") ?: ""
                    
                    val savedPath = saveFileToDownloads(fileName, content)
                    if (savedPath != null) {
                        result.success(savedPath)
                    } else {
                        result.error("WRITE_ERROR", "Failed to save file to downloads folder", null)
                    }
                }
                "selectBackupFile" -> {
                    pendingResult = result
                    selectBackupFile()
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun selectBackupFile() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            
            // Attempt to point to the Downloads directory
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val authority = "com.android.providers.downloads.documents"
                val documentId = "downloads"
                val downloadsUri = DocumentsContract.buildDocumentUri(authority, documentId)
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, downloadsUri)
            }
        }
        
        try {
            startActivityForResult(intent, PICK_JSON_FILE_REQUEST_CODE)
        } catch (e: Exception) {
            e.printStackTrace()
            // Try generic fallback if ACTION_OPEN_DOCUMENT fails
            val fallbackIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "application/json"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            try {
                startActivityForResult(fallbackIntent, PICK_JSON_FILE_REQUEST_CODE)
            } catch (ex: Exception) {
                ex.printStackTrace()
                pendingResult?.error("PICK_ERROR", "Failed to open document picker: ${ex.message}", null)
                pendingResult = null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_JSON_FILE_REQUEST_CODE) {
            if (pendingResult == null) return
            
            if (resultCode == RESULT_OK && data != null) {
                val uri = data.data
                if (uri != null) {
                    val content = readTextFromUri(uri)
                    if (content != null) {
                        pendingResult?.success(content)
                    } else {
                        pendingResult?.error("READ_ERROR", "Could not read file content", null)
                    }
                } else {
                    pendingResult?.error("NO_URI", "No file selected", null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }

    private fun readTextFromUri(uri: Uri): String? {
        return try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                inputStream.bufferedReader().use { it.readText() }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun saveFileToDownloads(fileName: String, content: String): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri: Uri? = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
            if (uri != null) {
                try {
                    resolver.openOutputStream(uri).use { outputStream ->
                        if (outputStream != null) {
                            outputStream.write(content.toByteArray())
                            outputStream.flush()
                            return "Downloads/$fileName"
                        }
                    }
                } catch (e: IOException) {
                    e.printStackTrace()
                    resolver.delete(uri, null, null)
                }
            }
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val file = File(downloadsDir, fileName)
            try {
                FileOutputStream(file).use { outputStream ->
                    outputStream.write(content.toByteArray())
                    outputStream.flush()
                    return file.absolutePath
                }
            } catch (e: IOException) {
                e.printStackTrace()
            }
        }
        return null
    }
}
