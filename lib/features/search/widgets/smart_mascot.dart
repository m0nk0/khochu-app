import 'package:flutter/material.dart';

class SmartMascot extends StatelessWidget {
  final String mood; // 'idle', 'thinking', 'excited', 'sad'
  final double size; // Размер (для угла или центра)

  const SmartMascot({
    super.key,
    required this.mood,
    required this.size,
  });

  // 🧠 База фраз маскота
  String get message {
    switch (mood) {
      case 'idle':
        return 'Готов к шопингу! 🛍️';
      case 'thinking':
        return 'Хм, подбираю варианты... 🤔';
      case 'excited':
        return 'Ура! Добавлено! 🎉';
      case 'sad':
        return 'Ничего не нашли... 😢';
      default:
        return 'Привет! 💖';
    }
  }

  String get imagePath {
    switch (mood) {
      case 'thinking': return 'assets/images/mascot_thinking.png';
      case 'sad': return 'assets/images/mascot_sad.png';
      case 'excited': return 'assets/images/mascot_excited.png';
      case 'idle': return 'assets/images/mascot_happy.png';
      default: return 'assets/images/mascot_happy.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Облачко с текстом
        if (mood != 'idle') // В углу текст можно скрыть или уменьшить, но оставим для атмосферы
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            message,
            style: TextStyle(
              fontSize: mood == 'idle' ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFCB11AB),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        
        // Картинка
        Image.asset(
          imagePath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.shopping_bag,
            size: size,
            color: const Color(0xFFFF0050),
          ),
        ),
      ],
    );
  }
}