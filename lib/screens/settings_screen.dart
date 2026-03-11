import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/audio_pipeline.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text(
            'Configure your DeafAssist system',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Network', icon: Icons.wifi_rounded),
          _SettingCard(
            children: [
              _TextFieldSetting(
                label: 'ESP32 IP Address',
                hint: '192.168.4.1',
                value: state.udpHost,
                onChanged: (v) => state.udpHost = v,
              ),
              const Divider(height: 1),
              _TextFieldSetting(
                label: 'UDP Port',
                hint: '5005',
                value: state.udpPort.toString(),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    state.udpPort = int.tryParse(v) ?? state.udpPort,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Detection', icon: Icons.tune_rounded),
          _SettingCard(
            children: [
              _SliderSetting(
                label: 'Confidence Threshold',
                description: 'Minimum confidence to show a sound event',
                value: state.confidenceThreshold,
                min: 0.1,
                max: 0.9,
                onChanged: (v) => state.confidenceThreshold = v,
              ),
              const Divider(height: 1),
              _SliderSetting(
                label: 'Mic Spacing',
                description: 'Distance between adjacent mics in cm',
                value: state.micSpacingCm,
                min: 1.0,
                max: 20.0,
                displaySuffix: ' cm',
                onChanged: (v) => state.micSpacingCm = v,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Alerts', icon: Icons.notifications_rounded),
          _SettingCard(
            children: [
              _SwitchSetting(
                label: 'Push Notifications',
                description: 'Show notifications for detected sounds',
                value: state.notificationsEnabled,
                onChanged: (v) => state.notificationsEnabled = v,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionHeader(title: 'Developer', icon: Icons.code_rounded),
          _SettingCard(
            children: [
              _SwitchSetting(
                label: 'Demo Mode',
                description: 'Simulate sounds and directions without hardware',
                value: state.demoMode,
                onChanged: (v) {
                  final pipeline = Provider.of<AudioPipeline>(
                    context,
                    listen: false,
                  );
                  v ? pipeline.startDemo() : pipeline.stopDemo();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoCard(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.cyan),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.cyan,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _TextFieldSetting extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final TextInputType keyboardType;
  final void Function(String) onChanged;

  const _TextFieldSetting({
    required this.label,
    required this.hint,
    required this.value,
    this.keyboardType = TextInputType.text,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              keyboardType: keyboardType,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderSetting extends StatefulWidget {
  final String label;
  final String description;
  final double value;
  final double min;
  final double max;
  final String displaySuffix;
  final void Function(double) onChanged;

  const _SliderSetting({
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    this.displaySuffix = '',
    required this.onChanged,
  });

  @override
  State<_SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<_SliderSetting> {
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${(_val * 100).round() / 100}${widget.displaySuffix}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          Text(
            widget.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.cyan,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.cyan,
              overlayColor: AppColors.cyan.withValues(alpha: 0.1),
              trackHeight: 3,
            ),
            child: Slider(
              value: _val,
              min: widget.min,
              max: widget.max,
              onChanged: (v) {
                setState(() => _val = v);
                widget.onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchSetting({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.cyan,
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? AppColors.cyan.withValues(alpha: 0.3)
                  : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.cyan),
              SizedBox(width: 6),
              Text(
                'About DeafAssist',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'DeafAssist v1.0\nESP32-S3 + 4× INMP441 microphone array\nSound classification via YAMNet (TFLite)\nDirection of arrival via GCC-PHAT algorithm\nAudio stream: raw PCM over UDP Wi-Fi (~540µs wire latency)',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
