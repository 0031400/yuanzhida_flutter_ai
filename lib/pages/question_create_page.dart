import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../services/answerly_api.dart';
import '../services/auth_session.dart';

class QuestionCreatePage extends StatefulWidget {
  const QuestionCreatePage({super.key});

  @override
  State<QuestionCreatePage> createState() => _QuestionCreatePageState();
}

class _QuestionCreatePageState extends State<QuestionCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late final AnswerlyApi _api;

  List<CategorySummary> _categories = const [];
  final List<_UploadedImage> _uploadedImages = <_UploadedImage>[];
  int? _selectedCategoryId;
  bool _loadingCategories = false;
  bool _uploadingImages = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _api = AnswerlyApi(baseUrl: AppConfig.apiBaseUrl);
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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
        _selectedCategoryId ??= categories.isNotEmpty
            ? categories.first.id
            : null;
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
      final loginValid = await _api.checkLogin(
        username: username,
        token: token,
      );
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
          images: _uploadedImages.map((item) => item.serverPath).join(','),
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
        (route) => route.settings.name == AppRoutes.root,
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

  Future<void> _pickAndUploadImages() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      setState(() {
        _errorText = '当前未登录，请先登录后上传图片';
      });
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _uploadingImages = true;
      _errorText = null;
    });

    try {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw ApiException('B000102', '图片读取失败');
        }
        final filename = file.name.isEmpty ? 'image.png' : file.name;
        final serverPath = await _api.uploadImage(
          username: username,
          token: token,
          bytes: bytes,
          filename: filename,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _uploadedImages.add(
            _UploadedImage(displayName: filename, serverPath: serverPath),
          );
        });
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      setState(() {
        _errorText = error.message ?? '图片上传失败';
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
          _uploadingImages = false;
        });
      }
    }
  }

  void _removeUploadedImage(_UploadedImage image) {
    setState(() {
      _uploadedImages.remove(image);
    });
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
            onPressed: _loadingCategories || _submitting || _uploadingImages
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
                          onChanged:
                              _loadingCategories ||
                                  _submitting ||
                                  _uploadingImages
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '题目图片',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _submitting || _uploadingImages
                                  ? null
                                  : _pickAndUploadImages,
                              icon: _uploadingImages
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file_outlined),
                              label: Text(_uploadingImages ? '上传中' : '选择并上传'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _uploadedImages.isEmpty
                              ? '可选。选择本地图片后会先上传到服务器，发布时自动拼接内部 `images` 字段。'
                              : '已上传 ${_uploadedImages.length} 张图片。页面只展示文件名，不展示内部图片地址。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_uploadedImages.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('暂未上传图片'),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _uploadedImages
                                .map(
                                  (image) => Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 180,
                                      maxWidth: 260,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.image_outlined,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            image.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              _submitting || _uploadingImages
                                              ? null
                                              : () =>
                                                    _removeUploadedImage(image),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 18,
                                          ),
                                          tooltip: '移除',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    _submitting ||
                                        _loadingCategories ||
                                        _uploadingImages
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
                                onPressed: _submitting || _uploadingImages
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

class _UploadedImage {
  const _UploadedImage({required this.displayName, required this.serverPath});

  final String displayName;
  final String serverPath;
}
