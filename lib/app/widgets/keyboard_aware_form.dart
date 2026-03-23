import 'package:flutter/material.dart';

const double kMobileFormBreakpoint = 720;

bool useFullscreenFormLayout(
  BuildContext context, {
  double breakpoint = kMobileFormBreakpoint,
}) {
  return MediaQuery.sizeOf(context).width < breakpoint;
}

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
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;
    final bottomSpacing = bottomInset > 0 ? bottomInset + 20 : safeBottom;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 0),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: padding.add(EdgeInsets.only(bottom: bottomSpacing)),
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
            ),
          );
        },
      ),
    );
  }
}

class EnsureVisibleWhenFocused extends StatefulWidget {
  const EnsureVisibleWhenFocused({
    super.key,
    required this.focusNode,
    required this.child,
    this.alignment = 0.18,
  });

  final FocusNode focusNode;
  final Widget child;
  final double alignment;

  @override
  State<EnsureVisibleWhenFocused> createState() =>
      _EnsureVisibleWhenFocusedState();
}

class _EnsureVisibleWhenFocusedState extends State<EnsureVisibleWhenFocused> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant EnsureVisibleWhenFocused oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) {
      return;
    }
    oldWidget.focusNode.removeListener(_handleFocusChange);
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    if (!widget.focusNode.hasFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.hasFocus) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: widget.alignment,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class KeyboardAwareFormScaffold extends StatelessWidget {
  const KeyboardAwareFormScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(title),
        actions: actions,
      ),
      body: KeyboardAwarePageBody(
        maxWidth: maxWidth,
        padding: padding,
        child: child,
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
