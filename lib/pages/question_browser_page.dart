import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../routes/app_routes.dart';
import '../services/answerly_api.dart';
import '../services/auth_session.dart';
import '../widgets/html_image_view.dart';

class QuestionBrowserPage extends StatefulWidget {
  const QuestionBrowserPage({super.key, this.initialQuestionId});

  final int? initialQuestionId;

  @override
  State<QuestionBrowserPage> createState() => _QuestionBrowserPageState();
}

class _QuestionBrowserPageState extends State<QuestionBrowserPage> {
  final _searchController = TextEditingController();
  final _answerController = TextEditingController();
  late final AnswerlyApi _api;

  List<CategorySummary> _categories = const [];
  List<QuestionSummary> _questions = const [];
  List<CommentItem> _comments = const [];
  final List<_UploadedImage> _uploadedImages = <_UploadedImage>[];
  QuestionDetail? _selectedQuestion;
  int? _selectedQuestionId;
  int? _selectedCategoryId;
  bool _loadingCategories = false;
  bool _loadingQuestions = false;
  bool _loadingDetail = false;
  bool _loadingComments = false;
  bool _uploadingAnswerImages = false;
  bool _submittingAnswer = false;
  bool _answerMode = false;
  String? _categoryError;
  String? _listError;
  String? _detailError;
  String? _commentError;
  String? _answerError;
  int _questionTotal = 0;
  int _commentTotal = 0;

