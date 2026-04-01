import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductItem {
  final String name;
  final String link;

  ProductItem({required this.name, required this.link});
}

class SheetService {
  static Future<List<ProductItem>> fetchProducts() async {
    final prefs = await SharedPreferences.getInstance();
    String sheetUrl = prefs.getString('sheet_product_url') ?? '';
    
    if (sheetUrl.isEmpty) {
      return [];
    }

    // Convert edit/view link to export CSV link
    if (sheetUrl.contains('/edit') || sheetUrl.contains('/view')) {
      sheetUrl = sheetUrl.replaceAll(RegExp(r'\/(edit|view).*'), '/export?format=csv');
    }

    try {
      final response = await http.get(Uri.parse(sheetUrl));
      if (response.statusCode == 200) {
        // Parse the CSV
        // Assuming Column 0 is Name, Column 1 is Link
        final converter = const CsvToListConverter();
        List<List<dynamic>> rows = converter.convert(response.body);
        
        List<ProductItem> items = [];
        
        // Skip header if first row looks like a header (optional, but good practice)
        // For simplicity, just convert all rows that have at least 1 column.
        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          if (row.isNotEmpty) {
            String name = row[0].toString().trim();
            // Ignore empty rows or pure header rows if needed
            if (name.isEmpty || name.toLowerCase() == 'tên sản phẩm' || name.toLowerCase() == 'product') {
              continue;
            }
            String link = row.length > 1 ? row[1].toString().trim() : '';
            items.add(ProductItem(name: name, link: link));
          }
        }
        return items;
      }
    } catch (e) {
      print('Failed to fetch sheet: $e');
    }
    
    return [];
  }
}
