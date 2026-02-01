import 'dart:math' as math;
import 'package:LunarStudio/src/features/chat/presentation/chat_screen.dart';
import 'package:LunarStudio/src/features/welcome/presentation/popup/beta_warning_popup.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _starMoveController;
  late AnimationController _starTwinkleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    // Continuous star movement
    _starMoveController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _starTwinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _starMoveController.dispose();
    _starTwinkleController.dispose();
    super.dispose();
  }

  void _navigateToChat() {
    BetaWarningPopup.show(context, () {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ChatPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF0D0D1A), Color(0xFF050510), Colors.black],
          ),
        ),
        child: Stack(
          children: [
            // Moving stars
            ...List.generate(80, (index) => _buildMovingStar(index, size)),

            // Main content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App name
                      Text(
                        'Lunar Studio',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Version + Beta badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'v0.1.0',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.25,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'BETA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Tagline
                      Text(
                        'Your local AI assistant',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),

                      const SizedBox(height: 56),

                      // Launch button
                      _AnimatedButton(
                        onTap: _navigateToChat,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovingStar(int index, Size screenSize) {
    final random = math.Random(index);
    final starSize = random.nextDouble() * 2.5 + 0.5;
    final speed = random.nextDouble() * 0.5 + 0.3; // Different speeds
    final startY = random.nextDouble();
    final startX = random.nextDouble();
    final twinkleDelay = random.nextDouble();
    final isBright = random.nextDouble() > 0.8;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _starMoveController,
        _starTwinkleController,
      ]),
      builder: (context, child) {
        // Calculate position with slow diagonal drift
        final moveProgress = (_starMoveController.value * speed) % 1.0;
        final x = (startX + moveProgress * 0.3) % 1.0;
        final y = (startY + moveProgress * 0.15) % 1.0;

        // Twinkle effect
        final twinklePhase =
            (_starTwinkleController.value + twinkleDelay) % 1.0;
        final twinkle = 0.4 + (math.sin(twinklePhase * math.pi * 2) * 0.6);
        final opacity = isBright ? twinkle : twinkle * 0.5;

        return Positioned(
          left: screenSize.width * x,
          top: screenSize.height * y,
          child: Container(
            width: starSize,
            height: starSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isBright ? const Color(0xFFE8E4FF) : Colors.white)
                  .withValues(alpha: opacity),
              boxShadow: isBright
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: opacity * 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _AnimatedButton({required this.onTap, required this.colorScheme});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.colorScheme.primary
                : widget.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: widget.colorScheme.primary.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: widget.colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Launch',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _isHovered ? Colors.white : widget.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_isHovered ? 4 : 0, 0, 0),
                child: Icon(
                  Icons.rocket_launch_outlined,
                  size: 18,
                  color: _isHovered ? Colors.white : widget.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
