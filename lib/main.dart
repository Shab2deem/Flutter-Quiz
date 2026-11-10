import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:quiz/counterPage.dart';
import 'package:quiz/homepage.dart';

void main() {
  runApp(const PubgBattleRoyaleApp());
}

class PubgBattleRoyaleApp extends StatelessWidget {
  const PubgBattleRoyaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PUBG PC 2D - 50 Players Free For All',
      home: HomePage(),
    );
  }
}

// ----------------- تعريف الأسلحة (Weapons) -----------------

class WeaponSpec {
  final String name;
  final double fireDelay;
  final double damage;
  final double bulletSpeed;
  final int pellets;
  final double spread;
  final int magSize;
  final double reloadTime;
  final double shakeIntensity;
  final Color tracerColor;
  final double barrelLength;

  const WeaponSpec({
    required this.name,
    required this.fireDelay,
    required this.damage,
    required this.bulletSpeed,
    required this.pellets,
    required this.spread,
    required this.magSize,
    required this.reloadTime,
    required this.shakeIntensity,
    required this.tracerColor,
    required this.barrelLength,
  });
}

const List<WeaponSpec> kWeapons = [
  WeaponSpec(
    name: 'M416',
    fireDelay: 0.095,
    damage: 34,
    bulletSpeed: 1200,
    pellets: 1,
    spread: 0.04,
    magSize: 30,
    reloadTime: 1.35,
    shakeIntensity: 3.0,
    tracerColor: Color(0xFFFFEA00),
    barrelLength: 32,
  ),
  WeaponSpec(
    name: 'S12K Shotgun',
    fireDelay: 0.40,
    damage: 24,
    bulletSpeed: 950,
    pellets: 6,
    spread: 0.24,
    magSize: 8,
    reloadTime: 1.7,
    shakeIntensity: 8.0,
    tracerColor: Color(0xFFFF9100),
    barrelLength: 28,
  ),
  WeaponSpec(
    name: 'AWM Sniper',
    fireDelay: 1.1,
    damage: 135,
    bulletSpeed: 1900,
    pellets: 1,
    spread: 0.004,
    magSize: 5,
    reloadTime: 2.1,
    shakeIntensity: 13.0,
    tracerColor: Color(0xFF00E5FF),
    barrelLength: 44,
  ),
];

// ----------------- الكيانات الأساسية (Entities) -----------------

enum DropState { inPlane, parachuting, grounded }

class MapPOI {
  final String name;
  final Offset center;
  final double radius;
  const MapPOI(this.name, this.center, this.radius);
}

class Bullet {
  final String ownerId;
  final String ownerName;
  Offset pos;
  Offset prevPos;
  final Offset vel;
  final double damage;
  final Color color;
  double distanceTraveled = 0;

  Bullet({
    required this.ownerId,
    required this.ownerName,
    required this.pos,
    required this.vel,
    required this.damage,
    required this.color,
  }) : prevPos = pos;
}

class Particle {
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  double life;
  final double maxLife;
  double rotation;
  final double rotSpeed;
  final bool isShell;

  Particle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.life,
    this.rotation = 0,
    this.rotSpeed = 0,
    this.isShell = false,
  }) : maxLife = life;
}

class GroundDecal {
  final Offset pos;
  final double radius;
  final Color color;
  double life;

  GroundDecal({
    required this.pos,
    required this.radius,
    required this.color,
    this.life = 15.0,
  });
}

class FloatingText {
  Offset pos;
  final String text;
  final Color color;
  double life = 0.85;

  FloatingText({required this.pos, required this.text, required this.color});
}

class BotFighter {
  final String id;
  final String name;
  Offset pos;
  double angle;
  double hp = 100;
  double maxHp = 100;
  final int weaponIdx;
  DropState dropState = DropState.inPlane;
  double altitude = 100.0;
  final double jumpProgress;
  Offset parachuteDir = Offset.zero;

  double shootCooldown = 0;
  Offset wanderDir = Offset.zero;
  double wanderTimer = 0;
  double muzzleFlashTimer = 0;
  double recoilOffset = 0;

  BotFighter({
    required this.id,
    required this.name,
    required this.pos,
    required this.jumpProgress,
    required this.weaponIdx,
    this.angle = 0,
  });
}

enum LootType { medkit, ammo, shield, airdropCrate }

class Loot {
  final Offset pos;
  final LootType type;
  double smokeTimer = 0;

  Loot({required this.pos, required this.type});
}

enum ObstacleType { tree, rock, buildingWall }

class MapObstacle {
  final Rect rect;
  final ObstacleType type;
  final List<Offset> rockPolygon;

  MapObstacle({
    required this.rect,
    required this.type,
    this.rockPolygon = const [],
  });
}

// ----------------- محرك اللعبة (GameEngine) -----------------

class GameEngine extends ChangeNotifier {
  final Random _rng = Random();

  static const double mapSize = 8000.0;
  static const double walkSpeed = 260.0;
  static const double sprintSpeed = 380.0;
  static const double parachuteMoveSpeed = 480.0;
  static const double botWalkSpeed = 195.0;

  final List<MapPOI> pois = const [
    MapPOI('POCHINKI', Offset(4000, 4000), 650),
    MapPOI('MILITARY BASE', Offset(5800, 6300), 700),
    MapPOI('SCHOOL', Offset(2500, 2400), 500),
    MapPOI('GEORGOPOL', Offset(1900, 5600), 650),
    MapPOI('ROZHOK', Offset(5600, 2200), 550),
  ];

  // الطائرة
  Offset planeStart = Offset.zero;
  Offset planeEnd = Offset.zero;
  Offset planePos = Offset.zero;
  double planeAngle = 0;
  double planeProgress = 0;
  bool planeActive = true;

  // حالة اللاعب
  Offset playerPos = const Offset(4000, 4000);
  double playerAngle = 0;
  double playerHp = 100;
  double playerArmor = 50;
  DropState playerDropState = DropState.inPlane;
  double playerAltitude = 100.0;

  int weaponIndex = 0;
  List<int> currentMags = [30, 8, 5];
  List<int> reserveAmmos = [150, 36, 10];
  bool isReloading = false;
  double reloadTimer = 0;
  int playerKills = 0;
  String eliminatedBy = '';

  // الكاميرا والمؤثرات
  Offset cameraPos = const Offset(4000, 4000);
  double cameraZoom = 0.45;
  double muzzleFlashTimer = 0;
  double gunRecoil = 0;
  double screenShake = 0;
  double hitVignette = 0;
  double dustTimer = 0;

  // الزون وحالة الجيم
  bool isPlaying = false;
  bool isVictory = false;
  double zoneRadius = 5600.0;
  Offset zoneCenter = const Offset(4000, 4000);

  // المدخلات
  final Set<LogicalKeyboardKey> manualKeys = {};
  Offset mouseScreenPos = Offset.zero;
  Size screenSize = Size.zero;
  bool isLeftMouseDown = false;
  bool isRightMouseDown = false;
  double fireCooldown = 0;

  // القوائم
  final List<BotFighter> bots = [];
  final List<Bullet> bullets = [];
  final List<Loot> loots = [];
  final List<MapObstacle> obstacles = [];
  final List<Rect> buildingFloors = [];
  final List<Particle> particles = [];
  final List<GroundDecal> decals = [];
  final List<FloatingText> floatingTexts = [];
  final List<String> killFeed = [];

  WeaponSpec get activeWeapon => kWeapons[weaponIndex];
  int get aliveCount => bots.length + (playerHp > 0 ? 1 : 0);

