import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static Future<Map<String, String>?> analyzeText(String input, List<String> fieldNames) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';
    
    if (apiKey.isEmpty) {
      throw Exception('API Key Gemini chưa được thiết lập trong phần Cấu hình.');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash', // Using faster, cheaper model
      apiKey: apiKey,
    );

    final fieldsList = fieldNames.map((e) => '"$e"').join(', ');
    
    final prompt = '''
Bạn là chuyên gia phân tích và bóc tách dữ liệu hội thoại, đơn hàng.
Văn bản đầu vào: "$input"

Hãy trích xuất thông tin và điền vào chính xác các trường dữ liệu sau: $fieldsList
Lưu ý:
- Trả về kết quả dưới dạng ĐÚNG MỘT khối JSON hợp lệ. KHÔNG CHỨA DẤU MARKDOWN (không dùng ```json).
- Các keys TRONG JSON PHẢI KHỚP CHÍNH XÁC VỚI CÁC TRƯỜNG Ở TRÊN.
- Nếu không tìm thấy thông tin phù hợp cho bất kỳ trường nào, hãy để giá trị là chuỗi rỗng "".
- Đối với số lượng, giá tiền, cố gắng chuẩn hóa thành số hoặc định dạng dễ đọc.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      
      if (text != null) {
         // Clean up potential markdown formatting if model didn't listen
        String cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final Map<String, dynamic> rawJson = jsonDecode(cleanJson);
        
        // Convert dynamic map to Map<String, String> ensuring keys match
        Map<String, String> result = {};
        for (var field in fieldNames) {
          result[field] = rawJson[field]?.toString() ?? '';
        }
        return result;
      }
    } catch (e) {
      throw Exception('Lỗi xử lý AI: ${e.toString()}');
    }
    return null;
  }
}
