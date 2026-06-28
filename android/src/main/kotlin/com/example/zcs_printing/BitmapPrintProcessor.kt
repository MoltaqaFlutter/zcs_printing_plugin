package com.example.zcs_printing

import android.content.Context
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.pdf.PdfRenderer
import kotlin.math.pow
import java.io.File
import java.io.FileOutputStream
import kotlin.math.roundToInt

/**
 * Prepares PDF pages and bitmap images for ZCS thermal printing.
 * Uses supersampling, contrast normalization, and adaptive binarization
 * to reduce fuzzy/muddy text on PDF and image jobs.
 */
class BitmapPrintProcessor(
    private val maxPrinterWidthPx: Int,
    private val debugSaveEnabled: Boolean = false,
    private val cacheDir: File? = null,
) {
    data class Options(
        val renderScale: Float = DEFAULT_RENDER_SCALE,
        val binarizationThreshold: Int? = null,
        val printGray: Int = DEFAULT_PRINT_GRAY,
        val useMonochromeConversion: Boolean = true,
        val allowUpscale: Boolean = true,
    )

    fun configurePrintDensity(printGray: Int, setPrintGray: (Int) -> Unit) {
        setPrintGray(printGray.coerceIn(0, 5))
    }

    fun renderPdfPageSupersampled(
        page: PdfRenderer.Page,
        targetWidth: Int,
        options: Options = Options(),
    ): Bitmap {
        val alignedTargetWidth = alignBitmapWidth(targetWidth, allowUpscale = true)
        val scaleFactor = options.renderScale.coerceIn(1.0f, MAX_RENDER_SCALE)
        val renderWidth = (alignedTargetWidth * scaleFactor).roundToInt().coerceAtLeast(alignedTargetWidth)

        val pageScale = renderWidth.toFloat() / page.width
        val renderHeight = (page.height * pageScale).toInt().coerceAtLeast(1)
        val highRes = Bitmap.createBitmap(renderWidth, renderHeight, Bitmap.Config.ARGB_8888)
        highRes.eraseColor(Color.WHITE)
        val matrix = Matrix().apply { setScale(pageScale, pageScale) }
        page.render(highRes, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)

        return if (renderWidth == alignedTargetWidth) {
            highRes
        } else {
            val downscaled = scaleBitmapHighQuality(highRes, alignedTargetWidth)
            highRes.recycle()
            downscaled
        }
    }

    fun prepareBitmapForPrinter(
        source: Bitmap,
        maxWidth: Int,
        options: Options = Options(),
    ): Bitmap {
        val alignedMaxWidth = alignBitmapWidth(maxWidth, options.allowUpscale)
        val targetWidth = if (options.allowUpscale) {
            alignedMaxWidth
        } else {
            alignBitmapWidth(minOf(source.width, alignedMaxWidth), allowUpscale = false)
        }

        val scaleFactor = options.renderScale.coerceIn(1.0f, MAX_RENDER_SCALE)
        val scaled = when {
            source.width == targetWidth -> source
            !options.allowUpscale && source.width < targetWidth -> source
            else -> scaleBitmapSupersampled(source, targetWidth, scaleFactor)
        }

        val output = if (options.useMonochromeConversion) {
            toMonochromeBitmap(scaled, options.binarizationThreshold)
        } else {
            if (scaled !== source) {
                Bitmap.createBitmap(scaled)
            } else {
                source.copy(source.config ?: Bitmap.Config.ARGB_8888, false)
            }
        }

        if (scaled !== source && scaled !== output) {
            scaled.recycle()
        }

        if (debugSaveEnabled && cacheDir != null) {
            saveDebugBitmap(output)
        }

        return output
    }

    fun decodeBitmapFromBytes(imageBytes: ByteArray, targetWidth: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, bounds)
        val decodeTarget = (targetWidth * DEFAULT_RENDER_SCALE).roundToInt()
        val decodeOptions = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = calculateInSampleSize(bounds, decodeTarget)
        }
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, decodeOptions)
            ?: throw IllegalArgumentException("Failed to decode image bytes")
    }

    fun decodeBitmapFromPath(imagePath: String, targetWidth: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(imagePath, bounds)
        val decodeTarget = (targetWidth * DEFAULT_RENDER_SCALE).roundToInt()
        val decodeOptions = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = calculateInSampleSize(bounds, decodeTarget)
        }
        return BitmapFactory.decodeFile(imagePath, decodeOptions)
            ?: throw IllegalArgumentException("Failed to decode image at path: $imagePath")
    }

    fun parseOptions(call: io.flutter.plugin.common.MethodCall): Options {
        val renderScale = (call.argument<Number>("renderScale"))?.toFloat() ?: DEFAULT_RENDER_SCALE
        val binarizationThreshold = call.argument<Int>("binarizationThreshold")
        val printGray = call.argument<Int>("printGray") ?: DEFAULT_PRINT_GRAY
        val useMonochromeConversion = call.argument<Boolean>("useMonochromeConversion") ?: true
        return Options(
            renderScale = renderScale,
            binarizationThreshold = binarizationThreshold,
            printGray = printGray,
            useMonochromeConversion = useMonochromeConversion,
        )
    }

    private fun alignBitmapWidth(width: Int, allowUpscale: Boolean = true): Int {
        val clamped = width.coerceAtMost(maxPrinterWidthPx).coerceAtLeast(8)
        return ((clamped + 7) / 8) * 8
    }

    private fun scaleBitmapHighQuality(bitmap: Bitmap, targetWidth: Int): Bitmap {
        if (bitmap.width <= 0 || bitmap.width == targetWidth) return bitmap
        val scale = targetWidth.toFloat() / bitmap.width
        val targetHeight = (bitmap.height * scale).toInt().coerceAtLeast(1)
        val output = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
        output.eraseColor(Color.WHITE)
        val canvas = Canvas(output)
        val matrix = Matrix().apply { setScale(scale, scale) }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawBitmap(bitmap, matrix, paint)
        return output
    }

    /**
     * Two-pass scale via an intermediate resolution to reduce jagged edges on text.
     * Upscaling goes source -> intermediate (target * factor) -> target; downscaling
     * uses the same path so anti-aliased grays survive until binarization.
     */
    private fun scaleBitmapSupersampled(
        bitmap: Bitmap,
        targetWidth: Int,
        scaleFactor: Float,
    ): Bitmap {
        if (bitmap.width <= 0 || bitmap.width == targetWidth) return bitmap
        if (scaleFactor <= 1.0f) {
            return scaleBitmapHighQuality(bitmap, targetWidth)
        }

        val intermediateWidth = (targetWidth * scaleFactor).roundToInt()
            .coerceAtLeast(targetWidth + 1)
        val needsTwoPass = bitmap.width != intermediateWidth && intermediateWidth != targetWidth
        if (!needsTwoPass) {
            return scaleBitmapHighQuality(bitmap, targetWidth)
        }

        val intermediate = scaleBitmapHighQuality(bitmap, intermediateWidth)
        val result = scaleBitmapHighQuality(intermediate, targetWidth)
        if (intermediate !== bitmap) {
            intermediate.recycle()
        }
        return result
    }

    private fun toMonochromeBitmap(source: Bitmap, manualThreshold: Int?): Bitmap {
        val width = source.width
        val height = source.height
        val pixelCount = width * height
        val pixels = IntArray(pixelCount)
        source.getPixels(pixels, 0, width, 0, 0, width, height)

        val grayValues = IntArray(pixelCount)
        var validCount = 0
        for (i in pixels.indices) {
            val pixel = pixels[i]
            if (Color.alpha(pixel) < 128) {
                grayValues[i] = 255
            } else {
                grayValues[i] = luminance(pixel)
                validCount++
            }
        }

        if (validCount == 0) {
            return createWhiteBitmap(width, height)
        }

        val gammaCorrected = applyGammaCorrection(grayValues, TEXT_GAMMA)
        val normalized = normalizeContrast(gammaCorrected)
        applyUnsharpMask(normalized, width, height)
        val otsuThreshold = computeOtsuThreshold(normalized)
        val threshold = manualThreshold?.coerceIn(0, 255)
            ?: (otsuThreshold - TEXT_THRESHOLD_BIAS).coerceIn(0, 255)

        for (i in pixels.indices) {
            pixels[i] = if (normalized[i] < threshold) Color.BLACK else Color.WHITE
        }

        val output = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        output.setPixels(pixels, 0, width, 0, 0, width, height)
        return output
    }

    private fun luminance(pixel: Int): Int {
        return ((Color.red(pixel) * 0.299) +
            (Color.green(pixel) * 0.587) +
            (Color.blue(pixel) * 0.114)).roundToInt()
    }

    private fun applyGammaCorrection(grayValues: IntArray, gamma: Float): IntArray {
        if (gamma == 1.0f) return grayValues
        val invGamma = 1.0f / gamma
        val table = IntArray(256) { value ->
            (255.0 * (value / 255.0).pow(invGamma.toDouble())).roundToInt().coerceIn(0, 255)
        }
        val corrected = IntArray(grayValues.size)
        for (i in grayValues.indices) {
            val value = grayValues[i]
            corrected[i] = if (value >= 255) 255 else table[value]
        }
        return corrected
    }

    private fun normalizeContrast(grayValues: IntArray): IntArray {
        val sorted = grayValues.filter { it in 0..254 }.sorted()
        if (sorted.size < 16) return grayValues.copyOf()

        val lowIndex = (sorted.size * 0.02).roundToInt().coerceIn(0, sorted.lastIndex)
        val highIndex = (sorted.size * 0.98).roundToInt().coerceIn(0, sorted.lastIndex)
        val low = sorted[lowIndex]
        val high = sorted[highIndex]
        if (high <= low) return grayValues.copyOf()

        val normalized = IntArray(grayValues.size)
        for (i in grayValues.indices) {
            val value = grayValues[i]
            normalized[i] = when {
                value >= 255 -> 255
                else -> (((value - low).toFloat() / (high - low)) * 255f)
                    .roundToInt()
                    .coerceIn(0, 255)
            }
        }
        return normalized
    }

    private fun applyUnsharpMask(grayValues: IntArray, width: Int, height: Int) {
        val copy = grayValues.copyOf()
        for (y in 1 until height - 1) {
            for (x in 1 until width - 1) {
                val index = y * width + x
                if (copy[index] >= 255) continue
                var sum = 0
                for (dy in -1..1) {
                    for (dx in -1..1) {
                        sum += copy[(y + dy) * width + (x + dx)]
                    }
                }
                val blurred = sum / 9
                val sharpened = (copy[index] * 2.0f - blurred * 1.0f).roundToInt()
                grayValues[index] = sharpened.coerceIn(0, 255)
            }
        }
    }

    private fun computeOtsuThreshold(grayValues: IntArray): Int {
        val histogram = IntArray(256)
        var total = 0
        for (value in grayValues) {
            if (value >= 255) continue
            histogram[value]++
            total++
        }
        if (total == 0) return DEFAULT_FALLBACK_THRESHOLD

        var sum = 0
        for (i in 0..255) sum += i * histogram[i]

        var sumBackground = 0
        var weightBackground = 0
        var maxVariance = 0.0
        var threshold = DEFAULT_FALLBACK_THRESHOLD

        for (t in 0..255) {
            weightBackground += histogram[t]
            if (weightBackground == 0) continue
            val weightForeground = total - weightBackground
            if (weightForeground == 0) break

            sumBackground += t * histogram[t]
            val meanBackground = sumBackground.toDouble() / weightBackground
            val meanForeground = (sum - sumBackground).toDouble() / weightForeground
            val variance = weightBackground.toDouble() * weightForeground *
                (meanBackground - meanForeground) * (meanBackground - meanForeground)
            if (variance > maxVariance) {
                maxVariance = variance
                threshold = t
            }
        }
        return threshold
    }

    private fun calculateInSampleSize(bounds: BitmapFactory.Options, targetWidth: Int): Int {
        val width = bounds.outWidth
        if (width <= 0 || width <= targetWidth * 2) return 1
        var sampleSize = 1
        while (width / sampleSize > targetWidth * 2) {
            sampleSize *= 2
        }
        return sampleSize
    }

    private fun createWhiteBitmap(width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        return bitmap
    }

    private fun saveDebugBitmap(bitmap: Bitmap) {
        val dir = cacheDir ?: return
        try {
            val file = File(dir, "print_preview_${System.currentTimeMillis()}.png")
            FileOutputStream(file).use { stream ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            }
        } catch (_: Exception) {
            // Debug-only helper; ignore failures.
        }
    }

    companion object {
        const val DEFAULT_RENDER_SCALE = 2.5f
        const val DEFAULT_PRINT_GRAY = 3
        const val MAX_RENDER_SCALE = 4.0f
        private const val DEFAULT_FALLBACK_THRESHOLD = 140
        private const val TEXT_GAMMA = 1.25f
        private const val TEXT_THRESHOLD_BIAS = 10

        fun create(context: Context?, maxPrinterWidthPx: Int): BitmapPrintProcessor {
            val debugEnabled = (context?.applicationInfo?.flags?.and(ApplicationInfo.FLAG_DEBUGGABLE)) != 0
            return BitmapPrintProcessor(
                maxPrinterWidthPx = maxPrinterWidthPx,
                debugSaveEnabled = debugEnabled,
                cacheDir = context?.cacheDir,
            )
        }
    }
}
