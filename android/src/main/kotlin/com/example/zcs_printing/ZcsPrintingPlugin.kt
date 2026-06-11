package com.example.zcs_printing

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.util.Log
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
    private var context: android.content.Context? = null
    private var driverManager: DriverManager? = null
    private var printer: Printer? = null
    private var executor: ExecutorService? = null

    companion object {
        private const val TAG = "ZcsPrintingPlugin"
        private const val DEBUG = true
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.example.zcs_printing/printer")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        driverManager = DriverManager.getInstance()
        printer = driverManager?.getPrinter()
        executor = driverManager?.getSingleThreadExecutor()
    }

    override fun onMethodCall(call: MethodCall, rawResult: Result) {
        val result = MethodResultWrapper(rawResult)
        when (call.method) {
            "getPrinterStatus" -> handleGetPrinterStatus(result)
            "isSupportCutter" -> handleIsSupportCutter(result)
            "appendText" -> handleAppendText(call, result)
            "appendStrings" -> handleAppendStrings(call, result)
            "appendQrCode" -> handleAppendQrCode(call, result)
            "appendBarcode" -> handleAppendBarcode(call, result)
            "appendBitmap" -> handleAppendBitmap(call, result)
            "startPrint" -> handleStartPrint(call, result)
            "cutPaper" -> handleCutPaper(result)
            "setPrintType" -> handleSetPrintType(call, result)
            "setPrintLine" -> handleSetPrintLine(call, result)
            "printLabel" -> handlePrintLabel(call, result)
            "openCashDrawer" -> handleOpenCashDrawer(result)
            "printPdf" -> handlePrintPdf(call, result)
            "cancelPrint" -> handleCancelPrint(result)
            "printWithSystem" -> handlePrintWithSystem(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleGetPrinterStatus(result: Result) {
        executor?.execute {
            try {
                val status = printer?.getPrinterStatus() ?: SdkResult.SDK_ERROR
                val statusStr = when (status) {
                    SdkResult.SDK_OK -> "ok"
                    SdkResult.SDK_PRN_STATUS_PAPEROUT -> "paperOut"
                    SdkResult.SDK_ERROR -> "error"
                    else -> "error"
                }
                if (DEBUG) Log.d(TAG, "getPrinterStatus: $statusStr")
                result.success(statusStr)
            } catch (e: Exception) {
                result.error("printerNotAvailable", "Printer is not available", e.message)
            }
        }
    }

    private fun handleIsSupportCutter(result: Result) {
        executor?.execute {
            try {
                val supports = printer?.isSupportCutter() ?: false
                if (DEBUG) Log.d(TAG, "isSupportCutter: $supports")
                result.success(supports)
            } catch (e: Exception) {
                result.error("printerNotAvailable", "Printer is not available", e.message)
            }
        }
    }

    private fun handleAppendText(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val text = call.argument<String>("text") ?: ""
                @Suppress("UNCHECKED_CAST")
                val formatMap = call.argument<Map<String, Any?>>("format") as? Map<String, Any?> ?: emptyMap()
                val format = mapToPrnStrFormat(formatMap)
                printer?.setPrintAppendString(text, format)
                if (DEBUG) Log.d(TAG, "appendText: length=${text.length}")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to append text", e.message)
            }
        }
    }

    private fun handleAppendStrings(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val texts = call.argument<List<String>>("texts")?.toTypedArray() ?: emptyArray()
                val columnWidths = call.argument<List<Int>>("columnWidths")?.toIntArray() ?: intArrayOf()
                @Suppress("UNCHECKED_CAST")
                val formatsList = call.argument<List<Map<String, Any?>>>("formats") as? List<Map<String, Any?>> ?: emptyList()
                val formats = formatsList.map { mapToPrnStrFormat(it) }.toTypedArray()
                printer?.setPrintAppendStrings(texts, columnWidths, formats)
                if (DEBUG) Log.d(TAG, "appendStrings: texts=${texts.size}")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to append strings", e.message)
            }
        }
    }

    private fun handleAppendQrCode(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val data = call.argument<String>("data") ?: ""
                val width = call.argument<Int>("width") ?: 200
                val height = call.argument<Int>("height") ?: 200
                val alignment = call.argument<String>("alignment") ?: "center"
                val align = stringToAlignment(alignment)
                printer?.setPrintAppendQRCode(data, width, height, align)
                if (DEBUG) Log.d(TAG, "appendQrCode: data=$data")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to append QR code", e.message)
            }
        }
    }

    private fun handleAppendBarcode(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val data = call.argument<String>("data") ?: ""
                val format = call.argument<String>("format") ?: "CODE_128"
                val width = call.argument<Int>("width") ?: 360
                val height = call.argument<Int>("height") ?: 100
                val showText = call.argument<Boolean>("showText") ?: true
                val alignment = call.argument<String>("alignment") ?: "center"
                val align = stringToAlignment(alignment)
                val barcodeFormat = when (format.uppercase()) {
                    "EAN13" -> BarcodeFormat.EAN_13
                    "EAN8" -> BarcodeFormat.EAN_8
                    "UPC_A" -> BarcodeFormat.UPC_A
                    "UPC_E" -> BarcodeFormat.UPC_E
                    "CODE_39" -> BarcodeFormat.CODE_39
                    "CODE_93" -> BarcodeFormat.CODE_93
                    "ITF" -> BarcodeFormat.ITF
                    else -> BarcodeFormat.CODE_128
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
                if (DEBUG) Log.d(TAG, "appendBarcode: data=$data format=$format")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to append barcode", e.message)
            }
        }
    }

    private fun handleAppendBitmap(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val imageBytes = call.argument<ByteArray>("imageBytes")
                val imagePath = call.argument<String>("imagePath")
                val alignment = call.argument<String>("alignment") ?: "center"
                val paperWidthPx = call.argument<Int>("paperWidthPx") ?: 384
                val convertToMonochrome = call.argument<Boolean>("convertToMonochrome") ?: false
                val align = stringToAlignment(alignment)

                val bitmap = if (imageBytes != null) {
                    BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                } else if (imagePath != null) {
                    BitmapFactory.decodeFile(imagePath)
                } else {
                    throw IllegalArgumentException("Either imageBytes or imagePath must be provided")
                }

                if (bitmap != null) {
                    val processor = PdfImageProcessor()
                    val processedBitmap = processor.processBitmap(bitmap, paperWidthPx, convertToMonochrome)
                    bitmap.recycle()
                    printer?.setPrintAppendBitmap(processedBitmap, align)
                    processedBitmap.recycle()
                    if (DEBUG) Log.d(TAG, "appendBitmap: paperWidthPx=$paperWidthPx monochrome=$convertToMonochrome")
                    result.success(null)
                } else {
                    result.error("invalidImage", "Failed to decode image", null)
                }
            } catch (e: Exception) {
                result.error("invalidImage", "Failed to append bitmap: ${e.message}", null)
            }
        }
    }

    private fun handleStartPrint(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val copies = call.argument<Int>("copies") ?: 1
                val cutAfterEachCopy = call.argument<Boolean>("cutAfterEachCopy") ?: false
                val spacingBetweenCopies = call.argument<Int>("spacingBetweenCopies") ?: 0
                val supportsCutter = printer?.isSupportCutter() ?: false

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
                    if (i < copies && spacingBetweenCopies > 0) {
                        for (line in 1..spacingBetweenCopies) {
                            printer?.setPrintAppendString("", spacingFormat)
                        }
                    }
                    if (cutAfterEachCopy && supportsCutter && i < copies) {
                        printer?.openPrnCutter(1)
                    }
                }
                if (DEBUG) Log.d(TAG, "startPrint: copies=$copies success=$success")
                result.success(success)
            } catch (e: Exception) {
                result.error("unknown", "Failed to print: ${e.message}", null)
            }
        }
    }

    private fun handleCutPaper(result: Result) {
        executor?.execute {
            try {
                if (printer?.isSupportCutter() == true) {
                    printer?.openPrnCutter(1)
                }
                if (DEBUG) Log.d(TAG, "cutPaper")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to cut paper", e.message)
            }
        }
    }

    private fun handleSetPrintType(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val paperType = call.argument<String>("paperType") ?: "label"
                val type = when (paperType) {
                    "label80mm" -> SdkData.LABEL_PAPER_80MM
                    else -> SdkData.LABEL_PAPER
                }
                printer?.setPrintType(type)
                if (DEBUG) Log.d(TAG, "setPrintType: $paperType")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to set print type", e.message)
            }
        }
    }

    private fun handleSetPrintLine(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val lines = call.argument<Int>("lines") ?: 30
                printer?.setPrintLine(lines)
                if (DEBUG) Log.d(TAG, "setPrintLine: $lines")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to set print line", e.message)
            }
        }
    }

    private fun handlePrintLabel(call: MethodCall, result: Result) {
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
                bitmap.recycle()
                if (DEBUG) Log.d(TAG, "printLabel: copies=$copies")
                result.success(null)
            } catch (e: Exception) {
                result.error("invalidImage", "Failed to print label: ${e.message}", null)
            }
        }
    }

    private fun handleOpenCashDrawer(result: Result) {
        executor?.execute {
            try {
                printer?.openBox()
                if (DEBUG) Log.d(TAG, "openCashDrawer")
                result.success(null)
            } catch (e: Exception) {
                result.error("unknown", "Failed to open cash drawer", e.message)
            }
        }
    }

    private fun handlePrintPdf(call: MethodCall, result: Result) {
        executor?.execute {
            try {
                val pdfBytes = call.argument<ByteArray>("pdfBytes")
                    ?: throw IllegalArgumentException("pdfBytes is required")
                val copies = call.argument<Int>("copies") ?: 1
                val cutAfterEachCopy = call.argument<Boolean>("cutAfterEachCopy") ?: false
                val cutBetweenPages = call.argument<Boolean>("cutBetweenPages") ?: false
                val spacingBetweenCopies = call.argument<Int>("spacingBetweenCopies") ?: 0
                val paperWidthPx = call.argument<Int>("paperWidthPx") ?: 384
                val imageModeStr = call.argument<String>("imageMode") ?: "adaptive"
                val threshold = call.argument<Int>("threshold") ?: 128
                val gamma = (call.argument<Double>("gamma") ?: 1.4).toFloat()
                val renderScale = call.argument<Int>("renderScale") ?: 3
                val supportsCutter = printer?.isSupportCutter() ?: false

                val imageMode = when (imageModeStr) {
                    "threshold" -> ImageProcessingMode.SIMPLE_THRESHOLD
                    "adaptive" -> ImageProcessingMode.ADAPTIVE_THRESHOLD
                    "dither" -> ImageProcessingMode.FLOYD_STEINBERG
                    else -> ImageProcessingMode.ADAPTIVE_THRESHOLD
                }

                val processor = PdfImageProcessor(
                    mode = imageMode,
                    threshold = threshold,
                    gamma = gamma,
                    renderScale = renderScale
                )

                val spacingFormat = PrnStrFormat().apply {
                    setTextSize(24)
                    setAli(Layout.Alignment.ALIGN_NORMAL)
                    setStyle(PrnTextStyle.NORMAL)
                    setFont(PrnTextFont.SANS_SERIF)
                }

                val tempFile = File(context?.cacheDir, "temp_pdf_${System.currentTimeMillis()}.pdf")
                FileOutputStream(tempFile).use { it.write(pdfBytes) }

                val fileDescriptor = ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY)
                val pdfRenderer = PdfRenderer(fileDescriptor)

                try {
                    for (copy in 1..copies) {
                        for (pageIndex in 0 until pdfRenderer.pageCount) {
                            val page = pdfRenderer.openPage(pageIndex)
                            val monoBitmap = processor.processPdfPage(page, paperWidthPx)
                            page.close()

                            printer?.setPrintAppendBitmap(monoBitmap, Layout.Alignment.ALIGN_CENTER)
                            monoBitmap.recycle()
                            printer?.setPrintStart()

                            if (cutBetweenPages && supportsCutter && pageIndex < pdfRenderer.pageCount - 1) {
                                printer?.openPrnCutter(1)
                            }
                        }

                        for (line in 1..2) {
                            printer?.setPrintAppendString("", spacingFormat)
                            printer?.setPrintStart()
                        }

                        if (copy < copies && spacingBetweenCopies > 0) {
                            for (line in 1..spacingBetweenCopies) {
                                printer?.setPrintAppendString("", spacingFormat)
                                printer?.setPrintStart()
                            }
                        }

                        if (cutAfterEachCopy && supportsCutter && copy < copies) {
                            printer?.openPrnCutter(1)
                        }
                    }
                    if (DEBUG) Log.d(TAG, "printPdf: pages=${pdfRenderer.pageCount} copies=$copies mode=$imageModeStr")
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

    private fun handleCancelPrint(result: Result) {
        result.success(false)
    }

    private fun handlePrintWithSystem(call: MethodCall, result: Result) {
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
                printHelper.printBitmap("Print", bitmap)
                if (DEBUG) Log.d(TAG, "printWithSystem")
                result.success(true)
            } ?: run {
                result.error("printerNotAvailable", "Activity not available", null)
            }
        } catch (e: Exception) {
            result.error("invalidImage", "Failed to print with system: ${e.message}", null)
        }
    }

    private fun mapToPrnStrFormat(map: Map<String, Any?>): PrnStrFormat {
        val format = PrnStrFormat()
        format.setTextSize((map["textSize"] as? Number)?.toInt() ?: 24)

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
                    if (path.startsWith("assets/") || !path.startsWith("/")) {
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