  void startNewGame() {
    double startAngle = _rng.nextDouble() * pi * 2;
    const Offset center = Offset(mapSize / 2, mapSize / 2);
    planeStart = center + Offset(cos(startAngle), sin(startAngle)) * 3700;
    planeEnd =
        center + Offset(cos(startAngle + pi), sin(startAngle + pi)) * 3700;
    planePos = planeStart;
    planeAngle =
        atan2(planeEnd.dy - planeStart.dy, planeEnd.dx - planeStart.dx);
    planeProgress = 0.0;
    planeActive = true;

    playerPos = planePos;
    cameraPos = planePos;
    cameraZoom = 0.42;
    playerHp = 100;
    playerArmor = 50;
    playerDropState = DropState.inPlane;
    playerAltitude = 100.0;
    weaponIndex = 0;
    currentMags = [30, 8, 5];
    reserveAmmos = [150, 36, 10];
    isReloading = false;
    reloadTimer = 0;
    playerKills = 0;
    eliminatedBy = '';

    zoneCenter = Offset(
      2600 + _rng.nextDouble() * (mapSize - 5200),
      2600 + _rng.nextDouble() * (mapSize - 5200),
    );
    zoneRadius = 5600.0;
    isVictory = false;
    isPlaying = true;
    isLeftMouseDown = false;
    isRightMouseDown = false;
    screenShake = 0;
    hitVignette = 0;
    manualKeys.clear();

    bots.clear();
    bullets.clear();
    loots.clear();
    obstacles.clear();
    buildingFloors.clear();
    particles.clear();
    decals.clear();
    floatingTexts.clear();
    killFeed.clear();

    for (final poi in pois) {
      const int buildingCount = 7;
      for (int b = 0; b < buildingCount; b++) {
        double ang = (b / buildingCount) * pi * 2;
        double dist = 160 + (b % 2) * 190.0;
        Offset bCenter = poi.center + Offset(cos(ang) * dist, sin(ang) * dist);
        _createBuilding(bCenter, 170, 140);

        loots.add(Loot(
          pos: bCenter + const Offset(-30, -20),
          type: LootType.values[_rng.nextInt(3)],
        ));
        loots.add(Loot(
          pos: bCenter + const Offset(30, 20),
          type: LootType.values[_rng.nextInt(3)],
        ));
      }
    }

    for (int i = 0; i < 360; i++) {
      double x = 250 + _rng.nextDouble() * (mapSize - 500);
      double y = 250 + _rng.nextDouble() * (mapSize - 500);
      Offset pos = Offset(x, y);

      bool insideBuilding = false;
      for (final f in buildingFloors) {
        if (f.inflate(45).contains(pos)) {
          insideBuilding = true;
          break;
        }
      }
      if (insideBuilding) continue;

      bool isTree = _rng.nextDouble() > 0.35;
      double size = isTree ? (85.0 + _rng.nextDouble() * 25) : 78.0;
      List<Offset> poly = [];
      if (!isTree) {
        const int sides = 7;
        for (int s = 0; s < sides; s++) {
          double ang = (s / sides) * pi * 2;
          double r = (size / 2) * (0.75 + _rng.nextDouble() * 0.3);
          poly.add(Offset(x + cos(ang) * r, y + sin(ang) * r));
        }
      }
      obstacles.add(MapObstacle(
        rect: Rect.fromCenter(center: pos, width: size, height: size),
        type: isTree ? ObstacleType.tree : ObstacleType.rock,
        rockPolygon: poly,
      ));
    }

    for (int i = 0; i < 140; i++) {
      double x = 300 + _rng.nextDouble() * (mapSize - 600);
      double y = 300 + _rng.nextDouble() * (mapSize - 600);
      loots.add(Loot(
        pos: Offset(x, y),
        type: LootType.values[_rng.nextInt(3)],
      ));
    }
    for (int i = 0; i < 8; i++) {
      double x = 1200 + _rng.nextDouble() * (mapSize - 2400);
      double y = 1200 + _rng.nextDouble() * (mapSize - 2400);
      loots.add(Loot(pos: Offset(x, y), type: LootType.airdropCrate));
    }

    for (int i = 0; i < 49; i++) {
      double jumpAt = 0.06 + _rng.nextDouble() * 0.86;
      double randAngle = _rng.nextDouble() * pi * 2;
      BotFighter bot = BotFighter(
        id: 'bot_$i',
        name: _generateBotName(i),
        pos: planeStart,
        jumpProgress: jumpAt,
        weaponIdx:
        _rng.nextDouble() < 0.72 ? 0 : (_rng.nextDouble() < 0.8 ? 1 : 2),
      );
      bot.parachuteDir = Offset(cos(randAngle), sin(randAngle));
      bots.add(bot);
    }

    notifyListeners();
  }

  void _createBuilding(Offset center, double w, double h) {
    Rect floor = Rect.fromCenter(center: center, width: w, height: h);
    buildingFloors.add(floor);
    const double t = 14.0;
    const double doorGap = 46.0;

    obstacles.add(MapObstacle(
      rect: Rect.fromLTWH(floor.left, floor.top, (w - doorGap) / 2, t),
      type: ObstacleType.buildingWall,
    ));
    obstacles.add(MapObstacle(
      rect: Rect.fromLTWH(
          floor.right - (w - doorGap) / 2, floor.top, (w - doorGap) / 2, t),
      type: ObstacleType.buildingWall,
    ));
    obstacles.add(MapObstacle(
      rect: Rect.fromLTWH(floor.left, floor.bottom - t, (w - doorGap) / 2, t),
      type: ObstacleType.buildingWall,
    ));
    obstacles.add(MapObstacle(
      rect: Rect.fromLTWH(floor.right - (w - doorGap) / 2, floor.bottom - t,
          (w - doorGap) / 2, t),
      type: ObstacleType.buildingWall,
    ));
    obstacles.add(MapObstacle(
      rect: Rect.fromLTWH(floor.left, floor.top, t, h),
      type: ObstacleType.buildingWall,
    ));
    obstacles.add(MapObstacle(
      rect: Rect.fromLTWH(floor.right - t, floor.top, t, h),
      type: ObstacleType.buildingWall,
    ));
  }

  String _generateBotName(int index) {
    const prefixes = [
      'Pharaoh', 'Sniper', 'Ghost', 'Cobra', 'Viper', 'Shadow', 'Falcon',
      'Apex', 'Delta', 'Erangel', 'Pochinki', 'Legend', 'Storm', 'Toxic',
      'Hunter', 'Knight', 'Wolf', 'Dragon', 'MidEast', 'NoScope'
    ];
    return '${prefixes[index % prefixes.length]}_${10 + index}';
  }

  // يدعم الكيبورد سواء كان إنجليزي أو عربي بدون أي تعارض مع الماوس
  bool _isKeyPressed(PhysicalKeyboardKey pKey, LogicalKeyboardKey lKey,
      [LogicalKeyboardKey? altKey]) {
    final phys = HardwareKeyboard.instance.physicalKeysPressed;
    final log = HardwareKeyboard.instance.logicalKeysPressed;
    if (phys.contains(pKey) || log.contains(lKey) || manualKeys.contains(lKey)) {
      return true;
    }
    if (altKey != null &&
        (log.contains(altKey) || manualKeys.contains(altKey))) {
      return true;
    }
    return false;
  }

  void jumpFromPlane() {
    if (playerDropState == DropState.inPlane) {
      playerDropState = DropState.parachuting;
      playerAltitude = 100.0;
    }
  }

