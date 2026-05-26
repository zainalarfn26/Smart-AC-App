import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/mqtt_controller.dart';
import '../../core/app_theme.dart';

class AddRoomPage extends StatefulWidget {
  const AddRoomPage({super.key});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _batasAtasController = TextEditingController(text: '29');
  final _batasBawahController = TextEditingController(text: '28');
  String _selectedBrand = 'Daikin';
  bool _isLoading = false;

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
  void dispose() {
    _roomNameController.dispose();
    _deviceIdController.dispose();
    _batasAtasController.dispose();
    _batasBawahController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final batasAtas = int.tryParse(_batasAtasController.text) ?? 29;
      final batasBawah = int.tryParse(_batasBawahController.text) ?? 28;

      if (batasAtas <= batasBawah) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_rounded, color: AppColors.backgroundDark),
                const SizedBox(width: 12),
                Text(
                  'Batas atas harus lebih besar dari batas bawah!',
                  style: GoogleFonts.poppins(color: AppColors.backgroundDark),
                ),
              ],
            ),
            backgroundColor: AppColors.neonOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final mqtt = Provider.of<MqttController>(context, listen: false);
        await mqtt.registerDevice(
          _deviceIdController.text.trim(),
          _roomNameController.text.trim(),
          brand: _selectedBrand,
          batasAtas: batasAtas,
          batasBawah: batasBawah,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menambahkan perangkat: $e',
                style: GoogleFonts.poppins(color: AppColors.backgroundDark),
              ),
              backgroundColor: AppColors.neonOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(20),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.backgroundDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Perangkat ${_roomNameController.text} berhasil ditambahkan!',
                    style: GoogleFonts.poppins(
                      color: AppColors.backgroundDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.neonGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );

        // Navigate back to home
        Navigator.of(context).pop();
      }
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormCard(isDark),
                    const SizedBox(height: 20),
                    _buildSubmitButton(isDark),
                    const SizedBox(height: 100),
                  ],
                ),
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
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.add_box_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Tambah Perangkat',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Daftarkan ESP32 dan Radar baru ke dalam\nsistem monitoring AC pintar.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.1 : 0.15),
            blurRadius: 20,
          ),
          if (!isDark)
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
          _buildTextField(
            controller: _roomNameController,
            label: 'Nama Ruangan',
            hint: 'Contoh: Ruang Dosen 1',
            icon: Icons.home_rounded,
            validator: (value) => value?.isEmpty == true ? 'Wajib diisi' : null,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _deviceIdController,
            label: 'ID Perangkat (Device ID)',
            hint: 'Contoh: ESP32-DOSEN-01',
            icon: Icons.developer_board_rounded,
            validator: (value) => value?.isEmpty == true ? 'Wajib diisi' : null,
            helperText: 'ID ini harus sama dengan topik MQTT di kode Arduino.',
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          _buildDropdownField(isDark),
          const SizedBox(height: 24),
          _buildTemperatureSection(isDark),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    String? helperText,
    bool isDark = true,
  }) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2d3748),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          validator: validator,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF2d3748),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: isDark ? AppColors.textMuted : Colors.grey[500],
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDark ? AppColors.backgroundDark : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isDark ? AppColors.primarySlate : Colors.grey)
                    .withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: (isDark ? AppColors.primarySlate : Colors.grey)
                    .withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.neonRed),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? AppColors.textMuted : Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.ac_unit_rounded, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              'Merk AC',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2d3748),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark ? AppColors.primarySlate : Colors.grey).withValues(
                alpha: 0.3,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBrand,
              isExpanded: true,
              dropdownColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.surfaceLight,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: primaryColor,
              ),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF2d3748),
              ),
              items: _acBrands.map((brand) {
                return DropdownMenuItem(
                  value: brand,
                  child: Text(
                    brand,
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.white : const Color(0xFF2d3748),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedBrand = value);
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pilih merk AC agar sinyal infrared dapat diterjemahkan dengan tepat.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isDark ? AppColors.textMuted : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureSection(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              'PENGATURAN HYSTERESIS',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTempInput(
                controller: _batasBawahController,
                label: 'Batas Bawah',
                sublabel: 'Threshold Normal',
                icon: Icons.thermostat_rounded,
                iconColor: AppColors.neonBlue,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTempInput(
                controller: _batasAtasController,
                label: 'Batas Atas',
                sublabel: 'Threshold Turbo',
                icon: Icons.thermostat_rounded,
                iconColor: AppColors.neonRed,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTempInput({
    required TextEditingController controller,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color iconColor,
    bool isDark = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF2d3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Text(
                '°C',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondary : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sublabel,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: isDark ? AppColors.textMuted : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final primaryColor = isDark ? AppColors.neonCyan : const Color(0xFF667eea);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isDark ? AppColors.primaryDark : Colors.white,
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: isDark ? AppColors.primaryDark : Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_rounded,
                    color: isDark ? AppColors.primaryDark : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Simpan Perangkat',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.primaryDark : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
