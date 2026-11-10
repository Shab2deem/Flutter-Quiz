import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() {
  runApp(const MiniPubgApp());
}

class MiniPubgApp extends StatelessWidget {
  const MiniPubgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mini PUBG Flutter',
      home: BattleRoyaleScreen(),
    );
  }
}

// ----------------- الكيانات الأساسية (Entities) -----------------

class Bullet {
  Offset pos;
  Offset vel;
  bool isPlayer;
  double distanceTraveled = 0;

  Bullet({required this.pos, required this.vel, required this.isPlayer});
}

class Enemy {
  Offset pos;
  double angle;
  double hp = 100;
  double shootCooldown = 0;
  Offset targetDir = Offset.zero;
  double changeDirTimer = 0;

  Enemy({required this.pos, this.angle = 0});
}

enum LootType { medkit, ammo }

class Loot {
  Offset pos;
  LootType type;
  Loot({required this.pos, required this.type});
}

class classObstacle {
Rect rect;
bool isTree;
classObstacle(this.rect, {this.isTree = false});
}

// ----------------- شاشة اللعبة -----------------

class BattleRoyaleScreen extends StatefulWidget {
  const BattleRoyaleScreen({super.key});

  @override
  State<BattleRoyaleScreen> createState() => _BattleRoyaleScreenState();
}

