import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('offline_scans');

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF0D9488),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
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
      BarcodeFormat.pdf417,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );

  final Box localBox = Hive.box('offline_scans');
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        _syncPendingScans();
      }
    });
    _syncPendingScans();
  }

  Future<void> _syncPendingScans() async {
    if (localBox.isEmpty) return;

    final keys = localBox.keys.toList();
    for (var key in keys) {
      final item = localBox.get(key);
      try {
        await Supabase.instance.client.from('scanned_barcodes').insert({
          'raw_content': item['raw_content'],
          'barcode_format': item['barcode_format'],
          'device_info': item['device_info'],
        });
        await localBox.delete(key);
      } catch (e) {
        break;
      }
    }
  }

  Future<void> _handleBarcodeScan(Barcode barcode) async {
    final String? rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => isProcessing = true);

    final scanData = {
      'raw_content': rawValue,
      'barcode_format': barcode.format.name,
      'device_info': 'Syrian Doc Scanner Mobile',
      'created_at': DateTime.now().toIso8601String(),
    };

    final connectivityResult = await Connectivity().checkConnectivity();
    final bool isOnline = !connectivityResult.contains(ConnectivityResult.none);

    if (isOnline) {
      try {
        await Supabase.instance.client.from('scanned_barcodes').insert({
          'raw_content': scanData['raw_content'],
          'barcode_format': scanData['barcode_format'],
          'device_info': scanData['device_info'],
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم المسح والمزامنة مباشرة مع Supabase!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        await localBox.add(scanData);
        _showOfflineMessage();
      }
    } else {
      await localBox.add(scanData);
      _showOfflineMessage();
    }

    setState(() => isProcessing = false);
  }

  void _showOfflineMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'لا يوجد إنترنت. تم الحفظ محلياً (المعلقة: ${localBox.length}). ستتم المزامنة تلقائياً!',
        ),
        backgroundColor: const Color(0xFFF59E0B),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الوثائق والبطاقات'),
        actions: [
          ValueListenableBuilder(
            valueListenable: localBox.listenable(),
            builder: (context, Box box, _) {
              if (box.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(left: 12),
                child: Chip(
                  avatar: const Icon(Icons.cloud_upload, size: 16, color: Colors.white),
                  label: Text('${box.length} معلق'),
                  backgroundColor: const Color(0xFFF59E0B),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  side: BorderSide.none,
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !isProcessing) {
                _handleBarcodeScan(barcodes.first);
              }
            },
          ),
          Center(
            child: Container(
              width: 310,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0D9488), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'وجه الكاميرا نحو الشفرة أو الـ QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black70,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF0D9488)),
                    SizedBox(height: 16),
                    Text(
                      'جاري معالجة البيانات وتخزينها...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
    super.dispose();
  }
}