  @override
  void initState() {
    super.initState();
    _api = AnswerlyApi(baseUrl: AppConfig.apiBaseUrl);
    _loadInitialData(initialQuestionId: widget.initialQuestionId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData({
    bool forceRefreshCategories = false,
    int? initialQuestionId,
  }) async {
    await _loadCategories(forceRefresh: forceRefreshCategories);
    await _loadQuestions(initialQuestionId: initialQuestionId);
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });

    try {
      final categories = await _api.fetchCategories(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
        if (_selectedCategoryId != null &&
            !categories.any((item) => item.id == _selectedCategoryId)) {
          _selectedCategoryId = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categoryError = error.message ?? '获取科目列表失败';
        _categories = const [];
        _selectedCategoryId = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _categoryError = '网络异常，请稍后重试';
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

  Future<void> _loadQuestions({int? initialQuestionId}) async {
    setState(() {
      _loadingQuestions = true;
      _listError = null;
    });

    try {
      final result = await _api.fetchQuestionPage(
        categoryId: _selectedCategoryId,
        keyword: _searchController.text.trim(),
      );
      if (!mounted) {
        return;
      }

      final questions = result.records;
      final preferredId = initialQuestionId ?? _selectedQuestionId;
      final selectedId = questions.any((item) => item.id == preferredId)
          ? preferredId
          : questions.isNotEmpty
          ? questions.first.id
          : null;

      setState(() {
        _questions = questions;
        _questionTotal = result.total;
        _selectedQuestionId = selectedId;
        _answerError = null;
        if (selectedId == null) {
          _selectedQuestion = null;
          _comments = const [];
          _commentTotal = 0;
          _detailError = null;
          _commentError = null;
        }
      });

      if (selectedId != null) {
        await _loadSelection(selectedId);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _listError = error.message ?? '获取题目列表失败';
        _questions = const [];
        _selectedQuestion = null;
        _comments = const [];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _listError = '网络异常，请稍后重试';
        _questions = const [];
        _selectedQuestion = null;
        _comments = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingQuestions = false;
        });
      }
    }
  }

  String _categoryNameOf(int categoryId) {
    for (final item in _categories) {
      if (item.id == categoryId) {
        return item.name;
      }
    }
    return '科目 $categoryId';
  }

  Future<void> _loadSelection(int questionId) async {
    setState(() {
      _selectedQuestionId = questionId;
      _loadingDetail = true;
      _loadingComments = true;
      _detailError = null;
      _commentError = null;
      _answerError = null;
      _selectedQuestion = null;
      _comments = const [];
      _commentTotal = 0;
    });

    try {
      final futures = await Future.wait([
        _api.fetchQuestionDetail(questionId),
        _api.fetchCommentPage(questionId: questionId),
      ]);
      if (!mounted) {
        return;
      }

      final detail = futures[0] as QuestionDetail;
      final comments = futures[1] as CommentPageData;
      setState(() {
        _selectedQuestion = detail;
        _comments = comments.records;
        _commentTotal = comments.total;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailError = error.message ?? '获取题目详情失败';
        _commentError = error.message ?? '获取解答列表失败';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _detailError = '网络异常，请稍后重试';
        _commentError = '网络异常，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDetail = false;
          _loadingComments = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAnswerImages() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      setState(() {
        _answerError = '当前未登录，请先登录后上传图片';
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
      _uploadingAnswerImages = true;
      _answerError = null;
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
        _answerError = error.message ?? '图片上传失败';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _answerError = '网络异常，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAnswerImages = false;
        });
      }
    }
  }

  Future<void> _submitAnswer() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    final questionId = _selectedQuestionId;
    final content = _answerController.text.trim();
    if (username == null || token == null) {
      setState(() {
        _answerError = '当前未登录，请先登录后发布解答';
      });
      return;
    }
    if (questionId == null) {
      setState(() {
        _answerError = '请先选择题目';
      });
      return;
    }
    if (content.isEmpty) {
      setState(() {
        _answerError = '请输入解答内容';
      });
      return;
    }
    if (content.length < 5) {
      setState(() {
        _answerError = '解答内容至少 5 个字符';
      });
      return;
    }

    setState(() {
      _submittingAnswer = true;
      _answerError = null;
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
          _answerError = '登录态已失效，请重新登录';
        });
        return;
      }

      await _api.createComment(
        username: username,
        token: token,
        request: CreateCommentRequest(
          questionId: questionId,
          content: content,
          images: _uploadedImages.map((item) => item.serverPath).join(','),
        ),
      );
      if (!mounted) {
        return;
      }
      _answerController.clear();
      setState(() {
        _uploadedImages.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('解答发布成功')));
      await _loadSelection(questionId);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      setState(() {
        _answerError = error.message ?? '发布解答失败';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _answerError = '网络异常，请稍后重试';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submittingAnswer = false;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('题目浏览'),
        actions: [
          IconButton(
            onPressed: _submittingAnswer || _uploadingAnswerImages
                ? null
                : () {
                    setState(() {
                      _answerMode = !_answerMode;
                      _answerError = null;
                    });
                  },
            icon: Icon(
              _answerMode ? Icons.list_alt_outlined : Icons.edit_note_outlined,
            ),
            tooltip: _answerMode ? '返回题目列表' : '进入新建解答',
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).pushNamed(AppRoutes.questionCreate);
              if (!mounted) {
                return;
              }
              _loadQuestions();
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '发布题目',
          ),
          IconButton(
            onPressed: _loadingCategories || _loadingQuestions
                ? null
                : () => _loadInitialData(forceRefreshCategories: true),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isThreeColumn = constraints.maxWidth >= 1200;
            final isTwoColumn = constraints.maxWidth >= 800;

            if (isThreeColumn) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _answerMode
                          ? _buildAnswerComposerPanel()
                          : _buildQuestionListPanel(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _buildQuestionDetailPanel()),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _buildCommentPanel()),
                  ],
                ),
              );
            }

