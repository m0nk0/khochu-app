import 'package:flutter/material.dart';
import '../services/traffic_tracker.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

    Future<void> _loadStats() async {
    final stats = await TrafficTracker.getStats();  // ← ИСПРАВЛЕНО
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' Статистика приложения'),
        backgroundColor: const Color(0xFFFF0050),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ваш вклад в экономику маркетплейсов',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Эти данные показывают, сколько трафика мы направляем на WB и Ozon',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            _buildStatCard(
              icon: Icons.search,
              title: 'Выполнено поисков',
              value: '${_stats['searches'] ?? 0}',
              color: const Color(0xFFCB11AB),
            ),
            const SizedBox(height: 16),
            
            _buildStatCard(
              icon: Icons.shopping_bag,
              title: 'Переходов на Wildberries',
              value: '${_stats['clicks_wb'] ?? 0}',
              color: const Color(0xFFCB11AB),
            ),
            const SizedBox(height: 16),
            
            _buildStatCard(
              icon: Icons.shopping_cart,
              title: 'Переходов на Ozon',
              value: '${_stats['clicks_ozon'] ?? 0}',
              color: const Color(0xFF005BFF),
            ),
            const SizedBox(height: 16),
            
            _buildStatCard(
              icon: Icons.trending_up,
              title: 'Всего переходов',
              value: '${_stats['total_clicks'] ?? 0}',
              color: const Color(0xFF00F2EA),
            ),
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0050), Color(0xFFC06BFF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Потенциальный оборот товаров',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${((_stats['estimated_gmv'] ?? 0.0) / 1000).toStringAsFixed(1)}K ₽',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Сумма цен товаров, на которые кликнули пользователи',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            Center(
              child: TextButton(
                onPressed: () async {
                  await TrafficTracker.resetStats();
                  _loadStats();
                },
                child: const Text('Сбросить статистику', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}