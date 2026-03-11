import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Top status bar showing connection dot, battery, and system state chip.
class StatusBar extends StatelessWidget {
  final AppState state;
  const StatusBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ConnectionDot(status: state.connectionStatus),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.connectionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (state.connectionStatus == ConnectionStatus.connected)
                  Text(
                    'UDP ${state.udpHost}:${state.udpPort}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          _SystemChip(status: state.systemStatus),
          if (state.batteryLevel != null) ...[
            const SizedBox(width: 10),
            _BatteryIndicator(level: state.batteryLevel!),
          ],
        ],
      ),
    );
  }
}

class _ConnectionDot extends StatefulWidget {
  final ConnectionStatus status;
  const _ConnectionDot({required this.status});

  @override
  State<_ConnectionDot> createState() => _ConnectionDotState();
}

class _ConnectionDotState extends State<_ConnectionDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final shouldAnimate =
        widget.status == ConnectionStatus.scanning ||
        widget.status == ConnectionStatus.connecting;

    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(
            alpha: shouldAnimate ? 0.4 + _anim.value * 0.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: shouldAnimate ? _anim.value * 0.6 : 0.3,
              ),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Color _color() {
    switch (widget.status) {
      case ConnectionStatus.connected:
        return AppColors.green;
      case ConnectionStatus.scanning:
      case ConnectionStatus.connecting:
        return AppColors.amber;
      case ConnectionStatus.disconnected:
        return AppColors.textMuted;
    }
  }
}

class _SystemChip extends StatelessWidget {
  final SystemStatus status;
  const _SystemChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SystemStatus.idle => ('IDLE', AppColors.textMuted),
      SystemStatus.listening => ('LISTENING', AppColors.cyan),
      SystemStatus.alerting => ('ALERT!', AppColors.coral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  final int level;
  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level > 20 ? AppColors.green : AppColors.coral;
    final icon = level > 80
        ? Icons.battery_full_rounded
        : level > 50
        ? Icons.battery_std_rounded
        : level > 20
        ? Icons.battery_3_bar_rounded
        : Icons.battery_alert_rounded;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        Text(
          ' $level%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
