import 'package:flutter/material.dart';

class KeyboardAwarePageBody extends StatelessWidget {
  const KeyboardAwarePageBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding.add(EdgeInsets.only(bottom: bottomInset)),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class KeyboardAwareDialogFrame extends StatelessWidget {
  const KeyboardAwareDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.maxHeightFactor = 0.92,
    this.margin = const EdgeInsets.all(16),
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final availableHeight = mediaQuery.size.height - bottomInset - 32;
    final maxHeight =
        (availableHeight <= 0
                ? mediaQuery.size.height * maxHeightFactor
                : availableHeight * maxHeightFactor)
            .clamp(280.0, mediaQuery.size.height)
            .toDouble();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: margin,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
