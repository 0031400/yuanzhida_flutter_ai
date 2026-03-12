# Answerly API 文档（按当前代码实现）

## 1. 基础约定

- 基础路径：`/api/answerly/v1`
- 统一返回结构（除验证码图片接口）：

```json
{
  "code": "0",
  "message": null,
  "data": {}
}
```

- 失败返回结构：

```json
{
  "code": "A000204",
  "message": "用户未登录",
  "data": null
}
```

- 登录态接口请求头（除公开接口外都需要）：

```http
username: alice
token: 8d7d55a3-7d12-4a99-b445-5608d6a7a111
```

- 分页参数（继承 MyBatis-Plus `Page`）：常用 `current`、`size`

## 2. 错误码（常见）

- `A000204` 用户未登录
- `A000205` 用户登录验证码错误
- `A000201` 用户名不存在
- `A000202` 密码错误
- `A000104` 验证码错误
- `A000101` 用户名已存在
- `A00105` 邮箱已被注册
- `A000302` 用户信息更新失败
- `C000101` 问题不存在
- `C000102` 问题操作权限错误
- `C000103` 评论不存在
- `C000104` 评论操作权限错误
- `C000105` 主题操作权限错误
- `B000101` 邮件发送错误
- `B000102` 图片上传错误
- `B000103` 当前系统繁忙，请稍后再试

## 3. 用户模块

### 3.1 获取用户信息
- `GET /api/answerly/v1/user/{username}`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"id":1,"studentId":"21370001","username":"alice","introduction":"hello","userType":"student","likeCount":12,"collectCount":4,"usefulCount":6,"phone":"138****8888"}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.2 获取用户信息（不脱敏）
- `GET /api/answerly/v1/actual/user/{username}`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"id":1,"studentId":"21370001","username":"alice","introduction":"hello","likeCount":12,"solvedCount":3,"phone":"13812348888"}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.3 检查用户名是否存在
- `GET /api/answerly/v1/user/has-username?username=alice`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":true}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.4 注册发送验证码
- `GET /api/answerly/v1/user/send-code?mail=alice@buaa.edu.cn`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":true}
```
- 失败示例
```json
{"code":"B000101","message":"邮件发送错误","data":null}
```

### 3.5 用户注册
- `POST /api/answerly/v1/user`
- 鉴权：不需要
- 请求体
```json
{"username":"alice","password":"123456","mail":"alice@buaa.edu.cn","code":"123456"}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"A000104","message":"验证码错误","data":null}
```

### 3.6 用户登录
- `POST /api/answerly/v1/user/login`
- 鉴权：不需要
- 前置：先调用 `GET /api/answerly/v1/user/captcha`，携带其下发的 `CaptchaOwner` Cookie
- 请求体
```json
{"username":"alice","password":"123456","code":"aB7K"}
```
- 成功示例
```json
{"code":"0","data":{"token":"8d7d55a3-7d12-4a99-b445-5608d6a7a111"}}
```
- 失败示例
```json
{"code":"A000205","message":"用户登录验证码错误","data":null}
```

### 3.7 检查登录状态
- `GET /api/answerly/v1/user/check-login?username=alice&token=xxx`
- 鉴权：需要（按当前过滤器实现）
- 成功示例
```json
{"code":"0","data":true}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.8 退出登录
- `DELETE /api/answerly/v1/user/logout?username=alice&token=xxx`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.9 更新用户信息
- `PUT /api/answerly/v1/user`
- 鉴权：需要
- 请求体
```json
{"oldUsername":"alice","newUsername":"alice2","password":"newpwd","avatar":"https://img/a.png","phone":"13812348888","introduction":"new intro"}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"A000302","message":"用户信息更新失败","data":null}
```

### 3.10 活跃度排行榜
- `GET /api/answerly/v1/user/activity/rank`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":[{"id":1,"username":"alice","activity":120,"avatar":"https://img/a.png","introduction":"hello"}]}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.11 我的活跃度
- `GET /api/answerly/v1/user/activity/score`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":120}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 3.12 找回用户名
- `GET /api/answerly/v1/user/forget-username?mail=alice@buaa.edu.cn`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":true}
```
- 失败示例
```json
{"code":"A000301","message":"用户记录不存在","data":null}
```

### 3.13 发送重置密码验证码
- `GET /api/answerly/v1/user/send-reset-password-code?mail=alice@buaa.edu.cn`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":true}
```
- 失败示例
```json
{"code":"A000301","message":"用户记录不存在","data":null}
```

### 3.14 重置密码
- `POST /api/answerly/v1/user/reset-password`
- 鉴权：不需要
- 请求体
```json
{"username":"alice","code":"654321","newPassword":"12345678"}
```
- 成功示例
```json
{"code":"0","data":true}
```
- 失败示例
```json
{"code":"A000104","message":"验证码错误","data":null}
```

