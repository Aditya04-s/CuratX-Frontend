import 'package:flutter/material.dart';

class CuratXLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const CuratXLogo({
    super.key,
    this.size = 48,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDF7357), Color(0xFFE76F51)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDF7357).withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white.withValues(alpha: 0.28),
                  size: size * 0.65,
                ),
                Text(
                  'CX',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: size * 0.56,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
              children: const [
                TextSpan(
                  text: 'Curat',
                  style: TextStyle(color: Color(0xFF111827)),
                ),
                TextSpan(
                  text: 'X',
                  style: TextStyle(color: Color(0xFFDF7357)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}