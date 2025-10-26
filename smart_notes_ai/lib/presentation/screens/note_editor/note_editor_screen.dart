import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/notes/notes_cubit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/speech/speech_service.dart';

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
  
  // Speech-to-text
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  String? _speechError;

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
    _initializeSpeech();
  }
  
  Future<void> _initializeSpeech() async {
    final initialized = await _speechService.initialize();
    if (!initialized && mounted) {
      setState(() {
        _speechError = 'Speech recognition not available';
      });
    }
    
    // Listen to speech service streams
    _speechService.listeningStream.listen((isListening) {
      if (mounted) {
        setState(() {
          _isListening = isListening;
        });
      }
    });
    
    _speechService.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _speechError = error;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _speechService.dispose();
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
  
  Future<void> _toggleSpeechToText() async {
    await _speechService.toggleListening(
      onResult: (text, isFinal) {
        // Get current cursor position
        final currentText = _contentController.text;
        final selection = _contentController.selection;
        final cursorPos = selection.baseOffset;
        
        if (cursorPos >= 0) {
          // Insert speech text at cursor position
          final newText = currentText.substring(0, cursorPos) +
              text +
              currentText.substring(cursorPos);
          
          _contentController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(
              offset: cursorPos + text.length,
            ),
          );
        } else {
          // If no cursor position, append to end
          _contentController.text = currentText + ' ' + text;
        }
      },
      continuous: false,
    );
  }
  
  Future<void> _showLanguageSelector() async {
    final locales = await _speechService.getAvailableLocales();
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: locales.length,
            itemBuilder: (context, index) {
              final locale = locales[index];
              final isSelected = locale.localeId == _speechService.currentLocale;
              
              return ListTile(
                title: Text(locale.name),
                subtitle: Text(locale.localeId),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () {
                  _speechService.setLocale(locale.localeId);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.noteId == null ? 'New Note' : 'Edit Note'),
        actions: [
          // Language selector for speech-to-text
          if (_speechService.isInitialized)
            IconButton(
              icon: const Icon(Icons.language),
              onPressed: _showLanguageSelector,
              tooltip: 'Select Language',
            ),
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
              child: Stack(
                children: [
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: 'Start typing or tap the mic button...',
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                  // Microphone button overlay
                  if (_speechService.isInitialized)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _toggleSpeechToText,
                        backgroundColor: _isListening
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
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
