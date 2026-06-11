package com.example.zcs_printing

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.File

enum class ImageProcessingMode {
    SIMPLE_THRESHOLD,
    ADAPTIVE_THRESHOLD,
    FLOYD_STEINBERG
}

class PdfImageProcessor(
    private val mode: ImageProcessingMode = ImageProcessingMode.ADAPTIVE_THRESHOLD,
    private val threshold: Int = 128,
    private val gamma: Float = 1.4f,
    private val renderScale: Int = 3
) {

    companion object {
        private const val TAG = "PdfImageProcessor"
        private const val ADAPTIVE_BLOCK_SIZE = 21
        private const val ADAPTIVE_C = 8
        private const val BACKGROUND_CLEANUP_LUMINANCE = 240
    }

    fun processPdfPage(
        page: PdfRenderer.Page,
        targetWidthPx: Int
    ): Bitmap {
        val renderWidth = targetWidthPx * renderScale
        val renderHeight = (page.height.toFloat() / page.width * renderWidth).toInt()

        val highResBitmap = Bitmap.createBitmap(renderWidth, renderHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(highResBitmap)
        canvas.drawColor(Color.WHITE)
        page.render(highResBitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)

        val grayBitmap = convertToGrayscale(highResBitmap)
        highResBitmap.recycle()

        val gammaCorrected = applyGamma(grayBitmap)
        val cleaned = backgroundCleanup(gammaCorrected)

        val monoBitmap = when (mode) {
            ImageProcessingMode.SIMPLE_THRESHOLD -> simpleThreshold(cleaned)
            ImageProcessingMode.ADAPTIVE_THRESHOLD -> adaptiveThreshold(cleaned)
            ImageProcessingMode.FLOYD_STEINBERG -> floydSteinberg(cleaned)
        }
        cleaned.recycle()

        return downscaleToWidth(monoBitmap, targetWidthPx)
    }

    fun processBitmap(
        bitmap: Bitmap,
        targetWidthPx: Int,
        convertToMonochrome: Boolean = false
    ): Bitmap {
        if (!convertToMonochrome) {
            return scaleBitmapNearestNeighbor(bitmap, targetWidthPx)
        }

        val grayBitmap = convertToGrayscale(bitmap)
        val gammaCorrected = applyGamma(grayBitmap)
        val cleaned = backgroundCleanup(gammaCorrected)

        val monoBitmap = when (mode) {
            ImageProcessingMode.SIMPLE_THRESHOLD -> simpleThreshold(cleaned)
            ImageProcessingMode.ADAPTIVE_THRESHOLD -> adaptiveThreshold(cleaned)
            ImageProcessingMode.FLOYD_STEINBERG -> floydSteinberg(cleaned)
        }
        cleaned.recycle()

        return downscaleToWidth(monoBitmap, targetWidthPx)
    }

    private fun convertToGrayscale(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        for (i in pixels.indices) {
            val color = pixels[i]
            val a = (color shr 24) and 0xFF
            val r = (color shr 16) and 0xFF
            val g = (color shr 8) and 0xFF
            val b = color and 0xFF

            val alphaFactor = a.toFloat() / 255f
            val blendedR = (r * alphaFactor + 255 * (1f - alphaFactor)).toInt()
            val blendedG = (g * alphaFactor + 255 * (1f - alphaFactor)).toInt()
            val blendedB = (b * alphaFactor + 255 * (1f - alphaFactor)).toInt()

            val luminance = (0.299 * blendedR + 0.587 * blendedG + 0.114 * blendedB).toInt()
            pixels[i] = Color.argb(255, luminance, luminance, luminance)
        }

        result.setPixels(pixels, 0, width, 0, 0, width, height)
        return result
    }

    private fun applyGamma(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        val gammaCorrection = 1f / gamma
        for (i in pixels.indices) {
            val gray = Color.red(pixels[i])
            val corrected = (255f * Math.pow(gray / 255.0, gammaCorrection.toDouble())).toInt().coerceIn(0, 255)
            pixels[i] = Color.argb(255, corrected, corrected, corrected)
        }

        result.setPixels(pixels, 0, width, 0, 0, width, height)
        return result
    }

    private fun backgroundCleanup(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        for (i in pixels.indices) {
            val gray = Color.red(pixels[i])
            if (gray > BACKGROUND_CLEANUP_LUMINANCE) {
                pixels[i] = Color.WHITE
            } else {
                pixels[i] = pixels[i]
            }
        }

        result.setPixels(pixels, 0, width, 0, 0, width, height)
        return result
    }

    private fun simpleThreshold(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        for (i in pixels.indices) {
            val gray = Color.red(pixels[i])
            val monoColor = if (gray < threshold) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
            pixels[i] = monoColor
        }

        result.setPixels(pixels, 0, width, 0, 0, width, height)
        return result
    }

    private fun adaptiveThreshold(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        val gray = IntArray(width * height) { Color.red(pixels[it]) }
        val integral = Array(height + 1) { IntArray(width + 1) }

        for (y in 0 until height) {
            for (x in 0 until width) {
                integral[y + 1][x + 1] = gray[y * width + x] +
                    integral[y][x + 1] +
                    integral[y + 1][x] -
                    integral[y][x]
            }
        }

        val halfBlock = ADAPTIVE_BLOCK_SIZE / 2
        for (y in 0 until height) {
            for (x in 0 until width) {
                val x1 = (x - halfBlock).coerceAtLeast(0)
                val x2 = (x + halfBlock).coerceAtMost(width - 1)
                val y1 = (y - halfBlock).coerceAtLeast(0)
                val y2 = (y + halfBlock).coerceAtMost(height - 1)

                val count = (x2 - x1 + 1) * (y2 - y1 + 1)
                val sum = integral[y2 + 1][x2 + 1] -
                    integral[y1][x2 + 1] -
                    integral[y2 + 1][x1] +
                    integral[y1][x1]
                val mean = sum / count

                val monoColor = if (gray[y * width + x] < mean - ADAPTIVE_C) {
                    0xFF000000.toInt()
                } else {
                    0xFFFFFFFF.toInt()
                }
                pixels[y * width + x] = monoColor
            }
        }

        result.setPixels(pixels, 0, width, 0, 0, width, height)
        return result
    }

    private fun floydSteinberg(bitmap: Bitmap): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        val gray = FloatArray(width * height) { Color.red(pixels[it]).toFloat() }

        for (y in 0 until height) {
            for (x in 0 until width) {
                val index = y * width + x
                val oldPixel = gray[index]
                val newPixel = if (oldPixel < threshold) 0f else 255f
                gray[index] = newPixel

                val error = oldPixel - newPixel

                if (x + 1 < width) {
                    gray[index + 1] += error * 7f / 16f
                }
                if (y + 1 < height) {
                    if (x - 1 >= 0) {
                        gray[index + width - 1] += error * 3f / 16f
                    }
                    gray[index + width] += error * 5f / 16f
                    if (x + 1 < width) {
                        gray[index + width + 1] += error * 1f / 16f
                    }
                }
            }
        }

        for (i in pixels.indices) {
            val value = gray[i].toInt().coerceIn(0, 255)
            val monoColor = if (value < threshold) 0xFF000000.toInt() else 0xFFFFFFFF.toInt()
            pixels[i] = monoColor
        }

        result.setPixels(pixels, 0, width, 0, 0, width, height)
        return result
    }

    private fun downscaleToWidth(bitmap: Bitmap, targetWidth: Int): Bitmap {
        if (bitmap.width <= targetWidth) return bitmap
        val scale = targetWidth.toFloat() / bitmap.width
        val targetHeight = (bitmap.height * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, false)
    }

    private fun scaleBitmapNearestNeighbor(bitmap: Bitmap, targetWidth: Int): Bitmap {
        if (bitmap.width <= 0) return bitmap
        val scale = targetWidth.toFloat() / bitmap.width
        val targetHeight = (bitmap.height * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, false)
    }
}
