import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  /// Public method to reload history from outside (called by MainNavigation)
  void reloadHistory() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyListStr = prefs.getStringList('submission_history') ?? [];
    
    setState(() {
      _historyData = historyListStr.map((str) {
        try {
          return jsonDecode(str) as Map<String, dynamic>;
        } catch (e) {
          return <String, dynamic>{};
        }
      }).where((map) => map.isNotEmpty).toList();
      
      // Sort so newest is first
      _historyData.sort((a, b) {
        final dateA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final dateB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return dateB.compareTo(dateA); // Descending order
      });
      
      _isLoading = false;
    });
  }

  Future<void> _deleteItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final historyListStr = prefs.getStringList('submission_history') ?? [];
    
    // The visual list is sorted descending. We need to find the correct item in raw storage.
    // However, recreating the string list order is easiest:
    setState(() {
      _historyData.removeAt(index);
    });

    final newStrings = _historyData.map((map) => jsonEncode(map)).toList();
    await prefs.setStringList('submission_history', newStrings);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Đã xóa 1 mục lịch sử'),
            ],
          ),
          backgroundColor: const Color(0xFF5F6368),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả báo cáo?'),
        content: const Text('Hành động này sẽ xóa vĩnh viễn toàn bộ lịch sử đã lưu. Không thể hoàn tác.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF5F6368))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa hết', style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('submission_history');
      setState(() {
        _historyData.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Lịch sử gửi Sheet',
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
          if (_historyData.isNotEmpty && !_isLoading)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Xóa toàn bộ lịch sử',
              color: const Color(0xFFEA4335),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyData.isEmpty
              ? _buildEmptyState()
              : _buildHistoryList(),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ]
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 56,
                color: Color(0xFFDADCE0),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có lịch sử nhập liệu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5F6368),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Các dữ liệu bạn gửi thành công\nsẽ được lưu lại tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _historyData.length,
      itemBuilder: (context, index) {
        final item = _historyData[index];
        final timestampStr = item['timestamp'] as String?;
        final dataValues = item['data'] as List<dynamic>? ?? [];
        final fieldNames = item['fields'] as List<dynamic>? ?? [];

        // Formatting timestamp properly
        String formattedDate = 'Không rõ ngày';
        if (timestampStr != null) {
          final dt = DateTime.tryParse(timestampStr);
          if (dt != null) {
             formattedDate = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
          }
        }

        return Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEA4335),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          onDismissed: (direction) => _deleteItem(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EAED)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Time and Delete btn)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF1A73E8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF202124),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: Colors.grey.shade400,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Xóa mục này',
                        onPressed: () => _deleteItem(index),
                      )
                    ],
                  ),
                ),
                // Divider
                Container(height: 1, color: const Color(0xFFE8EAED)),
                // Content Details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(dataValues.length, (i) {
                      final label = (i < fieldNames.length) ? fieldNames[i] : 'Trường ${i+1}';
                      final value = dataValues[i].toString();
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Color(0xFF5F6368),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Text(':  ', style: TextStyle(color: Color(0xFF5F6368))),
                            Expanded(
                              child: Text(
                                value.isEmpty ? '(trống)' : value,
                                style: TextStyle(
                                  color: value.isEmpty ? Colors.grey.shade400 : const Color(0xFF202124),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
