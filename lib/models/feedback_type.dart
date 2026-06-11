/// Types of celebration animations for special events
enum CelebrationType {
  /// Standard success - checkmark with orange burst
  /// Used for: Job Created, Quotation Created, Invoice Created, 
  /// Customer Added, Service Created, Expense Logged
  checkmark,

  /// Sparkle celebration - for premium/personal achievements
  /// Used for: Profile Updated, Company Branding Updated, Settings Updated
  sparkle,

  /// Send animation - for communication events
  /// Used for: Email Sent, Email Scheduled
  send,
}

/// Types of flash messages for temporary feedback
enum FlashMessageType {
  success,
  error,
  info,
  warning,
}

/// Extension to get brand colors for celebration types
extension CelebrationTypeExtension on CelebrationType {
  String get displayTitle {
    switch (this) {
      case CelebrationType.checkmark:
        return 'Success!';
      case CelebrationType.sparkle:
        return 'All Set!';
      case CelebrationType.send:
        return 'Sent!';
    }
  }
}

extension FlashMessageTypeExtension on FlashMessageType {
  String get iconName {
    switch (this) {
      case FlashMessageType.success:
        return 'check_circle';
      case FlashMessageType.error:
        return 'error';
      case FlashMessageType.info:
        return 'info';
      case FlashMessageType.warning:
        return 'warning';
    }
  }
}
