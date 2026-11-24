import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ajan_skins.dart';

/// Yankı's figures: abstract light, never a face.
///
/// - [EchoPainter] (Yankı): the voice coming in as a wave, a core of light
///   that ripples with it, and what it understood leaving as a network of
///   points.
/// - [LatticePainter] (Ağ): a geodesic lattice of light that flexes with the
///   voice, the voice's bars on either side.
/// - [AperturePainter] (Dalga): a turning ring of light with the voice's
///   colours passing through it.
///
/// Everything is lit (a soft front light and a bright rim, the back
/// hidden), bloomed, and moved by [AjanMotion]: its eased moods and the
/// last seconds of the voice's loudness ([AjanMotion.history]).

const _cyan = Color(0xFF3CDCFF);
const _blue = Color(0xFF2E6BFF);
const _ice = Color(0xFFD6F7FF);
const _violet = Color(0xFF8A6BFF);
const _pink = Color(0xFFFF5FC8);

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The voice heard [i] frames ago, between frames.
double _heard(Float32List h, double i) {
  final a = i.floor().clamp(0, h.length - 1);
  final b = (a + 1).clamp(0, h.length - 1);
  final f = i - a;
  return h[a] * (1 - f) + h[b] * f;
}

/// Draws [draw] twice: blurred and added (the bloom), then sharp.
void _bloom(Canvas canvas, Rect area, double sigma, void Function() draw) {
  canvas.saveLayer(
    area,
    Paint()
      ..blendMode = BlendMode.plus
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      ),
  );
  draw();
  canvas.restore();
  draw();
}

/// A soft round light.
void _halo(Canvas canvas, Offset c, double r, Color color, double alpha) {
  final a = alpha.clamp(0.0, 1.0);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(
        c,
        r,
        [
          color.withValues(alpha: a),
          color.withValues(alpha: a * .25),
          color.withValues(alpha: 0),
        ],
        const [0, .4, 1],
      ),
  );
}

/// The light's colour at [k] (0 deep blue … 1 white-hot).
Color _lit(double k) {
  if (k < .5) return Color.lerp(const Color(0xFF1B3FA8), _cyan, k * 2)!;
  return Color.lerp(_cyan, _ice, (k - .5) * 2)!;
}

// ───────────────────────────── 3D helpers ───────────────────────────────

/// A turn in three dimensions, then a perspective.
class _Turn {
  _Turn(double yaw, double pitch, double roll)
    : cy = math.cos(yaw),
      sy = math.sin(yaw),
      cp = math.cos(pitch),
      sp = math.sin(pitch),
      cr = math.cos(roll),
      sr = math.sin(roll);
  final double cy, sy, cp, sp, cr, sr;
  double x = 0, y = 0, z = 0;

  void apply(double px, double py, double pz) {
    final x1 = px * cy + pz * sy;
    final z1 = -px * sy + pz * cy;
    final y1 = py * cp - z1 * sp;
    z = py * sp + z1 * cp;
    x = x1 * cr - y1 * sr;
    y = x1 * sr + y1 * cr;
  }
}

/// Points evenly over a sphere (Fibonacci), with a seed each.
Float32List _sphere(int n, int seed) {
  final r = math.Random(seed);
  final out = Float32List(n * 4);
  const golden = 2.399963229728653;
  for (var i = 0; i < n; i++) {
    final y = 1 - 2 * (i + .5) / n;
    final rad = math.sqrt(1 - y * y);
    final th = golden * i + r.nextDouble() * .3;
    out[i * 4] = math.cos(th) * rad;
    out[i * 4 + 1] = y;
    out[i * 4 + 2] = math.sin(th) * rad;
    out[i * 4 + 3] = r.nextDouble();
  }
  return out;
}

/// How far a point at direction (x, y, z) is pushed out this frame: a slow
/// swell, ripples with the voice, a band while working.
double _swell(AjanMotion m, double x, double y, double z) {
  final t = m.t, l = m.level.clamp(0.0, 1.2);
  var d = .012 * math.sin(x * 2.3 + t * .8) * math.cos(y * 2.1 - t * .6);
  d +=
      (m.speak * (.012 + l * .055) + m.listen * l * .03) *
      (math.sin(x * 4.1 + t * 3.3) * math.cos(y * 3.7 - t * 2.9) * .6 +
          math.sin(z * 6.2 + y * 2.0 + t * 5.1) * .4);
  if (m.work > .01) {
    final band = y - math.sin(t * 1.6) * .8;
    d += math.exp(-band * band * 18) * .03 * m.work;
  }
  return d;
}