  void switchWeapon(int index) {
    if (index == weaponIndex || index < 0 || index >= kWeapons.length) return;
    weaponIndex = index;
    isReloading = false;
    reloadTimer = 0;
  }

  void triggerReload() {
    if (playerDropState != DropState.grounded) return;
    int mag = currentMags[weaponIndex];
    int res = reserveAmmos[weaponIndex];
    if (isReloading || mag == activeWeapon.magSize || res <= 0) return;
    isReloading = true;
    reloadTimer = activeWeapon.reloadTime;
  }

  void update(double dt) {
    if (!isPlaying) return;

    if (muzzleFlashTimer > 0) muzzleFlashTimer -= dt;
    if (gunRecoil > 0) gunRecoil = max(0, gunRecoil - 35 * dt);
    if (screenShake > 0) screenShake = max(0, screenShake - 28 * dt);
    if (hitVignette > 0) hitVignette = max(0, hitVignette - 2.0 * dt);

    if (planeActive) {
      planeProgress += dt * 0.085;
      if (planeProgress >= 1.0) {
        planeProgress = 1.0;
        planeActive = false;
        if (playerDropState == DropState.inPlane) {
          jumpFromPlane();
        }
      }
      planePos = Offset.lerp(planeStart, planeEnd, planeProgress)!;
    }

    if (!planeActive && zoneRadius > 320) {
      zoneRadius -= 36 * dt;
    }
    if (playerDropState == DropState.grounded &&
        (playerPos - zoneCenter).distance > zoneRadius) {
      playerHp -= 6.5 * dt;
      hitVignette = max(hitVignette, 0.45);
    }

    double dx = 0, dy = 0;
    if (_isKeyPressed(PhysicalKeyboardKey.keyW, LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.arrowUp)) {
      dy -= 1;
    }
    if (_isKeyPressed(PhysicalKeyboardKey.keyS, LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.arrowDown)) {
      dy += 1;
    }
    if (_isKeyPressed(PhysicalKeyboardKey.keyA, LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.arrowLeft)) {
      dx -= 1;
    }
    if (_isKeyPressed(PhysicalKeyboardKey.keyD, LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.arrowRight)) {
      dx += 1;
    }

    bool isSprinting = (_isKeyPressed(
        PhysicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftLeft) ||
        _isKeyPressed(
            PhysicalKeyboardKey.shiftRight, LogicalKeyboardKey.shiftRight)) &&
        !isLeftMouseDown &&
        !isRightMouseDown;

    if (playerDropState == DropState.inPlane) {
      playerPos = planePos;
      cameraZoom = 0.42;
    } else if (playerDropState == DropState.parachuting) {
      double diveMultiplier = isSprinting ? 34.0 : 22.0;
      playerAltitude -= diveMultiplier * dt;

      Offset glideDir = Offset(dx, dy);
      if (glideDir != Offset.zero) {
        glideDir = glideDir / glideDir.distance;
        playerAngle = atan2(glideDir.dy, glideDir.dx);
        playerPos += glideDir * parachuteMoveSpeed * dt;
      } else {
        playerPos += Offset(cos(playerAngle), sin(playerAngle)) * 140 * dt;
      }
      playerPos = Offset(
        playerPos.dx.clamp(120.0, mapSize - 120.0),
        playerPos.dy.clamp(120.0, mapSize - 120.0),
      );

      double targetZoom = 1.0 - (playerAltitude / 100.0) * 0.48;
      cameraZoom =
      ui.lerpDouble(cameraZoom, targetZoom, (8 * dt).clamp(0.0, 1.0))!;

      if (playerAltitude <= 0) {
        playerAltitude = 0;
        playerDropState = DropState.grounded;
        cameraZoom = 1.0;
        _pushOutFromObstacles();
      }
    } else {
      double targetZoom = isRightMouseDown ? 0.82 : 1.0;
      cameraZoom =
      ui.lerpDouble(cameraZoom, targetZoom, (10 * dt).clamp(0.0, 1.0))!;

      if (dx != 0 || dy != 0) {
        Offset moveDir = Offset(dx, dy);
        moveDir = moveDir / moveDir.distance;
        double spd = isSprinting ? sprintSpeed : walkSpeed;

        Offset nextX = Offset(
          (playerPos.dx + moveDir.dx * spd * dt).clamp(80.0, mapSize - 80.0),
          playerPos.dy,
        );
        if (!_collidesWithObstacles(nextX, 20)) playerPos = nextX;

        Offset nextY = Offset(
          playerPos.dx,
          (playerPos.dy + moveDir.dy * spd * dt).clamp(80.0, mapSize - 80.0),
        );
        if (!_collidesWithObstacles(nextY, 20)) playerPos = nextY;

        dustTimer -= dt;
        if (isSprinting && dustTimer <= 0) {
          dustTimer = 0.09;
          _spawnParticles(
            pos: playerPos - moveDir * 14,
            color: const Color(0x77D7CCC8),
            count: 2,
            minSpeed: 10,
            maxSpeed: 35,
            size: 5,
            life: 0.35,
          );
        }
      }
    }

    if (screenSize != Size.zero) {
      Offset screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
      Offset mouseOffset = mouseScreenPos - screenCenter;

      if (playerDropState == DropState.grounded) {
        double peekFactor = isRightMouseDown ? 0.45 : 0.08;
        Offset targetCam = playerPos + (mouseOffset / cameraZoom) * peekFactor;
        cameraPos =
        Offset.lerp(cameraPos, targetCam, (14 * dt).clamp(0.0, 1.0))!;

        Offset mouseWorldPos = cameraPos + (mouseOffset / cameraZoom);
        Offset aimVec = mouseWorldPos - playerPos;
        if (aimVec.distance > 2) {
          playerAngle = atan2(aimVec.dy, aimVec.dx);
        }
      } else {
        cameraPos =
        Offset.lerp(cameraPos, playerPos, (14 * dt).clamp(0.0, 1.0))!;
      }
    }

    if (playerDropState == DropState.grounded) {
      if (isReloading) {
        reloadTimer -= dt;
        if (reloadTimer <= 0) {
          int needed = activeWeapon.magSize - currentMags[weaponIndex];
          int toLoad = min(needed, reserveAmmos[weaponIndex]);
          currentMags[weaponIndex] += toLoad;
          reserveAmmos[weaponIndex] -= toLoad;
          isReloading = false;
        }
      }

      if (fireCooldown > 0) fireCooldown -= dt;

      if (isLeftMouseDown && !isReloading && fireCooldown <= 0) {
        if (currentMags[weaponIndex] > 0) {
          fireCooldown = activeWeapon.fireDelay;
          currentMags[weaponIndex]--;
          muzzleFlashTimer = 0.055;
          gunRecoil = 8.0;
          screenShake = max(screenShake, activeWeapon.shakeIntensity);

          Offset barrelDir = Offset(cos(playerAngle), sin(playerAngle));
          Offset muzzlePos = playerPos + barrelDir * activeWeapon.barrelLength;

          for (int p = 0; p < activeWeapon.pellets; p++) {
            double spreadAngle =
                playerAngle + (_rng.nextDouble() - 0.5) * activeWeapon.spread;
            Offset dir = Offset(cos(spreadAngle), sin(spreadAngle));
            bullets.add(Bullet(
              ownerId: 'player',
              ownerName: 'You [${activeWeapon.name}]',
              pos: muzzlePos,
              vel: dir * activeWeapon.bulletSpeed,
              damage: activeWeapon.damage,
              color: activeWeapon.tracerColor,
            ));
          }

          _spawnShellCasing(playerPos + barrelDir * 12, playerAngle);

          if (currentMags[weaponIndex] == 0 && reserveAmmos[weaponIndex] > 0) {
            triggerReload();
          }
        } else if (reserveAmmos[weaponIndex] > 0) {
          triggerReload();
        }
      }
    }

    Rect viewRect = _getVisibleWorldRect().inflate(200);
    for (int i = loots.length - 1; i >= 0; i--) {
      Loot l = loots[i];
      if (l.type == LootType.airdropCrate && viewRect.contains(l.pos)) {
        l.smokeTimer -= dt;
        if (l.smokeTimer <= 0) {
          l.smokeTimer = 0.07;
          particles.add(Particle(
            pos: l.pos +
                Offset((_rng.nextDouble() - 0.5) * 16,
                    (_rng.nextDouble() - 0.5) * 16),
            vel: Offset(
                18 + _rng.nextDouble() * 20, -25 - _rng.nextDouble() * 20),
            color: const Color(0x99FF1744),
            size: 10 + _rng.nextDouble() * 7,
            life: 1.0,
          ));
        }
      }

      if (playerDropState == DropState.grounded &&
          (l.pos - playerPos).distance < 42) {
        if (l.type == LootType.medkit && playerHp < 100) {
          playerHp = min(100, playerHp + 45);
          floatingTexts.add(FloatingText(
              pos: playerPos, text: '+45 HP', color: Colors.greenAccent));
          loots.removeAt(i);
        } else if (l.type == LootType.ammo) {
          reserveAmmos[0] += 45;
          reserveAmmos[1] += 12;
          floatingTexts.add(FloatingText(
              pos: playerPos, text: '+AMMO', color: Colors.amberAccent));
          loots.removeAt(i);
        } else if (l.type == LootType.shield && playerArmor < 100) {
          playerArmor = min(100, playerArmor + 50);
          floatingTexts.add(FloatingText(
              pos: playerPos, text: '+50 ARMOR', color: Colors.cyanAccent));
          loots.removeAt(i);
        } else if (l.type == LootType.airdropCrate) {
          playerHp = 100;
          playerArmor = 100;
          reserveAmmos[2] += 15;
          weaponIndex = 2;
          floatingTexts.add(FloatingText(
              pos: playerPos,
              text: 'AIRDROP LOOTED! (AWM + LVL3)',
              color: Colors.cyanAccent));
          loots.removeAt(i);
        }
      }
    }

    _updateBotsFreeForAll(dt);
    _updateBullets(dt, viewRect);

    for (int i = particles.length - 1; i >= 0; i--) {
      Particle p = particles[i];
      p.pos += p.vel * dt;
      p.vel *= (1.0 - 3.5 * dt).clamp(0.0, 1.0);
      p.rotation += p.rotSpeed * dt;
      p.life -= dt;
      if (p.life <= 0) particles.removeAt(i);
    }

    for (int i = decals.length - 1; i >= 0; i--) {
      decals[i].life -= dt;
      if (decals[i].life <= 0) decals.removeAt(i);
    }

    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      floatingTexts[i].pos += Offset(0, -40 * dt);
      floatingTexts[i].life -= dt;
      if (floatingTexts[i].life <= 0) floatingTexts.removeAt(i);
    }

