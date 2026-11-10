import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const FlappyBirdApp());
}

class FlappyBirdApp extends StatelessWidget {
  const FlappyBirdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flappy Bird Flutter',
      home: GameScreen(),
    );
  }
}

class Pipe {
  double x;
  double topHeight;
  bool passed;

  Pipe({
    required this.x,
    required this.topHeight,
    this.passed = false,
  });
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // إعدادات الفيزياء واللعبة
  static const double gravity = 1100.0;
  static const double jumpForce = -360.0;
  static const double birdRadius = 18.0;
  static const double pipeWidth = 65.0;
  static const double pipeGap = 155.0;
  static const double pipeSpeed = 190.0;
  static const double groundHeight = 90.0;

  // متغيرات حالة الطائر واللعبة
  double birdY = 0;
  double birdVelocity = 0;
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int highScore = 0;

  final List<Pipe> pipes = [];
  final Random _random = Random();
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    // حساب فرق الوقت بالثواني (Delta Time) لضمان ثبات السرعة على كل الشاشات
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    // تجنب القفزات الكبيرة في الوقت إذا توقف التطبيق مؤقتاً
    if (dt > 0.05) dt = 0.05;

    if (isPlaying && !isGameOver) {
      _updateGame(dt);
    }
  }

  void _startGame() {
    setState(() {
      birdY = (_screenSize.height - groundHeight) / 2;
      birdVelocity = jumpForce;
      pipes.clear();
      score = 0;
      isGameOver = false;
      isPlaying = true;
      _spawnPipe(_screenSize.width + 100);
    });
    _lastElapsed = Duration.zero;
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _jump() {
    if (isGameOver) {
      _startGame();
    } else if (!isPlaying) {
      _startGame();
    } else {
      setState(() {
        birdVelocity = jumpForce;
      });
    }
  }

  void _spawnPipe(double startX) {
    double playableHeight = _screenSize.height - groundHeight;
    double minPipe = 60.0;
    double maxPipe = playableHeight - pipeGap - minPipe;
    double topHeight = minPipe + _random.nextDouble() * max(10, maxPipe - minPipe);

    pipes.add(Pipe(x: startX, topHeight: topHeight));
  }

  void _updateGame(double dt) {
    setState(() {
      // تحديث موقع الطائر
      birdVelocity += gravity * dt;
      birdY += birdVelocity * dt;

      double playableHeight = _screenSize.height - groundHeight;

      // التحقق من الاصطدام بالأرض أو السقف
      if (birdY + birdRadius >= playableHeight) {
        birdY = playableHeight - birdRadius;
        _triggerGameOver();
      } else if (birdY - birdRadius <= 0) {
        birdY = birdRadius;
        birdVelocity = 0;
      }

      // توليد أنابيب جديدة
      if (pipes.isEmpty || (_screenSize.width - pipes.last.x) >= 230) {
        _spawnPipe(_screenSize.width + 50);
      }

      double birdX = _screenSize.width * 0.28;

      // تحديث حركة الأنابيب وفحص الاصطدام
      for (int i = pipes.length - 1; i >= 0; i--) {
        Pipe p = pipes[i];
        p.x -= pipeSpeed * dt;

        // زيادة النقاط عند تجاوز الأنبوب
        if (!p.passed && p.x + pipeWidth < birdX) {
          p.passed = true;
          score++;
          if (score > highScore) {
            highScore = score;
          }
        }

        // فحص الاصطدام بالأنابيب (مع تسامح بسيط 4 بكسل لتحسين تجربة اللعب)
        const double hitForgiveness = 4.0;
        if (birdX + birdRadius - hitForgiveness > p.x &&
            birdX - birdRadius + hitForgiveness < p.x + pipeWidth) {
          if (birdY - birdRadius + hitForgiveness < p.topHeight ||
              birdY + birdRadius - hitForgiveness > p.topHeight + pipeGap) {
            _triggerGameOver();
          }
        }

        // حذف الأنابيب التي خرجت من الشاشة
        if (p.x + pipeWidth < -50) {
          pipes.removeAt(i);
        }
      }
    });
  }

  void _triggerGameOver() {
    isGameOver = true;
    isPlaying = false;
    _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (!isPlaying && !isGameOver && birdY == 0) {
            birdY = (_screenSize.height - groundHeight) / 2;
          }

          return GestureDetector(
            onTapDown: (_) => _jump(),
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                // لوحة الرسم الأساسية للعبة
                CustomPaint(
                  size: _screenSize,
                  painter: _GamePainter(
                    birdY: birdY,
                    birdVelocity: birdVelocity,
                    birdRadius: birdRadius,
                    pipes: pipes,
                    pipeWidth: pipeWidth,
                    pipeGap: pipeGap,
                    groundHeight: groundHeight,
                  ),
                ),

                // عرض النقاط الحالية في الأعلى
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // شاشة البداية أو الخسارة
                if (!isPlaying)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isGameOver ? 'انتهت اللعبة!' : 'فلابي بيرد',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: isGameOver
                                  ? Colors.redAccent
                                  : Colors.amberAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isGameOver) ...[
                            Text(
                              'النقاط: $score',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'أعلى نتيجة: $highScore',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.amber,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isGameOver
                                  ? 'اضغط للعب مرة أخرى'
                                  : 'اضغط على الشاشة للبدء',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final double birdY;
  final double birdVelocity;
  final double birdRadius;
  final List<Pipe> pipes;
  final double pipeWidth;
  final double pipeGap;
  final double groundHeight;

  _GamePainter({
    required this.birdY,
    required this.birdVelocity,
    required this.birdRadius,
    required this.pipes,
    required this.pipeWidth,
    required this.pipeGap,
    required this.groundHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double playableHeight = size.height - groundHeight;

    // 1. رسم السماء (خلفية متدرجة)
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4EC0CA), Color(0xFF87CEEB)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, playableHeight));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, playableHeight), skyPaint);

    // 2. رسم الأنابيب
    final pipePaint = Paint()..color = const Color(0xFF73BF2E);
    final pipeBorderPaint = Paint()
      ..color = const Color(0xFF558022)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final p in pipes) {
      // الأنبوب العلوي
      final topRect = Rect.fromLTWH(p.x, 0, pipeWidth, p.topHeight);
      canvas.drawRect(topRect, pipePaint);
      canvas.drawRect(topRect, pipeBorderPaint);

      // حافة الأنبوب العلوي
      final topCapRect = Rect.fromLTWH(p.x - 4, p.topHeight - 24, pipeWidth + 8, 24);
      canvas.drawRect(topCapRect, pipePaint);
      canvas.drawRect(topCapRect, pipeBorderPaint);

      // الأنبوب السفلي
      final bottomY = p.topHeight + pipeGap;
      final bottomHeight = playableHeight - bottomY;
      final bottomRect = Rect.fromLTWH(p.x, bottomY, pipeWidth, bottomHeight);
      canvas.drawRect(bottomRect, pipePaint);
      canvas.drawRect(bottomRect, pipeBorderPaint);

      // حافة الأنبوب السفلي
      final bottomCapRect = Rect.fromLTWH(p.x - 4, bottomY, pipeWidth + 8, 24);
      canvas.drawRect(bottomCapRect, pipePaint);
      canvas.drawRect(bottomCapRect, pipeBorderPaint);
    }

    // 3. رسم الأرضية والعشب
    final groundPaint = Paint()..color = const Color(0xFFDED895);
    canvas.drawRect(
      Rect.fromLTWH(0, playableHeight, size.width, groundHeight),
      groundPaint,
    );

    final grassPaint = Paint()..color = const Color(0xFF73BF2E);
    canvas.drawRect(
      Rect.fromLTWH(0, playableHeight, size.width, 16),
      grassPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, playableHeight, size.width, 16),
      pipeBorderPaint,
    );

    // 4. رسم الطائر مع زاوية الميلان حسب السرعة
    final birdX = size.width * 0.28;
    canvas.save();
    canvas.translate(birdX, birdY);

    // تدوير الطائر للأعلى عند القفز وللأسفل عند السقوط
    double angle = (birdVelocity / 600).clamp(-0.5, 1.2);
    canvas.rotate(angle);

    // جسم الطائر
    final birdPaint = Paint()..color = const Color(0xFFF4D03F);
    final birdBorder = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(Offset.zero, birdRadius, birdPaint);
    canvas.drawCircle(Offset.zero, birdRadius, birdBorder);

    // جناح الطائر
    final wingPaint = Paint()..color = Colors.white;
    final wingRect = Rect.fromCenter(
      center: const Offset(-4, 3),
      width: 14,
      height: 10,
    );
    canvas.drawOval(wingRect, wingPaint);
    canvas.drawOval(wingRect, birdBorder);

    // عين الطائر
    canvas.drawCircle(const Offset(6, -5), 5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(6, -5), 5, birdBorder);
    canvas.drawCircle(const Offset(8, -5), 2, Paint()..color = Colors.black);

    // منقار الطائر
    final beakPaint = Paint()..color = const Color(0xFFE67E22);
    final beakPath = Path()
      ..moveTo(birdRadius - 2, -3)
      ..lineTo(birdRadius + 10, 2)
      ..lineTo(birdRadius - 2, 7)
      ..close();
    canvas.drawPath(beakPath, beakPaint);
    canvas.drawPath(beakPath, birdBorder);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}