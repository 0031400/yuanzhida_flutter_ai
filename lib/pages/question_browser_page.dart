import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
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
  bool _likingQuestion = false;
  bool _collectingQuestion = false;
  bool _deletingQuestion = false;
  bool _markingQuestionSolved = false;
  final Set<int> _likingCommentIds = <int>{};
  final Set<int> _deletingCommentIds = <int>{};
  bool _answerMode = false;
  CommentItem? _replyTargetComment;
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
    return '未知科目';
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
      _replyTargetComment = null;
    });

    final cachedComments = await _api.readCachedCommentPage(
      questionId: questionId,
    );
    if (mounted &&
        cachedComments != null &&
        _selectedQuestionId == questionId) {
      setState(() {
        _comments = cachedComments.records;
        _commentTotal = cachedComments.total;
      });
    }

    try {
      final futures = await Future.wait([
        _api.fetchQuestionDetail(questionId),
        _api.fetchCommentPage(questionId: questionId, forceRefresh: true),
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
    final replyTarget = _replyTargetComment;
    if (username == null || token == null) {
      setState(() {
        _answerError = replyTarget == null
            ? '当前未登录，请先登录后发布解答'
            : '当前未登录，请先登录后发布回复';
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
        _answerError = replyTarget == null ? '请输入解答内容' : '请输入回复内容';
      });
      return;
    }
    if (content.length < 5) {
      setState(() {
        _answerError = replyTarget == null ? '解答内容至少 5 个字符' : '回复内容至少 5 个字符';
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
          parentCommentId: replyTarget?.id ?? 0,
          topCommentId: replyTarget == null
              ? 0
              : (replyTarget.topCommentId == 0
                    ? replyTarget.id
                    : replyTarget.topCommentId),
          images: _uploadedImages.map((item) => item.serverPath).join(','),
        ),
      );
      if (!mounted) {
        return;
      }
      _answerController.clear();
      setState(() {
        _uploadedImages.clear();
        _replyTargetComment = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(replyTarget == null ? '解答发布成功' : '回复发布成功')),
      );
      await _loadSelection(questionId);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      setState(() {
        _answerError =
            error.message ?? (replyTarget == null ? '发布解答失败' : '发布回复失败');
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

  void _startReplyToComment(CommentItem comment) {
    setState(() {
      _answerMode = true;
      _answerError = null;
      _replyTargetComment = comment;
    });
  }

  void _cancelReplyTarget() {
    setState(() {
      _replyTargetComment = null;
      _answerError = null;
    });
  }

  Future<bool> _ensureLoggedInForQuestionAction() async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (username == null || token == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先登录后再操作')));
      }
      return false;
    }

    try {
      final loginValid = await _api.checkLogin(
        username: username,
        token: token,
      );
      if (loginValid) {
        return true;
      }
      await AuthSession.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录态已失效，请重新登录')));
      }
      return false;
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? '登录校验失败，请稍后重试')),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
      }
      return false;
    }
  }

  Future<void> _likeQuestion() async {
    final detail = _selectedQuestion;
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (detail == null || username == null || token == null) {
      await _ensureLoggedInForQuestionAction();
      return;
    }
    if (!await _ensureLoggedInForQuestionAction()) {
      return;
    }

    setState(() {
      _likingQuestion = true;
      _detailError = null;
    });

    try {
      await _api.likeQuestion(
        username: username,
        token: token,
        request: QuestionEngagementRequest(
          id: detail.id,
          entityUserId: detail.userId,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isLiked(detail.likeStatus) ? '已取消点赞' : '点赞成功')),
      );
      await _loadSelection(detail.id);
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '点赞操作失败')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _likingQuestion = false;
        });
      }
    }
  }

  Future<void> _collectQuestion() async {
    final detail = _selectedQuestion;
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (detail == null || username == null || token == null) {
      await _ensureLoggedInForQuestionAction();
      return;
    }
    if (!await _ensureLoggedInForQuestionAction()) {
      return;
    }

    setState(() {
      _collectingQuestion = true;
      _detailError = null;
    });

    try {
      await _api.collectQuestion(
        username: username,
        token: token,
        request: QuestionEngagementRequest(
          id: detail.id,
          entityUserId: detail.userId,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isCollected(detail.collectStatus) ? '已取消收藏' : '收藏成功'),
        ),
      );
      await _loadSelection(detail.id);
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '收藏操作失败')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _collectingQuestion = false;
        });
      }
    }
  }

  Future<void> _likeComment(CommentItem comment) async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    final questionId = _selectedQuestionId;
    if (username == null || token == null) {
      await _ensureLoggedInForQuestionAction();
      return;
    }
    if (questionId == null) {
      return;
    }
    if (!await _ensureLoggedInForQuestionAction()) {
      return;
    }

    setState(() {
      _likingCommentIds.add(comment.id);
      _commentError = null;
    });

    try {
      await _api.likeComment(
        username: username,
        token: token,
        request: QuestionEngagementRequest(
          id: comment.id,
          entityUserId: _selectedQuestion?.userId ?? 0,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLiked(comment.likeStatus) ? '已取消评论点赞' : '评论点赞成功'),
        ),
      );
      await _loadSelection(questionId);
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '评论点赞失败')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _likingCommentIds.remove(comment.id);
        });
      }
    }
  }

  Future<void> _deleteQuestion() async {
    final detail = _selectedQuestion;
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (detail == null || username == null || token == null) {
      await _ensureLoggedInForQuestionAction();
      return;
    }
    if (username != detail.username) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('只有题目作者可以删除题目')));
      }
      return;
    }
    if (detail.commentCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('只有评论数为 0 的题目才可以删除')));
      }
      return;
    }
    if (!await _ensureLoggedInForQuestionAction()) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除题目'),
          content: Text('确认删除“${detail.title}”吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _deletingQuestion = true;
      _detailError = null;
    });

    try {
      await _api.deleteQuestion(
        username: username,
        token: token,
        id: detail.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('题目已删除')));
      setState(() {
        _selectedQuestion = null;
        _selectedQuestionId = null;
        _comments = const [];
        _commentTotal = 0;
      });
      await _loadQuestions();
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '删除题目失败')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _deletingQuestion = false;
        });
      }
    }
  }

  Future<void> _markQuestionSolved() async {
    final detail = _selectedQuestion;
    final username = AuthSession.username;
    final token = AuthSession.token;
    if (detail == null || username == null || token == null) {
      await _ensureLoggedInForQuestionAction();
      return;
    }
    if (username != detail.username) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('只有题目作者可以标记已解答')));
      }
      return;
    }
    if (detail.solvedFlag == 1) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该题目已标记为已解答')));
      }
      return;
    }
    if (!await _ensureLoggedInForQuestionAction()) {
      return;
    }

    setState(() {
      _markingQuestionSolved = true;
      _detailError = null;
    });

    try {
      await _api.updateQuestionSolved(
        username: username,
        token: token,
        request: UpdateQuestionSolvedRequest(id: detail.id, solvedFlag: 1),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('题目已标记为已解答')));
      await _loadSelection(detail.id);
      await _loadQuestions(initialQuestionId: detail.id);
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? '标记题目已解答失败')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _markingQuestionSolved = false;
        });
      }
    }
  }

  Future<void> _deleteComment(CommentItem comment) async {
    final username = AuthSession.username;
    final token = AuthSession.token;
    final questionId = _selectedQuestionId;
    if (username == null || token == null) {
      await _ensureLoggedInForQuestionAction();
      return;
    }
    if (questionId == null) {
      return;
    }
    if (username != comment.username) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('只有评论作者可以删除评论')));
      }
      return;
    }
    if (comment.childComments.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('只有没有子评论的评论才可以删除')));
      }
      return;
    }
    if (!await _ensureLoggedInForQuestionAction()) {
      return;
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除评论'),
          content: const Text('确认删除这条评论吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _deletingCommentIds.add(comment.id);
      _commentError = null;
    });

    try {
      await _api.deleteComment(
        username: username,
        token: token,
        id: comment.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论已删除')));
      await _loadSelection(questionId);
    } on ApiException catch (error) {
      if (error.code == 'A000204') {
        await AuthSession.clear();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message ?? '删除评论失败')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('网络异常，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _deletingCommentIds.remove(comment.id);
        });
      }
    }
  }

  Future<void> _showImageViewer(String imageUrl) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => _FullscreenImageViewer(imageUrl: imageUrl),
    );
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
                      if (!_answerMode) {
                        _replyTargetComment = null;
                      }
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
      title: _replyTargetComment == null ? '新建解答' : '新建回复',
      subtitle: _selectedQuestionId == null
          ? '请先在题目列表中选择题目'
          : _replyTargetComment == null
          ? '当前题目 ID $_selectedQuestionId'
          : '正在回复 ${_replyTargetComment!.username}',
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
                  : '当前题目：${_selectedQuestion!.title}\n当前未登录，登录后才能发布${_replyTargetComment == null ? '解答' : '回复'}。',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (_replyTargetComment != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '正在回应 ${_replyTargetComment!.username} 的解答',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _replyTargetComment!.content.isEmpty
                            ? '暂无内容'
                            : _replyTargetComment!.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _submittingAnswer ? null : _cancelReplyTarget,
                  child: const Text('取消回复'),
                ),
              ],
            ),
          ),
        ],
        TextField(
          controller: _answerController,
          enabled: !_submittingAnswer,
          minLines: 10,
          maxLines: 14,
          decoration: InputDecoration(
            labelText: _replyTargetComment == null ? '解答内容' : '回复内容',
            hintText: _replyTargetComment == null
                ? '写下你的解法、推导过程、结论或补充说明'
                : '写下你要补充、追问或回应的内容',
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                _replyTargetComment == null ? '解答图片' : '回复图片',
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
              ? '可选。上传的图片会附加到当前${_replyTargetComment == null ? '解答' : '回复'}。'
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
              : Text(_replyTargetComment == null ? '发布解答' : '发布回复'),
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
    final canDeleteQuestion =
        AuthSession.username == detail.username && detail.commentCount == 0;
    final canMarkSolved =
        AuthSession.username == detail.username && detail.solvedFlag != 1;

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
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed:
                  _likingQuestion ||
                      _collectingQuestion ||
                      _deletingQuestion ||
                      _markingQuestionSolved
                  ? null
                  : _likeQuestion,
              icon: _likingQuestion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isLiked(detail.likeStatus)
                          ? Icons.thumb_up_alt
                          : Icons.thumb_up_alt_outlined,
                    ),
              label: Text(_isLiked(detail.likeStatus) ? '取消点赞' : '点赞题目'),
            ),
            FilledButton.tonalIcon(
              onPressed:
                  _likingQuestion ||
                      _collectingQuestion ||
                      _deletingQuestion ||
                      _markingQuestionSolved
                  ? null
                  : _collectQuestion,
              icon: _collectingQuestion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isCollected(detail.collectStatus)
                          ? Icons.star
                          : Icons.star_border,
                    ),
              label: Text(_isCollected(detail.collectStatus) ? '取消收藏' : '收藏题目'),
            ),
            if (canMarkSolved)
              FilledButton.tonalIcon(
                onPressed:
                    _likingQuestion ||
                        _collectingQuestion ||
                        _deletingQuestion ||
                        _markingQuestionSolved
                    ? null
                    : _markQuestionSolved,
                icon: _markingQuestionSolved
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('标记已解答'),
              ),
            if (canDeleteQuestion)
              FilledButton.icon(
                onPressed:
                    _likingQuestion ||
                        _collectingQuestion ||
                        _deletingQuestion ||
                        _markingQuestionSolved
                    ? null
                    : _deleteQuestion,
                icon: _deletingQuestion
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('删除题目'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: images
                .map(
                  (image) => _SquareImageThumbnail(
                    imageUrl: AppConfig.resolveMediaUrl(image),
                    size: 160,
                    onTap: () =>
                        _showImageViewer(AppConfig.resolveMediaUrl(image)),
                  ),
                )
                .toList(),
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
        final comment = _comments[index];
        return _CommentCard(
          comment: comment,
          showReplyAction: _answerMode,
          isTopLevel: true,
          isLikingComment: (commentId) => _likingCommentIds.contains(commentId),
          isDeletingComment: (commentId) =>
              _deletingCommentIds.contains(commentId),
          onLikeComment: _likeComment,
          onReplyComment: _startReplyToComment,
          onDeleteComment: _deleteComment,
          onPreviewImage: _showImageViewer,
        );
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

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    required this.comment,
    required this.showReplyAction,
    this.isTopLevel = false,
    required this.isLikingComment,
    required this.isDeletingComment,
    required this.onLikeComment,
    required this.onReplyComment,
    required this.onDeleteComment,
    required this.onPreviewImage,
  });

  final CommentItem comment;
  final bool showReplyAction;
  final bool isTopLevel;
  final bool Function(int commentId) isLikingComment;
  final bool Function(int commentId) isDeletingComment;
  final ValueChanged<CommentItem> onLikeComment;
  final ValueChanged<CommentItem> onReplyComment;
  final ValueChanged<CommentItem> onDeleteComment;
  final ValueChanged<String> onPreviewImage;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  static const int _initialVisibleChildCount = 2;
  static const int _childIncrementCount = 5;

  int _visibleChildCount = _initialVisibleChildCount;

  @override
  void didUpdateWidget(covariant _CommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _visibleChildCount = _initialVisibleChildCount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    final theme = Theme.of(context);
    final liking = widget.isLikingComment(comment.id);
    final deleting = widget.isDeletingComment(comment.id);
    final visibleChildren = comment.childComments
        .take(_visibleChildCount)
        .toList();
    final canExpandChildren = _visibleChildCount < comment.childComments.length;
    final canCollapseChildren =
        comment.childComments.length > _initialVisibleChildCount &&
        _visibleChildCount > _initialVisibleChildCount;

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
                if (AuthSession.username == comment.username &&
                    comment.childComments.isEmpty)
                  TextButton.icon(
                    onPressed: deleting
                        ? null
                        : () => widget.onDeleteComment(comment),
                    icon: deleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
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
                      (image) => _SquareImageThumbnail(
                        imageUrl: AppConfig.resolveMediaUrl(image),
                        size: 120,
                        onTap: () => widget.onPreviewImage(
                          AppConfig.resolveMediaUrl(image),
                        ),
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
                FilledButton.tonalIcon(
                  onPressed: liking || deleting
                      ? null
                      : () => widget.onLikeComment(comment),
                  icon: liking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isLiked(comment.likeStatus)
                              ? Icons.thumb_up_alt
                              : Icons.thumb_up_alt_outlined,
                          size: 18,
                        ),
                  label: Text(
                    _isLiked(comment.likeStatus)
                        ? '已点赞 ${comment.likeCount}'
                        : '点赞 ${comment.likeCount}',
                  ),
                ),
                if (widget.showReplyAction && widget.isTopLevel)
                  FilledButton.tonalIcon(
                    onPressed: deleting
                        ? null
                        : () => widget.onReplyComment(comment),
                    icon: const Icon(Icons.reply_outlined, size: 18),
                    label: const Text('回应此解答'),
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
              for (final child in visibleChildren) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CommentCard(
                    comment: child,
                    showReplyAction: widget.showReplyAction,
                    isTopLevel: false,
                    isLikingComment: widget.isLikingComment,
                    isDeletingComment: widget.isDeletingComment,
                    onLikeComment: widget.onLikeComment,
                    onReplyComment: widget.onReplyComment,
                    onDeleteComment: widget.onDeleteComment,
                    onPreviewImage: widget.onPreviewImage,
                  ),
                ),
              ],
              if (canExpandChildren || canCollapseChildren)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (canExpandChildren)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _visibleChildCount += _childIncrementCount;
                          });
                        },
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          '展开更多 (${comment.childComments.length - visibleChildren.length})',
                        ),
                      ),
                    if (canCollapseChildren)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _visibleChildCount = _initialVisibleChildCount;
                          });
                        },
                        icon: const Icon(Icons.expand_less),
                        label: const Text('收起'),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SquareImageThumbnail extends StatelessWidget {
  const _SquareImageThumbnail({
    required this.imageUrl,
    required this.size,
    required this.onTap,
  });

  final String imageUrl;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: HtmlImageView(
                    imageUrl: imageUrl,
                    width: size - 20,
                    height: size - 20,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(12),
                    errorText: '加载失败',
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  double _scale = 1;
  double _gestureScaleStart = 1;

  @override
  void dispose() {
    super.dispose();
  }

  void _zoom(double factor) {
    setState(() {
      _scale = (_scale * factor).clamp(0.5, 6.0);
    });
  }

  void _reset() {
    setState(() {
      _scale = 1;
    });
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _gestureScaleStart = _scale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_gestureScaleStart * details.scale).clamp(0.5, 6.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (event.scrollDelta.dy < 0) {
                          _zoom(1.1);
                        } else if (event.scrollDelta.dy > 0) {
                          _zoom(0.9);
                        }
                      }
                    },
                    child: GestureDetector(
                      onScaleStart: _handleScaleStart,
                      onScaleUpdate: _handleScaleUpdate,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: HtmlImageView(
                            imageUrl: widget.imageUrl,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            fit: BoxFit.contain,
                            scale: _scale,
                            errorText: '图片加载失败',
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ViewerButton(
                    icon: Icons.remove,
                    tooltip: '缩小',
                    onPressed: () => _zoom(0.9),
                  ),
                  const SizedBox(width: 8),
                  _ViewerButton(
                    icon: Icons.refresh,
                    tooltip: '重置',
                    onPressed: _reset,
                  ),
                  const SizedBox(width: 8),
                  _ViewerButton(
                    icon: Icons.add,
                    tooltip: '放大',
                    onPressed: () => _zoom(1.1),
                  ),
                  const SizedBox(width: 8),
                  _ViewerButton(
                    icon: Icons.close,
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.14),
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
        ),
        child: Icon(icon),
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

bool _isLiked(String status) {
  final normalized = status.trim();
  return normalized.isNotEmpty &&
      normalized != '未登录' &&
      !normalized.contains('未点赞');
}

bool _isCollected(String status) {
  final normalized = status.trim();
  return normalized.isNotEmpty &&
      normalized != '未登录' &&
      !normalized.contains('未收藏');
}
