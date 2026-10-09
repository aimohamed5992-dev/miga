import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/miga_colors.dart';
import '../theme/miga_theme.dart';
import 'miga_buttons.dart';
import 'miga_image.dart';

/// Shimmering placeholder block shown while data loads.
class MigaSkeleton extends StatelessWidget {
  const MigaSkeleton({super.key, this.width, this.height = 14, this.radius = MigaRadius.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: MigaColors.surfaceMuted, borderRadius: MigaRadius.all(radius)),
  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: .7));
}

/// Skeleton shaped like a [CampaignTile] row.
class MigaTileSkeleton extends StatelessWidget {
  const MigaTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: MigaColors.surface, borderRadius: MigaRadius.all(MigaRadius.lg)),
    child: const Row(
      children: [
        MigaSkeleton(width: 84, height: 84, radius: MigaRadius.md),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MigaSkeleton(width: 160),
              SizedBox(height: 10),
              MigaSkeleton(width: 90, height: 18),
              SizedBox(height: 14),
              MigaSkeleton(height: 6),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Full-page states for network failures.
class MigaErrorView extends StatelessWidget {
  const MigaErrorView({super.key, this.offline = true, this.onRetry});
  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MigaImage(offline ? 'no_internet.png' : 'error_failed.png', width: 200, height: 200, fit: BoxFit.contain),
            const SizedBox(height: 20),
            Text(offline ? 'لا يوجد اتصال بالإنترنت' : 'حدث خطأ غير متوقع', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(
              offline ? 'تحقق من اتصالك بالشبكة ثم حاول مرة أخرى' : 'نعتذر عن ذلك، حاول مرة أخرى بعد قليل',
              style: t.bodyMedium?.copyWith(color: MigaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              MigaButton(label: 'إعادة المحاولة', icon: Icons.refresh_rounded, expanded: false, onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loads [future] and renders skeleton → content → error with retry.
class MigaAsync<T> extends StatefulWidget {
  const MigaAsync({super.key, required this.load, required this.builder, this.skeletonCount = 4});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final int skeletonCount;

  @override
  State<MigaAsync<T>> createState() => _MigaAsyncState<T>();
}

class _MigaAsyncState<T> extends State<MigaAsync<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, s) {
      if (s.hasError) return MigaErrorView(onRetry: () => setState(() => _future = widget.load()));
      if (!s.hasData) {
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: widget.skeletonCount,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => const MigaTileSkeleton(),
        );
      }
      return widget.builder(context, s.data as T);
    },
  );
}
