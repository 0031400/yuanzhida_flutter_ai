import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/answerly_api.dart';
import '../services/auth_session.dart';
import 'login_page.dart' show kApiBaseUrl;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final AnswerlyApi _api;

  UserProfile? _profile;
  ActualUserProfile? _actualProfile;
  int? _activityScore;
  bool? _loginValid;
  bool _loading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _api = AnswerlyApi(baseUrl: kApiBaseUrl);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      setState(() {
        _profile = null;
        _actualProfile = null;
        _activityScore = null;
        _loginValid = false;
        _errorText = '当前未登录，请先登录后查看个人主页';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final results = await Future.wait([
        _api.checkLogin(username: username, token: token),
        _api.fetchUserProfile(
          authUsername: username,
          token: token,
          profileUsername: username,
        ),
        _api.fetchActualUserProfile(
          authUsername: username,
          token: token,
          profileUsername: username,
        ),
        _api.fetchActivityScore(username: username, token: token),
      ]);

      if (!mounted) {
        return;
      }

      final loginValid = results[0] as bool;
      if (!loginValid) {
        await AuthSession.clear();
      }

      setState(() {
        _loginValid = loginValid;
        _profile = loginValid ? results[1] as UserProfile : null;
        _actualProfile = loginValid ? results[2] as ActualUserProfile : null;
        _activityScore = loginValid ? results[3] as int : null;
        _errorText = loginValid ? null : '登录态已失效，请重新登录';
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final shouldClearSession = error.code == 'A000204';
      if (shouldClearSession) {
        await AuthSession.clear();
      }
      setState(() {
        _errorText = error.message ?? '获取个人信息失败';
        _loginValid = shouldClearSession ? false : _loginValid;
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

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = AuthSession.isLoggedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人主页'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            final content = <Widget>[
              _buildHeroCard(context),
              const SizedBox(height: 16),
              if (_errorText != null)
                _NoticeCard(
                  message: _errorText!,
                  actionLabel: isLoggedIn ? '重试' : '去登录',
                  onAction: isLoggedIn ? _loadProfile : _goToLogin,
                ),
              if (_errorText != null) const SizedBox(height: 16),
            ];

            if (_loading && _profile == null) {
              content.add(
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            } else if (_profile != null && _actualProfile != null) {
              if (isWide) {
                content.add(
                  SizedBox(
                    height: 420,
                    child: Row(
                      children: [
                        Expanded(child: _buildOverviewCard(context)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSensitiveCard(context)),
                      ],
                    ),
                  ),
                );
              } else {
                content.addAll([
                  SizedBox(height: 420, child: _buildOverviewCard(context)),
                  const SizedBox(height: 16),
                  SizedBox(height: 420, child: _buildSensitiveCard(context)),
                ]);
              }
            }

            return ListView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth >= 900 ? 32 : 16,
                vertical: 20,
              ),
              children: content,
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final username = AuthSession.username ?? '未登录';
    final introduction = _profile?.introduction.trim();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D3557), Color(0xFF457B9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            username,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            introduction == null || introduction.isEmpty
                ? '这个用户还没有填写个人简介'
                : introduction,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroTag(
                icon: Icons.verified_user_outlined,
                label: _loginValid == true ? '登录有效' : '待校验',
              ),
              _HeroTag(
                icon: Icons.local_fire_department_outlined,
                label: _activityScore == null ? '活跃度 -' : '活跃度 $_activityScore',
              ),
              _HeroTag(
                icon: Icons.badge_outlined,
                label: _profile?.userType.isEmpty ?? true
                    ? '身份未设置'
                    : _profile!.userType,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final profile = _profile!;
    return _SectionCard(
      title: '公开资料',
      subtitle: '脱敏信息与公开统计',
      child: ListView(
        children: [
          _InfoRow(label: '用户 ID', value: '${profile.id}'),
          _InfoRow(label: '学号', value: profile.studentId),
          _InfoRow(label: '用户名', value: profile.username),
          _InfoRow(label: '手机号', value: profile.phone),
          _InfoRow(label: '身份', value: profile.userType),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                icon: Icons.thumb_up_alt_outlined,
                label: '获赞',
                value: '${profile.likeCount}',
              ),
              _MetricCard(
                icon: Icons.bookmark_border,
                label: '被收藏',
                value: '${profile.collectCount}',
              ),
              _MetricCard(
                icon: Icons.workspace_premium_outlined,
                label: '有用',
                value: '${profile.usefulCount}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoBlock(label: '个人简介', value: profile.introduction),
        ],
      ),
    );
  }

  Widget _buildSensitiveCard(BuildContext context) {
    final profile = _actualProfile!;
    return _SectionCard(
      title: '账户详情',
      subtitle: '非脱敏资料与登录态摘要',
      child: ListView(
        children: [
          _InfoRow(label: '实际用户名', value: profile.username),
          _InfoRow(label: '完整手机号', value: profile.phone),
          _InfoRow(label: '已解决题目', value: '${profile.solvedCount}'),
          _InfoRow(label: '累计获赞', value: '${profile.likeCount}'),
          _InfoRow(
            label: 'Token',
            value: _maskToken(AuthSession.token ?? ''),
          ),
          _InfoRow(
            label: 'API',
            value: kApiBaseUrl,
          ),
          const SizedBox(height: 16),
          _InfoBlock(label: '简介快照', value: profile.introduction),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _goToLogin,
            child: const Text('返回登录页'),
          ),
        ],
      ),
    );
  }

  String _maskToken(String token) {
    if (token.length <= 12) {
      return token;
    }
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(value.isEmpty ? '暂无内容' : value),
          ],
        ),
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
