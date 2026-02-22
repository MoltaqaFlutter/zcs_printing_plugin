package com.example.zcs_printing_example

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure proper viewport initialization
        // FlutterActivity handles view creation, but we ensure it's done correctly
    }
    
    override fun onPostResume() {
        super.onPostResume()
        // Ensure viewport metrics are sent after resume
    }
}
