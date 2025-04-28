import 'package:flutter/material.dart';

/// A customizable expansion panel widget that provides more styling options
/// than the standard material ExpansionPanel.
class CustomExpansionPanel extends StatefulWidget {
  /// The title displayed in the header of the expansion panel
  final String title;

  /// The widget displayed when the panel is expanded
  final Widget content;

  /// Whether the panel is initially expanded
  final bool initiallyExpanded;

  /// Callback when expansion state changes
  final ValueChanged<bool>? onExpansionChanged;

  /// Background color of the header
  final Color? headerColor;

  /// Background color of the content section
  final Color? contentBackgroundColor;

  /// Text style for the header title
  final TextStyle? headerTextStyle;

  /// Border radius of the panel corners
  final double? borderRadius;

  /// Padding inside the panel header
  final EdgeInsets? padding;

  /// Custom icon for collapsed state
  final Widget? icon;

  /// Custom icon for expanded state
  final Widget? expandedIcon;

  /// Duration of expand/collapse animation
  final Duration? animationDuration;

  const CustomExpansionPanel({
    Key? key,
    required this.title,
    required this.content,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.headerColor,
    this.contentBackgroundColor,
    this.headerTextStyle,
    this.borderRadius,
    this.padding,
    this.icon,
    this.expandedIcon,
    this.animationDuration,
  }) : super(key: key);

  @override
  State<CustomExpansionPanel> createState() => _CustomExpansionPanelState();
}

class _CustomExpansionPanelState extends State<CustomExpansionPanel>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: widget.animationDuration ?? const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
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
    final theme = Theme.of(context);
    final headerColor = widget.headerColor ?? theme.colorScheme.surface;
    final contentBackgroundColor = 
        widget.contentBackgroundColor ?? theme.colorScheme.surface;
    final headerTextStyle = widget.headerTextStyle ?? theme.textTheme.titleMedium;
    final borderRadius = widget.borderRadius ?? 4.0;
    final headerPadding = widget.padding ?? 
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              color: headerColor,
              padding: headerPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: headerTextStyle,
                    ),
                  ),
                  _isExpanded
                      ? widget.expandedIcon ??
                          Icon(Icons.keyboard_arrow_up, color: headerTextStyle?.color)
                      : widget.icon ??
                          Icon(Icons.keyboard_arrow_down, color: headerTextStyle?.color),
                ],
              ),
            ),
          ),
          // Animated content
          AnimatedBuilder(
            animation: _controller.view,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  heightFactor: _heightFactor.value,
                  child: child,
                ),
              );
            },
            child: _isExpanded
                ? Container(
                    color: contentBackgroundColor,
                    padding: const EdgeInsets.all(16.0),
                    width: double.infinity,
                    child: widget.content,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// A widget that displays multiple CustomExpansionPanel widgets in a list.
class CustomExpansionPanelList extends StatelessWidget {
  /// List of expansion panels to display
  final List<CustomExpansionPanel> children;

  /// Color of dividers between panels
  final Color? dividerColor;

  /// Thickness of dividers between panels
  final double? dividerThickness;

  /// Elevation of the panel list
  final double? elevation;

  const CustomExpansionPanelList({
    Key? key,
    required this.children,
    this.dividerColor,
    this.dividerThickness,
    this.elevation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = this.dividerColor ?? theme.dividerColor;
    final dividerThickness = this.dividerThickness ?? 1.0;
    final elevation = this.elevation ?? 1.0;

    return Card(
      elevation: elevation,
      margin: EdgeInsets.zero,
      child: Column(
        children: _buildPanelsWithDividers(dividerColor, dividerThickness),
      ),
    );
  }

  List<Widget> _buildPanelsWithDividers(Color dividerColor, double dividerThickness) {
    final List<Widget> result = [];

    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      
      // Add divider after each panel except the last one
      if (i < children.length - 1) {
        result.add(Divider(
          height: dividerThickness,
          thickness: dividerThickness,
          color: dividerColor,
        ));
      }
    }

    return result;
  }
} 