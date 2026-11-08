import 'package:flutter/material.dart';

/// Root navigator key — lets services (fall detection, notifications)
/// show UI without a BuildContext.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
