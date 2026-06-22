import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/cache/cache_manager.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/bookmarks/presentation/bookmarks_screen.dart';

void main() async {
  // ВАЖНО: Инициализация Flutter bindings перед async операциями
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Hive для дискового кэша
  await Hive.initFlutter();
  
  // Инициализация умного кэша
  await CacheManager().init();
  // Очистка старого кэша (удалить после первого запуска!)
await CacheManager().clear();
debugPrint('🧹 Старый кэш очищен');
  
  // Запуск приложения
  runApp(const KhochuApp());
}

class KhochuApp extends StatelessWidget {
  const KhochuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Хочу! 💖',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Фирменная палитра "Хочу!" (TikTok-inspired Pink & Cyan)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0050), // Яркий розовый
          primary: const Color(0xFFFF0050),
          secondary: const Color(0xFF00F2EA), // Неоновый голубой
          surface: const Color(0xFFFFF5F7),   // Нежно-розовый фон
        ),
        useMaterial3: true,
        // Глобально увеличиваем шрифты
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
          bodyLarge: TextStyle(fontSize: 18, color: Color(0xFF333333)),
          bodyMedium: TextStyle(fontSize: 16, color: Color(0xFF555555)),
        ),
        // ✅ CardThemeData вместо CardTheme
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),         // ← Главный экран с 5 кнопками
          BookmarksScreen(),    // ← Хочушки
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 80,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 32),
            selectedIcon: Icon(Icons.home, size: 32, color: Color(0xFFFF0050)),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border, size: 32),
            selectedIcon: Icon(Icons.favorite, size: 32, color: Color(0xFFFF0050)),
            label: 'Хочушки',
          ),
        ],
      ),
    );
  }
}