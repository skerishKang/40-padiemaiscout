import 'package:flutter/material.dart';
  final _companyNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _establishmentDateController = TextEditingController();
  final _employeeCountController = TextEditingController();
  final _locationRegionController = TextEditingController();
  final _techKeywordsController = TextEditingController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadProfileData();
    } else {
      setState(() { _isLoading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필을 보려면 로그인이 필요합니다.')),
        );
        Navigator.pop(context);
      });
    }
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

  Future<void> _loadProfileData() async {
    if (_currentUser == null) return;
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(_currentUser!.uid)
          .get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _companyNameController.text = data['companyName'] ?? '';
        _businessTypeController.text = data['businessType'] ?? '';
        _establishmentDateController.text = data['establishmentDate'] ?? '';
        _employeeCountController.text = data['employeeCount']?.toString() ?? '';
        _locationRegionController.text = data['locationRegion'] ?? '';
        _techKeywordsController.text = (data['techKeywords'] as List<dynamic>?)?.join(', ') ?? '';
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('프로필 로딩 중 오류 발생: ${e.toString()}')),
         );
      }
    } finally {
       if (mounted) {
          setState(() { _isLoading = false; });
       }
    }
  }

  Future<void> _saveProfileData() async {
    if (_currentUser == null) return;
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      try {
        final companyName = _companyNameController.text.trim();
        final businessType = _businessTypeController.text.trim();
        final establishmentDate = _establishmentDateController.text.trim();
        final employeeCount = int.tryParse(_employeeCountController.text.trim());
        final locationRegion = _locationRegionController.text.trim();
        final techKeywords = _techKeywordsController.text.split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final profileData = {
          'companyName': companyName,
          'businessType': businessType,
          'establishmentDate': establishmentDate,
          'employeeCount': employeeCount,
          'locationRegion': locationRegion,
          'techKeywords': techKeywords,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(_currentUser!.uid)
            .set(profileData, SetOptions(merge: true));
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('프로필이 성공적으로 저장되었습니다.')),
           );
           Navigator.pop(context);
        }
      } catch (e) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('프로필 저장 중 오류 발생: ${e.toString()}')),
            );
         }
      } finally {
         if (mounted) {
            setState(() { _isLoading = false; });
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회사 프로필 입력'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: '회사명',
                        hintText: '예: 주식회사 커서',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '회사명을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessTypeController,
                      decoration: const InputDecoration(
                        labelText: '주요 업종/사업 분야',
                        hintText: '예: 인공지능 솔루션 개발',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '업종/사업 분야를 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _establishmentDateController,
                      decoration: const InputDecoration(
                        labelText: '설립일',
                        hintText: '예: 20231026',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '설립일을 입력해주세요.';
                        }
                        final pattern = r'^\d{8}$';
                        if (!RegExp(pattern).hasMatch(value.trim())) {
                          return 'YYYYMMDD 8자리로 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _employeeCountController,
                      decoration: const InputDecoration(
                        labelText: '상시 근로자 수',
                        hintText: '숫자만 입력 (예: 15)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      keyboardType: TextInputType.number,
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '근로자 수를 입력해주세요.';
                        }
                        if (int.tryParse(value) == null) {
                          return '숫자만 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationRegionController,
                      decoration: const InputDecoration(
                        labelText: '주요 사업장 소재지 (시/도)',
                        hintText: '시/도 단위 입력 (예: 서울특별시)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '소재지를 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _techKeywordsController,
                      decoration: const InputDecoration(
                        labelText: '핵심 키워드 (콤마로 구분)',
                        hintText: '쉼표(,)로 구분하여 입력 (예: AI, 핀테크, 정부지원사업)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                       validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '키워드를 하나 이상 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfileData,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('프로필 저장'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
} 