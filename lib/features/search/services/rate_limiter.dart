import 'dart:collection';
import 'dart:async';

class RateLimiter {
  final Duration _minInterval;
  DateTime? _lastRequestTime;
  final Queue<Completer<void>> _queue = Queue();
  bool _isProcessing = false;

  RateLimiter({Duration minInterval = const Duration(seconds: 3)})
      : _minInterval = minInterval;

  // Вызывать перед каждым запросом к маркетплейсу
  Future<void> waitForPermission() async {
    final completer = Completer<void>();
    _queue.add(completer);
    
    if (!_isProcessing) {
      _processQueue();
    }
    
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;
    final completer = _queue.removeFirst();

    // Ждем, если прошло мало времени с последнего запроса
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }

    _lastRequestTime = DateTime.now();
    completer.complete();
    
    // Обрабатываем следующий запрос в очереди
    _processQueue();
  }
}