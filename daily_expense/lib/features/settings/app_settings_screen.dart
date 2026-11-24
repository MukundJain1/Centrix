import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _biometricLock = false;
  bool _dailyReminders = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("App Settings", style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("PREFERENCES", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildListTile(Icons.currency_rupee_rounded, "Default Currency", trailing: const Text("INR (₹)", style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold))),
          _buildListTile(Icons.dark_mode_rounded, "Theme Appearance", trailing: const Text("System", style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold))),
          
          const SizedBox(height: 32),
          const Text("SECURITY & NOTIFICATIONS", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          SwitchListTile(
            activeColor: AppColors.primaryAccent,
            contentPadding: EdgeInsets.zero,
            title: const Text("App Lock (Biometrics)", style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text("Require fingerprint/face to open app", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _biometricLock,
            onChanged: (val) => setState(() => _biometricLock = val),
          ),
          SwitchListTile(
            activeColor: AppColors.primaryAccent,
            contentPadding: EdgeInsets.zero,
            title: const Text("Daily Reminders", style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text("Remind me to log expenses at 8:00 PM", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            value: _dailyReminders,
            onChanged: (val) => setState(() => _dailyReminders = val),
          ),

          const SizedBox(height: 32),
          const Text("DATA", style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildListTile(Icons.download_rounded, "Export Data to CSV"),
          _buildListTile(Icons.delete_forever_rounded, "Reset All Data", isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {Widget? trailing, bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : AppColors.textPrimary),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : AppColors.textPrimary)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: () {},
    );
  }
}