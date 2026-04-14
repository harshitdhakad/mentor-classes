import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    required this.dueDate,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final bool done;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dueDate': dueDate.toIso8601String(),
        'done': done,
      };

  static TodoItem fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'] as String,
        title: j['title'] as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        done: j['done'] == true,
      );
}

/// Local storage To-Do screen using shared_preferences
class LocalStudentTodoScreen extends ConsumerStatefulWidget {
  const LocalStudentTodoScreen({super.key});

  @override
  ConsumerState<LocalStudentTodoScreen> createState() => _LocalStudentTodoScreenState();
}

class _LocalStudentTodoScreenState extends ConsumerState<LocalStudentTodoScreen> {
  final _input = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate;
  List<TodoItem> _todos = [];

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getString('todos');
    if (todosJson != null) {
      final List<dynamic> decoded = jsonDecode(todosJson);
      setState(() {
        _todos = decoded.map((j) => TodoItem.fromJson(j as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = jsonEncode(_todos.map((t) => t.toJson()).toList());
    await prefs.setString('todos', todosJson);
  }

  Future<void> _addTodo() async {
    if (_input.text.trim().isEmpty || _selectedDate == null) {
      return;
    }

    final todo = TodoItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: _input.text.trim(),
      dueDate: _selectedDate!,
    );

    setState(() {
      _todos.add(todo);
      _todos.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    });

    await _saveTodos();

    _input.clear();
    _dateController.clear();
    setState(() => _selectedDate = null);
  }

  Future<void> _toggleTodo(String todoId) async {
    setState(() {
      final index = _todos.indexWhere((t) => t.id == todoId);
      if (index != -1) {
        _todos[index] = TodoItem(
          id: _todos[index].id,
          title: _todos[index].title,
          dueDate: _todos[index].dueDate,
          done: !_todos[index].done,
        );
      }
    });

    await _saveTodos();
  }

  Future<void> _deleteTodo(String todoId) async {
    setState(() {
      _todos.removeWhere((t) => t.id == todoId);
    });

    await _saveTodos();
  }

  @override
  void dispose() {
    _input.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // To-Do Entry Section
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New To-Do',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.deepBlue,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                decoration: InputDecoration(
                  labelText: 'Task description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Due date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text = '${picked.day}/${picked.month}/${picked.year}';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addTodo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deepBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Add To-Do',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        // To-Do List
        Expanded(
          child: _todos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No to-dos yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _todos.length,
                  itemBuilder: (context, index) {
                    final todo = _todos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: todo.done,
                          onChanged: (_) => _toggleTodo(todo.id),
                        ),
                        title: Text(
                          todo.title,
                          style: GoogleFonts.poppins(
                            decoration: todo.done ? TextDecoration.lineThrough : null,
                            color: todo.done ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          'Due: ${todo.dueDate.day}/${todo.dueDate.month}/${todo.dueDate.year}',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteTodo(todo.id),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Developer Credits
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Text(
            'Developed by Mentor Classes ERP Team',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
