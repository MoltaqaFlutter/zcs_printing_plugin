package com.example.zcs_printing

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.print.PrintHelper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ExecutorService
import com.zcs.sdk.DriverManager
import com.zcs.sdk.Printer
import com.zcs.sdk.SdkData
import com.zcs.sdk.SdkResult
import com.zcs.sdk.print.PrnStrFormat
import com.zcs.sdk.print.PrnTextFont
import com.zcs.sdk.print.PrnTextStyle
import android.text.Layout
import com.google.zxing.BarcodeFormat

class ZcsPrintingPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null
    private var driverManager: DriverManager? = null
    private var printer: Printer? = null
    private var executor: ExecutorService? = null
    private var bitmapProcessor: BitmapPrintProcessor? = null
    private var bitmapProcessorWidthPx: Int = -1

    private fun getBitmapProcessor(): BitmapPrintProcessor {
        val width = getPrinterWidthPx()
        val existing = bitmapProcessor
        if (existing != null && bitmapProcessorWidthPx == width) return existing
        val processor = BitmapPrintProcessor.create(context, width)
        bitmapProcessor = processor
        bitmapProcessorWidthPx = width
        return processor
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.zcs_printing/printer")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        driverManager = DriverManager.getInstance()
        printer = driverManager?.getPrinter()
        executor = driverManager?.getSingleThreadExecutor()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPrinterStatus" -> {
                executor?.execute {
                    try {
                        val status = printer?.getPrinterStatus() ?: SdkResult.SDK_ERROR
                        val statusStr = when (status) {
                            SdkResult.SDK_OK -> "ok"
                            SdkResult.SDK_PRN_STATUS_PAPEROUT -> "paperOut"
                            SdkResult.SDK_ERROR -> "error"
                            else -> "error"
                        }
                        result.success(statusStr)
                    } catch (e: Exception) {
                        result.error("printerNotAvailable", "Printer is not available", e.message)
                    }
                }
            }
            "isSupportCutter" -> {
                executor?.execute {
                    try {
                        val supports = printer?.isSupportCutter() ?: false
                        result.success(supports)
                    } catch (e: Exception) {
                        result.error("printerNotAvailable", "Printer is not available", e.message)
                    }
                }
            }
            "appendText" -> {
                executor?.execute {
                    try {
                        val text = call.argument<String>("text") ?: ""
                        @Suppress("UNCHECKED_CAST")
                        val formatMap = call.argument<Map<String, Any?>>("format") as? Map<String, Any?> ?: emptyMap()
                        val format = mapToPrnStrFormat(formatMap)
                        printer?.setPrintAppendString(text, format)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to append text", e.message)
                    }
                }
            }
            "appendStrings" -> {
                executor?.execute {
                    try {
                        val texts = call.argument<List<String>>("texts")?.toTypedArray() ?: emptyArray()
                        val columnWidths = call.argument<List<Int>>("columnWidths")?.toIntArray() ?: intArrayOf()
                        @Suppress("UNCHECKED_CAST")
                        val formatsList = call.argument<List<Map<String, Any?>>>("formats") as? List<Map<String, Any?>> ?: emptyList()
                        val formats = formatsList.map { mapToPrnStrFormat(it) }.toTypedArray()
                        printer?.setPrintAppendStrings(texts, columnWidths, formats)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to append strings", e.message)
                    }
                }
            }
            "appendQrCode" -> {
                executor?.execute {
                    try {
                        val data = call.argument<String>("data") ?: ""
                        val requestedWidth = call.argument<Int>("width") ?: 200
                        val requestedHeight = call.argument<Int>("height") ?: 200
                        val alignment = call.argument<String>("alignment") ?: "center"
                        val align = stringToAlignment(alignment)
                        val printerWidth = getPrinterWidthPx()
                        // Keep QR square and within printable width so modules stay crisp.
                        val qrSize = minOf(requestedWidth, requestedHeight, printerWidth - 32)
                            .coerceAtLeast(120)
                        val qrBitmap = Printer.createQRCode(data, qrSize, qrSize)
                            ?: throw IllegalStateException("Failed to generate QR code")
                        val processor = getBitmapProcessor()
                        val qrOptions = BitmapPrintProcessor.Options(allowUpscale = false)
                        val prepared = processor.prepareBitmapForPrinter(qrBitmap, printerWidth, qrOptions)
                        qrBitmap.recycle()
                        printer?.setPrintAppendBitmap(prepared, align)
                        prepared.recycle()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to append QR code", e.message)
                    }
                }
            }
            "appendBarcode" -> {
                executor?.execute {
                    try {
                        val data = call.argument<String>("data") ?: ""
                        val format = call.argument<String>("format") ?: "CODE_128"
                        val width = call.argument<Int>("width") ?: 360
                        val height = call.argument<Int>("height") ?: 100
                        val showText = call.argument<Boolean>("showText") ?: true
                        val alignment = call.argument<String>("alignment") ?: "center"
                        val align = stringToAlignment(alignment)
                        // Map format string to BarcodeFormat
                        val barcodeFormat = when (format.uppercase()) {
                            "EAN13" -> BarcodeFormat.EAN_13
                            "EAN8" -> BarcodeFormat.EAN_8
                            "UPC_A" -> BarcodeFormat.UPC_A
                            "UPC_E" -> BarcodeFormat.UPC_E
                            "CODE_39" -> BarcodeFormat.CODE_39
                            "CODE_93" -> BarcodeFormat.CODE_93
                            "ITF" -> BarcodeFormat.ITF
                            else -> BarcodeFormat.CODE_128 // Default
                        }
                        printer?.setPrintAppendBarCode(
                            context!!,
                            data,
                            width,
                            height,
                            showText,
                            align,
                            barcodeFormat
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to append barcode", e.message)
                    }
                }
            }
            "appendBitmap" -> {
                executor?.execute {
                    try {
                        val imageBytes = call.argument<ByteArray>("imageBytes")
                        val imagePath = call.argument<String>("imagePath")
                        val alignment = call.argument<String>("alignment") ?: "center"
                        val paperWidthPx = call.argument<Int>("paperWidthPx") ?: 384
                        val align = stringToAlignment(alignment)
                        val processor = getBitmapProcessor()
                        val options = processor.parseOptions(call)
                        val effectiveWidth = resolvePaperWidthPx(paperWidthPx)

                        processor.configurePrintDensity(options.printGray) { gray ->
                            printer?.setPrintGray(gray.toByte())
                        }

                        val bitmap = if (imageBytes != null) {
                            processor.decodeBitmapFromBytes(imageBytes, effectiveWidth)
                        } else if (imagePath != null) {
                            processor.decodeBitmapFromPath(imagePath, effectiveWidth)
                        } else {
                            throw IllegalArgumentException("Either imageBytes or imagePath must be provided")
                        }

                        val prepared = processor.prepareBitmapForPrinter(bitmap, effectiveWidth, options)
                        if (bitmap !== prepared) {
                            bitmap.recycle()
                        }
                        printer?.setPrintAppendBitmap(prepared, align)
                        prepared.recycle()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("invalidImage", "Failed to append bitmap: ${e.message}", null)
                    }
                }
            }
            "startPrint" -> {
                executor?.execute {
                    try {
                        val copies = call.argument<Int>("copies") ?: 1
                        val cutAfterEachCopy = call.argument<Boolean>("cutAfterEachCopy") ?: false
                        val spacingBetweenCopies = call.argument<Int>("spacingBetweenCopies") ?: 0
                        val supportsCutter = printer?.isSupportCutter() ?: false
                        
                        // Create a format for spacing (normal format)
                        val spacingFormat = PrnStrFormat().apply {
                            setTextSize(24)
                            setAli(Layout.Alignment.ALIGN_NORMAL)
                            setStyle(PrnTextStyle.NORMAL)
                            setFont(PrnTextFont.SANS_SERIF)
                        }
                        
                        var success = true
                        for (i in 1..copies) {
                            val status = printer?.setPrintStart() ?: SdkResult.SDK_ERROR
                            if (status != SdkResult.SDK_OK && status != SdkResult.SDK_PRN_STATUS_PAPEROUT) {
                                success = false
                                break
                            }
                            
                            // Add spacing between copies (not after the last copy)
                            if (i < copies && spacingBetweenCopies > 0) {
                                for (line in 1..spacingBetweenCopies) {
                                    printer?.setPrintAppendString("", spacingFormat)
                                }
                            }
                            
                            if (cutAfterEachCopy && supportsCutter && i < copies) {
                                printer?.openPrnCutter(1)
                            }
                        }
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to print: ${e.message}", null)
                    }
                }
            }
            "cutPaper" -> {
                executor?.execute {
                    try {
                        if (printer?.isSupportCutter() == true) {
                            printer?.openPrnCutter(1)
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to cut paper", e.message)
                    }
                }
            }
            "setPrintType" -> {
                executor?.execute {
                    try {
                        val paperType = call.argument<String>("paperType") ?: "label"
                        val type = when (paperType) {
                            "label80mm" -> SdkData.LABEL_PAPER_80MM
                            else -> SdkData.LABEL_PAPER
                        }
                        printer?.setPrintType(type)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to set print type", e.message)
                    }
                }
            }
            "setPrintLine" -> {
                executor?.execute {
                    try {
                        val lines = call.argument<Int>("lines") ?: 30
                        printer?.setPrintLine(lines)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to set print line", e.message)
                    }
                }
            }
            "printLabel" -> {
                executor?.execute {
                    try {
                        val bitmapBytes = call.argument<ByteArray>("bitmapBytes")
                            ?: throw IllegalArgumentException("bitmapBytes is required")
                        val copies = call.argument<Int>("copies") ?: 1
                        val cutAfterEachCopy = call.argument<Boolean>("cutAfterEachCopy") ?: false
                        val supportsCutter = printer?.isSupportCutter() ?: false
                        
                        val bitmap = BitmapFactory.decodeByteArray(bitmapBytes, 0, bitmapBytes.size)
                            ?: throw IllegalArgumentException("Failed to decode bitmap")
                        
                        for (i in 1..copies) {
                            printer?.printLabel(bitmap)
                            if (cutAfterEachCopy && supportsCutter && i < copies) {
                                printer?.openPrnCutter(1)
                            }
                        }
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("invalidImage", "Failed to print label: ${e.message}", null)
                    }
                }
            }
            "openCashDrawer" -> {
                executor?.execute {
                    try {
                        printer?.openBox()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unknown", "Failed to open cash drawer", e.message)
                    }
                }
            }
            "printPdf" -> {
                executor?.execute {
                    try {
                        val pdfBytes = call.argument<ByteArray>("pdfBytes")
                            ?: throw IllegalArgumentException("pdfBytes is required")
                        val copies = call.argument<Int>("copies") ?: 1
                        val cutAfterEachCopy = call.argument<Boolean>("cutAfterEachCopy") ?: false
                        val cutBetweenPages = call.argument<Boolean>("cutBetweenPages") ?: false
                        val spacingBetweenCopies = call.argument<Int>("spacingBetweenCopies") ?: 0
                        // Paper width in pixels: 384 = 58mm, 576 = 80mm. Use paperWidthPx to match your POS paper.
                        val paperWidthPx = call.argument<Int>("paperWidthPx") ?: 384
                        val supportsCutter = printer?.isSupportCutter() ?: false
                        
                        // Create a format for spacing (normal format)
                        val spacingFormat = PrnStrFormat().apply {
                            setTextSize(24)
                            setAli(Layout.Alignment.ALIGN_NORMAL)
                            setStyle(PrnTextStyle.NORMAL)
                            setFont(PrnTextFont.SANS_SERIF)
                        }
                        
                        // Write PDF bytes to temp file
                        val tempFile = File(context?.cacheDir, "temp_pdf_${System.currentTimeMillis()}.pdf")
                        FileOutputStream(tempFile).use { it.write(pdfBytes) }
                        
                        val fileDescriptor = ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY)
                        val pdfRenderer = PdfRenderer(fileDescriptor)
                        
                        try {
                            val effectiveWidth = resolvePaperWidthPx(paperWidthPx)
                            val processor = getBitmapProcessor()
                            val options = processor.parseOptions(call)
                            processor.configurePrintDensity(options.printGray) { gray ->
                                printer?.setPrintGray(gray.toByte())
                            }

                            for (copy in 1..copies) {
                                if (cutBetweenPages) {
                                    for (pageIndex in 0 until pdfRenderer.pageCount) {
                                        appendPdfPageBitmap(pdfRenderer, pageIndex, effectiveWidth, processor, options)
                                        processor.configurePrintDensity(options.printGray) { gray ->
                                            printer?.setPrintGray(gray.toByte())
                                        }
                                        val status = printer?.setPrintStart() ?: SdkResult.SDK_ERROR
                                        if (status != SdkResult.SDK_OK && status != SdkResult.SDK_PRN_STATUS_PAPEROUT) {
                                            result.success(false)
                                            return@execute
                                        }
                                        if (supportsCutter && pageIndex < pdfRenderer.pageCount - 1) {
                                            printer?.openPrnCutter(1)
                                        }
                                    }
                                } else {
                                    for (pageIndex in 0 until pdfRenderer.pageCount) {
                                        appendPdfPageBitmap(pdfRenderer, pageIndex, effectiveWidth, processor, options)
                                    }
                                    for (line in 1..2) {
                                        printer?.setPrintAppendString("", spacingFormat)
                                    }
                                    processor.configurePrintDensity(options.printGray) { gray ->
                                        printer?.setPrintGray(gray.toByte())
                                    }
                                    val status = printer?.setPrintStart() ?: SdkResult.SDK_ERROR
                                    if (status != SdkResult.SDK_OK && status != SdkResult.SDK_PRN_STATUS_PAPEROUT) {
                                        result.success(false)
                                        return@execute
                                    }
                                }

                                if (copy < copies && spacingBetweenCopies > 0) {
                                    for (line in 1..spacingBetweenCopies) {
                                        printer?.setPrintAppendString("", spacingFormat)
                                    }
                                    val status = printer?.setPrintStart() ?: SdkResult.SDK_ERROR
                                    if (status != SdkResult.SDK_OK && status != SdkResult.SDK_PRN_STATUS_PAPEROUT) {
                                        result.success(false)
                                        return@execute
                                    }
                                }

                                if (cutAfterEachCopy && supportsCutter && copy < copies) {
                                    printer?.openPrnCutter(1)
                                }
                            }
                            result.success(true)
                        } finally {
                            pdfRenderer.close()
                            fileDescriptor.close()
                            tempFile.delete()
                        }
                    } catch (e: Exception) {
                        result.error("invalidPdf", "Failed to print PDF: ${e.message}", null)
                    }
                }
            }
            "cancelPrint" -> {
                // System print dialog cannot be dismissed programmatically on Android.
                // Direct ZCS print has no cancel API in the SDK.
                result.success(false)
            }
            "printWithSystem" -> {
                val imageBytes = call.argument<ByteArray>("imageBytes")
                    ?: run {
                        result.error("invalidImage", "imageBytes is required", null)
                        return
                    }
                
                val copies = call.argument<Int>("copies") ?: 1
                
                try {
                    val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                        ?: run {
                            result.error("invalidImage", "Failed to decode image", null)
                            return
                        }
                    
                    activity?.let {
                        val printHelper = PrintHelper(it)
                        printHelper.scaleMode = PrintHelper.SCALE_MODE_FIT
                        // Note: PrintHelper doesn't directly support copies parameter
                        // User will set copies in the system dialog
                        printHelper.printBitmap("Print", bitmap)
                        result.success(true)
                    } ?: run {
                        result.error("printerNotAvailable", "Activity not available", null)
                    }
                } catch (e: Exception) {
                    result.error("invalidImage", "Failed to print with system: ${e.message}", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun mapToPrnStrFormat(map: Map<String, Any?>): PrnStrFormat {
        val format = PrnStrFormat()
        format.setTextSize((map["textSize"] as? Number)?.toInt() ?: 26)
        
        val alignment = map["alignment"] as? String ?: "left"
        format.setAli(stringToAlignment(alignment))
        
        val style = map["style"] as? String ?: "normal"
        format.setStyle(if (style == "bold") PrnTextStyle.BOLD else PrnTextStyle.NORMAL)
        
        val font = map["font"] as? String ?: "sansSerif"
        when (font) {
            "monospace" -> format.setFont(PrnTextFont.MONOSPACE)
            "custom" -> {
                val path = map["path"] as? String
                if (path != null) {
                    format.setFont(PrnTextFont.CUSTOM)
                    format.setPath(path)
                    // If path is asset, need to load from assets
                    if (path.startsWith("assets/") || !path.startsWith("/")) {
                        // Asset path - need to load from assets
                        context?.assets?.open(path)?.use { input ->
                            val tempFile = File(context?.cacheDir, "font_${System.currentTimeMillis()}.ttf")
                            FileOutputStream(tempFile).use { output ->
                                input.copyTo(output)
                            }
                            format.setPath(tempFile.absolutePath)
                        }
                    }
                } else {
                    format.setFont(PrnTextFont.SANS_SERIF)
                }
            }
            else -> format.setFont(PrnTextFont.SANS_SERIF)
        }
        
        return format
    }

    private fun stringToAlignment(alignment: String): Layout.Alignment {
        return when (alignment.lowercase()) {
            "center" -> Layout.Alignment.ALIGN_CENTER
            "right" -> Layout.Alignment.ALIGN_OPPOSITE
            else -> Layout.Alignment.ALIGN_NORMAL
        }
    }

    private fun appendPdfPageBitmap(
        pdfRenderer: PdfRenderer,
        pageIndex: Int,
        effectiveWidth: Int,
        processor: BitmapPrintProcessor,
        options: BitmapPrintProcessor.Options,
    ) {
        val page = pdfRenderer.openPage(pageIndex)
        val bitmap = processor.renderPdfPageSupersampled(page, effectiveWidth, options)
        page.close()

        val prepared = processor.prepareBitmapForPrinter(bitmap, effectiveWidth, options)
        if (bitmap !== prepared) {
            bitmap.recycle()
        }
        printer?.setPrintAppendBitmap(prepared, Layout.Alignment.ALIGN_NORMAL)
        prepared.recycle()
    }

    private fun getPrinterWidthPx(): Int {
        return if (printer?.is80MMPrinter() == true) 576 else 384
    }

    /** Prefer explicit paper width, but never exceed the connected printer width. */
    private fun resolvePaperWidthPx(requestedWidth: Int): Int {
        return minOf(requestedWidth, getPrinterWidthPx())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}
