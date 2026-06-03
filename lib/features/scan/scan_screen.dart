import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/providers.dart';
import '../../core/services/ocr_service.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  bool _isPermissionChecked = false;
  bool _isProcessingOcr = false;
  File? _capturedImage;
  final RealOcrService _ocrService = RealOcrService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (mounted) {
      setState(() {
        _cameraStatus = status;
        _isPermissionChecked = true;
      });
    }
  }

  Future<void> _requestCameraPermission() async {
    // On Samsung, once permanently denied, request() is silently ignored.
    // Must redirect to system app settings instead.
    if (_cameraStatus.isPermanentlyDenied) {
      await openAppSettings();
      await _checkCameraPermission();
      return;
    }
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _cameraStatus = status);
      if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission denied. Please enable it in App Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Opens the native Android camera to capture a real photo.
  Future<void> _openCamera() async {
    if (_isProcessingOcr) return;

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (photo == null) return; // User cancelled

    await _runOcrOnImage(File(photo.path));
  }

  /// Opens the native photo gallery/library.
  Future<void> _openGallery() async {
    if (_isProcessingOcr) return;

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (photo == null) return; // User cancelled

    await _runOcrOnImage(File(photo.path));
  }

  /// Runs ML Kit OCR on the captured image file and shows parsed results.
  Future<void> _runOcrOnImage(File imageFile) async {
    setState(() {
      _capturedImage = imageFile;
      _isProcessingOcr = true;
    });

    try {
      // Run real on-device ML Kit text recognition
      final recognizedText = await _ocrService.recognizeText(imageFile);

      // Parse the raw OCR text into structured medicine entries
      final extractedMeds = await _ocrService.extractMedicines(recognizedText);

      if (!mounted) return;

      if (extractedMeds.isEmpty) {
        // OCR ran but parser found no recognisable medicine entries
        _showNoResultsDialog(recognizedText);
        return;
      }

      _showVerifyResultsSheet(extractedMeds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: ${e.toString().split('\n').first}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingOcr = false);
    }
  }

  /// Shown when ML Kit reads text but the parser finds no medicine entries.
  void _showNoResultsDialog(String rawText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('No Medicines Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The scanner could not extract medicine entries from this image. Tips:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('• Ensure the prescription is well-lit and in focus', style: TextStyle(fontSize: 12)),
            const Text('• Medicines should be in a numbered list (1. 2. ...)', style: TextStyle(fontSize: 12)),
            const Text('• Try scanning closer to the text', style: TextStyle(fontSize: 12)),
            if (rawText.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Raw text detected:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rawText.length > 200 ? '${rawText.substring(0, 200)}...' : rawText,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _capturedImage = null); // allow retake
            },
            child: const Text('Retake'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVerifyResultsSheet(List<Map<String, dynamic>> extractedMeds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _VerifyScanResultsWidget(
              extractedMeds: extractedMeds,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPermissionChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasPermission = _cameraStatus.isGranted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
      ),
      body: !hasPermission ? _buildPermissionWalkthrough() : _buildScanUI(),
    );
  }

  Widget _buildPermissionWalkthrough() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 24),
          const Text(
            'Camera Permission Required',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'To scan doctor prescription documents and automatically extract medications, MedTrack requires access to your device camera.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _requestCameraPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _cameraStatus.isPermanentlyDenied
                  ? 'Open App Settings'
                  : 'Grant Camera Access',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Real scan UI — shows captured image preview while processing,
  /// or the instruction card when idle.
  Widget _buildScanUI() {
    return Stack(
      children: [
        // Background: captured image preview OR dark idle state
        Positioned.fill(
          child: _capturedImage != null
              ? Image.file(
                  _capturedImage!,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.document_scanner_outlined,
                          size: 80,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap the camera button to scan\na prescription document',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Viewfinder corner overlay (only when idle)
        if (_capturedImage == null)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner markers
                  Positioned(top: 0, left: 0, child: _buildCorner(tl: true)),
                  Positioned(top: 0, right: 0, child: _buildCorner(tr: true)),
                  Positioned(bottom: 0, left: 0, child: _buildCorner(bl: true)),
                  Positioned(bottom: 0, right: 0, child: _buildCorner(br: true)),
                  const Center(
                    child: Text(
                      'Align prescription inside the frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // OCR processing overlay on top of captured image
        if (_isProcessingOcr)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing prescription...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Bottom control bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Retake / clear button (shown after capture)
                _capturedImage != null
                    ? IconButton(
                        tooltip: 'Retake',
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                        onPressed: _isProcessingOcr
                            ? null
                            : () => setState(() => _capturedImage = null),
                      )
                    : const SizedBox(width: 48),

                // Main shutter button — opens native camera
                GestureDetector(
                  onTap: _isProcessingOcr ? null : _openCamera,
                  child: Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isProcessingOcr ? Colors.grey : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                ),

                // Gallery picker button
                IconButton(
                  tooltip: 'Pick from Gallery',
                  icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                  onPressed: _isProcessingOcr ? null : _openGallery,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner({bool tl = false, bool tr = false, bool bl = false, bool br = false}) {
    const size = 24.0;
    const thickness = 3.0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          color: AppColors.primary,
          thickness: thickness,
          tl: tl, tr: tr, bl: bl, br: br,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool tl, tr, bl, br;

  _CornerPainter({
    required this.color,
    required this.thickness,
    this.tl = false,
    this.tr = false,
    this.bl = false,
    this.br = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    if (tl) {
      canvas.drawLine(Offset(0, h), const Offset(0, 0), paint);
      canvas.drawLine(const Offset(0, 0), Offset(w, 0), paint);
    }
    if (tr) {
      canvas.drawLine(Offset(0, 0), Offset(w, 0), paint);
      canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
    }
    if (bl) {
      canvas.drawLine(Offset(0, 0), Offset(0, h), paint);
      canvas.drawLine(Offset(0, h), Offset(w, h), paint);
    }
    if (br) {
      canvas.drawLine(Offset(w, 0), Offset(w, h), paint);
      canvas.drawLine(Offset(w, h), Offset(0, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Verification bottom sheet
// ---------------------------------------------------------------------------

class _VerifyScanResultsWidget extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> extractedMeds;
  final ScrollController scrollController;

  const _VerifyScanResultsWidget({
    required this.extractedMeds,
    required this.scrollController,
  });

  @override
  ConsumerState<_VerifyScanResultsWidget> createState() =>
      _VerifyScanResultsWidgetState();
}

class _VerifyScanResultsWidgetState
    extends ConsumerState<_VerifyScanResultsWidget> {
  String? _selectedPrescriptionId;
  late List<Map<String, dynamic>> _meds;

  @override
  void initState() {
    super.initState();
    _meds = List<Map<String, dynamic>>.from(
      widget.extractedMeds.map((m) => {...m, 'selected': true}),
    );

    final prescriptions = ref.read(prescriptionsProvider);
    if (prescriptions.isNotEmpty) {
      _selectedPrescriptionId = prescriptions.first.id;
    }
  }

  Future<void> _saveExtractedMeds() async {
    if (_selectedPrescriptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select or add a doctor prescription first.')),
      );
      return;
    }

    final selectedMeds = _meds.where((m) => m['selected'] == true).toList();
    if (selectedMeds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Use microsecondsSinceEpoch + index to guarantee unique Hive keys
    // even when the loop runs within the same millisecond.
    final baseTimestamp = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < selectedMeds.length; i++) {
      final m = selectedMeds[i];
      final id = '${baseTimestamp + i}_${m['name'].hashCode.abs()}';
      final medicine = Medicine(
        id: id,
        prescriptionId: _selectedPrescriptionId!,
        medicineNumber: 'MED-$id',
        name: m['name'],
        strength: m['strength'],
        intakePerDay: m['intakePerDay'],
        foodRelation: m['foodRelation'],
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: m['durationDays'] - 1)),
        durationDays: m['durationDays'],
        notes: 'Extracted from OCR scan.',
        reminderTimes: List<String>.from(m['reminderTimes']),
        alarmEnabled: false,
      );

      await ref.read(medicinesProvider.notifier).saveMedicine(medicine);
    }

    if (!mounted) return;

    // Capture router & data before closing the bottom sheet
    final router = GoRouter.of(context);
    final targetId = _selectedPrescriptionId!;
    final count = selectedMeds.length;

    Navigator.pop(context); // close sheet — context invalid after this

    // Fire-and-forget drive backup
    ref.read(driveServiceProvider).uploadBackup();

    // Navigate using captured router (avoids stale bottom-sheet context)
    router.push('/prescriptions/$targetId');

    ScaffoldMessenger.of(router.routerDelegate.navigatorKey.currentContext!)
        .showSnackBar(
      SnackBar(
        content: Text('Successfully imported $count medications!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prescriptions = ref.watch(prescriptionsProvider);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24.0),
      children: [
        Row(
          children: [
            Icon(Icons.verified_outlined, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Verify Scan Results',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'The following medications were extracted. Select a prescription to add them to.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Prescription selector
        const Text('Target Prescription',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (prescriptions.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: () {
              // Save the selected medicines to the pending provider so they
              // survive the navigation to the prescription form and back.
              final selectedMeds =
                  _meds.where((m) => m['selected'] == true).toList();
              if (selectedMeds.isNotEmpty) {
                ref.read(pendingScanMedicinesProvider.notifier).state =
                    selectedMeds;
              }
              Navigator.pop(context); // close sheet
              context.push('/prescriptions/add');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Prescription First'),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            value: _selectedPrescriptionId,
            items: prescriptions.map((p) {
              return DropdownMenuItem(value: p.id, child: Text(p.title));
            }).toList(),
            onChanged: (val) =>
                setState(() => _selectedPrescriptionId = val),
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ],
        const SizedBox(height: 24),

        // Extracted medicines checklist
        const Text('Extracted Medications',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _meds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final med = _meds[index];
            final bool isSelected = med['selected'] == true;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                title: Text(med['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${med['strength']} • ${med['intakePerDay']}x daily • ${med['foodRelation']} • ${med['durationDays']} Days'),
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _meds[index]['selected'] = val == true);
                },
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: prescriptions.isEmpty ? null : _saveExtractedMeds,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Import Checked Medicines',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
