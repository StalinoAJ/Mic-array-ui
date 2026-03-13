import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/audio_pipeline.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  @override
  Widget build(BuildContext context) {
    final pipeline = Provider.of<AudioPipeline>(context, listen: false);
    final state = context.watch<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect Device',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Scan for ESP32-S3 mic array',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Connection card
            _buildConnectionCard(context, state, pipeline),
            const SizedBox(height: 24),

            // Device list
            Row(
              children: [
                Text(
                  'WiFi Instructions',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(child: _buildDeviceList(pipeline, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(
    BuildContext context,
    AppState state,
    AudioPipeline pipeline,
  ) {
    final isConnected = state.connectionStatus == ConnectionStatus.connected;
    final isConnecting = state.connectionStatus == ConnectionStatus.connecting;
    final color = isConnected
        ? AppColors.green
        : (isConnecting ? Colors.orange : AppColors.cyan);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isConnecting
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      )
                    : Icon(
                        isConnected
                            ? Icons.wifi_protected_setup_rounded
                            : Icons.wifi_off_rounded,
                        color: color,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'DeafAssist (WiFi)'
                          : (isConnecting
                              ? 'Connecting via WiFi...'
                              : 'Not Connected'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      isConnected
                          ? 'Streaming from ${state.udpHost}'
                          : (isConnecting
                              ? 'Requesting Handshake...'
                              : 'Connect to DeafAssist_AP'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (state.batteryLevel != null && isConnected)
                Text(
                  '🔋 ${state.batteryLevel}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isConnecting || isConnected
                      ? null
                      : () => _connectWifi(pipeline),
                  icon: isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Icon(Icons.wifi_find_rounded, size: 16),
                  label: Text(isConnected ? 'Connected' : 'Connect via WiFi'),
                ),
              ),
              if (isConnected || isConnecting) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    pipeline.wifi.disconnect();
                    pipeline.stopDemo();
                  },
                  child: const Text('Disconnect'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(AudioPipeline pipeline, AppState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'WiFi Mode Active',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '1. Connect your phone to WiFi: "DeafAssist_AP"\n2. Password: "password123"\n3. Click the button above to start stream.',
              textAlign: TextAlign.left,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _connectWifi(AudioPipeline pipeline) async {
    await pipeline.connectAudioStream();
  }
}
