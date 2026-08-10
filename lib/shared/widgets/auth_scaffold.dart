import 'package:flutter/material.dart';

import '../../core/theme/taji_theme.dart';
import 'taji_logo.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.wide = false,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool wide;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return Row(
            children: [
              const Expanded(flex: 9, child: _StoryPanel()),
              Expanded(
                flex: 11,
                child: _FormSurface(
                  maxWidth: wide ? 670 : 460,
                  eyebrow: eyebrow,
                  title: title,
                  subtitle: subtitle,
                  child: child,
                ),
              ),
            ],
          );
        }
        return Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 270,
              child: _MobileHeader(),
            ),
            SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 184, 16, 28),
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: wide ? 650 : 480),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: TajiColors.border.withValues(alpha: .8),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18243D5F),
                          blurRadius: 40,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: _FormContent(
                      eyebrow: eyebrow,
                      title: title,
                      subtitle: subtitle,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({
    required this.maxWidth,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final double maxWidth;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    color: TajiColors.canvas,
    padding: const EdgeInsets.all(36),
    alignment: Alignment.center,
    child: SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(35),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(color: TajiColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14243D5F),
              blurRadius: 45,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: _FormContent(
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          child: child,
        ),
      ),
    ),
  );
}

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: const TextStyle(
          color: TajiColors.primaryStrong,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 9),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
      ),
      const SizedBox(height: 25),
      child,
    ],
  );
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader();
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      23,
      MediaQuery.paddingOf(context).top + 20,
      23,
      20,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0C78FA), Color(0xFF0753C5)],
      ),
    ),
    child: const Align(
      alignment: Alignment.topLeft,
      child: TajiLogo(light: true),
    ),
  );
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(46),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0C7DFA), Color(0xFF0646AC)],
      ),
    ),
    child: Stack(
      children: [
        const Align(alignment: Alignment.topLeft, child: TajiLogo(light: true)),
        Align(
          alignment: const Alignment(-1, -.18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _GlassPill(),
              SizedBox(height: 18),
              Text(
                'Todo tu condominio,\nmás cerca.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2.2,
                ),
              ),
              SizedBox(height: 15),
              SizedBox(
                width: 420,
                child: Text(
                  'Una experiencia simple y segura para residentes, personal y administración.',
                  style: TextStyle(
                    color: Color(0xC8FFFFFF),
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Align(alignment: Alignment.bottomCenter, child: _BuildingScene()),
      ],
    ),
  );
}

class _GlassPill extends StatelessWidget {
  const _GlassPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      border: Border.all(color: Colors.white.withValues(alpha: .25)),
      borderRadius: BorderRadius.circular(40),
    ),
    child: const Text(
      'TU COMUNIDAD, EN CALMA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );
}

class _BuildingScene extends StatelessWidget {
  const _BuildingScene();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 155,
    width: 350,
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          left: 22,
          bottom: 0,
          child: _Building(
            width: 75,
            height: 92,
            color: const Color(0xFFD8EDFF),
          ),
        ),
        const Positioned(
          left: 104,
          bottom: 0,
          child: _Building(width: 105, height: 145, color: Colors.white),
        ),
        const Positioned(
          right: 27,
          bottom: 0,
          child: _Building(width: 88, height: 108, color: Color(0xFFB9DEFF)),
        ),
        Positioned(
          right: 0,
          top: 7,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD56A),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Building extends StatelessWidget {
  const _Building({
    required this.width,
    required this.height,
    required this.color,
  });
  final double width;
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(
        6,
        (_) => Container(
          width: 13,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF8BC8F9),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ),
  );
}
