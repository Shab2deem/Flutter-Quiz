import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PubgPcApp());
}

class PubgPcApp extends StatelessWidget {
  const PubgPcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PUBG PC 2D Flutter',
      home: BattleRoyalePcScreen(),
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

class GameObstacle {
  Rect rect;
  bool isTree;
  GameObstacle(this.rect, {this.isTree = false});
}

// ----------------- شاشة اللعبة الرئيسية -----------------

class BattleRoyalePcScreen extends StatefulWidget {
  const BattleRoyalePcScreen({super.key});

  @override
  State<BattleRoyalePcScreen> createState() => _BattleRoyalePcScreenState();
}

class _BattleRoyalePcScreenState extends State<BattleRoyalePcScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastTime = Duration.zero;
  final Random _rng = Random();
  final FocusNode _focusNode = FocusNode();

  // أبعاد الخريطة والفيزياء
  static const double mapSize = 2500.0;
  static const double baseWalkSpeed = 230.0;
  static const double sprintSpeed = 330.0;
  static const double enemySpeed = 140.0;
  static const double bulletSpeed = 800.0;
  static const int maxMagSize = 30;

  // حالة اللاعب
  Offset playerPos = const Offset(mapSize / 2, mapSize / 2);
  double playerAngle = 0;
  double playerHp = 100;
  int currentMag = 30;     // الرصاص في الخزنة الحالية
  int reserveAmmo = 90;    // الرصاص الاحتياطي في الحقيبة
  bool isReloading = false;
  double reloadTimer = 0;
  int kills = 0;

  // حالة اللعبة والزون
  bool isPlaying = false;
  bool isVictory = false;
  double zoneRadius = 1700.0;
  final Offset zoneCenter = const Offset(mapSize / 2, mapSize / 2);

  // مدخلات الكيبورد والماوس
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  Offset _mouseScreenPos = Offset.zero;
  Size _screenSize = Size.zero;
  bool isMouseDown = false;
  double fireCooldown = 0;

  // قوائم عناصر الخريطة
  final List<Enemy> enemies = [];
  final List<Bullet> bullets = [];
  final List<Loot> loots = [];
  final List<GameObstacle> obstacles = [];

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
      currentMag = maxMagSize;
      reserveAmmo = 90;
      isReloading = false;
      reloadTimer = 0;
      kills = 0;
      zoneRadius = 1700.0;
      isVictory = false;
      isPlaying = true;
      isMouseDown = false;
      _pressedKeys.clear();

      enemies.clear();
      bullets.clear();
      loots.clear();
      obstacles.clear();

      // توليد الصخور والأشجار (Cover)
      for (int i = 0; i < 50; i++) {
        double x = 150 + _rng.nextDouble() * (mapSize - 300);
        double y = 150 + _rng.nextDouble() * (mapSize - 300);
        if ((Offset(x, y) - playerPos).distance < 160) continue;
        obstacles.add(
          GameObstacle(
            Rect.fromCenter(center: Offset(x, y), width: 75, height: 75),
            isTree: _rng.nextBool(),
          ),
        );
      }

      // توليد 19 عدو (ليكون المجموع 20 لاعب في الجيم)
      for (int i = 0; i < 19; i++) {
        double x = 200 + _rng.nextDouble() * (mapSize - 400);
        double y = 200 + _rng.nextDouble() * (mapSize - 400);
        if ((Offset(x, y) - playerPos).distance < 400) {
          x = (x + 500).clamp(200.0, mapSize - 200.0);
        }
        enemies.add(Enemy(pos: Offset(x, y)));
      }

      // توليد لوت مبدئي على الأرض
      for (int i = 0; i < 28; i++) {
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
    _focusNode.requestFocus();
  }

  void _triggerReload() {
    if (isReloading || currentMag == maxMagSize || reserveAmmo <= 0) return;
    setState(() {
      isReloading = true;
      reloadTimer = 1.4; // مدة التعمير 1.4 ثانية
    });
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
      if ((playerPos - zoneCenter).distance > zoneRadius) {
        playerHp -= 7 * dt;
      }

      // 2. قراءة حركة الكيبورد (WASD أو الأسهم + Shift للجري)
      double dx = 0;
      double dy = 0;
      if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
        dy -= 1;
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
        dy += 1;
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
        dx -= 1;
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
        dx += 1;
      }

