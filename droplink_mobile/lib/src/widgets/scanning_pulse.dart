import 'package:flutter/material.dart';

class ScanningPulse extends StatefulWidget {
  const ScanningPulse({super.key});

  @override
  State<ScanningPulse> createState() => _ScanningPulseState();
}

class _ScanningPulseState extends State<ScanningPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 260,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                for (final offset in [0.0, 0.33, 0.66])
                  _Ring(progress: (_controller.value + offset) % 1, color: scheme.primary),
                CircleAvatar(
                  radius: 42,
                  backgroundColor: scheme.primary,
                  child: Icon(Icons.wifi_tethering_rounded, color: scheme.onPrimary, size: 38),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = 90 + progress * 150;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 1 - progress), width: 2),
      ),
    );
  }
}
