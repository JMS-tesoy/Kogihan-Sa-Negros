import 'package:flutter/material.dart';

import '../../../notifications/presentation/widgets/notification_bell_button.dart';

class KsnHeaderLogo extends StatelessWidget {
  const KsnHeaderLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isLightTheme
                ? theme.colorScheme.shadow.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'asset/ksn_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CustomPaint(painter: _KsnLogoPainter());
        },
      ),
    );
  }
}

class _KsnLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF243F92), Color(0xFF070E2F)],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final double width = size.width;
    final double height = size.height;
    const Color gold = Color(0xFFC9BE57);
    final Paint goldStroke = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint darkFill = Paint()..color = const Color(0xFF10235F);

    final Path tower = Path()
      ..moveTo(width * 0.60, height * 0.22)
      ..lineTo(width * 0.75, height * 0.14)
      ..lineTo(width * 0.75, height * 0.48)
      ..lineTo(width * 0.60, height * 0.42)
      ..close();
    canvas.drawPath(tower, darkFill);
    canvas.drawPath(tower, goldStroke);

    final Path roof = Path()
      ..moveTo(width * 0.18, height * 0.53)
      ..lineTo(width * 0.50, height * 0.32)
      ..lineTo(width * 0.82, height * 0.53);
    canvas.drawPath(roof, goldStroke);

    final Path roofSweep = Path()
      ..moveTo(width * 0.14, height * 0.61)
      ..quadraticBezierTo(
        width * 0.50,
        height * 0.53,
        width * 0.88,
        height * 0.61,
      );
    canvas.drawPath(roofSweep, goldStroke);

    final Paint windowPaint = Paint()..color = gold;
    final double windowSize = width * 0.055;
    for (final Offset offset in <Offset>[
      Offset(width * 0.44, height * 0.48),
      Offset(width * 0.51, height * 0.48),
      Offset(width * 0.44, height * 0.56),
      Offset(width * 0.51, height * 0.56),
    ]) {
      canvas.drawRect(offset & Size(windowSize, windowSize), windowPaint);
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: 'KSN',
        style: TextStyle(
          color: gold,
          fontSize: width * 0.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);

    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, height * 0.66),
    );
  }

  @override
  bool shouldRepaint(covariant _KsnLogoPainter oldDelegate) => false;
}

class TopHeader extends StatelessWidget {
  const TopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isCompactPhone = MediaQuery.sizeOf(context).width < 360;
    final double logoSize = isCompactPhone ? 42 : 48;
    final double horizontalGap = isCompactPhone ? 10 : 12;

    return Row(
      children: <Widget>[
        KsnHeaderLogo(size: logoSize),
        SizedBox(width: horizontalGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Kogihan Sa Negros',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (isCompactPhone
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: isCompactPhone ? 4 : 6),
              Text(
                'Explore premium lots and investment-ready land.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (isCompactPhone
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SizedBox(width: horizontalGap),
        const NotificationBellButton(),
      ],
    );
  }
}
