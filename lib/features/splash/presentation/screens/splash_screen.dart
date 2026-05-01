import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/app_shell.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isOpening = false;

  Future<void> _goNext() async {
    if (_isOpening) return;

    setState(() => _isOpening = true);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool onboardingDone =
        prefs.getBool(StorageConstants.onboardingCompleted) ?? false;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            onboardingDone ? const AppLoginPage() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const _SplashBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Center(
                        child: _SplashContent(
                          isOpening: _isOpening,
                          onContinue: _goNext,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.58),
            colorScheme.surface,
            colorScheme.secondaryContainer.withValues(alpha: 0.42),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -96,
            right: -76,
            child: _GlowCircle(
              size: 240,
              color: colorScheme.primary.withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -84,
            child: _GlowCircle(
              size: 280,
              color: colorScheme.tertiary.withValues(alpha: 0.11),
            ),
          ),
          Positioned(
            top: 130,
            left: 30,
            child: _MiniDot(
              color: colorScheme.primary.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            right: 42,
            bottom: 210,
            child: _MiniDot(
              color: colorScheme.tertiary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            left: 56,
            bottom: 110,
            child: _MiniDot(
              color: colorScheme.secondary.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({
    required this.isOpening,
    required this.onContinue,
  });

  final bool isOpening;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _SplashLogo(),
        const SizedBox(height: 24),
        const _BrandHeader(),
        const SizedBox(height: 18),
        const _PropertyTypePill(),
        const SizedBox(height: 24),
        const _FeatureDetailsCard(),
        const SizedBox(height: 22),
        const _TrustRow(),
        const SizedBox(height: 34),
        _ContinueButton(
          isOpening: isOpening,
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.primary,
              colorScheme.tertiary,
            ],
          ),
        ),
        child: Icon(
          Icons.real_estate_agent_rounded,
          size: 54,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Kogihan Sa Negros',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find land that fits your budget, location, and future plans.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.35,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PropertyTypePill extends StatelessWidget {
  const _PropertyTypePill();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.58),
        ),
      ),
      child: Text(
        'Lots • Farms • Beachfront • Residential',
        textAlign: TextAlign.center,
        style: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _FeatureDetailsCard extends StatelessWidget {
  const _FeatureDetailsCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.58),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _FeatureItem(
            icon: Icons.place_rounded,
            title: 'Negros-focused properties',
            description:
                'Browse lots near roads, markets, beaches, and city areas.',
          ),
          SizedBox(height: 14),
          _FeatureItem(
            icon: Icons.payments_rounded,
            title: 'Budget-first land search',
            description:
                'Match listings by price range, land type, and buyer purpose.',
          ),
          SizedBox(height: 14),
          _FeatureItem(
            icon: Icons.support_agent_rounded,
            title: 'Agent-assisted inquiries',
            description:
                'Connect with assigned agents for property details and viewing.',
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            size: 22,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.35,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _TrustBadge(
          icon: Icons.verified_rounded,
          label: 'Verified details',
        ),
        _TrustBadge(
          icon: Icons.map_rounded,
          label: 'Map-ready',
        ),
        _TrustBadge(
          icon: Icons.chat_bubble_rounded,
          label: 'Quick inquiry',
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 15,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.isOpening,
    required this.onPressed,
  });

  final bool isOpening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: isOpening ? null : onPressed,
        icon: isOpening
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.arrow_forward_rounded),
        label: Text(
          isOpening ? 'Opening...' : 'Continue',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  const _MiniDot({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}