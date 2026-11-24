import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyScreenWidget extends StatelessWidget {
  const EmptyScreenWidget(
      {super.key,
      required this.message,
      required this.imagePath,
      required this.imageSize,
      required this.colorBool});
  final String message;
  final String imagePath;
  final int imageSize;
  final bool colorBool;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            cacheHeight: imageSize,
            imagePath,
            color: colorBool ? Theme.of(context).colorScheme.primary : null,
            opacity: const AlwaysStoppedAnimation(0.35),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

// EmptyScreen widget specifically for notes
class EmptyScreen extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyScreen({
    super.key,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
