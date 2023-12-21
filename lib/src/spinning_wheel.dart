// ignore_for_file: unnecessary_null_comparison

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_spinning_wheel/src/utils.dart';

class SpinningWheel extends StatefulWidget {
  final double width;
  final double height;
  final Image image;
  final int dividers;
  final double initialSpinAngle;
  final double spinResistance;
  final bool canInteractWhileSpinning;
  final Image? secondaryImage;
  final double secondaryImageHeight;
  final double secondaryImageWidth;
  final double secondaryImageTop;
  final double secondaryImageLeft;
  final Function(int) onUpdate;
  final Function(int) onEnd;
  final Stream<dynamic>? shouldStartOrStop;

  SpinningWheel({
    required Image image,
    required this.width,
    required this.height,
    required this.dividers,
    this.initialSpinAngle = 0.0,
    this.spinResistance = 0.5,
    this.canInteractWhileSpinning = true,
    this.secondaryImage,
    this.secondaryImageHeight = 0.0,
    this.secondaryImageWidth = 0.0,
    this.secondaryImageTop = 0.0,
    this.secondaryImageLeft = 0.0,
    required this.onUpdate,
    required this.onEnd,
    this.shouldStartOrStop,
  })   : assert(width > 0.0 && height > 0.0),
        assert(spinResistance > 0.0 && spinResistance <= 1.0),
        assert(initialSpinAngle >= 0.0 && initialSpinAngle <= (2 * pi)),
        assert(secondaryImage == null ||
            (secondaryImageHeight <= height && secondaryImageWidth <= width)),
        image = image, // Provide a default value for the image parameter
        super();

  @override
  _SpinningWheelState createState() => _SpinningWheelState();
}


class _SpinningWheelState extends State<SpinningWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late SpinVelocity _spinVelocity;
  late NonUniformCircularMotion _motion;
  Offset? _localPositionOnPanUpdate;
  double _totalDuration = 0;
  double _initialCircularVelocity = 0;
  double _dividerAngle = 0;
  double _currentDistance = 0;
  double _initialSpinAngle = 0;
  int _currentDivider = 0;
  bool _isBackwards = false;
  DateTime? _offsetOutsideTimestamp;
  late RenderBox _renderBox;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();

    _spinVelocity = SpinVelocity(width: widget.width, height: widget.height);
    _motion = NonUniformCircularMotion(resistance: widget.spinResistance);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 0),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    _dividerAngle = _motion.anglePerDivision(widget.dividers);
    _initialSpinAngle = widget.initialSpinAngle;

    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) _stopAnimation();
    });

    if (widget.shouldStartOrStop != null) {
      _subscription = widget.shouldStartOrStop!.listen(_startOrStop);
    }
  }

  _startOrStop(dynamic velocity) {
    if (_animationController.isAnimating) {
      _stopAnimation();
    } else {
      var pixelsPerSecondY = velocity ?? 8000.0;
      _localPositionOnPanUpdate = Offset(250.0, 250.0);
      _startAnimation(Offset(0.0, pixelsPerSecondY));
    }
  }

  double get topSecondaryImage =>
      widget.secondaryImageTop;

  double get leftSecondaryImage =>
      widget.secondaryImageLeft;

  double get widthSecondaryImage => widget.secondaryImageWidth;

  double get heightSecondaryImage => widget.secondaryImageHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      child: Stack(
        children: [
          GestureDetector(
            onPanUpdate: _moveWheel,
            onPanEnd: _startAnimationOnPanEnd,
            onPanDown: (_details) => _stopAnimation(),
            child: AnimatedBuilder(
                animation: _animation,
                child: Container(child: widget.image),
                builder: (context, child) {
                  _updateAnimationValues();
                  widget.onUpdate(_currentDivider);
                  return Transform.rotate(
                    angle: _initialSpinAngle + _currentDistance,
                    child: child,
                  );
                }),
          ),
          if (widget.secondaryImage != null)
            Positioned(
              top: topSecondaryImage,
              left: leftSecondaryImage,
              child: Container(
                height: heightSecondaryImage,
                width: widthSecondaryImage,
                child: widget.secondaryImage,
              ),
            ),
        ],
      ),
    );
  }

  bool get _userCanInteract =>
      !_animationController.isAnimating || widget.canInteractWhileSpinning;

  void _updateLocalPosition(Offset position) {
    if (_renderBox == null) {
      _renderBox = context.findRenderObject() as RenderBox;
    }
    _localPositionOnPanUpdate = _renderBox.globalToLocal(position);
  }

  bool _contains(Offset p) => Size(widget.width, widget.height).contains(p);

  void _updateAnimationValues() {
    if (_animationController.isAnimating) {
      var currentTime = _totalDuration * _animation.value;
      _currentDistance = _motion.distance(_initialCircularVelocity, currentTime);
      if (_isBackwards) {
        _currentDistance = -_currentDistance;
      }
    }
    var modulo = _motion.modulo(_currentDistance + _initialSpinAngle);
    _currentDivider = widget.dividers - (modulo ~/ _dividerAngle);
    if (_animationController.isCompleted) {
      _initialSpinAngle = modulo;
      _currentDistance = 0;
    }
  }

  void _moveWheel(DragUpdateDetails details) {
    if (!_userCanInteract) return;

    if (_offsetOutsideTimestamp != null) return;

    _updateLocalPosition(details.globalPosition);

    if (_contains(_localPositionOnPanUpdate!)) {
      var angle = _spinVelocity.offsetToRadians(_localPositionOnPanUpdate!);
      setState(() {
        _currentDistance = angle - _initialSpinAngle;
      });
    } else {
      _offsetOutsideTimestamp = DateTime.now();
    }
  }

  void _stopAnimation() {
    if (!_userCanInteract) return;

    _offsetOutsideTimestamp = null;
    _animationController.stop();
    _animationController.reset();

    widget.onEnd(_currentDivider);
  }

  void _startAnimationOnPanEnd(DragEndDetails details) {
    if (!_userCanInteract) return;

    if (_offsetOutsideTimestamp != null) {
      var difference = DateTime.now().difference(_offsetOutsideTimestamp!);
      _offsetOutsideTimestamp = null;
      if (difference.inMilliseconds > 50) return;
    }

    if (_localPositionOnPanUpdate == null) return;

    _startAnimation(details.velocity.pixelsPerSecond);
  }

  void _startAnimation(Offset pixelsPerSecond) {
    var velocity = _spinVelocity.getVelocity(_localPositionOnPanUpdate!, pixelsPerSecond);

    _localPositionOnPanUpdate = null;
    _isBackwards = velocity < 0;
    _initialCircularVelocity = pixelsPerSecondToRadians(velocity.abs());
    _totalDuration = _motion.duration(_initialCircularVelocity);

    _animationController.duration =
        Duration(milliseconds: (_totalDuration * 1000).round());

    _animationController.reset();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subscription.cancel();
      super.dispose();
  }
}
