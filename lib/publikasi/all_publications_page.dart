import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:Dalem/components/app_colors.dart';
import 'package:Dalem/components/bar.dart';
import 'package:Dalem/components/state_widgets.dart';
import 'package:Dalem/providers/publication_provider.dart';
import 'package:Dalem/publikasi/detail_publikasi.dart';

class AllPublicationsPage extends StatefulWidget {
  const AllPublicationsPage({super.key});

  @override
  State<AllPublicationsPage> createState() => _AllPublicationsPageState();
}

class _AllPublicationsPageState extends State<AllPublicationsPage> {
  late ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchFocused = false;
  Timer? _debounceTimer;
  String _selectedYear = 'Semua';
  String _searchQuery = '';

  final List<String> _yearFilters = [
    'Semua',
    '${DateTime.now().year}',
    '${DateTime.now().year - 1}',
    '${DateTime.now().year - 2}',
    '${DateTime.now().year - 3}',
    '${DateTime.now().year - 4}',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _searchFocusNode.addListener(_onFocusChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PublicationProvider>(context, listen: false).fetchPublications(
        isRefresh: false,
        year: _selectedYear == 'Semua' ? null : _selectedYear,
        keyword: _searchQuery.isEmpty ? null : _searchQuery,
      );
    });
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final provider = Provider.of<PublicationProvider>(context, listen: false);
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !provider.isLoading &&
        provider.hasMoreData &&
        !provider.isError) {
      provider.fetchMorePublications();
    }
  }

  void _executeSearch(String val) {
    _debounceTimer?.cancel();
    final trimmed = val.trim();
    if (mounted) {
      setState(() {
        _searchQuery = trimmed;
      });
      Provider.of<PublicationProvider>(context, listen: false).fetchPublications(
        isRefresh: true,
        year: _selectedYear == 'Semua' ? null : _selectedYear,
        keyword: trimmed.isEmpty ? null : trimmed,
      );
    }
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(val);
    });
  }

  Future<void> _handleRefresh() async {
    await Provider.of<PublicationProvider>(context, listen: false)
        .refreshPublications();
  }

  List<dynamic> _getFilteredPublications(List<dynamic> publications) {
    return publications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: const AppBar2(
        title: 'Daftar Semua Publikasi',
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.primaryNavy,
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // Search & Filter Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Colors.white,
              child: Column(
                children: [
                  // Search Bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isSearchFocused
                            ? AppColors.primaryNavy
                            : const Color(0xFFE2E8F0),
                        width: _isSearchFocused ? 1.6 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isSearchFocused
                              ? AppColors.primaryNavy.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: _isSearchFocused ? 12 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _isSearchFocused
                                ? AppColors.primaryNavy.withValues(alpha: 0.1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            color: _isSearchFocused
                                ? AppColors.primaryNavy
                                : const Color(0xFF64748B),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _executeSearch,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              color: const Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari judul publikasi...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              filled: false,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFE2E8F0),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _executeSearch('');
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Year Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _yearFilters.map((year) {
                        final isSelected = _selectedYear == year;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              year == 'Semua' ? 'Semua Tahun' : 'Tahun $year',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected && _selectedYear != year) {
                                setState(() {
                                  _selectedYear = year;
                                });
                                Provider.of<PublicationProvider>(context,
                                        listen: false)
                                    .fetchPublications(
                                  isRefresh: true,
                                  year: year == 'Semua' ? null : year,
                                  keyword: _searchQuery.isEmpty
                                      ? null
                                      : _searchQuery,
                                );
                              }
                            },
                            selectedColor: AppColors.primaryNavy,
                            backgroundColor: const Color(0xFFF1F5F9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primaryNavy
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Publication List Body
            Expanded(
              child: Consumer<PublicationProvider>(
                builder: (context, provider, child) {
                  if (provider.isInitialLoading) {
                    return _buildSkeletonList();
                  }

                  if (provider.isError && provider.publications.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          vertical: 60, horizontal: 20),
                      children: [
                        ErrorStateWidget(
                          title: 'Gagal Memuat Publikasi',
                          message:
                              'Pastikan koneksi internet Anda terhubung dengan baik.',
                          onRetry: _handleRefresh,
                        ),
                      ],
                    );
                  }

                  final filteredList =
                      _getFilteredPublications(provider.publications);

                  if (filteredList.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          vertical: 60, horizontal: 20),
                      children: [
                        EmptyStateWidget(
                          title: 'Publikasi Tidak Ditemukan',
                          message: _searchQuery.isNotEmpty ||
                                  _selectedYear != 'Semua'
                              ? 'Tidak ada publikasi yang cocok dengan filter yang dipilih.'
                              : 'Publikasi statistik terbaru akan muncul di sini.',
                          icon: Icons.menu_book_outlined,
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredList.length +
                        (provider.isLoading && provider.hasMoreData ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredList.length) {
                        return _buildPaginationLoader();
                      }

                      var item = filteredList[index];
                      return _buildPublicationCard(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicationCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Publikasi BPS';
    final coverUrl = item['cover'] ?? '';
    final releaseDate = item['rl_date'] ?? 'No Date';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailPublikasi(publication: item),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverUrl,
                          width: 75,
                          height: 105,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Container(
                              width: 75,
                              height: 105,
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 75,
                            height: 105,
                            decoration: BoxDecoration(
                              color: AppColors.primaryNavy
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: AppColors.textMuted,
                                size: 28,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          width: 75,
                          height: 105,
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: AppColors.textMuted,
                              size: 28,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                // Details
                Expanded(
                  child: SizedBox(
                    height: 105,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Row & Badge
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    releaseDate,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PDF',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryNavy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Title
                            Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        // Action row
                        Row(
                          children: [
                            Text(
                              'Lihat Detail',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: AppColors.primaryLight,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Chevron icon container
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primaryNavy,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primaryNavy,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Memuat publikasi lainnya...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 75,
                    height: 105,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          height: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 180,
                          height: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 90,
                          height: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