const _bands = 9;
final _buckets = List.generate(_bands, (_) => Float32List(16000));
final _counts = List.filled(_bands, 0);

void _clear() {
  for (var b = 0; b < _bands; b++) {
    _counts[b] = 0;
  }
}

void _put(double x, double y, double k) {
  final b = (k * _bands).floor().clamp(0, _bands - 1);
  final c = _counts[b];
  if (c + 2 > _buckets[b].length) return;
  _buckets[b][c] = x;
  _buckets[b][c + 1] = y;
  _counts[b] = c + 2;
}

void _flush(Canvas canvas, double px, {double alpha = 1}) {
  final p = Paint()
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  for (var b = 0; b < _bands; b++) {
    if (_counts[b] == 0) continue;
    final k = (b + .5) / _bands;
    p
      ..strokeWidth = px * (.7 + k * 1.2)
      ..color = _lit(k)
          .withValues(alpha: ((.08 + k * k * .92) * alpha).clamp(0.0, 1.0));
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_buckets[b], 0, _counts[b]),
      p,
    );
  }
}

// The light: from the front, above and to the viewer's left.
const _lx = -.38, _ly = .52, _lz = .76;

/// A core of light: a sphere of fine points lit with a bright rim, its
/// surface rippling with the voice, rings of points turning around it.
void _core(
  Canvas canvas,
  Size size,
  AjanMotion m,
  Offset center,
  double radius, {
  double rings = 1,
}) {
  final h = size.height, t = m.t, l = m.level.clamp(0.0, 1.2);
  _halo(canvas, center, radius * 2.4, _blue, .18 + l * .12 + m.work * .08);
  _halo(canvas, center, radius * 1.1, _cyan, .14 + l * .16 + m.speak * .06);
  _halo(canvas, center, radius * .45, _ice, .08 + l * .18);
  final turn = _Turn(m.spin * .6 + t * .05, -.35 + .05 * math.sin(t * .3), .1);
  final pts = _orb;
  _clear();
  for (var i = 0; i < pts.length ~/ 4; i++) {
    final x = pts[i * 4], y = pts[i * 4 + 1], z = pts[i * 4 + 2];
    final r = 1 + _swell(m, x, y, z);
    turn.apply(x, y, z);
    final facing = turn.z;
    if (facing < -.1) continue;
    final diffuse = math.max(0.0, turn.x * _lx + turn.y * _ly + turn.z * _lz);
    final rim = math.pow(1 - facing.clamp(0.0, 1.0), 3).toDouble();
    final sparkle = math.sin(t * 2.3 + pts[i * 4 + 3] * 70) > .96 ? .5 : 0;
    final lit = .1 + diffuse * .45 + rim * .95 + sparkle + (r - 1) * 6;
    final k = 3.4 / (3.4 - turn.z * r);
    _put(
      center.dx + turn.x * r * k * radius,
      center.dy - turn.y * r * k * radius,
      lit.clamp(0.0, 1.0),
    );
  }
  // Rings: three tilted orbits of points.
  if (rings > 0) {
    for (var ring = 0; ring < 3; ring++) {
      final tilt = _Turn(
        t * (.25 + ring * .11) * (ring.isEven ? 1 : -1),
        .9 + ring * .5,
        ring * 1.1,
      );
      const n = 140;
      final rr = 1.32 + ring * .17 + l * .05;
      for (var i = 0; i < n; i++) {
        final a = i / n * math.pi * 2;
        tilt.apply(math.cos(a) * rr, 0, math.sin(a) * rr);
        final k = 3.4 / (3.4 - tilt.z);
        final front = (tilt.z / rr + 1) / 2;
        final comet = math
            .pow((1 + math.cos(a - t * (1.2 + ring * .4))) / 2, 8)
            .toDouble();
        _put(
          center.dx + tilt.x * k * radius,
          center.dy - tilt.y * k * radius,
          ((.12 + front * .25 + comet * .8) * rings).clamp(0.0, 1.0),
        );
      }
    }
  }
  _bloom(canvas, Offset.zero & size, h / 110, () => _flush(canvas, h / 560));
}

final _orb = _sphere(4200, 3);

// ───────────────────────────── Yankı ────────────────────────────────────

class EchoPainter extends CustomPainter {
  EchoPainter(this.clock, this.m) : super(repaint: clock);
  final ValueListenable<double> clock;
  final AjanMotion m;

