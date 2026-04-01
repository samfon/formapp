import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../updater.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

import '../services/gemini_service.dart';
import '../services/sheet_service.dart';

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

  // AI & Sheets variables
  final TextEditingController _aiInputCtrl = TextEditingController();
  bool _isAiParsing = false;
  String _productFieldName = 'Sản phẩm';
  String _linkFieldName = 'Link';
  List<ProductItem> _products = [];

  // ⚠️ THAY ĐỔI URL NÀY BẰNG LINK APPS SCRIPT CỦA BẠN
  static const String _appsScriptUrl = 'https://script.google.com/macros/s/AKfycbwcJfCZjbZrcC7NHqJvAmquHwAMpK1fDkg2Dm0Bj9Zpf0U0cqC-I-29kHioVsa7P3LSYg/exec';

  @override
  void initState() {
    super.initState();
    _loadFields();
    
    // Auto check for updates when app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Updater.checkForUpdates(context);
    });
  }

  /// Public method to reload fields from outside (called by MainNavigation)
  void reloadFields() {
    _loadFields();
  }

  Future<void> _loadFields() async {
    final prefs = await SharedPreferences.getInstance();
    final fields = prefs.getStringList('field_names') ?? [];
    
    _productFieldName = prefs.getString('field_name_product') ?? 'Sản phẩm';
    _linkFieldName = prefs.getString('field_name_link') ?? 'Link';

    // Dispose old controllers
    for (var c in _controllers) {
      c.dispose();
    }

    // Load products concurrently if url is set
    List<ProductItem> loadedProducts = await SheetService.fetchProducts();

    setState(() {
      _fieldNames = fields;
      _controllers = fields.map((_) => TextEditingController()).toList();
      _products = loadedProducts;
      _isLoading = false;
    });
  }

  Future<void> _handleAiAnalyze() async {
    final rawText = _aiInputCtrl.text.trim();
    if (rawText.isEmpty || _fieldNames.isEmpty) return;

    setState(() => _isAiParsing = true);
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    try {
      final result = await GeminiService.analyzeText(rawText, _fieldNames);
      if (result != null) {
        setState(() {
           for (int i = 0; i < _fieldNames.length; i++) {
             final field = _fieldNames[i];
             if (result.containsKey(field) && result[field]!.isNotEmpty) {
               _controllers[i].text = result[field]!;
             }
           }
        });
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đã trích xuất thông tin thành công!'), backgroundColor: Color(0xFF1A73E8)),
           );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tính năng AI: $e'), backgroundColor: const Color(0xFFEA4335)),
         );
      }
    } finally {
      if (mounted) setState(() => _isAiParsing = false);
    }
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
        // Save to History
        final prefs = await SharedPreferences.getInstance();
        final historyListStr = prefs.getStringList('submission_history') ?? [];
        
        final newHistoryItem = {
          'timestamp': DateTime.now().toIso8601String(),
          'fields': _fieldNames,
          'data': values,
        };
        
        historyListStr.add(jsonEncode(newHistoryItem));
        await prefs.setStringList('submission_history', historyListStr);

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
                  Text('Đã lưu dữ liệu vào Sheet & Lịch sử!', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              backgroundColor: const Color(0xFF34A853),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
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
    _aiInputCtrl.dispose();
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
        // AI Input Form
        if (_fieldNames.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF9333EA), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Rút trích tự động bằng hình thức trò chuyện',
                      style: TextStyle(color: Color(0xFF9333EA), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    TextField(
                      controller: _aiInputCtrl,
                      minLines: 3,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Dán đoạn văn bản thô vào đây (Ví dụ: 'bán 2 hộp sữa vinamilk 100k ghi chú giao sớm')...",
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.purple.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.purple.shade300, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: _isAiParsing ? null : _handleAiAnalyze,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _isAiParsing
                           ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                           : const Text('Phân tích', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Header info
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              final fieldName = _fieldNames[index];
              final isProductField = fieldName.toLowerCase() == _productFieldName.toLowerCase();
              return _InputFieldCard(
                fieldName: fieldName,
                controller: _controllers[index],
                index: index,
                isProductField: isProductField,
                products: _products,
                onProductSelected: (ProductItem item) {
                  // Find link field index and fill it
                  int linkIndex = _fieldNames.indexWhere((f) => f.toLowerCase() == _linkFieldName.toLowerCase());
                  if (linkIndex != -1) {
                    _controllers[linkIndex].text = item.link;
                  }
                },
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
    this.isProductField = false,
    this.products = const [],
    this.onProductSelected,
  });

  final String fieldName;
  final TextEditingController controller;
  final int index;
  final bool isProductField;
  final List<ProductItem> products;
  final ValueChanged<ProductItem>? onProductSelected;

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
              if (isProductField && products.isNotEmpty) ...[
                 const Spacer(),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                   decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
                   child: Text('${products.length} SP', style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                 ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          
          if (isProductField && products.isNotEmpty)
            Autocomplete<ProductItem>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<ProductItem>.empty();
                }
                return products.where((ProductItem option) {
                  return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (ProductItem option) => option.name,
              onSelected: onProductSelected,
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                // Keep the autocomplete controller exactly synced with our generic controller
                // when user types or selects
                textEditingController.addListener(() {
                   if (controller.text != textEditingController.text) {
                     controller.text = textEditingController.text;
                   }
                });
                
                // If generic controller changes from outside (e.g. AI), update autocomplete view
                controller.addListener(() {
                   if (textEditingController.text != controller.text) {
                     textEditingController.text = controller.text;
                   }
                });

                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm $fieldName từ Google Sheet...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    suffixIcon: const Icon(Icons.search, size: 20),
                  ),
                  textInputAction: TextInputAction.next,
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (BuildContext context, int index) {
                          final ProductItem option = options.elementAt(index);
                          return InkWell(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(option.name, style: const TextStyle(fontSize: 14)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            )
          else 
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
