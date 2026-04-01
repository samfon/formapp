import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  List<TextEditingController> _controllers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // New configurations (AI & Sheet)
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _sheetUrlCtrl = TextEditingController();
  final TextEditingController _productFieldCtrl = TextEditingController();
  final TextEditingController _linkFieldCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    final prefs = await SharedPreferences.getInstance();
    final fields = prefs.getStringList('field_names') ?? [];
    
    // Load AI & Sheet settings with defaults if empty
    _apiKeyCtrl.text = prefs.getString('gemini_api_key') ?? 'AIzaSyC5m_HpyGvVVl6FUd0p0gcYeaPSnKkb3Kw';
    _sheetUrlCtrl.text = prefs.getString('sheet_product_url') ?? 'https://docs.google.com/spreadsheets/d/12WhiBOELiCO0IJAxY1J1Z0Zd6oDGzXCM1ZjT6hCub4g/edit?gid=0#gid=0';
    _productFieldCtrl.text = prefs.getString('field_name_product') ?? 'Sản phẩm';
    _linkFieldCtrl.text = prefs.getString('field_name_link') ?? 'Link';

    setState(() {
      _controllers = fields.map((name) => TextEditingController(text: name)).toList();
      _isLoading = false;
    });
  }

  Future<void> _saveFields() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    
    // Save dynamic fields
    final names = _controllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    await prefs.setStringList('field_names', names);
    
    // Save AI & Sheet Settings
    await prefs.setString('gemini_api_key', _apiKeyCtrl.text.trim());
    await prefs.setString('sheet_product_url', _sheetUrlCtrl.text.trim());
    await prefs.setString('field_name_product', _productFieldCtrl.text.trim());
    await prefs.setString('field_name_link', _linkFieldCtrl.text.trim());

    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Đã lưu cấu hình thành công!', style: TextStyle(fontWeight: FontWeight.w500)),
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
  }

  void _addField() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeField(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
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
          'Cấu hình trường dữ liệu',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header info card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A73E8), Color(0xFF4285F4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A73E8).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.info_outline, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cấu Hình Trường Dữ Liệu',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Thêm các trường dữ liệu tương ứng với cột trên Google Sheet của bạn (Lưu ý: Tên phải khớp chính xác).',
                              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // AI CONFIGURATION UI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CẤU HÌNH AI & SHEET SẢN PHẨM',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF5F6368)),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingField(
                        controller: _apiKeyCtrl,
                        label: 'Gemini API Key',
                        icon: Icons.key_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingField(
                        controller: _sheetUrlCtrl,
                        label: 'Link Google Sheet chứa Sản Phẩm',
                        icon: Icons.link_rounded,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSettingField(
                              controller: _productFieldCtrl,
                              label: 'Tên trường "Sản phẩm" (nhập ở đưới)',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSettingField(
                              controller: _linkFieldCtrl,
                              label: 'Tên trường "Link" ảnh/web (nếu có)',
                              icon: Icons.insert_link_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: Color(0xFFE8EAED)),
                ),

                // Field count + Add button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_controllers.length} trường dữ liệu',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _addField,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Thêm trường', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F0FE),
                          foregroundColor: const Color(0xFF1A73E8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Fields list
                Expanded(
                  child: _controllers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'Chưa có trường dữ liệu nào',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bấm "Thêm trường" để bắt đầu',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _controllers.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex--;
                              final item = _controllers.removeAt(oldIndex);
                              _controllers.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            return _FieldCard(
                              key: ValueKey(_controllers[index]),
                              index: index,
                              controller: _controllers[index],
                              onDelete: () => _removeField(index),
                            );
                          },
                        ),
                ),

                // Save button
                if (_controllers.isNotEmpty)
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
                        onPressed: _isSaving ? null : _saveFields,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(_isSaving ? 'Đang lưu...' : 'Lưu cấu hình'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildSettingField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: Color(0xFF202124)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5F6368), fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF5F6368)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 1.5),
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    super.key,
    required this.index,
    required this.controller,
    required this.onDelete,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 6, right: 8, top: 4, bottom: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F0FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(Icons.drag_handle_rounded, color: Colors.grey.shade400, size: 20),
          ),
        ),
        title: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Nhập tên trường (VD: Sản phẩm)',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          color: const Color(0xFFEA4335),
          tooltip: 'Xóa trường này',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFCE8E6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}
