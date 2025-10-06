import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../providers/app_provider.dart';
import '../models/user_model.dart';
import '../services/preferences_service.dart';
import 'package:intl/intl.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/cached_avatar.dart';
import 'dart:typed_data'; // Added for Uint8List

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  final PreferencesService _preferencesService = PreferencesService();
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _nicknameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  bool _isEditingNickname = false;
  bool _isEditingEmail = false;
  bool _isEditingBio = false;
  bool _isUpdatingAvatar = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppProvider>(context, listen: false).user;
    _nicknameController = TextEditingController(text: user?.nickname ?? user?.username ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _bioController = TextEditingController(text: user?.description ?? '');
    
    // 页面加载后自动同步一次用户信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 如果上次同步时间超过15分钟，或者没有头像，自动同步
      if (user != null && (user.lastSyncTime == null || 
          DateTime.now().difference(user.lastSyncTime!).inMinutes > 15 || 
          user.avatarUrl == null || user.avatarUrl!.isEmpty)) {
        _syncUserInfo(context);
      }
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // 格式化创建时间
  String _formatCreationTime(User user) {
    if (user.lastSyncTime != null) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(user.lastSyncTime!);
    }
    return '未知';
  }

  // 从服务器同步用户信息
  Future<void> _syncUserInfo(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
          if (!appProvider.isLoggedIn || appProvider.memosApiService == null) {
        SnackBarUtils.showError(context, '未登录或API服务未初始化');
        return;
      }

    try {
      setState(() {
        _isUpdatingAvatar = true; // 使用同一个loading状态
      });

      // 先尝试v1 API，失败后尝试v2 API
      final userData = await _fetchUserInfoWithFallback(appProvider);
      
      // 更新本地用户信息
      final currentUser = appProvider.user;
      if (currentUser == null) {
        throw Exception('当前用户信息为空');
      }
      
      final updatedUser = User(
        id: userData['id'].toString(),
        username: userData['username'] ?? currentUser.username,
        nickname: userData['nickname'] ?? currentUser.nickname,
        email: userData['email'] ?? currentUser.email,
        description: userData['description'],
        role: userData['role'] ?? currentUser.role,
        avatarUrl: userData['avatarUrl'],
        token: currentUser.token,  // 保留原token
        lastSyncTime: DateTime.now(),
      );
      
      await _preferencesService.saveUser(updatedUser);
      await appProvider.setUser(updatedUser);
      
      // 重新加载控制器的值
      setState(() {
        _nicknameController.text = updatedUser.nickname ?? updatedUser.username ?? '';
        _emailController.text = updatedUser.email ?? '';
        _bioController.text = updatedUser.description ?? '';
      });
      
              if (mounted) {
          SnackBarUtils.showSuccess(context, '用户信息同步成功');
        }
    } catch (e) {
              if (mounted) {
          SnackBarUtils.showError(context, '同步失败: $e');
        }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  // API版本兼容性处理 - 支持v1和v2
  Future<Map<String, dynamic>> _fetchUserInfoWithFallback(AppProvider appProvider) async {
    // 先尝试v1 API
    try {
      final v1Response = await http.get(
        Uri.parse('${appProvider.appConfig.memosApiUrl}/api/v1/user/me'),
        headers: {
          'Authorization': 'Bearer ${appProvider.appConfig.lastToken}',
        },
      );

      if (v1Response.statusCode == 200) {
        return jsonDecode(v1Response.body);
      }
    } catch (e) {
      // 继续尝试v2 API
    }

    // 尝试v2 API
    try {
      final v2Response = await http.get(
        Uri.parse('${appProvider.appConfig.memosApiUrl}/api/v2/user/me'),
        headers: {
          'Authorization': 'Bearer ${appProvider.appConfig.lastToken}',
        },
      );

      if (v2Response.statusCode == 200) {
        final v2Data = jsonDecode(v2Response.body);
        // 转换v2格式到v1格式
        return {
          'id': v2Data['id'],
          'username': v2Data['username'],
          'nickname': v2Data['nickname'],
          'email': v2Data['email'],
          'description': v2Data['description'],
          'role': v2Data['role'],
          'avatarUrl': v2Data['avatarUrl'],
        };
      }
    } catch (e) {
      // 忽略错误，抛出异常
    }
    
    throw Exception('所有API版本都无法获取用户信息');
  }

  // 更新用户信息到服务器（支持v1和v2 API）
  Future<void> _updateUserInfoToServer({
    String? nickname,
    String? email,
    String? description,
    String? avatarUrl,
  }) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // 先尝试v1 API
    try {
      await _updateUserInfoV1(appProvider, nickname: nickname, email: email, description: description, avatarUrl: avatarUrl);
    } catch (e) {
      try {
        await _updateUserInfoV2(appProvider, nickname: nickname, email: email, description: description, avatarUrl: avatarUrl);
      } catch (e2) {
        throw Exception('所有API版本更新失败: v1($e), v2($e2)');
      }
    }
  }

  // v1 API更新用户信息
  Future<void> _updateUserInfoV1(AppProvider appProvider, {
    String? nickname,
    String? email,
    String? description,
    String? avatarUrl,
  }) async {
    final user = appProvider.user;
    if (user == null) {
      throw Exception('用户信息为空');
    }

    final apiUrl = '${appProvider.appConfig.memosApiUrl}/api/v1/user/${user.id}';
    final requestBody = <String, dynamic>{};
    
    if (nickname != null) requestBody['nickname'] = nickname;
    if (email != null) requestBody['email'] = email;
    if (description != null) requestBody['description'] = description;
    if (avatarUrl != null) requestBody['avatarUrl'] = avatarUrl;

    final response = await http.patch(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer ${appProvider.appConfig.lastToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('v1更新失败: ${response.statusCode} - ${response.body}');
    }
  }

  // v2 API更新用户信息
  Future<void> _updateUserInfoV2(AppProvider appProvider, {
    String? nickname,
    String? email,
    String? description,
    String? avatarUrl,
  }) async {
    // v2 API使用用户名而不是ID，格式为 /api/v2/users/{username}
    final username = appProvider.user?.username;
    if (username == null) {
      throw Exception('无法获取用户名');
    }

    final response = await http.patch(
      Uri.parse('${appProvider.appConfig.memosApiUrl}/api/v2/users/$username'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${appProvider.appConfig.lastToken}',
      },
      body: jsonEncode({
        'user': {
          'name': 'users/$username',
          if (nickname != null) 'nickname': nickname,
          if (email != null) 'email': email,
          if (description != null) 'description': description,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        },
        'updateMask': {
          'paths': [
            if (nickname != null) 'nickname',
            if (email != null) 'email', 
            if (description != null) 'description',
            if (avatarUrl != null) 'avatar_url', // v2使用下划线格式
          ],
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('v2更新失败: ${response.statusCode} - ${response.body}');
    }
  }

  // 更新密码到服务器（支持v1和v2 API）
  Future<bool> _updatePasswordToServer(AppProvider appProvider, String currentPassword, String newPassword) async {
    // 先尝试v1 API
    try {
      await _updatePasswordV1(appProvider, currentPassword, newPassword);
      return true;
    } catch (e) {
      try {
        await _updatePasswordV2(appProvider, currentPassword, newPassword);
        return true;
      } catch (e2) {
        throw Exception('所有API版本密码更新失败: v1($e), v2($e2)');
      }
    }
  }

  // v1 API更新密码
  Future<bool> _updatePasswordV1(AppProvider appProvider, String currentPassword, String newPassword) async {
    final user = appProvider.user;
    if (user == null) {
      throw Exception('用户信息为空');
    }

    // 首先验证当前密码是否正确（通过重新登录验证）
    try {
      final loginApiUrl = '${appProvider.appConfig.memosApiUrl}/api/v1/auth/signin';
      final loginResponse = await http.post(
        Uri.parse(loginApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': user.username,
          'password': currentPassword,
        }),
      );
      
      if (loginResponse.statusCode != 200) {
        throw Exception('当前密码验证失败');
      }
    } catch (e) {
      throw Exception('当前密码不正确');
    }
    
    final apiUrl = '${appProvider.appConfig.memosApiUrl}/api/v1/user/${user.id}';
    final requestBody = {
      'password': newPassword,
    };
    
    final response = await http.patch(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer ${appProvider.appConfig.lastToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('v1密码更新失败: ${response.statusCode} - ${response.body}');
    }
  }

  // v2 API更新密码
  Future<bool> _updatePasswordV2(AppProvider appProvider, String currentPassword, String newPassword) async {
    final user = appProvider.user;
    if (user == null) {
      throw Exception('用户信息为空');
    }

    // 首先验证当前密码是否正确（通过重新登录验证）
    try {
      final loginApiUrl = '${appProvider.appConfig.memosApiUrl}/api/v2/auth/signin';
      final loginResponse = await http.post(
        Uri.parse(loginApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': user.username,
          'password': currentPassword,
        }),
      );
      
      if (loginResponse.statusCode != 200) {
        throw Exception('当前密码验证失败');
      }
    } catch (e) {
      throw Exception('当前密码不正确');
    }
    
    final username = user.username;
    final apiUrl = '${appProvider.appConfig.memosApiUrl}/api/v2/users/$username';
    
    final requestBody = {
      'user': {
        'name': 'users/$username',
        'password': newPassword,
      },
      'updateMask': {
        'paths': ['password'],
      },
    };
    
    final response = await http.patch(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer ${appProvider.appConfig.lastToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(requestBody),
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('v2密码更新失败: ${response.statusCode} - ${response.body}');
    }
  }

  // 选择头像
  Future<void> _pickImage(User user) async {
    try {
      setState(() {
        _isUpdatingAvatar = true;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 95,
      );

      if (image == null) {
        setState(() {
          _isUpdatingAvatar = false;
        });
        return;
      }

      setState(() {
        _selectedImage = File(image.path);
      });

      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.memosApiService != null && appProvider.isLoggedIn) {
        try {
          // 上传图片到服务器
          final bytes = await _selectedImage!.readAsBytes();
          final base64Image = base64Encode(bytes);
          
          // 使用Memos API上传图片 - 支持v1和v2版本
          String imageUrl = '';
          
          try {
            // 先尝试v1 API上传
            imageUrl = await _uploadAvatarV1(appProvider, bytes);
          } catch (e) {
            try {
              // v1失败后尝试v2 API
              imageUrl = await _uploadAvatarV2(appProvider, bytes);
            } catch (e2) {
              throw Exception('所有API版本头像上传失败: v1($e), v2($e2)');
            }
          }
          
          if (imageUrl.isNotEmpty) {
            // 使用兼容的用户信息更新方法
            await _updateUserInfoToServer(avatarUrl: imageUrl);
            
            // 使用AppProvider的updateUserInfo方法确保全局状态同步
            final success = await appProvider.updateUserInfo(avatarUrl: imageUrl);
            
            if (!success) {
              // 如果AppProvider更新失败，手动更新本地状态
              final updatedUser = user.copyWith(avatarUrl: imageUrl);
              await _preferencesService.saveUser(updatedUser);
              await appProvider.setUser(updatedUser);
            }
            
            if (mounted) {
              SnackBarUtils.showSuccess(context, '头像已更新');
              
              // 清除网络图片缓存，确保新头像能立即显示
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
            }
            
            // 强制刷新用户信息（从服务器获取最新数据）
            await _syncUserInfo(context);
          } else {
            throw Exception('无法获取上传的头像URL');
          }
        } catch (e) {
          if (mounted) {
            SnackBarUtils.showError(context, '上传头像失败: $e');
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvatar = false;
        });
      }
    }
  }

  // v1 API上传头像
  Future<String> _uploadAvatarV1(AppProvider appProvider, Uint8List bytes) async {
    final apiUrl = '${appProvider.appConfig.memosApiUrl}/api/v1/resource/blob';
    
    // 构建multipart请求
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.headers['Authorization'] = 'Bearer ${appProvider.appConfig.lastToken}';
    
    // 添加文件部分
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      // 提取资源URL - 必须使用uid字段，而不是id
      if (data['uid'] != null) {
        // v1 API直接返回资源对象，使用uid字段
        return '${appProvider.appConfig.memosApiUrl}/o/r/${data['uid']}';
      } else if (data['data'] != null && data['data']['uid'] != null) {
        // 嵌套格式
        final uid = data['data']['uid'];
        return '${appProvider.appConfig.memosApiUrl}/o/r/$uid';
      } else if (data['resource'] != null && data['resource']['uid'] != null) {
        // 另一种格式
        final uid = data['resource']['uid'];
        return '${appProvider.appConfig.memosApiUrl}/o/r/$uid';
      }
      
      throw Exception('v1响应中无法提取资源UID');
    } else {
      throw Exception('v1上传失败: ${response.statusCode} - ${response.body}');
    }
  }

  // v2 API上传头像
  Future<String> _uploadAvatarV2(AppProvider appProvider, Uint8List bytes) async {
    final apiUrl = '${appProvider.appConfig.memosApiUrl}/api/v2/resource/blob';
    
    // 构建multipart请求
    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    request.headers['Authorization'] = 'Bearer ${appProvider.appConfig.lastToken}';
    
    // 添加文件部分
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      // v2 API响应格式 - 必须使用uid字段，而不是id
      if (data.containsKey('resource')) {
        final resource = data['resource'];
        if (resource['uid'] != null) {
          return '${appProvider.appConfig.memosApiUrl}/o/r/${resource['uid']}';
        }
      } else if (data['uid'] != null) {
        return '${appProvider.appConfig.memosApiUrl}/o/r/${data['uid']}';
      }
      
      throw Exception('v2响应中无法提取资源UID');
    } else {
      throw Exception('v2上传失败: ${response.statusCode} - ${response.body}');
    }
  }

  // 显示修改昵称对话框
  void _showNicknameDialog(BuildContext context, User user) {
    final TextEditingController controller = TextEditingController(text: user.nickname);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入新的昵称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                final appProvider = Provider.of<AppProvider>(context, listen: false);
                final result = await appProvider.updateUserInfo(nickname: newNickname);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  
                  if (result) {
                    SnackBarUtils.showSuccess(context, '昵称更新成功');
                  } else {
                    SnackBarUtils.showError(context, '昵称更新失败');
                  }
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 显示修改简介对话框
  void _showBioDialog(BuildContext context, User user) {
    final TextEditingController controller = TextEditingController(text: user.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改简介'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '简介',
            hintText: '请输入新的简介',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newBio = controller.text.trim();
              final appProvider = Provider.of<AppProvider>(context, listen: false);
              final result = await appProvider.updateUserInfo(description: newBio);
              
              if (context.mounted) {
                Navigator.pop(context);
                
                if (result) {
                  SnackBarUtils.showSuccess(context, '简介更新成功');
                } else {
                  SnackBarUtils.showError(context, '简介更新失败');
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 显示修改邮箱对话框
  void _showEmailDialog(BuildContext context, User user) {
    final TextEditingController controller = TextEditingController(text: user.email);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改邮箱'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '邮箱',
            hintText: '请输入新的邮箱地址',
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newEmail = controller.text.trim();
              if (newEmail.isNotEmpty) {
                final appProvider = Provider.of<AppProvider>(context, listen: false);
                final result = await appProvider.updateUserInfo(email: newEmail);
                
                if (context.mounted) {
                  Navigator.pop(context);
                  
                  if (result) {
                    SnackBarUtils.showSuccess(context, '邮箱更新成功');
                  } else {
                    SnackBarUtils.showError(context, '邮箱更新失败');
                  }
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 显示修改密码对话框
  void _showPasswordDialog(BuildContext context, User user) {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool isCurrentPasswordVisible = false;
    bool isNewPasswordVisible = false;
    bool isConfirmPasswordVisible = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: InputDecoration(
                  labelText: '当前密码',
                  hintText: '请输入当前密码',
                  suffixIcon: IconButton(
                    icon: Icon(
                      isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isCurrentPasswordVisible = !isCurrentPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !isCurrentPasswordVisible,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(
                  labelText: '新密码',
                  hintText: '请输入新密码（至少3位）',
                  suffixIcon: IconButton(
                    icon: Icon(
                      isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isNewPasswordVisible = !isNewPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !isNewPasswordVisible,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: '确认新密码',
                  hintText: '请再次输入新密码',
                  suffixIcon: IconButton(
                    icon: Icon(
                      isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isConfirmPasswordVisible = !isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !isConfirmPasswordVisible,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text.trim();
                final newPassword = newPasswordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();
                
                // 验证输入
                if (currentPassword.isEmpty) {
                  SnackBarUtils.showError(context, '请输入当前密码');
                  return;
                }
                
                if (newPassword.isEmpty) {
                  SnackBarUtils.showError(context, '请输入新密码');
                  return;
                }
                
                if (newPassword.length < 3) {
                  SnackBarUtils.showError(context, '新密码至少需要3位');
                  return;
                }
                
                if (newPassword != confirmPassword) {
                  SnackBarUtils.showError(context, '两次输入的新密码不一致');
                  return;
                }
                
                if (currentPassword == newPassword) {
                  SnackBarUtils.showError(context, '新密码不能与当前密码相同');
                  return;
                }
                
                try {
                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                  final result = await _updatePasswordToServer(appProvider, currentPassword, newPassword);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    
                    if (result) {
                      SnackBarUtils.showSuccess(context, '密码修改成功，请重新登录');
                      // 密码修改成功后，清除登录状态，要求用户重新登录
                      await appProvider.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    } else {
                      SnackBarUtils.showError(context, '密码修改失败，请检查当前密码是否正确');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    SnackBarUtils.showError(context, '密码修改失败: $e');
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  // 构建头像图像，支持URL和base64格式

  
  // 默认头像


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户信息'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          if (appProvider.user == null) {
            return const Center(
              child: Text('未登录'),
            );
          }
          
          final user = appProvider.user!;
          
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              // 用户基本信息卡片
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _pickImage(user),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isUpdatingAvatar
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : CachedAvatar.fromUser(
                                    user,
                                    size: 120,
                                    isCircle: true,
                                  ),
                          ),
                        ),
                        if (!_isUpdatingAvatar)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(40),
                                  bottomRight: Radius.circular(40),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.nickname ?? user.username ?? '未设置昵称',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '未设置邮箱',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '创建时间：${_formatCreationTime(user)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // 基本信息设置
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text(
                        '基本信息',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF46B696).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Color(0xFF46B696),
                        ),
                      ),
                      title: const Text('修改昵称'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showNicknameDialog(context, user),
                    ),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E9BFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF3E9BFF),
                        ),
                      ),
                      title: const Text('修改邮箱'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showEmailDialog(context, user),
                    ),
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFFFF6B6B),
                        ),
                      ),
                      title: const Text('修改密码'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPasswordDialog(context, user),
                    ),
                  ],
                ),
              ),
              
              // 添加同步按钮
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _syncUserInfo(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '立即同步个人信息',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 