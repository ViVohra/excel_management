// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, avoid_print

import 'dart:async';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role;
  final bool isActive;

  UserModel({
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
}

class ProjectModel {
  final String id;
  final String name;
  final String? description;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  ProjectModel({
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
}

class SupabaseService with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  static const _getAdminSummaryRpc = 'get_admin_dashboard_summary';
  static const _getAllTasksForUserRpc = 'get_all_tasks_for_user';
  static const _getUploadsForUserInProjectRpc =
      'get_uploads_for_user_in_project';
  static const _getProjectsForUserRpc = 'get_projects_for_user';
  static const _getFullReportDataRpc = 'get_full_report_data';

  Future<List<Map<String, dynamic>>> getFullReportData() async {
    logger.d('Fetching full report data.');
    try {
      final response = await _supabase.rpc(_getFullReportDataRpc);
      logger.i('Successfully fetched full report data.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      logger.e('Error fetching full report data', error: e, stackTrace: st);
      throw Exception('Failed to fetch report data: $e');
    }
  }

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
    logger.d('Setting up stream for employees.');
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
    logger.d('Setting up stream for projects.');
    return _supabase.from('projects').stream(primaryKey: ['id']).map((maps) {
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

  // ======== NEW/MODIFIED & CORRECTED SECTION: updateTask method ========
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

      // if status is being changed, fetch old status and set timestamps
      if (newStatus != null) {
        final currentTaskResponse = await _supabase
            .from('tasks')
            .select('status, started_at')
            .eq('id', taskId)
            .single();

        oldStatus = currentTaskResponse['status'] as String?;
        final currentStartedAt = currentTaskResponse['started_at'];

        if (oldStatus != newStatus) {
          // If task is started for the first time, set started_at
          if (oldStatus == 'Not Started' &&
              newStatus != 'Not Started' &&
              currentStartedAt == null) {
            updatePayload['started_at'] = DateTime.now().toIso8601String();
          }

          // If task is completed, set completed_at
          if (newStatus == 'Completed') {
            updatePayload['completed_at'] = DateTime.now().toIso8601String();
          } else {
            // If task is reopened, nullify completed_at
            updatePayload['completed_at'] = null;
          }
        }
      }

      // Update the task table
      await _supabase.from('tasks').update(updatePayload).eq('id', taskId);

      // If status changed, insert a record into the history table
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

  // ======== NEW/MODIFIED SECTION: New RPC methods for reporting ========
  Future<Map<String, dynamic>> getReportOverview(
    DateTimeRange dateRange,
  ) async {
    final params = {
      'start_date': DateFormat('yyyy-MM-dd').format(dateRange.start),
      'end_date': DateFormat('yyyy-MM-dd').format(dateRange.end),
    };
    logger.d('Fetching report overview with params: $params');
    try {
      final response = await _supabase.rpc(
        'get_report_overview',
        params: params,
      );
      // Explicitly cast the data to the correct type
      final Map<String, dynamic> overview = {
        'kpis': <String, dynamic>{},
        'pie_chart_data': <String, dynamic>{},
      };

      final List<dynamic> data = response;
      for (var item in data) {
        // Convert each 'item' to a Map<String, dynamic> here
        final Map<String, dynamic> metricMap = Map<String, dynamic>.from(item);
        final String metric = metricMap['metric'] as String;
        final num value = metricMap['value'] as num;

        if (metric == 'tasks_completed' ||
            metric == 'overdue_tasks' ||
            metric == 'tasks_in_progress') {
          (overview['kpis'] as Map<String, dynamic>)[metric] = value.toDouble();
        } else {
          (overview['pie_chart_data'] as Map<String, dynamic>)[metric] = value
              .toDouble();
        }
      }
      logger.i('Successfully fetched report overview.');
      return overview;
    } catch (e, st) {
      logger.e('Error fetching report overview', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getProjectSummaries(
    DateTimeRange dateRange,
  ) async {
    final params = {
      'start_date': DateFormat('yyyy-MM-dd').format(dateRange.start),
      'end_date': DateFormat('yyyy-MM-dd').format(dateRange.end),
    };
    logger.d('Fetching project summaries with params: $params');
    try {
      final response = await _supabase.rpc(
        'get_project_summaries',
        params: params,
      );
      logger.i('Successfully fetched project summaries.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      logger.e('Error fetching project summaries', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getEmployeePerformance(
    DateTimeRange dateRange,
  ) async {
    final params = {
      'start_date': DateFormat('yyyy-MM-dd').format(dateRange.start),
      'end_date': DateFormat('yyyy-MM-dd').format(dateRange.end),
    };
    logger.d('Fetching employee performance with params: $params');
    try {
      final response = await _supabase.rpc(
        'get_employee_performance',
        params: params,
      );
      logger.i('Successfully fetched employee performance.');
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      logger.e('Error fetching employee performance', error: e, stackTrace: st);
      rethrow;
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
    if (_userModel?.uid != newUserModel?.uid) {
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
      theme: _buildThemeData(),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildThemeData() {
    const primaryColor = Colors.teal;
    final secondaryColor = Colors.amber[700]!;
    const backgroundColor = Color(0xFFF8F9FA);
    const surfaceColor = Colors.white;
    const onPrimaryColor = Colors.white;
    const onSecondaryColor = Colors.black;
    final onBackgroundColor = Colors.grey[850]!;
    final onSurfaceColor = Colors.grey[850]!;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
        surface: surfaceColor,
        onPrimary: onPrimaryColor,
        onSecondary: onSecondaryColor,
        onBackground: onBackgroundColor,
        onSurface: onSurfaceColor,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: onSurfaceColor,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: onSurfaceColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: onSurfaceColor.withOpacity(0.8),
          height: 1.5,
        ),
        bodySmall: TextStyle(fontSize: 12, color: Colors.grey[600]),
        labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: onPrimaryColor,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: onPrimaryColor,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        color: surfaceColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
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
          foregroundColor: onPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          elevation: 2,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: onSecondaryColor,
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        backgroundColor: surfaceColor,
        elevation: 4,
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
                        Icons.manage_accounts_rounded,
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
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
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

  final GlobalKey<_AdminDashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<_EmployeeListScreenState> _employeeListKey = GlobalKey();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      AdminDashboardScreen(key: _dashboardKey),
      const ProjectListScreen(),
      EmployeeListScreen(key: _employeeListKey),
      const AdminReportingScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final titles = [
      'Dashboard',
      'Manage Projects',
      'Manage Employees',
      'Reporting',
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
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
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
            activeIcon: Icon(Icons.people_alt),
            label: 'Employees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
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
                Text('Could not load dashboard data. Error: ${snapshot.error}'),
                const SizedBox(height: 10),
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, Admin!",
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Here is a summary of your workspace.",
                  style: theme.textTheme.bodyMedium,
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
                                  style: theme.textTheme.bodyMedium,
                                ),
                                trailing: Text(
                                  entry.value.toString(),
                                  style: theme.textTheme.titleLarge,
                                ),
                              );
                            }).toList(),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
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
    final supabaseService = Provider.of<SupabaseService>(context);
    return Scaffold(
      body: StreamBuilder<List<ProjectModel>>(
        stream: supabaseService.getProjects(),
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
                child: ListTile(
                  leading: CircleAvatar(
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
                  trailing: const Icon(Icons.chevron_right),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_project_fab',
        onPressed: () => _showCreateProjectDialog(context, supabaseService),
        label: const Text('New Project'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context, SupabaseService service) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

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
                              final adminHomePageState = context
                                  .findAncestorStateOfType<
                                    _AdminHomePageState
                                  >();
                              adminHomePageState?._dashboardKey.currentState
                                  ?.refresh();
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
                      : const Text(
                          'Deactivated',
                          style: TextStyle(color: Colors.grey),
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
        final adminHomePageState = context
            .findAncestorStateOfType<_AdminHomePageState>();
        adminHomePageState?._dashboardKey.currentState?.refresh();
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
                              final adminHomePageState = context
                                  .findAncestorStateOfType<
                                    _AdminHomePageState
                                  >();
                              adminHomePageState?._dashboardKey.currentState
                                  ?.refresh();
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

// ======== NEW/MODIFIED SECTION: Complete Redesign of AdminReportingScreen ========

class AdminReportingScreen extends StatefulWidget {
  const AdminReportingScreen({super.key});

  @override
  State<AdminReportingScreen> createState() => _AdminReportingScreenState();
}

class _AdminReportingScreenState extends State<AdminReportingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (newDateRange != null) {
      setState(() {
        _dateRange = newDateRange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildDateRangeSelector(),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey[600],
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
              Tab(icon: Icon(Icons.folder_copy), text: 'Projects'),
              Tab(icon: Icon(Icons.person), text: 'Employees'),
              Tab(icon: Icon(Icons.table_chart), text: 'Data Export'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ReportOverviewTab(
                  dateRange: _dateRange,
                  key: ValueKey(_dateRange),
                ),
                ProjectReportsTab(
                  dateRange: _dateRange,
                  key: ValueKey(_dateRange),
                ),
                EmployeePerformanceTab(
                  dateRange: _dateRange,
                  key: ValueKey(_dateRange),
                ),
                DataExportTab(dateRange: _dateRange, key: ValueKey(_dateRange)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Report for:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 10),
          ActionChip(
            avatar: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              '${DateFormat.yMd().format(_dateRange.start)} - ${DateFormat.yMd().format(_dateRange.end)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onPressed: _selectDateRange,
          ),
        ],
      ),
    );
  }
}

// --- Tab 1: Overview ---
class ReportOverviewTab extends StatelessWidget {
  final DateTimeRange dateRange;

  const ReportOverviewTab({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    return FutureBuilder<Map<String, dynamic>>(
      future: supabaseService.getReportOverview(dateRange),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No data for this period."));
        }

        final overview = snapshot.data!;

        // Safe Casting
        final kpis = overview['kpis'] is Map
            ? Map<String, dynamic>.from(overview['kpis'])
            : <String, dynamic>{};
        final pieData = overview['pie_chart_data'] is Map
            ? Map<String, dynamic>.from(overview['pie_chart_data'])
            : <String, dynamic>{};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Key Metrics",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
                children: [
                  InfoCard(
                    title: "Tasks Completed",
                    value: kpis['tasks_completed']?.toInt().toString() ?? '0',
                    icon: Icons.check,
                    color: Colors.green,
                  ),
                  InfoCard(
                    title: "Tasks In Progress",
                    value: kpis['tasks_in_progress']?.toInt().toString() ?? '0',
                    icon: Icons.construction,
                    color: Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "Task Status Breakdown",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SizedBox(height: 250, child: _buildPieChart(pieData)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart(Map<String, dynamic> data) {
    final List<PieChartSectionData> sections = [];
    final colors = {
      'Not Started': Colors.orange[400]!,
      'In Progress': Colors.blue[400]!,
      'Completed': Colors.green[400]!,
      'On Hold': Colors.purple[400]!,
      'Under Review': Colors.yellow[700]!,
    };
    final total = data.values.fold(0.0, (sum, item) => sum + item);

    if (total == 0) return const Center(child: Text("No task data."));

    data.forEach((status, value) {
      sections.add(
        PieChartSectionData(
          color: colors[status] ?? Colors.grey,
          value: value.toDouble(),
          title: '${(value / total * 100).toStringAsFixed(0)}%',
          radius: 80,
          titleStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return PieChart(PieChartData(sections: sections, centerSpaceRadius: 40));
  }
}

// --- Tab 2: Project Reports ---
class ProjectReportsTab extends StatelessWidget {
  final DateTimeRange dateRange;

  const ProjectReportsTab({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabaseService.getProjectSummaries(dateRange),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return const Center(child: Text("No project data for this period."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            final total = (project['total_tasks'] as int?) ?? 0;
            final completed = (project['completed_tasks'] as int?) ?? 0;
            final progress = total > 0 ? completed / total : 0.0;

            return Card(
              child: ListTile(
                title: Text(
                  project['project_name'],
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress, minHeight: 6),
                      const SizedBox(height: 4),
                      Text("$completed of $total tasks completed"),
                    ],
                  ),
                ),
                trailing: Text(
                  "${(progress * 100).toStringAsFixed(0)}%",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Tab 3: Employee Performance ---
class EmployeePerformanceTab extends StatelessWidget {
  final DateTimeRange dateRange;

  const EmployeePerformanceTab({super.key, required this.dateRange});

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabaseService.getEmployeePerformance(dateRange),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final employees = snapshot.data ?? [];
        if (employees.isEmpty) {
          return const Center(child: Text("No employee data for this period."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: employees.length,
          itemBuilder: (context, index) {
            final employee = employees[index];
            final assigned = (employee['assigned_tasks'] as int?) ?? 0;
            final completed = (employee['completed_tasks'] as int?) ?? 0;
            final rate = assigned > 0 ? (completed / assigned * 100) : 0;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(employee['employee_name'][0]),
                ),
                title: Text(
                  employee['employee_name'],
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text("Completed: $completed | Assigned: $assigned"),
                trailing: Text(
                  "${rate.toStringAsFixed(0)}% Done",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Tab 4: Data Export ---
class DataExportTab extends StatefulWidget {
  final DateTimeRange dateRange;

  const DataExportTab({super.key, required this.dateRange});

  @override
  _DataExportTabState createState() => _DataExportTabState();
}

class _DataExportTabState extends State<DataExportTab> {
  late Future<List<Map<String, dynamic>>> _reportDataFuture;
  List<Map<String, dynamic>> _sourceData = [];
  List<Map<String, dynamic>> _filteredData = [];
  ReportDataSource? _dataSource;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant DataExportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dateRange != oldWidget.dateRange) {
      _loadData();
    }
  }

  void _loadData() {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    _reportDataFuture = supabaseService.getFullReportData().then((data) {
      if (mounted) {
        setState(() {
          _sourceData = data;
          _applyFilters();
        });
      }
      return data;
    });
  }

  void _applyFilters() {
    _filteredData = _sourceData.where((row) {
      final createdAt = DateTime.tryParse(row['created_at'] ?? '');
      if (createdAt == null) return false;
      return createdAt.isAfter(widget.dateRange.start) &&
          createdAt.isBefore(widget.dateRange.end);
    }).toList();
    setState(() {
      _dataSource = ReportDataSource(_filteredData);
    });
  }

  void _exportToCsv() async {
    if (_filteredData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No data to export.")));
      return;
    }

    List<List<dynamic>> rows = [];
    if (_filteredData.isNotEmpty) {
      rows.add(_filteredData.first.keys.toList());
      for (var row in _filteredData) {
        rows.add(row.values.toList());
      }
    }

    String csv = const ListToCsvConverter().convert(rows);

    logger.i("----- CSV DATA -----\n$csv\n----- END CSV DATA -----");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("CSV data printed to console for demonstration."),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _exportToCsv,
              icon: const Icon(Icons.download),
              label: const Text("Export as CSV"),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _reportDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _sourceData.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (_dataSource == null || _filteredData.isEmpty) {
                return const Center(child: Text("No data for this period."));
              }
              return SfDataGrid(
                source: _dataSource!,
                columns: _dataSource!.getColumns(),
                columnWidthMode: ColumnWidthMode.auto,
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReportDataSource extends DataGridSource {
  List<Map<String, dynamic>> _reportData = [];
  List<DataGridRow> _rows = [];

  ReportDataSource(List<Map<String, dynamic>> reportData) {
    _reportData = reportData;
    _buildDataGridRows();
  }

  @override
  List<DataGridRow> get rows => _rows;

  void _buildDataGridRows() {
    _rows = _reportData.map<DataGridRow>((row) {
      return DataGridRow(
        cells: row.entries.map((entry) {
          return DataGridCell(columnName: entry.key, value: entry.value);
        }).toList(),
      );
    }).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(cell.value?.toString() ?? ''),
        );
      }).toList(),
    );
  }

  List<GridColumn> getColumns() {
    if (_reportData.isEmpty) return [];

    return _reportData.first.keys.map((key) {
      return GridColumn(
        columnName: key,
        label: Container(
          padding: const EdgeInsets.all(8.0),
          alignment: Alignment.centerLeft,
          child: Text(
            key.replaceAll('_', ' ').capitalizeFirst(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }).toList();
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
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
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
          padding: const EdgeInsets.all(8),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
    if (currentUserRoleModel?.uid != roleModel?.uid) {
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
    final Set<String> columnNames = {};
    for (var task in tasks) {
      if (task['data'] is Map) {
        (task['data'] as Map<String, dynamic>).keys.forEach(columnNames.add);
      }
    }
    columnNames.removeAll(['id', 'status', 'assignedTo', 'employee_remarks']);
    _dataColumnNames = columnNames.toList()..sort();
  }

  void disposeControllers() =>
      _textControllers.forEach((_, controller) => controller.dispose());

  List<DataGridRow> _rows = [];

  @override
  List<DataGridRow> get rows => _rows;

  void _buildDataGridRows() {
    _rows = tasks.map<DataGridRow>((task) {
      final List<DataGridCell> cells = [
        DataGridCell<String>(
          columnName: 'id',
          value: task['id'] as String? ?? 'N/A_ID',
        ),
        DataGridCell<String>(
          columnName: 'status',
          value: task['status'] as String? ?? 'Not Started',
        ),
        DataGridCell<String>(
          columnName: 'assignedTo',
          value: task['assignedTo'] as String?,
        ),
        DataGridCell<String>(
          columnName: 'employee_remarks',
          value: task['employee_remarks'] as String?,
        ),
      ];
      final taskData = task['data'] as Map<String, dynamic>? ?? {};
      for (var colName in _dataColumnNames) {
        cells.add(
          DataGridCell<dynamic>(columnName: colName, value: taskData[colName]),
        );
      }
      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final bool isAdmin = currentUserRoleModel?.role == 'admin';
    final bool isManager = currentUserRoleModel?.role == 'manager';
    final String currentUserId = currentUserRoleModel?.uid ?? "";

    final taskDataForRow = tasks.firstWhere(
      (task) =>
          task['id'] ==
          row.getCells().firstWhere((c) => c.columnName == 'id').value,
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

    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        final String columnName = dataGridCell.columnName;
        final dynamic cellValue = dataGridCell.value;
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

        if (columnName == 'id') return buildTextCell(cellValue?.toString());

        if (columnName == 'employee_remarks') {
          // Employees can only edit remarks on tasks assigned to them.
          final bool canEditRemarks =
              !isAdmin && !isManager && isAssignedToCurrentUser;

          return canEditRemarks
              ? buildEditableCell(columnName, isSpecialColumn: true)
              : buildTextCell(cellValue?.toString());
        }

        if (columnName == 'status') {
          final bool canEditStatus = isAdmin || isManager || isAssignedToCurrentUser;
          return canEditStatus
              ? buildEditableCell(columnName, isSpecialColumn: true)
              : buildTextCell(cellValue?.toString(), isFaded: true);
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
              orElse: () => UserModel(
                uid: '',
                name: 'Unassigned',
                email: '',
                role: '',
                isActive: false,
              ),
            );
            return buildTextCell(employee.name, isFaded: true);
          }
        }

        if (_dataColumnNames.contains(columnName)) {
          return (isAdmin || isManager)
              ? buildEditableCell(columnName)
              : buildTextCell(cellValue?.toString(), isFaded: true);
        }

        return buildTextCell('Col: $columnName?');
      }).toList(),
    );
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

    return [
      buildColumn('id', 'ID', visible: false),
      buildColumn('status', 'Status', minWidth: 130),
      buildColumn('assignedTo', 'Assigned To', minWidth: 160),
      ..._dataColumnNames
          .map(
            (colName) => buildColumn(
              colName,
              colName.replaceAll("_", " ").capitalizeFirst(),
            ),
          )
          .toList(),
      buildColumn(
        'employee_remarks',
        'Employee Remarks',
        minWidth: 250,
        widthMode: ColumnWidthMode.fill,
      ),
    ];
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
        body: TabBarView(
          children: [
            UploadListScreen(project: project),
            ProjectSummaryScreen(project: project),
          ],
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
    if (result != null && result.files.single.bytes != null) {
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
        List<Map<String, dynamic>> tasksData;
        List<String> headerRow;

        if (fileName.toLowerCase().endsWith('.csv')) {
          final csvString = String.fromCharCodes(fileBytes);
          final List<List<dynamic>> csvTable = const CsvToListConverter()
              .convert(csvString);
          if (csvTable.length < 2) {
            throw Exception(
              "CSV file must have a header row and at least one data row.",
            );
          }

          headerRow = csvTable[0]
              .map((e) => e.toString().trim())
              .where((header) => header.isNotEmpty)
              .toList();

          if (headerRow.isEmpty) {
            throw Exception("No valid column headers found in the CSV file.");
          }

          tasksData = [];
          for (int i = 1; i < csvTable.length; i++) {
            final List<dynamic> cleanedDataRow = csvTable[i]
                .where((cell) => cell?.toString().trim().isNotEmpty ?? false)
                .toList();
            final Map<String, dynamic> rowData = {};
            for (int j = 0; j < headerRow.length; j++) {
              if (j < cleanedDataRow.length) {
                rowData[headerRow[j]] = cleanedDataRow[j];
              } else {
                rowData[headerRow[j]] = null;
              }
            }
            if (rowData.isNotEmpty) {
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

          headerRow = sheet.rows.first
              .map((cell) => cell?.value?.toString().trim() ?? '')
              .where((header) => header.isNotEmpty)
              .toList();

          if (headerRow.isEmpty) {
            throw Exception("No valid column headers found in the Excel file.");
          }

          tasksData = [];
          for (int i = 1; i < sheet.rows.length; i++) {
            var originalRow = sheet.rows[i];
            var cleanedDataRow = originalRow
                .where((cell) => cell?.value != null)
                .map((cell) => cell!.value)
                .toList();
            Map<String, dynamic> rowData = {};
            for (int j = 0; j < headerRow.length; j++) {
              dynamic cellValue;
              if (j < cleanedDataRow.length) {
                cellValue = cleanedDataRow[j];
                if (cellValue is excel.DateCellValue) {
                  rowData[headerRow[j]] = DateFormat('yyyy-MM-dd').format(
                    DateTime(cellValue.year, cellValue.month, cellValue.day),
                  );
                } else if (cellValue is excel.DateTimeCellValue) {
                  rowData[headerRow[j]] = DateFormat('yyyy-MM-dd HH:mm:ss')
                      .format(
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
                  rowData[headerRow[j]] = DateFormat('HH:mm:ss').format(
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
                  rowData[headerRow[j]] = cellValue?.toString();
                }
              } else {
                rowData[headerRow[j]] = null;
              }
            }
            if (rowData.values.any(
              (v) => v != null && v.toString().isNotEmpty,
            )) {
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
          headerRow,
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
    } else {
      logger.w("File selection was cancelled or file was empty.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(context);

    return Scaffold(
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
                child: ListTile(
                  leading: const Icon(Icons.file_present_rounded, size: 30),
                  title: Text(
                    upload.fileName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 16),
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
            padding: const EdgeInsets.all(16.0),
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
    if (_currentUserModel != null) {
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
          _taskDataSource.updateTasks(tasksToShow);

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
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              itemCount: tasksToShow.length,
              itemBuilder: (context, index) {
                final task = tasksToShow[index];
                final employee = _employees.firstWhere(
                  (e) => e.uid == task['assignedTo'],
                  orElse: () => UserModel(
                    uid: '',
                    email: '',
                    name: 'Unassigned',
                    role: '',
                    isActive: false,
                  ),
                );
                return TaskCard(
                  task: task,
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
  final VoidCallback onTap;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onTap,
    this.assignedEmployee,
  }) : super(key: key);

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
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text('Assigned to:', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      assignedEmployee?.name ?? 'Unassigned',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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

    // Combine admin and manager into a single check
    final bool isPrivilegedUser =
        userModel?.role == 'admin' || userModel?.role == 'manager';
    final bool isAssignedToCurrentUser =
        _currentTask['assignedTo'] == userModel?.uid;

    // Employees can edit remarks if the task is assigned to them.
    final bool canEditRemarks = !isPrivilegedUser && isAssignedToCurrentUser;

    // Admins, managers, or the assigned employee can edit the status.
    final bool canEditStatus = isPrivilegedUser || isAssignedToCurrentUser;

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
                    _buildStatusDropdown(canEditStatus),
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
                  canEditRemarks, // <-- Use the new and correct condition here
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