### 3.15 登录验证码图片
- `GET /api/answerly/v1/user/captcha`
- 鉴权：不需要
- 成功示例：返回 `image/png` 二进制，并写入 `CaptchaOwner` Cookie（60 秒）
- 失败示例
```json
{"code":"B000102","message":"图片上传错误","data":null}
```

## 4. 题目模块

### 4.1 发布题目
- `POST /api/answerly/v1/question`
- 鉴权：需要
- 请求体
```json
{"images":"a.png,b.png","categoryId":1,"title":"微积分题求解","content":"求极限..."}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 4.2 修改题目
- `PUT /api/answerly/v1/question`
- 鉴权：需要
- 请求体
```json
{"id":101,"images":"a.png","title":"更新后的标题","content":"更新后的内容"}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000102","message":"问题操作权限错误","data":null}
```

### 4.3 删除题目
- `DELETE /api/answerly/v1/question?id=101`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000101","message":"问题不存在","data":null}
```

### 4.4 点赞题目
- `POST /api/answerly/v1/question/like`
- 鉴权：需要
- 请求体
```json
{"id":101,"entityUserId":2}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000101","message":"问题不存在","data":null}
```

### 4.5 标记题目已解决
- `POST /api/answerly/v1/question/resolved`
- 鉴权：需要
- 请求体
```json
{"id":101}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000102","message":"问题操作权限错误","data":null}
```

### 4.6 分页查询题目
- `GET /api/answerly/v1/question/page?current=1&size=10&categoryId=1&keyword=微积分&solvedFlag=2`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":{"total":100,"size":10,"current":1,"records":[{"id":101,"title":"微积分题","content":"...","viewCount":123,"likeCount":8,"commentCount":5,"collectCount":2,"solvedFlag":0,"userId":1,"username":"alice","avatar":"https://img/a.png","createTime":"2026-02-12T10:00:00"}]}}
```
- 失败示例
```json
{"code":"B000001","message":"系统执行出错","data":null}
```

### 4.7 关键词补全
- `GET /api/answerly/v1/question/suggest?keyword=微`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":["微积分","微分方程"]}
```
- 失败示例
```json
{"code":"B000001","message":"系统执行出错","data":null}
```

### 4.8 热门题目
- `GET /api/answerly/v1/question/hot/{categoryId}`
- 鉴权：需要（按当前过滤器实现）
- 成功示例
```json
{"code":"0","data":[{"id":101,"title":"热门题","content":"...","viewCount":321,"likeCount":20,"commentCount":11,"collectCount":9,"solvedFlag":0,"userId":1,"username":"alice","avatar":"https://img/a.png","createTime":"2026-02-11T09:00:00"}]}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 4.9 题目详情
- `GET /api/answerly/v1/question/{id}`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":{"id":101,"category":1,"title":"微积分题","content":"题目内容","images":"a.png","userId":1,"username":"alice","viewCount":200,"likeCount":12,"commentCount":9,"collectCount":5,"likeStatus":"未登录","collectStatus":"未登录","solvedFlag":0,"createTime":"2026-02-10T10:00:00","updateTime":"2026-02-10T12:00:00"}}
```
- 失败示例
```json
{"code":"C000101","message":"问题不存在","data":null}
```

### 4.10 我的题目分页
- `GET /api/answerly/v1/question/my/page?current=1&size=10`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"records":[{"id":101,"title":"我的题目"}],"total":12,"size":10,"current":1,"pages":2}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 4.11 收藏/取消收藏题目
- `POST /api/answerly/v1/question/collect`
- 鉴权：需要
- 请求体
```json
{"id":101,"entityUserId":2}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000101","message":"问题不存在","data":null}
```

### 4.12 我的收藏分页
- `GET /api/answerly/v1/question/collect/my/page?current=1&size=10`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"records":[{"id":101,"title":"收藏的题目"}],"total":20,"size":10,"current":1,"pages":2}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 4.13 最近浏览分页
- `GET /api/answerly/v1/question/recent/page?current=1&size=10`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"records":[{"id":101,"title":"最近浏览题目"}],"total":30,"size":10,"current":1,"pages":3}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

## 5. 评论模块

### 5.1 发布评论
- `POST /api/answerly/v1/comment`
- 鉴权：需要
- 请求体
```json
{"questionId":101,"content":"我的解法如下","parentCommentId":0,"topCommentId":0,"images":"a.png"}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000101","message":"问题不存在","data":null}
```

### 5.2 修改评论
- `PUT /api/answerly/v1/comment`
- 鉴权：需要
- 请求体
```json
{"id":2001,"content":"更新后的评论","images":"a.png,b.png"}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000104","message":"评论操作权限错误","data":null}
```

