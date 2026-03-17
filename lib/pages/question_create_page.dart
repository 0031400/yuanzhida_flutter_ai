import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/answerly_api.dart';
import '../services/auth_session.dart';
import 'login_page.dart' show kApiBaseUrl;

class QuestionCreatePage extends StatefulWidget {
  const QuestionCreatePage({super.key});

  @override
  State<QuestionCreatePage> createState() => _QuestionCreatePageState();
}

class _QuestionCreatePageState extends State<QuestionCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _imagesController = TextEditingController();

  late final AnswerlyApi _api;

  List<CategorySummary> _categories = const [];
  int? _selectedCategoryId;
  bool _loadingCategories = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _api = AnswerlyApi(baseUrl: kApiBaseUrl);
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imagesController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    setState(() {
      _loadingCategories = true;
      _errorText = null;
    });

    try {
      final categories = await _api.fetchCategories(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = categories;
        _selectedCategoryId ??= categories.isNotEmpty ? categories.first.id : null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.message ?? '获取分类失败';
        _categories = const [];
        _selectedCategoryId = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '网络异常，请稍后重试';
        _categories = const [];
        _selectedCategoryId = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCategories = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      setState(() {
        _errorText = '当前未登录，请先登录后发布题目';
      });
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() {
        _errorText = '请选择题目分类';
      });
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final loginValid = await _api.checkLogin(username: username, token: token);
      if (!loginValid) {
        await AuthSession.clear();
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = '登录态已失效，请重新登录';
        });
        return;
      }

      await _api.createQuestion(
        username: username,
        token: token,
        request: CreateQuestionRequest(
          images: _normalizeImages(_imagesController.text),
          categoryId: _selectedCategoryId!,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ),
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('题目发布成功')));
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.questionList,
        (route) => route.settings.name == AppRoutes.home,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      setState(() {
        _errorText = error.message ?? '发布题目失败';
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
          _submitting = false;
        });
      }
    }
  }

  String _normalizeImages(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(',');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final username = AuthSession.username;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布题目'),
        actions: [
          IconButton(
            onPressed: _loadingCategories || _submitting
                ? null
                : () => _loadCategories(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新分类',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B1F1F), Color(0xFFB85C38)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '把问题描述清楚，答案会来得更快',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        username == null ? '当前未登录' : '当前发布账号：$username',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: '题目分类',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: _loadingCategories || _submitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                  });
                                },
                          validator: (value) {
                            if (value == null) {
                              return '请选择题目分类';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '标题',
                            hintText: '例如：微积分极限题求解',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return '请输入标题';
                            }
                            if (text.length < 5) {
                              return '标题至少 5 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contentController,
                          minLines: 8,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            labelText: '题目内容',
                            hintText: '请补充题目背景、已尝试的方法、卡住的位置等',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return '请输入题目内容';
                            }
                            if (text.length < 10) {
                              return '题目内容至少 10 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _imagesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '图片地址',
                            hintText: '支持多个地址，使用英文逗号或换行分隔',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '接口字段会按逗号拼接为 `images`，留空则不上传图片。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _submitting || _loadingCategories
                                    ? null
                                    : _submit,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('立即发布'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.of(context).maybePop(),
                                child: const Text('取消'),
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
