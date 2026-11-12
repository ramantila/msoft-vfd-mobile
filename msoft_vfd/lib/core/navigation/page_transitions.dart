import 'package:flutter/material.dart';

/// Shared slide-in-from-right + fade push transition, matching the
/// convention used across the app's existing screens (previously duplicated
/// per-file as a private `_slideRight` helper).
PageRoute<T> slideRight<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, anim, _, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
              parent: anim, curve: const Interval(0.0, 0.38, curve: Curves.easeOut)),
        );
        return FadeTransition(
            opacity: fade, child: SlideTransition(position: slide, child: child));
      },
    );