class _BattleRoyaleScreenState extends State<BattleRoyaleScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;
  final Random _rng = Random();

  // أبعاد الخريطة
  static const double mapSize = 2400.0;
  static const double playerSpeed = 220.0;
  static const double enemySpeed = 130.0;
  static const double bulletSpeed = 650.0;

  // حالة اللاعب
  Offset playerPos = const Offset(mapSize / 2, mapSize / 2);
  double playerAngle = 0;
  double playerHp = 100;
  int ammo = 90;
  int kills = 0;

  // حالة اللعبة والزون
  bool isPlaying = false;
  bool isVictory = false;
  double zoneRadius = 1600.0;
  final Offset zoneCenter = const Offset(mapSize / 2, mapSize / 2);

  // التحكم باللمس (Joysticks)
  Offset moveInput = Offset.zero; // عصا الحركة (يسار)
  Offset aimInput = Offset.zero;  // عصا التصويب والإطلاق (يمين)
  bool isFiring = false;
  double fireCooldown = 0;

  // قوائم عناصر الخريطة
  final List<Enemy> enemies = [];
  final List<Bullet> bullets = [];
  final List<Loot> loots = [];
  final List<classObstacle> obstacles = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _startNewGame();
  }

  void _startNewGame() {
    setState(() {
      playerPos = const Offset(mapSize / 2, mapSize / 2);
      playerHp = 100;
      ammo = 90;
      kills = 0;
      zoneRadius = 1650.0;
      isVictory = false;
      isPlaying = true;

      enemies.clear();
      bullets.clear();
      loots.clear();
      obstacles.clear();

      // توليد صخور وأشجار كحواجز (Cover)
      for (int i = 0; i < 45; i++) {
        double x = 150 + _rng.nextDouble() * (mapSize - 300);
        double y = 150 + _rng.nextDouble() * (mapSize - 300);
        // تجنب وضع عائق فوق نقطة بداية اللاعب مباشرة
        if ((Offset(x, y) - playerPos).distance < 150) continue;
        obstacles.add(
          classObstacle(
            Rect.fromCenter(center: Offset(x, y), width: 70, height: 70),
            isTree: _rng.nextBool(),
          ),
        );
      }

      // توليد الأعداء (19 بوت ليكون المجموع 20 مقاتل في السيرفر)
      for (int i = 0; i < 19; i++) {
        double x = 200 + _rng.nextDouble() * (mapSize - 400);
        double y = 200 + _rng.nextDouble() * (mapSize - 400);
        if ((Offset(x, y) - playerPos).distance < 350) {
          x += 400; // إبعادهم عن اللاعب في البداية
        }
        enemies.add(Enemy(pos: Offset(x, y)));
      }

      // توليد لوت مبدئي في الخريطة
      for (int i = 0; i < 25; i++) {
        double x = 200 + _rng.nextDouble() * (mapSize - 400);
        double y = 200 + _rng.nextDouble() * (mapSize - 400);
        loots.add(Loot(
          pos: Offset(x, y),
          type: _rng.nextBool() ? LootType.medkit : LootType.ammo,
        ));
      }
    });

    _lastTime = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;
    if (dt > 0.05) dt = 0.05;

    if (isPlaying) {
      _updateGame(dt);
    }
  }

  void _updateGame(double dt) {
    setState(() {
      // 1. تقليص الزون الأزرق
      if (zoneRadius > 180) {
        zoneRadius -= 18 * dt;
      }

      // ضرر الزون على اللاعب إذا خرج منه
      if ((playerPos - zoneCenter).distance > zoneRadius) {
        playerHp -= 7 * dt;
      }

      // 2. حركة اللاعب
      if (moveInput != Offset.zero) {
        Offset nextPos = playerPos + moveInput * playerSpeed * dt;
        nextPos = Offset(
          nextPos.dx.clamp(40.0, mapSize - 40.0),
          nextPos.dy.clamp(40.0, mapSize - 40.0),
        );
        if (!_collidesWithObstacles(nextPos, 20)) {
          playerPos = nextPos;
        }
        if (!isFiring) {
          playerAngle = atan2(moveInput.dy, moveInput.dx);
        }
      }

      // 3. تصويب وإطلاق نار اللاعب
      if (fireCooldown > 0) fireCooldown -= dt;
      if (aimInput != Offset.zero) {
        playerAngle = atan2(aimInput.dy, aimInput.dx);
      }

      if (isFiring && fireCooldown <= 0 && ammo > 0) {
        fireCooldown = 0.16; // سرعة إطلاق السلاح (رشاش)
        ammo--;
        Offset dir = Offset(cos(playerAngle), sin(playerAngle));
        bullets.add(Bullet(
          pos: playerPos + dir * 26,
          vel: dir * bulletSpeed,
          isPlayer: true,
        ));
      }

      // 4. التقاط اللوت (الإسعافات والذخيرة)
      for (int i = loots.length - 1; i >= 0; i--) {
        if ((loots[i].pos - playerPos).distance < 35) {
          if (loots[i].type == LootType.medkit && playerHp < 100) {
            playerHp = min(100, playerHp + 40);
            loots.removeAt(i);
          } else if (loots[i].type == LootType.ammo) {
            ammo += 35;
            loots.removeAt(i);
          }
        }
      }

      // 5. تحديث ذكاء البوتات (AI)
      for (int i = enemies.length - 1; i >= 0; i--) {
        Enemy e = enemies[i];

        // ضرر الزون على البوتات
        if ((e.pos - zoneCenter).distance > zoneRadius) {
          e.hp -= 5 * dt;
          if (e.hp <= 0) {
            enemies.removeAt(i);
            continue;
          }
        }

        double distToPlayer = (playerPos - e.pos).distance;

        // إذا كان اللاعب قريباً، يصوب البوت نحوه ويطلق النار
        if (distToPlayer < 450) {
          Offset dirToPlayer = (playerPos - e.pos) / distToPlayer;
          e.angle = atan2(dirToPlayer.dy, dirToPlayer.dx);

          // يتحرك نحو اللاعب إذا كان بعيداً قليلاً
          if (distToPlayer > 200) {
            Offset nextEPos = e.pos + dirToPlayer * enemySpeed * dt;
            if (!_collidesWithObstacles(nextEPos, 20)) {
              e.pos = nextEPos;
            }
          }

          e.shootCooldown -= dt;
          if (e.shootCooldown <= 0) {
            e.shootCooldown = 0.8 + _rng.nextDouble() * 0.6;
            // إضافة تشتت بسيط لرصاص البوت
            double spread = (_rng.nextDouble() - 0.5) * 0.25;
            Offset bulletDir = Offset(cos(e.angle + spread), sin(e.angle + spread));
            bullets.add(Bullet(
              pos: e.pos + bulletDir * 25,
              vel: bulletDir * (bulletSpeed * 0.75),
              isPlayer: false,
            ));
          }
        } else {
          // حركة عشوائية أو الهروب نحو مركز الزون
          e.changeDirTimer -= dt;
          if (e.changeDirTimer <= 0) {
            e.changeDirTimer = 1.5 + _rng.nextDouble() * 2;
            if ((e.pos - zoneCenter).distance > zoneRadius * 0.85) {
              // التوجه نحو الزون الآمن
              Offset toCenter = zoneCenter - e.pos;
              e.targetDir = toCenter / toCenter.distance;
            } else {
              double randAngle = _rng.nextDouble() * pi * 2;
              e.targetDir = Offset(cos(randAngle), sin(randAngle));
            }
          }
          Offset nextEPos = e.pos + e.targetDir * (enemySpeed * 0.75) * dt;
          if (!_collidesWithObstacles(nextEPos, 20) &&
              nextEPos.dx > 50 &&
              nextEPos.dx < mapSize - 50 &&
              nextEPos.dy > 50 &&
              nextEPos.dy < mapSize - 50) {
            e.pos = nextEPos;
            e.angle = atan2(e.targetDir.dy, e.targetDir.dx);
          } else {
            e.changeDirTimer = 0;
          }
        }
      }

      // 6. تحديث الرصاص وفحص الإصابات
      for (int i = bullets.length - 1; i >= 0; i--) {
        Bullet b = bullets[i];
        b.pos += b.vel * dt;
        b.distanceTraveled += b.vel.distance * dt;

        // حذف الرصاصة إذا تجاوزت المدى أو اصطدمت بصخرة/شجرة
        if (b.distanceTraveled > 650 || _collidesWithObstacles(b.pos, 4)) {
          bullets.removeAt(i);
          continue;
        }

        if (b.isPlayer) {
          // فحص إصابة الأعداء
          bool hitEnemy = false;
          for (int j = enemies.length - 1; j >= 0; j--) {
            if ((b.pos - enemies[j].pos).distance < 22) {
              enemies[j].hp -= 35;
              hitEnemy = true;
              if (enemies[j].hp <= 0) {
                // إسقاط صندوق لوت عند موت العدو
                loots.add(Loot(
                  pos: enemies[j].pos,
                  type: _rng.nextBool() ? LootType.medkit : LootType.ammo,
                ));
                enemies.removeAt(j);
                kills++;
              }
              break;
            }
          }
          if (hitEnemy) {
            bullets.removeAt(i);
            continue;
          }
        } else {
          // فحص إصابة اللاعب
          if ((b.pos - playerPos).distance < 22) {
            playerHp -= 14;
            bullets.removeAt(i);
            continue;
          }
        }
      }

      // 7. فحص الفوز أو الخسارة
      if (playerHp <= 0) {
        playerHp = 0;
        isPlaying = false;
        isVictory = false;
        _ticker.stop();
      } else if (enemies.isEmpty) {
        isPlaying = false;
        isVictory = true;
        _ticker.stop();
      }
    });
  }

  bool _collidesWithObstacles(Offset pos, double radius) {
    for (final obs in obstacles) {
      Rect expanded = obs.rect.inflate(radius * 0.7);
      if (expanded.contains(pos)) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int aliveCount = enemies.length + (playerHp > 0 ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

          return Stack(
            children: [
              // 1. رسم عالم اللعبة (المنظور العلوي يتبع اللاعب)
              CustomPaint(
                size: screenSize,
                painter: _BattleRoyalePainter(
                  playerPos: playerPos,
                  playerAngle: playerAngle,
                  enemies: enemies,
                  bullets: bullets,
                  loots: loots,
                  obstacles: obstacles,
                  zoneCenter: zoneCenter,
                  zoneRadius: zoneRadius,
                  mapSize: mapSize,
                ),
              ),

              // 2. واجهة المستخدم العلوية (HUD: Alive, Kills, Health, Ammo)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الرادار المصغر (Mini-map)
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          border: Border.all(color: Colors.white54, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: CustomPaint(
                          painter: _MinimapPainter(
                            playerPos: playerPos,
                            enemies: enemies,
                            zoneCenter: zoneCenter,
                            zoneRadius: zoneRadius,
                            mapSize: mapSize,
                          ),
                        ),
                      ),

                      // شريط الدم والذخيرة
                      Column(
                        children: [
                          Container(
                            width: 180,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (playerHp / 100).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: playerHp > 35
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'الذخيرة: $ammo  |  الدم: ${playerHp.toInt()}%',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // عداد الأحياء والقتلى (Alive / Kills) على طريقة ببجي
                      Row(
                        children: [
                          _buildStatBox('ALIVE', '$aliveCount', Colors.orange),
                          const SizedBox(width: 8),
                          _buildStatBox('KILLS', '$kills', Colors.redAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 3. أذرع التحكم باللمس (Dual Joysticks)
              if (isPlaying)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: 28, right: 28, bottom: 28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // عصا التحرك (اليسار)
                        _VirtualJoystick(
                          label: 'تحرك',
                          color: Colors.white,
                          onChange: (offset) {
                            moveInput = offset;
                          },
                        ),

                        // عصا التصويب وإطلاق النار (اليمين)
                        _VirtualJoystick(
                          label: 'إطلاق نار',
                          color: Colors.redAccent,
                          onChange: (offset) {
                            aimInput = offset;
                            isFiring = offset.distance > 0.25;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. شاشة النهاية (Winner Winner Chicken Dinner أو Game Over)
              if (!isPlaying)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isVictory ? Colors.amber : Colors.redAccent,
                        width: 2.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isVictory
                              ? 'WINNER WINNER\nCHICKEN DINNER! 🍗'
                              : 'حظاً أوفر في المرة القادمة!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isVictory ? Colors.amber : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'المركز: #$aliveCount من 20  |  عدد القتلى (Kills): $kills',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[700],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 12),
                          ),
                          onPressed: _startNewGame,
                          child: const Text(
                            'انزل جيم جديد (Play Again)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- رسام عالم اللعبة (Main Painter) -----------------

class _BattleRoyalePainter extends CustomPainter {
  final Offset playerPos;
  final double playerAngle;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<Loot> loots;
  final List<classObstacle> obstacles;
  final Offset zoneCenter;
  final double zoneRadius;
  final double mapSize;

  _BattleRoyalePainter({
    required this.playerPos,
    required this.playerAngle,
    required this.enemies,
    required this.bullets,
    required this.loots,
    required this.obstacles,
    required this.zoneCenter,
    required this.zoneRadius,
    required this.mapSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // تحريك الكاميرا لتكون متمركزة على اللاعب دائماً
    final Offset cameraOffset =
        Offset(size.width / 2, size.height / 2) - playerPos;
    canvas.translate(cameraOffset.dx, cameraOffset.dy);

    // 1. رسم أرضية الخريطة (عشب إرانغل)
    final mapRect = Rect.fromLTWH(0, 0, mapSize, mapSize);
    canvas.drawRect(mapRect, Paint()..color = const Color(0xFF4A6B3B));

    // رسم شبكة الخريطة (Grid) لإعطاء إحساس بالحركة
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 2;
    for (double x = 0; x <= mapSize; x += 150) {
      canvas.drawLine(Offset(x, 0), Offset(x, mapSize), gridPaint);
    }
    for (double y = 0; y <= mapSize; y += 150) {
      canvas.drawLine(Offset(0, y), Offset(mapSize, y), gridPaint);
    }

    // 2. رسم صناديق اللوت (إسعافات وذخيرة)
    for (final l in loots) {
      final rect = Rect.fromCenter(center: l.pos, width: 24, height: 24);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = l.type == LootType.medkit
              ? Colors.white
              : const Color(0xFFD4AC0D),
      );
      if (l.type == LootType.medkit) {
        // علامة الزائد الحمراء للإسعافات
        final crossPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 4;
        canvas.drawLine(
            l.pos + const Offset(-6, 0), l.pos + const Offset(6, 0), crossPaint);
        canvas.drawLine(
            l.pos + const Offset(0, -6), l.pos + const Offset(0, 6), crossPaint);
      }
    }

    // 3. رسم الصخور والأشجار
    for (final obs in obstacles) {
      if (obs.isTree) {
        canvas.drawCircle(
          obs.rect.center,
          obs.rect.width / 2,
          Paint()..color = const Color(0xFF2D4C1E),
        );
        canvas.drawCircle(
          obs.rect.center,
          obs.rect.width / 4,
          Paint()..color = const Color(0xFF1E3512),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(obs.rect, const Radius.circular(12)),
          Paint()..color = Colors.grey[700]!,
        );
      }
    }

    // 4. رسم الأعداء (البوتات)
    for (final e in enemies) {
      _drawSoldier(canvas, e.pos, e.angle, Colors.redAccent);
      // شريط صحة العدو
      if (e.hp < 100) {
        canvas.drawRect(
          Rect.fromLTWH(e.pos.dx - 18, e.pos.dy - 32, 36, 5),
          Paint()..color = Colors.black54,
        );
        canvas.drawRect(
          Rect.fromLTWH(
              e.pos.dx - 18, e.pos.dy - 32, 36 * (e.hp / 100), 5),
          Paint()..color = Colors.red,
        );
      }
    }

    // 5. رسم اللاعب (بخوذة ليفل 3 وسلاح)
    _drawSoldier(canvas, playerPos, playerAngle, const Color(0xFF3498DB),
        isPlayer: true);

    // 6. رسم الرصاص
    final bulletPaint = Paint()..color = Colors.yellowAccent;
    for (final b in bullets) {
      canvas.drawCircle(b.pos, 4.5, bulletPaint);
    }

    // 7. رسم حدود الزون الأزرق (Blue Zone)
    final zoneBorderPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(zoneCenter, zoneRadius, zoneBorderPaint);

    // تظليل خارج الزون باللون الأزرق الشفاف
    final Path outsideZone = Path()
      ..addRect(Rect.fromLTWH(-1000, -1000, mapSize + 2000, mapSize + 2000))
      ..addOval(Rect.fromCircle(center: zoneCenter, radius: zoneRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
        outsideZone, Paint()..color = Colors.blueAccent.withOpacity(0.28));

    canvas.restore();
  }

  void _drawSoldier(Canvas canvas, Offset pos, double angle, Color color,
      {bool isPlayer = false}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // رسم السلاح
    canvas.drawRect(
      const Rect.fromLTWH(8, 4, 22, 6),
      Paint()..color = Colors.black87,
    );

    // جسم الجندي
    canvas.drawCircle(Offset.zero, 18, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // خوذة اللاعب المميزة
    if (isPlayer) {
      canvas.drawCircle(
          const Offset(-2, 0), 12, Paint()..color = Colors.blueGrey[900]!);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BattleRoyalePainter oldDelegate) => true;
}

// ----------------- رسام الرادار المصغر (Mini-map) -----------------

class _MinimapPainter extends CustomPainter {
  final Offset playerPos;
  final List<Enemy> enemies;
  final Offset zoneCenter;
  final double zoneRadius;
  final double mapSize;

  _MinimapPainter({
    required this.playerPos,
    required this.enemies,
    required this.zoneCenter,
    required this.zoneRadius,
    required this.mapSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / mapSize;

    // دائرة الزون في الخريطة المصغرة
    canvas.drawCircle(
      zoneCenter * scale,
      (zoneRadius * scale).clamp(0.0, size.width),
      Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // نقاط الأعداء باللون الأحمر
    final enemyPaint = Paint()..color = Colors.redAccent;
    for (final e in enemies) {
      canvas.drawCircle(e.pos * scale, 2.2, enemyPaint);
    }

    // نقطة اللاعب باللون الأخضر
    canvas.drawCircle(
        playerPos * scale, 3.5, Paint()..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}

// ----------------- أداة عصا التحكم (Virtual Joystick) -----------------

class _VirtualJoystick extends StatefulWidget {
  final String label;
  final Color color;
  final ValueChanged<Offset> onChange;

  const _VirtualJoystick({
    required this.label,
    required this.color,
    required this.onChange,
  });

  @override
  State<_VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<_VirtualJoystick> {
  Offset _knobPos = Offset.zero;
  static const double _maxRadius = 48.0;

  void _updatePosition(Offset localPos) {
    final Offset center = const Offset(_maxRadius, _maxRadius);
    Offset delta = localPos - center;
    if (delta.distance > _maxRadius) {
      delta = (delta / delta.distance) * _maxRadius;
    }
    setState(() => _knobPos = delta);
    widget.onChange(delta / _maxRadius);
  }

  void _reset() {
    setState(() => _knobPos = Offset.zero);
    widget.onChange(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _updatePosition(d.localPosition),
      onPanUpdate: (d) => _updatePosition(d.localPosition),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: Container(
        width: _maxRadius * 2,
        height: _maxRadius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.45),
          border: Border.all(color: widget.color.withOpacity(0.5), width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                color: widget.color.withOpacity(0.35),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Transform.translate(
              offset: _knobPos,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 4)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}