### 5.3 删除评论
- `DELETE /api/answerly/v1/comment?id=2001`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000103","message":"评论不存在","data":null}
```

### 5.4 点赞评论
- `POST /api/answerly/v1/comment/like`
- 鉴权：需要
- 请求体
```json
{"id":2001,"entityUserId":2}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000103","message":"评论不存在","data":null}
```

### 5.5 标记评论有用
- `POST /api/answerly/v1/comment/useful`
- 鉴权：需要
- 请求体
```json
{"id":2001}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000102","message":"问题操作权限错误","data":null}
```

### 5.6 分页查询某题评论
- `GET /api/answerly/v1/comment/page?current=1&size=10&id=101`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":{"records":[{"id":2001,"content":"答案","parentCommentId":0,"topCommentId":0,"images":"","username":"alice","usertype":"student","avatar":"https://img/a.png","commentTo":null,"likeCount":3,"likeStatus":"未登录","useful":0,"createTime":"2026-02-12T08:00:00","childComments":[],"questionId":101}],"total":1,"size":10,"current":1,"pages":1}}
```
- 失败示例
```json
{"code":"B000001","message":"系统执行出错","data":null}
```

### 5.7 我的评论分页
- `GET /api/answerly/v1/comment/my/page?current=1&size=10`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"records":[{"id":2001,"content":"我的回答"}],"total":5,"size":10,"current":1,"pages":1}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

## 6. 主题模块

### 6.1 新增主题
- `POST /api/answerly/v1/category`
- 鉴权：需要（且要求 admin）
- 请求体
```json
{"name":"高数","image":"https://img/cat.png","sort":1}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000105","message":"主题操作权限错误","data":null}
```

### 6.2 删除主题
- `DELETE /api/answerly/v1/category?id=1`
- 鉴权：需要（且要求 admin）
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000105","message":"主题操作权限错误","data":null}
```

### 6.3 修改主题
- `PUT /api/answerly/v1/category`
- 鉴权：需要（且要求 admin）
- 请求体
```json
{"id":1,"name":"高等数学","image":"https://img/cat-new.png","sort":2}
```
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"C000105","message":"主题操作权限错误","data":null}
```

### 6.4 查询全部主题
- `GET /api/answerly/v1/category`
- 鉴权：不需要
- 成功示例
```json
{"code":"0","data":[{"id":1,"name":"高数","image":"https://img/cat.png","sort":1}]}
```
- 失败示例
```json
{"code":"B000001","message":"系统执行出错","data":null}
```

## 7. 消息模块

### 7.1 消息概览
- `GET /api/answerly/v1/message/summary`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":{"messageSummary":[{"type":"system","totalCount":3,"unreadCount":1,"firstMessage":{"id":1,"content":"欢迎使用"}}]}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 7.2 按类型分页消息
- `GET /api/answerly/v1/message/page?current=1&size=10&type=comment`
- 鉴权：需要
- `type` 常见值：`system` `like` `comment` `collect` `useful`
- 成功示例
```json
{"code":"0","data":{"records":[{"id":1001,"fromId":2,"toId":1,"content":"有人评论了你的问题","type":"comment","status":1,"createTime":"2026-02-12T09:00:00"}],"total":20,"size":10,"current":1,"pages":2}}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

### 7.3 删除消息
- `DELETE /api/answerly/v1/message/delete?id=1001`
- 鉴权：需要
- 成功示例
```json
{"code":"0","data":null}
```
- 失败示例
```json
{"code":"A000204","message":"用户未登录","data":null}
```

## 8. 图片模块

### 8.1 COS 上传图片
- `POST /cos/upload`
- 鉴权：需要
- `Content-Type: multipart/form-data`
- 参数：`file`
- 成功示例
```json
{"code":"0","data":"2026/02/12/550e8400-e29b-41d4-a716-446655440000.png"}
```
- 失败示例
```json
{"code":"B000102","message":"图片上传错误","data":null}
```

## 9. 公开接口清单（无需登录）

- `GET /api/answerly/v1/user/send-code`
- `POST /api/answerly/v1/user`
- `POST /api/answerly/v1/user/login`
- `GET /api/answerly/v1/user/captcha`
- `GET /api/answerly/v1/user/forget-username`
- `GET /api/answerly/v1/user/send-reset-password-code`
- `POST /api/answerly/v1/user/reset-password`
- `GET /api/answerly/v1/question/page`
- `GET /api/answerly/v1/question/suggest`
- `GET /api/answerly/v1/question/{id}`
- `GET /api/answerly/v1/comment/page`
- `GET /api/answerly/v1/category`

注：`GET /api/answerly/v1/question/hot/{categoryId}` 在当前过滤器实现下仍会被要求登录。
