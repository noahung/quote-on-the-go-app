import 'package:flutter/material.dart';
import 'auth_credentials_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthCredentialsScreen(register: false);
}
