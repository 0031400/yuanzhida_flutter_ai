import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/placeholder_page.dart';
import '../pages/profile_page.dart';
import '../pages/profile_edit_page.dart';
import '../pages/question_create_page.dart';
import '../pages/question_browser_page.dart';
import '../pages/register_page.dart';

class AppRoutes {
  static const root = '/';
  static const login = '/login';
  static const home = '/home';
  static const register = '/register';
  static const forgotUsername = '/forgot-username';
  static const resetPassword = '/reset-password';
  static const questionList = '/questions';
  static const questionCreate = '/questions/create';
  static const questionDetail = '/questions/detail';
  static const myQuestions = '/me/questions';
  static const myCollections = '/me/collections';
  static const recentQuestions = '/me/recent';
  static const myComments = '/me/comments';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const activityRank = '/activity/rank';
  static const messages = '/messages';
  static const categories = '/categories';
  static const categoryManage = '/admin/categories';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
      case login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case register:
        return MaterialPageRoute<void>(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      case forgotUsername:
        return _placeholderRoute(
          settings,
          title: '找回用户名',
          description: '对应通过邮箱找回用户名接口。',
        );
      case resetPassword:
        return _placeholderRoute(
          settings,
          title: '重置密码',
          description: '对应发送重置验证码和重置密码接口。',
        );
      case questionList:
        return MaterialPageRoute<void>(
          builder: (_) => QuestionBrowserPage(
            initialQuestionId: _readQuestionId(settings.arguments),
          ),
          settings: settings,
        );
      case questionCreate:
        return MaterialPageRoute<void>(
          builder: (_) => const QuestionCreatePage(),
          settings: settings,
        );
      case questionDetail:
        return MaterialPageRoute<void>(
          builder: (_) => QuestionBrowserPage(
            initialQuestionId: _readQuestionId(settings.arguments),
          ),
          settings: settings,
        );
      case myQuestions:
        return _placeholderRoute(
          settings,
          title: '我的题目',
          description: '对应我的题目分页接口。',
        );
      case myCollections:
        return _placeholderRoute(
          settings,
          title: '我的收藏',
          description: '对应收藏分页与收藏操作接口。',
        );
      case recentQuestions:
        return _placeholderRoute(
          settings,
          title: '最近浏览',
          description: '对应最近浏览分页接口。',
        );
      case myComments:
        return _placeholderRoute(
          settings,
          title: '我的评论',
          description: '对应我的评论分页、评论编辑删除接口。',
        );
      case profile:
        return MaterialPageRoute<void>(
          builder: (_) => const ProfilePage(),
          settings: settings,
        );
      case profileEdit:
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileEditPage(),
          settings: settings,
        );
      case activityRank:
        return _placeholderRoute(
          settings,
          title: '活跃榜',
          description: '对应活跃度排行榜与我的活跃度接口。',
        );
      case messages:
        return _placeholderRoute(
          settings,
          title: '消息中心',
          description: '对应消息概览、按类型分页、删除消息接口。',
        );
      case categories:
        return _placeholderRoute(
          settings,
          title: '主题列表',
          description: '对应公开主题查询接口。',
        );
      case categoryManage:
        return _placeholderRoute(
          settings,
          title: '主题管理',
          description: '对应管理员新增、修改、删除主题接口。',
        );
      default:
        return _placeholderRoute(
          settings,
          title: '页面不存在',
          description: '未匹配到对应路由，请检查跳转路径。',
        );
    }
  }

  static MaterialPageRoute<void> _placeholderRoute(
    RouteSettings settings, {
    required String title,
    required String description,
  }) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => PlaceholderPage(
        title: title,
        routePath: settings.name ?? 'unknown',
        description: description,
      ),
    );
  }

  static int? _readQuestionId(Object? arguments) {
    if (arguments is int) {
      return arguments;
    }
    if (arguments is String) {
      return int.tryParse(arguments);
    }
    if (arguments is Map<String, dynamic>) {
      final value = arguments['id'];
      if (value is int) {
        return value;
      }
      return int.tryParse(value?.toString() ?? '');
    }
    return null;
  }
}