      bool isSprinting = _pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
          _pressedKeys.contains(LogicalKeyboardKey.shiftRight);

      if (dx != 0 || dy != 0) {
        Offset moveDir = Offset(dx, dy);
        moveDir = moveDir / moveDir.distance; // توحيد السرعة في الحركة القطرية
        double currentSpeed =
        (isSprinting && !isMouseDown) ? sprintSpeed : baseWalkSpeed;

        Offset nextPos = playerPos + moveDir * currentSpeed * dt;
        // فصل فحص التصادم أفقياً وعمودياً لانزلاق سلس حول الصخور
        Offset nextPosX =
        Offset(nextPos.dx.clamp(40.0, mapSize - 40.0), playerPos.dy);
        if (!_collidesWithObstacles(nextPosX, 20)) {
          playerPos = nextPosX;
        }
        Offset nextPosY =
        Offset(playerPos.dx, nextPos.dy.clamp(40.0, mapSize - 40.0));
        if (!_collidesWithObstacles(nextPosY, 20)) {
          playerPos = nextPosY;
        }
      }

      // 3. دوران اللاعب نحو مؤشر الماوس دائماً
      if (_screenSize != Size.zero) {
        Offset screenCenter =
        Offset(_screenSize.width / 2, _screenSize.height / 2);
        Offset lookVec = _mouseScreenPos - screenCenter;
        if (lookVec.distance > 1) {
          playerAngle = atan2(lookVec.dy, lookVec.dx);
        }
      }

      // 4. نظام التعمير (Reload) وإطلاق النار بالماوس
      if (isReloading) {
        reloadTimer -= dt;
        if (reloadTimer <= 0) {
          int needed = maxMagSize - currentMag;
          int toLoad = min(needed, reserveAmmo);
          currentMag += toLoad;
          reserveAmmo -= toLoad;
          isReloading = false;
        }
      }

      if (fireCooldown > 0) fireCooldown -= dt;

      if (isMouseDown && !isReloading && fireCooldown <= 0) {
        if (currentMag > 0) {
          fireCooldown = 0.12; // معدل إطلاق M416 سريع
          currentMag--;
          Offset dir = Offset(cos(playerAngle), sin(playerAngle));
          bullets.add(Bullet(
            pos: playerPos + dir * 28,
            vel: dir * bulletSpeed,
            isPlayer: true,
          ));
          if (currentMag == 0 && reserveAmmo > 0) {
            _triggerReload(); // تعمير تلقائي عند انتهاء الخزنة
          }
        } else if (reserveAmmo > 0) {
          _triggerReload();
        }
      }

      // 5. التقاط اللوت
      for (int i = loots.length - 1; i >= 0; i--) {
        if ((loots[i].pos - playerPos).distance < 36) {
          if (loots[i].type == LootType.medkit && playerHp < 100) {
            playerHp = min(100, playerHp + 45);
            loots.removeAt(i);
          } else if (loots[i].type == LootType.ammo) {
            reserveAmmo += 45;
            loots.removeAt(i);
          }
        }
      }

