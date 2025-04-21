import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/core/utils/error_utils.dart';
import 'package:supabase_sync_calendar/features/auth/domain/blocs/custom_auth_bloc/custom_auth_bloc.dart';
import 'package:supabase_sync_calendar/features/auth/domain/blocs/custom_auth_bloc/custom_auth_event.dart';

class LoginForm extends StatefulWidget {
  final String initialSupabaseUrl;
  final String initialSupabaseApiKey;
  final String initialEmail;
  final String initialPassword;
  final bool hasBeenLoggedInBefore;

  const LoginForm({
    super.key,
    required this.initialSupabaseUrl,
    required this.initialSupabaseApiKey,
    required this.initialEmail,
    required this.initialPassword,
    required this.hasBeenLoggedInBefore,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscureApiKey = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialSupabaseUrl);
    _apiKeyController =
        TextEditingController(text: widget.initialSupabaseApiKey);
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController(text: widget.initialPassword);

    // Hide credentials if this is not the first login
    _obscureApiKey = widget.hasBeenLoggedInBefore;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),

          // Header
          const Text(
            'Sign in to your Supabase account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Credentials Form
          widget.hasBeenLoggedInBefore
              ? _buildHiddenCredentialsView()
              : _buildCredentialsForm(),

          const SizedBox(height: 20),

          // User Credentials
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            obscureText: _obscurePassword,
          ),
          const SizedBox(height: 24),

          // Login Button
          ElevatedButton.icon(
            onPressed: _login,
            icon: const Icon(Icons.login),
            label: const Text('Login'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsForm() {
    return Column(
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Supabase URL',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'Supabase API Key',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureApiKey ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureApiKey = !_obscureApiKey;
                });
              },
            ),
          ),
          obscureText: _obscureApiKey,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHiddenCredentialsView() {
    return Column(
      children: [
        // Hidden credentials with edit option
        ListTile(
          title: const Text('Supabase URL'),
          subtitle: Text(
            _obscureApiKey
                ? '${widget.initialSupabaseUrl.substring(0, 15)}...'
                : widget.initialSupabaseUrl,
          ),
          leading: const Icon(Icons.link),
          trailing: IconButton(
            icon: Icon(
              _obscureApiKey ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _obscureApiKey = !_obscureApiKey;
              });
            },
          ),
        ),

        ListTile(
          title: const Text('Supabase API Key'),
          subtitle: Text(
            _obscureApiKey
                ? '••••••••••••••••••••'
                : widget.initialSupabaseApiKey,
          ),
          leading: const Icon(Icons.key),
        ),

        TextButton.icon(
          onPressed: () {
            setState(() {
              _obscureApiKey = false;
              _showEditCredentialsDialog();
            });
          },
          icon: const Icon(Icons.edit),
          label: const Text('Edit Credentials'),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showEditCredentialsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Supabase Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Supabase URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Supabase API Key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _login() {
    final url = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (url.isEmpty || apiKey.isEmpty || email.isEmpty || password.isEmpty) {
      ErrorUtils.showErrorSnackBar(
        context,
        'Please fill in all fields',
      );
      return;
    }

    // Basic URL validation
    if (!url.startsWith('https://')) {
      ErrorUtils.showErrorSnackBar(
        context,
        'Supabase URL must start with https://',
      );
      return;
    }

    // Basic email validation
    if (!email.contains('@') || !email.contains('.')) {
      ErrorUtils.showErrorSnackBar(
        context,
        'Please enter a valid email address',
      );
      return;
    }

    // Login Button
    context.read<CustomAuthBloc>().add(
          LoginRequested(
            supabaseUrl: url,
            supabaseApiKey: apiKey,
            email: email,
            password: password,
          ),
        );
  }
}
