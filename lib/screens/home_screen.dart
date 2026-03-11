import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/audio_pipeline.dart';
import '../theme/app_theme.dart';
import '../widgets/radar_widget.dart';
import '../widgets/sound_event_card.dart';
import '../widgets/status_bar.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _navIndex,
            children: [
              _DashboardView(state: state),
              const ScanScreen(),
              const SettingsScreen(),
            ],
          ),
          bottomNavigationBar: _buildNavBar(),
        );
      },
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        height: 68,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            label: 'Monitor',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching_rounded),
            label: 'Connect',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final AppState state;
  const _DashboardView({required this.state});

  @override
  Widget build(BuildContext context) {
    final pipeline = Provider.of<AudioPipeline>(context, listen: false);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildHeader(context, pipeline, state),
            ),
          ),

          // Radar section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildRadarSection(state),
            ),
          ),

          // Sound card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SoundEventCard(event: state.latestSound),
            ),
          ),

          // Recent events header
          if (state.recentEvents.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Recent Events',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => state.clearEvents(),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Event list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final event = state.recentEvents[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _EventListTile(event: event),
              );
            }, childCount: state.recentEvents.length.clamp(0, 10)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AudioPipeline pipeline,
    AppState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DeafAssist',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                Text(
                  'Blind spot audio awareness',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const Spacer(),
            if (state.connectionStatus == ConnectionStatus.connected &&
                !state.demoMode)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                ),
                child: Text('RX: ${state.packetCount}',
                    style: const TextStyle(
                        color: AppColors.cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            // Demo mode FAB
            GestureDetector(
              onTap: () {
                if (state.demoMode) {
                  pipeline.stopDemo();
                } else {
                  pipeline.startDemo();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: state.demoMode
                      ? AppColors.amber.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.demoMode ? AppColors.amber : AppColors.border,
                  ),
                ),
                child: Text(
                  state.demoMode ? '⏹ Demo' : '▶ Demo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: state.demoMode
                        ? AppColors.amber
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        StatusBar(state: state),
      ],
    );
  }

  Widget _buildRadarSection(AppState state) {
    final dir = state.latestDirection;
    return Column(
      children: [
        RadarWidget(
          azimuth: dir?.azimuth,
          confidence: dir?.confidence ?? 0.0,
          isActive: state.connectionStatus == ConnectionStatus.connected,
        ),
        const SizedBox(height: 16),
        _buildMicLevelBars(state),
        const SizedBox(height: 16),
        _buildDirectionStats(state),
      ],
    );
  }

  Widget _buildMicLevelBars(AppState state) {
    bool isConnected = state.connectionStatus == ConnectionStatus.connected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) {
              double level = isConnected ? state.micLevels[i] : 0.0;
              // Amplify for better visibility, clamp to 1.0
              double displayLevel = (level * 5.0).clamp(0.01, 1.0);

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: double.infinity,
                          height: displayLevel * 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.cyan,
                                AppColors.cyan.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'M${i + 1}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            isConnected ? 'LIVE 4-CHANNEL STREAM' : 'ARRAY IDLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isConnected ? AppColors.cyan : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionStats(AppState state) {
    final dir = state.latestDirection;
    if (dir == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Text(
          state.connectionStatus == ConnectionStatus.connected
              ? 'Detecting direction...'
              : 'Connect to start monitoring',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatChip(
          icon: dir.cardinalIcon,
          label: dir.cardinalLabel,
          value: '${dir.azimuth.toStringAsFixed(0)}°',
          color: AppColors.cyan,
        ),
        const SizedBox(width: 12),
        _StatChip(
          icon: '🎯',
          label: 'CONFIDENCE',
          value: '${(dir.confidence * 100).toStringAsFixed(0)}%',
          color: AppColors.amber,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventListTile extends StatelessWidget {
  final SoundEvent event;
  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isHigh = event.isHighPriority;
    final accentColor = isHigh ? AppColors.coral : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh
              ? AppColors.coral.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Text(event.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                Text(
                  '${event.confidencePercent}${event.direction != null ? ' • ${event.direction!.cardinalIcon} ${event.direction!.cardinalLabel}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _timeAgo(event.timestamp),
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    return '${diff.inMinutes}m';
  }
}
