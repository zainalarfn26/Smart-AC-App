import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_room_page.dart';
import 'history_page.dart';
import 'room_detail_page.dart';
import 'package:provider/provider.dart';
import '../../controllers/mqtt_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: IndexedStack(
        index: _currentIndex,
        children: const [DashboardPage(), AddRoomPage(), HistoryPage()],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(color: primaryColor.withValues(alpha: 0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Beranda', isDark),
              _buildCenterButton(isDark),
              _buildNavItem(2, Icons.bar_chart_rounded, 'Riwayat', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: primaryColor.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : AppColors.textMuted,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? primaryColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(bool isDark) {
    final gradient = isDark ? AppColors.neonGradient : AppColors.purpleGradient;
    final shadowColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 1),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.5),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _currentIndex == 1 ? Icons.close : Icons.add,
          color: isDark ? AppColors.primaryDark : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<MqttController>(context, listen: false).init();
    });
  }

  Future<void> _handleLogout() async {
    await _apiService.clearToken();

    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  void _showSettingsDialog() {
    final themeController = Provider.of<ThemeController>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<ThemeController>(
          builder: (context, theme, child) {
            final isDark = theme.isDarkMode;

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark
                      ? AppColors.neonCyan.withValues(alpha: 0.2)
                      : const Color(0xFF667eea).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.textMuted : Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.neonCyan.withValues(alpha: 0.15)
                              : const Color(0xFF667eea).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          color: isDark
                              ? AppColors.neonCyan
                              : const Color(0xFF667eea),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Pengaturan',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF2d3748),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Theme toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryDark.withValues(alpha: 0.5)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.neonCyan.withValues(alpha: 0.2)
                            : const Color(0xFF667eea).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? LinearGradient(
                                    colors: [
                                      AppColors.neonPurple.withValues(
                                        alpha: 0.3,
                                      ),
                                      AppColors.neonBlue.withValues(alpha: 0.3),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFF667eea,
                                      ).withValues(alpha: 0.3),
                                      const Color(
                                        0xFF764ba2,
                                      ).withValues(alpha: 0.3),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: isDark
                                ? AppColors.neonPurple
                                : const Color(0xFF667eea),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mode Tampilan',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF2d3748),
                                ),
                              ),
                              Text(
                                isDark ? 'Dark Mode' : 'Light Mode',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Toggle switch
                        GestureDetector(
                          onTap: () => themeController.toggleTheme(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 60,
                            height: 32,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? AppColors.neonGradient
                                  : AppColors.purpleGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isDark
                                              ? AppColors.neonCyan
                                              : const Color(0xFF667eea))
                                          .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              alignment: isDark
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isDark
                                      ? Icons.nights_stay_rounded
                                      : Icons.wb_sunny_rounded,
                                  size: 16,
                                  color: isDark
                                      ? const Color(0xFF5c4d7d)
                                      : const Color(0xFFf59e0b),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // App info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryDark.withValues(alpha: 0.5)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.neonCyan.withValues(alpha: 0.2)
                            : const Color(0xFF667eea).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.neonGreen.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? AppColors.neonGreen : Colors.green,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart AC Control',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF2d3748),
                                ),
                              ),
                              Text(
                                'Version 1.0.0',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark
                              ? AppColors.textMuted
                              : Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonRed.withValues(
                          alpha: 0.16,
                        ),
                        foregroundColor: AppColors.neonRed,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: AppColors.neonRed.withValues(alpha: 0.45),
                          ),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(
                        'Keluar Akun',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mqtt = Provider.of<MqttController>(context);
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;

    return mqtt.rooms.isEmpty
        ? _buildLoadingState(isDark)
        : SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(mqtt, isDark),
                _buildStatsCards(mqtt, isDark),
                _buildRoomList(mqtt, isDark),
                const SizedBox(height: 100),
              ],
            ),
          );
  }

  Widget _buildLoadingState(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: CircularProgressIndicator(
              color: primaryColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Menghubungkan ke perangkat...',
            style: GoogleFonts.poppins(
              color: isDark ? AppColors.textSecondary : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(MqttController mqtt, bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final headerGradient = isDark
        ? AppColors.headerGradient
        : AppColors.lightHeaderGradient;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart AC Control',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IoT Monitoring System',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? AppColors.neonCyan : Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showSettingsDialog,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: isDark ? AppColors.neonCyan : Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // MQTT Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: mqtt.isConnected
                  ? AppColors.neonGreen.withValues(alpha: 0.15)
                  : mqtt.isConnecting
                  ? AppColors.neonOrange.withValues(alpha: 0.15)
                  : AppColors.neonRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: mqtt.isConnected
                    ? AppColors.neonGreen.withValues(alpha: 0.5)
                    : mqtt.isConnecting
                    ? AppColors.neonOrange.withValues(alpha: 0.5)
                    : AppColors.neonRed.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: mqtt.isConnected
                        ? AppColors.neonGreen
                        : mqtt.isConnecting
                        ? AppColors.neonOrange
                        : AppColors.neonRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: mqtt.isConnected
                            ? AppColors.neonGreen.withValues(alpha: 0.5)
                            : mqtt.isConnecting
                            ? AppColors.neonOrange.withValues(alpha: 0.5)
                            : AppColors.neonRed.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  mqtt.isConnected
                      ? 'MQTT Connected'
                      : mqtt.isConnecting
                      ? 'Connecting...'
                      : 'Disconnected',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: mqtt.isConnected
                        ? AppColors.neonGreen
                        : mqtt.isConnecting
                        ? AppColors.neonOrange
                        : AppColors.neonRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(MqttController mqtt, bool isDark) {
    final totalRooms = mqtt.rooms.length;
    final activeAC = mqtt.rooms.where((r) => r['ac_status'] == 'ON').length;
    final occupied = mqtt.rooms.where((r) => r['presence'] == true).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Ruangan',
              '$totalRooms',
              Icons.meeting_room_rounded,
              AppColors.neonCyan,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'AC Aktif',
              '$activeAC',
              Icons.ac_unit_rounded,
              AppColors.neonGreen,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Terisi',
              '$occupied',
              Icons.people_rounded,
              AppColors.neonOrange,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.1 : 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF2d3748),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? AppColors.textSecondary : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(MqttController mqtt, bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Ruangan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF2d3748),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${mqtt.rooms.length} unit',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...mqtt.rooms.map((room) => _buildRoomCard(room, isDark)),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, bool isDark) {
    final temp = room['temperature'];
    final ac = room['ac_status'];
    final presence = room['presence'];
    final roomName = room['room'];
    final isAcOn = ac == 'ON';
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAcOn
                ? primaryColor.withValues(alpha: 0.3)
                : (isDark ? AppColors.primarySlate : Colors.grey).withValues(
                    alpha: 0.3,
                  ),
          ),
          boxShadow: isAcOn
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: isDark ? 0.1 : 0.15),
                    blurRadius: 15,
                  ),
                ]
              : [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                ],
        ),
        child: Row(
          children: [
            // Temperature circle with glow
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppColors.neonCyan.withValues(alpha: 0.3),
                          AppColors.neonBlue.withValues(alpha: 0.5),
                        ]
                      : [
                          const Color(0xFF667eea).withValues(alpha: 0.3),
                          const Color(0xFF764ba2).withValues(alpha: 0.3),
                        ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$temp°',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2d3748),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF2d3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildBadge(
                        isAcOn ? 'AC ON' : 'AC OFF',
                        isAcOn ? AppColors.neonGreen : AppColors.textMuted,
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildBadge(
                        presence ? 'Terisi' : 'Kosong',
                        presence ? AppColors.neonOrange : AppColors.textMuted,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_right_rounded, color: primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
