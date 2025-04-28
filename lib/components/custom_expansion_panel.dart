import 'package:flutter/material.dart';

class CustomExpansionPanel extends StatefulWidget {
  final Widget title;
  final Widget content;
  final bool initiallyExpanded;
  final Function(bool)? onExpansionChanged;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? headerPadding;
  final Color? backgroundColor;
  final Color? expandedBackgroundColor;
  final Color? headerBackgroundColor;
  final Widget? expandedIcon;
  final Widget? collapsedIcon;
  final TextStyle? headerTextStyle;
  final BoxDecoration? decoration;
  final Duration animationDuration;
  final BorderRadius? borderRadius;

  const CustomExpansionPanel({
    Key? key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.contentPadding = const EdgeInsets.all(16.0),
    this.headerPadding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.backgroundColor,
    this.expandedBackgroundColor,
    this.headerBackgroundColor,
    this.expandedIcon,
    this.collapsedIcon,
    this.headerTextStyle,
    this.decoration,
    this.animationDuration = const Duration(milliseconds: 200),
    this.borderRadius = const BorderRadius.all(Radius.circular(8.0)),
  }) : super(key: key);

  @override
  _CustomExpansionPanelState createState() => _CustomExpansionPanelState();
}

class _CustomExpansionPanelState extends State<CustomExpansionPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));
    _iconTurns = _controller.drive(Tween<double>(begin: 0.0, end: 0.5)
        .chain(CurveTween(curve: Curves.easeIn)));

    _isExpanded = widget.initiallyExpanded;
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      widget.onExpansionChanged?.call(_isExpanded);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color headerColor = widget.headerBackgroundColor ?? Colors.transparent;
    final Color bodyColor = _isExpanded
        ? (widget.expandedBackgroundColor ?? widget.backgroundColor ?? theme.cardColor)
        : (widget.backgroundColor ?? theme.cardColor);

    return Container(
      decoration: widget.decoration ??
          BoxDecoration(
            color: bodyColor,
            borderRadius: widget.borderRadius,
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Material(
            color: headerColor,
            borderRadius: _isExpanded
                ? BorderRadius.only(
                    topLeft: widget.borderRadius?.topLeft ?? Radius.circular(8.0),
                    topRight: widget.borderRadius?.topRight ?? Radius.circular(8.0),
                  )
                : widget.borderRadius,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: _isExpanded
                  ? BorderRadius.only(
                      topLeft: widget.borderRadius?.topLeft ?? Radius.circular(8.0),
                      topRight: widget.borderRadius?.topRight ?? Radius.circular(8.0),
                    )
                  : widget.borderRadius,
              child: Padding(
                padding: widget.headerPadding!,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: DefaultTextStyle(
                        style: widget.headerTextStyle ??
                            theme.textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        child: widget.title,
                      ),
                    ),
                    RotationTransition(
                      turns: _iconTurns,
                      child: _isExpanded
                          ? widget.expandedIcon ??
                              Icon(Icons.keyboard_arrow_up, color: theme.primaryColor)
                          : widget.collapsedIcon ??
                              Icon(Icons.keyboard_arrow_down, color: theme.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller.view,
              builder: (BuildContext context, Widget? child) {
                return Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: child,
                );
              },
              child: _isExpanded
                  ? Padding(
                      padding: widget.contentPadding!,
                      child: widget.content,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
} 