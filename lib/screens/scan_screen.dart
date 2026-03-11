import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../state/app_state.dart';
import '../services/audio_pipeline.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;

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
                  'Nearby Devices',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (_devices.isNotEmpty)
                  Text(
                    '${_devices.length} found',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                            ? Icons.sensors_rounded
                            : Icons.sensors_off_rounded,
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
                          ? 'DeafAssist Array'
                          : (isConnecting
                              ? 'Waiting for Handshake...'
                              : 'Not Connected'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      isConnected
                          ? 'BLE Data Stream Active'
                          : (isConnecting
                              ? 'Requesting Handshake...'
                              : 'Scan to discover your device'),
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
                  onPressed: _isScanning ? null : () => _startScan(pipeline),
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching_rounded, size: 16),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan BLE'),
                ),
              ),
              if (isConnected || isConnecting) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    pipeline.ble.disconnect();
                    pipeline.stopDemo();
                    context
                        .read<AppState>()
                        .setConnectionStatus(ConnectionStatus.disconnected);
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
    if (_devices.isEmpty && !_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Make sure the ESP32-S3 is powered\nand in BLE advertising mode.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _startScan(pipeline),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, i) {
        final device = _devices[i];
        final name = device.platformName.isNotEmpty
            ? device.platformName
            : device.remoteId.toString();
        final isConnected =
            state.connectionStatus == ConnectionStatus.connected;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DeviceTile(
            name: name,
            id: device.remoteId.toString(),
            isConnected: isConnected,
            onConnect: () => _connectDevice(pipeline, device),
          ),
        );
      },
    );
  }

  void _startScan(AudioPipeline pipeline) async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    pipeline.ble.foundDevices.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });

    try {
      await pipeline.ble.startScan();
    } catch (e) {
      debugPrint("BLE Scan Error: $e");
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _connectDevice(AudioPipeline pipeline, BluetoothDevice device) async {
    await pipeline.ble.connect(device);
    // After BLE connect, start audio stream over BLE
    await pipeline.connectAudioStream();
  }
}

class _DeviceTile extends StatelessWidget {
  final String name;
  final String id;
  final bool isConnected;
  final VoidCallback onConnect;

  const _DeviceTile({
    required this.name,
    required this.id,
    required this.isConnected,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.developer_board_rounded,
              color: AppColors.cyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                Text(id, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          FilledButton(
            onPressed: isConnected ? null : onConnect,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              isConnected ? 'Connected' : 'Connect',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
