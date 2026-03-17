import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../services/answerly_api.dart';
import '../services/auth_session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  late final AnswerlyApi _api;

  Uint8List? _captchaBytes;
  bool _loadingCaptcha = false;
  bool _submitting = false;
  String? _errorText;
  String? _token;

  @override
  void initState() {
    super.initState();
    _api = AnswerlyApi(baseUrl: AppConfig.apiBaseUrl);
    _reloadCaptcha();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _reloadCaptcha() async {
    setState(() {
      _loadingCaptcha = true;
      _errorText = null;
    });

    try {
      final bytes = await _api.fetchCaptcha();
      if (!mounted) return;
      setState(() {
        _captchaBytes = bytes;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = '获取验证码失败，请重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCaptcha = false;
        });
      }
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final captcha = _captchaController.text.trim();

    if (username.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() {
        _errorText = '请填写用户名、密码和验证码';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final token = await _api.login(
        username: username,
        password: password,
        code: captcha,
      );
      if (!mounted) return;
      setState(() {
        _token = token;
      });
      await AuthSession.save(username: username, token: token);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录成功')));
      Navigator.of(context).pushReplacementNamed(AppRoutes.root);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = error.message ?? '登录失败';
      });
      await _reloadCaptcha();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = '网络异常，请稍后重试';
      });
      await _reloadCaptcha();
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final horizontalPadding = maxWidth > 900 ? 64.0 : 24.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Answerly 论坛',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '欢迎回来，请登录继续',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: '密码',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _captchaController,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: '验证码',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) => _login(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 108,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _loadingCaptcha
                                      ? null
                                      : _reloadCaptcha,
                                  child: _loadingCaptcha
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : _captchaBytes == null
                                      ? const Text('刷新')
                                      : Image.memory(
                                          _captchaBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorText!,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _login,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('登录'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.register);
                            },
                            child: const Text('没有账号？去注册'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.resetPassword);
                            },
                            child: const Text('忘记密码？去重置'),
                          ),
                          Text(
                            'API: ${AppConfig.apiBaseUrl}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.outline),
                          ),
                          if (_token != null) ...[
                            const SizedBox(height: 16),
                            SelectableText(
                              'Token: $_token',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
