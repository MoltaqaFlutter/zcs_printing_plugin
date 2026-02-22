import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zcs_printing/zcs_printing.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Maximum number of copies allowed per print job
const int _maxCopies = 4;

class _MyAppState extends State<MyApp> {
  final IPrintingServiceInterface _printer = PrinterPlugin();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  String _status = 'Not initialized';
  bool _supportsCutter = false;
  bool _isLoading = false;
  /// Total number of print jobs completed (incremented on each successful print)
  int _printCount = 0;
  /// Number of copies to print (1 to _maxCopies)
  int _copiesCount = 1;

  @override
  void initState() {
    super.initState();
    // Defer printer status check until after first frame to avoid splash freeze on debug run
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrinterStatus(isInitial: true);
    });
  }

  Future<void> _checkPrinterStatus({bool isInitial = false}) async {
    if (!isInitial) {
      setState(() => _isLoading = true);
    }
    try {
      final status = await _printer.getPrinterStatus();
      final supportsCutter = await _printer.isSupportCutter();
      setState(() {
        _status = 'Status: ${status.name}';
        _supportsCutter = supportsCutter;
        _isLoading = false;
      });
      if (!isInitial) _showToast('Printer status updated', Colors.green);
    } on PrinterError catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
        _isLoading = false;
      });
      _showToast('Failed to check status: ${e.message}', Colors.red);
    } catch (e) {
      setState(() {
        _status = 'Error: Unknown error';
        _isLoading = false;
      });
      _showToast('Unexpected error: $e', Colors.red);
    }
  }

  Future<void> _printTestReceipt() async {
    setState(() => _isLoading = true);
    try {
      // Check printer status first
      final status = await _printer.getPrinterStatus();
      if (status == PrinterStatus.error || status == PrinterStatus.offline) {
        setState(() => _isLoading = false);
        _showToast('Printer not available. Please check connection.', Colors.red);
        return;
      }

      final format = PrintFormats.normal;
      final headerFormat = PrintFormats.header;

      // Build receipt content
      await _printer.appendText('TEST RECEIPT', headerFormat);
      await _printer.appendEmptyLines(count: 1); // Use new spacing method
      await _printer.appendText('Date: ${DateTime.now()}', format);
      await _printer.appendEmptyLines(count: 1);
      
      // Table header
      await _printer.appendStrings(
        ['Item', 'Qty', 'Price'],
        [2, 1, 1],
        [format, format, PrintFormats.rightAligned],
      );
      
      // Table row
      await _printer.appendStrings(
        ['Apple', '2', '\$5.00'],
        [2, 1, 1],
        [format, format, PrintFormats.rightAligned],
      );
      
      await _printer.appendEmptyLines(count: 1);
      await _printer.appendText('Total: \$5.00', PrintFormats.bold);
      await _printer.appendEmptyLines(count: 1);
      await _printer.appendQrCode('https://example.com/receipt/123');

      final copies = _copiesCount.clamp(1, _maxCopies);
      final success = await _printer.startPrint(
        copies: copies,
        cutAfterEachCopy: _supportsCutter,
        spacingBetweenCopies: copies > 1 ? 2 : 0,
      );
      
      setState(() {
        _isLoading = false;
        if (success) _printCount++;
      });
      if (success) {
        _showToast('Receipt printed! $copies copy/copies. Total jobs: $_printCount', Colors.green);
      } else {
        _showToast('Print failed - check printer status', Colors.red);
      }
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      final errorMsg = _getErrorMessage(e);
      _showToast('Print error: $errorMsg', Colors.red);
      debugPrint('Receipt PrinterError: ${e.code} - ${e.message}');
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
      debugPrint('Receipt unexpected error: $e\n$stackTrace');
    }
  }

  Future<void> _printQRCode() async {
    setState(() => _isLoading = true);
    try {
      // Check printer status first
      final status = await _printer.getPrinterStatus();
      if (status == PrinterStatus.error || status == PrinterStatus.offline) {
        setState(() => _isLoading = false);
        _showToast('Printer not available. Please check connection.', Colors.red);
        return;
      }

      final format = PrintFormats.header;
      await _printer.appendText('QR CODE TEST', format);
      await _printer.appendEmptyLines(count: 1);
      
      // Print QR code with custom size
      await _printer.appendQrCode(
        'https://example.com/qr-test',
        width: 300,
        height: 300,
        alignment: 'center',
      );
      await _printer.appendEmptyLines(count: 1);
      await _printer.appendText('Scan this QR code', PrintFormats.center);

      final copies = _copiesCount.clamp(1, _maxCopies);
      final success = await _printer.startPrint(
        copies: copies,
        cutAfterEachCopy: _supportsCutter,
      );
      setState(() {
        _isLoading = false;
        if (success) _printCount++;
      });
      if (success) {
        _showToast('QR Code printed! Jobs: $_printCount', Colors.green);
      } else {
        _showToast('QR Code print failed - check printer status', Colors.red);
      }
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      final errorMsg = _getErrorMessage(e);
      _showToast('QR Code error: $errorMsg', Colors.red);
      debugPrint('QR Code PrinterError: ${e.code} - ${e.message}');
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
      debugPrint('QR Code unexpected error: $e\n$stackTrace');
    }
  }

  Future<void> _printImage() async {
    setState(() => _isLoading = true);
    try {
      // Check printer status first
      final status = await _printer.getPrinterStatus();
      if (status == PrinterStatus.error || status == PrinterStatus.offline) {
        setState(() => _isLoading = false);
        _showToast('Printer not available. Please check connection.', Colors.red);
        return;
      }

      // Pick image from gallery
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) {
        setState(() => _isLoading = false);
        _showToast('No image selected', Colors.orange);
        return;
      }

      // Read image bytes
      final Uint8List imageBytes = await image.readAsBytes();

      // Print image
      await _printer.appendText('IMAGE PRINT TEST', PrintFormats.header);
      await _printer.appendEmptyLines(count: 1);
      await _printer.appendBitmap(
        imageBytes: imageBytes,
        alignment: 'center',
      );
      await _printer.appendEmptyLines(count: 1);

      final copies = _copiesCount.clamp(1, _maxCopies);
      final success = await _printer.startPrint(
        copies: copies,
        cutAfterEachCopy: _supportsCutter,
      );
      setState(() {
        _isLoading = false;
        if (success) _printCount++;
      });
      if (success) {
        _showToast('Image printed! Jobs: $_printCount', Colors.green);
      } else {
        _showToast('Image print failed - check printer status', Colors.red);
      }
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      _showToast('Image error: ${_getErrorMessage(e)}', Colors.red);
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
      debugPrint('Image unexpected error: $e\n$stackTrace');
    }
  }

  Future<void> _printPDF() async {
    setState(() => _isLoading = true);
    try {
      // Check printer status first
      final status = await _printer.getPrinterStatus();
      if (status == PrinterStatus.error || status == PrinterStatus.offline) {
        setState(() => _isLoading = false);
        _showToast('Printer not available. Please check connection.', Colors.red);
        return;
      }

      // Pick PDF file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _isLoading = false);
        _showToast('No PDF file selected', Colors.orange);
        return;
      }

      // Read PDF bytes
      final File pdfFile = File(result.files.single.path!);
      final Uint8List pdfBytes = await pdfFile.readAsBytes();

      final copies = _copiesCount.clamp(1, _maxCopies);
      final success = await _printer.printPdf(
        pdfBytes,
        copies: copies,
        cutAfterEachCopy: _supportsCutter,
        cutBetweenPages: false,
      );
      setState(() {
        _isLoading = false;
        if (success) _printCount++;
      });
      if (success) {
        _showToast('PDF printed! Jobs: $_printCount', Colors.green);
      } else {
        _showToast('PDF print failed - check printer status', Colors.red);
      }
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      _showToast('PDF error: ${_getErrorMessage(e)}', Colors.red);
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
      debugPrint('PDF unexpected error: $e\n$stackTrace');
    }
  }

  Future<void> _printBarcode() async {
    setState(() => _isLoading = true);
    try {
      // Check printer status first
      final status = await _printer.getPrinterStatus();
      if (status == PrinterStatus.error || status == PrinterStatus.offline) {
        setState(() => _isLoading = false);
        _showToast('Printer not available. Please check connection.', Colors.red);
        return;
      }

      final format = PrintFormats.header;
      await _printer.appendText('BARCODE TEST', format);
      await _printer.appendEmptyLines(count: 1);
      
      // Print CODE_128 barcode
      await _printer.appendBarcode(
        '6922711079066',
        format: 'CODE_128',
        width: 360,
        height: 100,
        showText: true,
        alignment: 'center',
      );
      await _printer.appendEmptyLines(count: 1);
      await _printer.appendText('Barcode: 6922711079066', PrintFormats.center);

      final copies = _copiesCount.clamp(1, _maxCopies);
      final success = await _printer.startPrint(
        copies: copies,
        cutAfterEachCopy: _supportsCutter,
      );
      setState(() {
        _isLoading = false;
        if (success) _printCount++;
      });
      if (success) {
        _showToast('Barcode printed! Jobs: $_printCount', Colors.green);
      } else {
        _showToast('Barcode print failed - check printer status', Colors.red);
      }
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      _showToast('Barcode error: ${_getErrorMessage(e)}', Colors.red);
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
      debugPrint('Barcode unexpected error: $e\n$stackTrace');
    }
  }

  /// Cut paper manually
  Future<void> _cutPaper() async {
    if (!_supportsCutter) {
      _showToast('Cutter not supported on this device', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _printer.cutPaper();
      setState(() => _isLoading = false);
      _showToast('Paper cut successfully', Colors.green);
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      _showToast('Cut failed: ${_getErrorMessage(e)}', Colors.red);
    } catch (e) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
    }
  }

  /// Print with Android system print dialog
  Future<void> _printWithSystem() async {
    setState(() => _isLoading = true);
    try {
      // Pick image from gallery to print
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) {
        setState(() => _isLoading = false);
        _showToast('No image selected', Colors.orange);
        return;
      }

      final Uint8List imageBytes = await image.readAsBytes();
      final copies = _copiesCount.clamp(1, _maxCopies);
      
      final success = await _printer.printWithSystem(
        imageBytes,
        copies: copies,
        cutAfterEachCopy: false, // System print doesn't support cutter
      );
      
      setState(() {
        _isLoading = false;
        if (success) _printCount++;
      });
      
      if (success) {
        _showToast('System print dialog opened! Jobs: $_printCount', Colors.green);
      } else {
        _showToast('Failed to open system print dialog', Colors.red);
      }
    } on PrinterError catch (e) {
      setState(() => _isLoading = false);
      _showToast('System print error: ${_getErrorMessage(e)}', Colors.red);
      debugPrint('System print PrinterError: ${e.code} - ${e.message}');
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      _showToast('Unexpected error: $e', Colors.red);
      debugPrint('System print unexpected error: $e\n$stackTrace');
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(PrinterError error) {
    switch (error.code) {
      case PrinterErrorCode.platformUnsupported:
        return 'This feature is only available on Android';
      case PrinterErrorCode.printerNotAvailable:
        return 'Printer is not available. Check connection.';
      case PrinterErrorCode.paperOut:
        return 'Printer is out of paper';
      case PrinterErrorCode.invalidArgument:
        return 'Invalid input: ${error.message}';
      case PrinterErrorCode.invalidImage:
        return 'Invalid image format';
      case PrinterErrorCode.invalidPdf:
        return 'Invalid PDF file';
      case PrinterErrorCode.bufferEmpty:
        return 'Nothing to print. Add content first.';
      case PrinterErrorCode.cutterNotSupported:
        return 'Cutter not supported on this device';
      case PrinterErrorCode.unknown:
        return error.message.isNotEmpty ? error.message : 'Unknown error occurred';
    }
  }

  /// Show toast message (using SnackBar)
  void _showToast(String message, Color color) {
    // Ensure we're on the UI thread and widget is mounted
    if (!mounted) {
      debugPrint('Toast (not mounted): $message');
      return;
    }
    
    // Use a post-frame callback to ensure the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        debugPrint('Toast (not mounted after frame): $message');
        return;
      }
      
      // Try GlobalKey first (most reliable)
      final messenger = _scaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger.showSnackBar(_buildSnackBar(message, color));
        return;
      }
      
      // Fallback: try to get from context
      try {
        final contextMessenger = ScaffoldMessenger.maybeOf(context);
        if (contextMessenger != null) {
          contextMessenger.showSnackBar(_buildSnackBar(message, color));
          return;
        }
      } catch (e) {
        debugPrint('Toast context error: $e');
      }
      
      // Last resort: print to console
      debugPrint('Toast (could not display): $message');
    });
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green
                ? Icons.check_circle
                : color == Colors.red
                    ? Icons.error
                    : Icons.info,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.all(16),
      elevation: 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'ZCS Printing Example',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: false,
            elevation: 0,
          ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(context),
                    const SizedBox(height: 20),
                    _buildPrintTestsCard(context),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.print,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Printer Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _supportsCutter ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: _supportsCutter ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cutter: ${_supportsCutter ? "Supported" : "Not Supported"}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.numbers, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'Print jobs: ',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  '$_printCount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              children: [
                Text(
                  'Copies (max $_maxCopies): ',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                ...List.generate(_maxCopies, (i) {
                  final n = i + 1;
                  final selected = _copiesCount == n;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text('$n'),
                      selected: selected,
                      onSelected: _isLoading ? null : (v) => setState(() => _copiesCount = n),
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkPrinterStatus,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_supportsCutter) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _cutPaper,
                      icon: const Icon(Icons.content_cut, size: 20),
                      label: const Text(
                        'Cut Paper',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintTestsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.article,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Print Tests',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildPrintButton(
              'Print Test Receipt',
              Icons.receipt_long,
              _printTestReceipt,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildPrintButton(
              'Print QR Code',
              Icons.qr_code_2,
              _printQRCode,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildPrintButton(
              'Print Barcode',
              Icons.qr_code_scanner,
              _printBarcode,
              Colors.purple,
            ),
            const SizedBox(height: 12),
            _buildPrintButton(
              'Print Image',
              Icons.image,
              _printImage,
              Colors.teal,
            ),
            const SizedBox(height: 12),
            _buildPrintButton(
              'Print PDF',
              Icons.picture_as_pdf,
              _printPDF,
              Colors.red,
            ),
            const SizedBox(height: 12),
            _buildPrintButton(
              'Print with System',
              Icons.print_disabled,
              _printWithSystem,
              Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_status.contains('Error')) {
      return Colors.red;
    } else if (_status.contains('ok') || _status.contains('OK')) {
      return Colors.green;
    } else if (_status.contains('paperOut') || _status.contains('Paper')) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (_status.contains('Error')) {
      return Icons.error_outline;
    } else if (_status.contains('ok') || _status.contains('OK')) {
      return Icons.check_circle_outline;
    } else if (_status.contains('paperOut') || _status.contains('Paper')) {
      return Icons.warning_amber_rounded;
    } else {
      return Icons.info_outline;
    }
  }

  Widget _buildPrintButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