      // 6. تحديث ذكاء البوتات (AI)
      for (int i = enemies.length - 1; i >= 0; i--) {
        Enemy e = enemies[i];

        if ((e.pos - zoneCenter).distance > zoneRadius) {
          e.hp -= 5 * dt;
          if (e.hp <= 0) {
            enemies.removeAt(i);
            continue;
          }
        }

        double distToPlayer = (playerPos - e.pos).distance;

        if (distToPlayer < 480) {
          Offset dirToPlayer = (playerPos - e.pos) / distToPlayer;
          e.angle = atan2(dirToPlayer.dy, dirToPlayer.dx);

          if (distToPlayer > 220) {
            Offset nextEPos = e.pos + dirToPlayer * enemySpeed * dt;
            if (!_collidesWithObstacles(nextEPos, 20)) {
              e.pos = nextEPos;
            }
          }

          e.shootCooldown -= dt;
          if (e.shootCooldown <= 0) {
            e.shootCooldown = 0.75 + _rng.nextDouble() * 0.5;
            double spread = (_rng.nextDouble() - 0.5) * 0.22;
            Offset bulletDir =
            Offset(cos(e.angle + spread), sin(e.angle + spread));
            bullets.add(Bullet(
              pos: e.pos + bulletDir * 25,
              vel: bulletDir * (bulletSpeed * 0.7),
              isPlayer: false,
            ));
          }
        } else {
          e.changeDirTimer -= dt;
          if (e.changeDirTimer <= 0) {
            e.changeDirTimer = 1.5 + _rng.nextDouble() * 2;
            if ((e.pos - zoneCenter).distance > zoneRadius * 0.85) {
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

      // 7. تحديث الرصاص وفحص الإصابات
      for (int i = bullets.length - 1; i >= 0; i--) {
        Bullet b = bullets[i];
        b.pos += b.vel * dt;
        b.distanceTraveled += b.vel.distance * dt;

        if (b.distanceTraveled > 750 || _collidesWithObstacles(b.pos, 4)) {
          bullets.removeAt(i);
          continue;
        }

        if (b.isPlayer) {
          bool hitEnemy = false;
          for (int j = enemies.length - 1; j >= 0; j--) {
            if ((b.pos - enemies[j].pos).distance < 22) {
              enemies[j].hp -= 34;
              hitEnemy = true;
              if (enemies[j].hp <= 0) {
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
          if ((b.pos - playerPos).distance < 22) {
            playerHp -= 12;
            bullets.removeAt(i);
            continue;
          }
        }
      }

      // 8. فحص نهاية الجيم
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
      if (obs.rect.inflate(radius * 0.65).contains(pos)) return true;
    }
    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _triggerReload();
      } else if (event.logicalKey == LogicalKeyboardKey.space && !isPlaying) {
        _startNewGame();
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int aliveCount = enemies.length + (playerHp > 0 ? 1 : 0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          // إخفاء مؤشر الماوس العادي أثناء اللعب لرسم Crosshair احترافي
          cursor: isPlaying ? SystemMouseCursors.none : SystemMouseCursors.basic,
          onHover: (event) {
            _mouseScreenPos = event.localPosition;
          },
          child: Listener(
            onPointerDown: (event) {
              _focusNode.requestFocus();
              _mouseScreenPos = event.localPosition;
              if (event.buttons == kPrimaryMouseButton) {
                isMouseDown = true;
              } else if (event.buttons == kSecondaryMouseButton) {
                _triggerReload(); // كليك يمين للتعمير السريع أيضاً
              }
            },
            onPointerMove: (event) {
              _mouseScreenPos = event.localPosition;
            },
            onPointerUp: (event) {
              isMouseDown = false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                _screenSize = Size(constraints.maxWidth, constraints.maxHeight);

                return Stack(
                  children: [
                    // 1. لوحة رسم عالم اللعبة + مؤشر التصويب (Crosshair)
                    CustomPaint(
                      size: _screenSize,
                      painter: _BattleRoyalePcPainter(
                        playerPos: playerPos,
                        playerAngle: playerAngle,
                        enemies: enemies,
                        bullets: bullets,
                        loots: loots,
                        obstacles: obstacles,
                        zoneCenter: zoneCenter,
                        zoneRadius: zoneRadius,
                        mapSize: mapSize,
                        mouseScreenPos: _mouseScreenPos,
                        isPlaying: isPlaying,
                        isReloading: isReloading,
                      ),
                    ),

                    // 2. الواجهة العلوية (Mini-map + Alive/Kills)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // الرادار المصغر (Mini-map)
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                border:
                                Border.all(color: Colors.white54, width: 2),
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

                            // شريط إرشادات التحكم في الأعلى
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Text(
                                '[WASD] للحركة   |   [Shift] جري سريع   |   [Left Click] ضرب نار   |   [R] تعمير السلاح',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // عداد الأحياء والقتلى (ALIVE / KILLS)
                            Row(
                              children: [
                                _buildStatBox(
                                    'ALIVE', '$aliveCount', Colors.amber),
                                const SizedBox(width: 8),
                                _buildStatBox(
                                    'KILLS', '$kills', Colors.redAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. الواجهة السفلية على ستايل PUBG PC (الدم + الذخيرة)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isReloading)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  'جاري التعمير (RELOADING)...',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // عداد الرصاص (الخزنة / الاحتياطي)
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '$currentMag',
                                        style: TextStyle(
                                          color: currentMag <= 5
                                              ? Colors.redAccent
                                              : Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        ' / $reserveAmmo',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                  // شريط الدم
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'HP: ${playerHp.toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 220,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius:
                                          BorderRadius.circular(8),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor:
                                          (playerHp / 100).clamp(0.0, 1.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: playerHp > 35
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                              borderRadius:
                                              BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4. شاشة النهاية (الفوز أو الخسارة)
                    if (!isPlaying)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                              isVictory ? Colors.amber : Colors.redAccent,
                              width: 2.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isVictory
                                    ? 'WINNER WINNER CHICKEN DINNER! 🍗'
                                    : 'تم إقصاؤك (BETTER LUCK NEXT TIME)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: isVictory
                                      ? Colors.amber
                                      : Colors.redAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'المركز: #$aliveCount من 20   |   عدد القتلى (Kills): $kills',
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[700],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 36, vertical: 14),
                                ),
                                onPressed: _startNewGame,
                                child: const Text(
                                  'العب جيم جديد (أو اضغط Space)',
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
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withOpacity(0.7)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- رسام عالم اللعبة ومؤشر الماوس -----------------

class _BattleRoyalePcPainter extends CustomPainter {
  final Offset playerPos;
  final double playerAngle;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<Loot> loots;
  final List<GameObstacle> obstacles;
  final Offset zoneCenter;
  final double zoneRadius;
  final double mapSize;
  final Offset mouseScreenPos;
  final bool isPlaying;
  final bool isReloading;

  _BattleRoyalePcPainter({
    required this.playerPos,
    required this.playerAngle,
    required this.enemies,
    required this.bullets,
    required this.loots,
    required this.obstacles,
    required this.zoneCenter,
    required this.zoneRadius,
    required this.mapSize,
    required this.mouseScreenPos,
    required this.isPlaying,
    required this.isReloading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // تمركز الكاميرا على اللاعب
    final Offset cameraOffset =
        Offset(size.width / 2, size.height / 2) - playerPos;
    canvas.translate(cameraOffset.dx, cameraOffset.dy);

    // 1. أرضية الخريطة والشبكة
    final mapRect = Rect.fromLTWH(0, 0, mapSize, mapSize);
    canvas.drawRect(mapRect, Paint()..color = const Color(0xFF4A6B3B));

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 2;
    for (double x = 0; x <= mapSize; x += 150) {
      canvas.drawLine(Offset(x, 0), Offset(x, mapSize), gridPaint);
    }
    for (double y = 0; y <= mapSize; y += 150) {
      canvas.drawLine(Offset(0, y), Offset(mapSize, y), gridPaint);
    }

    // 2. رسم صناديق اللوت
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
        final crossPaint = Paint()
          ..color = Colors.red
          ..strokeWidth = 4;
        canvas.drawLine(l.pos + const Offset(-6, 0), l.pos + const Offset(6, 0),
            crossPaint);
        canvas.drawLine(l.pos + const Offset(0, -6), l.pos + const Offset(0, 6),
            crossPaint);
      }
    }

    // 3. رسم الصخور والأشجار
    for (final obs in obstacles) {
      if (obs.isTree) {
        canvas.drawCircle(obs.rect.center, obs.rect.width / 2,
            Paint()..color = const Color(0xFF2D4C1E));
        canvas.drawCircle(obs.rect.center, obs.rect.width / 4,
            Paint()..color = const Color(0xFF1E3512));
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(obs.rect, const Radius.circular(12)),
          Paint()..color = Colors.grey[700]!,
        );
      }
    }

    // 4. رسم الأعداء
    for (final e in enemies) {
      _drawSoldier(canvas, e.pos, e.angle, Colors.redAccent);
      if (e.hp < 100) {
        canvas.drawRect(Rect.fromLTWH(e.pos.dx - 18, e.pos.dy - 32, 36, 5),
            Paint()..color = Colors.black54);
        canvas.drawRect(
            Rect.fromLTWH(e.pos.dx - 18, e.pos.dy - 32, 36 * (e.hp / 100), 5),
            Paint()..color = Colors.red);
      }
    }

    // 5. رسم خط ليزر خفيف للتصويب + اللاعب
    Offset aimDir = Offset(cos(playerAngle), sin(playerAngle));
    canvas.drawLine(
      playerPos + aimDir * 25,
      playerPos + aimDir * 250,
      Paint()
        ..color = Colors.redAccent.withOpacity(0.25)
        ..strokeWidth = 1.5,
    );
    _drawSoldier(canvas, playerPos, playerAngle, const Color(0xFF3498DB),
        isPlayer: true);

    // 6. رسم الرصاص
    final bulletPaint = Paint()..color = Colors.yellowAccent;
    for (final b in bullets) {
      canvas.drawCircle(b.pos, 4.5, bulletPaint);
    }

    // 7. رسم الزون الأزرق
    canvas.drawCircle(
      zoneCenter,
      zoneRadius,
      Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    final Path outsideZone = Path()
      ..addRect(Rect.fromLTWH(-1500, -1500, mapSize + 3000, mapSize + 3000))
      ..addOval(Rect.fromCircle(center: zoneCenter, radius: zoneRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
        outsideZone, Paint()..color = Colors.blueAccent.withOpacity(0.28));

    canvas.restore();

    // 8. رسم مؤشر الماوس القتالي (Crosshair) على الشاشة
    if (isPlaying && mouseScreenPos != Offset.zero) {
      final crosshairPaint = Paint()
        ..color = isReloading ? Colors.amberAccent : Colors.greenAccent
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(mouseScreenPos, 12, crosshairPaint);
      canvas.drawLine(mouseScreenPos + const Offset(-18, 0),
          mouseScreenPos + const Offset(-6, 0), crosshairPaint);
      canvas.drawLine(mouseScreenPos + const Offset(6, 0),
          mouseScreenPos + const Offset(18, 0), crosshairPaint);
      canvas.drawLine(mouseScreenPos + const Offset(0, -18),
          mouseScreenPos + const Offset(0, -6), crosshairPaint);
      canvas.drawLine(mouseScreenPos + const Offset(0, 6),
          mouseScreenPos + const Offset(0, 18), crosshairPaint);
      canvas.drawCircle(
          mouseScreenPos, 2, Paint()..color = Colors.redAccent);
    }
  }

  void _drawSoldier(Canvas canvas, Offset pos, double angle, Color color,
      {bool isPlayer = false}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // السلاح
    canvas.drawRect(
        const Rect.fromLTWH(8, 4, 24, 6), Paint()..color = Colors.black87);

    // الجسم
    canvas.drawCircle(Offset.zero, 18, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      18,
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // خوذة ليفل 3 للاعب
    if (isPlayer) {
      canvas.drawCircle(
          const Offset(-2, 0), 12, Paint()..color = Colors.blueGrey[900]!);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BattleRoyalePcPainter oldDelegate) => true;
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

    canvas.drawCircle(
      zoneCenter * scale,
      (zoneRadius * scale).clamp(0.0, size.width),
      Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final enemyPaint = Paint()..color = Colors.redAccent;
    for (final e in enemies) {
      canvas.drawCircle(e.pos * scale, 2.5, enemyPaint);
    }

    canvas.drawCircle(
        playerPos * scale, 4.0, Paint()..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}