  /// The network's points: where each starts, its lane, its pace, phase.
  static final _flow = () {
    final r = math.Random(5);
    return [
      for (var i = 0; i < 150; i++)
        (
          r.nextDouble(),
          r.nextDouble() * 2 - 1,
          .4 + r.nextDouble() * .6,
          r.nextDouble() * math.pi * 2,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height, w = size.width;
    final center = Offset(w * .5, h * .47);
    final radius = h * .2;
    _wave(canvas, size, center.dx - radius * 1.15, center.dy, h);
    _network(canvas, size, center.dx + radius * 1.1, center.dy, h);
    _core(canvas, size, m, center, radius);
  }

  /// The voice coming in: its last seconds as a line, loudest nearest the
  /// core.
  void _wave(Canvas canvas, Size size, double end, double y, double h) {
    if (end < 40) return;
    const steps = 280;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final k = i / steps;
      final x = end * k;
      final heard = _heard(m.history, (1 - k) * 150);
      final env = _smooth(0, .35, k) * (1 - _smooth(.95, 1, k) * .85);
      final carrier =
          math.sin(k * 70 - m.t * 11) * .72 +
          math.sin(k * 23 - m.t * 4.7) * .28;
      final dy = h * (.006 + heard * .3) * env * carrier;
      i == 0 ? path.moveTo(x, y + dy) : path.lineTo(x, y + dy);
    }
    final shader = ui.Gradient.linear(
      Offset(0, y),
      Offset(end, y),
      [_blue.withValues(alpha: 0), _blue, _cyan, _ice],
      const [0, .35, .8, 1],
    );
    _bloom(canvas, Offset.zero & size, h / 70, () {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = h / 260
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.plus
          ..shader = shader,
      );
    });
  }

  /// What it understood, leaving as a network of points that spreads and
  /// fades.
  void _network(Canvas canvas, Size size, double x0, double y0, double h) {
    final reach = size.width - x0 - 8;
    if (reach < 40) return;
    final t = m.t;
    final speed = .025 + m.work * .05 + m.speak * .03;
    final pts = <(Offset, double)>[];
    for (final (start, lane, pace, ph) in _flow) {
      final k = (start + t * speed * pace) % 1.0;
      final spread = .04 + k * .4;
      final x = x0 + k * reach;
      final y =
          y0 + lane * spread * h + math.sin(t * .7 + ph) * h * .015 * (.3 + k);
      final life = _smooth(0, .08, k) * (1 - _smooth(.7, 1, k));
      pts.add((Offset(x, y), life));
    }
    final near = h * .12;
    final lines = <double>[], strong = <double>[];
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        final d = (pts[i].$1 - pts[j].$1).distance;
        if (d > near) continue;
        final a = math.min(pts[i].$2, pts[j].$2) * (1 - d / near);
        if (a < .05) continue;
        (a > .35 ? strong : lines).addAll([
          pts[i].$1.dx,
          pts[i].$1.dy,
          pts[j].$1.dx,
          pts[j].$1.dy,
        ]);
      }
    }
    _bloom(canvas, Offset.zero & size, h / 160, () {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(lines),
        Paint()
          ..strokeWidth = math.max(.6, h / 1100)
          ..blendMode = BlendMode.plus
          ..color = _cyan.withValues(alpha: .14),
      );
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(strong),
        Paint()
          ..strokeWidth = math.max(.7, h / 900)
          ..blendMode = BlendMode.plus
          ..color = _cyan.withValues(alpha: .34),
      );
      final dot = Paint()
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      for (var i = 0; i < pts.length; i++) {
        final (p, life) = pts[i];
        final (_, _, pace, ph) = _flow[i];
        final tw = .6 + .4 * math.sin(t * (1.2 + pace * 2) + ph);
        dot
          ..strokeWidth = h / 260 * (1 + pace * 1.6) * tw
          ..color = Color.lerp(
            _ice,
            _blue,
            ((p.dx - x0) / reach).clamp(0, 1),
          )!.withValues(alpha: (life * .95).clamp(0, 1));
        canvas.drawPoints(ui.PointMode.points, [p], dot);
      }
    });
  }

  @override
  bool shouldRepaint(EchoPainter old) => old.m != m;
}

// ───────────────────────────── Ağ ───────────────────────────────────────

/// An icosphere: its points and edges.
class _Lattice {
  _Lattice(this.points, this.edges);
  final Float32List points;
  final Uint16List edges;

  static final instance = _build(3);

