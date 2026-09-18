import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:Dalem/components/app_colors.dart';
import 'package:Dalem/components/bottom_nav.dart';
import 'package:Dalem/pdf/pdf.dart';

class DownloadedPublicationsPage extends StatefulWidget {
  final bool isBackHome;
  final bool showBottomNav;
  const DownloadedPublicationsPage({
    super.key,
    this.isBackHome = true,
    this.showBottomNav = true,
  });

  @override
  DownloadedPublicationsPageState createState() =>
      DownloadedPublicationsPageState();
}

class DownloadedPublicationsPageState
    extends State<DownloadedPublicationsPage>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, String>>> _downloadedFiles;
  String _sortCriteria = 'date';
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _permissionGranted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadFiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    if (await _requestPermission(Permission.storage)) {
      if (mounted) {
        setState(() {
          _permissionGranted = true;
          _downloadedFiles = _loadDownloadedFiles();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _permissionGranted = false;
          _downloadedFiles = Future.value([]);
        });
      }
    }
  }

  Future<void> _pickPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xls', 'xlsx'],
    );
    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;
      await OpenFile.open(filePath);
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final images = await Permission.photos.request();
        return images.isGranted;
      } else {
        final result = await permission.request();
        return result == PermissionStatus.granted;
      }
    } else {
      final result = await permission.request();
      return result == PermissionStatus.granted;
    }
  }

  Future<List<Map<String, String>>> _loadDownloadedFiles() async {
    if (kIsWeb) return [];
    final directory = Directory('/storage/emulated/0/Download/Dalem');
    if (!await directory.exists()) {
      return [];
    }
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) =>
            file.path.endsWith('.pdf') ||
            file.path.endsWith('.jpg') ||
            file.path.endsWith('.jpeg') ||
            file.path.endsWith('.png') ||
            file.path.endsWith('.xls') ||
            file.path.endsWith('.xlsx'))
        .toList();

    List<Map<String, String>> fileList = [];
    for (var file in files) {
      if (file.path.endsWith('.jpg') ||
          file.path.endsWith('.jpeg') ||
          file.path.endsWith('.png')) {
        final baseName = file.path.substring(0, file.path.lastIndexOf('.'));
        if (File('$baseName.pdf').existsSync() ||
            File('$baseName.xls').existsSync() ||
            File('$baseName.xlsx').existsSync()) {
          continue;
        }
      }

      String coverPath = '';
      final baseName = file.path.substring(0, file.path.lastIndexOf('.'));
      for (var ext in ['.jpg', '.jpeg', '.png']) {
        final possibleCover = File('$baseName$ext');
        if (possibleCover.existsSync() && possibleCover.path != file.path) {
          coverPath = possibleCover.path;
          break;
        }
      }
      fileList.add({'file': file.path, 'cover': coverPath});
    }

    if (_sortCriteria == 'date') {
      fileList.sort((a, b) {
        final aFile = File(a['file']!);
        final bFile = File(b['file']!);
        return bFile.lastModifiedSync().compareTo(aFile.lastModifiedSync());
      });
    } else if (_sortCriteria == 'name') {
      fileList.sort((a, b) =>
          a['file']!.toLowerCase().compareTo(b['file']!.toLowerCase()));
    } else if (_sortCriteria == 'size') {
      fileList.sort((a, b) {
        final aFile = File(a['file']!);
        final bFile = File(b['file']!);
        return bFile.lengthSync().compareTo(aFile.lengthSync());
      });
    }

    return fileList;
  }

  String _cleanFileName(String rawName) {
    final dotIndex = rawName.lastIndexOf('.');
    final nameWithoutExt =
        dotIndex != -1 ? rawName.substring(0, dotIndex) : rawName;
    return nameWithoutExt.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  String _getFileExtension(String path) {
    return path.split('.').last.toUpperCase();
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int _calculateTotalBytes(List<Map<String, String>> files) {
    int total = 0;
    for (var f in files) {
      final file = File(f['file']!);
      if (file.existsSync()) {
        total += file.lengthSync();
      }
    }
    return total;
  }

  int _countCategory(List<Map<String, String>> files, String type) {
    if (type == 'all') return files.length;
    return files.where((item) {
      final ext = item['file']!.split('.').last.toLowerCase();
      if (type == 'pdf') return ext == 'pdf';
      if (type == 'image') return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
      if (type == 'excel') return ext == 'xls' || ext == 'xlsx';
      return false;
    }).length;
  }

  String _getSortLabel() {
    switch (_sortCriteria) {
      case 'name':
        return 'Nama A-Z';
      case 'size':
        return 'Ukuran';
      case 'date':
      default:
        return 'Terbaru';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.subAppBarGradient,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isBackHome && Navigator.canPop(context))
                    Positioned(
                      left: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  Center(
                    child: Text(
                      'File Unduhan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _permissionGranted
          ? FutureBuilder<List<Map<String, String>>>(
              future: _downloadedFiles,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerLoading();
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Gagal memuat file: ${snapshot.error}',
                      style: GoogleFonts.plusJakartaSans(
                          color: AppColors.accentRose),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                } else {
                  final allFiles = snapshot.data!;
                  final totalSize = _calculateTotalBytes(allFiles);

                  // Filter by category
                  final filteredByCategory = allFiles.where((item) {
                    final ext = item['file']!.split('.').last.toLowerCase();
                    if (_selectedCategory == 'pdf') return ext == 'pdf';
                    if (_selectedCategory == 'image') {
                      return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
                    }
                    if (_selectedCategory == 'excel') {
                      return ext == 'xls' || ext == 'xlsx';
                    }
                    return true;
                  }).toList();

                  // Filter by search query
                  final filteredFiles = _searchQuery.trim().isEmpty
                      ? filteredByCategory
                      : filteredByCategory.where((item) {
                          final name =
                              item['file']!.split('/').last.toLowerCase();
                          return name
                              .contains(_searchQuery.trim().toLowerCase());
                        }).toList();

                  return Column(
                    children: [
                      // Overview Storage & Filter Section
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          children: [
                            // Stats Pill & Sort Filter Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.folder_special_rounded,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${allFiles.length} File tersimpan',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${_formatFileSize(totalSize)}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Sort / Filter Button (replacing Buka File Luar)
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    canvasColor: Colors.white,
                                  ),
                                  child: PopupMenuButton<String>(
                                    tooltip: 'Urutkan Dokumen',
                                    offset: const Offset(0, 38),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    color: Colors.white,
                                    onSelected: (value) {
                                      setState(() {
                                        _sortCriteria = value;
                                        _downloadedFiles = _loadDownloadedFiles();
                                      });
                                    },
                                    itemBuilder: (context) => [
                                      _buildSortMenuItem('date', 'Terbaru Diunduh',
                                          Icons.access_time_rounded),
                                      _buildSortMenuItem('name', 'Nama File (A - Z)',
                                          Icons.sort_by_alpha_rounded),
                                      _buildSortMenuItem('size', 'Ukuran Terbesar',
                                          Icons.data_usage_rounded),
                                    ],
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryNavy
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.primaryNavy
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.swap_vert_rounded,
                                            size: 16,
                                            color: AppColors.primaryNavy,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getSortLabel(),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryNavy,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.keyboard_arrow_down_rounded,
                                            size: 16,
                                            color: AppColors.primaryNavy,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Quick Search Input
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val;
                                        });
                                      },
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Cari file tersimpan...',
                                        hintStyle:
                                            GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Category Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildCategoryChip(
                                    key: 'all',
                                    label: 'Semua',
                                    count: _countCategory(allFiles, 'all'),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    key: 'pdf',
                                    label: 'Publikasi',
                                    count: _countCategory(allFiles, 'pdf'),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    key: 'image',
                                    label: 'Infografik',
                                    count: _countCategory(allFiles, 'image'),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    key: 'excel',
                                    label: 'Tabel Excel',
                                    count: _countCategory(allFiles, 'excel'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // File List or Empty Filter State
                      Expanded(
                        child: filteredFiles.isEmpty
                            ? _buildFilteredEmptyState()
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(14.0),
                                itemCount: filteredFiles.length,
                                itemBuilder: (context, index) {
                                  return _buildFileCard(
                                      filteredFiles[index], index, allFiles);
                                },
                              ),
                      ),
                    ],
                  );
                }
              },
            )
          : _buildPermissionDeniedState(),
      bottomNavigationBar: widget.showBottomNav
          ? const BottomNav(currentIndex: 3)
          : null,
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(
      String value, String label, IconData icon) {
    final isSelected = _sortCriteria == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
                isSelected ? AppColors.primaryNavy : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? AppColors.primaryNavy : const Color(0xFF1E293B),
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.primaryNavy,
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String key,
    required String label,
    required int count,
  }) {
    final isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(
      Map<String, String> item, int index, List<Map<String, String>> allFiles) {
    final file = File(item['file']!);
    final coverFile = File(item['cover']!);
    final hasCover = item['cover']!.isNotEmpty && coverFile.existsSync();
    final fileType = _getFileType(file);
    final fileName = file.path.split('/').last;
    final cleanTitle = _cleanFileName(fileName);
    final ext = _getFileExtension(file.path);
    final stat = file.existsSync() ? file.statSync() : null;
    final fileSizeStr = stat != null ? _formatFileSize(stat.size) : '';
    final dateStr = stat != null ? _formatDate(stat.modified) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDownloadedFile(file, fileName),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Preview Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildThumbnail(file, coverFile, hasCover),
                ),
                const SizedBox(width: 12),
                // File Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getFileTypeColor(file.path)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              fileType,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _getFileTypeColor(file.path),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              ext,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Cleaned File Title
                      Text(
                        cleanTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 7),
                      // Metadata Row (Size & Date)
                      Row(
                        children: [
                          if (fileSizeStr.isNotEmpty) ...[
                            const Icon(
                              Icons.data_usage_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              fileSizeStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (dateStr.isNotEmpty) ...[
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions Menu
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textMuted,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) async {
                    if (value == 'open') {
                      _openDownloadedFile(file, fileName);
                    } else if (value == 'open_with') {
                      await OpenFile.open(file.path);
                    } else if (value == 'share') {
                      await Share.shareXFiles([XFile(file.path)],
                          text: cleanTitle);
                    } else if (value == 'details') {
                      _showFileDetails(file);
                    } else if (value == 'delete') {
                      _confirmDeleteFile(index, allFiles);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 18, color: AppColors.primaryNavy),
                          const SizedBox(width: 10),
                          Text('Buka File',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'open_with',
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Text('Buka dengan aplikasi lain',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          const Icon(Icons.share_outlined,
                              size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Text('Bagikan File',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Text('Rincian Informasi',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppColors.accentRose),
                          const SizedBox(width: 10),
                          Text('Hapus File',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13, color: AppColors.accentRose)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(File file, File coverFile, bool hasCover) {
    final path = file.path.toLowerCase();
    if (hasCover) {
      return Image.file(
        coverFile,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFileTypeIcon(file.path),
      );
    } else if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png')) {
      return Image.file(
        file,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFileTypeIcon(file.path),
      );
    } else {
      return _buildFileTypeIcon(file.path);
    }
  }

  Widget _buildFileTypeIcon(String path) {
    if (path.endsWith('.pdf')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.accentRose.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.picture_as_pdf_rounded,
            size: 28, color: AppColors.accentRose),
      );
    } else if (path.endsWith('.xls') || path.endsWith('.xlsx')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.table_view_rounded,
            size: 28, color: Colors.green),
      );
    } else {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.accentTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_rounded,
            size: 28, color: AppColors.accentTeal),
      );
    }
  }

  Color _getFileTypeColor(String path) {
    if (path.endsWith('.pdf')) {
      return AppColors.primaryNavy;
    } else if (path.endsWith('.xls') || path.endsWith('.xlsx')) {
      return Colors.green.shade700;
    } else {
      return AppColors.accentTeal;
    }
  }

  String _getFileType(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'Publikasi';
      case 'jpg':
      case 'jpeg':
      case 'png':
        return 'Infografik';
      case 'xls':
      case 'xlsx':
        return 'Tabel Statistik';
      default:
        return 'File';
    }
  }

  Future<void> _openDownloadedFile(File file, String fileName) async {
    if (file.path.endsWith('.pdf')) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (!mounted) return;
      if (!kIsWeb &&
          Platform.isAndroid &&
          androidInfo.version.sdkInt >= 33 &&
          !_permissionGranted) {
        _pickPdfFile();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerFromFile(
              filePath: file.path,
              title: _cleanFileName(fileName),
            ),
          ),
        );
      }
    } else if (file.path.endsWith('.xls') || file.path.endsWith('.xlsx')) {
      await OpenFile.open(file.path);
    } else {
      showFullScreenImage(context, file.path);
    }
  }

  Widget _buildFilteredEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 42,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tidak Ada File yang Cocok',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ditemukan file dengan kata kunci "$_searchQuery"'
                  : 'Tidak ada file dalam kategori yang dipilih',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'all';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Reset Filter',
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_download_rounded,
                size: 64,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada File Terunduh',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'File publikasi, tabel, atau infografis\nyang Anda unduh akan muncul di sini',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _pickPdfFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(
                'Buka File dari HP',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Akses Penyimpanan Terbatas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Berikan izin penyimpanan untuk melihat daftar unduhan Anda',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _requestPermissionAndLoadFiles,
              icon: const Icon(Icons.security_rounded, size: 18),
              label: Text('Berikan Izin',
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickPdfFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text('Buka File Manual',
                  style:
                      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  void showFullScreenImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFileDetails(File file) async {
    final stat = await file.stat();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Informasi File',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Nama File', _cleanFileName(file.path.split('/').last)),
              _buildDetailRow('Ukuran', _formatFileSize(stat.size)),
              _buildDetailRow('Tipe', _getFileType(file)),
              _buildDetailRow('Terakhir Diubah', _formatDate(stat.modified)),
              _buildDetailRow('Lokasi Penyimpanan', file.path),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
              ),
              child: Text('Tutup',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(int index, List<Map<String, String>> files) async {
    final filePath = files[index]['file'];
    final coverPath = files[index]['cover'];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus File',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus file ini dari perangkat?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
            ),
            onPressed: () async {
              try {
                if (filePath != null && File(filePath).existsSync()) {
                  await File(filePath).delete();
                }
                if (coverPath != null &&
                    coverPath.isNotEmpty &&
                    File(coverPath).existsSync()) {
                  await File(coverPath).delete();
                }
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('File berhasil dihapus dari perangkat',
                          style: GoogleFonts.plusJakartaSans()),
                      backgroundColor: AppColors.textPrimary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  setState(() {
                    _downloadedFiles = _loadDownloadedFiles();
                  });
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus file: $e')),
                  );
                }
              }
            },
            child: Text(
              'Hapus',
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