            if (isTwoColumn) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _answerMode
                          ? _buildAnswerComposerPanel()
                          : _buildQuestionListPanel(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          Expanded(child: _buildQuestionDetailPanel()),
                          const SizedBox(height: 16),
                          Expanded(child: _buildCommentPanel()),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: _answerMode ? 520 : 420,
                  child: _answerMode
                      ? _buildAnswerComposerPanel()
                      : _buildQuestionListPanel(),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 360, child: _buildQuestionDetailPanel()),
                const SizedBox(height: 16),
                SizedBox(height: 420, child: _buildCommentPanel()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestionListPanel() {
    return _PanelScaffold(
      title: '题目列表',
      subtitle: '共 $_questionTotal 条',
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int?>(
                  key: ValueKey(_selectedCategoryId),
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: '科目',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部科目'),
                    ),
                    ..._categories.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: _loadingQuestions || _loadingCategories
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                          _loadQuestions();
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '搜索题目关键词',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadQuestions(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _loadingQuestions ? null : () => _loadQuestions(),
                child: const Text('搜索'),
              ),
            ],
          ),
          if (_categoryError != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _categoryError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: _buildQuestionListContent()),
        ],
      ),
    );
  }

  Widget _buildQuestionListContent() {
    if (_loadingQuestions && _questions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_listError != null) {
      return _ErrorState(message: _listError!, onRetry: () => _loadQuestions());
    }

    if (_questions.isEmpty) {
      return const _EmptyState(message: '暂无题目数据');
    }

    return ListView.separated(
      itemCount: _questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _questions[index];
        final isSelected = item.id == _selectedQuestionId;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _loadSelection(item.id),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SolvedChip(solvedFlag: item.solvedFlag),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _InfoTag(
                        icon: Icons.person_outline,
                        label: item.username,
                      ),
                      _InfoTag(
                        icon: Icons.remove_red_eye_outlined,
                        label: '${item.viewCount}',
                      ),
                      _InfoTag(
                        icon: Icons.chat_bubble_outline,
                        label: '${item.commentCount}',
                      ),
                      _InfoTag(
                        icon: Icons.thumb_up_alt_outlined,
                        label: '${item.likeCount}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnswerComposerPanel() {
    return _PanelScaffold(
      title: '新建解答',
      subtitle: _selectedQuestionId == null
          ? '请先在题目列表中选择题目'
          : '当前题目 ID $_selectedQuestionId',
      child: _buildAnswerComposerContent(),
    );
  }

  Widget _buildAnswerComposerContent() {
    final theme = Theme.of(context);
    final username = AuthSession.username;

    return ListView(
      children: [
        if (_selectedQuestion == null || username == null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _selectedQuestion == null
                  ? '请先切回题目列表并选择一个题目，再来编写解答。'
                  : '当前题目：${_selectedQuestion!.title}\n当前未登录，登录后才能发布解答。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        TextField(
          controller: _answerController,
          enabled: !_submittingAnswer,
          minLines: 10,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: '解答内容',
            hintText: '写下你的解法、推导过程、结论或补充说明',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '解答图片',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _submittingAnswer || _uploadingAnswerImages
                  ? null
                  : _pickAndUploadAnswerImages,
              icon: _uploadingAnswerImages
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined),
              label: Text(_uploadingAnswerImages ? '上传中' : '选择并上传'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _uploadedImages.isEmpty
              ? '可选。上传的图片会附加到当前解答。'
              : '已上传 ${_uploadedImages.length} 张图片。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 12),
        if (_uploadedImages.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
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
                      minWidth: 150,
                      maxWidth: 220,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.image_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            image.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _submittingAnswer || _uploadingAnswerImages
                              ? null
                              : () => _removeUploadedImage(image),
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: '移除',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        if (_answerError != null) ...[
          const SizedBox(height: 12),
          Text(_answerError!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submittingAnswer || _uploadingAnswerImages
              ? null
              : _submitAnswer,
          child: _submittingAnswer
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('发布解答'),
        ),
      ],
    );
  }

  Widget _buildQuestionDetailPanel() {
    return _PanelScaffold(
      title: '题目详情',
      subtitle: _selectedQuestion == null
          ? '未选择题目'
          : '${_categoryNameOf(_selectedQuestion!.category)} · 题目 ID ${_selectedQuestion!.id}',
      child: _buildQuestionDetailContent(),
    );
  }

  Widget _buildQuestionDetailContent() {
    if (_loadingDetail && _selectedQuestion == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detailError != null && _selectedQuestion == null) {
      return _ErrorState(
        message: _detailError!,
        onRetry: _selectedQuestionId == null
            ? null
            : () => _loadSelection(_selectedQuestionId!),
      );
    }

    final detail = _selectedQuestion;
    if (detail == null) {
      return const _EmptyState(message: '请选择左侧题目');
    }

    final images = detail.images
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    return ListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                detail.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _SolvedChip(solvedFlag: detail.solvedFlag),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _InfoTag(
              icon: Icons.book_outlined,
              label: _categoryNameOf(detail.category),
            ),
            _InfoTag(icon: Icons.person_outline, label: detail.username),
            _InfoTag(
              icon: Icons.remove_red_eye_outlined,
              label: '${detail.viewCount} 浏览',
            ),
            _InfoTag(
              icon: Icons.chat_bubble_outline,
              label: '${detail.commentCount} 解答',
            ),
            _InfoTag(
              icon: Icons.star_border,
              label: '${detail.collectCount} 收藏',
            ),
            _InfoTag(
              icon: Icons.thumb_up_alt_outlined,
              label: '${detail.likeCount} 点赞',
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          detail.content.isEmpty ? '暂无题目描述' : detail.content,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('图片', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final image in images)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HtmlImageView(
                      imageUrl: AppConfig.resolveMediaUrl(image),
                      fit: BoxFit.cover,
                      height: 220,
                      errorText: '图片加载失败',
                    ),
                    const SizedBox(height: 6),
                    SelectableText(AppConfig.resolveMediaUrl(image)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        _MetaBlock(label: '创建时间', value: _formatDateTime(detail.createTime)),
        _MetaBlock(label: '更新时间', value: _formatDateTime(detail.updateTime)),
        _MetaBlock(label: '点赞状态', value: detail.likeStatus),
        _MetaBlock(label: '收藏状态', value: detail.collectStatus),
      ],
    );
  }

  Widget _buildCommentPanel() {
    return _PanelScaffold(
      title: '解答列表',
      subtitle: '共 $_commentTotal 条',
      child: _buildCommentContent(),
    );
  }

  Widget _buildCommentContent() {
    if (_loadingComments && _comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_commentError != null && _comments.isEmpty) {
      return _ErrorState(
        message: _commentError!,
        onRetry: _selectedQuestionId == null
            ? null
            : () => _loadSelection(_selectedQuestionId!),
      );
    }

    if (_selectedQuestionId == null) {
      return const _EmptyState(message: '请选择题目后查看解答');
    }

    if (_comments.isEmpty) {
      return const _EmptyState(message: '该题目暂无解答');
    }

    return ListView.separated(
      itemCount: _comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _CommentCard(comment: _comments[index]);
      },
    );
  }
}

class _PanelScaffold extends StatelessWidget {
  const _PanelScaffold({
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final CommentItem comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: comment.avatar.isEmpty
                      ? null
                      : NetworkImage(AppConfig.resolveMediaUrl(comment.avatar)),
                  child: comment.avatar.isEmpty
                      ? Text(comment.username.characters.first)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    comment.username,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (comment.userType.isNotEmpty)
                  _Badge(label: comment.userType),
              ],
            ),
            if (comment.commentTo != null && comment.commentTo!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('回复 ${comment.commentTo}', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            Text(
              comment.content.isEmpty ? '暂无内容' : comment.content,
              style: theme.textTheme.bodyMedium,
            ),
            if (comment.images.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: comment.images
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .map(
                      (image) => HtmlImageView(
                        imageUrl: AppConfig.resolveMediaUrl(image),
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(12),
                        errorText: '加载失败',
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _InfoTag(
                  icon: Icons.thumb_up_alt_outlined,
                  label: '${comment.likeCount}',
                ),
                _InfoTag(
                  icon: Icons.verified_outlined,
                  label: '${comment.useful} 有用',
                ),
                _InfoTag(
                  icon: Icons.schedule,
                  label: _formatDateTime(comment.createTime),
                ),
              ],
            ),
            if (comment.childComments.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '子回复 ${comment.childComments.length}',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              for (final child in comment.childComments)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${child.username}: ${child.content}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SolvedChip extends StatelessWidget {
  const _SolvedChip({required this.solvedFlag});

  final int solvedFlag;

  @override
  Widget build(BuildContext context) {
    final isSolved = solvedFlag == 1;
    return Chip(
      label: Text(isSolved ? '已解决' : '待解答'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _UploadedImage {
  const _UploadedImage({required this.displayName, required this.serverPath});

  final String displayName;
  final String serverPath;
}

String _formatDateTime(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return '-';
  }

  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    return text;
  }

  final local = parsed.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
