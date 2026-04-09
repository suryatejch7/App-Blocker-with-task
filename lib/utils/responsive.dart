import 'package:flutter/widgets.dart';

extension ResponsiveContext on BuildContext {
  double get responsiveScale {
    final shortestSide = MediaQuery.sizeOf(this).shortestSide;
    return (shortestSide / 390.0).clamp(0.90, 1.15);
  }

  double scale(double value) => value * responsiveScale;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isCompactWidth => MediaQuery.sizeOf(this).width < 420;
}
