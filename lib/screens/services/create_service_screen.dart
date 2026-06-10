import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../models/service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_provider.dart';

class CreateServiceScreen extends ConsumerStatefulWidget {
  const CreateServiceScreen({super.key});

  @override
  ConsumerState<CreateServiceScreen> createState() =>
      _CreateServiceScreenState();
}

class _CreateServiceScreenState extends ConsumerState<CreateServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = ref.read(companyIdProvider);
    if (companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company not found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(serviceRepositoryProvider);
      final service = Service(
        id: '',
        companyId: companyId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
      );

      await repository.createService(service);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service created successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create service: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.04);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    return MeshBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'New Service',
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/services');
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Service name',
                      prefixIcon: const Icon(Icons.construction_outlined),
                      filled: true,
                      fillColor: fieldFill,
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a service name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      hintText: 'Price',
                      prefixIcon: const Icon(Icons.currency_pound_outlined),
                      filled: true,
                      fillColor: fieldFill,
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price < 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Description (optional)',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.notes_outlined),
                      ),
                      filled: true,
                      fillColor: fieldFill,
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFF4781F), width: 1.5),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveService,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF4781F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Create Service',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
