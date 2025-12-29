import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_keyboard_visibility_platform_interface/flutter_keyboard_visibility_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as html show window, Navigator;

/// The web implementation of the [FlutterKeyboardVisibilityPlatform] of the
/// FlutterKeyboardVisibility plugin.
class FlutterKeyboardVisibilityPluginWeb
    extends FlutterKeyboardVisibilityPlatform {
  /// Constructs a [FlutterKeyboardVisibilityPluginWeb].
  FlutterKeyboardVisibilityPluginWeb(html.Navigator navigator);

  static final _onChangeController = StreamController<bool>();
  static final _onChange = _onChangeController.stream.asBroadcastStream();

  static bool _isPortrait = true;
  static double _knownHeight = 0;
  static bool _isVisible = false;

  /// Factory method that initializes the FlutterKeyboardVisibility plugin
  /// platform with an instance of the plugin for the web.
  static void registerWith(Registrar registrar) {
    FlutterKeyboardVisibilityPlatform.instance =
        FlutterKeyboardVisibilityPluginWeb(html.window.navigator);

    // Initialize known height
    _knownHeight = _getHeight();

    // Primarily use MediaQueryList to listen for orientation changes
    final mediaQueryList = html.window.matchMedia('(orientation: portrait)');
    mediaQueryList.addEventListener(
        'change', (() => _updateOrientation(mediaQueryList.matches)).toJS);
    // Fallback to the deprecated addListener for browsers that do not support
    // addEventListener on MediaQueryList
    mediaQueryList
        .addListener((() => _updateOrientation(mediaQueryList.matches)).toJS);
    // Fallback to 'orientationchange' listener on the window object
    html.window.addEventListener(
        'orientationchange',
        () {
          final angle = html.window.orientation;
          final isPortrait = angle % 180 == 0;
          _updateOrientation(isPortrait);
        }.toJS);

    // Listen for visualViewport resize events
    html.window.visualViewport?.addEventListener(
        'resize',
        () {
          final newHeight = _getHeight();
          _checkKeyboardVisibility(newHeight);
        }.toJS);

    // Fallback to 'resize' listener on the window object
    // This is a fallback for browsers that do not support visualViewport
    // and also for orientation changes not detected by MediaQueryList
    html.window.addEventListener(
        'resize',
        () {
          final isPortrait = html.window.innerHeight > html.window.innerWidth;
          _updateOrientation(isPortrait);
          final newHeight = _getHeight();
          _checkKeyboardVisibility(newHeight);
        }.toJS);

    _knownHeight = _getHeight();
  }

  static void _updateOrientation(bool isPortrait) {
    // debounce same value
    if (isPortrait == _isPortrait) {
      return;
    }
    _isPortrait = isPortrait;
    _knownHeight = _getHeight();
  }

  static double _getHeight() {
    final vvh = html.window.visualViewport?.height;
    final vh = html.window.innerHeight;
    return vvh ?? vh.toDouble();
  }

  static void _checkKeyboardVisibility(double newHeight) {
    // wait or 200ms to allow for orientation change events to settle
    Future.delayed(const Duration(milliseconds: 200), (() {
      const minDifference = 150; // pixels
      final heightDifference = (_knownHeight - newHeight);
      _knownHeight = newHeight;
      if (heightDifference.abs() > minDifference) {
        _updateVisibility(heightDifference > 0);
      }
    }));
  }

  static void _updateVisibility(bool newValue) {
    // Don't report the same value multiple times
    if (newValue == _isVisible) {
      return;
    }

    _isVisible = newValue;
    _onChangeController.add(newValue);
  }

  /// Emits changes to keyboard visibility from the platform. Web is not
  /// implemented yet so false is returned.
  @override
  Stream<bool> get onChange => _onChange;
}
