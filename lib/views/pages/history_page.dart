import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/mqtt_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/app_theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Timer? _refreshTimer;
  late Future<List<Map<String, String>>> _historyFuture;
  bool _isInitDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitDone) return;
    _isInitDone = true;

    _historyFuture = _fetchHistory();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _historyFuture = _fetchHistory();
      });
    });
  }

  Future<List<Map<String, String>>> _fetchHistory() {
    return Provider.of<MqttController>(context, listen: false).getHistoryViewData();
  }

  Future<void> _handleRefresh() async {
    final future = _fetchHistory();
    if (mounted) {
      setState(() {
        _historyFuture = future;
      });
    }
    await future;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(child: _buildHistoryList(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final headerGradient = isDark ? AppColors.headerGradient : AppColors.lightHeaderGradient;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: headerGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riwayat Aktivitas',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Log aktivitas sistem AC',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? AppColors.neonCyan : Colors.white70,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.filter_list_rounded, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return FutureBuilder<List<Map<String, String>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat riwayat: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: isDark ? AppColors.textSecondary : Colors.grey[700],
                ),
              ),
            ),
          );
        }

        final historyData = snapshot.data ?? [];
        if (historyData.isEmpty) {
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    'Belum ada riwayat aktivitas.',
                    style: GoogleFonts.poppins(
                      color: isDark ? AppColors.textSecondary : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: historyData.length,
            itemBuilder: (context, index) {
              final item = historyData[index];
              final showDateHeader = index == 0 || historyData[index]['date'] != historyData[index - 1]['date'];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDateHeader) ...[
                    Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          item['date'] ?? '-',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                  _buildHistoryCard(item, isDark),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, String> item, bool isDark) {
    final action = item['action'] ?? '-';
    final isOn = action.contains('ON') || action.contains('Dinyalakan');
    final isOff = action.contains('OFF') || action.contains('Dimatikan');
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    
    Color iconColor = primaryColor;
    IconData icon = Icons.ac_unit_rounded;
    
    if (isOn) {
      iconColor = AppColors.neonGreen;
      icon = Icons.power_settings_new_rounded;
    } else if (isOff) {
      iconColor = AppColors.neonRed;
      icon = Icons.power_off_rounded;
    } else if (action.contains('MODE') || action.contains('Mode')) {
      icon = Icons.tune_rounded;
      iconColor = AppColors.neonOrange;
    } else if (action.contains('Suhu')) {
      icon = Icons.thermostat_rounded;
      iconColor = AppColors.neonPurple;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: isDark ? 0.1 : 0.15),
            blurRadius: 10,
          ),
          if (!isDark) BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['room'] ?? '-',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF2d3748),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondary : Colors.grey[600],
                  ),
                ),
                if ((item['mode'] ?? '-') != '-') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildTag(item['mode'] ?? '-', primaryColor),
                      const SizedBox(width: 8),
                      _buildTag(item['temp'] ?? '-', AppColors.neonOrange),
                      if ((item['trigger'] ?? '-') != '-') ...[
                        const SizedBox(width: 8),
                        _buildTag(item['trigger'] ?? '-', AppColors.neonPurple),
                      ],
                    ],
                  ),
                ] else if ((item['trigger'] ?? '-') != '-') ...[
                  const SizedBox(height: 8),
                  _buildTag(item['trigger'] ?? '-', AppColors.neonPurple),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item['time'] ?? '-',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
