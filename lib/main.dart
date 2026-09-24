import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة الاتصال بقاعدة البيانات باستعمال رابطك ومفتاحك
  await Supabase.initialize(
    url: 'https://knogorwwypatqkbsuxhk.supabase.co',
    anonKey: 'sb_publishable_-07OsSRJ15aBaSfcFEdYcA_h0-nyMVy',
  );

  runApp(const SyrianDocScannerApp());
}

class SyrianDocScannerApp extends StatelessWidget {
  const SyrianDocScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ماسح الوثائق والبطاقات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ScannerHomeScreen(),
    );
  }
}

class ScannerHomeScreen extends StatefulWidget {
  const ScannerHomeScreen({super.key});

  @override
  State<ScannerHomeScreen> createState() => _ScannerHomeScreenState();
}

class _ScannerHomeScreenState extends State<ScannerHomeScreen> {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.pdf417,   // شفرات البطاقات الهوية والوثائق الرسمية
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );

  bool isProcessing = false;

  Future<void> _saveToSupabase(Barcode barcode) async {
    final String? rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => isProcessing = true);

    try {
      // إرسال البيانات الممسوحة مباشرة إلى جدول scanned_barcodes
      await Supabase.instance.client.from('scanned_barcodes').insert({
        'raw_content': rawValue,
        'barcode_format': barcode.format.name,
        'device_info': 'Syrian Doc Scanner Mobile',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم المسح وتخزين البيانات في Supabase بنجاح!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في عملية التخزين: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الوثائق والبطاقات'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !isProcessing) {
                _saveToSupabase(barcodes.first);
              }
            },
          ),
          Center(
            child: Container(
              width: 320,
              height: 190,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Text(
                    'وجه الكاميرا نحو الشفرة أو الـ QR',
                    style: TextStyle(
                      color: Colors.white,
                      backgroundColor: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'جاري الحفظ في Supabase...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose(); // تم التغلب على الخطأ المطبعي هنا
  }
}