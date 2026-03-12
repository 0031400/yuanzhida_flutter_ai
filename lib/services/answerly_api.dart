import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'http_client_stub.dart'
    if (dart.library.js_interop) 'http_client_web.dart';

class QuestionPageData {
  const QuestionPageData({
    required this.records,
    required this.total,
    required this.current,
    required this.size,
  });

  final List<QuestionSummary> records;
  final int total;
  final int current;
  final int size;
}

class CategorySummary {
  const CategorySummary({
    required this.id,
    required this.name,
    required this.image,
    required this.sort,
  });

  factory CategorySummary.fromJson(Map<String, dynamic> json) {
    return CategorySummary(
      id: _readInt(json['id']),
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      sort: _readInt(json['sort']),
    );
  }

  final int id;
  final String name;
  final String image;
  final int sort;
}

class QuestionSummary {
  const QuestionSummary({
    required this.id,
    required this.title,
    required this.content,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.collectCount,
    required this.solvedFlag,
    required this.userId,
    required this.username,
    required this.avatar,
    required this.createTime,
  });

  factory QuestionSummary.fromJson(Map<String, dynamic> json) {
    return QuestionSummary(
      id: _readInt(json['id']),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      viewCount: _readInt(json['viewCount']),
      likeCount: _readInt(json['likeCount']),
      commentCount: _readInt(json['commentCount']),
      collectCount: _readInt(json['collectCount']),
      solvedFlag: _readInt(json['solvedFlag']),
      userId: _readInt(json['userId']),
      username: json['username']?.toString() ?? '未知用户',
      avatar: json['avatar']?.toString() ?? '',
      createTime: json['createTime']?.toString() ?? '',
    );
  }

  final int id;
  final String title;
  final String content;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int collectCount;
  final int solvedFlag;
  final int userId;
  final String username;
  final String avatar;
  final String createTime;
}

class QuestionDetail {
  const QuestionDetail({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.images,
    required this.userId,
    required this.username,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.collectCount,
    required this.likeStatus,
    required this.collectStatus,
    required this.solvedFlag,
    required this.createTime,
    required this.updateTime,
  });

  factory QuestionDetail.fromJson(Map<String, dynamic> json) {
    return QuestionDetail(
      id: _readInt(json['id']),
      category: _readInt(json['category']),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images: json['images']?.toString() ?? '',
      userId: _readInt(json['userId']),
      username: json['username']?.toString() ?? '未知用户',
      viewCount: _readInt(json['viewCount']),
      likeCount: _readInt(json['likeCount']),
      commentCount: _readInt(json['commentCount']),
      collectCount: _readInt(json['collectCount']),
      likeStatus: json['likeStatus']?.toString() ?? '',
      collectStatus: json['collectStatus']?.toString() ?? '',
      solvedFlag: _readInt(json['solvedFlag']),
      createTime: json['createTime']?.toString() ?? '',
      updateTime: json['updateTime']?.toString() ?? '',
    );
  }

  final int id;
  final int category;
  final String title;
  final String content;
  final String images;
  final int userId;
  final String username;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int collectCount;
  final String likeStatus;
  final String collectStatus;
  final int solvedFlag;
  final String createTime;
  final String updateTime;
}

class CommentPageData {
  const CommentPageData({
    required this.records,
    required this.total,
    required this.current,
    required this.size,
  });

  final List<CommentItem> records;
  final int total;
  final int current;
  final int size;
}

class CommentItem {
  const CommentItem({
    required this.id,
    required this.content,
    required this.parentCommentId,
    required this.topCommentId,
    required this.images,
    required this.username,
    required this.userType,
    required this.avatar,
    required this.commentTo,
    required this.likeCount,
    required this.likeStatus,
    required this.useful,
    required this.createTime,
    required this.childComments,
    required this.questionId,
  });

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['childComments'];
    final childComments = rawChildren is List
        ? rawChildren
              .map(
                (item) => CommentItem.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : const <CommentItem>[];

    return CommentItem(
      id: _readInt(json['id']),
      content: json['content']?.toString() ?? '',
      parentCommentId: _readInt(json['parentCommentId']),
      topCommentId: _readInt(json['topCommentId']),
      images: json['images']?.toString() ?? '',
      username: json['username']?.toString() ?? '匿名用户',
      userType: json['usertype']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      commentTo: json['commentTo']?.toString(),
      likeCount: _readInt(json['likeCount']),
      likeStatus: json['likeStatus']?.toString() ?? '',
      useful: _readInt(json['useful']),
      createTime: json['createTime']?.toString() ?? '',
      childComments: childComments,
      questionId: _readInt(json['questionId']),
    );
  }

  final int id;
  final String content;
  final int parentCommentId;
  final int topCommentId;
  final String images;
  final String username;
  final String userType;
  final String avatar;
  final String? commentTo;
  final int likeCount;
  final String likeStatus;
  final int useful;
  final String createTime;
  final List<CommentItem> childComments;
  final int questionId;
}

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final String code;
  final String? message;

  @override
  String toString() => 'ApiException(code: $code, message: $message)';
}

