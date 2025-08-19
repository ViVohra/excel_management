// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, avoid_print

import 'dart:async';
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
    printTime: true,
  ),
);

// ======== THEME DEFINITION (CENTRALIZED) ========
class AppTheme {
  static ThemeData build() {
    const primaryColor = Color(0xFF00796B); // A slightly deeper teal
    const secondaryColor = Color(0xFFFFA000); // A richer amber
    const backgroundColor = Color(0xFFF5F7FA); // A softer off-white
    const surfaceColor = Colors.white;
    const textColor = Color(0xFF333333);
    const borderColor = Color(0xFFE0E0E0);

    final baseTheme = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(
      baseTheme.textTheme,
    ).apply(bodyColor: textColor, displayColor: textColor);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: textColor,
        onSurface: textColor,
        error: const Color(0xFFD32F2F),
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
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0.5,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
        color: surfaceColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: borderColor),
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
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 1,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
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
        unselectedItemColor: Colors.grey[500],
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

  const ProjectModel({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.startDate,
    this.endDate,
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

// ======== SERVICES ========
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

  Future<void> signUpAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    logger.i('Attempting to sign up new admin: $email');
    try {
      final response = await _supabase
          .from('users')
          .select('uid')
          .eq('role', 'admin');
      if (response.isNotEmpty) {
        throw Exception('An admin account already exists.');
      }
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (authResponse.user == null) {
        throw Exception('User creation failed in Auth.');
      }
      await _supabase.from('users').insert({
        'uid': authResponse.user!.id,
        'email': email,
        'role': 'admin',
        'name': name,
        'isActive': true,
      });
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
        throw Exception('$role creation failed in Auth.');
      }
      await _supabase.from('users').insert({
        'uid': authResponse.user!.id,
        'email': email,
        'role': role,
        'name': name,
        'isActive': true,
      });
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
      throw Exception(e.message);
    } catch (e, st) {
      logger.e(
        'General exception during sign-in for $email',
        error: e,
        stackTrace: st,
      );
      if (e.toString().contains('Failed host lookup')) {
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

  static const _getAdminSummaryRpc = 'get_admin_dashboard_summary';
  static const _getAllTasksForUserRpc = 'get_all_tasks_for_user';
  static const _getUploadsForUserInProjectRpc =
      'get_uploads_for_user_in_project';
  static const _getProjectsForUserRpc = 'get_projects_for_user';

  Future<Map<String, dynamic>> getAdminDashboardSummary() async {
    logger.d('Fetching admin dashboard summary.');
    try {
      final response = await _supabase.rpc(_getAdminSummaryRpc);
      logger.i('Successfully fetched admin dashboard summary.');
      return response as Map<String, dynamic>;
    } catch (e, st) {
      logger.e(
        'Error getting admin dashboard summary',
        error: e,
        stackTrace: st,
      );
      return {};
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

  Stream<List<ProjectModel>> getProjects() {
    logger.d('Setting up stream for all projects.');
    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true) // Added ordering for consistency
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
    try {
      await _supabase.from('projects').insert({
        'name': name,
        'description': description,
        'status': 'Not Started',
      });
      logger.i('Project "$name" created successfully.');
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
    // Log the intention to update for clear debugging trails.
    logger.i('Attempting to update project: $projectId with name: $name');

    try {
      // 1. Perform the database query and wait for it to complete.
      // The .select() is added to ensure the query returns a result,
      // which helps in verifying the operation's success.
      await _supabase
          .from('projects')
          .update({'name': name, 'description': description})
          .eq('id', projectId)
          .select(); // Ensures the update is fully processed.

      // 2. Log the successful outcome.
      logger.i(
        'Project "$name" (ID: $projectId) updated successfully in the database.',
      );

      // 3. Signal to the UI to rebuild. This is the key to an instant refresh.
      // Any widget listening with a `Consumer` will now refetch its data.
      notifyListeners();
    } on PostgrestException catch (e, st) {
      // --- Specific Error Handling for Database Issues ---
      logger.e(
        'A database error occurred while updating project: $projectId',
        error: e,
        stackTrace: st,
      );

      // Check for a unique constraint violation (e.g., duplicate project name).
      if (e.code == '23505') {
        throw Exception(
          'A project with this name already exists. Please choose a different name.',
        );
      }

      // For any other database error, provide a clear but generic message.
      throw Exception('A database error occurred. Please try again later.');
    } catch (e, st) {
      // --- General Error Handling for any other exceptions (network, etc.) ---
      logger.e(
        'An unexpected error occurred while updating project: $projectId',
        error: e,
        stackTrace: st,
      );

      // Provide a generic, user-friendly message for unknown errors.
      throw Exception(
        'An unexpected error occurred. Please check your connection and try again.',
      );
    }
  }

  Future<void> deleteProject(BuildContext context, String projectId) async {
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
    return MaterialApp(
      title: 'Project Management App',
      theme: AppTheme.build(),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ======== AUTH & NAVIGATION ========
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserModelNotifier>(
      builder: (context, userNotifier, child) {
        final authService = context.watch<AuthService>();

        if (authService.currentUser == null) {
          return const AuthScreen();
        }

        final userModel = userNotifier.userModel;

        if (userModel == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userModel.isActive == false) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account has been deactivated.'),
              ),
            );
            Provider.of<AuthService>(context, listen: false).signOut();
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        switch (userModel.role) {
          case 'admin':
          case 'manager':
            return const AdminHomePage();
          case 'employee':
          default:
            return const EmployeeHomePage();
        }
      },
    );
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
    if (email.isEmpty || !email.contains('@')) {
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
  final Widget desktopBody;

  const ResponsiveLayout({
    Key? key,
    required this.mobileBody,
    required this.desktopBody,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return mobileBody;
        } else {
          return desktopBody;
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                Text(value, style: theme.textTheme.headlineMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ======== ADMIN SCREENS ========
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      const AdminDashboardScreen(),
      const ProjectListScreen(),
      const EmployeeListScreen(),
      const ReportingScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userModel = Provider.of<UserModelNotifier>(context).userModel;
    final titles = [
      'Welcome, ${userModel?.name ?? 'Admin'}',
      'Manage Projects',
      'Manage Employees',
      'Reporting & Analytics',
    ];
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
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt_rounded),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Reporting',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
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
  late Future<Map<String, dynamic>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _fetchSummary();
  }

  Future<Map<String, dynamic>> _fetchSummary() {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    return supabaseService.getAdminDashboardSummary();
  }

  void refresh() {
    setState(() {
      _summaryFuture = _fetchSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
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
                Text('${snapshot.error}', style: theme.textTheme.bodySmall),
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
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
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
                ),
                const SizedBox(height: 24),
                Text(
                  "Task Status Overview",
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: taskSummary.isNotEmpty
                        ? Column(
                            children: taskSummary.entries.map((entry) {
                              return ListTile(
                                title: Text(
                                  entry.key,
                                  style: theme.textTheme.bodyLarge,
                                ),
                                trailing: Text(
                                  entry.value.toString(),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              );
                            }).toList(),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<ProjectModel>>(
        stream: Provider.of<SupabaseService>(context).getProjects(),
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
                  trailing: isAdmin
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
      floatingActionButton: isAdmin
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
      onSelected: (value) {
        if (value == 'edit') {
          _showEditProjectDialog(context, project);
        } else if (value == 'delete') {
          Provider.of<SupabaseService>(
            context,
            listen: false,
          ).deleteProject(context, project.id);
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
  // === STATE FOR FILTERS ===
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

  // === STATE FOR DATA AND UI ===
  bool _isLoading = false;
  List<Map<String, dynamic>> _reportData = [];
  String? _errorMessage;

  // NEW: State for dynamic columns
  List<String> _allPossibleDataColumns = [];
  Set<String> _selectedDataColumns = {};

  // NEW: State for the chart
  List<BarChartGroupData> _chartData = [];
  late SupabaseService _supabaseService;
  bool _isServiceInitialized = false;

  // === LIFECYCLE METHODS ===
  @override
  void initState() {
    super.initState();
    // NEW: Set default date range to the current month on first load
    _setDefaultDateRange();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isServiceInitialized) {
      _supabaseService = Provider.of<SupabaseService>(context, listen: false);
      _isServiceInitialized = true;
      // NEW: Automatically generate report on first load with default dates
      // FIX: The callback must accept a Duration argument, which we ignore with _.
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateReport());
    }
  }

  // === DATA HANDLING AND PROCESSING ===
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
      // Clear previous chart data
      _allPossibleDataColumns = []; // Clear previous dynamic columns
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
        // NEW: Process data for charts and columns after fetching
        _processChartData(data);
        _discoverDataColumns(data);
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
  } // NEW: Processes fetched data to generate chart data

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

  // NEW: Discovers all possible dynamic columns from the 'task_data' field
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

  // === UI HELPER METHODS ===
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

  // NEW: Shows a dialog to let the user select which extra columns to display
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
    // ... (This method remains unchanged) ...
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
  } // === MAIN BUILD METHOD ===

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
            // --- FILTERS ---
            _buildFiltersSection(), const SizedBox(height: 16),
            // --- ACTION BUTTONS ---
            _buildActionButtons(theme),
            const Divider(height: 32),

            // --- RESULTS (CHARTS AND TABLE) ---
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildResultsView(),
          ],
        ),
      ),
    );
  } // === WIDGET BUILDER METHODS ===

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
          // ... (Dropdown filters remain the same) ...
          StreamBuilder<List<ProjectModel>>(
            stream: _supabaseService.getProjects(),
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
          // NEW: Button to select which data columns to show
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
        // --- CHART SECTION ---
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
        // --- DATA TABLE / LIST VIEW SECTION ---
        Text(
          'Detailed Report',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        // NEW: Responsive layout for the data display
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return _buildMobileListView();
            } else {
              return _buildDesktopDataTable();
            }
          },
        ),
      ],
    );
  } // NEW: Refactored mobile view

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

  // NEW: Desktop data table view
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
    // Discover columns only if they weren't provided from the database
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
    final seenKeys = <String>{}; // Use a Set for fast lookups

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

  // --- SINGLE SOURCE OF TRUTH FOR COLUMN ORDER ---
  List<String> _getUnifiedColumnList() {
    return [
      'id',
      'status',
      'assignedTo',
      'employee_remarks',
      ..._dataColumnNames, // The dynamic columns from the Excel file
    ];
  }

  // REWRITTEN to use the unified column list
  void _buildDataGridRows() {
    final unifiedColumns = _getUnifiedColumnList();
    _rows = tasks.map<DataGridRow>((task) {
      final taskData = task['data'] as Map<String, dynamic>? ?? {};
      return DataGridRow(
        cells: unifiedColumns.map((colName) {
          dynamic cellValue;
          // Get the value from the correct part of the task map
          if (colName == 'id' ||
              colName == 'status' ||
              colName == 'assignedTo' ||
              colName == 'employee_remarks') {
            cellValue = task[colName];
          } else {
            // It's a dynamic column from the 'data' map
            cellValue = taskData[colName];
          }
          return DataGridCell(columnName: colName, value: cellValue);
        }).toList(),
      );
    }).toList();
  }

  // REWRITTEN to use the unified column list
  @override
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
        case 'status':
          return buildColumn(name, 'Status', minWidth: 130);
        case 'assignedTo':
          return buildColumn(name, 'Assigned To', minWidth: 160);
        case 'employee_remarks':
          return buildColumn(name, 'Employee Remarks', minWidth: 250);
        default: // This handles all dynamic columns from the Excel file
          return buildColumn(name, name.replaceAll("_", " ").capitalizeFirst());
      }
    }).toList();
  }

  // REWRITTEN AND ROBUST to use the master column list as its guide
  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final bool isAdmin = currentUserRoleModel?.role == 'admin';
    final bool isManager = currentUserRoleModel?.role == 'manager';
    final String currentUserId = currentUserRoleModel?.uid ?? "";

    // Create a map for quick cell lookup by column name.
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

    // Get the master list of columns. This is our guide.
    final unifiedColumns = _getUnifiedColumnList();

    // Build the list of widgets by iterating through the master list,
    // guaranteeing the order matches the headers.
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
          if (isAssignedToCurrentUser) {
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

        if (columnName == 'employee_remarks') {
          return isAssignedToCurrentUser
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
        processedHeaderRow, // Pass the processed headers to the database
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
        columnName == 'employee_remarks') {
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
            FocusScope.of(context).unfocus(); // Dismiss keyboard
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
