import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _sections = <_RouteSection>[
    _RouteSection(
      title: '用户模块',
      items: [
        _RouteItem('登录', AppRoutes.login, '当前已实现'),
        _RouteItem('注册', AppRoutes.register, '用户注册与邮箱验证码'),
        _RouteItem('找回用户名', AppRoutes.forgotUsername, '邮箱找回用户名'),
        _RouteItem('重置密码', AppRoutes.resetPassword, '重置密码流程'),
        _RouteItem('个人主页', AppRoutes.profile, '用户信息与登录状态'),
        _RouteItem('编辑资料', AppRoutes.profileEdit, '资料编辑与退出登录'),
        _RouteItem('活跃榜', AppRoutes.activityRank, '活跃度排行榜'),
      ],
    ),
    _RouteSection(
      title: '题目与评论',
      items: [
        _RouteItem('题目广场', AppRoutes.questionList, '公开列表与搜索'),
        _RouteItem('发布题目', AppRoutes.questionCreate, '创建或编辑题目'),
        _RouteItem('题目详情', AppRoutes.questionDetail, '详情、评论、点赞、收藏'),
        _RouteItem('我的题目', AppRoutes.myQuestions, '我的提问列表'),
        _RouteItem('我的收藏', AppRoutes.myCollections, '收藏题目列表'),
        _RouteItem('最近浏览', AppRoutes.recentQuestions, '浏览历史'),
        _RouteItem('我的评论', AppRoutes.myComments, '我的回答和评论'),
      ],
    ),
    _RouteSection(
      title: '主题与消息',
      items: [
        _RouteItem('主题列表', AppRoutes.categories, '公开主题导航'),
        _RouteItem('主题管理', AppRoutes.categoryManage, '管理员主题管理'),
        _RouteItem('消息中心', AppRoutes.messages, '系统、点赞、评论消息'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200
        ? 3
        : width >= 760
        ? 2
        : 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Answerly 路由总览')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('根据 API 文档整理的页面入口', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '已开发页面保持现状，未开发页面先使用占位符承接，便于后续逐页实现。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          for (final section in _sections) ...[
            Text(section.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: width >= 760 ? 1.8 : 2.8,
              ),
              itemBuilder: (context, index) {
                final item = section.items[index];
                return _RouteCard(item: item);
              },
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.item});

  final _RouteItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(item.description, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              item.route,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pushNamed(item.route);
                },
                child: const Text('进入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSection {
  const _RouteSection({required this.title, required this.items});

  final String title;
  final List<_RouteItem> items;
}

class _RouteItem {
  const _RouteItem(this.label, this.route, this.description);

  final String label;
  final String route;
  final String description;
}
