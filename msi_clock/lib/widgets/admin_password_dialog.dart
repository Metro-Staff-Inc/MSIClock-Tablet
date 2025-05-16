import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';

class AdminPasswordDialog extends StatefulWidget {
  const AdminPasswordDialog({super.key});

  @override
  State<AdminPasswordDialog> createState() => _AdminPasswordDialogState();
}

class _AdminPasswordDialogState extends State<AdminPasswordDialog> {
  final _passwordController = TextEditingController();
  String? _error;
  bool _isValidating = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _validatePassword() async {
    if (_isValidating) return; // Prevent multiple validations

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final password = _passwordController.text;
      final adminPassword = await AppConfig.getAdminPassword();

      if (password == adminPassword) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Invalid password';
          _passwordController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error validating password: $e';
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.frontFrames,
      title: Text(
        'Admin Access',
        style: TextStyle(color: AppTheme.defaultText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: AppTheme.defaultText),
              errorText: _error,
              errorStyle: TextStyle(color: AppTheme.errorColor),
              filled: true,
              fillColor: AppTheme.darkerFrames,
            ),
            style: TextStyle(color: AppTheme.defaultText),
            obscureText: true,
            onSubmitted: (_) => _validatePassword(),
            enabled: !_isValidating,
          ),
          if (_isValidating)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mainGreen),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppTheme.mainGreen),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validatePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.mainGreen,
            foregroundColor: AppTheme.windowBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Enter',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

Future<bool> showAdminPasswordDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AdminPasswordDialog(),
  );
  return result ?? false;
}
