import 'package:flutter/material.dart';

class KhoshaMascot extends StatefulWidget {
  final String mood;
  final double size; // ← ДОБАВЛЕНО

  const KhoshaMascot({
    super.key,
    required this.mood,
    this.size = 160, // ← ДОБАВЛЕНО с дефолтным значением
  });

  @override
  State<KhoshaMascot> createState() => _KhoshaMascotState();
}

class _KhoshaMascotState extends State<KhoshaMascot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _imagePath {
    switch (widget.mood) {
      case 'thinking':
        return 'assets/images/mascot_thinking.png';
      case 'sad':
        return 'assets/images/mascot_sad.png';
      case 'love':
      case 'excited':
        return 'assets/images/mascot_excited.png';
      case 'happy':
      default:
        return 'assets/images/mascot_happy.png';
    }
  }

  String get _text {
    switch (widget.mood) {
      case 'thinking':
        return 'Хм, подбираю лучшие варианты...';
      case 'sad':
        return 'Ой, пока ничего не нашла...';
      case 'love':
        return 'Обожаю этот товар! 💖';
      case 'excited':
        return 'Ура! Отличный выбор! 🎉';
      case 'happy':
      default:
        return 'Привет! Я твой помощник!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounceAnimation.value),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.size, // ← ИЗМЕНЕНО: было 160
            height: widget.size, // ← ИЗМЕНЕНО: было 160
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF0050).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                _imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.shopping_bag,
                      size: widget.size * 0.5, // ← ИЗМЕНЕНО: пропорционально размеру
                      color: const Color(0xFFFF0050),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF0050).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCB11AB),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}