class AnswerlyApi {
  AnswerlyApi({required this.baseUrl});

  static List<CategorySummary>? _categoryCache;

  final String baseUrl;
  final http.Client _client = createHttpClient();

  Future<Uint8List> fetchCaptcha() async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/user/captcha');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode.toString(),
        'Captcha request failed',
      );
    }

    return response.bodyBytes;
  }

  Future<void> sendRegisterCode({required String mail}) async {
    final uri = Uri.parse(
      '$baseUrl/api/answerly/v1/user/send-code',
    ).replace(queryParameters: {'mail': mail});
    final response = await _client.get(uri);

    _ensureSuccessStatus(
      response,
      fallbackMessage: 'Send register code failed',
    );
    _ensureSuccessBody(response.body);
  }

  Future<void> register({
    required String username,
    required String password,
    required String mail,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/user');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'mail': mail,
        'code': code,
      }),
    );

    _ensureSuccessStatus(response, fallbackMessage: 'Register request failed');
    _ensureSuccessBody(response.body);
  }

  Future<QuestionPageData> fetchQuestionPage({
    int current = 1,
    int size = 20,
    int? categoryId,
    String? keyword,
  }) async {
    final queryParameters = <String, String>{
      'current': '$current',
      'size': '$size',
      'solvedFlag': '2',
    };
    if (categoryId != null && categoryId > 0) {
      queryParameters['categoryId'] = '$categoryId';
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      queryParameters['keyword'] = keyword.trim();
    }

    final uri = Uri.parse(
      '$baseUrl/api/answerly/v1/question/page',
    ).replace(queryParameters: queryParameters);
    final response = await _client.get(uri);

    _ensureSuccessStatus(
      response,
      fallbackMessage: 'Question page request failed',
    );
    final body = _ensureSuccessBody(response.body);
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final rawRecords = data['records'];
    final records = rawRecords is List
        ? rawRecords
              .map(
                (item) => QuestionSummary.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : const <QuestionSummary>[];

    return QuestionPageData(
      records: records,
      total: _readInt(data['total']),
      current: _readInt(data['current']),
      size: _readInt(data['size']),
    );
  }

  Future<List<CategorySummary>> fetchCategories({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _categoryCache != null) {
      return _categoryCache!;
    }

    final uri = Uri.parse('$baseUrl/api/answerly/v1/category');
    final response = await _client.get(uri);

    _ensureSuccessStatus(response, fallbackMessage: 'Category request failed');
    final body = _ensureSuccessBody(response.body);
    final rawData = body['data'];
    final categories = rawData is List
        ? rawData
              .map(
                (item) => CategorySummary.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : <CategorySummary>[];
    categories.sort((a, b) {
      final sortCompare = a.sort.compareTo(b.sort);
      if (sortCompare != 0) {
        return sortCompare;
      }
      return a.id.compareTo(b.id);
    });
    _categoryCache = List<CategorySummary>.unmodifiable(categories);
    return _categoryCache!;
  }

  Future<QuestionDetail> fetchQuestionDetail(int id) async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/question/$id');
    final response = await _client.get(uri);

    _ensureSuccessStatus(
      response,
      fallbackMessage: 'Question detail request failed',
    );
    final body = _ensureSuccessBody(response.body);
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return QuestionDetail.fromJson(data);
  }

  Future<CommentPageData> fetchCommentPage({
    required int questionId,
    int current = 1,
    int size = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/comment/page').replace(
      queryParameters: {
        'current': '$current',
        'size': '$size',
        'id': '$questionId',
      },
    );
    final response = await _client.get(uri);

    _ensureSuccessStatus(
      response,
      fallbackMessage: 'Comment page request failed',
    );
    final body = _ensureSuccessBody(response.body);
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final rawRecords = data['records'];
    final records = rawRecords is List
        ? rawRecords
              .map(
                (item) => CommentItem.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList()
        : const <CommentItem>[];

    return CommentPageData(
      records: records,
      total: _readInt(data['total']),
      current: _readInt(data['current']),
      size: _readInt(data['size']),
    );
  }

  Future<String> login({
    required String username,
    required String password,
    required String code,
  }) async {
    final uri = Uri.parse('$baseUrl/api/answerly/v1/user/login');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final response = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'code': code,
      }),
    );

    _ensureSuccessStatus(response, fallbackMessage: 'Login request failed');

    final body = _ensureSuccessBody(response.body);

    final data = body['data'] as Map<String, dynamic>?;
    final token = data?['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('A000000', 'Token missing in response');
    }

    return token;
  }

  void _ensureSuccessStatus(
    http.Response response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode.toString(), fallbackMessage);
    }
  }

  Map<String, dynamic> _ensureSuccessBody(String bodyText) {
    final body = jsonDecode(bodyText) as Map<String, dynamic>;
    final codeValue = body['code']?.toString() ?? 'unknown';
    if (codeValue != '0') {
      throw ApiException(codeValue, body['message']?.toString());
    }
    return body;
  }
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