  static _Lattice _build(int depth) {
    final t = (1 + math.sqrt(5)) / 2;
    final v = <List<double>>[
      [-1, t, 0],
      [1, t, 0],
      [-1, -t, 0],
      [1, -t, 0],
      [0, -1, t],
      [0, 1, t],
      [0, -1, -t],
      [0, 1, -t],
      [t, 0, -1],
      [t, 0, 1],
      [-t, 0, -1],
      [-t, 0, 1],
    ];
    List<double> norm(List<double> p) {
      final l = math.sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
      return [p[0] / l, p[1] / l, p[2] / l];
    }

    final pts = [for (final p in v) norm(p)];
    var faces = <List<int>>[
      [0, 11, 5],
      [0, 5, 1],
      [0, 1, 7],
      [0, 7, 10],
      [0, 10, 11],
      [1, 5, 9],
      [5, 11, 4],
      [11, 10, 2],
      [10, 7, 6],
      [7, 1, 8],
      [3, 9, 4],
      [3, 4, 2],
      [3, 2, 6],
      [3, 6, 8],
      [3, 8, 9],
      [4, 9, 5],
      [2, 4, 11],
      [6, 2, 10],
      [8, 6, 7],
      [9, 8, 1],
    ];
    for (var d = 0; d < depth; d++) {
      final cache = <int, int>{};
      int mid(int a, int b) {
        final key = a < b ? a * 10000 + b : b * 10000 + a;
        return cache[key] ??= () {
          final p = pts[a], q = pts[b];
          pts.add(
            norm([(p[0] + q[0]) / 2, (p[1] + q[1]) / 2, (p[2] + q[2]) / 2]),
          );
          return pts.length - 1;
        }();
      }

      faces = [
        for (final f in faces)
          ...() {
            final a = mid(f[0], f[1]), b = mid(f[1], f[2]), c = mid(f[2], f[0]);
            return [
              [f[0], a, c],
              [f[1], b, a],
              [f[2], c, b],
              [a, b, c],
            ];
          }(),
      ];
    }
    final edges = <int>{};
    for (final f in faces) {
      for (final (a, b) in [(f[0], f[1]), (f[1], f[2]), (f[2], f[0])]) {
        edges.add(a < b ? a * 10000 + b : b * 10000 + a);
      }
    }
    return _Lattice(
      Float32List.fromList([for (final p in pts) ...p]),
      Uint16List.fromList([
        for (final e in edges) ...[e ~/ 10000, e % 10000],
      ]),
    );
  }
}

class LatticePainter extends CustomPainter {
  LatticePainter(this.clock, this.m) : super(repaint: clock);
  final ValueListenable<double> clock;
  final AjanMotion m;

  static final _inner = _sphere(1600, 8);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height, t = m.t, l = m.level.clamp(0.0, 1.2);
    final center = Offset(size.width / 2, h * .47);
    final radius = h * .27;
    _halo(canvas, center, radius * 2.2, _blue, .16 + l * .1);
    _bars(canvas, size, center, radius * 1.45);

