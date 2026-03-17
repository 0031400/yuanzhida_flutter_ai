import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/answerly_api.dart';
import '../services/auth_session.dart';
import 'login_page.dart' show kApiBaseUrl;

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();
  final _introductionController = TextEditingController();

  late final AnswerlyApi _api;

  bool _loading = false;
  bool _saving = false;
  bool _loggingOut = false;
  bool _editUsername = false;
  bool _editPassword = false;
  bool _editPhone = false;
  bool _editAvatar = false;
  bool _editIntroduction = false;
  String? _errorText;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _api = AnswerlyApi(baseUrl: kApiBaseUrl);
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    _introductionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      setState(() {
        _errorText = '当前未登录，请先登录后编辑个人信息';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
      _currentUsername = username;
    });

    try {
      final results = await Future.wait([
        _api.checkLogin(username: username, token: token),
        _api.fetchActualUserProfile(
          authUsername: username,
          token: token,
          profileUsername: username,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final loginValid = results[0] as bool;
      if (!loginValid) {
        await AuthSession.clear();
        setState(() {
          _errorText = '登录态已失效，请重新登录';
        });
        return;
      }

      final profile = results[1] as ActualUserProfile;
      setState(() {
        _usernameController.text = profile.username;
        _phoneController.text = profile.phone;
        _introductionController.text = profile.introduction;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      setState(() {
        _errorText = error.message ?? '加载个人信息失败';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '网络异常，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final authUsername = _currentUsername ?? AuthSession.username;
    final token = AuthSession.token;
    if (authUsername == null || token == null) {
      setState(() {
        _errorText = '当前未登录，请先登录';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final request = UpdateUserProfileRequest(
      oldUsername: authUsername,
      newUsername: _editUsername ? _usernameController.text.trim() : null,
      password: _editPassword ? _passwordController.text : null,
      avatar: _editAvatar ? _avatarController.text.trim() : null,
      phone: _editPhone ? _phoneController.text.trim() : null,
      introduction: _editIntroduction
          ? _introductionController.text.trim()
          : null,
    );
    if (!request.hasChanges) {
      setState(() {
        _errorText = '请至少打开一个编辑开关';
      });
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await _api.updateUserProfile(
        authUsername: authUsername,
        token: token,
        request: request,
      );

      final nextUsername = request.newUsername ?? authUsername;
      await AuthSession.save(username: nextUsername, token: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentUsername = nextUsername;
        if (_editUsername) {
          _editUsername = false;
        }
        if (_editPassword) {
          _editPassword = false;
        }
        if (_editPhone) {
          _editPhone = false;
        }
        if (_editAvatar) {
          _editAvatar = false;
        }
        if (_editIntroduction) {
          _editIntroduction = false;
        }
        _passwordController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('个人信息已更新')));
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      setState(() {
        _errorText = error.message ?? '更新个人信息失败';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '网络异常，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      await AuthSession.clear();
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      return;
    }

    setState(() {
      _loggingOut = true;
      _errorText = null;
    });

    try {
      await _api.logout(username: username, token: token);
    } on ApiException catch (error) {
      if (error.code != 'A000204' && mounted) {
        setState(() {
          _errorText = error.message ?? '退出登录失败';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = '网络异常，已清理本地登录态';
        });
      }
    } finally {
      await AuthSession.clear();
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }

    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final busy = _loading || _saving || _loggingOut;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          IconButton(
            onPressed: busy ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF12355B), Color(0xFF1D6F8C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '更新公开资料与账户信息',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '先打开某项的编辑开关，再输入新内容；只有开启的字段才会进入更新请求。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorText != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(_errorText!),
                  ),
                if (_errorText != null) const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _EditableFieldCard(
                                title: '用户名',
                                enabled: _editUsername,
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _editUsername = value;
                                        });
                                      },
                                child: TextFormField(
                                  controller: _usernameController,
                                  enabled: _editUsername && !busy,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '用户名',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_editUsername) {
                                      return null;
                                    }
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return '请输入用户名';
                                    }
                                    if (text.length < 2) {
                                      return '用户名至少 2 个字符';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EditableFieldCard(
                                title: '手机号',
                                enabled: _editPhone,
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _editPhone = value;
                                        });
                                      },
                                child: TextFormField(
                                  controller: _phoneController,
                                  enabled: _editPhone && !busy,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '手机号',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_editPhone) {
                                      return null;
                                    }
                                    final text = value?.trim() ?? '';
                                    if (text.isNotEmpty &&
                                        !RegExp(r'^\d{11}$').hasMatch(text)) {
                                      return '请输入 11 位手机号';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EditableFieldCard(
                                title: '头像地址',
                                enabled: _editAvatar,
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _editAvatar = value;
                                        });
                                      },
                                child: TextFormField(
                                  controller: _avatarController,
                                  enabled: _editAvatar && !busy,
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '头像地址',
                                    hintText: 'https://example.com/avatar.png',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EditableFieldCard(
                                title: '新密码',
                                enabled: _editPassword,
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _editPassword = value;
                                          if (!value) {
                                            _passwordController.clear();
                                          }
                                        });
                                      },
                                child: TextFormField(
                                  controller: _passwordController,
                                  enabled: _editPassword && !busy,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '新密码',
                                    hintText: '留空则不修改',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_editPassword) {
                                      return null;
                                    }
                                    final text = value ?? '';
                                    if (text.isEmpty) {
                                      return '请输入新密码';
                                    }
                                    if (text.length < 6) {
                                      return '密码至少 6 位';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _EditableFieldCard(
                                title: '个人简介',
                                enabled: _editIntroduction,
                                onChanged: busy
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _editIntroduction = value;
                                        });
                                      },
                                child: TextFormField(
                                  controller: _introductionController,
                                  enabled: _editIntroduction && !busy,
                                  minLines: 4,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    labelText: '个人简介',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: busy ? null : _save,
                                      child: _saving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('保存修改'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: busy ? null : _logout,
                                      child: _loggingOut
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('退出登录'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableFieldCard extends StatelessWidget {
  const _EditableFieldCard({
    required this.title,
    required this.enabled,
    required this.onChanged,
    required this.child,
  });

  final String title;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
