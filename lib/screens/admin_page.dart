import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Data lists
  List<Map<String, dynamic>> admins = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  Map<String, dynamic>? currentViewedAdmin;

  // API Endpoints
  final String listApiUrl = 'http://127.0.0.1:8000/user/admin/list/';
  final String filterApiUrl = 'http://127.0.0.1:8000/user/admin/filter/';
  final String createApiUrl = 'http://127.0.0.1:8000/user/Admin/registration/';
  final String detailApiUrl = 'http://127.0.0.1:8000/user/User/detail/';
  final String updateApiUrl = 'http://127.0.0.1:8000/user/Admin/update/';

  // Pagination variables
  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;
  int pageSize = 20;

  // Filter and sort variables
  Map<String, String> filterParams = {'role_name': 'admin'};
  String? sortBy;
  String? sortOrder;

  // Scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();

  // Search query for field selection
  String fieldSearchQuery = '';

  // List settings variables
  bool compactRows = false;
  bool activeRowHighlighting = false;
  bool modernCellColoring = false;
  bool enableView = true;
  bool enableEdit = true;

  // Group By / Display Fields variables
  List<Map<String, dynamic>> availableFields = [
    {'key': 'user_code', 'label': 'User Code', 'selected': true, 'order': 0},
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 1},
    {'key': 'full_name', 'label': 'Full Name', 'selected': true, 'order': 2},
    {'key': 'email_id', 'label': 'Email ID', 'selected': true, 'order': 3},
    {'key': 'mobile_no', 'label': 'Mobile No', 'selected': true, 'order': 4},
    {'key': 'status', 'label': 'Status', 'selected': true, 'order': 5},
    {'key': 'dob', 'label': 'Date of Birth', 'selected': false, 'order': 6},
    {'key': 'city', 'label': 'City', 'selected': true, 'order': 7},
    {'key': 'state', 'label': 'State', 'selected': true, 'order': 8},
    {'key': 'country', 'label': 'Country', 'selected': true, 'order': 9},
    {'key': 'pincode', 'label': 'Pincode', 'selected': true, 'order': 10},
    {'key': 'aadhar_number', 'label': 'Aadhar Number', 'selected': true, 'order': 11},
    {'key': 'profile_picture', 'label': 'Profile Picture', 'selected': false, 'isFile': true, 'order': 12},
    {'key': 'aadhar_photo', 'label': 'Aadhar Photo', 'selected': false, 'isFile': true, 'order': 13},
    {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 14},
    {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 15},
  ];

  // Filter controllers
  final TextEditingController bpCodeController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailIdController = TextEditingController();
  final TextEditingController mobileNoController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController aadharNumberController = TextEditingController();

  // Status dropdown for filter
  String? selectedFilterStatus;

  // Create controllers
  final Map<String, TextEditingController> createControllers = {};

  // Status dropdown for create
  String? selectedCreateStatus;

  // Edit controllers
  Map<String, TextEditingController>? editControllers;
  int? editingAdminId;

  // Status dropdown for edit
  String? selectedEditStatus;

  // File uploads - Use XFile for better cross-platform support
  XFile? profilePictureXFile;
  XFile? aadharPhotoXFile;

  // Status options
  final List<Map<String, String>> statusOptions = [
    {'display': 'Active', 'value': 'active'},
    {'display': 'Inactive', 'value': 'inactive'},
  ];

  // Required fields for admin
  final List<String> requiredFields = [
    'profile_picture',
    'role_name',
    'user_code',
    'bp_code',
    'full_name',
    'email_id',
    'mobile_no',
    'status',
    'dob',
    'city',
    'state',
    'country',
    'pincode',
    'aadhar_photo',
    'aadhar_number',
    'password',
    'created_at',
    'updated_at'
  ];

  // Fields to exclude from certain operations
  final List<String> excludeFromCreate = ['created_at', 'updated_at', 'role_name'];
  final List<String> excludeFromEdit = ['created_at', 'updated_at', 'password', 'role_name'];
  final List<String> excludeFromDisplay = ['password'];

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadSavedFieldSelections();
    loadListSettings();
    loadToken();
  }

  @override
  void dispose() {
    // Dispose filter controllers
    bpCodeController.dispose();
    fullNameController.dispose();
    emailIdController.dispose();
    mobileNoController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    aadharNumberController.dispose();

    // Dispose create controllers
    createControllers.forEach((key, controller) {
      controller.dispose();
    });

    // Dispose edit controllers
    if (editControllers != null) {
      editControllers!.forEach((key, controller) {
        controller.dispose();
      });
    }

    // Dispose scroll controller
    _horizontalScrollController.dispose();

    super.dispose();
  }

  // Load saved field selections from SharedPreferences
  Future<void> loadSavedFieldSelections() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedSelections = prefs.getString('admin_fields');
    String? savedOrder = prefs.getString('admin_field_order');

    if (savedSelections != null) {
      try {
        Map<String, dynamic> savedMap = json.decode(savedSelections);
        setState(() {
          for (var field in availableFields) {
            String key = field['key'];
            if (savedMap.containsKey(key)) {
              field['selected'] = savedMap[key] ?? field['selected'];
            }
          }
        });
      } catch (e) {
        print('Error loading saved field selections: $e');
      }
    }

    // Load saved field order
    if (savedOrder != null) {
      try {
        List<dynamic> savedOrderList = json.decode(savedOrder);
        setState(() {
          // Reorder availableFields based on saved order
          List<Map<String, dynamic>> reorderedFields = [];
          for (String key in savedOrderList) {
            final index = availableFields.indexWhere((f) => f['key'] == key);
            if (index != -1) {
              reorderedFields.add(availableFields[index]);
            }
          }
          // Add any missing fields at the end
          for (var field in availableFields) {
            if (!reorderedFields.any((f) => f['key'] == field['key'])) {
              reorderedFields.add(field);
            }
          }
          availableFields = reorderedFields;

          // Update order values
          for (int i = 0; i < availableFields.length; i++) {
            availableFields[i]['order'] = i;
          }
        });
      } catch (e) {
        print('Error loading saved field order: $e');
      }
    }
  }

  // Save field selections to SharedPreferences
  Future<void> saveFieldSelections() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, bool> selections = {};

    for (var field in availableFields) {
      selections[field['key']] = field['selected'];
    }

    await prefs.setString('admin_fields', json.encode(selections));

    // Save field order
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('admin_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      compactRows = prefs.getBool('admin_compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('admin_active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('admin_modern_cell_coloring') ?? false;
      enableView = prefs.getBool('admin_enable_view') ?? true;
      enableEdit = prefs.getBool('admin_enable_edit') ?? true;
    });
  }

  // Save list settings to SharedPreferences
  Future<void> saveListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableView,
    required bool enableEdit,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool('admin_compact_rows', compactRows);
    await prefs.setBool('admin_active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('admin_modern_cell_coloring', modernCellColoring);
    await prefs.setBool('admin_enable_view', enableView);
    await prefs.setBool('admin_enable_edit', enableEdit);
  }

  // Get selected fields for display in correct order
  List<Map<String, dynamic>> getSelectedFields() {
    return availableFields
        .where((field) => field['selected'] == true)
        .toList()
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
  }

  // Show Group By / Field Selection Dialog
  void showFieldSelectionDialog() {
    fieldSearchQuery = ''; // Reset search when opening dialog

    // Local variables for checkbox states
    bool localCompactRows = compactRows;
    bool localActiveRowHighlighting = activeRowHighlighting;
    bool localModernCellColoring = modernCellColoring;
    bool localEnableView = enableView;
    bool localEnableEdit = enableEdit;

    // Track selected field index for up/down movement
    int selectedFieldIndex = -1;

    // Create separate lists for available and selected fields
    List<Map<String, dynamic>> availableFieldsList = [];
    List<Map<String, dynamic>> selectedFieldsList = [];

    // Populate both lists based on current selection state and order
    // First, get all fields sorted by order
    List<Map<String, dynamic>> sortedFields = List.from(availableFields)
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

    for (var field in sortedFields) {
      if (field['selected'] == true) {
        selectedFieldsList.add(Map.from(field));
      } else {
        availableFieldsList.add(Map.from(field));
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter available fields based on search query
            final filteredAvailableFields = fieldSearchQuery.isEmpty
                ? availableFieldsList
                : availableFieldsList.where((field) {
                    return field['label']
                            .toLowerCase()
                            .contains(fieldSearchQuery.toLowerCase()) ||
                        field['key']
                            .toLowerCase()
                            .contains(fieldSearchQuery.toLowerCase());
                  }).toList();

            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Container(
                width: 950,
                constraints: BoxConstraints(maxHeight: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.view_column, color: Colors.blue),
                          SizedBox(width: 12),
                          Text(
                            'Personalize List Columns - Admins',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Field
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search fields...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            fieldSearchQuery = value;
                          });
                        },
                      ),
                    ),

                    // Two-panel layout with arrow buttons in the middle
                    Expanded(
                      child: Row(
                        children: [
                          // Available Fields Panel (Left)
                          Expanded(
                            flex: 5,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(
                                      'Available',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Divider(height: 1),
                                  Expanded(
                                    child: filteredAvailableFields.isEmpty
                                        ? Center(
                                            child: Text('No fields found'),
                                          )
                                        : ListView.builder(
                                            itemCount:
                                                filteredAvailableFields.length,
                                            itemBuilder: (context, index) {
                                              final field =
                                                  filteredAvailableFields[index];
                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  field['label'],
                                                  style: TextStyle(fontSize: 14),
                                                ),
                                                subtitle: field['isFile'] == true
                                                    ? Text('File field',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey))
                                                    : null,
                                                trailing: Icon(
                                                  Icons.add_circle_outline,
                                                  color: Colors.blue,
                                                  size: 22,
                                                ),
                                                onTap: () {
                                                  setState(() {
                                                    // Move field from available to selected
                                                    field['selected'] = true;
                                                    availableFieldsList.removeWhere(
                                                        (f) =>
                                                            f['key'] ==
                                                            field['key']);
                                                    selectedFieldsList.add(field);
                                                    selectedFieldIndex =
                                                        selectedFieldsList.length -
                                                            1;
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Arrow buttons in the middle
                          Container(
                            width: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Move right button
                                Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  child: IconButton(
                                    icon: Icon(Icons.arrow_forward, size: 30),
                                    color: Colors.blue,
                                    onPressed: () {
                                      setState(() {
                                        // Move all available fields to selected
                                        if (filteredAvailableFields.isNotEmpty) {
                                          for (var field
                                              in filteredAvailableFields.toList()) {
                                            field['selected'] = true;
                                            availableFieldsList.removeWhere(
                                                (f) =>
                                                    f['key'] == field['key']);
                                            selectedFieldsList.add(field);
                                          }
                                          if (selectedFieldsList.isNotEmpty) {
                                            selectedFieldIndex =
                                                selectedFieldsList.length - 1;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ),
                                // Move left button
                                Container(
                                  margin: EdgeInsets.only(top: 16),
                                  child: IconButton(
                                    icon: Icon(Icons.arrow_back, size: 30),
                                    color: Colors.orange,
                                    onPressed: () {
                                      setState(() {
                                        // Move all selected fields back to available
                                        if (selectedFieldsList.isNotEmpty) {
                                          for (var field
                                              in selectedFieldsList.toList()) {
                                            field['selected'] = false;
                                            selectedFieldsList.removeWhere(
                                                (f) =>
                                                    f['key'] == field['key']);
                                            availableFieldsList.add(field);
                                          }
                                          selectedFieldIndex = -1;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Selected Fields Panel (Right)
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Selected',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (selectedFieldsList.isNotEmpty)
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  // Move all selected fields back to available
                                                  for (var field
                                                      in selectedFieldsList
                                                          .toList()) {
                                                    field['selected'] = false;
                                                  }
                                                  availableFieldsList
                                                      .addAll(selectedFieldsList);
                                                  selectedFieldsList.clear();
                                                  selectedFieldIndex = -1;
                                                });
                                              },
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size(0, 0),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: Text(
                                                'Remove all',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(height: 1),
                                Expanded(
                                  child: selectedFieldsList.isEmpty
                                      ? Center(
                                          child: Text('No fields selected'),
                                        )
                                      : ListView.builder(
                                          itemCount: selectedFieldsList.length,
                                          itemBuilder: (context, index) {
                                            final field = selectedFieldsList[index];
                                            return Container(
                                              color: selectedFieldIndex == index
                                                  ? Colors.blue.shade50
                                                  : null,
                                              child: ListTile(
                                                dense: true,
                                                leading: Icon(
                                                  Icons.drag_handle,
                                                  color: Colors.grey,
                                                  size: 18,
                                                ),
                                                title: Text(
                                                  field['label'],
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        selectedFieldIndex == index
                                                            ? FontWeight.bold
                                                            : FontWeight.w500,
                                                  ),
                                                ),
                                                trailing: IconButton(
                                                  icon: Icon(
                                                    Icons.close,
                                                    color: Colors.grey,
                                                    size: 18,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      // Move field from selected to available
                                                      field['selected'] = false;
                                                      selectedFieldsList
                                                          .removeAt(index);
                                                      availableFieldsList
                                                          .add(field);
                                                      if (selectedFieldIndex >=
                                                          selectedFieldsList
                                                              .length) {
                                                        selectedFieldIndex =
                                                            selectedFieldsList
                                                                    .length -
                                                                1;
                                                      }
                                                    });
                                                  },
                                                ),
                                                onTap: () {
                                                  setState(() {
                                                    selectedFieldIndex = index;
                                                  });
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                ),

                                // Up/Down arrow buttons for selected fields
                                if (selectedFieldsList.isNotEmpty)
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.arrow_upward,
                                              color: Colors.blue),
                                          onPressed: selectedFieldIndex > 0
                                              ? () {
                                                  setState(() {
                                                    // Move selected field up
                                                    final field = selectedFieldsList
                                                        .removeAt(
                                                            selectedFieldIndex);
                                                    selectedFieldsList.insert(
                                                        selectedFieldIndex - 1,
                                                        field);
                                                    selectedFieldIndex =
                                                        selectedFieldIndex - 1;
                                                  });
                                                }
                                              : null,
                                        ),
                                        SizedBox(width: 30),
                                        IconButton(
                                          icon: Icon(Icons.arrow_downward,
                                              color: Colors.blue),
                                          onPressed: selectedFieldIndex <
                                                  selectedFieldsList.length - 1
                                              ? () {
                                                  setState(() {
                                                    // Move selected field down
                                                    final field = selectedFieldsList
                                                        .removeAt(
                                                            selectedFieldIndex);
                                                    selectedFieldsList.insert(
                                                        selectedFieldIndex + 1,
                                                        field);
                                                    selectedFieldIndex =
                                                        selectedFieldIndex + 1;
                                                  });
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom options section
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Column(
                        children: [
                          // First row of checkboxes
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: localCompactRows,
                                  onChanged: (value) {
                                    setState(() {
                                      localCompactRows = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Compact rows'),
                              SizedBox(width: 32),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: localActiveRowHighlighting,
                                  onChanged: (value) {
                                    setState(() {
                                      localActiveRowHighlighting = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Active row highlighting'),
                              SizedBox(width: 32),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: localModernCellColoring,
                                  onChanged: (value) {
                                    setState(() {
                                      localModernCellColoring = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Modern cell coloring'),
                            ],
                          ),
                          SizedBox(height: 12),
                          // Second row of checkboxes for View/Edit
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: localEnableView,
                                  onChanged: (value) {
                                    setState(() {
                                      localEnableView = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Enable View'),
                              SizedBox(width: 32),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: localEnableEdit,
                                  onChanged: (value) {
                                    setState(() {
                                      localEnableEdit = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Enable Edit'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Footer with Reset button and metadata
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                // Reset to default fields in the dialog
                                availableFieldsList.clear();
                                selectedFieldsList.clear();

                                List<Map<String, dynamic>> defaultFields = [
                                  {
                                    'key': 'user_code',
                                    'label': 'User Code',
                                    'selected': true
                                  },
                                  {
                                    'key': 'bp_code',
                                    'label': 'BP Code',
                                    'selected': true
                                  },
                                  {
                                    'key': 'full_name',
                                    'label': 'Full Name',
                                    'selected': true
                                  },
                                  {
                                    'key': 'email_id',
                                    'label': 'Email ID',
                                    'selected': true
                                  },
                                  {
                                    'key': 'mobile_no',
                                    'label': 'Mobile No',
                                    'selected': true
                                  },
                                  {
                                    'key': 'status',
                                    'label': 'Status',
                                    'selected': true
                                  },
                                  {
                                    'key': 'city',
                                    'label': 'City',
                                    'selected': true
                                  },
                                  {
                                    'key': 'state',
                                    'label': 'State',
                                    'selected': true
                                  },
                                  {
                                    'key': 'country',
                                    'label': 'Country',
                                    'selected': true
                                  },
                                  {
                                    'key': 'pincode',
                                    'label': 'Pincode',
                                    'selected': true
                                  },
                                  {
                                    'key': 'aadhar_number',
                                    'label': 'Aadhar Number',
                                    'selected': true
                                  },
                                ];

                                for (var field in availableFields) {
                                  bool isDefaultSelected = defaultFields
                                      .any((df) => df['key'] == field['key']);
                                  if (isDefaultSelected) {
                                    field['selected'] = true;
                                    selectedFieldsList.add(Map.from(field));
                                  } else {
                                    field['selected'] = false;
                                    availableFieldsList.add(Map.from(field));
                                  }
                                }

                                // Reset checkboxes to default
                                localCompactRows = false;
                                localActiveRowHighlighting = false;
                                localModernCellColoring = false;
                                localEnableView = true;
                                localEnableEdit = true;

                                selectedFieldIndex = -1;
                              });
                            },
                            child: Text(
                              'Reset to column defaults',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Admins - Field Selection',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'Customize visible columns',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              // Apply the field selection and order to the actual availableFields
                              this.setState(() {
                                // First set all fields to false
                                for (var field in availableFields) {
                                  field['selected'] = false;
                                }

                                // Then set selected fields to true and update their order
                                for (int i = 0; i < selectedFieldsList.length;
                                    i++) {
                                  final selectedField = selectedFieldsList[i];
                                  final index = availableFields.indexWhere(
                                    (f) => f['key'] == selectedField['key'],
                                  );
                                  if (index != -1) {
                                    availableFields[index]['selected'] = true;
                                    availableFields[index]['order'] = i;
                                  }
                                }

                                // Update order for unselected fields (keep them at the end)
                                int nextOrder = selectedFieldsList.length;
                                for (var field in availableFields) {
                                  if (field['selected'] != true) {
                                    field['order'] = nextOrder;
                                    nextOrder++;
                                  }
                                }

                                // Reorder availableFields based on order
                                availableFields.sort((a, b) =>
                                    (a['order'] ?? 0).compareTo(b['order'] ?? 0));
                              });

                              // Save selections to SharedPreferences
                              await saveFieldSelections();

                              // Apply other settings
                              applyListSettings(
                                compactRows: localCompactRows,
                                activeRowHighlighting: localActiveRowHighlighting,
                                modernCellColoring: localModernCellColoring,
                                enableView: localEnableView,
                                enableEdit: localEnableEdit,
                              );

                              Navigator.pop(context);
                            },
                            child: Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Apply list settings
  void applyListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableView,
    required bool enableEdit,
  }) {
    // Save these settings to SharedPreferences
    saveListSettings(
      compactRows: compactRows,
      activeRowHighlighting: activeRowHighlighting,
      modernCellColoring: modernCellColoring,
      enableView: enableView,
      enableEdit: enableEdit,
    );

    // Apply the settings to the current view
    setState(() {
      this.compactRows = compactRows;
      this.activeRowHighlighting = activeRowHighlighting;
      this.modernCellColoring = modernCellColoring;
      this.enableView = enableView;
      this.enableEdit = enableEdit;
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('List settings applied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Helper Methods
  int safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String formatFieldName(String field) {
    return field.replaceAll('_', ' ').toUpperCase();
  }

  bool isFileField(String field) {
    return field == 'profile_picture' || field == 'aadhar_photo';
  }

  bool isFieldDisplayable(String field) {
    return !excludeFromDisplay.contains(field) && field != 'password';
  }

  String getStatusDisplayValue(String? statusValue) {
    if (statusValue == null) return '-';
    for (var option in statusOptions) {
      if (option['value'] == statusValue) {
        return option['display']!;
      }
    }
    return statusValue;
  }

  // Get field value with proper formatting
  String getFieldValue(Map<String, dynamic> admin, String key) {
    final value = admin[key];

    if (value == null) return '-';

    if (key == 'status') {
      return getStatusDisplayValue(value);
    }

    if (value is bool) {
      return value.toString();
    }

    return value.toString();
  }

  // Token Management
  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null || token!.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    fetchAdmins();
  }

  // API Request Building
  String buildRequestUrl({String? baseUrl}) {
    String url = filterApiUrl;
    Map<String, String> queryParams = {};

    // Add role filter
    queryParams['role_name'] = 'admin';

    // Add filter parameters
    filterParams.forEach((key, value) {
      if (key != 'role_name' && value.isNotEmpty) {
        queryParams[key] = value;
      }
    });

    // Add sort parameters
    if (sortBy != null && sortBy!.isNotEmpty) {
      queryParams['sort_by'] = sortBy!;
      if (sortOrder != null && sortOrder!.isNotEmpty) {
        queryParams['sort_order'] = sortOrder!;
      }
    }

    // Add pagination
    if (pageSize != 20) {
      queryParams['page_size'] = pageSize.toString();
    }
    if (currentPage > 1) {
      queryParams['page'] = currentPage.toString();
    }

    Uri uri = Uri.parse(url);
    return uri.replace(queryParameters: queryParams).toString();
  }

  // Fetch Admins
  Future<void> fetchAdmins({String? url}) async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final requestUrl = url ?? buildRequestUrl();
      print('Fetching: $requestUrl');

      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

        setState(() {
          admins = results;
          nextUrl = data['next'];
          prevUrl = data['previous'];
          totalCount = safeParseInt(data['count']);

          // Calculate current page
          if (prevUrl == null && nextUrl != null) {
            currentPage = 1;
          } else if (prevUrl != null) {
            final uri = Uri.parse(prevUrl!);
            final pageParam = uri.queryParameters['page'];
            if (pageParam != null) {
              currentPage = int.parse(pageParam) + 1;
            }
          } else if (nextUrl != null) {
            final uri = Uri.parse(nextUrl!);
            final pageParam = uri.queryParameters['page'];
            if (pageParam != null) {
              currentPage = int.parse(pageParam) - 1;
            }
          }

          // Clear selections when data refreshes
          selectedIds.clear();
          isLoading = false;
        });
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch admins', isError: true);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // Fetch Single Admin Details
  Future<void> fetchAdminDetails(int id) async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$detailApiUrl$id/'),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentViewedAdmin = data;
          isLoading = false;
        });
        showAdminDetailDialog();
      } else {
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch admin details', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // Filter Methods
  Future<void> applyFilters() async {
    filterParams.clear();
    filterParams['role_name'] = 'admin';

    if (bpCodeController.text.isNotEmpty) {
      filterParams['bp_code'] = bpCodeController.text;
    }
    if (fullNameController.text.isNotEmpty) {
      filterParams['full_name'] = fullNameController.text;
    }
    if (emailIdController.text.isNotEmpty) {
      filterParams['email_id'] = emailIdController.text;
    }
    if (mobileNoController.text.isNotEmpty) {
      filterParams['mobile_no'] = mobileNoController.text;
    }
    if (selectedFilterStatus != null && selectedFilterStatus!.isNotEmpty) {
      filterParams['status'] = selectedFilterStatus!;
    }
    if (cityController.text.isNotEmpty) {
      filterParams['city'] = cityController.text;
    }
    if (stateController.text.isNotEmpty) {
      filterParams['state'] = stateController.text;
    }
    if (pincodeController.text.isNotEmpty) {
      filterParams['pincode'] = pincodeController.text;
    }
    if (aadharNumberController.text.isNotEmpty) {
      filterParams['aadhar_number'] = aadharNumberController.text;
    }

    currentPage = 1;
    await fetchAdmins();
    Navigator.pop(context);
  }

  Future<void> clearFilters() async {
    filterParams.clear();
    filterParams['role_name'] = 'admin';

    bpCodeController.clear();
    fullNameController.clear();
    emailIdController.clear();
    mobileNoController.clear();
    cityController.clear();
    stateController.clear();
    pincodeController.clear();
    aadharNumberController.clear();

    setState(() {
      selectedFilterStatus = null;
    });

    await fetchAdmins();
  }

  void showFilterDialog() {
    // Initialize controllers with current values
    bpCodeController.text = filterParams['bp_code'] ?? '';
    fullNameController.text = filterParams['full_name'] ?? '';
    emailIdController.text = filterParams['email_id'] ?? '';
    mobileNoController.text = filterParams['mobile_no'] ?? '';
    cityController.text = filterParams['city'] ?? '';
    stateController.text = filterParams['state'] ?? '';
    pincodeController.text = filterParams['pincode'] ?? '';
    aadharNumberController.text = filterParams['aadhar_number'] ?? '';

    setState(() {
      selectedFilterStatus = filterParams['status'];
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Admins'),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterField(
                          bpCodeController, 'BP Code', Icons.code),
                      _buildFilterField(
                          fullNameController, 'Full Name', Icons.person),
                      _buildFilterField(
                          emailIdController, 'Email ID', Icons.email),
                      _buildFilterField(
                          mobileNoController, 'Mobile No', Icons.phone),

                      // Status dropdown filter
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: DropdownButtonFormField<String>(
                          value: selectedFilterStatus,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...statusOptions.map((option) {
                              return DropdownMenuItem(
                                value: option['value'],
                                child: Text(option['display']!),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedFilterStatus = value;
                            });
                          },
                        ),
                      ),

                      _buildFilterField(
                          cityController, 'City', Icons.location_city),
                      _buildFilterField(stateController, 'State', Icons.map),
                      _buildFilterField(
                          pincodeController, 'Pincode', Icons.pin_drop),
                      _buildFilterField(aadharNumberController,
                          'Aadhar Number', Icons.credit_card),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    clearFilters();
                  },
                  child: Text('Clear All'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: applyFilters,
                  child: Text('Apply Filters'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterField(
      TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  // Sort Methods
  Future<void> applySort(String field, String order) async {
    setState(() {
      sortBy = field;
      sortOrder = order;
    });
    currentPage = 1;
    await fetchAdmins();
  }

  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchAdmins();
  }

  void toggleSortOrder() {
    if (sortBy == null) return;
    String newOrder = sortOrder == 'asc' ? 'desc' : 'asc';
    applySort(sortBy!, newOrder);
  }

  void showSortDialog() {
    List<Map<String, String>> sortFields = [
      {'value': 'bp_code', 'label': 'BP Code'},
      {'value': 'full_name', 'label': 'Full Name'},
      {'value': 'email_id', 'label': 'Email ID'},
      {'value': 'mobile_no', 'label': 'Mobile No'},
      {'value': 'status', 'label': 'Status'},
      {'value': 'dob', 'label': 'Date of Birth'},
      {'value': 'city', 'label': 'City'},
      {'value': 'state', 'label': 'State'},
      {'value': 'country', 'label': 'Country'},
      {'value': 'pincode', 'label': 'Pincode'},
      {'value': 'aadhar_number', 'label': 'Aadhar Number'},
      {'value': 'created_at', 'label': 'Created Date'},
      {'value': 'user_code', 'label': 'User Code'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Sort By'),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...sortFields.map((field) {
                        return RadioListTile<String>(
                          title: Text(field['label']!),
                          value: field['value']!,
                          groupValue: sortBy,
                          onChanged: (value) {
                            setState(() {
                              this.sortBy = value;
                              if (sortOrder == null) {
                                sortOrder = 'asc';
                              }
                            });
                          },
                          secondary: sortBy == field['value']
                              ? IconButton(
                                  icon: Icon(
                                    sortOrder == 'desc'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      sortOrder = sortOrder == 'asc'
                                          ? 'desc'
                                          : 'asc';
                                    });
                                  },
                                )
                              : null,
                        );
                      }).toList(),

                      if (sortBy != null)
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sort Order:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Text('Ascending'),
                                      value: 'asc',
                                      groupValue: sortOrder,
                                      onChanged: (value) {
                                        setState(() {
                                          sortOrder = value;
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: Text('Descending'),
                                      value: 'desc',
                                      groupValue: sortOrder,
                                      onChanged: (value) {
                                        setState(() {
                                          sortOrder = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    clearSort();
                  },
                  child: Text('Clear Sort'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (sortBy != null) {
                      if (sortOrder == null) sortOrder = 'asc';
                      fetchAdmins();
                    }
                  },
                  child: Text('Apply Sort'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Pagination Methods
  void loadNextPage() {
    if (nextUrl != null && nextUrl!.isNotEmpty) {
      currentPage++;
      fetchAdmins(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchAdmins(url: prevUrl);
    }
  }

  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    await fetchAdmins();
  }

  // Create Admin Methods
  void showAddAdminDialog() {
    // Initialize controllers for required fields
    for (var field in requiredFields) {
      if (!excludeFromCreate.contains(field) &&
          !isFileField(field) &&
          !createControllers.containsKey(field)) {
        createControllers[field] = TextEditingController();
      }
    }

    // Reset selections
    profilePictureXFile = null;
    aadharPhotoXFile = null;
    selectedCreateStatus = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Admin'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCreateTextField(
                        'user_code', 'User Code', Icons.code,
                        isRequired: true),
                    _buildCreateTextField(
                        'bp_code', 'BP Code', Icons.qr_code,
                        isRequired: true),
                    _buildCreateTextField(
                        'full_name', 'Full Name', Icons.person,
                        isRequired: true),
                    _buildCreateTextField(
                        'email_id', 'Email ID', Icons.email,
                        isRequired: true),
                    _buildCreateTextField(
                        'mobile_no', 'Mobile No', Icons.phone,
                        isRequired: true),
                    _buildCreateTextField('password', 'Password', Icons.lock,
                        isRequired: true, isPassword: true),

                    // Status dropdown for create
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: DropdownButtonFormField<String>(
                        value: selectedCreateStatus,
                        decoration: InputDecoration(
                          labelText: 'Status *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info),
                        ),
                        items: statusOptions.map((option) {
                          return DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['display']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCreateStatus = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select status';
                          }
                          return null;
                        },
                      ),
                    ),

                    _buildCreateTextField('dob', 'Date of Birth', Icons.cake),
                    _buildCreateTextField('city', 'City', Icons.location_city),
                    _buildCreateTextField('state', 'State', Icons.map),
                    _buildCreateTextField('country', 'Country', Icons.public),
                    _buildCreateTextField('pincode', 'Pincode', Icons.pin_drop),
                    _buildCreateTextField(
                        'aadhar_number', 'Aadhar Number', Icons.credit_card),

                    _buildCreateFileField(
                        'profile_picture', 'Profile Picture', Icons.image, setState),
                    _buildCreateFileField(
                        'aadhar_photo', 'Aadhar Photo', Icons.credit_card, setState),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (selectedCreateStatus == null) {
                    _showSnackBar('Please select status', isError: true);
                    return;
                  }
                  await createAdmin();
                  Navigator.pop(context);
                },
                child: Text('Create'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCreateTextField(String field, String label, IconData icon,
      {bool isRequired = false, bool isPassword = false}) {
    if (!createControllers.containsKey(field)) {
      createControllers[field] = TextEditingController();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: createControllers[field],
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildCreateFileField(
      String field, String label, IconData icon, StateSetter setState) {
    XFile? currentFile = field == 'profile_picture' ? profilePictureXFile : aadharPhotoXFile;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await pickFile(field);
                    setState(() {});
                  },
                  icon: Icon(icon),
                  label: Text(
                    currentFile != null 
                        ? path.basename(currentFile.path)
                        : 'Select $label',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (currentFile != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      if (field == 'profile_picture') {
                        profilePictureXFile = null;
                      } else {
                        aadharPhotoXFile = null;
                      }
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> createAdmin() async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(createApiUrl));
      request.headers['Authorization'] = 'Token $token';

      // Add text fields
      createControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          request.fields[key] = controller.text;
        }
      });

      // Add status from dropdown
      if (selectedCreateStatus != null) {
        request.fields['status'] = selectedCreateStatus!;
      }

      // Add role_name
      request.fields['role_name'] = 'admin';

      // Add files with proper filenames and extensions
      if (profilePictureXFile != null) {
        String filename = path.basename(profilePictureXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(profilePictureXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          final bytes = await profilePictureXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_picture',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(profilePictureXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_picture',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      if (aadharPhotoXFile != null) {
        String filename = path.basename(aadharPhotoXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(aadharPhotoXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          final bytes = await aadharPhotoXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'aadhar_photo',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(aadharPhotoXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'aadhar_photo',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      var response = await request.send();

      if (response.statusCode == 201) {
        // Clear controllers
        createControllers.forEach((key, controller) {
          controller.clear();
        });

        profilePictureXFile = null;
        aadharPhotoXFile = null;
        selectedCreateStatus = null;

        await fetchAdmins();
        _showSnackBar('Admin created successfully!');
      } else {
        final responseBody = await response.stream.bytesToString();
        print('Error response: $responseBody');
        _showSnackBar('Failed to create admin', isError: true);
      }
    } catch (e) {
      print('Error in createAdmin: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // View Admin Details
  void showAdminDetailDialog() {
    if (currentViewedAdmin == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Admin Details'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: requiredFields
                  .where((field) => isFieldDisplayable(field))
                  .map((field) => _buildDetailField(field))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailField(String field) {
    dynamic value = currentViewedAdmin?[field];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '${formatFieldName(field)}:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _buildDetailValue(field, value),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailValue(String field, dynamic value) {
    if (isFileField(field)) {
      if (value != null && value.toString().isNotEmpty) {
        return InkWell(
          onTap: () =>
              _showFileDialog(formatFieldName(field), value.toString()),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'View File',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
      return Text('No file');
    }

    if (field == 'status') {
      return Text(getStatusDisplayValue(value));
    }

    if (value == null) return Text('-');
    if (value is bool) return Text(value.toString());
    return Text(value.toString());
  }

  // Edit Admin Methods
  void showEditAdminDialog(Map<String, dynamic> admin) {
    editingAdminId = admin['id'];
    editControllers = {};

    // Initialize edit controllers
    for (var field in requiredFields) {
      if (!excludeFromEdit.contains(field) && !isFileField(field)) {
        editControllers![field] = TextEditingController(
          text: admin[field]?.toString() ?? '',
        );
      }
    }

    // Set selected status for edit
    selectedEditStatus = admin['status'];

    // Reset file selections
    profilePictureXFile = null;
    aadharPhotoXFile = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit Admin'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditTextField('user_code', 'User Code', Icons.code),
                    _buildEditTextField('bp_code', 'BP Code', Icons.qr_code),
                    _buildEditTextField('full_name', 'Full Name', Icons.person),
                    _buildEditTextField('email_id', 'Email ID', Icons.email),
                    _buildEditTextField('mobile_no', 'Mobile No', Icons.phone),

                    // Status dropdown for edit
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: DropdownButtonFormField<String>(
                        value: selectedEditStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.info),
                        ),
                        items: statusOptions.map((option) {
                          return DropdownMenuItem(
                            value: option['value'],
                            child: Text(option['display']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedEditStatus = value;
                          });
                        },
                      ),
                    ),

                    _buildEditTextField('dob', 'Date of Birth', Icons.cake),
                    _buildEditTextField('city', 'City', Icons.location_city),
                    _buildEditTextField('state', 'State', Icons.map),
                    _buildEditTextField('country', 'Country', Icons.public),
                    _buildEditTextField('pincode', 'Pincode', Icons.pin_drop),
                    _buildEditTextField(
                        'aadhar_number', 'Aadhar Number', Icons.credit_card),

                    _buildEditFileField('profile_picture', 'Profile Picture',
                        Icons.image, admin, setState),
                    _buildEditFileField('aadhar_photo', 'Aadhar Photo',
                        Icons.credit_card, admin, setState),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await updateAdmin(editingAdminId!);
                  Navigator.pop(context);
                },
                child: Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  editControllers = null;
                  editingAdminId = null;
                  profilePictureXFile = null;
                  aadharPhotoXFile = null;
                  selectedEditStatus = null;
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditTextField(String field, String label, IconData icon) {
    if (editControllers == null || !editControllers!.containsKey(field)) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: editControllers![field],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildEditFileField(String field, String label, IconData icon,
      Map<String, dynamic> admin, StateSetter setState) {
    String? fileUrl = admin[field];
    XFile? currentFile = field == 'profile_picture' ? profilePictureXFile : aadharPhotoXFile;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 4),
          if (fileUrl != null && fileUrl.isNotEmpty && currentFile == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showFileDialog(label, fileUrl),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'View Existing Attachment',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await pickFile(field);
                    setState(() {});
                  },
                  icon: Icon(icon),
                  label: Text(
                    currentFile != null
                        ? path.basename(currentFile.path)
                        : 'Select New $label',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (currentFile != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      if (field == 'profile_picture') {
                        profilePictureXFile = null;
                      } else {
                        aadharPhotoXFile = null;
                      }
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> updateAdmin(int id) async {
    if (token == null || editControllers == null) return;

    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$updateApiUrl$id/'),
      );

      request.headers['Authorization'] = 'Token $token';

      // Add text fields
      editControllers!.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          request.fields[key] = controller.text;
        }
      });

      // Add status from dropdown
      if (selectedEditStatus != null) {
        request.fields['status'] = selectedEditStatus!;
      }

      // Add files if selected with proper filenames
      if (profilePictureXFile != null) {
        String filename = path.basename(profilePictureXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(profilePictureXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await profilePictureXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'profile_picture',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(profilePictureXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_picture',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      if (aadharPhotoXFile != null) {
        String filename = path.basename(aadharPhotoXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(aadharPhotoXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await aadharPhotoXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'aadhar_photo',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(aadharPhotoXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'aadhar_photo',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        editControllers = null;
        editingAdminId = null;
        profilePictureXFile = null;
        aadharPhotoXFile = null;
        selectedEditStatus = null;

        await fetchAdmins();
        _showSnackBar('Admin updated successfully!');
      } else {
        final responseBody = await response.stream.bytesToString();
        print('Error response: $responseBody');
        _showSnackBar('Failed to update admin', isError: true);
      }
    } catch (e) {
      print('Error in updateAdmin: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // File Picker
  Future<void> pickFile(String field) async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          if (field == 'profile_picture') {
            profilePictureXFile = file;
          } else if (field == 'aadhar_photo') {
            aadharPhotoXFile = file;
          }
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      _showSnackBar('Error picking file: $e', isError: true);
    }
  }

  // File Dialog
  void _showFileDialog(String title, String fileUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 50, color: Colors.blue),
            SizedBox(height: 16),
            Text('File URL:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                fileUrl,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement file download/open functionality
              print('Opening file: $fileUrl');
              Navigator.pop(context);
              _showSnackBar('Opening file...');
            },
            child: Text('Open'),
          ),
        ],
      ),
    );
  }

  // Utility Methods
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build Methods
  List<DataColumn> _buildTableColumns() {
    final selectedFields = getSelectedFields();

    List<DataColumn> columns = [
      DataColumn(
        label: Text(
          'Select',
          style: TextStyle(fontSize: compactRows ? 12 : 14),
        ),
      ),
      DataColumn(
        label: Text(
          'Actions',
          style: TextStyle(fontSize: compactRows ? 12 : 14),
        ),
      ),
    ];

    // Add selected fields as columns
    for (var field in selectedFields) {
      columns.add(
        DataColumn(
          label: GestureDetector(
            onTap: () {
              if (sortBy == field['key']) {
                toggleSortOrder();
              } else {
                applySort(field['key'], 'asc');
              }
            },
            child: Row(
              children: [
                Text(
                  field['label'],
                  style: TextStyle(fontSize: compactRows ? 11 : 13),
                ),
                if (sortBy == field['key'])
                  Icon(
                    sortOrder == 'desc'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: compactRows ? 14 : 16,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return columns;
  }

  List<DataRow> _buildTableRows() {
    if (admins.isEmpty) {
      int columnCount = _buildTableColumns().length;
      return [
        DataRow(
          cells: List.generate(
            columnCount,
            (index) => DataCell(
              index == 1 ? SizedBox.shrink() : Text('No data'),
            ),
          ),
        ),
      ];
    }

    final selectedFields = getSelectedFields();

    return admins.map((admin) {
      final id = admin['id'];
      final isSelected = selectedIds.contains(id);

      List<DataCell> cells = [
        // Select checkbox
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  // Clear all other selections and select only this one
                  selectedIds.clear();
                  selectedIds.add(id);
                } else {
                  selectedIds.remove(id);
                }
              });
            },
          ),
        ),

        // Actions - Show only if this row is selected and based on enableView/enableEdit settings
        DataCell(
          isSelected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show View button only if enableView is true
                    if (enableView)
                      ElevatedButton(
                        onPressed: () => fetchAdminDetails(id),
                        child: Text(
                          'View',
                          style: TextStyle(fontSize: compactRows ? 11 : 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(60, 30),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    
                    // Show Edit button only if enableEdit is true
                    if (enableEdit) ...[
                      if (enableView) SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () => showEditAdminDialog(admin),
                        child: Text(
                          'Edit',
                          style: TextStyle(fontSize: compactRows ? 11 : 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(60, 30),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ],
                )
              : SizedBox.shrink(),
        ),
      ];

      // Add selected field cells
      for (var field in selectedFields) {
        String displayValue = getFieldValue(admin, field['key']);

        // Special handling for file fields
        if (field['isFile'] == true && displayValue != '-') {
          cells.add(
            DataCell(
              InkWell(
                onTap: () => _showFileDialog(
                    field['label'], admin[field['key']].toString()),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: modernCellColoring
                        ? Colors.purple.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attachment,
                        size: compactRows ? 10 : 12,
                        color: modernCellColoring ? Colors.purple : Colors.blue,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: compactRows ? 10 : 12,
                          color: modernCellColoring
                              ? Colors.purple
                              : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          cells.add(
            DataCell(
              Container(
                constraints: BoxConstraints(maxWidth: 150),
                child: Text(
                  displayValue,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: compactRows ? 11 : 13,
                    color: modernCellColoring && isSelected
                        ? Colors.blue
                        : null,
                  ),
                ),
              ),
            ),
          );
        }
      }

      return DataRow(
        color: activeRowHighlighting && isSelected
            ? MaterialStateProperty.resolveWith<Color?>(
                (Set<MaterialState> states) {
                  return Colors.blue.shade50;
                },
              )
            : null,
        cells: cells,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin'),
        actions: [
          // Field Selection button
          IconButton(
            icon: Icon(Icons.view_column),
            onPressed: showFieldSelectionDialog,
            tooltip: 'Select Fields',
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: showSortDialog,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => fetchAdmins(),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: showAddAdminDialog,
              icon: Icon(Icons.add),
              label: Text('Add Admin'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Field selection summary
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.purple.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.view_column, size: 16, color: Colors.purple),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing ${getSelectedFields().length} fields',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: showFieldSelectionDialog,
                        icon: Icon(Icons.edit, size: 14),
                        label:
                            Text('Change', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

                // Active filters
                if (filterParams.length > 1)
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filters: ${filterParams.entries.where((e) => e.key != 'role_name').map((e) => '${e.key}=${e.value}').join(', ')}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16),
                          onPressed: clearFilters,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                // Active sort
                if (sortBy != null)
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.green.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.sort, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sort: ${formatFieldName(sortBy!)} (${sortOrder ?? 'asc'})',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 16),
                          onPressed: clearSort,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            sortOrder == 'desc'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                          ),
                          onPressed: toggleSortOrder,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                // Page size selector and selection info
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Page size:'),
                      SizedBox(width: 8),
                      DropdownButton<int>(
                        value: pageSize,
                        items: [10, 20, 50, 100].map((size) {
                          return DropdownMenuItem(
                            value: size,
                            child: Text('$size'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            changePageSize(value);
                          }
                        },
                      ),
                      Spacer(),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Selected: ${selectedIds.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Data table
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 8,
                    radius: Radius.circular(10),
                    controller: _horizontalScrollController,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: compactRows ? 15 : 20,
                          dataRowHeight: compactRows ? 40 : null,
                          headingRowHeight: compactRows ? 45 : null,
                          showCheckboxColumn: false,
                          columns: _buildTableColumns(),
                          rows: _buildTableRows(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pagination
                Container(
                  padding: EdgeInsets.all(compactRows ? 8 : 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page $currentPage of ${(totalCount / pageSize).ceil()} | Total: $totalCount',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: compactRows ? 11 : 13,
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: (prevUrl == null || prevUrl!.isEmpty)
                                ? null
                                : loadPrevPage,
                            child: Text(
                              'Previous',
                              style: TextStyle(
                                  fontSize: compactRows ? 11 : 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (prevUrl == null || prevUrl!.isEmpty)
                                      ? Colors.grey
                                      : null,
                              padding: EdgeInsets.symmetric(
                                horizontal: compactRows ? 8 : 16,
                                vertical: compactRows ? 4 : 8,
                              ),
                            ),
                          ),
                          SizedBox(width: compactRows ? 8 : 12),
                          ElevatedButton(
                            onPressed: (nextUrl == null || nextUrl!.isEmpty)
                                ? null
                                : loadNextPage,
                            child: Text(
                              'Next',
                              style: TextStyle(
                                  fontSize: compactRows ? 11 : 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (nextUrl == null || nextUrl!.isEmpty)
                                      ? Colors.grey
                                      : null,
                              padding: EdgeInsets.symmetric(
                                horizontal: compactRows ? 8 : 16,
                                vertical: compactRows ? 4 : 8,
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}


// import 'package:flutter/material.dart';
// // import 'package:url_launcher/url_launcher.dart';
// // import '../services/auth_service.dart';
// // import 'package:intl/intl.dart';
// import 'package:flutter/foundation.dart';
// import 'dart:typed_data';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:image_picker/image_picker.dart';
// // import 'dart:io';
// import 'dart:io';
// import 'package:http/http.dart' as http;
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

// class AdminPage extends StatefulWidget {
//   @override
//   _AdminPageState createState() => _AdminPageState();
// }

// class _AdminPageState extends State<AdminPage> {
//   // Data lists
//   List<Map<String, dynamic>> admins = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   Map<String, dynamic>? currentViewedAdmin;

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/user/admin/list/';
//   final String filterApiUrl = 'http://127.0.0.1:8000/user/admin/filter/';
//   final String createApiUrl = 'http://127.0.0.1:8000/user/Admin/registration/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/user/User/detail/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/user/Admin/update/';

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   int pageSize = 20;

//   // Filter and sort variables
//   Map<String, String> filterParams = {'role_name': 'admin'};
//   String? sortBy;
//   String? sortOrder;

//   // Scroll controller for horizontal scrolling
//   final ScrollController _horizontalScrollController = ScrollController();

//   // Search query for field selection
//   String fieldSearchQuery = '';

//   // List settings variables
//   bool compactRows = false;
//   bool activeRowHighlighting = false;
//   bool modernCellColoring = false;
//   bool enableView = true;
//   bool enableEdit = true;

//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'user_code', 'label': 'User Code', 'selected': true, 'order': 0},
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 1},
//     {'key': 'full_name', 'label': 'Full Name', 'selected': true, 'order': 2},
//     {'key': 'email_id', 'label': 'Email ID', 'selected': true, 'order': 3},
//     {'key': 'mobile_no', 'label': 'Mobile No', 'selected': true, 'order': 4},
//     {'key': 'status', 'label': 'Status', 'selected': true, 'order': 5},
//     {'key': 'dob', 'label': 'Date of Birth', 'selected': false, 'order': 6},
//     {'key': 'city', 'label': 'City', 'selected': true, 'order': 7},
//     {'key': 'state', 'label': 'State', 'selected': true, 'order': 8},
//     {'key': 'country', 'label': 'Country', 'selected': true, 'order': 9},
//     {'key': 'pincode', 'label': 'Pincode', 'selected': true, 'order': 10},
//     {'key': 'aadhar_number', 'label': 'Aadhar Number', 'selected': true, 'order': 11},
//     {'key': 'profile_picture', 'label': 'Profile Picture', 'selected': false, 'isFile': true, 'order': 12},
//     {'key': 'aadhar_photo', 'label': 'Aadhar Photo', 'selected': false, 'isFile': true, 'order': 13},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 14},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 15},
//   ];

//   // Filter controllers
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController fullNameController = TextEditingController();
//   final TextEditingController emailIdController = TextEditingController();
//   final TextEditingController mobileNoController = TextEditingController();
//   final TextEditingController cityController = TextEditingController();
//   final TextEditingController stateController = TextEditingController();
//   final TextEditingController pincodeController = TextEditingController();
//   final TextEditingController aadharNumberController = TextEditingController();

//   // Status dropdown for filter
//   String? selectedFilterStatus;

//   // Create controllers
//   final Map<String, TextEditingController> createControllers = {};

//   // Status dropdown for create
//   String? selectedCreateStatus;

//   // Edit controllers
//   Map<String, TextEditingController>? editControllers;
//   int? editingAdminId;

//   // Status dropdown for edit
//   String? selectedEditStatus;

//   // File uploads
//   File? profilePictureFile;
//   File? aadharPhotoFile;
//   String? profilePictureFileName;
//   String? aadharPhotoFileName;

//   // Status options
//   final List<Map<String, String>> statusOptions = [
//     {'display': 'Active', 'value': 'active'},
//     {'display': 'Inactive', 'value': 'inactive'},
//   ];

//   // Required fields for admin
//   final List<String> requiredFields = [
//     'profile_picture',
//     'role_name',
//     'user_code',
//     'bp_code',
//     'full_name',
//     'email_id',
//     'mobile_no',
//     'status',
//     'dob',
//     'city',
//     'state',
//     'country',
//     'pincode',
//     'aadhar_photo',
//     'aadhar_number',
//     'password',
//     'created_at',
//     'updated_at'
//   ];

//   // Fields to exclude from certain operations
//   final List<String> excludeFromCreate = ['created_at', 'updated_at', 'role_name'];
//   final List<String> excludeFromEdit = ['created_at', 'updated_at', 'password', 'role_name'];
//   final List<String> excludeFromDisplay = ['password'];

//   @override
//   void initState() {
//     super.initState();
//     loadSavedFieldSelections();
//     loadListSettings();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose filter controllers
//     bpCodeController.dispose();
//     fullNameController.dispose();
//     emailIdController.dispose();
//     mobileNoController.dispose();
//     cityController.dispose();
//     stateController.dispose();
//     pincodeController.dispose();
//     aadharNumberController.dispose();

//     // Dispose create controllers
//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });

//     // Dispose edit controllers
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }

//     // Dispose scroll controller
//     _horizontalScrollController.dispose();

//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('admin_fields');
//     String? savedOrder = prefs.getString('admin_field_order');

//     if (savedSelections != null) {
//       try {
//         Map<String, dynamic> savedMap = json.decode(savedSelections);
//         setState(() {
//           for (var field in availableFields) {
//             String key = field['key'];
//             if (savedMap.containsKey(key)) {
//               field['selected'] = savedMap[key] ?? field['selected'];
//             }
//           }
//         });
//       } catch (e) {
//         print('Error loading saved field selections: $e');
//       }
//     }

//     // Load saved field order
//     if (savedOrder != null) {
//       try {
//         List<dynamic> savedOrderList = json.decode(savedOrder);
//         setState(() {
//           // Reorder availableFields based on saved order
//           List<Map<String, dynamic>> reorderedFields = [];
//           for (String key in savedOrderList) {
//             final index = availableFields.indexWhere((f) => f['key'] == key);
//             if (index != -1) {
//               reorderedFields.add(availableFields[index]);
//             }
//           }
//           // Add any missing fields at the end
//           for (var field in availableFields) {
//             if (!reorderedFields.any((f) => f['key'] == field['key'])) {
//               reorderedFields.add(field);
//             }
//           }
//           availableFields = reorderedFields;

//           // Update order values
//           for (int i = 0; i < availableFields.length; i++) {
//             availableFields[i]['order'] = i;
//           }
//         });
//       } catch (e) {
//         print('Error loading saved field order: $e');
//       }
//     }
//   }

//   // Save field selections to SharedPreferences
//   Future<void> saveFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     Map<String, bool> selections = {};

//     for (var field in availableFields) {
//       selections[field['key']] = field['selected'];
//     }

//     await prefs.setString('admin_fields', json.encode(selections));

//     // Save field order
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('admin_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     setState(() {
//       compactRows = prefs.getBool('admin_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('admin_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('admin_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('admin_enable_view') ?? true;
//       enableEdit = prefs.getBool('admin_enable_edit') ?? true;
//     });
//   }

//   // Save list settings to SharedPreferences
//   Future<void> saveListSettings({
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableView,
//     required bool enableEdit,
//   }) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     await prefs.setBool('admin_compact_rows', compactRows);
//     await prefs.setBool('admin_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('admin_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('admin_enable_view', enableView);
//     await prefs.setBool('admin_enable_edit', enableEdit);
//   }

//   // Get selected fields for display in correct order
//   List<Map<String, dynamic>> getSelectedFields() {
//     return availableFields
//         .where((field) => field['selected'] == true)
//         .toList()
//       ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
//   }

//   // Show Group By / Field Selection Dialog
//   void showFieldSelectionDialog() {
//     fieldSearchQuery = ''; // Reset search when opening dialog

//     // Local variables for checkbox states
//     bool localCompactRows = compactRows;
//     bool localActiveRowHighlighting = activeRowHighlighting;
//     bool localModernCellColoring = modernCellColoring;
//     bool localEnableView = enableView;
//     bool localEnableEdit = enableEdit;

//     // Track selected field index for up/down movement
//     int selectedFieldIndex = -1;

//     // Create separate lists for available and selected fields
//     List<Map<String, dynamic>> availableFieldsList = [];
//     List<Map<String, dynamic>> selectedFieldsList = [];

//     // Populate both lists based on current selection state and order
//     // First, get all fields sorted by order
//     List<Map<String, dynamic>> sortedFields = List.from(availableFields)
//       ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));

//     for (var field in sortedFields) {
//       if (field['selected'] == true) {
//         selectedFieldsList.add(Map.from(field));
//       } else {
//         availableFieldsList.add(Map.from(field));
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             // Filter available fields based on search query
//             final filteredAvailableFields = fieldSearchQuery.isEmpty
//                 ? availableFieldsList
//                 : availableFieldsList.where((field) {
//                     return field['label']
//                             .toLowerCase()
//                             .contains(fieldSearchQuery.toLowerCase()) ||
//                         field['key']
//                             .toLowerCase()
//                             .contains(fieldSearchQuery.toLowerCase());
//                   }).toList();

//             return Dialog(
//               insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
//               child: Container(
//                 width: 950,
//                 constraints: BoxConstraints(maxHeight: 700),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Header
//                     Container(
//                       padding: EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         border: Border(
//                           bottom: BorderSide(color: Colors.grey.shade300),
//                         ),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.view_column, color: Colors.blue),
//                           SizedBox(width: 12),
//                           Text(
//                             'Personalize List Columns - Admins',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Search Field
//                     Padding(
//                       padding: EdgeInsets.all(16),
//                       child: TextField(
//                         decoration: InputDecoration(
//                           hintText: 'Search fields...',
//                           prefixIcon: Icon(Icons.search, size: 20),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           contentPadding:
//                               EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                         ),
//                         onChanged: (value) {
//                           setState(() {
//                             fieldSearchQuery = value;
//                           });
//                         },
//                       ),
//                     ),

//                     // Two-panel layout with arrow buttons in the middle
//                     Expanded(
//                       child: Row(
//                         children: [
//                           // Available Fields Panel (Left)
//                           Expanded(
//                             flex: 5,
//                             child: Container(
//                               decoration: BoxDecoration(
//                                 border: Border(
//                                   right: BorderSide(color: Colors.grey.shade300),
//                                 ),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Padding(
//                                     padding: EdgeInsets.symmetric(
//                                         horizontal: 16, vertical: 8),
//                                     child: Text(
//                                       'Available',
//                                       style: TextStyle(
//                                         fontWeight: FontWeight.w600,
//                                         fontSize: 14,
//                                       ),
//                                     ),
//                                   ),
//                                   Divider(height: 1),
//                                   Expanded(
//                                     child: filteredAvailableFields.isEmpty
//                                         ? Center(
//                                             child: Text('No fields found'),
//                                           )
//                                         : ListView.builder(
//                                             itemCount:
//                                                 filteredAvailableFields.length,
//                                             itemBuilder: (context, index) {
//                                               final field =
//                                                   filteredAvailableFields[index];
//                                               return ListTile(
//                                                 dense: true,
//                                                 title: Text(
//                                                   field['label'],
//                                                   style: TextStyle(fontSize: 14),
//                                                 ),
//                                                 subtitle: field['isFile'] == true
//                                                     ? Text('File field',
//                                                         style: TextStyle(
//                                                             fontSize: 11,
//                                                             color: Colors.grey))
//                                                     : null,
//                                                 trailing: Icon(
//                                                   Icons.add_circle_outline,
//                                                   color: Colors.blue,
//                                                   size: 22,
//                                                 ),
//                                                 onTap: () {
//                                                   setState(() {
//                                                     // Move field from available to selected
//                                                     field['selected'] = true;
//                                                     availableFieldsList.removeWhere(
//                                                         (f) =>
//                                                             f['key'] ==
//                                                             field['key']);
//                                                     selectedFieldsList.add(field);
//                                                     selectedFieldIndex =
//                                                         selectedFieldsList.length -
//                                                             1;
//                                                   });
//                                                 },
//                                               );
//                                             },
//                                           ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),

//                           // Arrow buttons in the middle
//                           Container(
//                             width: 60,
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 // Move right button
//                                 Container(
//                                   margin: EdgeInsets.only(bottom: 16),
//                                   child: IconButton(
//                                     icon: Icon(Icons.arrow_forward, size: 30),
//                                     color: Colors.blue,
//                                     onPressed: () {
//                                       setState(() {
//                                         // Move all available fields to selected
//                                         if (filteredAvailableFields.isNotEmpty) {
//                                           for (var field
//                                               in filteredAvailableFields.toList()) {
//                                             field['selected'] = true;
//                                             availableFieldsList.removeWhere(
//                                                 (f) =>
//                                                     f['key'] == field['key']);
//                                             selectedFieldsList.add(field);
//                                           }
//                                           if (selectedFieldsList.isNotEmpty) {
//                                             selectedFieldIndex =
//                                                 selectedFieldsList.length - 1;
//                                           }
//                                         }
//                                       });
//                                     },
//                                   ),
//                                 ),
//                                 // Move left button
//                                 Container(
//                                   margin: EdgeInsets.only(top: 16),
//                                   child: IconButton(
//                                     icon: Icon(Icons.arrow_back, size: 30),
//                                     color: Colors.orange,
//                                     onPressed: () {
//                                       setState(() {
//                                         // Move all selected fields back to available
//                                         if (selectedFieldsList.isNotEmpty) {
//                                           for (var field
//                                               in selectedFieldsList.toList()) {
//                                             field['selected'] = false;
//                                             selectedFieldsList.removeWhere(
//                                                 (f) =>
//                                                     f['key'] == field['key']);
//                                             availableFieldsList.add(field);
//                                           }
//                                           selectedFieldIndex = -1;
//                                         }
//                                       });
//                                     },
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),

//                           // Selected Fields Panel (Right)
//                           Expanded(
//                             flex: 5,
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Padding(
//                                   padding: EdgeInsets.symmetric(
//                                       horizontal: 16, vertical: 8),
//                                   child: Row(
//                                     mainAxisAlignment:
//                                         MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       Text(
//                                         'Selected',
//                                         style: TextStyle(
//                                           fontWeight: FontWeight.w600,
//                                           fontSize: 14,
//                                         ),
//                                       ),
//                                       Row(
//                                         children: [
//                                           if (selectedFieldsList.isNotEmpty)
//                                             TextButton(
//                                               onPressed: () {
//                                                 setState(() {
//                                                   // Move all selected fields back to available
//                                                   for (var field
//                                                       in selectedFieldsList
//                                                           .toList()) {
//                                                     field['selected'] = false;
//                                                   }
//                                                   availableFieldsList
//                                                       .addAll(selectedFieldsList);
//                                                   selectedFieldsList.clear();
//                                                   selectedFieldIndex = -1;
//                                                 });
//                                               },
//                                               style: TextButton.styleFrom(
//                                                 padding: EdgeInsets.zero,
//                                                 minimumSize: Size(0, 0),
//                                                 tapTargetSize:
//                                                     MaterialTapTargetSize
//                                                         .shrinkWrap,
//                                               ),
//                                               child: Text(
//                                                 'Remove all',
//                                                 style: TextStyle(
//                                                     fontSize: 12,
//                                                     color: Colors.red),
//                                               ),
//                                             ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Divider(height: 1),
//                                 Expanded(
//                                   child: selectedFieldsList.isEmpty
//                                       ? Center(
//                                           child: Text('No fields selected'),
//                                         )
//                                       : ListView.builder(
//                                           itemCount: selectedFieldsList.length,
//                                           itemBuilder: (context, index) {
//                                             final field = selectedFieldsList[index];
//                                             return Container(
//                                               color: selectedFieldIndex == index
//                                                   ? Colors.blue.shade50
//                                                   : null,
//                                               child: ListTile(
//                                                 dense: true,
//                                                 leading: Icon(
//                                                   Icons.drag_handle,
//                                                   color: Colors.grey,
//                                                   size: 18,
//                                                 ),
//                                                 title: Text(
//                                                   field['label'],
//                                                   style: TextStyle(
//                                                     fontSize: 14,
//                                                     fontWeight:
//                                                         selectedFieldIndex == index
//                                                             ? FontWeight.bold
//                                                             : FontWeight.w500,
//                                                   ),
//                                                 ),
//                                                 trailing: IconButton(
//                                                   icon: Icon(
//                                                     Icons.close,
//                                                     color: Colors.grey,
//                                                     size: 18,
//                                                   ),
//                                                   onPressed: () {
//                                                     setState(() {
//                                                       // Move field from selected to available
//                                                       field['selected'] = false;
//                                                       selectedFieldsList
//                                                           .removeAt(index);
//                                                       availableFieldsList
//                                                           .add(field);
//                                                       if (selectedFieldIndex >=
//                                                           selectedFieldsList
//                                                               .length) {
//                                                         selectedFieldIndex =
//                                                             selectedFieldsList
//                                                                     .length -
//                                                                 1;
//                                                       }
//                                                     });
//                                                   },
//                                                 ),
//                                                 onTap: () {
//                                                   setState(() {
//                                                     selectedFieldIndex = index;
//                                                   });
//                                                 },
//                                               ),
//                                             );
//                                           },
//                                         ),
//                                 ),

//                                 // Up/Down arrow buttons for selected fields
//                                 if (selectedFieldsList.isNotEmpty)
//                                   Container(
//                                     padding: EdgeInsets.symmetric(vertical: 8),
//                                     decoration: BoxDecoration(
//                                       border: Border(
//                                         top: BorderSide(color: Colors.grey.shade300),
//                                       ),
//                                     ),
//                                     child: Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                       children: [
//                                         IconButton(
//                                           icon: Icon(Icons.arrow_upward,
//                                               color: Colors.blue),
//                                           onPressed: selectedFieldIndex > 0
//                                               ? () {
//                                                   setState(() {
//                                                     // Move selected field up
//                                                     final field = selectedFieldsList
//                                                         .removeAt(
//                                                             selectedFieldIndex);
//                                                     selectedFieldsList.insert(
//                                                         selectedFieldIndex - 1,
//                                                         field);
//                                                     selectedFieldIndex =
//                                                         selectedFieldIndex - 1;
//                                                   });
//                                                 }
//                                               : null,
//                                         ),
//                                         SizedBox(width: 30),
//                                         IconButton(
//                                           icon: Icon(Icons.arrow_downward,
//                                               color: Colors.blue),
//                                           onPressed: selectedFieldIndex <
//                                                   selectedFieldsList.length - 1
//                                               ? () {
//                                                   setState(() {
//                                                     // Move selected field down
//                                                     final field = selectedFieldsList
//                                                         .removeAt(
//                                                             selectedFieldIndex);
//                                                     selectedFieldsList.insert(
//                                                         selectedFieldIndex + 1,
//                                                         field);
//                                                     selectedFieldIndex =
//                                                         selectedFieldIndex + 1;
//                                                   });
//                                                 }
//                                               : null,
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Bottom options section
//                     Container(
//                       padding: EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade50,
//                         border: Border(
//                           top: BorderSide(color: Colors.grey.shade300),
//                           bottom: BorderSide(color: Colors.grey.shade300),
//                         ),
//                       ),
//                       child: Column(
//                         children: [
//                           // First row of checkboxes
//                           Row(
//                             children: [
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localCompactRows,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localCompactRows = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Compact rows'),
//                               SizedBox(width: 32),
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localActiveRowHighlighting,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localActiveRowHighlighting = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Active row highlighting'),
//                               SizedBox(width: 32),
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localModernCellColoring,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localModernCellColoring = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Modern cell coloring'),
//                             ],
//                           ),
//                           SizedBox(height: 12),
//                           // Second row of checkboxes for View/Edit
//                           Row(
//                             children: [
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localEnableView,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localEnableView = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Enable View'),
//                               SizedBox(width: 32),
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localEnableEdit,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localEnableEdit = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Enable Edit'),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Footer with Reset button and metadata
//                     Container(
//                       padding:
//                           EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       decoration: BoxDecoration(
//                         border: Border(
//                           top: BorderSide(color: Colors.grey.shade300),
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           TextButton(
//                             onPressed: () {
//                               setState(() {
//                                 // Reset to default fields in the dialog
//                                 availableFieldsList.clear();
//                                 selectedFieldsList.clear();

//                                 List<Map<String, dynamic>> defaultFields = [
//                                   {
//                                     'key': 'user_code',
//                                     'label': 'User Code',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'bp_code',
//                                     'label': 'BP Code',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'full_name',
//                                     'label': 'Full Name',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'email_id',
//                                     'label': 'Email ID',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'mobile_no',
//                                     'label': 'Mobile No',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'status',
//                                     'label': 'Status',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'city',
//                                     'label': 'City',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'state',
//                                     'label': 'State',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'country',
//                                     'label': 'Country',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'pincode',
//                                     'label': 'Pincode',
//                                     'selected': true
//                                   },
//                                   {
//                                     'key': 'aadhar_number',
//                                     'label': 'Aadhar Number',
//                                     'selected': true
//                                   },
//                                 ];

//                                 for (var field in availableFields) {
//                                   bool isDefaultSelected = defaultFields
//                                       .any((df) => df['key'] == field['key']);
//                                   if (isDefaultSelected) {
//                                     field['selected'] = true;
//                                     selectedFieldsList.add(Map.from(field));
//                                   } else {
//                                     field['selected'] = false;
//                                     availableFieldsList.add(Map.from(field));
//                                   }
//                                 }

//                                 // Reset checkboxes to default
//                                 localCompactRows = false;
//                                 localActiveRowHighlighting = false;
//                                 localModernCellColoring = false;
//                                 localEnableView = true;
//                                 localEnableEdit = true;

//                                 selectedFieldIndex = -1;
//                               });
//                             },
//                             child: Text(
//                               'Reset to column defaults',
//                               style: TextStyle(
//                                 color: Colors.blue,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ),
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                               Text(
//                                 'Admins - Field Selection',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey.shade700,
//                                 ),
//                               ),
//                               Text(
//                                 'Customize visible columns',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color: Colors.grey.shade500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Action buttons
//                     Container(
//                       padding: EdgeInsets.all(16),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           TextButton(
//                             onPressed: () => Navigator.pop(context),
//                             child: Text('Cancel'),
//                           ),
//                           SizedBox(width: 12),
//                           ElevatedButton(
//                             onPressed: () async {
//                               // Apply the field selection and order to the actual availableFields
//                               this.setState(() {
//                                 // First set all fields to false
//                                 for (var field in availableFields) {
//                                   field['selected'] = false;
//                                 }

//                                 // Then set selected fields to true and update their order
//                                 for (int i = 0; i < selectedFieldsList.length;
//                                     i++) {
//                                   final selectedField = selectedFieldsList[i];
//                                   final index = availableFields.indexWhere(
//                                     (f) => f['key'] == selectedField['key'],
//                                   );
//                                   if (index != -1) {
//                                     availableFields[index]['selected'] = true;
//                                     availableFields[index]['order'] = i;
//                                   }
//                                 }

//                                 // Update order for unselected fields (keep them at the end)
//                                 int nextOrder = selectedFieldsList.length;
//                                 for (var field in availableFields) {
//                                   if (field['selected'] != true) {
//                                     field['order'] = nextOrder;
//                                     nextOrder++;
//                                   }
//                                 }

//                                 // Reorder availableFields based on order
//                                 availableFields.sort((a, b) =>
//                                     (a['order'] ?? 0).compareTo(b['order'] ?? 0));
//                               });

//                               // Save selections to SharedPreferences
//                               await saveFieldSelections();

//                               // Apply other settings
//                               applyListSettings(
//                                 compactRows: localCompactRows,
//                                 activeRowHighlighting: localActiveRowHighlighting,
//                                 modernCellColoring: localModernCellColoring,
//                                 enableView: localEnableView,
//                                 enableEdit: localEnableEdit,
//                               );

//                               Navigator.pop(context);
//                             },
//                             child: Text('Apply'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   // Apply list settings
//   void applyListSettings({
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableView,
//     required bool enableEdit,
//   }) {
//     // Save these settings to SharedPreferences
//     saveListSettings(
//       compactRows: compactRows,
//       activeRowHighlighting: activeRowHighlighting,
//       modernCellColoring: modernCellColoring,
//       enableView: enableView,
//       enableEdit: enableEdit,
//     );

//     // Apply the settings to the current view
//     setState(() {
//       this.compactRows = compactRows;
//       this.activeRowHighlighting = activeRowHighlighting;
//       this.modernCellColoring = modernCellColoring;
//       this.enableView = enableView;
//       this.enableEdit = enableEdit;
//     });

//     // Show confirmation
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('List settings applied'),
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }

//   // Helper Methods
//   int safeParseInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is double) return value.toInt();
//     if (value is String) return int.tryParse(value) ?? 0;
//     return 0;
//   }

//   String formatFieldName(String field) {
//     return field.replaceAll('_', ' ').toUpperCase();
//   }

//   bool isFileField(String field) {
//     return field == 'profile_picture' || field == 'aadhar_photo';
//   }

//   bool isFieldDisplayable(String field) {
//     return !excludeFromDisplay.contains(field) && field != 'password';
//   }

//   String getStatusDisplayValue(String? statusValue) {
//     if (statusValue == null) return '-';
//     for (var option in statusOptions) {
//       if (option['value'] == statusValue) {
//         return option['display']!;
//       }
//     }
//     return statusValue;
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> admin, String key) {
//     final value = admin[key];

//     if (value == null) return '-';

//     if (key == 'status') {
//       return getStatusDisplayValue(value);
//     }

//     if (value is bool) {
//       return value.toString();
//     }

//     return value.toString();
//   }

//   // Token Management
//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchAdmins();
//   }

//   // API Request Building
//   String buildRequestUrl({String? baseUrl}) {
//     String url = filterApiUrl;
//     Map<String, String> queryParams = {};

//     // Add role filter
//     queryParams['role_name'] = 'admin';

//     // Add filter parameters
//     filterParams.forEach((key, value) {
//       if (key != 'role_name' && value.isNotEmpty) {
//         queryParams[key] = value;
//       }
//     });

//     // Add sort parameters
//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }

//     // Add pagination
//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
//     if (currentPage > 1) {
//       queryParams['page'] = currentPage.toString();
//     }

//     Uri uri = Uri.parse(url);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Fetch Admins
//   Future<void> fetchAdmins({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final requestUrl = url ?? buildRequestUrl();
//       print('Fetching: $requestUrl');

//       final response = await http.get(
//         Uri.parse(requestUrl),
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

//         setState(() {
//           admins = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = safeParseInt(data['count']);

//           // Calculate current page
//           if (prevUrl == null && nextUrl != null) {
//             currentPage = 1;
//           } else if (prevUrl != null) {
//             final uri = Uri.parse(prevUrl!);
//             final pageParam = uri.queryParameters['page'];
//             if (pageParam != null) {
//               currentPage = int.parse(pageParam) + 1;
//             }
//           } else if (nextUrl != null) {
//             final uri = Uri.parse(nextUrl!);
//             final pageParam = uri.queryParameters['page'];
//             if (pageParam != null) {
//               currentPage = int.parse(pageParam) - 1;
//             }
//           }

//           // Clear selections when data refreshes
//           selectedIds.clear();
//           isLoading = false;
//         });
//       } else {
//         print('Error: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch admins', isError: true);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Fetch Single Admin Details
//   Future<void> fetchAdminDetails(int id) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final response = await http.get(
//         Uri.parse('$detailApiUrl$id/'),
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           currentViewedAdmin = data;
//           isLoading = false;
//         });
//         showAdminDetailDialog();
//       } else {
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch admin details', isError: true);
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Filter Methods
//   Future<void> applyFilters() async {
//     filterParams.clear();
//     filterParams['role_name'] = 'admin';

//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (fullNameController.text.isNotEmpty) {
//       filterParams['full_name'] = fullNameController.text;
//     }
//     if (emailIdController.text.isNotEmpty) {
//       filterParams['email_id'] = emailIdController.text;
//     }
//     if (mobileNoController.text.isNotEmpty) {
//       filterParams['mobile_no'] = mobileNoController.text;
//     }
//     if (selectedFilterStatus != null && selectedFilterStatus!.isNotEmpty) {
//       filterParams['status'] = selectedFilterStatus!;
//     }
//     if (cityController.text.isNotEmpty) {
//       filterParams['city'] = cityController.text;
//     }
//     if (stateController.text.isNotEmpty) {
//       filterParams['state'] = stateController.text;
//     }
//     if (pincodeController.text.isNotEmpty) {
//       filterParams['pincode'] = pincodeController.text;
//     }
//     if (aadharNumberController.text.isNotEmpty) {
//       filterParams['aadhar_number'] = aadharNumberController.text;
//     }

//     currentPage = 1;
//     await fetchAdmins();
//     Navigator.pop(context);
//   }

//   Future<void> clearFilters() async {
//     filterParams.clear();
//     filterParams['role_name'] = 'admin';

//     bpCodeController.clear();
//     fullNameController.clear();
//     emailIdController.clear();
//     mobileNoController.clear();
//     cityController.clear();
//     stateController.clear();
//     pincodeController.clear();
//     aadharNumberController.clear();

//     setState(() {
//       selectedFilterStatus = null;
//     });

//     await fetchAdmins();
//   }

//   void showFilterDialog() {
//     // Initialize controllers with current values
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     fullNameController.text = filterParams['full_name'] ?? '';
//     emailIdController.text = filterParams['email_id'] ?? '';
//     mobileNoController.text = filterParams['mobile_no'] ?? '';
//     cityController.text = filterParams['city'] ?? '';
//     stateController.text = filterParams['state'] ?? '';
//     pincodeController.text = filterParams['pincode'] ?? '';
//     aadharNumberController.text = filterParams['aadhar_number'] ?? '';

//     setState(() {
//       selectedFilterStatus = filterParams['status'];
//     });

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Filter Admins'),
//               content: Container(
//                 width: double.maxFinite,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       _buildFilterField(
//                           bpCodeController, 'BP Code', Icons.code),
//                       _buildFilterField(
//                           fullNameController, 'Full Name', Icons.person),
//                       _buildFilterField(
//                           emailIdController, 'Email ID', Icons.email),
//                       _buildFilterField(
//                           mobileNoController, 'Mobile No', Icons.phone),

//                       // Status dropdown filter
//                       Container(
//                         margin: EdgeInsets.symmetric(vertical: 6),
//                         child: DropdownButtonFormField<String>(
//                           value: selectedFilterStatus,
//                           decoration: InputDecoration(
//                             labelText: 'Status',
//                             border: OutlineInputBorder(),
//                             prefixIcon: Icon(Icons.info),
//                           ),
//                           items: [
//                             DropdownMenuItem(
//                               value: null,
//                               child: Text('All'),
//                             ),
//                             ...statusOptions.map((option) {
//                               return DropdownMenuItem(
//                                 value: option['value'],
//                                 child: Text(option['display']!),
//                               );
//                             }),
//                           ],
//                           onChanged: (value) {
//                             setState(() {
//                               selectedFilterStatus = value;
//                             });
//                           },
//                         ),
//                       ),

//                       _buildFilterField(
//                           cityController, 'City', Icons.location_city),
//                       _buildFilterField(stateController, 'State', Icons.map),
//                       _buildFilterField(
//                           pincodeController, 'Pincode', Icons.pin_drop),
//                       _buildFilterField(aadharNumberController,
//                           'Aadhar Number', Icons.credit_card),
//                     ],
//                   ),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     clearFilters();
//                   },
//                   child: Text('Clear All'),
//                 ),
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: applyFilters,
//                   child: Text('Apply Filters'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildFilterField(
//       TextEditingController controller, String label, IconData icon) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: controller,
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//       ),
//     );
//   }

//   // Sort Methods
//   Future<void> applySort(String field, String order) async {
//     setState(() {
//       sortBy = field;
//       sortOrder = order;
//     });
//     currentPage = 1;
//     await fetchAdmins();
//   }

//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchAdmins();
//   }

//   void toggleSortOrder() {
//     if (sortBy == null) return;
//     String newOrder = sortOrder == 'asc' ? 'desc' : 'asc';
//     applySort(sortBy!, newOrder);
//   }

//   void showSortDialog() {
//     List<Map<String, String>> sortFields = [
//       {'value': 'bp_code', 'label': 'BP Code'},
//       {'value': 'full_name', 'label': 'Full Name'},
//       {'value': 'email_id', 'label': 'Email ID'},
//       {'value': 'mobile_no', 'label': 'Mobile No'},
//       {'value': 'status', 'label': 'Status'},
//       {'value': 'dob', 'label': 'Date of Birth'},
//       {'value': 'city', 'label': 'City'},
//       {'value': 'state', 'label': 'State'},
//       {'value': 'country', 'label': 'Country'},
//       {'value': 'pincode', 'label': 'Pincode'},
//       {'value': 'aadhar_number', 'label': 'Aadhar Number'},
//       {'value': 'created_at', 'label': 'Created Date'},
//       {'value': 'user_code', 'label': 'User Code'},
//     ];

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Sort By'),
//               content: Container(
//                 width: double.maxFinite,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       ...sortFields.map((field) {
//                         return RadioListTile<String>(
//                           title: Text(field['label']!),
//                           value: field['value']!,
//                           groupValue: sortBy,
//                           onChanged: (value) {
//                             setState(() {
//                               this.sortBy = value;
//                               if (sortOrder == null) {
//                                 sortOrder = 'asc';
//                               }
//                             });
//                           },
//                           secondary: sortBy == field['value']
//                               ? IconButton(
//                                   icon: Icon(
//                                     sortOrder == 'desc'
//                                         ? Icons.arrow_downward
//                                         : Icons.arrow_upward,
//                                   ),
//                                   onPressed: () {
//                                     setState(() {
//                                       sortOrder = sortOrder == 'asc'
//                                           ? 'desc'
//                                           : 'asc';
//                                     });
//                                   },
//                                 )
//                               : null,
//                         );
//                       }).toList(),

//                       if (sortBy != null)
//                         Container(
//                           padding: EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             border:
//                                 Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Sort Order:',
//                                 style: TextStyle(fontWeight: FontWeight.bold),
//                               ),
//                               Row(
//                                 children: [
//                                   Expanded(
//                                     child: RadioListTile<String>(
//                                       title: Text('Ascending'),
//                                       value: 'asc',
//                                       groupValue: sortOrder,
//                                       onChanged: (value) {
//                                         setState(() {
//                                           sortOrder = value;
//                                         });
//                                       },
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: RadioListTile<String>(
//                                       title: Text('Descending'),
//                                       value: 'desc',
//                                       groupValue: sortOrder,
//                                       onChanged: (value) {
//                                         setState(() {
//                                           sortOrder = value;
//                                         });
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     clearSort();
//                   },
//                   child: Text('Clear Sort'),
//                 ),
//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     if (sortBy != null) {
//                       if (sortOrder == null) sortOrder = 'asc';
//                       fetchAdmins();
//                     }
//                   },
//                   child: Text('Apply Sort'),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   // Pagination Methods
//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchAdmins(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchAdmins(url: prevUrl);
//     }
//   }

//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
//     await fetchAdmins();
//   }

//   // Create Admin Methods
//   void showAddAdminDialog() {
//     // Initialize controllers for required fields
//     for (var field in requiredFields) {
//       if (!excludeFromCreate.contains(field) &&
//           !isFileField(field) &&
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }

//     // Reset selections
//     profilePictureFile = null;
//     aadharPhotoFile = null;
//     profilePictureFileName = null;
//     aadharPhotoFileName = null;
//     selectedCreateStatus = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Admin'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildCreateTextField(
//                         'user_code', 'User Code', Icons.code,
//                         isRequired: true),
//                     _buildCreateTextField(
//                         'bp_code', 'BP Code', Icons.qr_code,
//                         isRequired: true),
//                     _buildCreateTextField(
//                         'full_name', 'Full Name', Icons.person,
//                         isRequired: true),
//                     _buildCreateTextField(
//                         'email_id', 'Email ID', Icons.email,
//                         isRequired: true),
//                     _buildCreateTextField(
//                         'mobile_no', 'Mobile No', Icons.phone,
//                         isRequired: true),
//                     _buildCreateTextField('password', 'Password', Icons.lock,
//                         isRequired: true, isPassword: true),

//                     // Status dropdown for create
//                     Container(
//                       margin: EdgeInsets.symmetric(vertical: 6),
//                       child: DropdownButtonFormField<String>(
//                         value: selectedCreateStatus,
//                         decoration: InputDecoration(
//                           labelText: 'Status *',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.info),
//                         ),
//                         items: statusOptions.map((option) {
//                           return DropdownMenuItem(
//                             value: option['value'],
//                             child: Text(option['display']!),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           setState(() {
//                             selectedCreateStatus = value;
//                           });
//                         },
//                         validator: (value) {
//                           if (value == null) {
//                             return 'Please select status';
//                           }
//                           return null;
//                         },
//                       ),
//                     ),

//                     _buildCreateTextField('dob', 'Date of Birth', Icons.cake),
//                     _buildCreateTextField('city', 'City', Icons.location_city),
//                     _buildCreateTextField('state', 'State', Icons.map),
//                     _buildCreateTextField('country', 'Country', Icons.public),
//                     _buildCreateTextField('pincode', 'Pincode', Icons.pin_drop),
//                     _buildCreateTextField(
//                         'aadhar_number', 'Aadhar Number', Icons.credit_card),

//                     _buildCreateFileField(
//                         'profile_picture', 'Profile Picture', Icons.image, setState),
//                     _buildCreateFileField(
//                         'aadhar_photo', 'Aadhar Photo', Icons.credit_card, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   if (selectedCreateStatus == null) {
//                     _showSnackBar('Please select status', isError: true);
//                     return;
//                   }
//                   await createAdmin();
//                   Navigator.pop(context);
//                 },
//                 child: Text('Create'),
//               ),
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Cancel'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildCreateTextField(String field, String label, IconData icon,
//       {bool isRequired = false, bool isPassword = false}) {
//     if (!createControllers.containsKey(field)) {
//       createControllers[field] = TextEditingController();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: createControllers[field],
//         obscureText: isPassword,
//         decoration: InputDecoration(
//           labelText: isRequired ? '$label *' : label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//       ),
//     );
//   }

//   Widget _buildCreateFileField(
//       String field, String label, IconData icon, StateSetter setState) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
//           ),
//           SizedBox(height: 4),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field);
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     field == 'profile_picture'
//                         ? (profilePictureFileName ??
//                             'Select Profile Picture')
//                         : (aadharPhotoFileName ?? 'Select Aadhar Photo'),
//                   ),
//                 ),
//               ),
//               if ((field == 'profile_picture' && profilePictureFileName != null) ||
//                   (field == 'aadhar_photo' && aadharPhotoFileName != null))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       if (field == 'profile_picture') {
//                         profilePictureFile = null;
//                         profilePictureFileName = null;
//                       } else {
//                         aadharPhotoFile = null;
//                         aadharPhotoFileName = null;
//                       }
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> createAdmin() async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       var request =
//           http.MultipartRequest('POST', Uri.parse(createApiUrl));
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && !isFileField(key)) {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add status from dropdown
//       if (selectedCreateStatus != null) {
//         request.fields['status'] = selectedCreateStatus!;
//       }

//       // Add role_name
//       request.fields['role_name'] = 'admin';

//       // Add files

//       // Profile Picture Upload
//       if (profilePictureFile != null) {
//         if (kIsWeb) {
//           final bytes = await profilePictureFile!.readAsBytes();

//           request.files.add(
//             http.MultipartFile.fromBytes(
//               'profile_picture',
//               bytes,
//               filename: path.basename(profilePictureFile!.path),
//             ),
//           );
//         } else {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'profile_picture',
//               profilePictureFile!.path,
//               filename: path.basename(profilePictureFile!.path),
//             ),
//           );
//         }
//       }
//       if (aadharPhotoFile != null) {
//         if (kIsWeb) {
//           final bytes = await aadharPhotoFile!.readAsBytes();

//           request.files.add(
//             http.MultipartFile.fromBytes(
//               'aadhar_photo',
//               bytes,
//               filename: path.basename(aadharPhotoFile!.path),
//             ),
//           );
//         } else {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'aadhar_photo',
//               aadharPhotoFile!.path,
//               filename: path.basename(aadharPhotoFile!.path),
//             ),
//           );
//         }
//       }
//       // if (profilePictureFile != null) {
//       //   request.files.add(
//       //     await http.MultipartFile.fromPath(
//       //       'profile_picture',
//       //       profilePictureFile!.path,
//       //       filename: profilePictureFileName,
//       //     ),
//       //   );
//       // }

//       // if (aadharPhotoFile != null) {
//       //   request.files.add(
//       //     await http.MultipartFile.fromPath(
//       //       'aadhar_photo',
//       //       aadharPhotoFile!.path,
//       //       filename: aadharPhotoFileName,
//       //     ),
//       //   );
//       // }

//       var response = await request.send();

//       if (response.statusCode == 201) {
//         // Clear controllers
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });

//         profilePictureFile = null;
//         aadharPhotoFile = null;
//         profilePictureFileName = null;
//         aadharPhotoFileName = null;
//         selectedCreateStatus = null;

//         await fetchAdmins();
//         _showSnackBar('Admin created successfully!');
//       } else {
//         final responseBody = await response.stream.bytesToString();
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to create admin', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // View Admin Details
//   void showAdminDetailDialog() {
//     if (currentViewedAdmin == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Admin Details'),
//         content: Container(
//           width: double.maxFinite,
//           constraints: BoxConstraints(
//             maxHeight: MediaQuery.of(context).size.height * 0.7,
//           ),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: requiredFields
//                   .where((field) => isFieldDisplayable(field))
//                   .map((field) => _buildDetailField(field))
//                   .toList(),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailField(String field) {
//     dynamic value = currentViewedAdmin?[field];

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 140,
//             child: Text(
//               '${formatFieldName(field)}:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//           Expanded(
//             child: _buildDetailValue(field, value),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailValue(String field, dynamic value) {
//     if (isFileField(field)) {
//       if (value != null && value.toString().isNotEmpty) {
//         return InkWell(
//           onTap: () =>
//               _showFileDialog(formatFieldName(field), value.toString()),
//           child: Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade50,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Text(
//               'View File',
//               style: TextStyle(
//                 color: Colors.blue,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         );
//       }
//       return Text('No file');
//     }

//     if (field == 'status') {
//       return Text(getStatusDisplayValue(value));
//     }

//     if (value == null) return Text('-');
//     if (value is bool) return Text(value.toString());
//     return Text(value.toString());
//   }

//   // Edit Admin Methods
//   void showEditAdminDialog(Map<String, dynamic> admin) {
//     editingAdminId = admin['id'];
//     editControllers = {};

//     // Initialize edit controllers
//     for (var field in requiredFields) {
//       if (!excludeFromEdit.contains(field) && !isFileField(field)) {
//         editControllers![field] = TextEditingController(
//           text: admin[field]?.toString() ?? '',
//         );
//       }
//     }

//     // Set selected status for edit
//     selectedEditStatus = admin['status'];

//     // Reset file selections
//     profilePictureFile = null;
//     aadharPhotoFile = null;
//     profilePictureFileName = null;
//     aadharPhotoFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Edit Admin'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildEditTextField('user_code', 'User Code', Icons.code),
//                     _buildEditTextField('bp_code', 'BP Code', Icons.qr_code),
//                     _buildEditTextField('full_name', 'Full Name', Icons.person),
//                     _buildEditTextField('email_id', 'Email ID', Icons.email),
//                     _buildEditTextField('mobile_no', 'Mobile No', Icons.phone),

//                     // Status dropdown for edit
//                     Container(
//                       margin: EdgeInsets.symmetric(vertical: 6),
//                       child: DropdownButtonFormField<String>(
//                         value: selectedEditStatus,
//                         decoration: InputDecoration(
//                           labelText: 'Status',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.info),
//                         ),
//                         items: statusOptions.map((option) {
//                           return DropdownMenuItem(
//                             value: option['value'],
//                             child: Text(option['display']!),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           setState(() {
//                             selectedEditStatus = value;
//                           });
//                         },
//                       ),
//                     ),

//                     _buildEditTextField('dob', 'Date of Birth', Icons.cake),
//                     _buildEditTextField('city', 'City', Icons.location_city),
//                     _buildEditTextField('state', 'State', Icons.map),
//                     _buildEditTextField('country', 'Country', Icons.public),
//                     _buildEditTextField('pincode', 'Pincode', Icons.pin_drop),
//                     _buildEditTextField(
//                         'aadhar_number', 'Aadhar Number', Icons.credit_card),

//                     _buildEditFileField('profile_picture', 'Profile Picture',
//                         Icons.image, admin, setState),
//                     _buildEditFileField('aadhar_photo', 'Aadhar Photo',
//                         Icons.credit_card, admin, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await updateAdmin(editingAdminId!);
//                   Navigator.pop(context);
//                 },
//                 child: Text('Save'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   editControllers = null;
//                   editingAdminId = null;
//                   profilePictureFile = null;
//                   aadharPhotoFile = null;
//                   profilePictureFileName = null;
//                   aadharPhotoFileName = null;
//                   selectedEditStatus = null;
//                   Navigator.pop(context);
//                 },
//                 child: Text('Cancel'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildEditTextField(String field, String label, IconData icon) {
//     if (editControllers == null || !editControllers!.containsKey(field)) {
//       return SizedBox.shrink();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: editControllers![field],
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//       ),
//     );
//   }

//   Widget _buildEditFileField(String field, String label, IconData icon,
//       Map<String, dynamic> admin, StateSetter setState) {
//     String? fileUrl = admin[field];

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
//           ),
//           SizedBox(height: 4),
//           if (fileUrl != null && fileUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () => _showFileDialog(label, fileUrl),
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       'View Existing Attachment',
//                       style: TextStyle(
//                         color: Colors.blue,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 8),
//               ],
//             ),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field);
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     field == 'profile_picture'
//                         ? (profilePictureFileName ??
//                             'Select New Profile Picture')
//                         : (aadharPhotoFileName ?? 'Select New Aadhar Photo'),
//                   ),
//                 ),
//               ),
//               if ((field == 'profile_picture' && profilePictureFileName != null) ||
//                   (field == 'aadhar_photo' && aadharPhotoFileName != null))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       if (field == 'profile_picture') {
//                         profilePictureFile = null;
//                         profilePictureFileName = null;
//                       } else {
//                         aadharPhotoFile = null;
//                         aadharPhotoFileName = null;
//                       }
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> updateAdmin(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('$updateApiUrl$id/'),
//       );

//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       editControllers!.forEach((key, controller) {
//         if (!isFileField(key)) {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add status from dropdown
//       if (selectedEditStatus != null) {
//         request.fields['status'] = selectedEditStatus!;
//       }

//       // Add files if selected
      
//       // Profile Picture Upload

//       if (profilePictureFile != null) {
//         if (kIsWeb) {
//           Uint8List bytes = await profilePictureFile!.readAsBytes();

//           request.files.add(
//             http.MultipartFile.fromBytes(
//               'profile_picture',
//               bytes,
//               filename: profilePictureFileName ?? 'profile_picture.jpg',
//             ),
//           );
//         } else {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'profile_picture',
//               profilePictureFile!.path!,   // important !
//               filename: profilePictureFileName ?? 'profile_picture.jpg',
//             ),
//           );
//         }
//       }

//       if (aadharPhotoFile != null) {
//         if (kIsWeb) {
//           Uint8List bytes = await aadharPhotoFile!.readAsBytes();

//           request.files.add(
//             http.MultipartFile.fromBytes(
//               'aadhar_photo',
//               bytes,
//               filename: aadharPhotoFileName ?? 'aadhar_photo.jpg',
//             ),
//           );
//         } else {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'aadhar_photo',
//               aadharPhotoFile!.path!,   // important !
//               filename: aadharPhotoFileName ?? 'aadhar_photo.jpg',
//             ),
//           );
//         }
//       }
//       // if (profilePictureFile != null) {
//       //   if (kIsWeb) {
//       //     Uint8List bytes = await profilePictureFile!.readAsBytes();

//       //     request.files.add(
//       //       http.MultipartFile.fromBytes(
//       //         'profile_picture',
//       //         bytes,
//       //         filename: profilePictureFileName,
//       //       ),
//       //     );
//       //   } else {
//       //     request.files.add(
//       //       await http.MultipartFile.fromPath(
//       //         'profile_picture',
//       //         profilePictureFile!.path,
//       //         filename: profilePictureFileName,
//       //       ),
//       //     );
//       //   }
//       // }

//       // // Aadhar Photo Upload
//       // if (aadharPhotoFile != null) {
//       //   if (kIsWeb) {
//       //     Uint8List bytes = await aadharPhotoFile!.readAsBytes();

//       //     request.files.add(
//       //       http.MultipartFile.fromBytes(
//       //         'aadhar_photo',
//       //         bytes,
//       //         filename: aadharPhotoFileName,
//       //       ),
//       //     );
//       //   } else {
//       //     request.files.add(
//       //       await http.MultipartFile.fromPath(
//       //         'aadhar_photo',
//       //         aadharPhotoFile!.path,
//       //         filename: aadharPhotoFileName,
//       //       ),
//       //     );
//       //   }
//       // }
//       // if (profilePictureFile != null) {
//       //   request.files.add(
//       //     await http.MultipartFile.fromPath(
//       //       'profile_picture',
//       //       profilePictureFile!.path,
//       //       filename: profilePictureFileName,
//       //     ),
//       //   );
//       // }

//       // if (aadharPhotoFile != null) {
//       //   request.files.add(
//       //     await http.MultipartFile.fromPath(
//       //       'aadhar_photo',
//       //       aadharPhotoFile!.path,
//       //       filename: aadharPhotoFileName,
//       //     ),
//       //   );
//       // }

//       var response = await request.send();

//       if (response.statusCode == 200) {
//         editControllers = null;
//         editingAdminId = null;
//         profilePictureFile = null;
//         aadharPhotoFile = null;
//         profilePictureFileName = null;
//         aadharPhotoFileName = null;
//         selectedEditStatus = null;

//         await fetchAdmins();
//         _showSnackBar('Admin updated successfully!');
//       } else {
//         final responseBody = await response.stream.bytesToString();
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to update admin', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // File Picker
//   Future<void> pickFile(String field) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);

//     if (file != null) {
//       setState(() {
//         if (field == 'profile_picture') {
//           profilePictureFile = File(file.path);
//           profilePictureFileName = path.basename(file.path);
//         } else if (field == 'aadhar_photo') {
//           aadharPhotoFile = File(file.path);
//           aadharPhotoFileName = path.basename(file.path);
//         }
//       });
//     }
//   }

//   // File Dialog
//   void _showFileDialog(String title, String fileUrl) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(title),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.insert_drive_file, size: 50, color: Colors.blue),
//             SizedBox(height: 16),
//             Text('File URL:'),
//             SizedBox(height: 8),
//             Container(
//               padding: EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: SelectableText(
//                 fileUrl,
//                 style: TextStyle(fontSize: 12),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               // Implement file download/open functionality
//               print('Opening file: $fileUrl');
//               Navigator.pop(context);
//               _showSnackBar('Opening file...');
//             },
//             child: Text('Open'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Utility Methods
//   void _showSnackBar(String message, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? Colors.red : Colors.green,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   // Build Methods
//   List<DataColumn> _buildTableColumns() {
//     final selectedFields = getSelectedFields();

//     List<DataColumn> columns = [
//       DataColumn(
//         label: Text(
//           'Select',
//           style: TextStyle(fontSize: compactRows ? 12 : 14),
//         ),
//       ),
//       DataColumn(
//         label: Text(
//           'Actions',
//           style: TextStyle(fontSize: compactRows ? 12 : 14),
//         ),
//       ),
//     ];

//     // Add selected fields as columns
//     for (var field in selectedFields) {
//       columns.add(
//         DataColumn(
//           label: GestureDetector(
//             onTap: () {
//               if (sortBy == field['key']) {
//                 toggleSortOrder();
//               } else {
//                 applySort(field['key'], 'asc');
//               }
//             },
//             child: Row(
//               children: [
//                 Text(
//                   field['label'],
//                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                 ),
//                 if (sortBy == field['key'])
//                   Icon(
//                     sortOrder == 'desc'
//                         ? Icons.arrow_downward
//                         : Icons.arrow_upward,
//                     size: compactRows ? 14 : 16,
//                   ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     return columns;
//   }

//   List<DataRow> _buildTableRows() {
//     if (admins.isEmpty) {
//       int columnCount = _buildTableColumns().length;
//       return [
//         DataRow(
//           cells: List.generate(
//             columnCount,
//             (index) => DataCell(
//               index == 1 ? SizedBox.shrink() : Text('No data'),
//             ),
//           ),
//         ),
//       ];
//     }

//     final selectedFields = getSelectedFields();

//     return admins.map((admin) {
//       final id = admin['id'];
//       final isSelected = selectedIds.contains(id);

//       List<DataCell> cells = [
//         // Select checkbox
//         DataCell(
//           Checkbox(
//             value: isSelected,
//             onChanged: (v) {
//               setState(() {
//                 if (v == true) {
//                   // Clear all other selections and select only this one
//                   selectedIds.clear();
//                   selectedIds.add(id);
//                 } else {
//                   selectedIds.remove(id);
//                 }
//               });
//             },
//           ),
//         ),

//         // Actions - Show only if this row is selected and based on enableView/enableEdit settings
//         DataCell(
//           isSelected
//               ? Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Show View button only if enableView is true
//                     if (enableView)
//                       ElevatedButton(
//                         onPressed: () => fetchAdminDetails(id),
//                         child: Text(
//                           'View',
//                           style: TextStyle(fontSize: compactRows ? 11 : 13),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           minimumSize: Size(60, 30),
//                           padding: EdgeInsets.symmetric(horizontal: 8),
//                         ),
//                       ),
                    
//                     // Show Edit button only if enableEdit is true
//                     if (enableEdit) ...[
//                       if (enableView) SizedBox(width: 4),
//                       ElevatedButton(
//                         onPressed: () => showEditAdminDialog(admin),
//                         child: Text(
//                           'Edit',
//                           style: TextStyle(fontSize: compactRows ? 11 : 13),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           minimumSize: Size(60, 30),
//                           padding: EdgeInsets.symmetric(horizontal: 8),
//                         ),
//                       ),
//                     ],
//                   ],
//                 )
//               : SizedBox.shrink(),
//         ),
//       ];

//       // Add selected field cells
//       for (var field in selectedFields) {
//         String displayValue = getFieldValue(admin, field['key']);

//         // Special handling for file fields
//         if (field['isFile'] == true && displayValue != '-') {
//           cells.add(
//             DataCell(
//               InkWell(
//                 onTap: () => _showFileDialog(
//                     field['label'], admin[field['key']].toString()),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: modernCellColoring
//                         ? Colors.purple.shade50
//                         : Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.attachment,
//                         size: compactRows ? 10 : 12,
//                         color: modernCellColoring ? Colors.purple : Colors.blue,
//                       ),
//                       SizedBox(width: 2),
//                       Text(
//                         'View',
//                         style: TextStyle(
//                           fontSize: compactRows ? 10 : 12,
//                           color: modernCellColoring
//                               ? Colors.purple
//                               : Colors.blue,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           );
//         } else {
//           cells.add(
//             DataCell(
//               Container(
//                 constraints: BoxConstraints(maxWidth: 150),
//                 child: Text(
//                   displayValue,
//                   overflow: TextOverflow.ellipsis,
//                   maxLines: 2,
//                   style: TextStyle(
//                     fontSize: compactRows ? 11 : 13,
//                     color: modernCellColoring && isSelected
//                         ? Colors.blue
//                         : null,
//                   ),
//                 ),
//               ),
//             ),
//           );
//         }
//       }

//       return DataRow(
//         color: activeRowHighlighting && isSelected
//             ? MaterialStateProperty.resolveWith<Color?>(
//                 (Set<MaterialState> states) {
//                   return Colors.blue.shade50;
//                 },
//               )
//             : null,
//         cells: cells,
//       );
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admin'),
//         actions: [
//           // Field Selection button
//           IconButton(
//             icon: Icon(Icons.view_column),
//             onPressed: showFieldSelectionDialog,
//             tooltip: 'Select Fields',
//           ),
//           IconButton(
//             icon: Icon(Icons.filter_list),
//             onPressed: showFilterDialog,
//             tooltip: 'Filter',
//           ),
//           IconButton(
//             icon: Icon(Icons.sort),
//             onPressed: showSortDialog,
//             tooltip: 'Sort',
//           ),
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () => fetchAdmins(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddAdminDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add Admin'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 foregroundColor: Colors.white,
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 // Field selection summary
//                 Container(
//                   padding: EdgeInsets.all(8),
//                   color: Colors.purple.shade50,
//                   child: Row(
//                     children: [
//                       Icon(Icons.view_column, size: 16, color: Colors.purple),
//                       SizedBox(width: 8),
//                       Expanded(
//                         child: Text(
//                           'Showing ${getSelectedFields().length} fields',
//                           style: TextStyle(fontSize: 12),
//                         ),
//                       ),
//                       TextButton.icon(
//                         onPressed: showFieldSelectionDialog,
//                         icon: Icon(Icons.edit, size: 14),
//                         label:
//                             Text('Change', style: TextStyle(fontSize: 12)),
//                         style: TextButton.styleFrom(
//                           padding: EdgeInsets.zero,
//                           minimumSize: Size(0, 0),
//                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // Active filters
//                 if (filterParams.length > 1)
//                   Container(
//                     padding: EdgeInsets.all(8),
//                     color: Colors.blue.shade50,
//                     child: Row(
//                       children: [
//                         Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             'Filters: ${filterParams.entries.where((e) => e.key != 'role_name').map((e) => '${e.key}=${e.value}').join(', ')}',
//                             style: TextStyle(fontSize: 12),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.close, size: 16),
//                           onPressed: clearFilters,
//                           padding: EdgeInsets.zero,
//                           constraints: BoxConstraints(),
//                         ),
//                       ],
//                     ),
//                   ),

//                 // Active sort
//                 if (sortBy != null)
//                   Container(
//                     padding: EdgeInsets.all(8),
//                     color: Colors.green.shade50,
//                     child: Row(
//                       children: [
//                         Icon(Icons.sort, size: 16, color: Colors.green),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             'Sort: ${formatFieldName(sortBy!)} (${sortOrder ?? 'asc'})',
//                             style: TextStyle(fontSize: 12),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.close, size: 16),
//                           onPressed: clearSort,
//                           padding: EdgeInsets.zero,
//                           constraints: BoxConstraints(),
//                         ),
//                         IconButton(
//                           icon: Icon(
//                             sortOrder == 'desc'
//                                 ? Icons.arrow_downward
//                                 : Icons.arrow_upward,
//                           ),
//                           onPressed: toggleSortOrder,
//                           padding: EdgeInsets.zero,
//                           constraints: BoxConstraints(),
//                         ),
//                       ],
//                     ),
//                   ),

//                 // Page size selector and selection info
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   child: Row(
//                     children: [
//                       Text('Page size:'),
//                       SizedBox(width: 8),
//                       DropdownButton<int>(
//                         value: pageSize,
//                         items: [10, 20, 50, 100].map((size) {
//                           return DropdownMenuItem(
//                             value: size,
//                             child: Text('$size'),
//                           );
//                         }).toList(),
//                         onChanged: (value) {
//                           if (value != null) {
//                             changePageSize(value);
//                           }
//                         },
//                       ),
//                       Spacer(),
//                       Container(
//                         padding:
//                             EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: Colors.blue.shade50,
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Text(
//                           'Selected: ${selectedIds.length}',
//                           style: TextStyle(
//                             fontWeight: FontWeight.w500,
//                             color: Colors.blue.shade700,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 // Data table
//                 Expanded(
//                   child: Scrollbar(
//                     thumbVisibility: true,
//                     trackVisibility: true,
//                     thickness: 8,
//                     radius: Radius.circular(10),
//                     controller: _horizontalScrollController,
//                     child: SingleChildScrollView(
//                       controller: _horizontalScrollController,
//                       scrollDirection: Axis.horizontal,
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: DataTable(
//                           columnSpacing: compactRows ? 15 : 20,
//                           dataRowHeight: compactRows ? 40 : null,
//                           headingRowHeight: compactRows ? 45 : null,
//                           showCheckboxColumn: false,
//                           columns: _buildTableColumns(),
//                           rows: _buildTableRows(),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 // Pagination
//                 Container(
//                   padding: EdgeInsets.all(compactRows ? 8 : 12),
//                   decoration: BoxDecoration(
//                     border: Border(
//                       top: BorderSide(color: Colors.grey.shade300),
//                     ),
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Page $currentPage of ${(totalCount / pageSize).ceil()} | Total: $totalCount',
//                         style: TextStyle(
//                           fontWeight: FontWeight.w600,
//                           fontSize: compactRows ? 11 : 13,
//                         ),
//                       ),
//                       Row(
//                         children: [
//                           ElevatedButton(
//                             onPressed: (prevUrl == null || prevUrl!.isEmpty)
//                                 ? null
//                                 : loadPrevPage,
//                             child: Text(
//                               'Previous',
//                               style: TextStyle(
//                                   fontSize: compactRows ? 11 : 13),
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor:
//                                   (prevUrl == null || prevUrl!.isEmpty)
//                                       ? Colors.grey
//                                       : null,
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: compactRows ? 8 : 16,
//                                 vertical: compactRows ? 4 : 8,
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: compactRows ? 8 : 12),
//                           ElevatedButton(
//                             onPressed: (nextUrl == null || nextUrl!.isEmpty)
//                                 ? null
//                                 : loadNextPage,
//                             child: Text(
//                               'Next',
//                               style: TextStyle(
//                                   fontSize: compactRows ? 11 : 13),
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor:
//                                   (nextUrl == null || nextUrl!.isEmpty)
//                                       ? Colors.grey
//                                       : null,
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: compactRows ? 8 : 16,
//                                 vertical: compactRows ? 4 : 8,
//                               ),
//                             ),
//                           ),
//                         ],
//                       )
//                     ],
//                   ),
//                 )
//               ],
//             ),
//     );
//   }
// }