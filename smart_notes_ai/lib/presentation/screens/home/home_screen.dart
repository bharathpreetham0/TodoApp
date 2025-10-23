import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/notes/notes_cubit.dart';
import '../../bloc/tasks/tasks_cubit.dart';
import '../../bloc/search/search_cubit.dart';
import '../../bloc/settings/settings_cubit.dart';
import '../note_editor/note_editor_screen.dart';
import '../../../data/models/task_model.dart';
import '../../../core/theme/app_theme.dart';

/// Home screen with bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const NotesListScreen(),
    const TasksScreen(),
    const SearchScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotesCubit>().loadNotes();
      context.read<TasksCubit>().loadTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NoteEditorScreen(),
                  ),
                ).then((_) {
                  // Reload notes after editing
                  context.read<NotesCubit>().loadNotes();
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('New Note'),
            )
          : _currentIndex == 1
              ? FloatingActionButton(
                  onPressed: () => _showAddTaskDialog(),
                  child: const Icon(Icons.add),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.note_outlined),
            selectedIcon: Icon(Icons.note),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_outlined),
            selectedIcon: Icon(Icons.task),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog() async {
    final descController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Task'),
        content: TextField(
          controller: descController,
          decoration: const InputDecoration(
            hintText: 'Task description',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (descController.text.isNotEmpty) {
                context.read<TasksCubit>().createTask(
                      description: descController.text,
                    );
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Notes list screen
class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Notes AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              if (value == 'all') {
                context.read<NotesCubit>().filterByCategory(null);
              } else {
                context.read<NotesCubit>().filterByCategory(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Notes')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'Work', child: Text('Work')),
              const PopupMenuItem(value: 'Personal', child: Text('Personal')),
              const PopupMenuItem(value: 'Ideas', child: Text('Ideas')),
              const PopupMenuItem(value: 'Projects', child: Text('Projects')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<NotesCubit, NotesState>(
        builder: (context, state) {
          if (state is NotesLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is NotesError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<NotesCubit>().loadNotes(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (state is NotesLoaded) {
            if (state.notes.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.note_add_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withAlpha((0.5 * 255).round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notes yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the button below to create your first note',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: state.notes.length,
              itemBuilder: (context, index) {
                final note = state.notes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.summary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            note.summary!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Updated ${_formatDate(note.updatedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: note.isEncrypted
                        ? const Icon(Icons.lock, size: 16)
                        : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NoteEditorScreen(
                            noteId: note.id,
                            initialTitle: note.title,
                            initialContent: note.content,
                          ),
                        ),
                      ).then((_) {
                        context.read<NotesCubit>().loadNotes();
                      });
                    },
                  ),
                );
              },
            );
          }
          
          return const SizedBox();
        },
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Tasks screen
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          BlocBuilder<TasksCubit, TasksState>(
            builder: (context, state) {
              if (state is TasksLoaded) {
                return IconButton(
                  icon: Icon(
                    state.showCompleted
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    context.read<TasksCubit>().toggleShowCompleted();
                  },
                  tooltip: state.showCompleted
                      ? 'Hide completed'
                      : 'Show completed',
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: BlocBuilder<TasksCubit, TasksState>(
        builder: (context, state) {
          if (state is TasksLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is TasksError) {
            return Center(child: Text(state.message));
          }
          
          if (state is TasksLoaded) {
            final tasks = state.showCompleted
                ? state.tasks
                : state.pendingTasks;
                
            if (tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary.withAlpha((0.5 * 255).round()),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No tasks yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.isCompleted,
                      onChanged: (value) {
                        context.read<TasksCubit>().toggleTask(
                              task.id,
                              task.isCompleted,
                            );
                      },
                    ),
                    title: Text(
                      task.description,
                      style: TextStyle(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: task.dueDate != null
                        ? Text(
                            'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                            style: TextStyle(
                              color: task.isOverdue
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (task.priority == TaskPriority.high)
                          const Icon(
                            Icons.priority_high,
                            color: Colors.red,
                            size: 20,
                          )
                        else if (task.priority == TaskPriority.medium)
                          Icon(
                            Icons.circle,
                            color: Colors.orange,
                            size: 12,
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            context.read<TasksCubit>().deleteTask(task.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          
          return const SizedBox();
        },
      ),
    );
  }
}

/// Search screen
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ask anything about your notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<SearchCubit>().clear();
                  },
                ),
              ),
              onSubmitted: (query) {
                context.read<SearchCubit>().semanticSearch(query);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        context.read<SearchCubit>().search(
                              _searchController.text,
                            );
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        context.read<SearchCubit>().semanticSearch(
                              _searchController.text,
                            );
                      }
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AI Search'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.aiPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state is SearchLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state is SearchError) {
                    return Center(child: Text(state.message));
                  }
                  
                  if (state is SearchResults) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.aiAnswer != null) ...[
                          Card(
                            color: AppTheme.aiPurple.withAlpha((0.1 * 255).round()),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: AppTheme.aiPurple,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'AI Answer',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(state.aiAnswer!),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          '${state.results.length} result(s)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: state.results.length,
                            itemBuilder: (context, index) {
                              final note = state.results[index];
                              return Card(
                                child: ListTile(
                                  title: Text(note.title),
                                  subtitle: Text(
                                    note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => NoteEditorScreen(
                                          noteId: note.id,
                                          initialTitle: note.title,
                                          initialContent: note.content,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  
                  return const Center(
                    child: Text('Enter a query to search your notes'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              const SizedBox(height: 8),
              _buildSection(
                context,
                title: 'AI Features',
                children: [
                  SwitchListTile(
                    title: const Text('Enable AI'),
                    subtitle: const Text('Use on-device AI for summarization and search'),
                    value: state.aiEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleAI(value);
                    },
                  ),
                  ListTile(
                    title: const Text('AI Model'),
                    subtitle: const Text('Phi-3-mini Q4 (Mock Mode)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'Privacy & Security',
                children: [
                  SwitchListTile(
                    title: const Text('Encrypt Notes'),
                    subtitle: const Text('Protect your notes with encryption'),
                    value: state.encryptionEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleEncryption(value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Biometric Lock'),
                    subtitle: const Text('Require fingerprint or face ID'),
                    value: state.biometricEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleBiometric(value);
                    },
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'Notifications',
                children: [
                  SwitchListTile(
                    title: const Text('Daily Digest'),
                    subtitle: const Text('Get a summary every morning'),
                    value: state.dailyDigestEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleDailyDigest(value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Task Reminders'),
                    subtitle: const Text('Notify me about upcoming tasks'),
                    value: state.taskRemindersEnabled,
                    onChanged: (value) {
                      context.read<SettingsCubit>().toggleTaskReminders(value);
                    },
                  ),
                ],
              ),
              _buildSection(
                context,
                title: 'About',
                children: [
                  const ListTile(
                    title: Text('Version'),
                    subtitle: Text('1.0.0 (MVP)'),
                  ),
                  ListTile(
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Open Source'),
                    subtitle: const Text('View on GitHub'),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () {},
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}
