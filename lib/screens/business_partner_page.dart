import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../services/auth_service.dart';
// import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

class BusinessPartnerPage extends StatefulWidget {
  @override
  _BusinessPartnerPageState createState() => _BusinessPartnerPageState();
}

class _BusinessPartnerPageState extends State<BusinessPartnerPage> {
  List<Map<String, dynamic>> partners = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  
  // Pagination variables
  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;
  int pageSize = 20;
  
  // Filter and sort variables
  Map<String, String> filterParams = {};
  String? sortBy;
  String? sortOrder;
  
  // Search query for field selection
  String fieldSearchQuery = '';
  
  // List settings variables
  bool compactRows = false;
  bool activeRowHighlighting = false;
  bool modernCellColoring = false;
  bool enableListView = false;
  bool doubleClickToEdit = false;
  
  // Scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();
  
  // Group By / Display Fields variables
  List<Map<String, dynamic>> availableFields = [
    {'key': 'role', 'label': 'Role', 'selected': true, 'order': 0},
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 1},
    {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 2},
    {'key': 'name', 'label': 'Name', 'selected': true, 'order': 3},
    {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 4},
    {'key': 'landline', 'label': 'Landline', 'selected': false, 'order': 5},
    {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 6},
    {'key': 'refered_by', 'label': 'Referred By', 'selected': false, 'order': 7},
    {'key': 'pan_name', 'label': 'PAN Name', 'selected': false, 'order': 8},
    {'key': 'pan_no', 'label': 'PAN Number', 'selected': false, 'order': 9},
    {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 10},
    {'key': 'gst_no', 'label': 'GST Number', 'selected': false, 'order': 11},
    {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 12},
    {'key': 'more', 'label': 'More Info', 'selected': false, 'order': 13},
    {'key': 'more_detail', 'label': 'More Details', 'selected': false, 'isComplex': true, 'order': 14},
    {'key': 'door_no', 'label': 'Door No', 'selected': false, 'order': 15},
    {'key': 'shop_no', 'label': 'Shop No', 'selected': false, 'order': 16},
    {'key': 'complex_name', 'label': 'Complex Name', 'selected': false, 'order': 17},
    {'key': 'building_name', 'label': 'Building Name', 'selected': false, 'order': 18},
    {'key': 'street_name', 'label': 'Street Name', 'selected': false, 'order': 19},
    {'key': 'area', 'label': 'Area', 'selected': false, 'order': 20},
    {'key': 'pincode', 'label': 'Pincode', 'selected': false, 'order': 21},
    {'key': 'city', 'label': 'City', 'selected': false, 'order': 22},
    {'key': 'state', 'label': 'State', 'selected': false, 'order': 23},
    {'key': 'country', 'label': 'Country', 'selected': false, 'order': 24},
    {'key': 'map_location', 'label': 'Map Location', 'selected': false, 'order': 25},
    {'key': 'location_guide', 'label': 'Location Guide', 'selected': false, 'order': 26},
  ];
  
  // Filter field controllers
  final TextEditingController bpCodeController = TextEditingController();
  final TextEditingController bpNameController = TextEditingController();
  final TextEditingController bpTypeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // For editing business partner
  Map<String, TextEditingController>? editControllers;
  int? editingPartnerId;

  @override
  void initState() {
    super.initState();
    loadSavedFieldSelections();
    loadListSettings();
    loadTokenAndFetchData();
  }

  @override
  void dispose() {
    bpCodeController.dispose();
    bpNameController.dispose();
    bpTypeController.dispose();
    emailController.dispose();
    phoneController.dispose();
    
    // Dispose edit controllers if they exist
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
    String? savedSelections = prefs.getString('business_partner_fields');
    String? savedOrder = prefs.getString('business_partner_field_order');
    
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
    
    await prefs.setString('business_partner_fields', json.encode(selections));
    
    // Save field order
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('business_partner_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    setState(() {
      compactRows = prefs.getBool('compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('modern_cell_coloring') ?? false;
      enableListView = prefs.getBool('enable_list_view') ?? false;
      doubleClickToEdit = prefs.getBool('double_click_to_edit') ?? false;
    });
  }

  // Save list settings to SharedPreferences
  Future<void> saveListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableListView,
    required bool doubleClickToEdit,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('compact_rows', compactRows);
    await prefs.setBool('active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('modern_cell_coloring', modernCellColoring);
    await prefs.setBool('enable_list_view', enableListView);
    await prefs.setBool('double_click_to_edit', doubleClickToEdit);
    
    // Also update the current state
    setState(() {
      this.compactRows = compactRows;
      this.activeRowHighlighting = activeRowHighlighting;
      this.modernCellColoring = modernCellColoring;
      this.enableListView = enableListView;
      this.doubleClickToEdit = doubleClickToEdit;
    });
  }

  // Get selected fields for display in correct order
  List<Map<String, dynamic>> getSelectedFields() {
    return availableFields
        .where((field) => field['selected'] == true)
        .toList()
        ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
  }

  // Toggle field selection
  void toggleFieldSelection(String key) {
    setState(() {
      final index = availableFields.indexWhere((field) => field['key'] == key);
      if (index != -1) {
        availableFields[index]['selected'] = !availableFields[index]['selected'];
      }
    });
  }

  // Reset to default fields
  void resetToDefaultFields() {
    setState(() {
      // Reset selection and order
      List<Map<String, dynamic>> defaultFields = [
        {'key': 'role', 'label': 'Role', 'selected': true},
        {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
        {'key': 'business_name', 'label': 'Business Name', 'selected': true},
        {'key': 'name', 'label': 'Name', 'selected': true},
        {'key': 'mobile', 'label': 'Mobile', 'selected': true},
        {'key': 'landline', 'label': 'Landline', 'selected': false},
        {'key': 'business_email', 'label': 'Email', 'selected': true},
        {'key': 'refered_by', 'label': 'Referred By', 'selected': false},
        {'key': 'pan_name', 'label': 'PAN Name', 'selected': false},
        {'key': 'pan_no', 'label': 'PAN Number', 'selected': false},
        {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
        {'key': 'gst_no', 'label': 'GST Number', 'selected': false},
        {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
        {'key': 'more', 'label': 'More Info', 'selected': false},
        {'key': 'more_detail', 'label': 'More Details', 'selected': false, 'isComplex': true},
        {'key': 'door_no', 'label': 'Door No', 'selected': false},
        {'key': 'shop_no', 'label': 'Shop No', 'selected': false},
        {'key': 'complex_name', 'label': 'Complex Name', 'selected': false},
        {'key': 'building_name', 'label': 'Building Name', 'selected': false},
        {'key': 'street_name', 'label': 'Street Name', 'selected': false},
        {'key': 'area', 'label': 'Area', 'selected': false},
        {'key': 'pincode', 'label': 'Pincode', 'selected': false},
        {'key': 'city', 'label': 'City', 'selected': false},
        {'key': 'state', 'label': 'State', 'selected': false},
        {'key': 'country', 'label': 'Country', 'selected': false},
        {'key': 'map_location', 'label': 'Map Location', 'selected': false},
        {'key': 'location_guide', 'label': 'Location Guide', 'selected': false},
      ];
      
      // Update existing fields while preserving additional properties
      for (int i = 0; i < defaultFields.length; i++) {
        final defaultField = defaultFields[i];
        final existingIndex = availableFields.indexWhere((f) => f['key'] == defaultField['key']);
        if (existingIndex != -1) {
          availableFields[existingIndex]['selected'] = defaultField['selected'];
          availableFields[existingIndex]['order'] = i;
        }
      }
    });
    
    // Save selections to SharedPreferences
    saveFieldSelections();
    
    // Show a snackbar to confirm reset
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fields reset to default'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Apply list settings
  void applyListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableListView,
    required bool doubleClickToEdit,
  }) {
    // Update state immediately
    setState(() {
      this.compactRows = compactRows;
      this.activeRowHighlighting = activeRowHighlighting;
      this.modernCellColoring = modernCellColoring;
      this.enableListView = enableListView;
      this.doubleClickToEdit = doubleClickToEdit;
    });
    
    // Save to SharedPreferences
    saveListSettings(
      compactRows: compactRows,
      activeRowHighlighting: activeRowHighlighting,
      modernCellColoring: modernCellColoring,
      enableListView: enableListView,
      doubleClickToEdit: doubleClickToEdit,
    );
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('List settings applied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Show Group By / Field Selection Dialog
  void showFieldSelectionDialog() {
    fieldSearchQuery = ''; // Reset search when opening dialog
    
    // Local variables for checkbox states
    bool localCompactRows = compactRows;
    bool localActiveRowHighlighting = activeRowHighlighting;
    bool localModernCellColoring = modernCellColoring;
    bool localEnableListView = enableListView;
    bool localDoubleClickToEdit = doubleClickToEdit;
    
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
                            'Personalize List Columns',
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                            itemCount: filteredAvailableFields.length,
                                            itemBuilder: (context, index) {
                                              final field = filteredAvailableFields[index];
                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  field['label'],
                                                  style: TextStyle(fontSize: 14),
                                                ),
                                                subtitle: field['isComplex'] == true 
                                                    ? Text('Complex field', style: TextStyle(fontSize: 11, color: Colors.grey))
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
                                                    availableFieldsList.removeWhere((f) => f['key'] == field['key']);
                                                    selectedFieldsList.add(field);
                                                    selectedFieldIndex = selectedFieldsList.length - 1;
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
                                          for (var field in filteredAvailableFields.toList()) {
                                            field['selected'] = true;
                                            availableFieldsList.removeWhere((f) => f['key'] == field['key']);
                                            selectedFieldsList.add(field);
                                          }
                                          if (selectedFieldsList.isNotEmpty) {
                                            selectedFieldIndex = selectedFieldsList.length - 1;
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
                                          for (var field in selectedFieldsList.toList()) {
                                            field['selected'] = false;
                                            selectedFieldsList.removeWhere((f) => f['key'] == field['key']);
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
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                                  for (var field in selectedFieldsList.toList()) {
                                                    field['selected'] = false;
                                                  }
                                                  availableFieldsList.addAll(selectedFieldsList);
                                                  selectedFieldsList.clear();
                                                  selectedFieldIndex = -1;
                                                });
                                              },
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size(0, 0),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: Text(
                                                'Remove all',
                                                style: TextStyle(fontSize: 12, color: Colors.red),
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
                                                    fontWeight: selectedFieldIndex == index 
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
                                                      selectedFieldsList.removeAt(index);
                                                      availableFieldsList.add(field);
                                                      if (selectedFieldIndex >= selectedFieldsList.length) {
                                                        selectedFieldIndex = selectedFieldsList.length - 1;
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.arrow_upward, color: Colors.blue),
                                          onPressed: selectedFieldIndex > 0
                                              ? () {
                                                  setState(() {
                                                    // Move selected field up
                                                    final field = selectedFieldsList.removeAt(selectedFieldIndex);
                                                    selectedFieldsList.insert(selectedFieldIndex - 1, field);
                                                    selectedFieldIndex = selectedFieldIndex - 1;
                                                  });
                                                }
                                              : null,
                                        ),
                                        SizedBox(width: 30),
                                        IconButton(
                                          icon: Icon(Icons.arrow_downward, color: Colors.blue),
                                          onPressed: selectedFieldIndex < selectedFieldsList.length - 1
                                              ? () {
                                                  setState(() {
                                                    // Move selected field down
                                                    final field = selectedFieldsList.removeAt(selectedFieldIndex);
                                                    selectedFieldsList.insert(selectedFieldIndex + 1, field);
                                                    selectedFieldIndex = selectedFieldIndex + 1;
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
                    
                    // Bottom options section with working checkboxes
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
                            ],
                          ),
                          SizedBox(height: 12),
                          // Second row of checkboxes
                          Row(
                            children: [
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
                              SizedBox(width: 32),
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: localEnableListView,
                                  onChanged: (value) {
                                    setState(() {
                                      localEnableListView = value ?? false;
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
                                  value: localDoubleClickToEdit,
                                  onChanged: (value) {
                                    setState(() {
                                      localDoubleClickToEdit = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Enable edit'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Footer with Reset button and metadata
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  {'key': 'role', 'label': 'Role', 'selected': true},
                                  {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
                                  {'key': 'business_name', 'label': 'Business Name', 'selected': true},
                                  {'key': 'name', 'label': 'Name', 'selected': true},
                                  {'key': 'mobile', 'label': 'Mobile', 'selected': true},
                                  {'key': 'business_email', 'label': 'Email', 'selected': true},
                                ];
                                
                                for (var field in availableFields) {
                                  bool isDefaultSelected = defaultFields.any((df) => df['key'] == field['key']);
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
                                localEnableListView = false;
                                localDoubleClickToEdit = false;
                                
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
                                'P4 - resolution (36h) 8-17',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'Ricky S Larsson · 09-27-2022',
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
                                for (int i = 0; i < selectedFieldsList.length; i++) {
                                  final selectedField = selectedFieldsList[i];
                                  final index = availableFields.indexWhere(
                                    (f) => f['key'] == selectedField['key']
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
                                  (a['order'] ?? 0).compareTo(b['order'] ?? 0)
                                );
                              });
                              
                              // Save selections to SharedPreferences
                              await saveFieldSelections();
                              
                              // Apply other settings
                              applyListSettings(
                                compactRows: localCompactRows,
                                activeRowHighlighting: localActiveRowHighlighting,
                                modernCellColoring: localModernCellColoring,
                                enableListView: localEnableListView,
                                doubleClickToEdit: localDoubleClickToEdit,
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

  // Format complex field for display
  String formatComplexField(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      if (value.isEmpty) return '[]';
      if (value.length > 1) {
        return '[${value.length} items]';
      } else {
        // Show first item summary
        final firstItem = value.first;
        if (firstItem is Map) {
          final name = firstItem['dummy_name'] ?? '';
          final email = firstItem['dummy_email'] ?? '';
          return '$name, $email';
        }
      }
    }
    return value.toString();
  }

  // Get field value with proper formatting
  String getFieldValue(Map<String, dynamic> partner, String key) {
    final value = partner[key];
    
    if (value == null) return '';
    
    // Handle complex fields
    if (key == 'more_detail' && value is List) {
      return formatComplexField(value);
    }
    
    // Handle map location - show as link text
    if (key == 'map_location' && value.toString().isNotEmpty) {
      return '📍 Map Link';
    }
    
    // Handle attachments
    if (key.contains('attachment') && value.toString().isNotEmpty) {
      return '📎 Attachment';
    }
    
    return value.toString();
  }

  // Helper method to safely get int from dynamic value
  int safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Build URL with filter and sort parameters
  String buildRequestUrl({String? baseUrl}) {
    Uri uri;
    
    if (baseUrl != null) {
      uri = Uri.parse(baseUrl);
    } else {
      // Use filter API when there are filter parameters, otherwise use list API
      if (filterParams.isNotEmpty || sortBy != null) {
        uri = Uri.parse('http://127.0.0.1:8000/user/BusinessPartner/filter/');
      } else {
        uri = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/list/');
      }
    }
    
    // Create a new Uri with additional query parameters
    Map<String, String> queryParams = {};
    
    // Add existing query parameters from the URL
    queryParams.addAll(uri.queryParameters);
    
    // Add filter parameters (backend handles these dynamically)
    queryParams.addAll(filterParams);
    
    // Add sort parameters
    if (sortBy != null && sortBy!.isNotEmpty) {
      queryParams['sort_by'] = sortBy!;
      
      // Only add sort_order if it's not null
      if (sortOrder != null && sortOrder!.isNotEmpty) {
        queryParams['sort_order'] = sortOrder!;
      }
    }
    
    // Add page_size if it's not already in filterParams
    if (!queryParams.containsKey('page_size')) {
      queryParams['page_size'] = pageSize.toString();
    }
    
    // Rebuild URI with all parameters
    return uri.replace(queryParameters: queryParams).toString();
  }

  Future<void> loadTokenAndFetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null || token!.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    await fetchBusinessPartners();
  }

  Future<void> fetchBusinessPartners({String? url}) async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      // Use provided URL for pagination, otherwise build URL with filters
      final requestUrl = url ?? buildRequestUrl();
      
      print('Fetching: $requestUrl'); // For debugging
      
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        setState(() {
          // Handle different response structures from different APIs
          if (data.containsKey('results')) {
            // Paginated response (list API)
            partners = List<Map<String, dynamic>>.from(data['results'] ?? []);
            nextUrl = data['next'];
            prevUrl = data['previous'];
            totalCount = safeParseInt(data['count']);
          } else if (data is List) {
            // Non-paginated response (filter API might return list)
            partners = List<Map<String, dynamic>>.from(data);
            nextUrl = null;
            prevUrl = null;
            totalCount = partners.length;
          } else {
            // Single object response
            partners = [Map<String, dynamic>.from(data)];
            nextUrl = null;
            prevUrl = null;
            totalCount = 1;
          }
          
          // Calculate current page from URL if possible
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
          
          isLoading = false;
        });
      } else {
        print('Failed to load partners: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching business partners: $e');
      setState(() => isLoading = false);
    }
  }

  // Apply all filters at once
  Future<void> applyFilters() async {
    filterParams.clear();
    
    if (bpCodeController.text.isNotEmpty) {
      filterParams['bp_code'] = bpCodeController.text;
    }
    if (bpNameController.text.isNotEmpty) {
      filterParams['name'] = bpNameController.text;
    }
    if (bpTypeController.text.isNotEmpty) {
      filterParams['role'] = bpTypeController.text;
    }
    if (emailController.text.isNotEmpty) {
      filterParams['business_email'] = emailController.text;
    }
    if (phoneController.text.isNotEmpty) {
      filterParams['mobile'] = phoneController.text;
    }
    
    // Reset to first page when applying filters
    currentPage = 1;
    await fetchBusinessPartners();
  }

  // Clear all filters
  Future<void> clearFilters() async {
    filterParams.clear();
    bpCodeController.clear();
    bpNameController.clear();
    bpTypeController.clear();
    emailController.clear();
    phoneController.clear();
    
    await fetchBusinessPartners();
  }

  // Show filter dialog
  void showFilterDialog() {
    // Initialize controllers with current filter values
    bpCodeController.text = filterParams['bp_code'] ?? '';
    bpNameController.text = filterParams['name'] ?? '';
    bpTypeController.text = filterParams['role'] ?? '';
    emailController.text = filterParams['business_email'] ?? '';
    phoneController.text = filterParams['mobile'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter Business Partners'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: bpCodeController,
                  decoration: InputDecoration(
                    labelText: 'BP Code',
                    hintText: 'e.g., BV009',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.code),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: bpNameController,
                  decoration: InputDecoration(
                    labelText: 'BP Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: bpTypeController.text.isNotEmpty ? bpTypeController.text : null,
                  decoration: InputDecoration(
                    labelText: 'BP Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    DropdownMenuItem(value: 'buyer', child: Text('Buyer')),
                    DropdownMenuItem(value: 'craftsman', child: Text('Craftsman')),
                  ],
                  onChanged: (value) {
                    bpTypeController.text = value ?? '';
                  },
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
              ],
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
              onPressed: () {
                Navigator.pop(context);
                applyFilters();
              },
              child: Text('Apply Filters'),
            ),
          ],
        );
      },
    );
  }

  // Apply sort
  Future<void> applySort(String field, String order) async {
    setState(() {
      sortBy = field;
      sortOrder = order;
    });
    await fetchBusinessPartners();
  }

  // Clear sort
  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchBusinessPartners();
  }

  // Toggle sort order
  void toggleSortOrder() {
    if (sortOrder == null || sortOrder == 'asc') {
      applySort(sortBy!, 'desc');
    } else {
      applySort(sortBy!, 'asc');
    }
  }

  // Show sort options
  void showSortDialog() {
    List<Map<String, String>> sortFields = [
      {'value': 'bp_code', 'label': 'BP Code'},
      {'value': 'name', 'label': 'Name'},
      {'value': 'business_name', 'label': 'Business Name'},
      {'value': 'role', 'label': 'BP Type'},
      {'value': 'business_email', 'label': 'Email'},
      {'value': 'mobile', 'label': 'Phone'},
      {'value': 'created_at', 'label': 'Created Date'},
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sort field selection
                    ...sortFields.map((field) {
                      return RadioListTile<String>(
                        title: Text(field['label']!),
                        value: field['value']!,
                        groupValue: sortBy,
                        onChanged: (value) {
                          setState(() {
                            this.sortBy = value;
                          });
                        },
                        secondary: sortBy == field['value'] ? IconButton(
                          icon: Icon(sortOrder == 'desc' 
                              ? Icons.arrow_downward 
                              : Icons.arrow_upward),
                          onPressed: () {
                            setState(() {
                              sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
                            });
                          },
                        ) : null,
                      );
                    }).toList(),
                    
                    SizedBox(height: 16),
                    
                    // Sort order selection
                    if (sortBy != null)
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sort Order:', 
                              style: TextStyle(fontWeight: FontWeight.bold)),
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
                            Text(
                              'Note: "newest", "latest" = desc, "oldest" = asc',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                      fetchBusinessPartners();
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

  // Pagination methods
  void loadNextPage() {
    if (nextUrl != null && nextUrl!.isNotEmpty) {
      currentPage++;
      fetchBusinessPartners(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchBusinessPartners(url: prevUrl);
    }
  }

  // Change page size
  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    
    // Add page_size to filterParams
    filterParams['page_size'] = newSize.toString();
    await fetchBusinessPartners();
  }

  // Fetch single partner details for editing
  Future<Map<String, dynamic>> fetchPartnerDetails(int id) async {
    if (token == null) throw Exception('No token available');

    final Uri apiUrl = Uri.parse(
      'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/detail/$id/',
    );

    try {
      final response = await http.get(
        apiUrl,
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to fetch partner details');
      }
    } catch (e) {
      throw Exception('Error fetching partner details: $e');
    }
  }

  // Initialize edit mode
  void initializeEditMode(Map<String, dynamic> partner) {
    editingPartnerId = partner['id'];
    editControllers = {};
    
    // Initialize all field controllers
    for (var field in partner.keys) {
      if (field.toLowerCase() != 'id' && field != 'more_detail') {
        editControllers![field] = TextEditingController(
          text: partner[field]?.toString() ?? '',
        );
      }
    }
  }

  // Update partner
  Future<void> updatePartner(int id) async {
    if (token == null || editControllers == null) return;

    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/$id/'),
      );

      request.headers['Authorization'] = 'Token $token';

      // Add text fields
      editControllers!.forEach((key, controller) {
        if (!key.contains('attachment')) {
          request.fields[key] = controller.text.trim();
        }
      });

      var response = await request.send();
      
      if (response.statusCode == 200) {
        // Clear edit controllers
        editControllers = null;
        editingPartnerId = null;
        
        // Refresh the list
        fetchBusinessPartners();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partner updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update partner. Status: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        print('Error response: $responseBody');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Exception: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Show edit dialog
  void showEditDialog(Map<String, dynamic> partner) async {
    try {
      setState(() => isLoading = true);
      final detailedPartner = await fetchPartnerDetails(partner['id']);
      setState(() => isLoading = false);
      
      initializeEditMode(detailedPartner);
      
      showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit Business Partner'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: editControllers!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TextField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    await updatePartner(editingPartnerId!);
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
                TextButton(
                  onPressed: () {
                    editControllers = null;
                    editingPartnerId = null;
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load partner details for editing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showBusinessPartnerDialog(Map<String, dynamic> partner) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Business Partner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: partner.entries.map((e) {
              // Handle complex fields specially
              if (e.key == 'more_detail' && e.value is List) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'More Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...(e.value as List).map((item) {
                      return Container(
                        margin: EdgeInsets.only(left: 16, bottom: 8),
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: ${item['dummy_name'] ?? ''}'),
                            Text('Email: ${item['dummy_email'] ?? ''}'),
                            Text('Mobile: ${item['dummy_mobile'] ?? ''}'),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              }
              
              // Handle attachments
              if (e.key.contains('attachment') && e.value != null && e.value.toString().isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.key.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      GestureDetector(
                        onTap: () {
                          // Add logic to open attachment
                          print('Open attachment: ${e.value}');
                        },
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attachment, size: 16, color: Colors.blue),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'View Attachment',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller:
                      TextEditingController(text: e.value?.toString() ?? ''),
                  readOnly: true,
                  maxLines: e.key == 'map_location' ? 2 : 1,
                  decoration: InputDecoration(
                    labelText: e.key.replaceAll('_', ' ').toUpperCase(),
                    border: OutlineInputBorder(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFields = getSelectedFields();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Buyers & Craftsmans'),
        actions: [
          // Field Selection button (Group By)
          IconButton(
            icon: Icon(Icons.view_column),
            onPressed: showFieldSelectionDialog,
            tooltip: 'Select Fields',
          ),
          // Filter button
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: showFilterDialog,
            tooltip: 'Filter',
          ),
          // Sort button
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: showSortDialog,
            tooltip: 'Sort',
          ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => fetchBusinessPartners(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : partners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No data found'),
                      if (filterParams.isNotEmpty) ...[
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: clearFilters,
                          child: Text('Clear Filters'),
                        ),
                      ],
                      if (sortBy != null) ...[
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: clearSort,
                          child: Text('Clear Sort'),
                        ),
                      ]
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Show field selection summary
                    Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.purple.shade50,
                      child: Row(
                        children: [
                          Icon(Icons.view_column, size: 16, color: Colors.purple),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing ${selectedFields.length} fields',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: showFieldSelectionDialog,
                            icon: Icon(Icons.edit, size: 14),
                            label: Text('Change', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Show active filters if any
                    if (filterParams.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(8),
                        color: Colors.blue.shade50,
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Filters: ${filterParams.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
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
                    
                    // Show active sort if any
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
                                'Sort: ${sortBy?.replaceAll('_', ' ')} (${sortOrder ?? 'asc'})',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 16),
                              onPressed: clearSort,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),
                            if (sortBy != null)
                              IconButton(
                                icon: Icon(sortOrder == 'desc' 
                                    ? Icons.arrow_downward 
                                    : Icons.arrow_upward),
                                onPressed: toggleSortOrder,
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    
                    // Page size selector
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
                        ],
                      ),
                    ),
                    
                    // Apply list settings to DataTable
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
                              columns: [
                                DataColumn(label: Text('Select', style: TextStyle(fontSize: compactRows ? 12 : 14))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontSize: compactRows ? 12 : 14))),
                                ...selectedFields.map((f) => DataColumn(
                                      label: GestureDetector(
                                        onTap: () {
                                          // Quick sort by clicking column header
                                          if (sortBy == f['key']) {
                                            toggleSortOrder();
                                          } else {
                                            applySort(f['key'], 'asc');
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              f['label'].toUpperCase(),
                                              style: TextStyle(fontSize: compactRows ? 11 : 13),
                                            ),
                                            if (sortBy == f['key'])
                                              Icon(
                                                sortOrder == 'desc' 
                                                    ? Icons.arrow_downward 
                                                    : Icons.arrow_upward,
                                                size: compactRows ? 14 : 16,
                                              ),
                                          ],
                                        ),
                                      ),
                                    )),
                              ],
                              rows: partners.map((partner) {
                                final id = partner['id'];
                                final isSelected = selectedIds.contains(id);
                                
                                return DataRow(
                                  color: activeRowHighlighting && isSelected
                                      ? MaterialStateProperty.resolveWith<Color?>(
                                          (Set<MaterialState> states) {
                                            return Colors.blue.shade50;
                                          },
                                        )
                                      : null,
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (v) {
                                          setState(() {
                                            v == true
                                                ? selectedIds.add(id)
                                                : selectedIds.remove(id);
                                          });
                                        },
                                      ),
                                    ),
                                    
                                    // Actions cell
                                    DataCell(
                                      isSelected
                                          ? Row(
                                              children: [
                                                // View button (shows if enableListView is true)
                                                if (enableListView)
                                                  Container(
                                                    height: compactRows ? 30 : 35,
                                                    margin: EdgeInsets.only(right: 8),
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          showBusinessPartnerDialog(partner),
                                                      child: Text(
                                                        'View',
                                                        style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                                      ),
                                                    ),
                                                  ),
                                                
                                                // Edit button (shows if doubleClickToEdit is true)
                                                if (doubleClickToEdit)
                                                  Container(
                                                    height: compactRows ? 30 : 35,
                                                    child: ElevatedButton(
                                                      onPressed: () =>
                                                          showEditDialog(partner),
                                                      child: Text(
                                                        'Edit',
                                                        style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            )
                                          : SizedBox.shrink(),
                                    ),

                                    // Selected fields
                                    ...selectedFields.map((f) {
                                      String displayValue = getFieldValue(partner, f['key']);
                                      
                                      // Special handling for map_location to make it tappable
                                      if (f['key'] == 'map_location' && displayValue.isNotEmpty) {
                                        return DataCell(
                                          GestureDetector(
                                            onTap: () {
                                              // Open map link
                                              final url = partner['map_location'];
                                              if (url != null && url.toString().isNotEmpty) {
                                                // You can add URL launcher here
                                                print('Open map: $url');
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                displayValue,
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  decoration: TextDecoration.underline,
                                                  fontSize: compactRows ? 11 : 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      // Special handling for attachments
                                      if (f['key'].contains('attachment') && displayValue.isNotEmpty) {
                                        return DataCell(
                                          GestureDetector(
                                            onTap: () {
                                              final url = partner[f['key']];
                                              print('Open attachment: $url');
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: modernCellColoring 
                                                    ? Colors.purple.shade50 
                                                    : Colors.orange.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.attachment, 
                                                    size: compactRows ? 10 : 12, 
                                                    color: modernCellColoring ? Colors.purple : Colors.orange
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    displayValue,
                                                    style: TextStyle(
                                                      fontSize: compactRows ? 10 : 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      
                                      // Special handling for more_detail (complex field)
                                      if (f['key'] == 'more_detail') {
                                        final details = partner['more_detail'];
                                        if (details != null && details is List) {
                                          return DataCell(
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${details.length} items',
                                                style: TextStyle(
                                                  fontSize: compactRows ? 11 : 13,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                      
                                      return DataCell(
                                        Text(
                                          displayValue,
                                          style: TextStyle(
                                            fontSize: compactRows ? 11 : 13,
                                            color: modernCellColoring && isSelected 
                                                ? Colors.blue 
                                                : null,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Pagination controls
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
                                  style: TextStyle(fontSize: compactRows ? 11 : 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (prevUrl == null || prevUrl!.isEmpty) 
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
                                  style: TextStyle(fontSize: compactRows ? 11 : 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (nextUrl == null || nextUrl!.isEmpty) 
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
