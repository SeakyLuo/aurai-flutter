import 'package:flutter/material.dart';

class SearchSkeleton extends StatefulWidget {
  const SearchSkeleton({super.key, this.label = '正在搜索', this.rowGap = 24});
  final String label;
  final double rowGap;
  @override
  State<SearchSkeleton> createState() => _SearchSkeletonState();
}

class _SearchSkeletonState extends State<SearchSkeleton>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Widget _block(double width, double height, {double radius = 8}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: .06);
    final highlight = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: .12);
    return Semantics(
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (_, child) => ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-3 + _animation.value * 6, 0),
              end: Alignment(-1 + _animation.value * 6, 0),
              colors: [base, highlight, base],
              stops: const [0, .5, 1],
            ).createShader(bounds),
            child: child,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: widget.rowGap),
                  child: Row(
                    children: [
                      _block(24, 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(
                              widthFactor: i.isEven ? .7 : .5,
                              child: _block(double.infinity, 16),
                            ),
                            const SizedBox(height: 10),
                            _block(double.infinity, 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
