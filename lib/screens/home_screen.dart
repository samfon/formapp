import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<String> _fieldNames = [];
  List<TextEditingController> _controllers = [];
  bool _isLoading = true;
  bool _isSending = false;

  // ⚠️ THAY ĐỔI URL NÀY BẰNG LINK APPS SCRIPT CỦA BẠN
  static const String _appsScriptUrl = 'https://script.google.com/macros/s/AKfycbwcJfCZjbZrcC7NHqJvAmquHwAMpK1fDkg2Dm0Bj9Zpf0U0cqC-I-29kHioVsa7P3LSYg/exec';

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  /// Public method to reload fields from outside (called by MainNavigation)
  void reloadFields() {
    _loadFields();
  }

  Future<void> _loadFields() async {
    final prefs = await SharedPreferences.getInstance();
    final fields = prefs.getStringList('field_names') ?? [];

    // Dispose old controllers
    for (var c in _controllers) {
      c.dispose();
    }

    setState(() {
      _fieldNames = fields;
      _controllers = fields.map((_) => TextEditingController()).toList();
      _isLoading = false;
    });
  }

  Future<void> _submitData() async {
    // Validate - check at least one field has content
    final values = _controllers.map((c) => c.text.trim()).toList();
    final hasContent = values.any((v) => v.isNotEmpty);

    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Vui lòng nhập ít nhất một trường dữ liệu',
                    style: TextStyle(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF9AB00),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final body = jsonEncode({'values': values});
      final response = await http.post(
        Uri.parse(_appsScriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        // Clear all fields on success
        for (var c in _controllers) {
          c.clear();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Đã lưu thành công!', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF34A853),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Server trả về mã lỗi ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Lỗi: ${e.toString()}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEA4335),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Nhập liệu',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EAED)),
        ),
        actions: [
          IconButton(
            onPressed: _loadFields,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại trường dữ liệu',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fieldNames.isEmpty
              ? _buildEmptyState()
              : _buildForm(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.settings_suggest_outlined,
                size: 56,
                color: Color(0xFF1A73E8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có cấu hình',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Vui lòng sang trang Cấu hình để tạo\ncác ô nhập liệu trước khi sử dụng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () {
                // Switch to Settings tab
                final navState = context.findAncestorStateOfType<MainNavigationState>();
                navState?.switchToTab(1);
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Đi đến Cấu hình', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A73E8),
                side: const BorderSide(color: Color(0xFF1A73E8)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Header info
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_chart_outlined, color: Color(0xFF1A73E8), size: 20),
              const SizedBox(width: 10),
              Text(
                '${_fieldNames.length} trường dữ liệu sẵn sàng',
                style: const TextStyle(
                  color: Color(0xFF1A73E8),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Form fields
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _fieldNames.length,
            itemBuilder: (context, index) {
              return _InputFieldCard(
                fieldName: _fieldNames[index],
                controller: _controllers[index],
                index: index,
              );
            },
          ),
        ),

        // Submit button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _submitData,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 22),
              label: Text(
                _isSending ? 'Đang gửi...' : 'Gửi lên Sheet',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34A853),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                shadowColor: const Color(0xFF34A853).withOpacity(0.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InputFieldCard extends StatelessWidget {
  const _InputFieldCard({
    required this.fieldName,
    required this.controller,
    required this.index,
  });

  final String fieldName;
  final TextEditingController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF1A73E8),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                fieldName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF5F6368),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Nhập $fieldName...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
            ),
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }
}
