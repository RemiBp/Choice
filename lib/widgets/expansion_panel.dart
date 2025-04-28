import 'package:flutter/material.dart';

class CustomExpansionPanel extends StatefulWidget {
  final String title;
  final Widget content;
  final bool initiallyExpanded;
  final Color? headerColor;
  final Color? contentBackgroundColor;
  final TextStyle? headerTextStyle;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? icon;
  final Widget? expandedIcon;
  final VoidCallback? onExpansionChanged;

  const CustomExpansionPanel({
    Key? key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.headerColor,
    this.contentBackgroundColor,
    this.headerTextStyle,
    this.borderRadius = 8.0,
    this.padding = const EdgeInsets.all(16.0),
    this.icon,
    this.expandedIcon,
    this.onExpansionChanged,
  }) : super(key: key);

  @override
  _CustomExpansionPanelState createState() => _CustomExpansionPanelState();
}

class _CustomExpansionPanelState extends State<CustomExpansionPanel> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));
    _iconTurns = _controller.drive(Tween<double>(begin: 0.0, end: 0.5)
        .chain(CurveTween(curve: Curves.easeIn)));
    
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
      if (widget.onExpansionChanged != null) {
        widget.onExpansionChanged!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    
    return Container(
      margin: EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.headerColor ?? theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.borderRadius),
                  topRight: Radius.circular(widget.borderRadius),
                  bottomLeft: Radius.circular(_isExpanded ? 0 : widget.borderRadius),
                  bottomRight: Radius.circular(_isExpanded ? 0 : widget.borderRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: widget.headerTextStyle ?? 
                          TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: _isExpanded 
                        ? (widget.expandedIcon ?? Icon(Icons.keyboard_arrow_up))
                        : (widget.icon ?? Icon(Icons.keyboard_arrow_down)),
                  ),
                ],
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
              child: Container(
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: widget.contentBackgroundColor ?? Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(widget.borderRadius),
                    bottomRight: Radius.circular(widget.borderRadius),
                  ),
                ),
                child: widget.content,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomExpansionPanelList extends StatelessWidget {
  final List<CustomExpansionPanel> children;
  final EdgeInsetsGeometry padding;
  
  const CustomExpansionPanelList({
    Key? key,
    required this.children,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: children,
      ),
    );
  }
} 