    if (playerHp <= 0) {
      playerHp = 0;
      isPlaying = false;
      isVictory = false;
    } else if (bots.isEmpty) {
      isPlaying = false;
      isVictory = true;
    }

    notifyListeners();
  }

  void _updateBotsFreeForAll(double dt) {
    for (int i = bots.length - 1; i >= 0; i--) {
      BotFighter b = bots[i];
      if (b.muzzleFlashTimer > 0) b.muzzleFlashTimer -= dt;
      if (b.recoilOffset > 0) b.recoilOffset = max(0, b.recoilOffset - 25 * dt);

      if (b.dropState == DropState.inPlane) {
        b.pos = planePos;
        if (planeProgress >= b.jumpProgress || !planeActive) {
          b.dropState = DropState.parachuting;
          b.altitude = 100.0;
        }
        continue;
      }

      if (b.dropState == DropState.parachuting) {
        b.altitude -= 24.0 * dt;
        b.pos += b.parachuteDir * 340 * dt;
        b.pos = Offset(
          b.pos.dx.clamp(150.0, mapSize - 150.0),
          b.pos.dy.clamp(150.0, mapSize - 150.0),
        );
        b.angle = atan2(b.parachuteDir.dy, b.parachuteDir.dx);
        if (b.altitude <= 0) {
          b.altitude = 0;
          b.dropState = DropState.grounded;
        }
        continue;
      }

      if ((b.pos - zoneCenter).distance > zoneRadius) {
        b.hp -= 6.0 * dt;
        if (b.hp <= 0) {
          _addKillFeed('Blue Zone', b.name);
          bots.removeAt(i);
          continue;
        }
      }

      Offset? closestTargetPos;
      double closestDist = 600.0;

      if (playerDropState == DropState.grounded && playerHp > 0) {
        double dPlayer = (playerPos - b.pos).distance;
        if (dPlayer < closestDist) {
          closestDist = dPlayer;
          closestTargetPos = playerPos;
        }
      }

      for (int j = 0; j < bots.length; j++) {
        if (i == j) continue;
        BotFighter other = bots[j];
        if (other.dropState != DropState.grounded) continue;
        double dBot = (other.pos - b.pos).distance;
        if (dBot < closestDist) {
          closestDist = dBot;
          closestTargetPos = other.pos;
        }
      }

      if (closestTargetPos != null && closestDist > 1) {
        Offset dirToTarget = (closestTargetPos - b.pos) / closestDist;
        b.angle = atan2(dirToTarget.dy, dirToTarget.dx);

        if (closestDist > 240) {
          Offset nextPos = b.pos + dirToTarget * botWalkSpeed * dt;
          if (!_collidesWithObstacles(nextPos, 20)) {
            b.pos = nextPos;
          }
        }

        b.shootCooldown -= dt;
        if (b.shootCooldown <= 0) {
          WeaponSpec w = kWeapons[b.weaponIdx];
          b.shootCooldown = (w.fireDelay * 3.2) + _rng.nextDouble() * 0.45;
          b.muzzleFlashTimer = 0.05;
          b.recoilOffset = 6.0;

          double spread = (_rng.nextDouble() - 0.5) * 0.20;
          Offset bDir = Offset(cos(b.angle + spread), sin(b.angle + spread));
          bullets.add(Bullet(
            ownerId: b.id,
            ownerName: '${b.name} [${w.name}]',
            pos: b.pos + bDir * 28,
            vel: bDir * (w.bulletSpeed * 0.72),
            damage: w.damage * 0.55,
            color: w.tracerColor,
          ));
        }
      } else {
        b.wanderTimer -= dt;
        if (b.wanderTimer <= 0) {
          b.wanderTimer = 1.8 + _rng.nextDouble() * 2.5;
          if ((b.pos - zoneCenter).distance > zoneRadius * 0.78) {
            Offset toCenter = zoneCenter - b.pos;
            b.wanderDir = toCenter / toCenter.distance;
          } else {
            double rAng = _rng.nextDouble() * pi * 2;
            b.wanderDir = Offset(cos(rAng), sin(rAng));
          }
        }
        Offset nextPos = b.pos + b.wanderDir * (botWalkSpeed * 0.85) * dt;
        if (!_collidesWithObstacles(nextPos, 20) &&
            nextPos.dx > 100 &&
            nextPos.dx < mapSize - 100 &&
            nextPos.dy > 100 &&
            nextPos.dy < mapSize - 100) {
          b.pos = nextPos;
          b.angle = atan2(b.wanderDir.dy, b.wanderDir.dx);
        } else {
          b.wanderTimer = 0;
        }
      }
    }
  }

  void _updateBullets(double dt, Rect viewRect) {
    for (int i = bullets.length - 1; i >= 0; i--) {
      Bullet b = bullets[i];
      b.prevPos = b.pos;
      b.pos += b.vel * dt;
      b.distanceTraveled += b.vel.distance * dt;

      if (_collidesWithObstacles(b.pos, 4)) {
        if (viewRect.contains(b.pos)) {
          _spawnParticles(
            pos: b.pos,
            color: const Color(0xFFFFD54F),
            count: 5,
            minSpeed: 50,
            maxSpeed: 180,
            size: 3.5,
            life: 0.22,
          );
        }
        bullets.removeAt(i);
        continue;
      }

      if (b.distanceTraveled > 1350) {
        bullets.removeAt(i);
        continue;
      }

      bool bulletConsumed = false;

      if (b.ownerId != 'player' &&
          playerDropState == DropState.grounded &&
          (b.pos - playerPos).distance < 22) {
        double dmg = b.damage;
        if (playerArmor > 0) {
          double absorbed = min(playerArmor, dmg * 0.55);
          playerArmor -= absorbed;
          dmg -= absorbed;
        }
        playerHp -= dmg;
        eliminatedBy = b.ownerName;
        hitVignette = 0.85;
        screenShake = max(screenShake, 6.5);
        _spawnParticles(
          pos: playerPos,
          color: const Color(0xFFD50000),
          count: 7,
          minSpeed: 40,
          maxSpeed: 140,
          size: 4,
          life: 0.3,
        );
        bullets.removeAt(i);
        continue;
      }

      for (int j = bots.length - 1; j >= 0; j--) {
        BotFighter targetBot = bots[j];
        if (targetBot.id == b.ownerId ||
            targetBot.dropState != DropState.grounded) {
          continue;
        }

        if ((b.pos - targetBot.pos).distance < 23) {
          targetBot.hp -= b.damage;
          bulletConsumed = true;

          if (viewRect.contains(targetBot.pos)) {
            _spawnParticles(
              pos: b.pos,
              color: const Color(0xFFD50000),
              count: 8,
              minSpeed: 40,
              maxSpeed: 160,
              size: 4.5,
              life: 0.32,
            );
            decals.add(GroundDecal(
              pos: targetBot.pos,
              radius: 12,
              color: const Color(0x888B0000),
            ));
            if (b.ownerId == 'player') {
              floatingTexts.add(FloatingText(
                pos: targetBot.pos + const Offset(0, -24),
                text: '-${b.damage.toInt()}',
                color:
                b.damage >= 100 ? Colors.cyanAccent : Colors.amberAccent,
              ));
            }
          }

          if (targetBot.hp <= 0) {
            loots.add(Loot(
              pos: targetBot.pos,
              type: LootType.values[_rng.nextInt(3)],
            ));
            _addKillFeed(b.ownerName, targetBot.name);
            if (b.ownerId == 'player') {
              playerKills++;
            }
            bots.removeAt(j);
          }
          break;
        }
      }

      if (bulletConsumed) {
        bullets.removeAt(i);
      }
    }
  }

  Rect _getVisibleWorldRect() {
    if (screenSize == Size.zero) {
      return Rect.fromCenter(center: cameraPos, width: 1920, height: 1080);
    }
    return Rect.fromCenter(
      center: cameraPos,
      width: (screenSize.width / cameraZoom) + 220,
      height: (screenSize.height / cameraZoom) + 220,
    );
  }

  void _pushOutFromObstacles() {
    for (int attempt = 0; attempt < 12; attempt++) {
      if (!_collidesWithObstacles(playerPos, 22)) break;
      playerPos += const Offset(28, 28);
    }
  }

  bool _collidesWithObstacles(Offset pos, double radius) {
    final double r = radius * 0.58;
    for (int i = 0; i < obstacles.length; i++) {
      final Rect rect = obstacles[i].rect;
      if (pos.dx + r > rect.left &&
          pos.dx - r < rect.right &&
          pos.dy + r > rect.top &&
          pos.dy - r < rect.bottom) {
        return true;
      }
    }
    return false;
  }

  void _spawnParticles({
    required Offset pos,
    required Color color,
    required int count,
    double minSpeed = 40,
    double maxSpeed = 180,
    double size = 4,
    double life = 0.4,
  }) {
    if (particles.length > 250) return;
    for (int i = 0; i < count; i++) {
      double ang = _rng.nextDouble() * pi * 2;
      double spd = minSpeed + _rng.nextDouble() * (maxSpeed - minSpeed);
      particles.add(Particle(
        pos: pos,
        vel: Offset(cos(ang) * spd, sin(ang) * spd),
        color: color,
        size: size * (0.7 + _rng.nextDouble() * 0.6),
        life: life * (0.7 + _rng.nextDouble() * 0.5),
      ));
    }
  }

  void _spawnShellCasing(Offset pos, double shootAngle) {
    if (particles.length > 250) return;
    double ejectAngle = shootAngle + pi / 2 + (_rng.nextDouble() - 0.5) * 0.4;
    double speed = 90 + _rng.nextDouble() * 60;
    particles.add(Particle(
      pos: pos,
      vel: Offset(cos(ejectAngle) * speed, sin(ejectAngle) * speed),
      color: const Color(0xFFFFD54F),
      size: 4.5,
      life: 1.0,
      rotation: _rng.nextDouble() * pi,
      rotSpeed: (_rng.nextDouble() - 0.5) * 18,
      isShell: true,
    ));
  }

  void _addKillFeed(String killer, String victim) {
    killFeed.insert(0, '$killer  🎯  $victim');
    if (killFeed.length > 5) killFeed.removeLast();
  }
}

