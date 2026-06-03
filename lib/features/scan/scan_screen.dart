import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final MockOcrService _ocrService = MockOcrService();

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
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _cameraStatus = status;
      });
    }
  }

  Future<void> _simulatePrescriptionScan() async {
    setState(() => _isProcessingOcr = true);
    
    try {
      // Simulate taking a picture and running OCR
      final recognizedText = await _ocrService.recognizeText(File('placeholder_prescription.jpg'));
      final extractedMeds = await _ocrService.extractMedicines(recognizedText);
      
      if (mounted) {
        _showVerifyResultsSheet(extractedMeds);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR Scan failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
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
      body: !hasPermission ? _buildPermissionWalkthrough() : _buildCameraViewfinder(),
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
            child: const Text('Grant Camera Access', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    return Stack(
      children: [
        // Camera Viewfinder Mockup
        Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Opacity(
              opacity: 0.15,
              child: Image.network(
                'https://images.unsplash.com/photo-1576091160550-2173dba999ef?q=80&w=600',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.assignment,
                  size: 200,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        // Scanner Viewfinder Grid Overlay
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCorner(16, 0, 0, 16),
                    _buildCorner(0, 16, 16, 0),
                  ],
                ),
                if (_isProcessingOcr)
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                else
                  const Text(
                    'Align prescription inside the box',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.black54,
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCorner(16, 0, 0, 16, isTop: false),
                    _buildCorner(0, 16, 16, 0, isTop: false),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Control Bar Overlays
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'ML-Kit Offline Text Recognition Engine Active',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flash toggle placeholder
                  IconButton(
                    icon: const Icon(Icons.flash_off, color: Colors.white, size: 28),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 32),
                  // Capture Button
                  GestureDetector(
                    onTap: _isProcessingOcr ? null : _simulatePrescriptionScan,
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
                          Icons.camera,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Photo library trigger placeholder
                  IconButton(
                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                    onPressed: _simulatePrescriptionScan, // Trigger same OCR simulation
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(double tl, double tr, double bl, double br, {bool isTop = true}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: isTop ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
          left: tl > 0 || bl > 0 ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
          right: tr > 0 || br > 0 ? BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
        ),
      ),
    );
  }
}

// Verification Modal sheet widget
class _VerifyScanResultsWidget extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> extractedMeds;
  final ScrollController scrollController;

  const _VerifyScanResultsWidget({
    required this.extractedMeds,
    required this.scrollController,
  });

  @override
  ConsumerState<_VerifyScanResultsWidget> createState() => _VerifyScanResultsWidgetState();
}

class _VerifyScanResultsWidgetState extends ConsumerState<_VerifyScanResultsWidget> {
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

  void _saveExtractedMeds() async {
    if (_selectedPrescriptionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a doctor prescription first.')),
      );
      return;
    }

    final selectedMeds = _meds.where((m) => m['selected'] == true).toList();
    if (selectedMeds.isEmpty) {
      Navigator.pop(context);
      return;
    }

    for (final m in selectedMeds) {
      final id = DateTime.now().millisecondsSinceEpoch.toString() + m['name'].hashCode.toString();
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

    // Trigger drive backup
    ref.read(driveServiceProvider).uploadBackup();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported ${selectedMeds.length} medications!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context); // close bottom sheet
      context.push('/prescriptions/$_selectedPrescriptionId');
    }
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'ML-Kit extracted the following medications. Check the list and select the prescription to add them to.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Prescription selector dropdown
        const Text('Target Prescription', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (prescriptions.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
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
            onChanged: (val) {
              setState(() => _selectedPrescriptionId = val);
            },
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ],
        const SizedBox(height: 24),

        // Extracted Doses Checklist
        const Text('Extracted Medications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _meds.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final med = _meds[index];
            final bool isSelected = med['selected'] == true;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${med['strength']} • ${med['intakePerDay']}x daily • ${med['foodRelation']} • ${med['durationDays']} Days'),
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _meds[index]['selected'] = val == true;
                  });
                },
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // Import Button
        ElevatedButton(
          onPressed: prescriptions.isEmpty ? null : _saveExtractedMeds,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Import Checked Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
