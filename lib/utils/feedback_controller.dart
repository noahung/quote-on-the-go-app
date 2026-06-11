import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/success_celebration_screen.dart';
import '../components/success_bottom_sheet.dart';
import '../components/flash_message.dart';
import '../models/feedback_type.dart';

/// Controller for showing feedback messages and celebrations
/// Use via Riverpod: ref.read(feedbackControllerProvider)
class FeedbackController {
  /// Show a full-screen success celebration for special events
  /// 
  /// Example:
  /// ```dart
  /// await ref.read(feedbackControllerProvider).showCelebration(
  ///   context: context,
  ///   type: CelebrationType.checkmark,
  ///   title: 'Quotation Created',
  ///   subtitle: 'QT-001 has been saved',
  ///   onDone: () => context.pop(),
  /// );
  /// ```
  Future<void> showCelebration({
    required BuildContext context,
    required CelebrationType type,
    required String title,
    String? subtitle,
    String? buttonText,
    VoidCallback? onDone,
    bool allowAutoDismiss = false,
    Duration autoDismissDuration = const Duration(seconds: 3),
  }) async {
    return SuccessCelebrationScreen.show(
      context: context,
      type: type,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
      onDone: onDone,
      allowAutoDismiss: allowAutoDismiss,
      autoDismissDuration: autoDismissDuration,
    );
  }

  /// Show a temporary flash message (replaces SnackBar)
  /// 
  /// Example:
  /// ```dart
  /// ref.read(feedbackControllerProvider).showFlash(
  ///   context: context,
  ///   type: FlashMessageType.success,
  ///   message: 'Photo uploaded',
  /// );
  /// ```
  void showFlash({
    required BuildContext context,
    required FlashMessageType type,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    FlashMessage.show(
      context: context,
      type: type,
      message: message,
      duration: duration,
    );
  }

  /// Convenience methods for flash messages
  void success(BuildContext context, String message) {
    showFlash(
      context: context,
      type: FlashMessageType.success,
      message: message,
    );
  }

  void error(BuildContext context, String message) {
    showFlash(
      context: context,
      type: FlashMessageType.error,
      message: message,
    );
  }

  void info(BuildContext context, String message) {
    showFlash(
      context: context,
      type: FlashMessageType.info,
      message: message,
    );
  }

  void warning(BuildContext context, String message) {
    showFlash(
      context: context,
      type: FlashMessageType.warning,
      message: message,
    );
  }

  /// Show a bottom sheet style success modal (like the reference image)
  /// Rounded card with animated icon, centered on screen
  /// 
  /// Example:
  /// ```dart
  /// await ref.read(feedbackControllerProvider).showBottomSheet(
  ///   context: context,
  ///   type: CelebrationType.checkmark,
  ///   title: 'Success',
  ///   subtitle: 'Password successfully changed',
  /// );
  /// ```
  Future<void> showBottomSheet({
    required BuildContext context,
    required CelebrationType type,
    required String title,
    String? subtitle,
    String buttonText = 'Got it',
  }) async {
    return SuccessBottomSheet.show(
      context: context,
      type: type,
      title: title,
      subtitle: subtitle,
      buttonText: buttonText,
    );
  }

  /// Hide current flash message if any
  void hideFlash() {
    FlashMessage.hide();
  }
}

/// Provider for the feedback controller
final feedbackControllerProvider = Provider<FeedbackController>((ref) {
  return FeedbackController();
});

/// Extension on WidgetRef for easier access
extension FeedbackControllerExtension on WidgetRef {
  FeedbackController get feedback => read(feedbackControllerProvider);
}