// ----------------- شاشة اللعبة الرئيسية -----------------

class BattleRoyaleScreen extends StatefulWidget {
  const BattleRoyaleScreen({super.key});

  @override
  State<BattleRoyaleScreen> createState() => _BattleRoyaleScreenState();
}

class _BattleRoyaleScreenState extends State<BattleRoyaleScreen>
    with SingleTickerProviderStateMixin {
  late final GameEngine _engine;
  late final Ticker _ticker;
  Duration _lastTime = Duration.zero;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _engine = GameEngine()..startNewGame();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    double dt = (elapsed - _lastTime).inMicroseconds / 1000000.0;
    _lastTime = elapsed;
    if (dt > 0.05) dt = 0.05;

    _engine.update(dt);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      _engine.manualKeys.add(event.logicalKey);
      if (event.physicalKey == PhysicalKeyboardKey.keyR ||
          event.logicalKey == LogicalKeyboardKey.keyR) {
        _engine.triggerReload();
      } else if (event.physicalKey == PhysicalKeyboardKey.keyF ||
          event.logicalKey == LogicalKeyboardKey.keyF ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (!_engine.isPlaying) {
          _engine.startNewGame();
        } else if (_engine.playerDropState == DropState.inPlane) {
          _engine.jumpFromPlane();
        }
      } else if (event.logicalKey == LogicalKeyboardKey.digit1) {
        _engine.switchWeapon(0);
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        _engine.switchWeapon(1);
      } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
        _engine.switchWeapon(2);
      }
    } else if (event is KeyUpEvent) {
      _engine.manualKeys.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          cursor: SystemMouseCursors.none,
          onHover: (e) => _engine.mouseScreenPos = e.localPosition,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (signal) {
              if (signal is PointerScrollEvent) {
                int next = (_engine.weaponIndex +
                    (signal.scrollDelta.dy > 0 ? 1 : -1)) %
                    kWeapons.length;
                if (next < 0) next += kWeapons.length;
                _engine.switchWeapon(next);
              }
            },
            onPointerDown: (e) {
              if (!_focusNode.hasFocus) _focusNode.requestFocus();
              _engine.mouseScreenPos = e.localPosition;
              if (e.buttons & kPrimaryMouseButton != 0) {
                _engine.isLeftMouseDown = true;
              }
              if (e.buttons & kSecondaryMouseButton != 0) {
                _engine.isRightMouseDown = true;
              }
            },
            onPointerMove: (e) {
              _engine.mouseScreenPos = e.localPosition;
              _engine.isLeftMouseDown = (e.buttons & kPrimaryMouseButton) != 0;
              _engine.isRightMouseDown =
                  (e.buttons & kSecondaryMouseButton) != 0;
            },
            onPointerUp: (e) {
              _engine.isLeftMouseDown = (e.buttons & kPrimaryMouseButton) != 0;
              _engine.isRightMouseDown =
                  (e.buttons & kSecondaryMouseButton) != 0;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                _engine.screenSize =
                    Size(constraints.maxWidth, constraints.maxHeight);

                return Stack(
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: _engine.screenSize,
                        painter: _UltraWorldPainter(engine: _engine),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _engine,
                      builder: (context, _) {
                        return _buildHudOverlay();
                      },
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

  Widget _buildHudOverlay() {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 175,
                  height: 175,
                  decoration: BoxDecoration(
                    color: const Color(0xCC0D160D),
                    border: Border.all(color: Colors.white54, width: 2),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 10)
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: _MinimapPainter(engine: _engine),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        'W  |  NW  |  N  •  ${((_engine.playerAngle * 180 / pi + 360) % 360).toInt()}°  •  E  |  SE  |  S',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_engine.playerDropState == DropState.inPlane)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '✈️ اضغط [F] أو [Space] للقفز بالباراشوت من الطائرة!',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else if (_engine.playerDropState == DropState.parachuting)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🪂 الارتفاع: ${_engine.playerAltitude.toInt()}m  |  تحكم بـ [WASD] واضغط [Shift] للغطس السريع',
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _buildStatBox(
                            'ALIVE', '${_engine.aliveCount}', Colors.amber),
                        const SizedBox(width: 8),
                        _buildStatBox('KILLS', '${_engine.playerKills}',
                            Colors.redAccent),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._engine.killFeed.map(
                          (msg) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.68),
                          borderRadius: BorderRadius.circular(4),
                          border: Border(
                            right: BorderSide(
                              color: msg.startsWith('You')
                                  ? Colors.amberAccent
                                  : Colors.redAccent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          msg,
                          style: TextStyle(
                            color: msg.startsWith('You')
                                ? Colors.amberAccent
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_engine.playerDropState == DropState.grounded)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_engine.isReloading)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amberAccent),
                      ),
                      child: Text(
                        'RELOADING ${_engine.activeWeapon.name}... (${_engine.reloadTimer.toStringAsFixed(1)}s)',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(kWeapons.length, (i) {
                      bool selected = i == _engine.weaponIndex;
                      return GestureDetector(
                        onTap: () => _engine.switchWeapon(i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.amber.withOpacity(0.25)
                                : Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? Colors.amberAccent
                                  : Colors.white24,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            '[${i + 1}] ${kWeapons[i].name}',
                            style: TextStyle(
                              color: selected
                                  ? Colors.amberAccent
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xD9121212),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${_engine.currentMags[_engine.weaponIndex]}',
                              style: TextStyle(
                                color: _engine.currentMags[
                                _engine.weaponIndex] <=
                                    3
                                    ? Colors.redAccent
                                    : Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              ' / ${_engine.reserveAmmos[_engine.weaponIndex]}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shield,
                                    color: Colors.cyanAccent, size: 14),
                                const SizedBox(width: 6),
                                Container(
                                  width: 210,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (_engine.playerArmor / 100)
                                        .clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.cyanAccent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.favorite,
                                    color: Colors.redAccent, size: 14),
                                const SizedBox(width: 6),
                                Container(
                                  width: 210,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: (_engine.playerHp / 100)
                                        .clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _engine.playerHp > 35
                                            ? const Color(0xFF00E676)
                                            : const Color(0xFFFF1744),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        if (!_engine.isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xF2101010),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _engine.isVictory ? Colors.amber : Colors.redAccent,
                  width: 3,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _engine.isVictory
                        ? 'WINNER WINNER CHICKEN DINNER! 🍗'
                        : 'تم إقصاؤك بواسطة: ${_engine.eliminatedBy.isEmpty ? "Blue Zone" : _engine.eliminatedBy}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color:
                      _engine.isVictory ? Colors.amber : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'المركز: #${_engine.aliveCount} من 50   |   القتلى (Kills): ${_engine.playerKills}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16),
                    ),
                    onPressed: _engine.startNewGame,
                    child: const Text(
                      'اركب الطائرة لجيم جديد (Space)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
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
  }

  Widget _buildStatBox(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.75), width: 1.5),
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
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- رسام العالم عالي الأداء (Viewport Culling) -----------------

class _UltraWorldPainter extends CustomPainter {
  final GameEngine engine;
  final Random _shakeRng = Random();

  _UltraWorldPainter({required this.engine}) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    Offset shakeOffset = Offset.zero;
    if (engine.screenShake > 0) {
      shakeOffset = Offset(
        (_shakeRng.nextDouble() - 0.5) * engine.screenShake * 2,
        (_shakeRng.nextDouble() - 0.5) * engine.screenShake * 2,
      );
    }

    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(engine.cameraZoom);
    final Offset camCenter = engine.cameraPos + shakeOffset;
    canvas.translate(-camCenter.dx, -camCenter.dy);

    final Rect viewRect = Rect.fromCenter(
      center: camCenter,
      width: (size.width / engine.cameraZoom) + 300,
      height: (size.height / engine.cameraZoom) + 300,
    );

    const double mapSize = GameEngine.mapSize;

    canvas.drawRect(
      viewRect.inflate(400),
      Paint()..color = const Color(0xFF154360),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-70, -70, mapSize + 140, mapSize + 140),
        const Radius.circular(90),
      ),
      Paint()..color = const Color(0xFFD4AC6E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, mapSize, mapSize),
        const Radius.circular(50),
      ),
      Paint()..color = const Color(0xFF436131),
    );

    final roadPaint = Paint()
      ..color = const Color(0xFF756347)
      ..strokeWidth = 95
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, mapSize / 2),
        const Offset(mapSize, mapSize / 2), roadPaint);
    canvas.drawLine(const Offset(mapSize / 2, 0),
        const Offset(mapSize / 2, mapSize), roadPaint);
    canvas.drawLine(
        const Offset(1900, 5600), const Offset(5600, 2200), roadPaint);

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.11)
      ..strokeWidth = 2;
    double startX = (viewRect.left ~/ 250) * 250.0;
    double endX = viewRect.right;
    for (double x = startX; x <= endX; x += 250) {
      if (x >= 0 && x <= mapSize) {
        canvas.drawLine(Offset(x, max(0, viewRect.top)),
            Offset(x, min(mapSize, viewRect.bottom)), gridPaint);
      }
    }
    double startY = (viewRect.top ~/ 250) * 250.0;
    double endY = viewRect.bottom;
    for (double y = startY; y <= endY; y += 250) {
      if (y >= 0 && y <= mapSize) {
        canvas.drawLine(Offset(max(0, viewRect.left), y),
            Offset(min(mapSize, viewRect.right), y), gridPaint);
      }
    }

    final floorPaint = Paint()..color = const Color(0xFF616A6B);
    final floorGridPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final floor in engine.buildingFloors) {
      if (!viewRect.overlaps(floor)) continue;
      canvas.drawRect(floor, floorPaint);
      canvas.drawRect(floor, floorGridPaint);
    }

    for (final poi in engine.pois) {
      if ((poi.center - camCenter).distance < 2500) {
        final tp = TextPainter(
          text: TextSpan(
            text: poi.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.28),
              fontSize: 54,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, poi.center - Offset(tp.width / 2, tp.height / 2));
      }
    }

    for (final d in engine.decals) {
      if (!viewRect.contains(d.pos)) continue;
      canvas.drawCircle(
        d.pos,
        d.radius,
        Paint()
          ..color = d.color.withOpacity((d.life / 15.0).clamp(0.0, 0.75)),
      );
    }

    for (final l in engine.loots) {
      if (!viewRect.contains(l.pos)) continue;
      _drawLootItem(canvas, l);
    }

    for (final b in engine.bots) {
      if (b.dropState != DropState.grounded || !viewRect.contains(b.pos)) {
        continue;
      }
      _drawTacticalSoldier(
        canvas: canvas,
        pos: b.pos,
        angle: b.angle,
        recoil: b.recoilOffset,
        muzzleFlash: b.muzzleFlashTimer > 0,
        bodyColor: const Color(0xFFC0392B),
        helmetColor: const Color(0xFF424949),
        weaponIndex: b.weaponIdx,
      );
    }

    if (engine.playerDropState == DropState.grounded) {
      Offset aimDir = Offset(cos(engine.playerAngle), sin(engine.playerAngle));
      canvas.drawLine(
        engine.playerPos + aimDir * 28,
        engine.playerPos +
            aimDir *
                (engine.weaponIndex == 2 || engine.isRightMouseDown
                    ? 750
                    : 300),
        Paint()
          ..color = engine.weaponIndex == 2
              ? Colors.cyanAccent.withOpacity(0.45)
              : Colors.redAccent.withOpacity(0.28)
          ..strokeWidth = 2.0,
      );

      _drawTacticalSoldier(
        canvas: canvas,
        pos: engine.playerPos,
        angle: engine.playerAngle,
        recoil: engine.gunRecoil,
        muzzleFlash: engine.muzzleFlashTimer > 0,
        bodyColor: const Color(0xFF2980B9),
        helmetColor: const Color(0xFF1C2833),
        weaponIndex: engine.weaponIndex,
        isPlayer: true,
      );
    }

    for (final b in engine.bullets) {
      if (!viewRect.contains(b.pos)) continue;
      Offset tail = b.pos - (b.vel / b.vel.distance) * 36;
      canvas.drawLine(
        tail,
        b.pos,
        Paint()
          ..shader = ui.Gradient.linear(
              tail, b.pos, [b.color.withOpacity(0.0), b.color])
          ..strokeWidth = b.damage >= 100 ? 4.5 : 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final obs in engine.obstacles) {
      if (!viewRect.overlaps(obs.rect)) continue;
      _drawObstacle(canvas, obs);
    }

    for (final p in engine.particles) {
      if (!viewRect.contains(p.pos)) continue;
      double alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      if (p.isShell) {
        canvas.save();
        canvas.translate(p.pos.dx, p.pos.dy);
        canvas.rotate(p.rotation);
        canvas.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3),
            Paint()..color = p.color.withOpacity(alpha));
        canvas.restore();
      } else {
        canvas.drawCircle(
            p.pos, p.size, Paint()..color = p.color.withOpacity(alpha));
      }
    }

    for (final ft in engine.floatingTexts) {
      if (!viewRect.contains(ft.pos)) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(ft.life.clamp(0.0, 1.0)),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, ft.pos - Offset(tp.width / 2, tp.height / 2));
    }

    for (final b in engine.bots) {
      if (b.dropState == DropState.parachuting && viewRect.contains(b.pos)) {
        _drawParachuter(canvas, b.pos, b.angle, b.altitude, false);
      }
    }
    if (engine.playerDropState == DropState.parachuting) {
      _drawParachuter(canvas, engine.playerPos, engine.playerAngle,
          engine.playerAltitude, true);
    }

    if (engine.planeActive) {
      canvas.drawLine(
        engine.planeStart,
        engine.planeEnd,
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..strokeWidth = 4,
      );
      _drawAirplane(canvas, engine.planePos, engine.planeAngle);
    }

    final Path outsideZone = Path()
      ..addRect(
          const Rect.fromLTWH(-3000, -3000, mapSize + 6000, mapSize + 6000))
      ..addOval(
          Rect.fromCircle(center: engine.zoneCenter, radius: engine.zoneRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outsideZone, Paint()..color = const Color(0x440066FF));
    canvas.drawCircle(
      engine.zoneCenter,
      engine.zoneRadius,
      Paint()
        ..color = const Color(0xFF00E5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    canvas.restore();

    if (engine.hitVignette > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width / 2, size.height / 2),
            size.longestSide * 0.55,
            [
              Colors.transparent,
              Colors.redAccent
                  .withOpacity((engine.hitVignette * 0.55).clamp(0.0, 0.7)),
            ],
          ),
      );
    }

    if (engine.isPlaying && engine.mouseScreenPos != Offset.zero) {
      _drawCrosshair(canvas, engine.mouseScreenPos);
    }
  }

  void _drawAirplane(Canvas canvas, Offset pos, double angle) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(45, 65), width: 220, height: 50),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    final wingPaint = Paint()..color = const Color(0xFFCFD8DC);
    final bodyPaint = Paint()..color = const Color(0xFFECEFF1);
    final darkPaint = Paint()..color = const Color(0xFF37474F);

    final wingPath = Path()
      ..moveTo(20, 0)
      ..lineTo(-25, -165)
      ..lineTo(-65, -165)
      ..lineTo(-35, 0)
      ..lineTo(-65, 165)
      ..lineTo(-25, 165)
      ..close();
    canvas.drawPath(wingPath, wingPaint);

    final tailPath = Path()
      ..moveTo(-110, 0)
      ..lineTo(-145, -55)
      ..lineTo(-165, -55)
      ..lineTo(-145, 0)
      ..lineTo(-165, 55)
      ..lineTo(-145, 55)
      ..close();
    canvas.drawPath(tailPath, darkPaint);

    for (double y in [-105, -55, 55, 105]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(-10, y), width: 34, height: 16),
            const Radius.circular(4)),
        darkPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 290, height: 42),
          const Radius.circular(22)),
      bodyPaint,
    );

    canvas.drawArc(
      const Rect.fromLTWH(95, -14, 35, 28),
      -1.1,
      2.2,
      false,
      Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    canvas.restore();
  }

  void _drawParachuter(
      Canvas canvas, Offset pos, double angle, double altitude, bool isPlayer) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    double scale = 1.0 + (altitude / 100.0) * 0.55;
    canvas.drawCircle(
      Offset(altitude * 0.45, altitude * 0.65),
      18 * scale,
      Paint()..color = Colors.black26,
    );

    canvas.scale(scale);
    canvas.rotate(angle);

    canvas.drawCircle(
      Offset.zero,
      14,
      Paint()..color = isPlayer ? Colors.blueAccent : Colors.redAccent,
    );

    final canopyRect =
    Rect.fromCenter(center: const Offset(-14, 0), width: 34, height: 64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(canopyRect, const Radius.circular(14)),
      Paint()
        ..color = isPlayer ? const Color(0xFF00E5FF) : const Color(0xFFFF7043),
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(-14, 0), width: 34, height: 20),
      Paint()..color = Colors.amberAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(canopyRect, const Radius.circular(14)),
      Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.restore();
  }

  void _drawTacticalSoldier({
    required Canvas canvas,
    required Offset pos,
    required double angle,
    required double recoil,
    required bool muzzleFlash,
    required Color bodyColor,
    required Color helmetColor,
    required int weaponIndex,
    bool isPlayer = false,
  }) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    canvas.drawCircle(const Offset(5, 7), 20,
        Paint()..color = Colors.black.withOpacity(0.35));
    canvas.rotate(angle);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-22, -12, 12, 24), const Radius.circular(4)),
      Paint()..color = const Color(0xFF5D4037),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -19, 24, 38), const Radius.circular(11)),
      Paint()..color = bodyColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-10, -14, 18, 28), const Radius.circular(6)),
      Paint()..color = const Color(0xFF2C3E50),
    );

    double rx = -recoil;
    double gunLen = kWeapons[weaponIndex].barrelLength;

    canvas.drawCircle(
        Offset(12 + rx, 9), 5.5, Paint()..color = const Color(0xFFF5CBA7));
    canvas.drawCircle(
        Offset(18 + rx, 4), 5.0, Paint()..color = const Color(0xFFF5CBA7));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 + rx, 1, gunLen, 6.5),
        const Radius.circular(2),
      ),
      Paint()
        ..color = weaponIndex == 2
            ? const Color(0xFF33691E)
            : const Color(0xFF212121),
    );

    if (muzzleFlash) {
      Offset flashPos = Offset(8 + rx + gunLen, 4);
      canvas.drawCircle(
          flashPos, 16, Paint()..color = Colors.amber.withOpacity(0.65));
      canvas.drawCircle(
          flashPos, 8, Paint()..color = const Color(0xFFFFF59D));
    }

    canvas.drawCircle(Offset.zero, 13.5, Paint()..color = helmetColor);
    canvas.drawArc(
      const Rect.fromLTWH(-11, -11, 22, 22),
      -0.65,
      1.3,
      false,
      Paint()
        ..color = isPlayer ? Colors.cyanAccent : Colors.orangeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    canvas.restore();
  }

  void _drawObstacle(Canvas canvas, MapObstacle obs) {
    if (obs.type == ObstacleType.buildingWall) {
      canvas.drawRect(
        obs.rect.shift(const Offset(5, 7)),
        Paint()..color = Colors.black38,
      );
      canvas.drawRect(obs.rect, Paint()..color = const Color(0xFF909497));
      canvas.drawRect(
        obs.rect,
        Paint()
          ..color = const Color(0xFF2C3E50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }

    final center = obs.rect.center;
    final radius = obs.rect.width / 2;

    if (obs.type == ObstacleType.tree) {
      canvas.drawCircle(center + const Offset(8, 10), radius,
          Paint()..color = Colors.black26);
      canvas.drawCircle(
          center, radius, Paint()..color = const Color(0xFF1E3F15));
      canvas.drawCircle(center + const Offset(-4, -4), radius * 0.76,
          Paint()..color = const Color(0xFF2D5A20));
      canvas.drawCircle(center + const Offset(-7, -7), radius * 0.44,
          Paint()..color = const Color(0xFF427A30));
    } else {
      final rockPath = Path()..addPolygon(obs.rockPolygon, true);
      canvas.drawPath(rockPath, Paint()..color = const Color(0xFF7F8C8D));
      canvas.drawPath(
        rockPath,
        Paint()
          ..color = const Color(0xFF2E3333)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawLootItem(Canvas canvas, Loot l) {
    if (l.type == LootType.airdropCrate) {
      final rect = Rect.fromCenter(center: l.pos, width: 44, height: 44);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = const Color(0xFFD32F2F),
      );
      canvas.drawRect(
        Rect.fromCenter(center: l.pos, width: 44, height: 14),
        Paint()..color = const Color(0xFF1565C0),
      );
      return;
    }

    final rect = Rect.fromCenter(center: l.pos, width: 25, height: 25);
    Color bg = l.type == LootType.medkit
        ? Colors.white
        : l.type == LootType.ammo
        ? const Color(0xFFFBC02D)
        : const Color(0xFF00ACC1);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = bg,
    );
  }

  void _drawCrosshair(Canvas canvas, Offset pos) {
    double spreadGap = 8 + engine.gunRecoil * 1.6;
    Color cColor = engine.isReloading
        ? Colors.amberAccent
        : (engine.isRightMouseDown ? Colors.cyanAccent : Colors.greenAccent);

    final p = Paint()
      ..color = cColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(pos, spreadGap + 6, p);
    canvas.drawLine(
        pos + Offset(-spreadGap - 12, 0), pos + Offset(-spreadGap, 0), p);
    canvas.drawLine(
        pos + Offset(spreadGap, 0), pos + Offset(spreadGap + 12, 0), p);
    canvas.drawLine(
        pos + Offset(0, -spreadGap - 12), pos + Offset(0, -spreadGap), p);
    canvas.drawLine(
        pos + Offset(0, spreadGap), pos + Offset(0, spreadGap + 12), p);
    canvas.drawCircle(pos, 2.2, Paint()..color = Colors.redAccent);
  }

  @override
  bool shouldRepaint(covariant _UltraWorldPainter oldDelegate) => true;
}

// ----------------- رسام الخريطة المصغرة (Mini-map) -----------------

class _MinimapPainter extends CustomPainter {
  final GameEngine engine;

  _MinimapPainter({required this.engine}) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    double scale = size.width / GameEngine.mapSize;

    final roadP = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), roadP);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), roadP);

    for (final poi in engine.pois) {
      canvas.drawCircle(
          poi.center * scale, 6, Paint()..color = Colors.white12);
    }

    canvas.drawCircle(
      engine.zoneCenter * scale,
      (engine.zoneRadius * scale).clamp(0.0, size.width),
      Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    if (engine.planeActive) {
      canvas.drawLine(
        engine.planeStart * scale,
        engine.planeEnd * scale,
        Paint()
          ..color = Colors.white54
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(
          engine.planePos * scale, 4.5, Paint()..color = Colors.white);
    }

    for (final l in engine.loots) {
      if (l.type == LootType.airdropCrate) {
        canvas.drawCircle(l.pos * scale, 3.0, Paint()..color = Colors.amber);
      }
    }

    final enemyPaint = Paint()..color = Colors.redAccent;
    for (final b in engine.bots) {
      if (b.dropState == DropState.grounded) {
        canvas.drawCircle(b.pos * scale, 2.0, enemyPaint);
      }
    }

    canvas.drawCircle(
        engine.playerPos * scale, 4.0, Paint()..color = Colors.greenAccent);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}