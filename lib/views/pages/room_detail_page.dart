import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'dart:math' as math;
import '../../controllers/mqtt_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/app_theme.dart';

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;

  const RoomDetailPage({super.key, required this.room});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  late double currentTemp;
  late int batasAtas;
  late int batasBawah;
  late String selectedBrand;
  late String controlMode;
  late String coolingMode;
  late bool isAcOn;
  late bool hasPresence;
  late String roomName;
  late String deviceId;
  late String irLearningState;
  late String? irLearningTarget;
  late bool irCloneReady;
  late String selectedIrTarget;
  MqttController? _mqttController;
  bool isEditingSettings = false;

  final List<String> _acBrands = [
    'Daikin',
    'Panasonic',
    'LG',
    'Samsung',
    'Sharp',
    'Mitsubishi',
    'Gree',
    'Haier',
  ];

  @override
  void initState() {
    super.initState();
    currentTemp = (widget.room['temperature'] ?? 27).toDouble();
    batasAtas = widget.room['batas_atas'] ?? 29;
    batasBawah = widget.room['batas_bawah'] ?? 28;
    selectedBrand = widget.room['brand'] ?? 'Daikin';
    controlMode = _normalizeControlMode(
      widget.room['control_mode'] ?? widget.room['mode'],
    );
    coolingMode = widget.room['cooling_mode'] ?? 'TURBO';
    isAcOn = widget.room['ac_status'] == 'ON';
    hasPresence = widget.room['presence'] ?? false;
    roomName = widget.room['room']?.toString() ?? 'Ruangan';
    deviceId = widget.room['device_id']?.toString() ?? '';
    irLearningState = (widget.room['ir_learning_state']?.toString() ?? 'IDLE').toUpperCase();
    irLearningTarget = widget.room['ir_learning_target']?.toString();
    irCloneReady = widget.room['ir_clone_ready'] ?? false;
    selectedIrTarget = (irLearningTarget?.toString().isNotEmpty == true)
      ? irLearningTarget!.toUpperCase()
      : 'POWER_ON';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mqttController ??= Provider.of<MqttController>(context, listen: false)
      ..addListener(_syncFromController);
    _syncFromController();
  }

  @override
  void dispose() {
    _mqttController?.removeListener(_syncFromController);
    super.dispose();
  }

  String _normalizeControlMode(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value == 'auto' || value == 'otomatis') return 'auto';
    if (value == 'manual') return 'manual';
    return 'auto';
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _toPresence(dynamic value, bool fallback) {
    if (value is bool) return value;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'ada orang' ||
        normalized == 'true' ||
        normalized == '1') {
      return true;
    }
    if (normalized == 'kosong' || normalized == 'false' || normalized == '0') {
      return false;
    }
    return fallback;
  }

  void _syncFromController() {
    final mqtt = _mqttController;
    if (mqtt == null || !mounted) return;

    Map<String, dynamic>? latestRoom;

    if (deviceId.isNotEmpty) {
      final byDevice = mqtt.rooms.indexWhere(
        (r) => (r['device_id']?.toString() ?? '') == deviceId,
      );
      if (byDevice != -1) {
        latestRoom = mqtt.rooms[byDevice];
      }
    }

    if (latestRoom == null) {
      final byName = mqtt.rooms.indexWhere(
        (r) => (r['room']?.toString() ?? '') == roomName,
      );
      if (byName != -1) {
        latestRoom = mqtt.rooms[byName];
      }
    }

    if (latestRoom == null) return;

    setState(() {
      final previousLearningState = irLearningState;
      final previousLearningTarget = irLearningTarget;

      currentTemp = _toDouble(latestRoom!['temperature'], currentTemp);
      if (!isEditingSettings) {
        batasAtas = _toInt(latestRoom['batas_atas'], batasAtas);
        batasBawah = _toInt(latestRoom['batas_bawah'], batasBawah);
        selectedBrand = latestRoom['brand']?.toString() ?? selectedBrand;
      }
      controlMode = _normalizeControlMode(
        latestRoom['control_mode'] ?? latestRoom['mode'],
      );
      coolingMode = (latestRoom['cooling_mode']?.toString() ?? coolingMode)
          .toUpperCase();
      isAcOn =
          (latestRoom['ac_status']?.toString() ?? '').toUpperCase() == 'ON';
      hasPresence = _toPresence(latestRoom['presence'], hasPresence);
      roomName = latestRoom['room']?.toString() ?? roomName;
      deviceId = latestRoom['device_id']?.toString() ?? deviceId;
      irLearningState = (latestRoom['ir_learning_state']?.toString() ?? irLearningState).toUpperCase();
      irLearningTarget = latestRoom['ir_learning_target']?.toString();
      irCloneReady = latestRoom['ir_clone_ready'] ?? irCloneReady;

      if ((previousLearningState != irLearningState || previousLearningTarget != irLearningTarget) &&
          (irLearningState == 'READY' || irLearningState == 'FAILED')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final success = irLearningState == 'READY';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Cloning IR berhasil. Data siap dipakai untuk tombol kontrol.'
                    : 'Cloning IR gagal atau waktu habis. Silakan coba lagi.',
                style: GoogleFonts.poppins(),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: success ? AppColors.neonGreen.withValues(alpha: 0.18) : AppColors.neonRed.withValues(alpha: 0.18),
            ),
          );
        });
      }
    });
  }

  void sendCommand(String command, {Map<String, dynamic>? data}) {
    final mqtt = Provider.of<MqttController>(context, listen: false);
    mqtt.sendCommand(roomName, command);
  }

  Future<void> _startIrLearning() async {
    final mqtt = Provider.of<MqttController>(context, listen: false);
    final target = selectedIrTarget;

    try {
      await mqtt.startIrCloneLearning(roomName: roomName, target: target);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mode belajar IR aktif untuk $target. Arahkan remote asli ke KY-022.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memulai cloning IR. Coba lagi.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    final mqtt = Provider.of<MqttController>(context, listen: false);

    try {
      await mqtt.updateRoomSettings(
        roomName: roomName,
        brand: selectedBrand,
        batasAtas: batasAtas,
        batasBawah: batasBawah,
      );

      if (!mounted) return;
      setState(() => isEditingSettings = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan pengaturan. Coba lagi.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final isDark = themeController.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildControlModeSection(isDark),
                  const SizedBox(height: 16),
                  _buildManualControlSection(isDark),
                  const SizedBox(height: 16),
                  _buildIrCloneSection(isDark),
                  const SizedBox(height: 16),
                  _buildSettingsSection(isDark),
                  const SizedBox(height: 16),
                  _buildDeleteButton(isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final headerGradient = isDark
        ? AppColors.headerGradient
        : AppColors.lightHeaderGradient;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
      decoration: BoxDecoration(
        gradient: headerGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // App bar
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      deviceId.isNotEmpty ? deviceId : 'ESP32-DEVICE-01',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? AppColors.neonCyan : Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Power indicator
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAcOn
                      ? AppColors.neonGreen.withValues(alpha: 0.15)
                      : AppColors.neonRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAcOn
                        ? AppColors.neonGreen.withValues(alpha: 0.5)
                        : AppColors.neonRed.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isAcOn
                          ? AppColors.neonGreen.withValues(alpha: 0.3)
                          : AppColors.neonRed.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: isAcOn ? AppColors.neonGreen : AppColors.neonRed,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Temperature gauge
          _buildTemperatureGauge(isDark),
          const SizedBox(height: 16),
          // Status badges
          _buildStatusBadges(isDark),
        ],
      ),
    );
  }

  Widget _buildTemperatureGauge(bool isDark) {
    final gradient = isDark ? AppColors.neonGradient : AppColors.purpleGradient;

    return SizedBox(
      height: 180,
      width: 240,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Gauge arc - positioned at top
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(240, 140),
              painter: GaugePainter(
                temperature: currentTemp,
                minTemp: 16,
                maxTemp: 40,
                isDark: isDark,
              ),
            ),
          ),
          // Temperature display - positioned below the arc
          Positioned(
            top: 70,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => gradient.createShader(bounds),
                  child: Text(
                    currentTemp.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2d3748),
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  '°C',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadges(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBadge(
          isAcOn ? 'Menyala' : 'Mati',
          isAcOn ? AppColors.neonGreen : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        _buildBadge(
          coolingMode,
          coolingMode == 'TURBO' ? primaryColor : AppColors.neonBlue,
        ),
        const SizedBox(width: 8),
        _buildBadge(
          hasPresence ? 'Ada Orang' : 'Kosong',
          hasPresence ? AppColors.neonOrange : AppColors.textMuted,
          icon: Icons.person,
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlModeSection(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final gradient = isDark ? AppColors.neonGradient : AppColors.purpleGradient;
    final isAutoActive = controlMode == 'auto';
    final isManualActive = controlMode == 'manual';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_rounded, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'SISTEM KONTROL',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => controlMode = 'auto');
                    sendCommand('MODE:AUTO');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isAutoActive ? gradient : null,
                      color: isAutoActive
                          ? null
                          : (isDark
                                ? AppColors.backgroundDark
                                : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAutoActive
                            ? Colors.transparent
                            : (isDark ? AppColors.primarySlate : Colors.grey)
                                  .withValues(alpha: 0.3),
                      ),
                      boxShadow: isAutoActive
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Auto',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isAutoActive
                              ? (isDark ? AppColors.primaryDark : Colors.white)
                              : (isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => controlMode = 'manual');
                    sendCommand('MODE:MANUAL');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isManualActive ? gradient : null,
                      color: isManualActive
                          ? null
                          : (isDark
                                ? AppColors.backgroundDark
                                : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isManualActive
                            ? Colors.transparent
                            : (isDark ? AppColors.primarySlate : Colors.grey)
                                  .withValues(alpha: 0.3),
                      ),
                      boxShadow: isManualActive
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Manual',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isManualActive
                              ? (isDark ? AppColors.primaryDark : Colors.white)
                              : (isDark
                                    ? AppColors.textSecondary
                                    : Colors.grey[600]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualControlSection(bool isDark) {
    final isManual = controlMode == 'manual';
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final gradient = isDark ? AppColors.neonGradient : AppColors.purpleGradient;

    return Opacity(
      opacity: isManual ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.neonPurple.withValues(alpha: 0.2),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 20,
                  color: AppColors.neonPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  'KONTROL MANUAL',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonPurple,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Power button
            GestureDetector(
              onTap: isManual
                  ? () {
                      // Toggle state and send command
                      final newState = !isAcOn;
                      setState(() => isAcOn = newState);
                      sendCommand(newState ? 'ON' : 'OFF');
                    }
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isAcOn
                      ? AppColors.neonRed.withValues(alpha: 0.15)
                      : AppColors.neonGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isAcOn
                        ? AppColors.neonRed.withValues(alpha: 0.5)
                        : AppColors.neonGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.power_settings_new_rounded,
                      color: isAcOn ? AppColors.neonRed : AppColors.neonGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAcOn ? 'Matikan AC' : 'Nyalakan AC',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isAcOn ? AppColors.neonRed : AppColors.neonGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mode Pendinginan',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDark ? AppColors.textSecondary : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isManual
                        ? () {
                            setState(() => coolingMode = 'TURBO');
                            sendCommand('COOLING:TURBO');
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: coolingMode == 'TURBO' ? gradient : null,
                        color: coolingMode == 'TURBO'
                            ? null
                            : (isDark
                                  ? AppColors.backgroundDark
                                  : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: coolingMode == 'TURBO'
                              ? Colors.transparent
                              : (isDark ? AppColors.primarySlate : Colors.grey)
                                    .withValues(alpha: 0.3),
                        ),
                        boxShadow: coolingMode == 'TURBO'
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'TURBO',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: coolingMode == 'TURBO'
                                ? (isDark
                                      ? AppColors.primaryDark
                                      : Colors.white)
                                : (isDark
                                      ? AppColors.textSecondary
                                      : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: isManual
                        ? () {
                            setState(() => coolingMode = 'NORMAL');
                            sendCommand('COOLING:NORMAL');
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: coolingMode == 'NORMAL' ? gradient : null,
                        color: coolingMode == 'NORMAL'
                            ? null
                            : (isDark
                                  ? AppColors.backgroundDark
                                  : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: coolingMode == 'NORMAL'
                              ? Colors.transparent
                              : (isDark ? AppColors.primarySlate : Colors.grey)
                                    .withValues(alpha: 0.3),
                        ),
                        boxShadow: coolingMode == 'NORMAL'
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          'NORMAL',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: coolingMode == 'NORMAL'
                                ? (isDark
                                      ? AppColors.primaryDark
                                      : Colors.white)
                                : (isDark
                                      ? AppColors.textSecondary
                                      : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIrCloneSection(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final gradient = isDark ? AppColors.neonGradient : AppColors.purpleGradient;
    final isLearning = irLearningState == 'LEARNING';

    final targets = <Map<String, String>>[
      {'value': 'POWER_ON', 'label': 'Power ON'},
      {'value': 'POWER_OFF', 'label': 'Power OFF'},
      {'value': 'TURBO', 'label': 'Mode TURBO'},
      {'value': 'NORMAL', 'label': 'Mode NORMAL'},
    ];

    String targetLabel(String value) {
      final match = targets.firstWhere(
        (item) => item['value'] == value,
        orElse: () => {'label': value},
      );
      return match['label'] ?? value;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'CLONING IR',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (irCloneReady ? AppColors.neonGreen : AppColors.neonOrange)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  irLearningState == 'FAILED'
                      ? 'GAGAL'
                      : (irCloneReady ? 'SIAP' : irLearningState),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: irLearningState == 'FAILED'
                        ? AppColors.neonRed
                        : (irCloneReady ? AppColors.neonGreen : AppColors.neonOrange),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pilih target, lalu tekan tombol mulai cloning. Setelah berhasil, data cloning akan langsung dipakai oleh tombol kontrol yang sudah ada.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.5,
              color: isDark ? AppColors.textSecondary : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedIrTarget,
            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
            decoration: InputDecoration(
              labelText: 'Target cloning',
              labelStyle: GoogleFonts.poppins(
                color: isDark ? AppColors.textSecondary : Colors.grey[600],
              ),
              filled: true,
              fillColor: isDark ? AppColors.backgroundDark : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.22)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.22)),
              ),
            ),
            items: targets
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item['value'],
                    child: Text(item['label'] ?? item['value']!),
                  ),
                )
                .toList(),
            onChanged: isLearning
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => selectedIrTarget = value);
                  },
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isLearning ? null : _startIrLearning,
            child: Opacity(
              opacity: isLearning ? 0.6 : 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLearning ? Icons.hourglass_top_rounded : Icons.sensors_rounded,
                      color: isDark ? AppColors.primaryDark : Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLearning ? 'Sedang belajar...' : 'Mulai Cloning',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.primaryDark : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (irLearningState == 'FAILED'
                      ? AppColors.neonRed
                      : (irCloneReady ? AppColors.neonGreen : AppColors.neonOrange))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (irLearningState == 'FAILED'
                        ? AppColors.neonRed
                        : (irCloneReady ? AppColors.neonGreen : AppColors.neonOrange))
                    .withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              irLearningState == 'READY'
                  ? 'Cloning berhasil untuk ${targetLabel(irLearningTarget ?? selectedIrTarget)}.'
                  : irLearningState == 'FAILED'
                      ? 'Cloning gagal atau waktu habis. Silakan ulangi proses.'
                      : isLearning
                          ? 'Menunggu sinyal dari remote asli untuk ${targetLabel(irLearningTarget ?? selectedIrTarget)}.'
                          : 'Belum ada proses cloning yang berjalan.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);
    final gradient = isDark ? AppColors.neonGradient : AppColors.purpleGradient;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonOrange.withValues(alpha: 0.2)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.neonOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PENGATURAN',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neonOrange,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () async {
                  if (isEditingSettings) {
                    await _saveSettings();
                    return;
                  }
                  setState(() => isEditingSettings = !isEditingSettings);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: isEditingSettings ? gradient : null,
                    color: isEditingSettings
                        ? null
                        : primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: isEditingSettings
                        ? null
                        : Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                  ),
                  child: Text(
                    isEditingSettings ? 'Simpan' : 'Edit',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isEditingSettings
                          ? (isDark ? AppColors.primaryDark : Colors.white)
                          : primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Brand setting
          _buildSettingItem(
            label: 'Merk AC',
            value: selectedBrand,
            isEditing: isEditingSettings,
            onEdit: isEditingSettings ? () => _showBrandPicker() : null,
          ),
          const SizedBox(height: 16),
          // Temperature limits
          Row(
            children: [
              Expanded(
                child: _buildTempSettingItem(
                  label: 'Batas Bawah',
                  value: batasBawah,
                  color: AppColors.neonBlue,
                  isEditing: isEditingSettings,
                  onIncrease: () => setState(() => batasBawah++),
                  onDecrease: () => setState(() => batasBawah--),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTempSettingItem(
                  label: 'Batas Atas',
                  value: batasAtas,
                  color: AppColors.neonRed,
                  isEditing: isEditingSettings,
                  onIncrease: () => setState(() => batasAtas++),
                  onDecrease: () => setState(() => batasAtas--),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required String label,
    required String value,
    required bool isEditing,
    VoidCallback? onEdit,
  }) {
    final isDark = Provider.of<ThemeController>(context).isDarkMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.primarySlate : Colors.grey[300])!
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? AppColors.textSecondary : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onEdit,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF2d3748),
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded, size: 16, color: AppColors.neonCyan),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTempSettingItem({
    required String label,
    required int value,
    required Color color,
    required bool isEditing,
    required VoidCallback onIncrease,
    required VoidCallback onDecrease,
  }) {
    final isDark = Provider.of<ThemeController>(context).isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? AppColors.textSecondary : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (isEditing)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onDecrease,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.remove, size: 18, color: color),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$value°C',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onIncrease,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.add, size: 18, color: color),
                  ),
                ),
              ],
            )
          else
            Text(
              '$value°C',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  void _showBrandPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Merk AC',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _acBrands.map((brand) {
                  final isSelected = selectedBrand == brand;
                  return GestureDetector(
                    onTap: () {
                      setState(() => selectedBrand = brand);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.neonGradient : null,
                        color: isSelected ? null : AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: AppColors.primarySlate.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.neonCyan.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        brand,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? AppColors.primaryDark
                              : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return GestureDetector(
      onTap: () => _showDeleteConfirmation(isDark),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.neonRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.neonRed.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            'Hapus Ruangan Ini',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.neonRed,
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Ruangan?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2d3748),
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $roomName? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.poppins(
            color: isDark ? AppColors.textSecondary : Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.poppins(
                color: isDark ? AppColors.textSecondary : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final mqtt = Provider.of<MqttController>(context, listen: false);
              await mqtt.deleteRoom(roomName);

              if (!mounted) return;

              if (context.mounted) {
                Navigator.of(context).pop();
              }

              Navigator.of(this.context).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ruangan berhasil dihapus',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.neonGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Hapus',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double temperature;
  final double minTemp;
  final double maxTemp;
  final bool isDark;

  GaugePainter({
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    this.isDark = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Center at bottom-center of the canvas for semi-circle
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2 - 30;

    // Background arc
    final bgPaint = Paint()
      ..color = (isDark ? AppColors.primarySlate : Colors.grey).withValues(
        alpha: 0.3,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Value arc with gradient
    final progress = (temperature - minTemp) / (maxTemp - minTemp);
    final sweepAngle = math.pi * progress.clamp(0.0, 1.0);

    final gradientColors = isDark
        ? const [
            AppColors.neonCyan,
            AppColors.neonBlue,
            AppColors.neonPurple,
            AppColors.neonRed,
          ]
        : const [
            Color(0xFF667eea),
            Color(0xFF764ba2),
            Color(0xFFf093fb),
            Color(0xFFf5576c),
          ];

    final valuePaint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      sweepAngle,
      false,
      valuePaint,
    );

    // Draw scale marks and labels
    final textStyle = GoogleFonts.poppins(fontSize: 9, color: Colors.white70);

    for (int i = 0; i <= 4; i++) {
      final temp = minTemp + (maxTemp - minTemp) * i / 4;
      final angle = math.pi + math.pi * i / 4;

      // Scale marks
      final markStart = Offset(
        center.dx + (radius - 15) * math.cos(angle),
        center.dy + (radius - 15) * math.sin(angle),
      );
      final markEnd = Offset(
        center.dx + (radius - 8) * math.cos(angle),
        center.dy + (radius - 8) * math.sin(angle),
      );

      canvas.drawLine(
        markStart,
        markEnd,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 2,
      );

      // Temperature labels - positioned outside the arc
      final textSpan = TextSpan(text: '${temp.toInt()}°', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final labelOffset = Offset(
        center.dx + (radius + 12) * math.cos(angle) - textPainter.width / 2,
        center.dy + (radius + 12) * math.sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.temperature != temperature ||
        oldDelegate.isDark != isDark;
  }
}