    final lat = _Lattice.instance;
    final n = lat.points.length ~/ 3;
    final turn = _Turn(
      m.spin * .7 + t * .07,
      -.3 + .06 * math.sin(t * .27),
      .15,
    );
    final xy = Float32List(n * 2);
    final light = Float32List(n);
    final facing = Float32List(n);
    for (var i = 0; i < n; i++) {
      final x = lat.points[i * 3],
          y = lat.points[i * 3 + 1],
          z = lat.points[i * 3 + 2];
      final r = 1 + _swell(m, x, y, z);
      turn.apply(x, y, z);
      facing[i] = turn.z;
      final diffuse = math.max(0.0, turn.x * _lx + turn.y * _ly + turn.z * _lz);
      final rim = math.pow(1 - turn.z.clamp(0.0, 1.0), 3).toDouble();
      light[i] = (.1 + diffuse * .5 + rim * .7 + (r - 1) * 8).clamp(0.0, 1.0);
      final k = 3.4 / (3.4 - turn.z * r);
      xy[i * 2] = center.dx + turn.x * r * k * radius;
      xy[i * 2 + 1] = center.dy - turn.y * r * k * radius;
    }
    // The faint inner sphere.
    _clear();
    final inner = _Turn(-t * .1, .3, 0);
    for (var i = 0; i < _inner.length ~/ 4; i++) {
      inner.apply(_inner[i * 4], _inner[i * 4 + 1], _inner[i * 4 + 2]);
      final k = 3.4 / (3.4 - inner.z * .55);
      final front = (inner.z + 1) / 2;
      _put(
        center.dx + inner.x * .55 * k * radius,
        center.dy - inner.y * .55 * k * radius,
        (.05 + front * .3 + l * .2).clamp(0.0, 1.0),
      );
    }
    _bloom(canvas, Offset.zero & size, h / 100, () {
      _flush(canvas, h / 700, alpha: .8);
      // Edges: back ones faint, front ones lit.
      final lines = List.generate(5, (_) => <double>[]);
      final e = lat.edges;
      for (var i = 0; i < e.length; i += 2) {
        final a = e[i], b = e[i + 1];
        final front = (facing[a] + facing[b]) / 2;
        final lit = front < -.05 ? .08 : (light[a] + light[b]) / 2;
        lines[(lit * 5).floor().clamp(0, 4)].addAll([
          xy[a * 2],
          xy[a * 2 + 1],
          xy[b * 2],
          xy[b * 2 + 1],
        ]);
      }
      final lp = Paint()
        ..strokeWidth = math.max(.7, h / 800)
        ..blendMode = BlendMode.plus;
      for (var b = 0; b < 5; b++) {
        if (lines[b].isEmpty) continue;
        final k = (b + .5) / 5;
        lp.color = _lit(k).withValues(alpha: (.04 + k * .42).clamp(0.0, 1.0));
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.fromList(lines[b]),
          lp,
        );
      }
      // Nodes: a pulse runs across them.
      final np = Paint()
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.plus;
      for (var i = 0; i < n; i++) {
        if (facing[i] < -.05) continue;
        final pulse = math
            .pow(
              (1 +
                      math.sin(
                        t * 2.2 +
                            lat.points[i * 3 + 1] * 5 +
                            lat.points[i * 3] * 3,
                      )) /
                  2,
              6,
            )
            .toDouble();
        final k = (light[i] + pulse * (.3 + m.speak * .5 + m.work * .5)).clamp(
          0.0,
          1.0,
        );
        np
          ..strokeWidth = h / 520 * (1 + k * 1.6)
          ..color = _lit(k).withValues(alpha: (.25 + k * .75).clamp(0.0, 1.0));
        canvas.drawPoints(ui.PointMode.points, [
          Offset(xy[i * 2], xy[i * 2 + 1]),
        ], np);
      }
    });
  }

  /// The voice's last seconds as bars, flowing outward from the lattice.
  void _bars(Canvas canvas, Size size, Offset center, double gap) {
    final h = size.height;
    final reach = size.width / 2 - gap - 12;
    if (reach < 30) return;
    const n = 56;
    final step = reach / n;
    final w = math.max(1.4, step * .46);
    final bars = <double>[];
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < n; i++) {
        final x = center.dx + side * (gap + (i + .5) * step);
        final fade = math.pow(1 - i / n, 1.2).toDouble();
        final heard = _heard(m.history, i * 1.6);
        final grain = .55 + .45 * math.sin(i * 2.7 + side * 1.3 + m.t * 3);
        final half = h * (.006 + heard * .26 * fade * grain);
        bars.addAll([x, center.dy - half, x, center.dy + half]);
      }
    }
    _bloom(canvas, Offset.zero & size, h / 140, () {
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(bars),
        Paint()
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(center.dx - gap - reach, 0),
            Offset(center.dx + gap + reach, 0),
            [
              _blue.withValues(alpha: .12),
              _cyan.withValues(alpha: .9),
              _ice,
              _cyan.withValues(alpha: .9),
              _blue.withValues(alpha: .12),
            ],
            const [0, .3, .5, .7, 1],
          ),
      );
    });
  }

  @override
  bool shouldRepaint(LatticePainter old) => old.m != m;
}

// ───────────────────────────── Dalga ────────────────────────────────────

class AperturePainter extends CustomPainter {
  AperturePainter(this.clock, this.m) : super(repaint: clock);
  final ValueListenable<double> clock;
  final AjanMotion m;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height, w = size.width, t = m.t;
    final l = m.level.clamp(0.0, 1.2);
    final center = Offset(w / 2, h * .47);
    final radius = h * .3;
    _halo(canvas, center, radius * 1.9, _violet, .1 + l * .08);
    _halo(canvas, center, radius * 1.2, _blue, .14 + l * .1);

    // The voice's colours, across the whole width, through the ring.
    _wave(canvas, size, center, h);

