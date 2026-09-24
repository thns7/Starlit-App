import 'package:flutter/material.dart';

/// Paleta do Starlit: violeta profundo, céu noturno e estrelas lilás.
class SC {
  SC._();

  // Fundos, do mais profundo ao mais elevado.
  static const night = Color(0xFF0F0822);
  static const bg = Color(0xFF150B2E);
  static const bgTop = Color(0xFF2A1266);
  static const surface = Color(0xFF221248);
  static const surfaceHigh = Color(0xFF2F1B63);
  static const surfaceHigher = Color(0xFF3A267F);
  static const outline = Color(0xFF4A3590);

  // Marca.
  static const primary = Color(0xFF7E56E4);
  static const primaryDeep = Color(0xFF5936B2);
  static const star = Color(0xFF9670F5);
  static const starSoft = Color(0xFFB9A3FF);

  // Texto: secundários tingidos de lilás, nunca cinza.
  static const text = Color(0xFFF6F2FF);
  static const textMuted = Color(0xFFC9BCEB);
  static const textFaint = Color(0xFF9A8BC4);

  // Estados.
  static const danger = Color(0xFFFF5A6E);
  static const success = Color(0xFF4ADE9B);
  static const gold = Color(0xFFFFC857);

  static const skyGradient = LinearGradient(
    colors: [bgTop, bg, night],
    stops: [0, 0.55, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF462F7E), primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const buttonGradient = LinearGradient(
    colors: [primaryDeep, primary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Espaçamentos em múltiplos de 4.
class SSpace {
  SSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 20.0;
}

class SRadius {
  SRadius._();
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// Tempos e curvas de movimento.
class SMotion {
  SMotion._();

  /// Desaceleração exponencial: chegadas confiantes, sem quique.
  static const emphasized = Cubic(0.16, 1, 0.3, 1);
  static const standard = Cubic(0.2, 0, 0, 1);
  static const exit = Cubic(0.3, 0, 1, 1);

  static const tap = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 320);
  static const page = Duration(milliseconds: 420);
  static const hero = Duration(milliseconds: 560);

  /// Respeita "Reduzir movimento" do sistema.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Sombras com deslocamento e desfoque suave (nunca halo sem offset).
class SShadow {
  SShadow._();
  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF05020D).withValues(alpha: 0.45),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  static List<BoxShadow> raised = [
    BoxShadow(
      color: const Color(0xFF05020D).withValues(alpha: 0.55),
      blurRadius: 32,
      offset: const Offset(0, 18),
    ),
  ];
  static List<BoxShadow> glowButton = [
    BoxShadow(
      color: SC.primaryDeep.withValues(alpha: 0.5),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
