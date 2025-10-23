import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/notes/notes_cubit.dart';
import '../../../core/theme/app_theme.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  final String? initialTitle;
  final String? initialContent;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.initialTitle,
    this.initialContent,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _selectedCategory;
  final List<String> _tags = [];
  bool _isEncrypted = false;
  bool _showAISummary = false;
  String? _aiSummary;
  List<String>? _aiInsights;
  List<String>? _aiKeyPoints;

  final List<String> _categories = [
    'Work',
    'Personal',
    'Ideas',
    'Projects',
    'Shopping',
    'Health',
    'Finance',
    'Travel',
    'Learning',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty) {
      return;
    }

    final notesCubit = context.read<NotesCubit>();

    if (widget.noteId == null) {
      // Create new note
      await notesCubit.createNote(
        title: _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
        content: _contentController.text,
        category: _selectedCategory,
        tags: _tags,
        encrypt: _isEncrypted,
        autoSummarize: true,
      );
    } else {
      // Update existing note
      await notesCubit.updateNote(
        id: widget.noteId!,
        title: _titleController.text,
        content: _contentController.text,
        category: _selectedCategory,
        tags: _tags,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _generateSummary() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some content first')),
      );
      return;
    }

    setState(() => _showAISummary = true);
    
    // Mock AI summary for now
    setState(() {
      _aiSummary = 'This note discusses important topics and action items.';
      _aiInsights = [
        'Contains actionable tasks',
        'References future dates',
        'Includes important decisions',
      ];
      _aiKeyPoints = [
        'Complete project by deadline',
        'Follow up with team',
        'Review budget allocation',
      ];
    });
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
        actions: [
          IconButton(
            icon: Icon(
              _isEncrypted ? Icons.lock : Icons.lock_open,
              color: _isEncrypted ? AppTheme.aiPurple : null,
            ),
            onPressed: () {
              setState(() => _isEncrypted = !_isEncrypted);
            },
            tooltip: _isEncrypted ? 'Encrypted' : 'Not encrypted',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _generateSummary,
            tooltip: 'Generate AI Summary',
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveNote,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          // Title input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          // Category and tags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // Category dropdown
                DropdownButton<String>(
                  value: _selectedCategory,
                  hint: const Text('Category'),
                  underline: Container(),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                ),
                const SizedBox(width: 16),
                // Tags
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ..._tags.map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () => _removeTag(tag),
                            deleteIconColor: Colors.grey,
                          )),
                      ActionChip(
                        label: const Icon(Icons.add, size: 16),
                        onPressed: () => _showAddTagDialog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: 'Start typing...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ),

          // AI Summary card
          if (_showAISummary) _buildAISummaryCard(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveNote,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
    );
  }

  Widget _buildAISummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: ExpansionTile(
          leading: Icon(Icons.auto_awesome, color: AppTheme.aiPurple),
          title: const Text('AI Summary'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _showAISummary = false),
          ),
          initiallyExpanded: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_aiSummary != null) ...[
                    Text(
                      'Summary',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(_aiSummary!),
                    const SizedBox(height: 16),
                  ],
                  if (_aiInsights != null && _aiInsights!.isNotEmpty) ...[
                    Text(
                      'Insights',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ..._aiInsights!.map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• '),
                              Expanded(child: Text(insight)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (_aiKeyPoints != null && _aiKeyPoints!.isNotEmpty) ...[
                    Text(
                      'Key Points',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ..._aiKeyPoints!.map((point) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('✓ '),
                              Expanded(child: Text(point)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tag name',
          ),
          autofocus: true,
          onSubmitted: (value) {
            _addTag(value);
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _addTag(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
