import 'package:flutter/material.dart';

class ErrorHandler {
  // ─── Show Error Snackbar ───────────────────────────────────────────────
  // Shows a red snackbar at the bottom of the screen with the error message
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Show Success Snackbar ─────────────────────────────────────────────
  // Shows a green snackbar for success messages
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Show Loading Dialog ───────────────────────────────────────────────
  // Shows a loading spinner dialog while an async operation is in progress
  static void showLoading(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  // ─── Hide Loading Dialog ───────────────────────────────────────────────
  // Dismisses the loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // ─── Parse Error Message ───────────────────────────────────────────────
  // Converts common error types to user-friendly messages
  static String parseError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('connection refused') ||
        errorStr.contains('network')) {
      return 'Connection error. Check your internet connection.';
    }

    if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return 'Session expired. Please login again.';
    }

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Resource not found.';
    }

    return 'Something went wrong. Please try again.';
  }
}
