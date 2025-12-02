import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../utils/validators.dart';

class ProfileFormWidget extends StatefulWidget {
  final UserProfile? initialProfile;
  final Function(UserProfile) onSave;
  final bool isLoading;

  const ProfileFormWidget({
    super.key,
    this.initialProfile,
    required this.onSave,
    this.isLoading = false,
  });

  @override
  State<ProfileFormWidget> createState() => _ProfileFormWidgetState();
}

class _ProfileFormWidgetState extends State<ProfileFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyNameController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _establishmentDateController;
  late final TextEditingController _employeeCountController;
  late final TextEditingController _locationRegionController;
  late final TextEditingController _techKeywordsController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final profile = widget.initialProfile;
    _companyNameController = TextEditingController(text: profile?.companyName ?? '');
    _businessTypeController = TextEditingController(text: profile?.businessType ?? '');
    _establishmentDateController = TextEditingController(text: profile?.establishmentDate ?? '');
    _employeeCountController = TextEditingController(text: profile?.employeeCount.toString() ?? '');
    _locationRegionController = TextEditingController(text: profile?.locationRegion ?? '');
    _techKeywordsController = TextEditingController(text: profile?.techKeywords.join(', ') ?? '');
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _businessTypeController.dispose();
    _establishmentDateController.dispose();
    _employeeCountController.dispose();
    _locationRegionController.dispose();
    _techKeywordsController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final profile = UserProfile(
        companyName: _companyNameController.text.trim(),
        businessType: _businessTypeController.text.trim(),
        establishmentDate: _establishmentDateController.text.trim(),
        employeeCount: int.parse(_employeeCountController.text.trim()),
        locationRegion: _locationRegionController.text.trim(),
        techKeywords: _techKeywordsController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
      widget.onSave(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompanyNameField(),
          const SizedBox(height: 16),
          _buildBusinessTypeField(),
          const SizedBox(height: 16),
          _buildEstablishmentDateField(),
          const SizedBox(height: 16),
          _buildEmployeeCountField(),
          const SizedBox(height: 16),
          _buildLocationRegionField(),
          const SizedBox(height: 16),
          _buildTechKeywordsField(),
          const SizedBox(height: 32),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildCompanyNameField() {
    return TextFormField(
      controller: _companyNameController,
      decoration: const InputDecoration(
        labelText: '회사명',
        hintText: '예: 주식회사 커서',
        prefixIcon: Icon(Icons.business),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: Validators.required,
    );
  }

  Widget _buildBusinessTypeField() {
    return TextFormField(
      controller: _businessTypeController,
      decoration: const InputDecoration(
        labelText: '주요 업종/사업 분야',
        hintText: '예: 인공지능 솔루션 개발',
        prefixIcon: Icon(Icons.work),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: Validators.required,
    );
  }

  Widget _buildEstablishmentDateField() {
    return TextFormField(
      controller: _establishmentDateController,
      decoration: const InputDecoration(
        labelText: '설립일',
        hintText: '예: 20231026',
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: Validators.establishmentDate,
    );
  }

  Widget _buildEmployeeCountField() {
    return TextFormField(
      controller: _employeeCountController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: '상시 근로자 수',
        hintText: '숫자만 입력 (예: 15)',
        prefixIcon: Icon(Icons.people),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: Validators.employeeCount,
    );
  }

  Widget _buildLocationRegionField() {
    return TextFormField(
      controller: _locationRegionController,
      decoration: const InputDecoration(
        labelText: '주요 사업장 소재지 (시/도)',
        hintText: '시/도 단위 입력 (예: 서울특별시)',
        prefixIcon: Icon(Icons.location_on),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: Validators.required,
    );
  }

  Widget _buildTechKeywordsField() {
    return TextFormField(
      controller: _techKeywordsController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: '핵심 키워드 (콤마로 구분)',
        hintText: '쉼표(,)로 구분하여 입력 (예: AI, 핀테크, 정부지원사업)',
        prefixIcon: Icon(Icons.label),
        border: OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      validator: Validators.techKeywords,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: widget.isLoading ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      icon: widget.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save),
      label: Text(widget.isLoading ? '저장 중...' : '프로필 저장'),
    );
  }
}