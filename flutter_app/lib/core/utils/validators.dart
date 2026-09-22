class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15) return 'Enter a valid phone number';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }

  static String? minLength(String? value, int min, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    if (value.trim().length < min) return '$fieldName must be at least $min characters';
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Amount']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    final number = double.tryParse(value.trim());
    if (number == null) return 'Enter a valid number';
    if (number <= 0) return '$fieldName must be greater than zero';
    return null;
  }
}
