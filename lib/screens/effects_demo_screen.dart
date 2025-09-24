import 'package:flutter/material.dart';
import '../widgets/animations/page_transitions.dart';
import '../widgets/animations/custom_loading_indicators.dart';
import '../widgets/effects/glassmorphism_card.dart';
import '../widgets/effects/animated_button.dart';
import '../widgets/effects/parallax_container.dart';
import '../widgets/effects/shimmer_effect.dart';

/// Demo screen to showcase all the new effects
class EffectsDemoScreen extends StatelessWidget {
  const EffectsDemoScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with Neon effect
                const NeonText(
                  text: 'افکت‌های جدید',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  neonColor: Colors.cyanAccent,
                  animate: true,
                ),
                const SizedBox(height: 30),

                // Glassmorphism Cards
                _buildSectionTitle('Glassmorphism Cards'),
                const SizedBox(height: 15),
                GlassmorphismCard(
                  blur: 15,
                  opacity: 0.15,
                  child: Column(
                    children: [
                      const Icon(Icons.security, color: Colors.white, size: 40),
                      const SizedBox(height: 10),
                      const Text(
                        'Secure VPN Connection',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Protected with glassmorphism effect',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Animated Glass Card
                AnimatedGlassmorphismCard(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Tap me for animation!',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Loading Indicators
                _buildSectionTitle('Loading Animations'),
                const SizedBox(height: 15),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    PulseLoadingIndicator(color: Colors.cyanAccent),
                    WaveLoadingIndicator(color: Colors.purpleAccent),
                    ArcLoadingIndicator(color: Colors.pinkAccent),
                    MorphingDotsIndicator(color: Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 30),

                // Animated Buttons
                _buildSectionTitle('Animated Buttons'),
                const SizedBox(height: 15),
                AnimatedButton(
                  onPressed: () {},
                  backgroundColor: Colors.cyanAccent,
                  enableGlow: true,
                  child: const Text('Glowing Button'),
                ),
                const SizedBox(height: 15),
                GradientAnimatedButton(
                  onPressed: () {},
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.pink],
                  ),
                  child: const Text(
                    'Gradient Button',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 30),

                // Shimmer Effect
                _buildSectionTitle('Shimmer Loading'),
                const SizedBox(height: 15),
                ShimmerEffect(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Floating Widget
                _buildSectionTitle('Floating Animation'),
                const SizedBox(height: 30),
                Center(
                  child: FloatingWidget(
                    floatingRange: 15,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Glow Effect
                _buildSectionTitle('Glow Effects'),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GlowEffect(
                      glowColor: Colors.cyanAccent,
                      glowRadius: 20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.wifi, color: Colors.white),
                      ),
                    ),
                    GlowEffect(
                      glowColor: Colors.purpleAccent,
                      glowRadius: 20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.shield, color: Colors.white),
                      ),
                    ),
                    GlowEffect(
                      glowColor: Colors.pinkAccent,
                      glowRadius: 20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.speed, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Example of how to navigate with custom transitions
class TransitionExamples {
  static void showFadeTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(FadePageRoute(child: page));
  }

  static void showSlideUpTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(SlideUpPageRoute(child: page));
  }

  static void showZoomTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(ZoomPageRoute(child: page));
  }

  static void showSharedAxisTransition(BuildContext context, Widget page) {
    Navigator.of(context).push(SharedAxisPageRoute(
      child: page,
      transitionType: SharedAxisTransitionType.scaled,
    ));
  }
}
