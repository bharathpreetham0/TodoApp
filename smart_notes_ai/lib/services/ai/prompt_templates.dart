/// AI Prompt Templates for Smart Notes AI
class PromptTemplates {
  /// System prompt for summarization
  static const String summarizationSystem = '''
You are Smart Notes AI — an offline assistant that helps users summarize notes.
You must never send data externally. Always output in structured JSON format.
Be concise, accurate, and extract the most important information.
Output format: {"summary": "string", "insights": ["string"], "key_points": ["string"]}
''';

  /// User prompt template for summarization
  static String summarizationUser(String noteContent) => '''
Summarize the following note in 1-2 sentences and extract key insights and points:

$noteContent

Return only valid JSON with keys: summary, insights (array of 2-3 strings), key_points (array of 3-5 strings).
''';

  /// System prompt for task extraction
  static const String taskExtractionSystem = '''
You are Smart Notes AI — an offline assistant that extracts actionable tasks from notes.
Identify tasks, to-dos, action items, and deadlines.
Output structured JSON only.
Output format: {"tasks": [{"description": "string", "priority": 0-2, "due_date": "YYYY-MM-DD or null"}], "reminders": [{"task": "string", "date": "string", "time": "string or null"}]}
''';

  /// User prompt template for task extraction
  static String taskExtractionUser(String noteContent) => '''
Extract all actionable tasks, to-dos, and reminders from this note:

$noteContent

Identify:
- Tasks and action items
- Deadlines and due dates
- Priority levels (0=low, 1=medium, 2=high)
- Time-based reminders

Return only valid JSON with keys: tasks (array), reminders (array).
''';

  /// System prompt for semantic search
  static const String searchSystem = '''
You are Smart Notes AI — an offline assistant that helps users find information in their notes.
Answer queries based only on the provided notes context.
Be concise and reference which note contains the information.
If information is not found in the notes, say so clearly.
''';

  /// User prompt template for semantic search
  static String searchUser(String query, List<String> relevantNotes) => '''
User Query: $query

Available Notes:
${relevantNotes.asMap().entries.map((e) => 'Note ${e.key + 1}:\n${e.value}').join('\n\n')}

Answer the user's query based on the notes above. Be specific and reference note numbers.
''';

  /// System prompt for reminder suggestion
  static const String reminderSuggestionSystem = '''
You are Smart Notes AI — an offline assistant that suggests reminders from notes.
Detect date/time references and suggest appropriate reminders.
Output structured JSON only.
Output format: {"reminders": [{"title": "string", "description": "string", "suggested_time": "YYYY-MM-DD HH:MM"}]}
''';

  /// User prompt template for reminder suggestion
  static String reminderSuggestionUser(String noteContent) => '''
Analyze this note and suggest reminders for any time-sensitive items:

$noteContent

Look for:
- Specific dates and times
- Relative times (tomorrow, next week, etc.)
- Deadlines and appointments
- Events and meetings

Return only valid JSON with suggested reminders.
''';

  /// System prompt for daily digest
  static const String dailyDigestSystem = '''
You are Smart Notes AI — an offline assistant that creates daily summaries.
Summarize the user's notes, tasks, and priorities for the day.
Be encouraging and helpful in tone.
Keep it concise but informative.
''';

  /// User prompt template for daily digest
  static String dailyDigestUser({
    required List<String> todayNotes,
    required List<String> pendingTasks,
    required List<String> upcomingReminders,
  }) => '''
Create a daily digest for the user based on:

Today's Notes (${todayNotes.length}):
${todayNotes.isEmpty ? 'None' : todayNotes.take(5).join('\n')}

Pending Tasks (${pendingTasks.length}):
${pendingTasks.isEmpty ? 'None' : pendingTasks.take(10).join('\n')}

Upcoming Reminders (${upcomingReminders.length}):
${upcomingReminders.isEmpty ? 'None' : upcomingReminders.take(5).join('\n')}

Create a concise, helpful daily summary highlighting priorities and next steps.
''';

  /// System prompt for smart categorization
  static const String categorizationSystem = '''
You are Smart Notes AI — an offline assistant that categorizes notes.
Suggest appropriate categories and tags based on note content.
Output structured JSON only.
Output format: {"category": "string", "tags": ["string"]}
''';

  /// User prompt template for categorization
  static String categorizationUser(String noteContent) => '''
Suggest a category and relevant tags for this note:

$noteContent

Common categories: Work, Personal, Ideas, Projects, Shopping, Health, Finance, Travel, Learning
Tags should be single words or short phrases (max 5 tags).

Return only valid JSON with keys: category (string), tags (array of strings).
''';

  /// Extract JSON from model response
  static String? extractJson(String response) {
    // Try to find JSON in the response
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (jsonMatch != null) {
      return jsonMatch.group(0);
    }
    
    // Try to find JSON array
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
    if (arrayMatch != null) {
      return arrayMatch.group(0);
    }
    
    return null;
  }

  /// Build complete prompt with system and user messages
  static String buildPrompt({
    required String system,
    required String user,
  }) {
    return '''<|system|>
$system<|end|>
<|user|>
$user<|end|>
<|assistant|>
''';
  }
}
