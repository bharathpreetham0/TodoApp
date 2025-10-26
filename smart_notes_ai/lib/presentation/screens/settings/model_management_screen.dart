import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../services/ai/model_downloader.dart';
import '../../../services/ai/ai_service.dart';

class ModelManagementScreen extends StatefulWidget {
  final AIService aiService;

  const ModelManagementScreen({
    Key? key,
    required this.aiService,
  }) : super(key: key);

  @override
  State<ModelManagementScreen> createState() => _ModelManagementScreenState();
}

class _ModelManagementScreenState extends State<ModelManagementScreen> {
  Map<ModelSize, bool> _downloadedModels = {};
  Map<ModelSize, double> _downloadProgress = {};
  bool _isLoading = true;
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _loadModelStatus();
  }

  Future<void> _loadModelStatus() async {
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final downloader = widget.aiService.modelDownloader;

      for (final size in ModelSize.values) {
        final isDownloaded = await downloader.isModelDownloaded(size);
        _downloadedModels[size] = isDownloaded;
      }

      _totalSize = await downloader.getTotalModelsSize();
    } catch (e) {
      debugPrint('Error loading model status: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _downloadModel(ModelSize size) async {
    final downloader = widget.aiService.modelDownloader;

    setState(() {
      _downloadProgress[size] = 0.0;
    });

    try {
      final status = await downloader.downloadModel(
        size: size,
        onProgress: (progress, downloaded, total) {
          setState(() {
            _downloadProgress[size] = progress;
          });
        },
      );

      if (status == DownloadStatus.completed) {
        setState(() {
          _downloadedModels[size] = true;
          _downloadProgress.remove(size);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${size.displayName} downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Auto-load the downloaded model
        await widget.aiService.loadModel(size);
      } else if (status == DownloadStatus.failed) {
        setState(() {
          _downloadProgress.remove(size);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed for ${size.displayName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _downloadProgress.remove(size);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    await _loadModelStatus();
  }

  Future<void> _deleteModel(ModelSize size) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text(
          'Are you sure you want to delete ${size.displayName}?\n'
          'This will free up ${size.sizeMB} MB of storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final downloader = widget.aiService.modelDownloader;
      final success = await downloader.deleteModel(size);

      if (success) {
        await _loadModelStatus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${size.displayName} deleted'),
            ),
          );
        }
      }
    }
  }

  Future<void> _switchModel(ModelSize size) async {
    try {
      await widget.aiService.loadModel(size);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${size.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Model Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : kIsWeb
              ? _buildWebView()
              : _buildNativeView(),
    );
  }

  Widget _buildWebView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Web AI Active',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'On web, AI runs directly in your browser.\n'
              'No model download needed!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Features Available:'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFeatureItem('Note summarization'),
                    _buildFeatureItem('Task extraction'),
                    _buildFeatureItem('Smart search'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Storage info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Models Storage',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ModelDownloader.formatBytes(_totalSize),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Available Models',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Download a model to enable offline AI features',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // Model list
        ...ModelSize.values.map((size) => _buildModelCard(size)),
      ],
    );
  }

  Widget _buildModelCard(ModelSize size) {
    final isDownloaded = _downloadedModels[size] ?? false;
    final downloadProgress = _downloadProgress[size];
    final isDownloading = downloadProgress != null;
    final isCurrent = widget.aiService.currentModel == size;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            size.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${size.sizeMB} MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isDownloaded)
                  Icon(Icons.check_circle, color: Colors.green)
                else if (isDownloading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(Icons.cloud_download, color: Colors.grey),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              _getModelDescription(size),
              style: Theme.of(context).textTheme.bodySmall,
            ),

            if (isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: downloadProgress),
              const SizedBox(height: 4),
              Text(
                '${(downloadProgress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isDownloaded) ...[
                  if (!isCurrent)
                    TextButton.icon(
                      onPressed: () => _switchModel(size),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Use'),
                    ),
                  TextButton.icon(
                    onPressed: () => _deleteModel(size),
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ] else if (!isDownloading)
                  FilledButton.icon(
                    onPressed: () => _downloadModel(size),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  String _getModelDescription(ModelSize size) {
    switch (size) {
      case ModelSize.small:
        return 'Fast and lightweight. Good for basic summarization and quick tasks.';
      case ModelSize.medium:
        return 'Recommended. Balanced performance and quality for most use cases.';
      case ModelSize.large:
        return 'Best quality. Slower but more accurate for complex tasks.';
    }
  }
}
