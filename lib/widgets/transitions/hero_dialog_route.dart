import 'package:flutter/material.dart';

class HeroDialogRoute<T> extends PageRoute<T> {
  final Widget child;

  HeroDialogRoute({required this.child})
      : super(fullscreenDialog: true);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'Fermer';

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
}
