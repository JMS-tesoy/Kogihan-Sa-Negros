import 'package:flutter/material.dart';

class GoogleLogoIcon extends StatelessWidget {
  const GoogleLogoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: const Color(0xFF4285F4),
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
          ),
          Positioned(
            right: 1,
            bottom: 5,
            child: Container(
              height: 5,
              width: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF34A853),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 3,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                height: 5,
                width: 10,
                color: const Color(0xFFFBBC05),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 4,
            child: Transform.rotate(
              angle: 0.55,
              child: Container(
                height: 5,
                width: 10,
                color: const Color(0xFFEA4335),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
