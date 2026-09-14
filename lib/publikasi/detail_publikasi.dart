import 'package:Dalem/pdf/pdf.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:Dalem/components/app_colors.dart';
import '../model/download.dart';
import 'package:Dalem/components/bar.dart';
import 'package:Dalem/components/bottom_nav.dart';
import 'package:Dalem/components/notification_service.dart';

// The duplicate class block is removed. Only keep one definition of DetailPublikasi and DetailPublikasiState.

class DetailPublikasi extends StatefulWidget {
  final Map<String, dynamic> publication;

  const DetailPublikasi({super.key, required this.publication});

  @override
  DetailPublikasiState createState() => DetailPublikasiState();
}

class DetailPublikasiState extends State<DetailPublikasi> {
  late Future<void> initialization;
  String localFilePath = 'Lokasi default'; // You can update this after download
  bool isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    initialization = _checkIfDownloaded();
  }

  Future<void> _checkIfDownloaded() async {
    if (kIsWeb) return;
    try {
      final directory = Directory('/storage/emulated/0/Download/Dalem');
      final cleanTitle =
          widget.publication['title'].replaceAll(RegExp(r'[^\w\s\-]'), '');
      final filePath = '${directory.path}/$cleanTitle.pdf';
      final file = File(filePath);

      if (await file.exists()) {
        if (mounted) {
          setState(() {
            isDownloaded = true;
            localFilePath = filePath;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking file existence: $e');
    }
  }

  Future<void> _savePdfWithFileSaver(String url, String title) async {
    // Cek izin penyimpanan (skip di web)
    if (!kIsWeb && Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt < 33) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Izin penyimpanan diperlukan')),
              );
            }
            return;
          }
        }
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final notificationService = NotificationService();

    try {
      // Tentukan direktori penyimpanan (sesuai dengan download.dart)
      final directory = Directory('/storage/emulated/0/Download/Dalem');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Bersihkan nama file
      final cleanTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '');
      final filePath = '${directory.path}/$cleanTitle.pdf';
      final file = File(filePath);

      // Mulai download
      final response =
          await http.Client().send(http.Request('GET', Uri.parse(url)));

      if (response.statusCode == 200) {
        final totalLength = response.contentLength ?? 0;
        int received = 0;
        final List<int> bytes = [];

        final stream = response.stream;
        await for (var chunk in stream) {
          bytes.addAll(chunk);
          await notificationService.showProgressNotification(
            id: notificationId,
            title: 'Mengunduh Publikasi',
            body: title,
            progress: received,
            maxProgress: totalLength,
          );
          received += chunk.length;
          if (totalLength > 0) {
            setState(() {
              _downloadProgress = received / totalLength;
            });
          }
        }

        await file.writeAsBytes(bytes);

        // Download Cover Image
        try {
          String coverUrl = widget.publication['cover'];
          if (coverUrl.isNotEmpty) {
            final coverResponse = await http.get(Uri.parse(coverUrl));
            if (coverResponse.statusCode == 200) {
              String ext = '.jpg';
              if (coverUrl.toLowerCase().endsWith('.png')) ext = '.png';
              if (coverUrl.toLowerCase().endsWith('.jpeg')) ext = '.jpeg';

              final coverPath = '${directory.path}/$cleanTitle$ext';
              final coverFile = File(coverPath);
              await coverFile.writeAsBytes(coverResponse.bodyBytes);
            }
          }
        } catch (e) {
          debugPrint('Gagal mengunduh cover: $e');
        }

        setState(() {
          isDownloaded = true;
          localFilePath = filePath;
        });
        if (mounted) {
          await notificationService.showCompleteNotification(
            id: notificationId,
            title: 'Unduhan Berhasil',
            body: '$title telah diunduh.',
            filePath: filePath,
          );
        }
      } else {
        throw Exception('Gagal mengunduh: ${response.statusCode}');
      }
    } catch (e) {
      await notificationService.showFailedNotification(
          id: notificationId,
          title: 'Unduhan Gagal',
          body: 'Gagal mengunduh $title: $e');
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showDownloadLocation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Lokasi Penyimpanan'),
          content: Text('File disimpan di: $localFilePath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Tutup'),
            ),
            TextButton(
                onPressed: _navigateToDownloadsPage, child: Text('Lihat'))
          ],
        );
      },
    );
  }

  void _navigateToDownloadsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadedPublicationsPage(
          isBackHome: false,
        ),
      ),
    );
  }

  String _cleanText(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Deskripsi publikasi belum tersedia.';
    }

    String cleaned = raw;

    // 1. Tangani double-escaped &amp;nbsp;
    cleaned = cleaned.replaceAll(RegExp(r'&amp;nbsp;?', caseSensitive: false), ' ');

    // 2. Decode entity HTML (&amp;, &quot;, &#39;, &lt;, &gt;, dll.)
    cleaned = HtmlUnescape().convert(cleaned);

    // 3. Tangani single-escaped &nbsp; atau sisa decode
    cleaned = cleaned.replaceAll(RegExp(r'&nbsp;?', caseSensitive: false), ' ');

    // 4. Decode sekali lagi untuk entitas bersarang
    cleaned = HtmlUnescape().convert(cleaned);

    // 5. Ganti karakter Unicode Non-Breaking Space (\u00A0) dan sisa &nbsp; jika ada
    cleaned = cleaned.replaceAll('\u00A0', ' ').replaceAll('&nbsp;', ' ');

    // 6. Konversi tag HTML baris baru (<br>, </p>) menjadi enter/newline
    cleaned = cleaned
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '');

    // 7. Bersihkan spasi horizontal ganda dan baris kosong berlebih
    cleaned = cleaned
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: const AppBar2(
              title: 'Detail Publikasi',
            ),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryNavy),
            ),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: const AppBar2(
              title: 'Detail Publikasi',
            ),
            body: Center(
              child: Text('Gagal memuat: ${snapshot.error}'),
            ),
          );
        } else {
          final cleanTitle = _cleanText(widget.publication['title'] ?? 'Publikasi');
          final releaseDate = widget.publication['rl_date'] ?? '-';
          final cleanAbstract = _cleanText(widget.publication['abstract']);

          return Scaffold(
            backgroundColor: AppColors.backgroundScaffold,
            appBar: const AppBar2(
              title: 'Detail Publikasi',
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Card
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 340),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryNavy.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 1 / 1.414,
                                child: Image.network(
                                  widget.publication['cover'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFF1F5F9),
                                    child: const Center(
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        size: 56,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          cleanTitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Release date badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Dirilis pada tanggal $releaseDate',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Header: Deskripsi Publikasi
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.primaryNavy,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Deskripsi Publikasi',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Clean Description Text
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.borderDefault),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            cleanAbstract,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              height: 1.65,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        // Tombol Lihat PDF
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryNavy,
                              side: BorderSide(color: AppColors.primaryNavy, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PDFViewerFromUrl(
                                    url: widget.publication['pdf'],
                                    title: cleanTitle,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility_rounded, size: 18),
                            label: Text(
                              'Lihat PDF',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tombol Download / Buka File
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryNavy,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isDownloading
                                ? null
                                : () {
                                    if (isDownloaded) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PDFViewerFromFile(
                                            filePath: localFilePath,
                                            title: cleanTitle,
                                          ),
                                        ),
                                      );
                                    } else {
                                      _savePdfWithFileSaver(
                                        widget.publication['pdf'],
                                        cleanTitle,
                                      );
                                    }
                                  },
                            icon: _isDownloading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      value: _downloadProgress > 0 ? _downloadProgress : null,
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isDownloaded ? Icons.folder_open_rounded : Icons.download_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _isDownloading
                                  ? 'Mengunduh...'
                                  : (isDownloaded ? 'Buka File' : 'Download PDF'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                        if (isDownloaded) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9),
                              padding: const EdgeInsets.all(12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            icon: const Icon(Icons.info_outline_rounded, color: AppColors.textSecondary, size: 20),
                            tooltip: 'Lokasi File',
                            onPressed: _showDownloadLocation,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: const BottomNav(currentIndex: 2),
          );
        }
      },
    );
  }
}
