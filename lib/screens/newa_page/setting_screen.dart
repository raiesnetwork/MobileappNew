import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/chat_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int selectedIndex = 0;

  late TextEditingController nameController;
  late TextEditingController professionController;
  late TextEditingController infoController;

  List<String> uploadedFiles = []; // Stores at most one file (full file paths for new files)
  List<String> serverFiles = []; // Existing server files (just filenames)
  List<String> filesToDelete = []; // Track files to delete

  // Switches
  bool emailNotifications = false;
  bool pushNotifications = false;
  bool allowAnalytics = false;
  bool allowPersonalizedAds = false;
  bool profileVisibilityPublic = false;
  bool pastDueReminders = false;
  bool weeklyReport = false;
  bool calendarSync = false;
  bool emailAutomation = false;

  final List<String> menuItems = [
    'Account',
    'Tasks',
    'Notifications',
    'Privacy'
  ];
  final List<IconData> menuIcons = [
    Icons.person,
    Icons.calendar_today,
    Icons.notifications,
    Icons.lock,
  ];

  bool _isInitialized = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    professionController = TextEditingController();
    infoController = TextEditingController();

    // Add listeners to detect changes
    nameController.addListener(_onFieldChanged);
    professionController.addListener(_onFieldChanged);
    infoController.addListener(_onFieldChanged);

    // Load settings when the page initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ChatProvider>(context, listen: false);
      provider.loadUserSettings();
    });
  }

  void _onFieldChanged() {
    if (_isInitialized) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  @override
  void dispose() {
    nameController.removeListener(_onFieldChanged);
    professionController.removeListener(_onFieldChanged);
    infoController.removeListener(_onFieldChanged);

    nameController.dispose();
    professionController.dispose();
    infoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        // Handle loading state
        if (chatProvider.isSettingsLoading) {
          print("DEBUG: Loading settings...");
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle error state
        if (chatProvider.settingsError != null) {
          print("DEBUG: Settings error: ${chatProvider.settingsError}");
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Error: ${chatProvider.settingsError}"),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => chatProvider.loadUserSettings(),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle null settings
        final settings = chatProvider.userSettings;
        if (settings == null) {
          print("DEBUG: No settings available");
          return const Scaffold(
            body: Center(child: Text("No settings available")),
          );
        }

        // Initialize fields only once to prevent overwriting user input
        if (!_isInitialized) {
          _initializeFields(settings);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Settings"),
            scrolledUnderElevation: 0,
            actions: [
              if (_hasUnsavedChanges)
                TextButton(
                  onPressed: _discardChanges,
                  child: const Text("Discard", style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabMenu(),
                const SizedBox(height: 32),
                if (selectedIndex == 0) _buildAccountSection(),
                if (selectedIndex == 1) _buildTaskSection(),
                if (selectedIndex == 2) _buildNotificationsSection(),
                if (selectedIndex == 3) _buildPrivacySection(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initializeFields(Map<String, dynamic> settings) {
    if (!mounted) return;

    nameController.text = settings['name']?.toString() ?? '';
    professionController.text = settings['profession']?.toString() ?? '';
    infoController.text = settings['additionalInfo']?.toString() ?? '';

    uploadedFiles.clear();
    serverFiles.clear();

    try {
      if (settings['files'] != null) {
        final filesData = settings['files'];
        List<Map<String, dynamic>> filesList = [];

        if (filesData is List) {
          filesList = filesData
              .where((file) => file is Map)
              .map((file) => Map<String, dynamic>.from(file as Map))
              .toList();
        } else if (filesData is Map) {
          filesList = [Map<String, dynamic>.from(filesData)];
        }

        // Select only the most recent file (last in the list)
        if (filesList.isNotEmpty) {
          final latestFile = filesList.last;
          final fileName = latestFile['name']?.toString() ?? '';
          if (fileName.isNotEmpty) {
            serverFiles = [fileName];
            print("DEBUG: Initialized serverFiles with latest file: $serverFiles");
          }
        }
      }
    } catch (e) {
      print("DEBUG: Error parsing server files: $e");
      serverFiles.clear();
    }

    print("DEBUG: No local uploadedFiles, serverFiles: $serverFiles");

    emailNotifications = _parseBool(settings['emailNotifications']);
    pushNotifications = _parseBool(settings['pushNotifications']);
    allowAnalytics = _parseBool(settings['allowAnalytics']);
    allowPersonalizedAds = _parseBool(settings['allowPersonalizedAds']);
    profileVisibilityPublic = settings['profileVisibility']?.toString() == 'public';

    final tasks = settings['tasks'];
    Map<String, dynamic> tasksMap = tasks is Map ? Map<String, dynamic>.from(tasks) : {};

    pastDueReminders = _parseBool(tasksMap['pastDueReminders']);
    weeklyReport = _parseBool(tasksMap['weeklyReport']);
    calendarSync = _parseBool(tasksMap['calendarSync']);
    emailAutomation = _parseBool(tasksMap['emailAutomation']);

    _isInitialized = true;
    _hasUnsavedChanges = false;
    filesToDelete.clear();
  }

  // Helper method to safely parse boolean values
  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  void _discardChanges() {
    final provider = Provider.of<ChatProvider>(context, listen: false);
    final settings = provider.userSettings;
    if (settings != null) {
      setState(() {
        _isInitialized = false;
        _hasUnsavedChanges = false;
        uploadedFiles.clear();
        serverFiles.clear();
        filesToDelete.clear();
      });
      _initializeFields(settings);
    }
  }

  Widget _buildTabMenu() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(menuItems.length, (index) {
          final isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => setState(() => selectedIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                isSelected ? const Color(0xFFEDEAFF) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    menuIcons[index],
                    size: 18,
                    color: isSelected ? Colors.purple : Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    menuItems[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.purple : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAccountSection() {
    // Display file from either uploadedFiles (new) or serverFiles (existing)
    final hasNewFile = uploadedFiles.isNotEmpty;
    final hasServerFile = serverFiles.isNotEmpty;
    final displayFile = hasNewFile ? uploadedFiles.last : (hasServerFile ? serverFiles.last : null);

    print("DEBUG: hasNewFile: $hasNewFile, hasServerFile: $hasServerFile, displayFile: $displayFile");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildLabeledField("What should Ask Newa call you?", nameController),
        const SizedBox(height: 16),
        _buildLabeledField("What do you do?", professionController),
        const SizedBox(height: 16),
        _buildLabeledField(
            "Anything else Ask Newa should know about you", infoController,
            maxLines: 4),
        const SizedBox(height: 32),
        const Text("Knowledge Base",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
          "Upload a document to help Ask Newa understand you better. "
              "Only the most recent file will be stored and displayed.",
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickFiles,
          child: Container(
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.shade100,
            ),
            child: const Text("+ Upload File",
                style: TextStyle(color: Colors.black87)),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Supported formats: PDF, DOC, DOCX, TXT (Max 5MB)",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        if (displayFile != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
              color: hasNewFile ? Colors.blue.shade50 : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                if (hasNewFile)
                  Icon(Icons.file_upload, color: Colors.blue, size: 16),
                if (hasServerFile && !hasNewFile)
                  Icon(Icons.cloud_done, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _getFileDisplayName(displayFile),
                          style: const TextStyle(fontWeight: FontWeight.w500)
                      ),
                      if (hasNewFile)
                        const Text(
                          "New file (not saved yet)",
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      if (hasServerFile && !hasNewFile)
                        const Text(
                          "Saved on server",
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _removeFile(displayFile, isNewFile: hasNewFile),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
          )
        else
          const Text(
            "No file uploaded",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasUnsavedChanges)
              const Text(
                "You have unsaved changes",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ElevatedButton(
              onPressed: _hasUnsavedChanges ? _saveSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges ? Colors.blue : Colors.grey,
              ),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ],
    );
  }

  String _getFileDisplayName(String filePath) {
    // If it's a full path, extract just the filename
    if (filePath.contains('/')) {
      return filePath.split('/').last;
    }
    return filePath;
  }

  void _removeFile(String fileName, {required bool isNewFile}) {
    setState(() {
      if (isNewFile) {
        // Remove from uploadedFiles (new files)
        uploadedFiles.remove(fileName);
        print("DEBUG: Removed new file: $fileName");
      } else {
        // Add server file to deletion list and remove from serverFiles
        filesToDelete.add(fileName);
        serverFiles.remove(fileName);
        print("DEBUG: Marked server file for deletion: $fileName");
      }

      _hasUnsavedChanges = true;
      print("DEBUG: uploadedFiles: $uploadedFiles, serverFiles: $serverFiles, filesToDelete: $filesToDelete");
    });
  }

  Widget _buildTaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📝 Tasks",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildSwitchTile("Past Due Reminders", pastDueReminders,
                (val) => setState(() {
              pastDueReminders = val;
              _hasUnsavedChanges = true;
            })),
        _buildSwitchTile("Weekly Report", weeklyReport,
                (val) => setState(() {
              weeklyReport = val;
              _hasUnsavedChanges = true;
            })),
        _buildSwitchTile("Calendar Sync", calendarSync,
                (val) => setState(() {
              calendarSync = val;
              _hasUnsavedChanges = true;
            })),
        _buildSwitchTile("Email Automation", emailAutomation,
                (val) => setState(() {
              emailAutomation = val;
              _hasUnsavedChanges = true;
            })),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasUnsavedChanges)
              const Text(
                "You have unsaved changes",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ElevatedButton(
              onPressed: _hasUnsavedChanges ? _saveSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges ? Colors.blue : Colors.grey,
              ),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🔔 Notifications",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildSwitchTile("Email Notifications", emailNotifications,
                (val) => setState(() {
              emailNotifications = val;
              _hasUnsavedChanges = true;
            })),
        _buildSwitchTile("Push Notifications", pushNotifications,
                (val) => setState(() {
              pushNotifications = val;
              _hasUnsavedChanges = true;
            })),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasUnsavedChanges)
              const Text(
                "You have unsaved changes",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ElevatedButton(
              onPressed: _hasUnsavedChanges ? _saveSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges ? Colors.blue : Colors.grey,
              ),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("🔒 Privacy",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildSwitchTile("Allow Analytics", allowAnalytics,
                (val) => setState(() {
              allowAnalytics = val;
              _hasUnsavedChanges = true;
            })),
        _buildSwitchTile("Personalized Ads", allowPersonalizedAds,
                (val) => setState(() {
              allowPersonalizedAds = val;
              _hasUnsavedChanges = true;
            })),
        _buildSwitchTile("Profile Visibility (Public)", profileVisibilityPublic,
                (val) => setState(() {
              profileVisibilityPublic = val;
              _hasUnsavedChanges = true;
            })),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_hasUnsavedChanges)
              const Text(
                "You have unsaved changes",
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ElevatedButton(
              onPressed: _hasUnsavedChanges ? _saveSettings : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedChanges ? Colors.blue : Colors.grey,
              ),
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
      String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );

      if (result == null || result.paths.isEmpty || result.paths.first == null) {
        print("DEBUG: No file selected in _pickFiles");
        return;
      }

      final newFile = result.paths.first!;
      final file = File(newFile);

      if (!file.existsSync()) {
        _showErrorSnackBar("Selected file does not exist");
        print("DEBUG: File does not exist: $newFile");
        return;
      }

      // Check file size (max 5MB)
      final fileSizeInBytes = file.lengthSync();
      if (fileSizeInBytes > 5 * 1024 * 1024) {
        _showErrorSnackBar("File size exceeds 5MB limit");
        print("DEBUG: File size exceeds 5MB: $newFile");
        return;
      }

      // Check for duplicates by comparing file names
      final newFileName = newFile.split('/').last.toLowerCase();

      // Check against existing uploaded files
      final existingUploadedFileName = uploadedFiles.isNotEmpty
          ? _getFileDisplayName(uploadedFiles.last).toLowerCase()
          : '';

      // Check against server files
      final existingServerFileName = serverFiles.isNotEmpty
          ? _getFileDisplayName(serverFiles.last).toLowerCase()
          : '';

      if ((uploadedFiles.isNotEmpty && newFileName == existingUploadedFileName) ||
          (serverFiles.isNotEmpty && newFileName == existingServerFileName)) {
        _showErrorSnackBar("File with this name already exists");
        print("DEBUG: Duplicate file detected: $newFileName");
        return;
      }

      // Mark old server file for deletion if it exists
      if (serverFiles.isNotEmpty) {
        final oldServerFile = serverFiles.last;
        filesToDelete.add(oldServerFile);
        serverFiles.clear();
      }

      // Clear any existing uploaded files (replace with new one)
      uploadedFiles.clear();

      // Add the new file
      setState(() {
        uploadedFiles = [newFile];
        _hasUnsavedChanges = true;
        print("DEBUG: New file uploaded: $uploadedFiles");
        print("DEBUG: Server files marked for deletion: $filesToDelete");
      });

      _showSuccessSnackBar("File uploaded successfully");
    } catch (e) {
      _showErrorSnackBar("Error picking file: $e");
      print("DEBUG: Error in _pickFiles: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _saveSettings() async {
    if (!_hasUnsavedChanges) return;

    final provider = Provider.of<ChatProvider>(context, listen: false);

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text("Saving settings..."),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );

    // Prepare fields for saving
    final fields = {
      'name': nameController.text.trim(),
      'profession': professionController.text.trim(),
      'additionalInfo': infoController.text.trim(),
      'emailNotifications': emailNotifications.toString(),
      'pushNotifications': pushNotifications.toString(),
      'allowAnalytics': allowAnalytics.toString(),
      'allowPersonalizedAds': allowPersonalizedAds.toString(),
      'profileVisibility': profileVisibilityPublic ? 'public' : 'private',
      'tasks[pastDueReminders]': pastDueReminders.toString(),
      'tasks[weeklyReport]': weeklyReport.toString(),
      'tasks[calendarSync]': calendarSync.toString(),
      'tasks[emailAutomation]': emailAutomation.toString(),
    };

    print("DEBUG: Saving settings with fields: $fields");
    print("DEBUG: uploadedFiles (new files with full paths): $uploadedFiles");
    print("DEBUG: filesToDelete (server files): $filesToDelete");

    // Only pass files that are actual file paths (newly uploaded files)
    final filesToUpload = uploadedFiles.where((file) {
      // Check if the file exists (is a real file path)
      try {
        return File(file).existsSync();
      } catch (e) {
        print("DEBUG: Error checking file existence: $file - $e");
        return false;
      }
    }).toList();

    print("DEBUG: filesToUpload (verified existing files): $filesToUpload");

    try {
      final success = await provider.updateUserSettings(
        fields,
        filesToUpload, // Only send actual file paths
        deletedFiles: filesToDelete, // Server filenames to delete
      );

      // Clear any existing snackbars
      ScaffoldMessenger.of(context).clearSnackBars();

      if (success) {
        // Update local state immediately
        setState(() {
          if (filesToUpload.isNotEmpty) {
            // Add the uploaded file name to server files
            final uploadedFileName = filesToUpload.last.split('/').last;
            serverFiles = [uploadedFileName];
          }

          // Clear temporary lists
          uploadedFiles.clear();
          filesToDelete.clear();
          _hasUnsavedChanges = false;
        });

        // Show success message immediately
        _showSuccessSnackBar("✅ Settings updated successfully");
        print("DEBUG: Settings saved successfully");

        // Refresh settings in background to sync with server
        Future.delayed(const Duration(milliseconds: 500), () async {
          await provider.loadUserSettings();
          // Force UI rebuild with fresh data
          if (mounted) {
            setState(() {
              _isInitialized = false;
            });
          }
        });

      } else {
        _showErrorSnackBar(
            provider.settingsError ?? "❌ Failed to update settings"
        );
        print("DEBUG: Save failed, error: ${provider.settingsError}");
      }
    } catch (e) {
      // Clear loading snackbar
      ScaffoldMessenger.of(context).clearSnackBars();

      print("DEBUG: Exception during save: $e");
      _showErrorSnackBar("❌ Error occurred while saving: ${e.toString()}");

      // Reset unsaved changes flag on error
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }
}