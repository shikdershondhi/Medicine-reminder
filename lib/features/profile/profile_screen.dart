import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/providers.dart';
import '../../core/shared/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/shared/app_logo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;
  const ProfileScreen({super.key, this.isOnboarding = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;
  String _selectedSex = 'Male';

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _weightController = TextEditingController(text: profile.weight > 0 ? profile.weight.toString() : '');
    _ageController = TextEditingController(text: profile.age > 0 ? profile.age.toString() : '');
    _selectedSex = profile.sex.isNotEmpty ? profile.sex : 'Male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = UserProfile(
      name: _nameController.text.trim(),
      sex: _selectedSex,
      weight: double.tryParse(_weightController.text) ?? 0.0,
      age: int.tryParse(_ageController.text) ?? 0,
    );

    await ref.read(profileProvider.notifier).saveProfile(profile);
    
    // Trigger backup in background
    ref.read(driveServiceProvider).uploadBackup();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile saved successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
      if (widget.isOnboarding) {
        context.go('/dashboard');
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Complete Profile' : 'Edit Profile'),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isOnboarding) ...[
                const Center(
                  child: AppLogo(size: 48, padding: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome to MedTrack!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill in your basic health profile to help us manage your medicines and logs.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
              ],
              // Profile Picture Mockup
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                      child: Icon(
                        Icons.person_outline,
                        size: 50,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Name Input
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),
              // Sex Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSex,
                decoration: const InputDecoration(
                  labelText: 'Sex',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedSex = val);
                  }
                },
              ),
              const SizedBox(height: 20),
              // Weight Input
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter your weight';
                  if (double.tryParse(val) == null) return 'Please enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Age Input
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter your age';
                  if (int.tryParse(val) == null) return 'Please enter a valid integer';
                  return null;
                },
              ),
              const SizedBox(height: 40),
              // Save Button
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  widget.isOnboarding ? 'Save & Get Started' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