    // The ring: a torus of points, tilted, turning; brighter in front.
    _clear();
    final turn = _Turn(
      t * .15,
      1.15 + .06 * math.sin(t * .4),
      .12 * math.sin(t * .23),
    );
    const around = 260, across = 14;
    for (var i = 0; i < around; i++) {
      final a = i / around * math.pi * 2;
      final heard = _heard(m.history, (i % 64).toDouble() * 2);
      for (var j = 0; j < across; j++) {
        final b = j / across * math.pi * 2 + i * .37;
        final tube = .07 + heard * .05 + m.work * .02 * math.sin(a * 6 + t * 4);
        final r = 1 + tube * math.cos(b);
        final x = math.cos(a) * r, z = math.sin(a) * r, y = tube * math.sin(b);
        turn.apply(x, y, z);
        final front = (turn.z + 1.1) / 2.2;
        final comet = math
            .pow((1 + math.cos(a - t * (1 + m.work * 2))) / 2, 10)
            .toDouble();
        final k = 3.4 / (3.4 - turn.z);
        _put(
          center.dx + turn.x * k * radius,
          center.dy - turn.y * k * radius,
          (.08 + front * .45 + comet * .7 + l * .15).clamp(0.0, 1.0),
        );
      }
    }
    _bloom(canvas, Offset.zero & size, h / 90, () => _flush(canvas, h / 620));
  }

  void _wave(Canvas canvas, Size size, Offset center, double h) {
    final w = size.width;
    const n = 64;
    _bloom(canvas, Offset.zero & size, h / 55, () {
      final p = Paint()..blendMode = BlendMode.plus;
      for (var i = 0; i < n; i++) {
        final k = i / (n - 1);
        final x = w * (.06 + .88 * k);
        final fromMid = (k - .5).abs() * 2;
        final heard = _heard(m.history, fromMid * 120);
        final env = math.pow(1 - fromMid, 1.3).toDouble();
        final grain = .6 + .4 * math.sin(i * 2.1 + m.t * 2.5);
        final hh = h * (.01 + heard * .32 * env * grain);
        final c = Color.lerp(
          Color.lerp(_cyan, _ice, env)!,
          k < .5 ? _pink : _violet,
          _smooth(.2, .9, fromMid),
        )!;
        final r = Rect.fromCenter(
          center: Offset(x, center.dy),
          width: h * (.006 + .01 * env),
          height: hh * 2,
        );
        p.color = c.withValues(
          alpha: (.12 + .75 * env * (.3 + heard)).clamp(0, 1),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(r.width / 2)),
          p,
        );
      }
      canvas.drawLine(
        Offset(w * .04, center.dy),
        Offset(w * .96, center.dy),
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = h / 400
          ..shader = ui.Gradient.linear(
            Offset(w * .04, center.dy),
            Offset(w * .96, center.dy),
            [
              Colors.transparent,
              _cyan.withValues(alpha: .7),
              _ice,
              _cyan.withValues(alpha: .7),
              Colors.transparent,
            ],
            const [0, .3, .5, .7, 1],
          ),
      );
    });
  }

  @override
  bool shouldRepaint(AperturePainter old) => old.m != m;
}

// ───────────────────────────── Backdrop ─────────────────────────────────

/// Behind Yankı's figures: the nebula shader (shaders/yanki_nebula.frag),
/// or a plain gradient where it could not be loaded.
class DotFieldBackdrop extends CustomPainter {
  DotFieldBackdrop(this.clock, {this.energy}) : super(repaint: clock);
  final ValueListenable<double> clock;
  final double Function()? energy;

  static ui.FragmentProgram? _program;

  static Future<void> load() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset(
        'shaders/yanki_nebula.frag',
      );
    } catch (_) {}
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_program case final program?) {
      final shader = program.fragmentShader()
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, clock.value)
        ..setFloat(3, (energy?.call() ?? .3).clamp(0.0, 1.0))
        ..setFloat(4, .5)
        ..setFloat(5, .45);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
      return;
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * .5, size.height * .45),
          size.longestSide * .7,
          const [Color(0xFF0B2A6B), Color(0xFF061331), Color(0xFF02060F)],
          const [0, .45, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(DotFieldBackdrop old) => false;
}

// ───────────────────────────── Orb ──────────────────────────────────────

/// The floating orb's core: the same light as the full screen's, small.
class OrbPainter extends CustomPainter {
  OrbPainter(this.clock, this.m) : super(repaint: clock);
  final ValueListenable<double> clock;
  final AjanMotion m;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final c = size.center(Offset.zero);
    _core(canvas, size, m, c, size.shortestSide * .27, rings: 1);
  }

  @override
  bool shouldRepaint(OrbPainter old) => old.m != m;
}
