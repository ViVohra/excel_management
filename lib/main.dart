// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:equatable/equatable.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:uuid/uuid.dart';

// LOGGING: Create a global logger instance
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
  ),
);

// ======== RESPONSIVE BREAKPOINTS ========
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 840;
  static const double desktop = 1200;
}

// ======== THEME DEFINITION (REFACTORED) ========
class AppTheme {
  static final ThemeData lightTheme = _buildTheme(Brightness.light);
  static final ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    // Define color palettes
    final Color primaryColor = isLight
        ? const Color(0xFF00796B)
        : const Color(0xFF4DB6AC);
    final Color secondaryColor = isLight
        ? const Color(0xFFFFA000)
        : const Color(0xFFFFC107);
    final Color backgroundColor = isLight
        ? const Color(0xFFF5F7FA)
        : const Color(0xFF121212);
    final Color surfaceColor = isLight ? Colors.white : const Color(0xFF1E1E1E);
    final Color textColor = isLight
        ? const Color(0xFF333333)
        : const Color(0xFFE0E0E0);
    final Color borderColor = isLight
        ? const Color(0xFFE0E0E0)
        : const Color(0xFF424242);

    final baseTheme = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: textColor, displayColor: textColor);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        onPrimary: isLight ? Colors.white : Colors.black,
        onSecondary: Colors.black,
        onBackground: textColor,
        onSurface: textColor,
        error: isLight ? const Color(0xFFD32F2F) : const Color(0xFFCF6679),
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: primaryColor,
          fontSize: 32,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          color: textColor.withOpacity(0.9),
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: textColor.withOpacity(0.7),
          height: 1.5,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? primaryColor : surfaceColor,
        foregroundColor: isLight ? Colors.white : textColor,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isLight ? Colors.white : textColor,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 0.5 : 1.0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
        color: surfaceColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: borderColor),
        ),
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: isLight ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 1,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.black,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        titleTextStyle: textTheme.headlineMedium?.copyWith(fontSize: 20),
        backgroundColor: surfaceColor,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: isLight ? Colors.grey[500] : Colors.grey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        backgroundColor: surfaceColor,
        elevation: 2,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.1),
        labelStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }
}

class ThemeNotifier with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }
}

// ======== HELPER EXTENSIONS & CLASSES ========
extension StringExtensions on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

// ======== MODELS ========
class RoleModel {
  final String uid;
  final String role;
  final String? name;

  RoleModel({required this.uid, required this.role, this.name});

  factory RoleModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RoleModel(
      uid: documentId,
      role: map['role'] as String? ?? 'employee',
      name: map['name'] as String?,
    );
  }
}

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String name;
  final String role;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'employee',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [uid, email, name, role, isActive];
}

class ProjectModel extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? createdBy;

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.startDate,
    this.endDate,
    this.createdBy,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      status: map['status'] as String,
      startDate: map['start_date'] == null
          ? null
          : DateTime.tryParse(map['start_date'] as String),
      endDate: map['end_date'] == null
          ? null
          : DateTime.tryParse(map['end_date'] as String),
      createdBy: map['created_by'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    status,
    startDate,
    endDate,
    createdBy,
  ];
}

class UploadModel {
  final String id;
  final String projectId;
  final String fileName;
  final DateTime createdAt;
  final List<String>? columnOrder;

  UploadModel({
    required this.id,
    required this.projectId,
    required this.fileName,
    required this.createdAt,
    this.columnOrder,
  });

  factory UploadModel.fromMap(Map<String, dynamic> map) {
    List<String>? parsedColumnOrder;
    if (map['column_order'] is List) {
      parsedColumnOrder = List<String>.from(map['column_order']);
    }

    return UploadModel(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      fileName: map['file_name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      columnOrder: parsedColumnOrder,
    );
  }
}

class SubTaskModel {
  final String id;
  final String parentTaskId;
  final String title;
  bool isCompleted;

  SubTaskModel({
    required this.id,
    required this.parentTaskId,
    required this.title,
    this.isCompleted = false,
  });

  factory SubTaskModel.fromMap(Map<String, dynamic> map) {
    return SubTaskModel(
      id: map['id'],
      parentTaskId: map['parent_task_id'],
      title: map['title'],
      isCompleted: map['is_completed'],
    );
  }
}

class TaskCommentModel {
  final String id;
  final String taskId;
  final String userId;
  final String userName;
  final String comment;
  final DateTime createdAt;

  TaskCommentModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    required this.comment,
    required this.createdAt,
  });

  factory TaskCommentModel.fromMap(Map<String, dynamic> map) {
    return TaskCommentModel(
      id: map['id'],
      taskId: map['task_id'],
      userId: map['user_id'],
      userName: map['user_name'],
      comment: map['comment'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

// ======== SERVICES (REFACTORED) ========
class AuthService with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Future<UserModel?> getUserData(String uid) async {
    logger.d('Fetching user data for UID: $uid');
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('uid', uid)
          .single();
      if (response.isNotEmpty) {
        logger.i('User data found for UID: $uid');
        return UserModel.fromMap(response, uid);
      }
      logger.w('No user data found for UID: $uid');
      return null;
    } catch (e, st) {
      logger.e(
        'Error getting user data for UID $uid',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // Private helper to reduce duplication
  Future<void> _insertUser({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) async {
    await _supabase.from('users').insert({
      'uid': uid,
      'email': email,
      'role': role,
      'name': name,
      'isActive': true,
    });
  }

  Future<void> signUpAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    logger.i('Attempting to sign up new admin: $email');
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (authResponse.user == null) {
        throw const AuthException('User creation failed in Supabase Auth.');
      }
      await _insertUser(
        uid: authResponse.user!.id,
        email: email,
        name: name,
        role: 'admin',
      );
      logger.i('Admin account created successfully for: $email');
      notifyListeners();
    } on AuthException catch (e, st) {
      logger.e('AuthException during admin signup', error: e, stackTrace: st);
      throw Exception(e.message);
    } catch (e, st) {
      logger.e(
        'General exception during admin signup',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<String> createEmployee({
    required String email,
    required String name,
    String role = 'employee',
  }) async {
    logger.i('Attempting to create new $role: $email');
    try {
      final password = 'temp${DateTime.now().millisecondsSinceEpoch}';
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (authResponse.user == null) {
        throw AuthException('$role creation failed in Supabase Auth.');
      }
      await _insertUser(
        uid: authResponse.user!.id,
        email: email,
        name: name,
        role: role,
      );
      logger.i('$role account created successfully for: $email');
      notifyListeners();
      return password;
    } on AuthException catch (e, st) {
      logger.e('AuthException during $role creation', error: e, stackTrace: st);
      throw Exception(e.message);
    } catch (e, st) {
      logger.e(
        'General exception during $role creation',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    logger.i('Attempting to sign in user: $email');
    try {
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final userData = await getUserData(authResponse.user!.id);
      if (userData?.isActive == false) {
        await _supabase.auth.signOut();
        throw Exception('This account is deactivated.');
      }
      logger.i('User sign-in successful: $email');
      notifyListeners();
    } on AuthException catch (e, st) {
      logger.w(
        'AuthException during sign-in for $email',
        error: e,
        stackTrace: st,
      );
      // More robust error handling
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        throw Exception('Invalid email or password.');
      }
      if (e.statusCode == '400') {
        throw Exception('Please check your email and password.');
      }
      throw Exception(e.message);
    } catch (e, st) {
      logger.e(
        'General exception during sign-in for $email',
        error: e,
        stackTrace: st,
      );
      // Avoid fragile string matching
      if (e is SocketException) {
        throw Exception('Please check your internet connection.');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    logger.i('User signing out.');
    await _supabase.auth.signOut();
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    logger.i('Attempting to reset password for: $email');
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      logger.i('Password reset email sent to: $email');
    } on AuthException catch (e, st) {
      logger.e('AuthException during password reset', error: e, stackTrace: st);
      throw Exception(e.message);
    } catch (e, st) {
      logger.e(
        'General exception during password reset',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

class SupabaseService with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  static const _getAdminSummaryRpc = 'get_admin_dashboard_summary_for_admin';
  static const _getAllTasksForUserRpc = 'get_all_tasks_for_user';
  static const _getUploadsForUserInProjectRpc =
      'get_uploads_for_user_in_project';
  static const _getProjectsForUserRpc = 'get_projects_for_user';

  Future<Map<String, dynamic>?> getAdminDashboardSummary(String adminId) async {
    logger.d('Fetching admin dashboard summary for admin: $adminId');
    try {
      final response = await _supabase.rpc(
        _getAdminSummaryRpc,
        params: {'p_admin_id': adminId},
      );
      logger.i('Successfully fetched admin dashboard summary for $adminId.');
      return response as Map<String, dynamic>;
    } catch (e, st) {
      logger.e(
        'Error getting admin dashboard summary for $adminId',
        error: e,
        stackTrace: st,
      );
      return null; // Return null on error
    }
  }

  Future<List<Map<String, dynamic>>> getAllTasksForUser(String userId) async {
    logger.d('Fetching all tasks for user: $userId');
    try {
      final response = await _supabase.rpc(
        _getAllTasksForUserRpc,
        params: {'p_user_id': userId},
      );
      logger.i('Successfully fetched all tasks for user: $userId');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      logger.e(
        'Error fetching all tasks for user: $userId',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Stream<List<UserModel>> getEmployees() {
    logger.d('Setting up stream for all employees.');
    return _supabase
        .from('users')
        .stream(primaryKey: ['uid'])
        .eq('role', 'employee')
        .order('name', ascending: true)
        .map((listOfMaps) {
          logger.v('Received new data from employees stream.');
          return listOfMaps
              .map((singleMap) {
                final String? documentId = singleMap['uid'] as String?;
                if (documentId == null) {
                  logger.w('Employee data missing uid: $singleMap');
                  return null;
                }
                return UserModel.fromMap(singleMap, documentId);
              })
              .whereType<UserModel>()
              .toList();
        });
  }

  Stream<List<ProjectModel>> getProjectsForAdmin(String adminId) {
    logger.d('Setting up stream for projects for admin: $adminId');
    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .eq('created_by', adminId)
        .order('name', ascending: true)
        .map((maps) {
          logger.v('Received new data from admin-specific projects stream.');
          return maps.map((map) => ProjectModel.fromMap(map)).toList();
        });
  }

  Stream<List<ProjectModel>> getAllProjects() {
    logger.d('Setting up stream for all projects.');
    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((maps) {
          logger.v('Received new data from projects stream.');
          return maps.map((map) => ProjectModel.fromMap(map)).toList();
        });
  }

  Stream<List<UploadModel>> getUploadsForProject(String projectId) {
    logger.d('Setting up stream for uploads in project: $projectId');
    return _supabase
        .from('uploads')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .map((maps) {
          logger.v(
            'Received new data from uploads stream for project: $projectId',
          );
          return maps.map((map) => UploadModel.fromMap(map)).toList();
        });
  }

  Future<List<UploadModel>> getUploadsForUserInProject(
    String projectId,
    String userId,
  ) async {
    logger.d('Fetching uploads for user $userId in project: $projectId');
    try {
      final response = await _supabase.rpc(
        _getUploadsForUserInProjectRpc,
        params: {'p_project_id': projectId, 'p_user_id': userId},
      );
      logger.i(
        'Successfully fetched uploads for user $userId in project $projectId',
      );
      if (response is List) {
        return response.map((item) => UploadModel.fromMap(item)).toList();
      }
      return [];
    } catch (e, st) {
      logger.e(
        'Error fetching uploads for user $userId in project $projectId',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> getTasksForUpload(
    String uploadId,
    String userId,
    String userRole,
  ) {
    logger.d(
      'Setting up stream for tasks in upload: $uploadId for user: $userId with role: $userRole',
    );
    var query = _supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('upload_id', uploadId);

    return query.map((listOfTasksForUpload) {
      if (userRole == 'admin' || userRole == 'manager') {
        logger.v(
          'Admin/Manager role detected. Returning all ${listOfTasksForUpload.length} tasks for upload $uploadId.',
        );
        return listOfTasksForUpload;
      } else {
        logger.v(
          'Employee role detected. Filtering ${listOfTasksForUpload.length} tasks for user $userId.',
        );
        final filteredTasks = listOfTasksForUpload
            .where((task) => task['assignedTo'] == userId)
            .toList();
        logger.i(
          'Filtered down to ${filteredTasks.length} tasks for user $userId.',
        );
        return filteredTasks;
      }
    });
  }

  Future<void> uploadTasksFromExcel(
    String projectId,
    String fileName,
    List<Map<String, dynamic>> tasksDataFromExcel,
    List<String> headerRow,
  ) async {
    logger.i('Uploading tasks from file: $fileName to project: $projectId');
    logger.d('Header row: $headerRow');
    logger.v('Tasks data payload count: ${tasksDataFromExcel.length}');

    if (tasksDataFromExcel.isEmpty) {
      throw Exception('No tasks to upload.');
    }
    try {
      final uploadRecord = await _supabase
          .from('uploads')
          .insert({
            'project_id': projectId,
            'file_name': fileName,
            'column_order': headerRow,
          })
          .select()
          .single();
      final uploadId = uploadRecord['id'];
      logger.d('Created upload record with ID: $uploadId');
      final List<Map<String, dynamic>> tasksToInsert = [];
      for (var data in tasksDataFromExcel) {
        final taskDataForSupabase = Map<String, dynamic>.from(data);
        final String? id = taskDataForSupabase.remove('id')?.toString();
        final String? assignedTo = taskDataForSupabase
            .remove('assignedTo')
            ?.toString();
        final String? status = taskDataForSupabase.remove('status')?.toString();
        taskDataForSupabase.remove('lastEditedBy');
        tasksToInsert.add({
          'id': id ?? _uuid.v4(),
          'project_id': projectId,
          'upload_id': uploadId,
          'data': taskDataForSupabase,
          'assignedTo': assignedTo,
          'status': status ?? 'Not Started',
          'employee_remarks': null,
        });
      }
      if (tasksToInsert.isEmpty) {
        throw Exception('No valid task data to upload.');
      }
      await _supabase.from('tasks').insert(tasksToInsert);
      logger.i(
        'Successfully inserted ${tasksToInsert.length} tasks for upload ID: $uploadId',
      );
      notifyListeners();
    } on PostgrestException catch (e, st) {
      logger.e(
        'PostgrestException during task upload',
        error: e,
        stackTrace: st,
      );
      throw Exception('Database error: ${e.message}');
    } catch (e, st) {
      logger.e('Unknown error during task upload', error: e, stackTrace: st);
      throw Exception('Failed to upload tasks to the database.');
    }
  }

  Future<void> createProject(String name, String description) async {
    logger.i('Creating new project: $name');
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated. Cannot create project.');
    }

    try {
      await _supabase.from('projects').insert({
        'name': name,
        'description': description,
        'status': 'Not Started',
        'created_by': currentUser.id,
      });
      logger.i(
        'Project "$name" created successfully by admin ${currentUser.id}.',
      );
      notifyListeners();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('A project with this name already exists.');
      }
      throw Exception('Database Error: ${e.message}');
    } catch (e, st) {
      logger.e('Error creating project: $name', error: e, stackTrace: st);
      throw Exception('Failed to create project.');
    }
  }

  Future<void> updateTask(
    String taskId,
    Map<String, dynamic> updatedFields,
  ) async {
    logger.v('Updating task: $taskId with fields: $updatedFields');
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception("User not authenticated.");

      final updatePayload = {...updatedFields, 'lastEditedBy': currentUser.id};
      String? oldStatus;
      String? newStatus = updatedFields['status'];

      if (newStatus != null) {
        final currentTaskResponse = await _supabase
            .from('tasks')
            .select('status, started_at')
            .eq('id', taskId)
            .single();

        oldStatus = currentTaskResponse['status'] as String?;
        final currentStartedAt = currentTaskResponse['started_at'];

        if (oldStatus != newStatus) {
          if (oldStatus == 'Not Started' &&
              newStatus != 'Not Started' &&
              currentStartedAt == null) {
            updatePayload['started_at'] = DateTime.now().toIso8601String();
          }

          if (newStatus == 'Completed') {
            updatePayload['completed_at'] = DateTime.now().toIso8601String();
          } else {
            updatePayload['completed_at'] = null;
          }
        }
      }

      await _supabase.from('tasks').update(updatePayload).eq('id', taskId);

      if (newStatus != null && oldStatus != newStatus) {
        await _supabase.from('task_status_history').insert({
          'task_id': taskId,
          'old_status': oldStatus,
          'new_status': newStatus,
          'changed_by_uid': currentUser.id,
        });
      }

      logger.d('Task $taskId updated successfully.');
      notifyListeners();
    } catch (e, st) {
      logger.e('Error updating task: $taskId', error: e, stackTrace: st);
      throw Exception('Failed to update task.');
    }
  }

  Future<void> deactivateUser(String uid) async {
    logger.i('Deactivating user: $uid');
    try {
      await _supabase.from('users').update({'isActive': false}).eq('uid', uid);
      logger.i('User $uid deactivated successfully.');
      notifyListeners();
    } catch (e, st) {
      logger.e('Error deactivating user: $uid', error: e, stackTrace: st);
      throw Exception('Failed to deactivate user.');
    }
  }

  Future<Map<String, int>> getTaskSummaryForProject(String projectId) async {
    logger.d('Fetching task summary for project: $projectId');
    try {
      final tasks = await _supabase
          .from('tasks')
          .select('status')
          .eq('project_id', projectId);
      final statusCounts = {
        'Not Started': 0,
        'In Progress': 0,
        'Completed': 0,
        'On Hold': 0,
        'Under Review': 0,
      };
      for (var task in tasks) {
        final status = task['status'] as String;
        if (statusCounts.containsKey(status)) {
          statusCounts[status] = statusCounts[status]! + 1;
        }
      }
      logger.i('Successfully fetched task summary for project: $projectId');
      return statusCounts;
    } catch (e, st) {
      logger.e(
        'Error fetching task summary for project: $projectId',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  Future<List<ProjectModel>> getProjectsForUser(String userId) async {
    logger.d('Fetching projects for user: $userId');
    try {
      final response = await _supabase.rpc(
        _getProjectsForUserRpc,
        params: {'user_id': userId},
      );
      logger.i('Successfully fetched projects for user: $userId');
      if (response is List) {
        return response.map((item) => ProjectModel.fromMap(item)).toList();
      }
      return [];
    } catch (e, st) {
      logger.e(
        'Error fetching projects for user: $userId',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Stream<List<SubTaskModel>> getSubTasks(String parentTaskId) {
    return _supabase
        .from('sub_tasks')
        .stream(primaryKey: ['id'])
        .eq('parent_task_id', parentTaskId)
        .order('created_at')
        .map((maps) => maps.map((map) => SubTaskModel.fromMap(map)).toList());
  }

  Future<void> addComment(String taskId, String comment, UserModel user) async {
    await _supabase.from('task_comments').insert({
      'task_id': taskId,
      'user_id': user.uid,
      'user_name': user.name,
      'comment': comment,
    });
  }

  Stream<List<TaskCommentModel>> getComments(String taskId) {
    return _supabase
        .from('task_comments')
        .stream(primaryKey: ['id'])
        .eq('task_id', taskId)
        .order('created_at', ascending: false)
        .map(
          (maps) => maps.map((map) => TaskCommentModel.fromMap(map)).toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getFilteredTaskReport({
    DateTime? startDate,
    DateTime? endDate,
    String? projectId,
    String? userId,
    String? status,
  }) async {
    logger.d(
      'Fetching filtered task report with params: '
      'startDate: $startDate, endDate: $endDate, projectId: $projectId, '
      'userId: $userId, status: $status',
    );
    try {
      final response = await _supabase.rpc(
        'get_filtered_task_report',
        params: {
          'start_date_param': startDate?.toIso8601String(),
          'end_date_param': endDate?.toIso8601String(),
          'project_id_param': projectId,
          'user_id_param': userId,
          'status_param': status,
        },
      );
      logger.i('Successfully fetched filtered task report.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      logger.e('Error fetching filtered task report', error: e, stackTrace: st);
      throw Exception('Failed to generate report. Please try again.');
    }
  }

  Future<void> updateProject(
    String projectId,
    String name,
    String description,
  ) async {
    logger.i('Attempting to update project: $projectId with name: $name');

    try {
      await _supabase
          .from('projects')
          .update({'name': name, 'description': description})
          .eq('id', projectId)
          .select();
      logger.i(
        'Project "$name" (ID: $projectId) updated successfully in the database.',
      );
      notifyListeners();
    } on PostgrestException catch (e, st) {
      logger.e(
        'A database error occurred while updating project: $projectId',
        error: e,
        stackTrace: st,
      );
      if (e.code == '23505') {
        throw Exception(
          'A project with this name already exists. Please choose a different name.',
        );
      }
      throw Exception('A database error occurred. Please try again later.');
    } catch (e, st) {
      logger.e(
        'An unexpected error occurred while updating project: $projectId',
        error: e,
        stackTrace: st,
      );
      throw Exception(
        'An unexpected error occurred. Please check your connection and try again.',
      );
    }
  }

  Future<void> deleteProject(String projectId) async {
    logger.w('Attempting to PERMANENTLY DELETE project: $projectId');
    try {
      await _supabase.from('projects').delete().eq('id', projectId);
      logger.i(
        'Project (ID: $projectId) was successfully deleted from the database.',
      );
      notifyListeners();
    } on PostgrestException catch (e, st) {
      logger.e(
        'A database error occurred while deleting project: $projectId',
        error: e,
        stackTrace: st,
      );
      throw Exception(
        'A database error occurred while deleting the project. It may have already been removed.',
      );
    } catch (e, st) {
      logger.e(
        'An unexpected error occurred while deleting project: $projectId',
        error: e,
        stackTrace: st,
      );
      throw Exception(
        'An unexpected error occurred. Please check your connection and try again.',
      );
    }
  }
}

// ======== MAIN APP ENTRY POINT ========
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SupabaseService()),
        ChangeNotifierProxyProvider<AuthService, UserModelNotifier>(
          create: (_) => UserModelNotifier(null),
          update: (_, auth, notifier) {
            final user = auth.currentUser;
            if (user == null) {
              notifier?.update(null);
            } else {
              if (user.id != notifier?.userModel?.uid) {
                auth.getUserData(user.id).then((userModel) {
                  notifier?.update(userModel);
                });
              }
            }
            return notifier!;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class UserModelNotifier with ChangeNotifier {
  UserModel? _userModel;

  UserModel? get userModel => _userModel;

  UserModelNotifier(this._userModel);

  void update(UserModel? newUserModel) {
    if (_userModel != newUserModel) {
      logger.i(
        'UserModelNotifier updated. New user: ${newUserModel?.name}, Role: ${newUserModel?.role}, IsActive: ${newUserModel?.isActive}',
      );
      _userModel = newUserModel;
      notifyListeners();
    }
  }
}

// ======== DESIGN-FOCUSED ROOT WIDGET ========
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Project Management App',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ======== AUTH & NAVIGATION (REFACTORED) ========
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Listen to user model changes to handle deactivation
    Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).addListener(_handleUserDeactivation);
  }

  @override
  void dispose() {
    Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).removeListener(_handleUserDeactivation);
    super.dispose();
  }

  void _handleUserDeactivation() {
    final userModel = Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).userModel;
    if (userModel != null && !userModel.isActive) {
      // Show snackbar and sign out
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account has been deactivated.'),
          backgroundColor: Colors.red,
        ),
      );
      Provider.of<AuthService>(context, listen: false).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userNotifier = context.watch<UserModelNotifier>();

    if (authService.currentUser == null) {
      return const AuthScreen();
    }

    final userModel = userNotifier.userModel;

    if (userModel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // The listener will handle deactivation, so we just need to route
    switch (userModel.role) {
      case 'admin':
      case 'manager':
        return const AdminHomePage();
      case 'employee':
      default:
        return const EmployeeHomePage();
    }
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  bool _isAdminSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      if (_isLogin) {
        await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else if (_isAdminSignUp) {
        await authService.signUpAdmin(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin account created! Please log in.'),
          ),
        );
        setState(() {
          _isLogin = true;
          _isAdminSignUp = false;
        });
      }
    } catch (e) {
      logger.w("Auth submission failed.", error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    // Improved email validation
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email to reset password.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.resetPassword(email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.insights_rounded,
                        size: 60,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isLogin ? 'Welcome Back!' : 'Create Admin Account',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin
                            ? 'Log in to continue'
                            : 'Fill in the details to get started',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (_isAdminSignUp) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Please enter your name' : null,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v!.isEmpty || !v.contains('@')
                            ? 'Enter a valid email'
                            : null,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        obscureText: true,
                        validator: (v) => v!.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submit,
                              child: Text(_isLogin ? 'Login' : 'Create Admin'),
                            ),
                      const SizedBox(height: 16),
                      _buildAuthSwitch(),
                      if (_isLogin)
                        TextButton(
                          onPressed: _resetPassword,
                          child: const Text('Forgot Password?'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthSwitch() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isLogin = !_isLogin;
          _isAdminSignUp = !_isLogin;
          _formKey.currentState?.reset();
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
        });
      },
      child: Text(
        _isLogin
            ? 'No Admin Account? Create One'
            : 'Already have an account? Login',
      ),
    );
  }
}

// ======== WIDGETS (REUSABLE COMPONENTS) ========
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget tabletBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    Key? key,
    required this.mobileBody,
    required this.tabletBody,
    required this.desktopBody,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.desktop) {
          return desktopBody;
        } else if (constraints.maxWidth >= Breakpoints.tablet) {
          return tabletBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const InfoCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                    ),
                    overflow: TextOverflow.ellipsis,
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

// ======== ADMIN SCREENS (REFACTORED) ========
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = const <Widget>[
    AdminDashboardScreen(),
    ProjectListScreen(),
    EmployeeListScreen(),
    ReportingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);

    // Use Consumer to reactively build the title
    return Consumer<UserModelNotifier>(
      builder: (context, userNotifier, child) {
        final userModel = userNotifier.userModel;
        final titles = [
          'Welcome, ${userModel?.name ?? 'Admin'}',
          'Manage Projects',
          'Manage Employees',
          'Reporting & Analytics',
        ];

        return ResponsiveLayout(
          mobileBody: _buildMobileLayout(titles, authService, themeNotifier),
          tabletBody: _buildDesktopLayout(titles, authService, themeNotifier),
          // Using desktop for tablet
          desktopBody: _buildDesktopLayout(titles, authService, themeNotifier),
        );
      },
    );
  }

  Scaffold _buildMobileLayout(
    List<String> titles,
    AuthService authService,
    ThemeNotifier themeNotifier,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: Icon(
              themeNotifier.themeMode == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: IndexedStack(index: _selectedIndex, children: _widgetOptions),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reporting',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Scaffold _buildDesktopLayout(
    List<String> titles,
    AuthService authService,
    ThemeNotifier themeNotifier,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: Icon(
              themeNotifier.themeMode == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: Text('Projects'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_alt_outlined),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Employees'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Reporting'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _widgetOptions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _fetchSummary();
  }

  Future<Map<String, dynamic>?> _fetchSummary() {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final userModel = Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).userModel;

    if (userModel == null) {
      logger.w("AdminDashboard: User not available yet, cannot fetch summary.");
      // Throw an exception to be caught by FutureBuilder
      throw Exception('User not available');
    }
    return supabaseService.getAdminDashboardSummary(userModel.uid);
  }

  void refresh() {
    setState(() {
      _summaryFuture = _fetchSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load dashboard data.',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          );
        }
        final summary = snapshot.data!;
        final projectCount = summary['projectCount']?.toString() ?? '0';
        final employeeCount = summary['employeeCount']?.toString() ?? '0';
        final taskSummary =
            summary['taskSummary'] as Map<String, dynamic>? ?? {};
        final totalTasks = taskSummary.values.fold<int>(
          0,
          (prev, count) => prev + (count as int),
        );

        final List<Map<String, dynamic>> infoCardsData = [
          {
            'title': 'Total Projects',
            'value': projectCount,
            'icon': Icons.folder_copy_outlined,
            'color': Colors.blue,
          },
          {
            'title': 'Active Employees',
            'value': employeeCount,
            'icon': Icons.people_outline,
            'color': Colors.green,
          },
          {
            'title': 'Total Tasks',
            'value': totalTasks.toString(),
            'icon': Icons.list_alt,
            'color': Colors.orange,
          },
        ];

        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Workspace Overview",
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 350)
                        .floor()
                        .clamp(1, 4);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 3,
                      ),
                      itemCount: infoCardsData.length,
                      itemBuilder: (context, index) {
                        final cardData = infoCardsData[index];
                        return InfoCard(
                          title: cardData['title'],
                          value: cardData['value'],
                          icon: cardData['icon'],
                          color: cardData['color'],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  "Task Status Overview",
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: taskSummary.isNotEmpty
                        ? SizedBox(
                            height: 250,
                            child: _buildTaskPieChart(taskSummary, totalTasks),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text("No tasks found."),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskPieChart(Map<String, dynamic> taskSummary, int totalTasks) {
    final List<PieChartSectionData> sections = [];
    final colors = {
      'Not Started': Colors.orange[400]!,
      'In Progress': Colors.blue[400]!,
      'Completed': Colors.green[400]!,
      'On Hold': Colors.purple[400]!,
      'Under Review': Colors.yellow[700]!,
    };

    taskSummary.forEach((status, count) {
      if (count > 0) {
        final color = colors[status] ?? Colors.grey[400]!;
        sections.add(
          PieChartSectionData(
            color: color,
            value: count.toDouble(),
            title: '${(count / totalTasks * 100).toStringAsFixed(0)}%',
            radius: 80.0,
            titleStyle: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        );
      }
    });

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: sections,
      ),
    );
  }
}

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).userModel;
    final bool isAdmin = userModel?.role == 'admin';

    final Stream<List<ProjectModel>> projectsStream;
    final supabaseService = Provider.of<SupabaseService>(context);

    if (isAdmin && userModel != null) {
      projectsStream = supabaseService.getProjectsForAdmin(userModel.uid);
    } else {
      projectsStream = supabaseService.getAllProjects();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<ProjectModel>>(
        stream: projectsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final projects = snapshot.data ?? [];
          if (projects.isEmpty) {
            return const Center(child: Text('No projects yet. Create one!'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.folder_copy_outlined, size: 20),
                  ),
                  title: Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(
                    project.description ?? 'No description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: (isAdmin || userModel?.role == 'manager')
                      ? _buildAdminMenu(context, project)
                      : const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailScreen(project: project),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: (isAdmin || userModel?.role == 'manager')
          ? FloatingActionButton.extended(
              heroTag: 'new_project_fab',
              onPressed: () {
                _showCreateProjectDialog(context);
              },
              label: const Text('New Project'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAdminMenu(BuildContext context, ProjectModel project) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'edit') {
          _showEditProjectDialog(context, project);
        } else if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                'Are you sure you want to delete this project and all its tasks? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              await Provider.of<SupabaseService>(
                context,
                listen: false,
              ).deleteProject(project.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Project deleted successfully.')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting project: $e')),
              );
            }
          }
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  void _showEditProjectDialog(BuildContext context, ProjectModel project) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: project.name);
    final descriptionController = TextEditingController(
      text: project.description,
    );
    final service = Provider.of<SupabaseService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            bool isLoading = false;
            return AlertDialog(
              title: const Text('Edit Project'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Project Name',
                      ),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setStateDialog(() => isLoading = true);
                            try {
                              await service.updateProject(
                                project.id,
                                nameController.text.trim(),
                                descriptionController.text.trim(),
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Project updated successfully!',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error: ${e.toString().replaceFirst("Exception: ", "")}',
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setStateDialog(() => isLoading = false);
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final service = Provider.of<SupabaseService>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setStateDialog) {
            bool isLoading = false;
            return AlertDialog(
              title: const Text('Create New Project'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Project Name',
                      ),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setStateDialog(() => isLoading = true);
                            try {
                              await service.createProject(
                                nameController.text.trim(),
                                descriptionController.text.trim(),
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error: ${e.toString().replaceFirst("Exception: ", "")}',
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              if (dialogContext.mounted) {
                                setStateDialog(() => isLoading = false);
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

class _ReportingScreenState extends State<ReportingScreen> {
  ProjectModel? _selectedProject;
  UserModel? _selectedEmployee;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  final List<String> _statuses = [
    "Not Started",
    "In Progress",
    "Completed",
    "On Hold",
    "Under Review",
  ];

  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];
  String? _errorMessage;

  List<String> _allPossibleDataColumns = [];
  Set<String> _selectedDataColumns = {};

  List<BarChartGroupData> _chartData = [];
  late SupabaseService _supabaseService;
  bool _isServiceInitialized = false;

  // New state variables for dashboard
  double _totalBilled = 0;
  double _totalPaid = 0;
  int _workedClaims = 0;
  int _nonWorkedClaims = 0;
  Map<String, int> _claimBuckets = {};

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isServiceInitialized) {
      _supabaseService = Provider.of<SupabaseService>(context, listen: false);
      _isServiceInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateReport());
    }
  }

  void _setDefaultDateRange() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _reportData = [];
      _chartData = [];
      _allPossibleDataColumns = [];
      _totalBilled = 0;
      _totalPaid = 0;
      _workedClaims = 0;
      _nonWorkedClaims = 0;
      _claimBuckets = {};
    });
    try {
      final data = await _supabaseService.getFilteredTaskReport(
        startDate: _startDate,
        endDate: _endDate,
        projectId: _selectedProject?.id,
        userId: _selectedEmployee?.uid,
        status: _selectedStatus,
      );
      setState(() {
        _reportData = data;
        _processChartData(data);
        _discoverDataColumns(data);
        _calculateDashboardMetrics(data);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateDashboardMetrics(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;

    double billed = 0;
    double paid = 0;
    int worked = 0;
    int notWorked = 0;
    Map<String, int> buckets = {
      "0-29 Days": 0,
      "30-59 Days": 0,
      "60-89 Days": 0,
      "90+ Days": 0,
    };

    final now = DateTime.now();

    for (final row in data) {
      final taskData = row['task_data'] as Map<String, dynamic>? ?? {};

      // Billed and Paid
      billed += double.tryParse(taskData['CHARGES']?.toString() ?? '0') ?? 0;
      paid += double.tryParse(taskData['Pmts/Refunds']?.toString() ?? '0') ?? 0;

      // Worked vs Non-worked
      if (row['status'] != 'Not Started') {
        worked++;
      } else {
        notWorked++;
      }

      // Claim Bucketing
      final serviceDateString = taskData['SERVICE DATE']?.toString();
      if (serviceDateString != null) {
        final serviceDate = DateTime.tryParse(serviceDateString);
        if (serviceDate != null) {
          final difference = now.difference(serviceDate).inDays;
          if (difference >= 0 && difference < 30) {
            buckets["0-29 Days"] = (buckets["0-29 Days"] ?? 0) + 1;
          } else if (difference >= 30 && difference < 60) {
            buckets["30-59 Days"] = (buckets["30-59 Days"] ?? 0) + 1;
          } else if (difference >= 60 && difference < 90) {
            buckets["60-89 Days"] = (buckets["60-89 Days"] ?? 0) + 1;
          } else if (difference >= 90) {
            buckets["90+ Days"] = (buckets["90+ Days"] ?? 0) + 1;
          }
        }
      }
    }

    setState(() {
      _totalBilled = billed;
      _totalPaid = paid;
      _workedClaims = worked;
      _nonWorkedClaims = notWorked;
      _claimBuckets = buckets;
    });
  }

  void _processChartData(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;
    final Map<String, int> employeeTaskCounts = {};
    for (final row in data) {
      final employeeName = row['employee_name'] as String? ?? 'Unassigned';
      employeeTaskCounts[employeeName] =
          (employeeTaskCounts[employeeName] ?? 0) + 1;
    }

    int i = 0;
    _chartData = employeeTaskCounts.entries.map((entry) {
      return BarChartGroupData(
        x: i++,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: Colors.teal,
            width: 16,
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();
  }

  void _discoverDataColumns(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return;
    final Set<String> columns = {};
    for (final row in data) {
      final taskData = row['task_data'] as Map<String, dynamic>? ?? {};
      columns.addAll(taskData.keys);
    }
    setState(() {
      _allPossibleDataColumns = columns.toList()..sort();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedProject = null;
      _selectedEmployee = null;
      _startDate = null;
      _endDate = null;
      _selectedStatus = null;
      _reportData = [];
      _chartData = [];
      _allPossibleDataColumns = [];
      _selectedDataColumns = {};
      _errorMessage = null;
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _showColumnSelectionDialog() async {
    final Set<String> tempSelected = Set<String>.from(_selectedDataColumns);
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Data Columns'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _allPossibleDataColumns.map((col) {
                    return CheckboxListTile(
                      title: Text(col),
                      value: tempSelected.contains(col),
                      onChanged: (isSelected) {
                        setStateDialog(() {
                          if (isSelected == true) {
                            tempSelected.add(col);
                          } else {
                            tempSelected.remove(col);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDataColumns = tempSelected;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportToCsv() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No data to export.")));
      return;
    }
    final List<Map<String, dynamic>> flattenedData = _reportData.map((row) {
      final Map<String, dynamic> flatRow = {};
      row.forEach((key, value) {
        if (key == 'task_data' && value is Map) {
          (value as Map).forEach((taskKey, taskValue) {
            flatRow[taskKey] = taskValue;
          });
        } else {
          flatRow[key] = value;
        }
      });
      return flatRow;
    }).toList();
    final Set<String> headerSet = {};
    for (var row in flattenedData) {
      headerSet.addAll(row.keys);
    }
    final List<String> orderedHeaders =
        [
          'task_id',
          'project_name',
          'file_name',
          'employee_name',
          'status',
          'completed_at',
          'employee_remarks',
        ]..addAll(
          headerSet.where(
            (h) => ![
              'task_id',
              'project_name',
              'file_name',
              'employee_name',
              'status',
              'completed_at',
              'employee_remarks',
            ].contains(h),
          ),
        );

    List<List<dynamic>> csvData = [orderedHeaders];

    for (var row in flattenedData) {
      csvData.add(orderedHeaders.map((header) => row[header]).toList());
    }

    String csv = const ListToCsvConverter().convert(csvData);
    final Uint8List bytes = Uint8List.fromList(csv.codeUnits);
    final String fileName =
        "report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv";

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'csv',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Report '$fileName' saved successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFiltersSection(),
            const SizedBox(height: 16),
            _buildActionButtons(theme),
            const Divider(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildResultsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: [
          StreamBuilder<List<ProjectModel>>(
            stream: _supabaseService.getAllProjects(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No projects found.');
              }
              return DropdownButtonFormField<ProjectModel>(
                value: _selectedProject,
                hint: const Text('All Projects'),
                items: snapshot.data!
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedProject = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              );
            },
          ),
          StreamBuilder<List<UserModel>>(
            stream: _supabaseService.getEmployees(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No employees found.');
              }
              return DropdownButtonFormField<UserModel>(
                value: _selectedEmployee,
                hint: const Text('All Employees'),
                items: snapshot.data!
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedEmployee = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              );
            },
          ),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            hint: const Text('All Statuses'),
            items: _statuses
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => _selectedStatus = val),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          InputChip(
            avatar: const Icon(Icons.calendar_today),
            label: Text(
              _startDate != null && _endDate != null
                  ? '${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}'
                  : 'Select Date Range',
            ),
            onPressed: () => _selectDateRange(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _generateReport,
          icon: const Icon(Icons.search),
          label: const Text('Generate Report'),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: _clearFilters,
          child: const Text('Clear Filters'),
        ),
        const Spacer(),
        if (_reportData.isNotEmpty) ...[
          TextButton.icon(
            onPressed: _allPossibleDataColumns.isNotEmpty
                ? _showColumnSelectionDialog
                : null,
            icon: const Icon(Icons.view_column_outlined),
            label: const Text('Columns'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _exportToCsv,
            icon: const Icon(Icons.download),
            label: const Text('Export CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsView() {
    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Error: $_errorMessage',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_reportData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            'No data found for the selected filters. Please generate a report.',
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDashboard(),
        const SizedBox(height: 32),
        Text(
          'Tasks per Employee',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BarChart(BarChartData(barGroups: _chartData)),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Detailed Report',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < Breakpoints.tablet) {
              return _buildMobileListView();
            } else {
              return _buildDesktopDataTable();
            }
          },
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    final formatCurrency = NumberFormat.simpleCurrency(decimalDigits: 2);
    final percentagePaid = _totalBilled > 0
        ? (_totalPaid / _totalBilled) * 100
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Dashboard", style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = (constraints.maxWidth / 300).floor().clamp(
              1,
              4,
            );
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                InfoCard(
                  title: "Billed Amount",
                  value: formatCurrency.format(_totalBilled),
                  icon: Icons.monetization_on,
                  color: Colors.blue,
                ),
                InfoCard(
                  title: "Paid Amount",
                  value: formatCurrency.format(_totalPaid),
                  icon: Icons.price_check,
                  color: Colors.green,
                ),
                InfoCard(
                  title: "% Billed vs Paid",
                  value: "${percentagePaid.toStringAsFixed(2)}%",
                  icon: Icons.pie_chart,
                  color: Colors.orange,
                ),
                InfoCard(
                  title: "Worked Claims",
                  value: _workedClaims.toString(),
                  icon: Icons.work,
                  color: Colors.purple,
                ),
                InfoCard(
                  title: "Non-Worked Claims",
                  value: _nonWorkedClaims.toString(),
                  icon: Icons.work_off,
                  color: Colors.red,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          "Claim Bucketing (by Service Date)",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: _claimBuckets.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    entry.value.toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileListView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reportData.length,
      itemBuilder: (context, index) {
        final row = _reportData[index];
        final taskData = row['task_data'] as Map<String, dynamic>? ?? {};
        final title =
            taskData['Task Name'] ??
            taskData['task_name'] ??
            taskData.values.first?.toString() ??
            'Untitled';
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Employee: ${row['employee_name'] ?? 'N/A'}"),
                Text("Project: ${row['project_name'] ?? 'N/A'}"),
                Text("Status: ${row['status'] ?? 'N/A'}"),
                if (row['completed_at'] != null)
                  Text(
                    "Completed: ${DateFormat.yMd().format(DateTime.parse(row['completed_at']))}",
                  ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildDesktopDataTable() {
    final List<String> fixedHeaders = [
      'Project',
      'Employee',
      'Status',
      'Completed',
    ];
    final List<String> dynamicHeaders = _selectedDataColumns.toList()..sort();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            ...fixedHeaders.map(
              (h) => DataColumn(
                label: Text(
                  h,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            ...dynamicHeaders.map(
              (h) => DataColumn(
                label: Text(
                  h,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          rows: _reportData.map((row) {
            final taskData = row['task_data'] as Map<String, dynamic>? ?? {};
            return DataRow(
              cells: [
                DataCell(Text(row['project_name']?.toString() ?? '')),
                DataCell(Text(row['employee_name']?.toString() ?? '')),
                DataCell(Text(row['status']?.toString() ?? '')),
                DataCell(
                  Text(
                    row['completed_at'] != null
                        ? DateFormat.yMd().format(
                            DateTime.parse(row['completed_at']),
                          )
                        : '',
                  ),
                ),
                ...dynamicHeaders.map(
                  (col) => DataCell(Text(taskData[col]?.toString() ?? '')),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<UserModel>>(
        stream: supabaseService.getEmployees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final employees = snapshot.data ?? [];
          if (employees.isEmpty) {
            return const Center(child: Text('No employees found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      employee.name.isNotEmpty
                          ? employee.name[0].toUpperCase()
                          : 'U',
                    ),
                  ),
                  title: Text(
                    employee.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(employee.email),
                  trailing: employee.isActive
                      ? TextButton(
                          onPressed: () => _confirmDeactivateUser(employee),
                          child: const Text(
                            'Deactivate',
                            style: TextStyle(color: Colors.red),
                          ),
                        )
                      : const Chip(
                          label: Text('Deactivated'),
                          padding: EdgeInsets.zero,
                        ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_employee_fab',
        onPressed: () => _showCreateEmployeeDialog(context, authService),
        label: const Text('Add User'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDeactivateUser(UserModel employee) async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate User?'),
        content: Text(
          'Are you sure you want to deactivate ${employee.name}? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabaseService.deactivateUser(employee.uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${employee.name} deactivated.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to deactivate: $e')));
      }
    }
  }

  void _showCreateEmployeeDialog(
    BuildContext context,
    AuthService authService,
  ) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'employee';

    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Create New User'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty || !v.contains('@')
                          ? 'Valid email is required'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(
                          value: 'employee',
                          child: Text('Employee'),
                        ),
                        DropdownMenuItem(
                          value: 'manager',
                          child: Text('Manager'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setStateDialog(() => isLoading = true);
                            try {
                              final tempPassword = await authService
                                  .createEmployee(
                                    email: emailController.text.trim(),
                                    name: nameController.text.trim(),
                                    role: selectedRole,
                                  );
                              Navigator.of(ctx).pop();
                              _showEmployeeCredentialsDialog(
                                context,
                                nameController.text.trim(),
                                emailController.text.trim(),
                                tempPassword,
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: ${e.toString().replaceFirst("Exception: ", "")}',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setStateDialog(() => isLoading = false);
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmployeeCredentialsDialog(
    BuildContext context,
    String name,
    String email,
    String password,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('User Account Created: $name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please share these credentials with the user.'),
            const SizedBox(height: 16),
            Text(
              'Email: $email',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Temporary Password: $password',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Note: This password will only be shown once.',
              style: TextStyle(
                color: Colors.red[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK, I Understand'),
          ),
        ],
      ),
    );
  }
}

// ======== EMPLOYEE SCREENS ========
class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key});

  @override
  _EmployeeHomePageState createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    final currentUser = Provider.of<AuthService>(
      context,
      listen: false,
    ).currentUser;
    if (currentUser != null) {
      _widgetOptions = [
        EmployeeAllTasksView(userId: currentUser.id),
        EmployeeProjectsScreen(userId: currentUser.id),
      ];
    } else {
      _widgetOptions = [const Center(child: Text("Error: User not found."))];
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final titles = ['My Tasks', 'My Projects'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              authService.signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: IndexedStack(index: _selectedIndex, children: _widgetOptions),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_outlined),
            activeIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared_outlined),
            activeIcon: Icon(Icons.folder_shared),
            label: 'Projects',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class EmployeeAllTasksView extends StatelessWidget {
  final String userId;

  const EmployeeAllTasksView({Key? key, required this.userId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabaseService.getAllTasksForUser(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return const Center(child: Text("You have no assigned tasks."));
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return TaskCard(
              task: task,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'To edit, go to Projects > [Project Name] > [File Name]',
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class EmployeeProjectsScreen extends StatelessWidget {
  final String userId;

  const EmployeeProjectsScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    return FutureBuilder<List<ProjectModel>>(
      future: supabaseService.getProjectsForUser(userId),
      builder: (context, projectSnapshot) {
        if (projectSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (projectSnapshot.hasError) {
          return Center(
            child: Text('Error loading projects: ${projectSnapshot.error}'),
          );
        }
        final projects = projectSnapshot.data ?? [];
        if (projects.isEmpty) {
          return const Center(
            child: Text('You are not assigned to any projects yet.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                leading: const Icon(Icons.folder_shared_outlined),
                title: Text(
                  project.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(project.description ?? 'Project tasks'),
                children: <Widget>[
                  FutureBuilder<List<UploadModel>>(
                    future: supabaseService.getUploadsForUserInProject(
                      project.id,
                      userId,
                    ),
                    builder: (context, uploadSnapshot) {
                      if (uploadSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      if (uploadSnapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Error loading uploads: ${uploadSnapshot.error}',
                            ),
                          ),
                        );
                      }
                      final uploads = uploadSnapshot.data ?? [];
                      if (uploads.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'No task files assigned to you in this project.',
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: uploads.map((upload) {
                          return ListTile(
                            leading: const Icon(Icons.file_present_rounded),
                            title: Text(upload.fileName),
                            subtitle: Text(
                              'Uploaded: ${DateFormat.yMMMd().format(upload.createdAt.toLocal())}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaskListScreen(
                                    upload: upload,
                                    project: project,
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ======== DATA GRID & TASK HANDLING ========
class MyCustomDropdown extends StatefulWidget {
  final String? value;
  final List<UserModel> validEmployees;
  final Function(String?) onChanged;
  final DataGridRow row;

  const MyCustomDropdown({
    super.key,
    required this.value,
    required this.validEmployees,
    required this.onChanged,
    required this.row,
  });

  @override
  _MyCustomDropdownState createState() => _MyCustomDropdownState();
}

class _MyCustomDropdownState extends State<MyCustomDropdown> {
  String _getStableRowId(DataGridRow row) {
    try {
      final idCell = row.getCells().firstWhere(
        (cell) => cell.columnName == 'id',
      );
      return idCell.value?.toString() ?? row.hashCode.toString();
    } catch (e) {
      return row.hashCode.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<String>> dropdownItems = _buildDropdownItems();
    String? currentDropdownValue = _getValidatedValue(
      widget.value,
      dropdownItems,
    );
    final String stableRowId = _getStableRowId(widget.row);
    final Key dropdownKey = ValueKey('dd_row_$stableRowId');

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: dropdownKey,
        value: currentDropdownValue,
        hint: const Text(
          'Assign',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        isExpanded: true,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black,
          overflow: TextOverflow.ellipsis,
        ),
        items: dropdownItems,
        onChanged: widget.onChanged,
        selectedItemBuilder: (BuildContext context) {
          return dropdownItems.map((item) {
            return Container(
              alignment: Alignment.centerLeft,
              child: item.child,
            );
          }).toList();
        },
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildDropdownItems() {
    return [
      const DropdownMenuItem<String>(
        value: null,
        child: Text(
          'Unassigned',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      ),
      ...widget.validEmployees.map((employee) {
        String displayName = employee.name.isNotEmpty
            ? employee.name
            : "Unnamed (ID: ${employee.uid.substring(0, 8)}...)";
        return DropdownMenuItem<String>(
          value: employee.uid,
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Colors.black),
          ),
        );
      }).toList(),
    ];
  }

  String? _getValidatedValue(
    String? inputValue,
    List<DropdownMenuItem<String>> items,
  ) {
    bool isValuePresent = items.any((item) => item.value == inputValue);
    return isValuePresent ? inputValue : null;
  }
}

class StatusDropdownEditor extends StatefulWidget {
  final String? value;
  final Function(String?) onChanged;
  final DataGridRow row;

  const StatusDropdownEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.row,
  });

  @override
  _StatusDropdownEditorState createState() => _StatusDropdownEditorState();
}

class _StatusDropdownEditorState extends State<StatusDropdownEditor> {
  final List<String> _statuses = [
    "Not Started",
    "In Progress",
    "Completed",
    "On Hold",
    "Under Review",
  ];

  String? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    if (!_statuses.contains(_currentValue)) {
      _currentValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _currentValue,
        hint: const Text(
          'Select Status',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        isExpanded: true,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black,
          overflow: TextOverflow.ellipsis,
        ),
        items: _statuses.map((String status) {
          return DropdownMenuItem<String>(
            value: status,
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _currentValue = newValue;
          });
          widget.onChanged(newValue);
        },
        selectedItemBuilder: (BuildContext context) {
          return _statuses.map((item) {
            return Container(
              alignment: Alignment.centerLeft,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList();
        },
      ),
    );
  }
}

class TaskDataSource extends DataGridSource {
  List<Map<String, dynamic>> tasks = [];
  List<UserModel> employees = [];
  List<String> _dataColumnNames = [];

  RoleModel? currentUserRoleModel;

  final Map<String, TextEditingController> _textControllers = {};
  final void Function(DataGridRow, String, dynamic) _onCellValueChangedCallback;

  TaskDataSource({
    required List<Map<String, dynamic>> initialTasks,
    required this.employees,
    required this.currentUserRoleModel,
    required void Function(DataGridRow, String, dynamic) onCellValueChanged,
    List<String>? columnOrder,
  }) : _onCellValueChangedCallback = onCellValueChanged {
    if (columnOrder != null && columnOrder.isNotEmpty) {
      _dataColumnNames = columnOrder;
    }
    updateTasks(initialTasks);
  }

  void updateTasks(List<Map<String, dynamic>> newTasks) {
    tasks = newTasks;
    if (_dataColumnNames.isEmpty) {
      _discoverDataColumnNames();
    }
    _buildDataGridRows();
    notifyListeners();
  }

  void updateEmployees(List<UserModel> newEmployees) {
    employees = newEmployees;
    if (rows.isNotEmpty) _buildDataGridRows();
    notifyListeners();
  }

  void updateCurrentUserRole(RoleModel? roleModel) {
    if (currentUserRoleModel != roleModel) {
      currentUserRoleModel = roleModel;
      if (rows.isNotEmpty) _buildDataGridRows();
      notifyListeners();
    }
  }

  void _discoverDataColumnNames() {
    if (tasks.isEmpty) {
      _dataColumnNames = [];
      return;
    }
    final orderedKeys = <String>[];
    final seenKeys = <String>{};

    for (var task in tasks) {
      final taskData = task['data'] as Map<String, dynamic>? ?? {};
      for (var key in taskData.keys) {
        if (seenKeys.add(key)) {
          orderedKeys.add(key);
        }
      }
    }
    _dataColumnNames = orderedKeys;
  }

  void disposeControllers() =>
      _textControllers.forEach((_, controller) => controller.dispose());

  List<DataGridRow> _rows = [];

  @override
  List<DataGridRow> get rows => _rows;

  List<String> _getUnifiedColumnList() {
    return [
      'id',
      'work_date',
      'notes',
      'assignedTo',
      'denial_reason',
      'status',
      'responsible_party',
      'action',
      'employee_remarks',
      ..._dataColumnNames,
    ];
  }

  void _buildDataGridRows() {
    final unifiedColumns = _getUnifiedColumnList();
    _rows = tasks.map<DataGridRow>((task) {
      final taskData = task['data'] as Map<String, dynamic>? ?? {};
      return DataGridRow(
        cells: unifiedColumns.map((colName) {
          dynamic cellValue;
          if (colName == 'id' ||
              colName == 'status' ||
              colName == 'assignedTo' ||
              colName == 'employee_remarks' ||
              colName == 'work_date' ||
              colName == 'notes' ||
              colName == 'denial_reason' ||
              colName == 'responsible_party' ||
              colName == 'action') {
            cellValue = task[colName];
          } else {
            cellValue = taskData[colName];
          }
          return DataGridCell(columnName: colName, value: cellValue);
        }).toList(),
      );
    }).toList();
  }

  List<GridColumn> getColumns(BuildContext? context) {
    GridColumn buildColumn(
      String name,
      String label, {
      double minWidth = 120,
      bool visible = true,
      ColumnWidthMode widthMode = ColumnWidthMode.auto,
    }) {
      return GridColumn(
        columnName: name,
        columnWidthMode: widthMode,
        minimumWidth: minWidth,
        visible: visible,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final unifiedColumns = _getUnifiedColumnList();
    return unifiedColumns.map((name) {
      switch (name) {
        case 'id':
          return buildColumn(name, 'ID', visible: false);
        case 'work_date':
          return buildColumn(name, 'Work Date', minWidth: 130);
        case 'notes':
          return buildColumn(name, 'Notes', minWidth: 250);
        case 'assignedTo':
          return buildColumn(name, 'Assigned To', minWidth: 160);
        case 'denial_reason':
          return buildColumn(name, 'Denial Reason', minWidth: 150);
        case 'status':
          return buildColumn(name, 'Status', minWidth: 130);
        case 'responsible_party':
          return buildColumn(name, 'Responsible Party', minWidth: 150);
        case 'action':
          return buildColumn(name, 'Action', minWidth: 150);
        case 'employee_remarks':
          return buildColumn(name, 'Employee Remarks', minWidth: 250);
        default:
          return buildColumn(name, name.replaceAll("_", " ").capitalizeFirst());
      }
    }).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final bool isAdmin = currentUserRoleModel?.role == 'admin';
    final bool isManager = currentUserRoleModel?.role == 'manager';
    final String currentUserId = currentUserRoleModel?.uid ?? "";

    final Map<String, DataGridCell> cellMap = {
      for (var cell in row.getCells()) cell.columnName: cell,
    };

    final taskDataForRow = tasks.firstWhere(
      (task) => task['id'] == cellMap['id']?.value,
      orElse: () => {},
    );

    if (taskDataForRow.isEmpty) {
      return DataGridRowAdapter(
        cells: [
          Container(
            alignment: Alignment.centerLeft,
            child: const Text("Error: Task data not found."),
          ),
        ],
      );
    }

    final String taskIdForRow = taskDataForRow['id'] as String? ?? 'UNKNOWN_ID';
    final String assignedToUidInRow =
        taskDataForRow['assignedTo'] as String? ?? "";
    final bool isAssignedToCurrentUser = (assignedToUidInRow == currentUserId);

    final unifiedColumns = _getUnifiedColumnList();

    return DataGridRowAdapter(
      cells: unifiedColumns.map<Widget>((columnName) {
        final dataGridCell = cellMap[columnName];
        final cellValue = dataGridCell?.value;
        final contentPadding = const EdgeInsets.symmetric(
          horizontal: 8.0,
          vertical: 12.0,
        );

        Widget buildTextCell(String? text, {bool isFaded = false}) {
          return Container(
            alignment: Alignment.centerLeft,
            padding: contentPadding,
            child: Text(
              text ?? '',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: isFaded ? Colors.grey[600] : Colors.black,
              ),
            ),
          );
        }

        Widget buildEditableCell(String key, {bool isSpecialColumn = false}) {
          final controllerKey = "${taskIdForRow}_$key";
          final controller = _textControllers.putIfAbsent(
            controllerKey,
            () => TextEditingController(
              text:
                  (isSpecialColumn
                          ? taskDataForRow[key]
                          : (taskDataForRow['data'] as Map?)?[key])
                      ?.toString() ??
                  '',
            ),
          );
          controller.text =
              (isSpecialColumn
                      ? taskDataForRow[key]
                      : (taskDataForRow['data'] as Map?)?[key])
                  ?.toString() ??
              '';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Center(
              child: TextFormField(
                controller: controller,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 2.0,
                    horizontal: 4.0,
                  ),
                  isDense: true,
                ),
                onChanged: (newValue) =>
                    _onCellValueChangedCallback(row, key, newValue),
              ),
            ),
          );
        }

        if (columnName == 'id') return const SizedBox.shrink();

        if (columnName == 'status') {
          if (isAssignedToCurrentUser || isAdmin || isManager) {
            return Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: StatusDropdownEditor(
                value: cellValue as String?,
                row: row,
                onChanged: (newValue) =>
                    _onCellValueChangedCallback(row, 'status', newValue),
              ),
            );
          } else {
            return buildTextCell(cellValue?.toString());
          }
        }

        if (columnName == 'assignedTo') {
          if (isAdmin || isManager) {
            return Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: MyCustomDropdown(
                value: cellValue as String?,
                validEmployees: employees
                    .where((e) => e.uid.isNotEmpty)
                    .toList(),
                onChanged: (newValue) =>
                    _onCellValueChangedCallback(row, 'assignedTo', newValue),
                row: row,
              ),
            );
          } else {
            final employee = employees.firstWhere(
              (e) => e.uid == cellValue,
              orElse: () => const UserModel(
                uid: '',
                name: 'Unassigned',
                email: '',
                role: '',
                isActive: false,
              ),
            );
            return buildTextCell(employee.name);
          }
        }

        if (columnName == 'employee_remarks' ||
            columnName == 'notes' ||
            columnName == 'action') {
          return isAssignedToCurrentUser || isAdmin || isManager
              ? buildEditableCell(columnName, isSpecialColumn: true)
              : buildTextCell(cellValue?.toString());
        }

        if (columnName == 'work_date') {
          return isAssignedToCurrentUser || isAdmin || isManager
              ? buildEditableCell(
                  columnName,
                  isSpecialColumn: true,
                ) // This should be a date picker
              : buildTextCell(cellValue?.toString());
        }

        if (columnName == 'denial_reason' ||
            columnName == 'responsible_party') {
          // These should be dropdowns
          return isAssignedToCurrentUser || isAdmin || isManager
              ? buildEditableCell(columnName, isSpecialColumn: true)
              : buildTextCell(cellValue?.toString());
        }

        if (_dataColumnNames.contains(columnName)) {
          return (isAdmin || isManager)
              ? buildEditableCell(columnName)
              : buildTextCell(cellValue?.toString());
        }

        return buildTextCell('Unknown Col: $columnName');
      }).toList(),
    );
  }
}

// ======== TASK SCREENS ========
class ProjectDetailScreen extends StatelessWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.name),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Uploads'),
              Tab(text: 'Summary'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TabBarView(
            children: [
              UploadListScreen(project: project),
              ProjectSummaryScreen(project: project),
            ],
          ),
        ),
      ),
    );
  }
}

class UploadListScreen extends StatelessWidget {
  final ProjectModel project;

  const UploadListScreen({super.key, required this.project});

  Future<void> _pickAndUploadExcel(
    BuildContext context,
    SupabaseService supabaseService,
  ) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) {
      logger.w("File selection was cancelled or file was empty.");
      return;
    }
    PlatformFile file = result.files.single;
    Uint8List fileBytes = file.bytes!;
    String fileName = file.name;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Processing File..."),
            ],
          ),
        ),
      ),
    );

    try {
      List<Map<String, dynamic>> tasksData = [];
      List<String> processedHeaderRow = [];

      void processHeaders(List<String> rawHeaders) {
        int unnamedColumnIndex = 1;
        for (String header in rawHeaders) {
          final trimmedHeader = header.trim();
          if (trimmedHeader.isEmpty) {
            processedHeaderRow.add('unnamed_column_$unnamedColumnIndex');
            unnamedColumnIndex++;
          } else {
            processedHeaderRow.add(trimmedHeader);
          }
        }
      }

      if (fileName.toLowerCase().endsWith('.csv')) {
        final csvString = String.fromCharCodes(fileBytes);
        final List<List<dynamic>> csvTable = const CsvToListConverter(
          shouldParseNumbers: false,
        ).convert(csvString);
        if (csvTable.isEmpty) throw Exception("CSV file is empty.");

        final rawHeaders = csvTable.first.map((e) => e.toString()).toList();
        processHeaders(rawHeaders);

        for (int i = 1; i < csvTable.length; i++) {
          final List<dynamic> dataRow = csvTable[i];
          final Map<String, dynamic> rowData = {};
          for (int j = 0; j < processedHeaderRow.length; j++) {
            final key = processedHeaderRow[j];
            final value = (j < dataRow.length) ? dataRow[j] : null;
            rowData[key] = value?.toString();
          }
          if (rowData.values.any((v) => v != null && v.isNotEmpty)) {
            tasksData.add(rowData);
          }
        }
      } else {
        var excelFile = excel.Excel.decodeBytes(fileBytes);
        if (excelFile.tables.isEmpty ||
            excelFile.tables.values.first.rows.isEmpty) {
          throw Exception("Excel file is empty or has no readable sheets.");
        }
        var sheet = excelFile.tables.values.first;
        final rawHeaders = sheet.rows.first
            .map((cell) => cell?.value?.toString() ?? '')
            .toList();
        processHeaders(rawHeaders);

        for (int i = 1; i < sheet.rows.length; i++) {
          final originalRow = sheet.rows[i];
          final Map<String, dynamic> rowData = {};
          for (int j = 0; j < processedHeaderRow.length; j++) {
            final key = processedHeaderRow[j];
            final cell = (j < originalRow.length) ? originalRow[j] : null;
            dynamic cellValue = cell?.value;

            if (cellValue is excel.DateCellValue) {
              rowData[key] = DateFormat('yyyy-MM-dd').format(
                DateTime(cellValue.year, cellValue.month, cellValue.day),
              );
            } else if (cellValue is excel.DateTimeCellValue) {
              rowData[key] = DateFormat('yyyy-MM-dd HH:mm:ss').format(
                DateTime(
                  cellValue.year,
                  cellValue.month,
                  cellValue.day,
                  cellValue.hour,
                  cellValue.minute,
                  cellValue.second,
                ),
              );
            } else if (cellValue is excel.TimeCellValue) {
              rowData[key] = DateFormat('HH:mm:ss').format(
                DateTime(
                  0,
                  1,
                  1,
                  cellValue.hour,
                  cellValue.minute,
                  cellValue.second,
                ),
              );
            } else {
              rowData[key] = cellValue?.toString();
            }
          }
          if (rowData.values.any((v) => v != null && v.toString().isNotEmpty)) {
            tasksData.add(rowData);
          }
        }
      }

      if (tasksData.isEmpty) {
        throw Exception("No data rows found in the file.");
      }

      await supabaseService.uploadTasksFromExcel(
        project.id,
        fileName,
        tasksData,
        processedHeaderRow,
      );

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$fileName" uploaded successfully!')),
      );
    } catch (e, st) {
      logger.e(
        "Error during file processing and upload.",
        error: e,
        stackTrace: st,
      );
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error processing file: ${e.toString().replaceFirst("Exception: ", "")}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<UploadModel>>(
        stream: supabaseService.getUploadsForProject(project.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final uploads = snapshot.data ?? [];
          if (uploads.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No files uploaded for this project yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: uploads.length,
            itemBuilder: (context, index) {
              final upload = uploads[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.file_present_rounded, size: 30),
                  title: Text(
                    upload.fileName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  subtitle: Text(
                    'Uploaded: ${DateFormat.yMMMd().add_jm().format(upload.createdAt.toLocal())}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TaskListScreen(upload: upload, project: project),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'upload_file_fab',
        onPressed: () => _pickAndUploadExcel(context, supabaseService),
        label: const Text('Upload File'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }
}

class ProjectSummaryScreen extends StatelessWidget {
  final ProjectModel project;

  const ProjectSummaryScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, int>>(
        future: supabaseService.getTaskSummaryForProject(project.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading summary: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No task data available for summary.'),
            );
          }

          final summary = snapshot.data!;
          final totalTasks = summary.values.reduce((a, b) => a + b);

          if (totalTasks == 0) {
            return const Center(
              child: Text('No tasks found in this project to summarize.'),
            );
          }

          final List<PieChartSectionData> sections = [];
          final List<_ChartLegendItem> legendItems = [];
          final colors = {
            'Not Started': Colors.orange[400]!,
            'In Progress': Colors.blue[400]!,
            'Completed': Colors.green[400]!,
            'On Hold': Colors.purple[400]!,
            'Under Review': Colors.yellow[700]!,
          };

          summary.forEach((status, count) {
            if (count > 0) {
              final color = colors[status] ?? Colors.grey[400]!;
              sections.add(
                PieChartSectionData(
                  color: color,
                  value: count.toDouble(),
                  title: '${(count / totalTasks * 100).toStringAsFixed(0)}%',
                  radius: 100.0,
                  titleStyle: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              );
              legendItems.add(
                _ChartLegendItem(color: color, title: '$status ($count)'),
              );
            }
          });

          if (sections.isEmpty) {
            return const Center(
              child: Text(
                'No tasks with defined statuses to display in chart.',
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Status Overview',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Tasks: $totalTasks',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: sections,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Legend',
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
                ),
                const Divider(height: 20),
                ...legendItems.map(
                  (item) => ListTile(
                    leading: Container(
                      width: 16,
                      height: 16,
                      color: item.color,
                    ),
                    title: Text(item.title),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ChartLegendItem {
  final Color color;
  final String title;

  _ChartLegendItem({required this.color, required this.title});
}

class TaskListScreen extends StatefulWidget {
  final UploadModel upload;
  final ProjectModel project;

  const TaskListScreen({
    super.key,
    required this.upload,
    required this.project,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late TaskDataSource _taskDataSource;
  List<UserModel> _employees = [];

  UserModel? _currentUserModel;
  RoleModel? _currentUserRoleModel;

  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  final GlobalKey<SfDataGridState> _dataGridKey = GlobalKey<SfDataGridState>();

  @override
  void initState() {
    super.initState();
    _currentUserModel = Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).userModel;

    if (_currentUserModel != null) {
      _currentUserRoleModel = RoleModel(
        uid: _currentUserModel!.uid,
        role: _currentUserModel!.role,
        name: _currentUserModel!.name,
      );
    }

    _taskDataSource = TaskDataSource(
      initialTasks: [],
      employees: _employees,
      currentUserRoleModel: _currentUserRoleModel,
      onCellValueChanged: _handleCellValueChanged,
      columnOrder: widget.upload.columnOrder,
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    try {
      final employeeList = await supabaseService.getEmployees().first;
      if (mounted) {
        setState(() => _employees = employeeList);
        _taskDataSource.updateEmployees(_employees);
      }
    } catch (e, st) {
      logger.e(
        "TaskListScreen: Error loading employees.",
        error: e,
        stackTrace: st,
      );
    }
  }

  void _handleCellValueChanged(
    DataGridRow row,
    String columnName,
    dynamic newValue,
  ) {
    final taskId = row
        .getCells()
        .firstWhere((c) => c.columnName == 'id')
        .value
        .toString();
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    Map<String, dynamic> updatedFields = {};

    if (columnName == 'status' ||
        columnName == 'assignedTo' ||
        columnName == 'employee_remarks' ||
        columnName == 'work_date' ||
        columnName == 'notes' ||
        columnName == 'denial_reason' ||
        columnName == 'responsible_party' ||
        columnName == 'action') {
      updatedFields[columnName] = newValue;
    } else {
      final originalTask = _taskDataSource.tasks.firstWhere(
        (t) => t['id'] == taskId,
        orElse: () => {},
      );
      if (originalTask.isNotEmpty) {
        Map<String, dynamic> currentData = Map<String, dynamic>.from(
          originalTask['data'] as Map? ?? {},
        );
        currentData[columnName] = newValue;
        updatedFields['data'] = currentData;
      }
    }
    if (updatedFields.isNotEmpty) {
      _debouncer.run(() async {
        try {
          await supabaseService.updateTask(taskId, updatedFields);

          if (mounted) {
            final taskIndex = _taskDataSource.tasks.indexWhere(
              (t) => t['id'] == taskId,
            );
            if (taskIndex != -1) {
              final newTasks = List<Map<String, dynamic>>.from(
                _taskDataSource.tasks,
              );
              final updatedTask = Map<String, dynamic>.from(
                newTasks[taskIndex],
              );

              updatedFields.forEach((key, value) {
                if (key == 'data') {
                  updatedTask['data'] = value;
                } else {
                  updatedTask[key] = value;
                }
              });

              newTasks[taskIndex] = updatedTask;
              _taskDataSource.updateTasks(newTasks);
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error updating task: $e')));
          }
        }
      });
    }
  }

  Future<void> _exportToCsv() async {
    if (_taskDataSource.tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No data to export.")));
      return;
    }

    final List<Map<String, dynamic>> flattenedData = _taskDataSource.tasks.map((
      task,
    ) {
      final Map<String, dynamic> flatRow = {
        'status': task['status'],
        'employee_remarks': task['employee_remarks'],
        'assigned_to': _employees
            .firstWhere(
              (e) => e.uid == task['assignedTo'],
              orElse: () => const UserModel(
                uid: '',
                email: '',
                name: 'Unassigned',
                role: '',
                isActive: false,
              ),
            )
            .name,
      };
      if (task['data'] is Map) {
        (task['data'] as Map).forEach((key, value) {
          flatRow[key.toString()] = value;
        });
      }
      return flatRow;
    }).toList();

    final Set<String> headerSet = {};
    for (var row in flattenedData) {
      headerSet.addAll(row.keys);
    }
    final List<String> orderedHeaders = headerSet.toList()..sort();

    List<List<dynamic>> csvData = [orderedHeaders];
    for (var row in flattenedData) {
      csvData.add(orderedHeaders.map((header) => row[header]).toList());
    }

    String csv = const ListToCsvConverter().convert(csvData);
    final Uint8List bytes = Uint8List.fromList(csv.codeUnits);
    final String fileName =
        "${widget.upload.fileName.replaceAll('.xlsx', '').replaceAll('.csv', '')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";

    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      fileExtension: 'csv',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Report '$fileName' saved successfully!")),
    );
  }

  @override
  void dispose() {
    _taskDataSource.disposeControllers();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _currentUserModel = context.watch<UserModelNotifier>().userModel;
    if (_currentUserModel != null &&
        _currentUserRoleModel?.uid != _currentUserModel!.uid) {
      _currentUserRoleModel = RoleModel(
        uid: _currentUserModel!.uid,
        role: _currentUserModel!.role,
        name: _currentUserModel!.name,
      );
      _taskDataSource.updateCurrentUserRole(_currentUserRoleModel);
    }

    if (_currentUserModel == null) {
      return const Scaffold(
        body: Center(child: Text("User not found. Please re-login.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name, style: const TextStyle(fontSize: 14)),
            Text(
              widget.upload.fileName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export to CSV',
            onPressed: _exportToCsv,
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Provider.of<SupabaseService>(context, listen: false)
            .getTasksForUpload(
              widget.upload.id,
              _currentUserModel!.uid,
              _currentUserModel!.role,
            ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _taskDataSource.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Error fetching tasks: ${snapshot.error}"),
            );
          }

          final tasksToShow = snapshot.data ?? [];
          if (!const DeepCollectionEquality().equals(
            _taskDataSource.tasks.map((t) => t['id']).toList(),
            tasksToShow.map((t) => t['id']).toList(),
          )) {
            _taskDataSource.updateTasks(tasksToShow);
          }

          if (tasksToShow.isEmpty &&
              snapshot.connectionState == ConnectionState.active) {
            final message =
                (_currentUserModel!.role == 'admin' ||
                    _currentUserModel!.role == 'manager')
                ? 'No tasks found in this file.'
                : 'No tasks have been assigned to you in this file.';
            return Center(child: Text(message));
          }

          return ResponsiveLayout(
            mobileBody: ListView.builder(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 8,
                left: 16,
                right: 16,
              ),
              itemCount: tasksToShow.length,
              itemBuilder: (context, index) {
                final task = tasksToShow[index];
                final employee = _employees.firstWhere(
                  (e) => e.uid == task['assignedTo'],
                  orElse: () => const UserModel(
                    uid: '',
                    email: '',
                    name: 'Unassigned',
                    role: '',
                    isActive: false,
                  ),
                );
                return TaskCard(
                  task: task,
                  project: widget.project,
                  assignedEmployee: employee,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(
                          task: task,
                          employees: _employees,
                          project: widget.project,
                          upload: widget.upload,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            tabletBody: SfDataGrid(
              key: _dataGridKey,
              source: _taskDataSource,
              columns: _taskDataSource.getColumns(context),
              columnWidthMode: ColumnWidthMode.auto,
              allowEditing: true,
              selectionMode: SelectionMode.none,
              navigationMode: GridNavigationMode.cell,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
            ),
            desktopBody: SfDataGrid(
              key: _dataGridKey,
              source: _taskDataSource,
              columns: _taskDataSource.getColumns(context),
              columnWidthMode: ColumnWidthMode.auto,
              allowEditing: true,
              selectionMode: SelectionMode.none,
              navigationMode: GridNavigationMode.cell,
              gridLinesVisibility: GridLinesVisibility.both,
              headerGridLinesVisibility: GridLinesVisibility.both,
            ),
          );
        },
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final UserModel? assignedEmployee;
  final ProjectModel? project;
  final VoidCallback onTap;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onTap,
    this.assignedEmployee,
    this.project,
  }) : super(key: key);

  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskData = task['data'] as Map<String, dynamic>? ?? {};
    final status = task['status']?.toString() ?? 'Not Started';

    final Color statusColor;
    final IconData statusIcon;
    switch (status) {
      case 'In Progress':
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Completed':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'On Hold':
        statusColor = Colors.purple.shade700;
        statusIcon = Icons.pause_circle_filled_rounded;
        break;
      case 'Under Review':
        statusColor = Colors.yellow.shade800;
        statusIcon = Icons.rate_review_rounded;
        break;
      default: // Not Started
        statusColor = Colors.grey.shade600;
        statusIcon = Icons.rocket_launch_outlined;
    }

    final title =
        taskData['Task Name'] ??
        taskData['task_name'] ??
        taskData.values.first?.toString() ??
        'Untitled Task';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(statusIcon, color: statusColor, size: 16),
                    label: Text(status),
                    backgroundColor: statusColor.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              if (project != null) ...[
                _buildInfoRow(context, Icons.folder_open, project!.name),
                const SizedBox(height: 8),
              ],
              _buildInfoRow(
                context,
                Icons.person_outline,
                assignedEmployee?.name ?? 'Unassigned',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final List<UserModel> employees;
  final ProjectModel project;
  final UploadModel upload;

  const TaskDetailScreen({
    Key? key,
    required this.task,
    required this.employees,
    required this.project,
    required this.upload,
  }) : super(key: key);

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Map<String, dynamic> _currentTask;
  final Map<String, TextEditingController> _controllers = {};
  final Debouncer _debouncer = Debouncer(milliseconds: 700);
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentTask = Map<String, dynamic>.from(widget.task);
    final taskData = _currentTask['data'] as Map<String, dynamic>? ?? {};
    _controllers['status'] = TextEditingController(
      text: _currentTask['status']?.toString() ?? '',
    );
    _controllers['employee_remarks'] = TextEditingController(
      text: _currentTask['employee_remarks']?.toString() ?? '',
    );
    taskData.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value?.toString() ?? '');
    });
  }

  void _updateTask(String key, dynamic value) {
    _debouncer.run(() {
      final supabase = Provider.of<SupabaseService>(context, listen: false);
      Map<String, dynamic> updatePayload = {};

      if (key == 'status' || key == 'assignedTo' || key == 'employee_remarks') {
        updatePayload[key] = value;
      } else {
        final Map<String, dynamic> currentData = Map.from(_currentTask['data']);
        currentData[key] = value;
        updatePayload['data'] = currentData;
      }

      supabase.updateTask(_currentTask['id'], updatePayload);
    });
  }

  void _postComment() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final user = Provider.of<UserModelNotifier>(
      context,
      listen: false,
    ).userModel;
    final supabase = Provider.of<SupabaseService>(context, listen: false);

    if (user != null) {
      supabase
          .addComment(_currentTask['id'], comment, user)
          .then((_) {
            _commentController.clear();
            FocusScope.of(context).unfocus();
          })
          .catchError((e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error posting comment: $e')),
            );
          });
    }
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    _commentController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userModel = context.watch<UserModelNotifier>().userModel;

    final bool isPrivilegedUser =
        userModel?.role == 'admin' || userModel?.role == 'manager';
    final bool isAssignedToCurrentUser =
        _currentTask['assignedTo'] == userModel?.uid;

    final bool canEditProtectedFields = isAssignedToCurrentUser;

    final taskData = _currentTask['data'] as Map<String, dynamic>? ?? {};
    final title =
        taskData['Task Name'] ?? taskData['task_name'] ?? 'Task Details';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, "Task Overview"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatusDropdown(canEditProtectedFields),
                    const SizedBox(height: 16),
                    _buildAssigneeDropdown(isPrivilegedUser),
                  ],
                ),
              ),
            ),
            _buildSectionHeader(context, "Task Data"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: taskData.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildTextField(
                        entry.key,
                        entry.key.capitalizeFirst(),
                        isPrivilegedUser,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            _buildSectionHeader(context, "Employee Remarks"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTextField(
                  'employee_remarks',
                  'Add comments or updates',
                  canEditProtectedFields,
                ),
              ),
            ),
            _buildSectionHeader(context, "Sub-tasks"),
            _buildSubTaskList(),
            _buildSectionHeader(context, "Comments"),
            _buildCommentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontSize: 20),
      ),
    );
  }

  Widget _buildTextField(String key, String label, bool canEdit) {
    return TextFormField(
      controller: _controllers[key],
      readOnly: !canEdit,
      maxLines: (key == 'employee_remarks') ? 5 : 1,
      decoration: InputDecoration(
        labelText: label,
        filled: !canEdit,
        fillColor: !canEdit ? Colors.grey[100] : Colors.white,
        suffixIcon: canEdit
            ? null
            : const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
      ),
      onChanged: (value) {
        if (canEdit) _updateTask(key, value);
      },
    );
  }

  Widget _buildStatusDropdown(bool canEdit) {
    final statuses = [
      "Not Started",
      "In Progress",
      "Completed",
      "On Hold",
      "Under Review",
    ];
    String currentStatus = _currentTask['status'] ?? 'Not Started';
    if (!statuses.contains(currentStatus)) {
      currentStatus = "Not Started";
    }

    return DropdownButtonFormField<String>(
      value: currentStatus,
      decoration: InputDecoration(
        labelText: 'Status',
        filled: !canEdit,
        fillColor: !canEdit ? Colors.grey[100] : Colors.white,
      ),
      items: statuses
          .map((status) => DropdownMenuItem(value: status, child: Text(status)))
          .toList(),
      onChanged: canEdit ? (value) => _updateTask('status', value) : null,
    );
  }

  Widget _buildAssigneeDropdown(bool canEdit) {
    String? currentAssignedUid = _currentTask['assignedTo'] as String?;
    if (currentAssignedUid != null &&
        !widget.employees.any((e) => e.uid == currentAssignedUid)) {
      currentAssignedUid = null;
    }

    return DropdownButtonFormField<String>(
      value: currentAssignedUid,
      decoration: InputDecoration(
        labelText: 'Assigned To',
        filled: !canEdit,
        fillColor: !canEdit ? Colors.grey[100] : Colors.white,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Unassigned',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        ...widget.employees
            .map((e) => DropdownMenuItem(value: e.uid, child: Text(e.name)))
            .toList(),
      ],
      onChanged: canEdit ? (value) => _updateTask('assignedTo', value) : null,
    );
  }

  Widget _buildSubTaskList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Sub-task functionality to be implemented here.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                ),
              ],
            ),
            const Divider(height: 24),
            StreamBuilder<List<TaskCommentModel>>(
              stream: supabase.getComments(_currentTask['id']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No comments yet.');
                }
                final comments = snapshot.data!;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return ListTile(
                      title: Text(
                        comment.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(comment.comment),
                      trailing: Text(
                        DateFormat.yMd().add_jm().format(
                          comment.createdAt.toLocal(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
