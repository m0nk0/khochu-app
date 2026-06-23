import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../search/widgets/khosha_mascot.dart';
import '../widgets/main_action_button.dart';
import '../../search/presentation/search_screen.dart';
import '../../search/presentation/promotions_screen.dart';
import '../../search/presentation/wb_search_screen.dart';
import '../../search/presentation/ozon_search_screen.dart';
import '../../search/presentation/search_everywhere_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ConfettiController _confettiController = ConfettiController(
    duration: const Duration(seconds: 3),
  );

  // Рандомные фразы приветствия
  final List<String> _greetings = [
    'Привет! Я Хоша — твой умный помощник!\nНи в чём себе не отказывай! 🛍️',
    'Время безумного шопинга! 🎉\nЯ помогу найти лучшие цены!',
    'Привет! Давай найдём то, что ты хочешь! 💖',
    'Шопинг — это искусство! 🎨\nА я твой личный куратор!',
    'Готова к покупкам? 💃\nЯ уже нашёл для тебя лучшие предложения!',
    'Привет, красотка! 💅\nСегодня будем тратить с умом!',
    'Твой личный шопинг-ассистент на связи! 📱\nЧто будем искать?',
  ];

  late String _currentGreeting;

  @override
  void initState() {
    super.initState();
    // Выбираем случайную фразу
    _currentGreeting = _greetings[Random().nextInt(_greetings.length)];
    
    // Конфетти при первом запуске
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Маскот + приветствие
                  Column(
                    children: [
                      KhoshaMascot(mood: 'happy', size: 120),
                      const SizedBox(height: 16),
                      Text(
                        _currentGreeting,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCB11AB),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Выбери, где искать:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // ========== 1. ТОП ТОВАРОВ ОТОВСЮДУ ==========
                  MainActionButton(
                    icon: Icons.trending_up,
                    title: '🏆 Топ товаров отовсюду',
                    subtitle: 'С повышенной комиссией',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF0050), Color(0xFFCB11AB)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ========== 2. 🔥 ГОРЯЩИЕ АКЦИИ ==========
                  MainActionButton(
                    icon: Icons.local_fire_department,
                    title: '🔥 Горящие акции',
                    subtitle: 'Скидки до 90%',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF0050)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PromotionsScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ========== 3. 🔍 ПОИСК ВЕЗДЕ ==========
                 MainActionButton(
                    icon: Icons.search,
                    title: '🔍 Поиск везде',
                    subtitle: 'WB + Ozon одновременно',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00F2EA), Color(0xFF005BFF)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchEverywhereScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ========== 4. 🟣 WILDBERRIES ==========
                  MainActionButton(
                    icon: Icons.shopping_bag,
                    title: '🟣 Wildberries',
                    subtitle: 'Поиск по каталогу WB',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCB11AB), Color(0xFF9B0B8B)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WbSearchScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // ========== 5. 🔵 OZON ==========
                  MainActionButton(
                    icon: Icons.local_mall,
                    title: '🔵 Ozon',
                    subtitle: 'Поиск по каталогу Ozon',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF005BFF), Color(0xFF003EBA)],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OzonSearchScreen()),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Конфетти
          Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFFF0050),
                  Color(0xFF00F2EA),
                  Colors.yellow,
                  Colors.purple,
                  Colors.orange,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}