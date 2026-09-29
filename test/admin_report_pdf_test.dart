import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('embedded report fonts render Vietnamese text in generated PDFs',
      () async {
    final regularFont =
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final boldFont = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final document = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(regularFont),
        bold: pw.Font.ttf(boldFont),
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text('Báo cáo doanh thu theo chợ'),
          pw.Text(
            'Nông dân tích cực nhất',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    final bytes = await document.save();
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
