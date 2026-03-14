import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';

class BuyerPage extends StatefulWidget {
  @override
  _BuyerPageState createState() => _BuyerPageState();
}

class _BuyerPageState extends State<BuyerPage> {
  List<Map<String, dynamic>> buyers = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  List<String> dynamicFields = [];

  // API Endpoints
  final String listApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
  final String filterApiUrl = 'http://127.0.0.1:8000/user/BusinessPartner/filter/';
  final String createApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/';
  final String detailApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/detail/';
  final String updateApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/';

  // Pagination variables
  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;
  int pageSize = 20;
  
  // Filter and sort variables
  Map<String, String> filterParams = {
    'role': 'buyer',
  };
  String? sortBy;
  String? sortOrder;
  
  // Search query for field selection
  String fieldSearchQuery = '';
  
  // List settings variables
  bool compactRows = false;
  bool activeRowHighlighting = false;
  bool modernCellColoring = false;
  bool enableView = false;
  bool enableEdit = false;
  
  // Scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();
  
  // Group By / Display Fields variables
  List<Map<String, dynamic>> availableFields = [
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
    {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
    {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
    {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
    {'key': 'landline', 'label': 'Landline', 'selected': false, 'order': 4},
    {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 5},
    {'key': 'company_name', 'label': 'Company Name', 'selected': true, 'order': 6},
    {'key': 'gst_number', 'label': 'GST Number', 'selected': true, 'order': 7},
    {'key': 'refered_by', 'label': 'Referred By', 'selected': false, 'order': 8},
    {'key': 'pan_name', 'label': 'PAN Name', 'selected': false, 'order': 9},
    {'key': 'pan_no', 'label': 'PAN Number', 'selected': false, 'order': 10},
    {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 11},
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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();
  final TextEditingController landlineController = TextEditingController();
  final TextEditingController gstNumberController = TextEditingController();

  // For creating new buyer
  final Map<String, TextEditingController> createControllers = {};
  // Store more details as controllers for create
  List<Map<String, TextEditingController>> moreDetailControllers = [];
  
  // For editing existing buyer
  Map<String, TextEditingController>? editControllers;
  List<Map<String, TextEditingController>>? editMoreDetailControllers;
  int? editingBuyerId;
  
  // For file uploads - Use XFile for better cross-platform support
  XFile? panAttachmentXFile;
  XFile? gstAttachmentXFile;

  // Currently viewed buyer for detail view
  Map<String, dynamic>? currentViewedBuyer;

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
    bpNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    companyNameController.dispose();
    landlineController.dispose();
    gstNumberController.dispose();
    
    // Dispose all text controllers
    createControllers.forEach((key, controller) {
      controller.dispose();
    });
    
    // Dispose edit controllers if they exist
    if (editControllers != null) {
      editControllers!.forEach((key, controller) {
        controller.dispose();
      });
    }
    
    // Dispose create more detail controllers
    for (var controllers in moreDetailControllers) {
      controllers.forEach((key, controller) {
        controller.dispose();
      });
    }
    
    // Dispose edit more detail controllers
    if (editMoreDetailControllers != null) {
      for (var controllers in editMoreDetailControllers!) {
        controllers.forEach((key, controller) {
          controller.dispose();
        });
      }
    }
    
    // Dispose scroll controller
    _horizontalScrollController.dispose();
    
    super.dispose();
  }

  // Load saved field selections from SharedPreferences
  Future<void> loadSavedFieldSelections() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedSelections = prefs.getString('buyer_fields');
    String? savedOrder = prefs.getString('buyer_field_order');
    
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
    
    await prefs.setString('buyer_fields', json.encode(selections));
    
    // Save field order
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('buyer_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    setState(() {
      compactRows = prefs.getBool('buyer_compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('buyer_active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('buyer_modern_cell_coloring') ?? false;
      enableView = prefs.getBool('buyer_enable_view') ?? false;
      enableEdit = prefs.getBool('buyer_enable_edit') ?? false;
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
    
    await prefs.setBool('buyer_compact_rows', compactRows);
    await prefs.setBool('buyer_active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('buyer_modern_cell_coloring', modernCellColoring);
    await prefs.setBool('buyer_enable_view', enableView);
    await prefs.setBool('buyer_enable_edit', enableEdit);
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
        {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
        {'key': 'business_name', 'label': 'Business Name', 'selected': true},
        {'key': 'name', 'label': 'Name', 'selected': true},
        {'key': 'mobile', 'label': 'Mobile', 'selected': true},
        {'key': 'business_email', 'label': 'Email', 'selected': true},
        {'key': 'company_name', 'label': 'Company Name', 'selected': true},
        {'key': 'gst_number', 'label': 'GST Number', 'selected': true},
        {'key': 'landline', 'label': 'Landline', 'selected': false},
        {'key': 'refered_by', 'label': 'Referred By', 'selected': false},
        {'key': 'pan_name', 'label': 'PAN Name', 'selected': false},
        {'key': 'pan_no', 'label': 'PAN Number', 'selected': false},
        {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
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
                            'Personalize List Columns - Buyers',
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
                          // Second row of checkboxes
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
                              Text('Enable view'),
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
                                  {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
                                  {'key': 'business_name', 'label': 'Business Name', 'selected': true},
                                  {'key': 'name', 'label': 'Name', 'selected': true},
                                  {'key': 'mobile', 'label': 'Mobile', 'selected': true},
                                  {'key': 'business_email', 'label': 'Email', 'selected': true},
                                  {'key': 'company_name', 'label': 'Company Name', 'selected': true},
                                  {'key': 'gst_number', 'label': 'GST Number', 'selected': true},
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
                                localEnableView = false;
                                localEnableEdit = false;
                                
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
                                'Buyers - Field Selection',
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
  String getFieldValue(Map<String, dynamic> buyer, String key) {
    final value = buyer[key];
    
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

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null || token!.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    fetchBuyers();
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
    // Start with base filter URL
    String url = filterApiUrl;
    
    // Build query parameters
    Map<String, String> queryParams = {};
    
    // Add role filter (always present)
    queryParams['role'] = 'buyer';
    
    // Add additional filter parameters from filterParams
    filterParams.forEach((key, value) {
      if (key != 'role' && value.isNotEmpty) {
        queryParams[key] = value;
      }
    });
    
    // Add sort parameters if set
    if (sortBy != null && sortBy!.isNotEmpty) {
      queryParams['sort_by'] = sortBy!;
      
      if (sortOrder != null && sortOrder!.isNotEmpty) {
        queryParams['sort_order'] = sortOrder!;
      }
    }
    
    // Add pagination parameters
    if (pageSize != 20) {
      queryParams['page_size'] = pageSize.toString();
    }
    
    // Add page number for pagination if not first page
    if (currentPage > 1) {
      queryParams['page'] = currentPage.toString();
    }
    
    // Build URI with query parameters
    Uri uri = Uri.parse(url);
    return uri.replace(queryParameters: queryParams).toString();
  }

  Future<void> fetchBuyers({String? url}) async {
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

        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

        if (results.isNotEmpty) {
          // Include bp_code in dynamic fields to make it visible
          dynamicFields = results.first.keys
              .where((k) => k.toLowerCase() != 'id' && k.toLowerCase() != 'role')
              .toList();
        }

        setState(() {
          buyers = results;
          nextUrl = data['next'];
          prevUrl = data['previous'];
          totalCount = safeParseInt(data['count']);
          
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
          
          // Clear selections when data refreshes
          selectedIds.clear();
          isLoading = false;
        });
      } else {
        print('Error response: ${response.statusCode} - ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
    }
  }

  // Fetch single buyer details
  Future<void> fetchBuyerDetails(int id) async {
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
          currentViewedBuyer = data;
          isLoading = false;
        });
        
        // Show detail dialog with fetched data
        showBuyerDetailDialog();
      } else {
        print('Error fetching details: ${response.statusCode}');
        setState(() => isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch buyer details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Exception fetching details: $e');
      setState(() => isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Apply all filters at once
  Future<void> applyFilters() async {
    // Clear existing filter params but keep role
    filterParams.clear();
    filterParams['role'] = 'buyer';
    
    if (bpCodeController.text.isNotEmpty) {
      filterParams['bp_code'] = bpCodeController.text;
    }
    if (bpNameController.text.isNotEmpty) {
      filterParams['name'] = bpNameController.text;
    }
    if (emailController.text.isNotEmpty) {
      filterParams['business_email'] = emailController.text;
    }
    if (phoneController.text.isNotEmpty) {
      filterParams['mobile'] = phoneController.text;
    }
    if (companyNameController.text.isNotEmpty) {
      filterParams['company_name'] = companyNameController.text;
    }
    if (landlineController.text.isNotEmpty) {
      filterParams['landline'] = landlineController.text;
    }
    if (gstNumberController.text.isNotEmpty) {
      filterParams['gst_number'] = gstNumberController.text;
    }
    
    // Reset to first page when applying filters
    currentPage = 1;
    await fetchBuyers();
  }

  // Clear all filters
  Future<void> clearFilters() async {
    filterParams.clear();
    filterParams['role'] = 'buyer'; // Keep role filter
    
    bpCodeController.clear();
    bpNameController.clear();
    emailController.clear();
    phoneController.clear();
    companyNameController.clear();
    landlineController.clear();
    gstNumberController.clear();
    
    await fetchBuyers();
  }

  // Show filter dialog
  void showFilterDialog() {
    // Initialize controllers with current filter values
    bpCodeController.text = filterParams['bp_code'] ?? '';
    bpNameController.text = filterParams['name'] ?? '';
    emailController.text = filterParams['business_email'] ?? '';
    phoneController.text = filterParams['mobile'] ?? '';
    companyNameController.text = filterParams['company_name'] ?? '';
    landlineController.text = filterParams['landline'] ?? '';
    gstNumberController.text = filterParams['gst_number'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter Buyers'),
          content: Container(
            width: double.maxFinite,
            child: SingleChildScrollView(
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
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
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
                  SizedBox(height: 12),
                  TextField(
                    controller: companyNameController,
                    decoration: InputDecoration(
                      labelText: 'Company Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: landlineController,
                    decoration: InputDecoration(
                      labelText: 'LandLine',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.call),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: gstNumberController,
                    decoration: InputDecoration(
                      labelText: 'GST Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
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
    print('Applying sort: $field, $order'); // Debug print
    
    setState(() {
      sortBy = field;
      sortOrder = order;
    });
    
    // Reset to first page when sorting
    currentPage = 1;
    await fetchBuyers();
  }

  // Clear sort
  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchBuyers();
  }

  // Toggle sort order
  void toggleSortOrder() {
    if (sortBy == null) return;
    
    String newOrder;
    if (sortOrder == null || sortOrder == 'asc') {
      newOrder = 'desc';
    } else {
      newOrder = 'asc';
    }
    
    applySort(sortBy!, newOrder);
  }

  // Show sort options
  void showSortDialog() {
    List<Map<String, String>> sortFields = [
      {'value': 'bp_code', 'label': 'BP Code'},
      {'value': 'name', 'label': 'Name'},
      {'value': 'business_name', 'label': 'Business Name'},
      {'value': 'business_email', 'label': 'Email'},
      {'value': 'mobile', 'label': 'Phone'},
      {'value': 'company_name', 'label': 'Company Name'},
      {'value': 'landline', 'label': 'LandLine'},
      {'value': 'gst_number', 'label': 'GST Number'},
      {'value': 'created_at', 'label': 'Created Date'},
      {'value': 'id', 'label': 'ID'},
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
                      // Sort field selection
                      ...sortFields.map((field) {
                        return RadioListTile<String>(
                          title: Text(field['label']!),
                          value: field['value']!,
                          groupValue: sortBy,
                          onChanged: (value) {
                            setState(() {
                              this.sortBy = value;
                              // Set default sort order if not set
                              if (sortOrder == null) {
                                sortOrder = 'asc';
                              }
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
                      // Ensure sortOrder is set
                      if (sortOrder == null) {
                        sortOrder = 'asc';
                      }
                      fetchBuyers();
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
      fetchBuyers(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchBuyers(url: prevUrl);
    }
  }

  // Change page size
  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    
    await fetchBuyers();
  }

  // Show buyer detail dialog using fetched data
  void showBuyerDetailDialog() {
    if (currentViewedBuyer == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Buyer Details'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Include all fields including bp_code
                ...currentViewedBuyer!.entries.where((entry) {
                  String key = entry.key;
                  return key.toLowerCase() != 'id' && key != 'more_detail';
                }).map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${entry.key.replaceAll('_', ' ')}:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildDetailValue(entry.key, entry.value),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                // More Detail section
                if (currentViewedBuyer!['more_detail'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MORE DETAILS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...List<Map<String, dynamic>>.from(currentViewedBuyer!['more_detail']).asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, dynamic> detail = entry.value;
                          
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Detail ${index + 1}', 
                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(height: 4),
                                  Text('Name: ${detail['dummy_name'] ?? ''}'),
                                  Text('Email: ${detail['dummy_email'] ?? ''}'),
                                  Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
              ],
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

  // Helper to build detail value with proper formatting
  Widget _buildDetailValue(String key, dynamic value) {
    if (key == 'pan_attachment' || key == 'gst_attachment') {
      if (value != null && value.toString().isNotEmpty) {
        return InkWell(
          onTap: () {
            // Open file URL
            print('Open: $value');
          },
          child: Text(
            'View File',
            style: TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      }
      return Text('No file');
    }
    
    if (value == null) return Text('');
    if (value is bool) return Text(value.toString());
    if (value is Map || value is List) return Text(value.toString());
    return Text(value.toString());
  }

  // Show buyer dialog with scrollable content (for view/edit)
  void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
    // If editing, initialize controllers with buyer data
    if (isEdit) {
      editingBuyerId = buyer['id'];
      editControllers = {};
      
      // Initialize all field controllers except id and role (include bp_code for editing)
      for (var field in buyer.keys) {
        if (field.toLowerCase() != 'id' && 
            field.toLowerCase() != 'role' &&
            field != 'more_detail') {
          editControllers![field] = TextEditingController(
            text: buyer[field]?.toString() ?? '',
          );
        }
      }
      
      // Initialize more detail controllers with existing data
      editMoreDetailControllers = [];
      if (buyer['more_detail'] != null && buyer['more_detail'] is List) {
        List<Map<String, dynamic>> existingMoreDetails = 
            List<Map<String, dynamic>>.from(buyer['more_detail']);
        
        for (var detail in existingMoreDetails) {
          editMoreDetailControllers!.add({
            'dummy_name': TextEditingController(text: detail['dummy_name']?.toString() ?? ''),
            'dummy_email': TextEditingController(text: detail['dummy_email']?.toString() ?? ''),
            'dummy_mobile': TextEditingController(text: detail['dummy_mobile']?.toString() ?? ''),
          });
        }
      }
      
      // Reset file selections for edit
      panAttachmentXFile = null;
      gstAttachmentXFile = null;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show all fields except 'id', 'role', and 'more_detail' (include bp_code)
                    ...buyer.entries.where((entry) {
                      String key = entry.key;
                      return key.toLowerCase() != 'id' && 
                             key.toLowerCase() != 'role' &&
                             key != 'more_detail';
                    }).map((entry) {
                      // Check if this is a file attachment field
                      if (entry.key == 'pan_attachment' || entry.key == 'gst_attachment') {
                        return _buildFileAttachmentField(
                          context: context,
                          field: entry.key,
                          label: entry.key.replaceAll('_', ' ').toUpperCase(),
                          buyer: buyer,
                          isEdit: isEdit,
                          setState: setState,
                        );
                      }
                      
                      // For edit mode, use editControllers
                      if (isEdit && editControllers != null && editControllers!.containsKey(entry.key)) {
                        return _buildTextField(
                          context: context,
                          field: entry.key,
                          controller: editControllers![entry.key],
                          buyer: buyer,
                          isEdit: isEdit,
                          setState: setState,
                        );
                      } else {
                        // For view mode, show the value
                        return _buildTextField(
                          context: context,
                          field: entry.key,
                          value: entry.value?.toString() ?? '',
                          buyer: buyer,
                          isEdit: isEdit,
                          setState: setState,
                        );
                      }
                    }).toList(),
                    
                    // More Detail section
                    _buildMoreDetailsSection(
                      buyer: buyer,
                      isEdit: isEdit,
                      setState: setState,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (isEdit)
                ElevatedButton(
                  onPressed: () async {
                    await updateBuyer(editingBuyerId!);
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
              TextButton(
                onPressed: () {
                  // Clean up edit controllers when closing dialog
                  if (isEdit) {
                    editControllers = null;
                    editMoreDetailControllers = null;
                    editingBuyerId = null;
                    panAttachmentXFile = null;
                    gstAttachmentXFile = null;
                  }
                  Navigator.pop(context);
                },
                child: Text(isEdit ? 'Cancel' : 'Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String field,
    TextEditingController? controller,
    String? value,
    required Map<String, dynamic> buyer,
    required bool isEdit,
    required StateSetter setState,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        readOnly: !isEdit,
        decoration: InputDecoration(
          labelText: field.replaceAll('_', ' ').toUpperCase(),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildFileAttachmentField({
    required BuildContext context,
    required String field,
    required String label,
    required Map<String, dynamic> buyer,
    required bool isEdit,
    required StateSetter setState,
  }) {
    String? fileUrl = buyer[field];
    XFile? currentFile = field == 'pan_attachment' ? panAttachmentXFile : gstAttachmentXFile;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          if (fileUrl != null && fileUrl.isNotEmpty && currentFile == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    // Open file in browser or show preview
                    print('File URL: $fileUrl');
                  },
                  child: Text(
                    'View Existing Attachment',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                if (isEdit)
                  SizedBox(height: 8),
              ],
            )
          else if (!isEdit && (fileUrl == null || fileUrl.isEmpty))
            Text('No attachment'),
          
          // File upload for edit mode
          if (isEdit)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
                          setState(() {});
                        },
                        icon: Icon(Icons.attach_file),
                        label: Text(
                          field == 'pan_attachment' 
                            ? (currentFile != null ? path.basename(currentFile.path) : 'Select New PAN File')
                            : (currentFile != null ? path.basename(currentFile.path) : 'Select New GST File'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (currentFile != null)
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            if (field == 'pan_attachment') {
                              panAttachmentXFile = null;
                            } else {
                              gstAttachmentXFile = null;
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMoreDetailsSection({
    required Map<String, dynamic> buyer,
    required bool isEdit,
    required StateSetter setState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MORE DETAILS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (isEdit)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    if (editMoreDetailControllers == null) {
                      editMoreDetailControllers = [];
                    }
                    editMoreDetailControllers!.add({
                      'dummy_name': TextEditingController(),
                      'dummy_email': TextEditingController(),
                      'dummy_mobile': TextEditingController(),
                    });
                  });
                },
                icon: Icon(Icons.add, size: 20),
                label: Text('Add'),
              ),
          ],
        ),
        SizedBox(height: 10),
        
        // List of more details
        if (isEdit && editMoreDetailControllers != null)
          ...editMoreDetailControllers!.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, TextEditingController> controllers = entry.value;
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 5),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Detail ${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              // Dispose controllers before removing
                              controllers.forEach((key, controller) {
                                controller.dispose();
                              });
                              editMoreDetailControllers!.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                    TextField(
                      controller: controllers['dummy_name'],
                      decoration: InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: controllers['dummy_email'],
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: controllers['dummy_mobile'],
                      decoration: InputDecoration(
                        labelText: 'Mobile',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList()
        else if (!isEdit && buyer['more_detail'] != null && buyer['more_detail'] is List)
          ...List<Map<String, dynamic>>.from(buyer['more_detail']).asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> detail = entry.value;
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 5),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detail ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Name: ${detail['dummy_name'] ?? ''}'),
                    Text('Email: ${detail['dummy_email'] ?? ''}'),
                    Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // Show add buyer dialog with scrollable content
  void showAddBuyerDialog() {
    // Initialize controllers for dynamic fields (excluding role only, include bp_code)
    for (var field in dynamicFields) {
      if (field.toLowerCase() != 'role' && 
          !createControllers.containsKey(field)) {
        createControllers[field] = TextEditingController();
      }
    }
    
    // Initialize moreDetails controllers
    moreDetailControllers = [];
    // Reset file selections
    panAttachmentXFile = null;
    gstAttachmentXFile = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Buyer'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main fields - exclude role only (include bp_code)
                    ...dynamicFields.where((field) => 
                      field.toLowerCase() != 'role' && 
                      field != 'more_detail'
                    ).map((field) {
                      if (!createControllers.containsKey(field)) {
                        createControllers[field] = TextEditingController();
                      }
                      
                      // Check if this is a file attachment field
                      if (field == 'pan_attachment' || field == 'gst_attachment') {
                        return _buildCreateFileAttachmentField(
                          context: context,
                          field: field,
                          label: field.replaceAll('_', ' ').toUpperCase(),
                          setState: setState,
                        );
                      }
                      
                      // Regular text fields
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TextField(
                          controller: createControllers[field],
                          decoration: InputDecoration(
                            labelText: field.replaceAll('_', ' ').toUpperCase(),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      );
                    }).toList(),
                    
                    // More Detail section
                    _buildCreateMoreDetailsSection(setState: setState),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await createBuyer();
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

  Widget _buildCreateFileAttachmentField({
    required BuildContext context,
    required String field,
    required String label,
    required StateSetter setState,
  }) {
    XFile? currentFile = field == 'pan_attachment' ? panAttachmentXFile : gstAttachmentXFile;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
                    setState(() {});
                  },
                  icon: Icon(Icons.attach_file),
                  label: Text(
                    field == 'pan_attachment' 
                      ? (currentFile != null ? path.basename(currentFile.path) : 'Select PAN File')
                      : (currentFile != null ? path.basename(currentFile.path) : 'Select GST File'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (currentFile != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      if (field == 'pan_attachment') {
                        panAttachmentXFile = null;
                      } else {
                        gstAttachmentXFile = null;
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

  Widget _buildCreateMoreDetailsSection({required StateSetter setState}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MORE DETAILS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  moreDetailControllers.add({
                    'dummy_name': TextEditingController(),
                    'dummy_email': TextEditingController(),
                    'dummy_mobile': TextEditingController(),
                  });
                });
              },
              icon: Icon(Icons.add, size: 20),
              label: Text('Add'),
            ),
          ],
        ),
        SizedBox(height: 10),
        
        // List of more details
        ...moreDetailControllers.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, TextEditingController> controllers = entry.value;
          
          return Card(
            margin: EdgeInsets.symmetric(vertical: 5),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Detail ${index + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            // Dispose controllers before removing
                            controllers.forEach((key, controller) {
                              controller.dispose();
                            });
                            moreDetailControllers.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                  TextField(
                    controller: controllers['dummy_name'],
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: controllers['dummy_email'],
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: controllers['dummy_mobile'],
                    decoration: InputDecoration(
                      labelText: 'Mobile',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> pickFile(String type) async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          if (type == 'pan') {
            panAttachmentXFile = file;
          } else {
            gstAttachmentXFile = file;
          }
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> createBuyer() async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(createApiUrl),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Token $token';

      // Add text fields - exclude role only (include bp_code)
      createControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty && 
            key != 'pan_attachment' && 
            key != 'gst_attachment' &&
            key != 'more_detail' &&
            key.toLowerCase() != 'role') {
          request.fields[key] = controller.text;
        }
      });

      // Add PAN attachment if selected with proper filename
      if (panAttachmentXFile != null) {
        String filename = path.basename(panAttachmentXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(panAttachmentXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          final bytes = await panAttachmentXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'pan_attachment',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(panAttachmentXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'pan_attachment',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      // Add GST attachment if selected with proper filename
      if (gstAttachmentXFile != null) {
        String filename = path.basename(gstAttachmentXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(gstAttachmentXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          final bytes = await gstAttachmentXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'gst_attachment',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(gstAttachmentXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'gst_attachment',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      // Add more_detail fields with array indexing
      for (int i = 0; i < moreDetailControllers.length; i++) {
        var controllers = moreDetailControllers[i];
        String name = controllers['dummy_name']?.text.trim() ?? '';
        String email = controllers['dummy_email']?.text.trim() ?? '';
        String mobile = controllers['dummy_mobile']?.text.trim() ?? '';
        
        // Only add if at least one field has data
        if (name.isNotEmpty || email.isNotEmpty || mobile.isNotEmpty) {
          request.fields['more_detail[$i][dummy_name]'] = name;
          request.fields['more_detail[$i][dummy_email]'] = email;
          request.fields['more_detail[$i][dummy_mobile]'] = mobile;
        }
      }

      // Send request
      var response = await request.send();
      
      if (response.statusCode == 201) {
        // Clear controllers after successful creation
        createControllers.forEach((key, controller) {
          controller.clear();
        });
        
        // Clear more detail controllers
        for (var controllers in moreDetailControllers) {
          controllers.forEach((key, controller) {
            controller.clear();
          });
        }
        moreDetailControllers.clear();
        
        panAttachmentXFile = null;
        gstAttachmentXFile = null;
        
        // Refresh the buyer list
        fetchBuyers();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Buyer created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Read response body for error details
        final responseBody = await response.stream.bytesToString();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create buyer. Status: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Print error response for debugging
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

  Future<void> updateBuyer(int id) async {
    if (token == null || editControllers == null) return;

    setState(() => isLoading = true);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$updateApiUrl$id/'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Token $token';

      // Add text fields - exclude role only (include bp_code)
      editControllers!.forEach((key, controller) {
        if (key != 'pan_attachment' && 
            key != 'gst_attachment' &&
            key != 'more_detail' &&
            key.toLowerCase() != 'role') {
          request.fields[key] = controller.text;
        }
      });

      // Add PAN attachment if a new one is selected with proper filename
      if (panAttachmentXFile != null) {
        String filename = path.basename(panAttachmentXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(panAttachmentXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await panAttachmentXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'pan_attachment',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(panAttachmentXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'pan_attachment',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      // Add GST attachment if a new one is selected with proper filename
      if (gstAttachmentXFile != null) {
        String filename = path.basename(gstAttachmentXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(gstAttachmentXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await gstAttachmentXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'gst_attachment',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(gstAttachmentXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'gst_attachment',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      // Add more_detail fields with array indexing
      if (editMoreDetailControllers != null) {
        for (int i = 0; i < editMoreDetailControllers!.length; i++) {
          var controllers = editMoreDetailControllers![i];
          String name = controllers['dummy_name']?.text.trim() ?? '';
          String email = controllers['dummy_email']?.text.trim() ?? '';
          String mobile = controllers['dummy_mobile']?.text.trim() ?? '';
          
          // Only add if at least one field has data
          if (name.isNotEmpty || email.isNotEmpty || mobile.isNotEmpty) {
            request.fields['more_detail[$i][dummy_name]'] = name;
            request.fields['more_detail[$i][dummy_email]'] = email;
            request.fields['more_detail[$i][dummy_mobile]'] = mobile;
          }
        }
      }

      // Send request
      var response = await request.send();
      
      if (response.statusCode == 200) {
        // Clear edit controllers after successful update
        editControllers = null;
        editMoreDetailControllers = null;
        editingBuyerId = null;
        
        panAttachmentXFile = null;
        gstAttachmentXFile = null;
        
        // Refresh the buyer list
        fetchBuyers();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Buyer updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Read response body for error details
        final responseBody = await response.stream.bytesToString();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update buyer. Status: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Print error response for debugging
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

  @override
  Widget build(BuildContext context) {
    final selectedFields = getSelectedFields();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Buyers'),
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
            onPressed: () => fetchBuyers(),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: showAddBuyerDialog,
              icon: Icon(Icons.add),
              label: Text('Add New'),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : buyers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No buyers found'),
                      if (filterParams.length > 1) ...[
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
                    
                    // Show active filters if any (excluding role)
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
                                'Filters: ${filterParams.entries.where((e) => e.key != 'role').map((e) => '${e.key}=${e.value}').join(', ')}',
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
                              rows: buyers.map((buyer) {
                                final id = buyer['id'];
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

                                    // ACTIONS - Show only if this row is selected
                                    DataCell(
                                      isSelected
                                          ? Row(
                                              children: [
                                                // Show View button only if enableView is true
                                                if (enableView)
                                                  ElevatedButton(
                                                    onPressed: () => fetchBuyerDetails(id),
                                                    child: Text(
                                                      'View',
                                                      style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                
                                                // Show Edit button only if enableEdit is true
                                                if (enableEdit) ...[
                                                  if (enableView) SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: () => showBuyerDialog(buyer, true),
                                                    child: Text(
                                                      'Edit',
                                                      style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          : SizedBox.shrink(), // Empty widget when not selected
                                    ),

                                    // Selected fields only
                                    ...selectedFields.map((f) {
                                      String displayValue = getFieldValue(buyer, f['key']);
                                      
                                      // Special handling for map_location to make it tappable
                                      if (f['key'] == 'map_location' && displayValue.isNotEmpty) {
                                        return DataCell(
                                          GestureDetector(
                                            onTap: () {
                                              // Open map link
                                              final url = buyer['map_location'];
                                              if (url != null && url.toString().isNotEmpty) {
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
                                              final url = buyer[f['key']];
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
                                      
                                      // Special handling for more_detail
                                      if (f['key'] == 'more_detail') {
                                        final details = buyer['more_detail'];
                                        if (details != null && details is List) {
                                          return DataCell(
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${details.length} details',
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
                                        Container(
                                          child: Text(
                                            displayValue,
                                            style: TextStyle(
                                              fontSize: compactRows ? 11 : 13,
                                              color: modernCellColoring && isSelected 
                                                  ? Colors.blue 
                                                  : null,
                                            ),
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




// import 'package:flutter/material.dart';
// // import 'package:url_launcher/url_launcher.dart';
// // import '../services/auth_service.dart';
// // import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:file_picker/file_picker.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {}; // Keep as Set for potential multi-select in future
//   String? token;
//   List<String> dynamicFields = [];

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
//   final String filterApiUrl = 'http://127.0.0.1:8000/user/BusinessPartner/filter/';
//   final String createApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/detail/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/';

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   int pageSize = 20; // Default page size from backend
  
//   // Filter and sort variables
//   Map<String, String> filterParams = {
//     'role': 'buyer', // Always filter by buyer role
//   };
//   String? sortBy;
//   String? sortOrder; // 'asc' or 'desc'
  
//   // Search query for field selection
//   String fieldSearchQuery = '';
  
//   // List settings variables
//   bool compactRows = false;
//   bool activeRowHighlighting = false;
//   bool modernCellColoring = false;
//   bool enableView = false;
//   bool enableEdit = false;
  
//   // Scroll controller for horizontal scrolling
//   final ScrollController _horizontalScrollController = ScrollController();
  
//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
//     {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
//     {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
//     {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
//     {'key': 'landline', 'label': 'Landline', 'selected': false, 'order': 4},
//     {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 5},
//     {'key': 'company_name', 'label': 'Company Name', 'selected': true, 'order': 6},
//     {'key': 'gst_number', 'label': 'GST Number', 'selected': true, 'order': 7},
//     {'key': 'refered_by', 'label': 'Referred By', 'selected': false, 'order': 8},
//     {'key': 'pan_name', 'label': 'PAN Name', 'selected': false, 'order': 9},
//     {'key': 'pan_no', 'label': 'PAN Number', 'selected': false, 'order': 10},
//     {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 11},
//     {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 12},
//     {'key': 'more', 'label': 'More Info', 'selected': false, 'order': 13},
//     {'key': 'more_detail', 'label': 'More Details', 'selected': false, 'isComplex': true, 'order': 14},
//     {'key': 'door_no', 'label': 'Door No', 'selected': false, 'order': 15},
//     {'key': 'shop_no', 'label': 'Shop No', 'selected': false, 'order': 16},
//     {'key': 'complex_name', 'label': 'Complex Name', 'selected': false, 'order': 17},
//     {'key': 'building_name', 'label': 'Building Name', 'selected': false, 'order': 18},
//     {'key': 'street_name', 'label': 'Street Name', 'selected': false, 'order': 19},
//     {'key': 'area', 'label': 'Area', 'selected': false, 'order': 20},
//     {'key': 'pincode', 'label': 'Pincode', 'selected': false, 'order': 21},
//     {'key': 'city', 'label': 'City', 'selected': false, 'order': 22},
//     {'key': 'state', 'label': 'State', 'selected': false, 'order': 23},
//     {'key': 'country', 'label': 'Country', 'selected': false, 'order': 24},
//     {'key': 'map_location', 'label': 'Map Location', 'selected': false, 'order': 25},
//     {'key': 'location_guide', 'label': 'Location Guide', 'selected': false, 'order': 26},
//   ];
  
//   // Filter field controllers
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController bpNameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController companyNameController = TextEditingController();
//   final TextEditingController landlineController = TextEditingController();
//   final TextEditingController gstNumberController = TextEditingController();

//   // For creating new buyer
//   final Map<String, TextEditingController> createControllers = {};
//   // Store more details as controllers for create
//   List<Map<String, TextEditingController>> moreDetailControllers = [];
  
//   // For editing existing buyer
//   Map<String, TextEditingController>? editControllers;
//   List<Map<String, TextEditingController>>? editMoreDetailControllers;
//   int? editingBuyerId;
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;

//   // Currently viewed buyer for detail view
//   Map<String, dynamic>? currentViewedBuyer;

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
//     bpNameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     companyNameController.dispose();
//     landlineController.dispose();
//     gstNumberController.dispose();
    
//     // Dispose all text controllers
//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });
    
//     // Dispose edit controllers if they exist
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose create more detail controllers
//     for (var controllers in moreDetailControllers) {
//       controllers.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose edit more detail controllers
//     if (editMoreDetailControllers != null) {
//       for (var controllers in editMoreDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose scroll controller
//     _horizontalScrollController.dispose();
    
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('buyer_fields');
//     String? savedOrder = prefs.getString('buyer_field_order');
    
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
    
//     await prefs.setString('buyer_fields', json.encode(selections));
    
//     // Save field order
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('buyer_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     setState(() {
//       compactRows = prefs.getBool('buyer_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('buyer_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('buyer_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('buyer_enable_view') ?? false;
//       enableEdit = prefs.getBool('buyer_enable_edit') ?? false;
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
    
//     await prefs.setBool('buyer_compact_rows', compactRows);
//     await prefs.setBool('buyer_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('buyer_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('buyer_enable_view', enableView);
//     await prefs.setBool('buyer_enable_edit', enableEdit);
//   }

//   // Get selected fields for display in correct order
//   List<Map<String, dynamic>> getSelectedFields() {
//     return availableFields
//         .where((field) => field['selected'] == true)
//         .toList()
//         ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
//   }

//   // Toggle field selection
//   void toggleFieldSelection(String key) {
//     setState(() {
//       final index = availableFields.indexWhere((field) => field['key'] == key);
//       if (index != -1) {
//         availableFields[index]['selected'] = !availableFields[index]['selected'];
//       }
//     });
//   }

//   // Reset to default fields
//   void resetToDefaultFields() {
//     setState(() {
//       // Reset selection and order
//       List<Map<String, dynamic>> defaultFields = [
//         {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//         {'key': 'business_name', 'label': 'Business Name', 'selected': true},
//         {'key': 'name', 'label': 'Name', 'selected': true},
//         {'key': 'mobile', 'label': 'Mobile', 'selected': true},
//         {'key': 'business_email', 'label': 'Email', 'selected': true},
//         {'key': 'company_name', 'label': 'Company Name', 'selected': true},
//         {'key': 'gst_number', 'label': 'GST Number', 'selected': true},
//         {'key': 'landline', 'label': 'Landline', 'selected': false},
//         {'key': 'refered_by', 'label': 'Referred By', 'selected': false},
//         {'key': 'pan_name', 'label': 'PAN Name', 'selected': false},
//         {'key': 'pan_no', 'label': 'PAN Number', 'selected': false},
//         {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
//         {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
//         {'key': 'more', 'label': 'More Info', 'selected': false},
//         {'key': 'more_detail', 'label': 'More Details', 'selected': false, 'isComplex': true},
//         {'key': 'door_no', 'label': 'Door No', 'selected': false},
//         {'key': 'shop_no', 'label': 'Shop No', 'selected': false},
//         {'key': 'complex_name', 'label': 'Complex Name', 'selected': false},
//         {'key': 'building_name', 'label': 'Building Name', 'selected': false},
//         {'key': 'street_name', 'label': 'Street Name', 'selected': false},
//         {'key': 'area', 'label': 'Area', 'selected': false},
//         {'key': 'pincode', 'label': 'Pincode', 'selected': false},
//         {'key': 'city', 'label': 'City', 'selected': false},
//         {'key': 'state', 'label': 'State', 'selected': false},
//         {'key': 'country', 'label': 'Country', 'selected': false},
//         {'key': 'map_location', 'label': 'Map Location', 'selected': false},
//         {'key': 'location_guide', 'label': 'Location Guide', 'selected': false},
//       ];
      
//       // Update existing fields while preserving additional properties
//       for (int i = 0; i < defaultFields.length; i++) {
//         final defaultField = defaultFields[i];
//         final existingIndex = availableFields.indexWhere((f) => f['key'] == defaultField['key']);
//         if (existingIndex != -1) {
//           availableFields[existingIndex]['selected'] = defaultField['selected'];
//           availableFields[existingIndex]['order'] = i;
//         }
//       }
//     });
    
//     // Save selections to SharedPreferences
//     saveFieldSelections();
    
//     // Show a snackbar to confirm reset
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Fields reset to default'),
//         duration: Duration(seconds: 2),
//       ),
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
//                         .toLowerCase()
//                         .contains(fieldSearchQuery.toLowerCase()) ||
//                         field['key']
//                         .toLowerCase()
//                         .contains(fieldSearchQuery.toLowerCase());
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
//                             'Personalize List Columns - Buyers',
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
//                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
//                                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
//                                             itemCount: filteredAvailableFields.length,
//                                             itemBuilder: (context, index) {
//                                               final field = filteredAvailableFields[index];
//                                               return ListTile(
//                                                 dense: true,
//                                                 title: Text(
//                                                   field['label'],
//                                                   style: TextStyle(fontSize: 14),
//                                                 ),
//                                                 subtitle: field['isComplex'] == true 
//                                                     ? Text('Complex field', style: TextStyle(fontSize: 11, color: Colors.grey))
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
//                                                     availableFieldsList.removeWhere((f) => f['key'] == field['key']);
//                                                     selectedFieldsList.add(field);
//                                                     selectedFieldIndex = selectedFieldsList.length - 1;
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
//                                           for (var field in filteredAvailableFields.toList()) {
//                                             field['selected'] = true;
//                                             availableFieldsList.removeWhere((f) => f['key'] == field['key']);
//                                             selectedFieldsList.add(field);
//                                           }
//                                           if (selectedFieldsList.isNotEmpty) {
//                                             selectedFieldIndex = selectedFieldsList.length - 1;
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
//                                           for (var field in selectedFieldsList.toList()) {
//                                             field['selected'] = false;
//                                             selectedFieldsList.removeWhere((f) => f['key'] == field['key']);
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
//                                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
//                                                   for (var field in selectedFieldsList.toList()) {
//                                                     field['selected'] = false;
//                                                   }
//                                                   availableFieldsList.addAll(selectedFieldsList);
//                                                   selectedFieldsList.clear();
//                                                   selectedFieldIndex = -1;
//                                                 });
//                                               },
//                                               style: TextButton.styleFrom(
//                                                 padding: EdgeInsets.zero,
//                                                 minimumSize: Size(0, 0),
//                                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                                               ),
//                                               child: Text(
//                                                 'Remove all',
//                                                 style: TextStyle(fontSize: 12, color: Colors.red),
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
//                                                     fontWeight: selectedFieldIndex == index 
//                                                         ? FontWeight.bold 
//                                                         : FontWeight.w500,
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
//                                                       selectedFieldsList.removeAt(index);
//                                                       availableFieldsList.add(field);
//                                                       if (selectedFieldIndex >= selectedFieldsList.length) {
//                                                         selectedFieldIndex = selectedFieldsList.length - 1;
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
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         IconButton(
//                                           icon: Icon(Icons.arrow_upward, color: Colors.blue),
//                                           onPressed: selectedFieldIndex > 0
//                                               ? () {
//                                                   setState(() {
//                                                     // Move selected field up
//                                                     final field = selectedFieldsList.removeAt(selectedFieldIndex);
//                                                     selectedFieldsList.insert(selectedFieldIndex - 1, field);
//                                                     selectedFieldIndex = selectedFieldIndex - 1;
//                                                   });
//                                                 }
//                                               : null,
//                                         ),
//                                         SizedBox(width: 30),
//                                         IconButton(
//                                           icon: Icon(Icons.arrow_downward, color: Colors.blue),
//                                           onPressed: selectedFieldIndex < selectedFieldsList.length - 1
//                                               ? () {
//                                                   setState(() {
//                                                     // Move selected field down
//                                                     final field = selectedFieldsList.removeAt(selectedFieldIndex);
//                                                     selectedFieldsList.insert(selectedFieldIndex + 1, field);
//                                                     selectedFieldIndex = selectedFieldIndex + 1;
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
//                           // Second row of checkboxes
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
//                               Text('Enable view'),
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
//                               Text('Enable edit'),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     // Footer with Reset button and metadata
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'business_name', 'label': 'Business Name', 'selected': true},
//                                   {'key': 'name', 'label': 'Name', 'selected': true},
//                                   {'key': 'mobile', 'label': 'Mobile', 'selected': true},
//                                   {'key': 'business_email', 'label': 'Email', 'selected': true},
//                                   {'key': 'company_name', 'label': 'Company Name', 'selected': true},
//                                   {'key': 'gst_number', 'label': 'GST Number', 'selected': true},
//                                 ];
                                
//                                 for (var field in availableFields) {
//                                   bool isDefaultSelected = defaultFields.any((df) => df['key'] == field['key']);
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
//                                 localEnableView = false;
//                                 localEnableEdit = false;
                                
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
//                                 'Buyers - Field Selection',
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
//                                 for (int i = 0; i < selectedFieldsList.length; i++) {
//                                   final selectedField = selectedFieldsList[i];
//                                   final index = availableFields.indexWhere(
//                                     (f) => f['key'] == selectedField['key']
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
//                                   (a['order'] ?? 0).compareTo(b['order'] ?? 0)
//                                 );
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

//   // Format complex field for display
//   String formatComplexField(dynamic value) {
//     if (value == null) return '';
//     if (value is List) {
//       if (value.isEmpty) return '[]';
//       if (value.length > 1) {
//         return '[${value.length} items]';
//       } else {
//         // Show first item summary
//         final firstItem = value.first;
//         if (firstItem is Map) {
//           final name = firstItem['dummy_name'] ?? '';
//           final email = firstItem['dummy_email'] ?? '';
//           return '$name, $email';
//         }
//       }
//     }
//     return value.toString();
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> buyer, String key) {
//     final value = buyer[key];
    
//     if (value == null) return '';
    
//     // Handle complex fields
//     if (key == 'more_detail' && value is List) {
//       return formatComplexField(value);
//     }
    
//     // Handle map location - show as link text
//     if (key == 'map_location' && value.toString().isNotEmpty) {
//       return '📍 Map Link';
//     }
    
//     // Handle attachments
//     if (key.contains('attachment') && value.toString().isNotEmpty) {
//       return '📎 Attachment';
//     }
    
//     return value.toString();
//   }

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchBuyers();
//   }

//   // Helper method to safely get int from dynamic value
//   int safeParseInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is double) return value.toInt();
//     if (value is String) return int.tryParse(value) ?? 0;
//     return 0;
//   }

//   // Build URL with filter and sort parameters
//   String buildRequestUrl({String? baseUrl}) {
//     // Start with base filter URL
//     String url = filterApiUrl;
    
//     // Build query parameters
//     Map<String, String> queryParams = {};
    
//     // Add role filter (always present)
//     queryParams['role'] = 'buyer';
    
//     // Add additional filter parameters from filterParams
//     filterParams.forEach((key, value) {
//       if (key != 'role' && value.isNotEmpty) {
//         queryParams[key] = value;
//       }
//     });
    
//     // Add sort parameters if set
//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
      
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }
    
//     // Add pagination parameters
//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
    
//     // Add page number for pagination if not first page
//     if (currentPage > 1) {
//       queryParams['page'] = currentPage.toString();
//     }
    
//     // Build URI with query parameters
//     Uri uri = Uri.parse(url);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Use provided URL for pagination, otherwise build URL with filters
//       final requestUrl = url ?? buildRequestUrl();
      
//       print('Fetching: $requestUrl'); // For debugging
      
//       final response = await http.get(
//         Uri.parse(requestUrl),
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           // Include bp_code in dynamic fields to make it visible
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id' && k.toLowerCase() != 'role')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = safeParseInt(data['count']);
          
//           // Calculate current page from URL if possible
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
//         print('Error response: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   // Fetch single buyer details
//   Future<void> fetchBuyerDetails(int id) async {
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
//           currentViewedBuyer = data;
//           isLoading = false;
//         });
        
//         // Show detail dialog with fetched data
//         showBuyerDetailDialog();
//       } else {
//         print('Error fetching details: ${response.statusCode}');
//         setState(() => isLoading = false);
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to fetch buyer details'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Exception fetching details: $e');
//       setState(() => isLoading = false);
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   // Apply all filters at once
//   Future<void> applyFilters() async {
//     // Clear existing filter params but keep role
//     filterParams.clear();
//     filterParams['role'] = 'buyer';
    
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (bpNameController.text.isNotEmpty) {
//       filterParams['name'] = bpNameController.text;
//     }
//     if (emailController.text.isNotEmpty) {
//       filterParams['business_email'] = emailController.text;
//     }
//     if (phoneController.text.isNotEmpty) {
//       filterParams['mobile'] = phoneController.text;
//     }
//     if (companyNameController.text.isNotEmpty) {
//       filterParams['company_name'] = companyNameController.text;
//     }
//     if (landlineController.text.isNotEmpty) {
//       filterParams['landline'] = landlineController.text;
//     }
//     if (gstNumberController.text.isNotEmpty) {
//       filterParams['gst_number'] = gstNumberController.text;
//     }
    
//     // Reset to first page when applying filters
//     currentPage = 1;
//     await fetchBuyers();
//   }

//   // Clear all filters
//   Future<void> clearFilters() async {
//     filterParams.clear();
//     filterParams['role'] = 'buyer'; // Keep role filter
    
//     bpCodeController.clear();
//     bpNameController.clear();
//     emailController.clear();
//     phoneController.clear();
//     companyNameController.clear();
//     landlineController.clear();
//     gstNumberController.clear();
    
//     await fetchBuyers();
//   }

//   // Show filter dialog
//   void showFilterDialog() {
//     // Initialize controllers with current filter values
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     bpNameController.text = filterParams['name'] ?? '';
//     emailController.text = filterParams['business_email'] ?? '';
//     phoneController.text = filterParams['mobile'] ?? '';
//     companyNameController.text = filterParams['company_name'] ?? '';
//     landlineController.text = filterParams['landline'] ?? '';
//     gstNumberController.text = filterParams['gst_number'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Filter Buyers'),
//           content: Container(
//             width: double.maxFinite,
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField(
//                     controller: bpCodeController,
//                     decoration: InputDecoration(
//                       labelText: 'BP Code',
//                       hintText: 'e.g., BV009',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.code),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: bpNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.person),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: emailController,
//                     decoration: InputDecoration(
//                       labelText: 'Email',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.email),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: phoneController,
//                     decoration: InputDecoration(
//                       labelText: 'Phone',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: companyNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Company Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.business),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: landlineController,
//                     decoration: InputDecoration(
//                       labelText: 'LandLine',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.call),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: gstNumberController,
//                     decoration: InputDecoration(
//                       labelText: 'GST Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.numbers),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 clearFilters();
//               },
//               child: Text('Clear All'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 applyFilters();
//               },
//               child: Text('Apply Filters'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // Apply sort
//   Future<void> applySort(String field, String order) async {
//     print('Applying sort: $field, $order'); // Debug print
    
//     setState(() {
//       sortBy = field;
//       sortOrder = order;
//     });
    
//     // Reset to first page when sorting
//     currentPage = 1;
//     await fetchBuyers();
//   }

//   // Clear sort
//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchBuyers();
//   }

//   // Toggle sort order
//   void toggleSortOrder() {
//     if (sortBy == null) return;
    
//     String newOrder;
//     if (sortOrder == null || sortOrder == 'asc') {
//       newOrder = 'desc';
//     } else {
//       newOrder = 'asc';
//     }
    
//     applySort(sortBy!, newOrder);
//   }

//   // Show sort options
//   void showSortDialog() {
//     List<Map<String, String>> sortFields = [
//       {'value': 'bp_code', 'label': 'BP Code'},
//       {'value': 'name', 'label': 'Name'},
//       {'value': 'business_name', 'label': 'Business Name'},
//       {'value': 'business_email', 'label': 'Email'},
//       {'value': 'mobile', 'label': 'Phone'},
//       {'value': 'company_name', 'label': 'Company Name'},
//       {'value': 'landline', 'label': 'LandLine'},
//       {'value': 'gst_number', 'label': 'GST Number'},
//       {'value': 'created_at', 'label': 'Created Date'},
//       {'value': 'id', 'label': 'ID'},
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
//                       // Sort field selection
//                       ...sortFields.map((field) {
//                         return RadioListTile<String>(
//                           title: Text(field['label']!),
//                           value: field['value']!,
//                           groupValue: sortBy,
//                           onChanged: (value) {
//                             setState(() {
//                               this.sortBy = value;
//                               // Set default sort order if not set
//                               if (sortOrder == null) {
//                                 sortOrder = 'asc';
//                               }
//                             });
//                           },
//                           secondary: sortBy == field['value'] ? IconButton(
//                             icon: Icon(sortOrder == 'desc' 
//                                 ? Icons.arrow_downward 
//                                 : Icons.arrow_upward),
//                             onPressed: () {
//                               setState(() {
//                                 sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
//                               });
//                             },
//                           ) : null,
//                         );
//                       }).toList(),
                      
//                       SizedBox(height: 16),
                      
//                       // Sort order selection
//                       if (sortBy != null)
//                         Container(
//                           padding: EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Sort Order:', 
//                                 style: TextStyle(fontWeight: FontWeight.bold)),
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
//                       // Ensure sortOrder is set
//                       if (sortOrder == null) {
//                         sortOrder = 'asc';
//                       }
//                       fetchBuyers();
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

//   // Pagination methods
//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   // Change page size
//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
    
//     await fetchBuyers();
//   }

//   // Show buyer detail dialog using fetched data
//   void showBuyerDetailDialog() {
//     if (currentViewedBuyer == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Buyer Details'),
//         content: Container(
//           width: double.maxFinite,
//           constraints: BoxConstraints(
//             maxHeight: MediaQuery.of(context).size.height * 0.7,
//           ),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Include all fields including bp_code
//                 ...currentViewedBuyer!.entries.where((entry) {
//                   String key = entry.key;
//                   return key.toLowerCase() != 'id' && key != 'more_detail';
//                 }).map((entry) {
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         SizedBox(
//                           width: 120,
//                           child: Text(
//                             '${entry.key.replaceAll('_', ' ')}:',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: _buildDetailValue(entry.key, entry.value),
//                         ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
                
//                 // More Detail section
//                 if (currentViewedBuyer!['more_detail'] != null)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'MORE DETAILS',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                         SizedBox(height: 8),
//                         ...List<Map<String, dynamic>>.from(currentViewedBuyer!['more_detail']).asMap().entries.map((entry) {
//                           int index = entry.key;
//                           Map<String, dynamic> detail = entry.value;
                          
//                           return Card(
//                             margin: EdgeInsets.symmetric(vertical: 4),
//                             child: Padding(
//                               padding: const EdgeInsets.all(8.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Detail ${index + 1}', 
//                                     style: TextStyle(fontWeight: FontWeight.bold)),
//                                   SizedBox(height: 4),
//                                   Text('Name: ${detail['dummy_name'] ?? ''}'),
//                                   Text('Email: ${detail['dummy_email'] ?? ''}'),
//                                   Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                                 ],
//                               ),
//                             ),
//                           );
//                         }).toList(),
//                       ],
//                     ),
//                   ),
//               ],
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

//   // Helper to build detail value with proper formatting
//   Widget _buildDetailValue(String key, dynamic value) {
//     if (key == 'pan_attachment' || key == 'gst_attachment') {
//       if (value != null && value.toString().isNotEmpty) {
//         return InkWell(
//           onTap: () {
//             // Open file URL
//             print('Open: $value');
//           },
//           child: Text(
//             'View File',
//             style: TextStyle(
//               color: Colors.blue,
//               decoration: TextDecoration.underline,
//             ),
//           ),
//         );
//       }
//       return Text('No file');
//     }
    
//     if (value == null) return Text('');
//     if (value is bool) return Text(value.toString());
//     if (value is Map || value is List) return Text(value.toString());
//     return Text(value.toString());
//   }

//   // Show buyer dialog with scrollable content (for view/edit)
//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     // If editing, initialize controllers with buyer data
//     if (isEdit) {
//       editingBuyerId = buyer['id'];
//       editControllers = {};
      
//       // Initialize all field controllers except id and role (include bp_code for editing)
//       for (var field in buyer.keys) {
//         if (field.toLowerCase() != 'id' && 
//             field.toLowerCase() != 'role' &&
//             field != 'more_detail') {
//           editControllers![field] = TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           );
//         }
//       }
      
//       // Initialize more detail controllers with existing data
//       editMoreDetailControllers = [];
//       if (buyer['more_detail'] != null && buyer['more_detail'] is List) {
//         List<Map<String, dynamic>> existingMoreDetails = 
//             List<Map<String, dynamic>>.from(buyer['more_detail']);
        
//         for (var detail in existingMoreDetails) {
//           editMoreDetailControllers!.add({
//             'dummy_name': TextEditingController(text: detail['dummy_name']?.toString() ?? ''),
//             'dummy_email': TextEditingController(text: detail['dummy_email']?.toString() ?? ''),
//             'dummy_mobile': TextEditingController(text: detail['dummy_mobile']?.toString() ?? ''),
//           });
//         }
//       }
      
//       // Reset file selections for edit
//       panAttachmentFile = null;
//       gstAttachmentFile = null;
//       panAttachmentFileName = null;
//       gstAttachmentFileName = null;
//     }

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Show all fields except 'id', 'role', and 'more_detail' (include bp_code)
//                     ...buyer.entries.where((entry) {
//                       String key = entry.key;
//                       return key.toLowerCase() != 'id' && 
//                              key.toLowerCase() != 'role' &&
//                              key != 'more_detail';
//                     }).map((entry) {
//                       // Check if this is a file attachment field
//                       if (entry.key == 'pan_attachment' || entry.key == 'gst_attachment') {
//                         return _buildFileAttachmentField(
//                           context: context,
//                           field: entry.key,
//                           label: entry.key.replaceAll('_', ' ').toUpperCase(),
//                           buyer: buyer,
//                           isEdit: isEdit,
//                           setState: setState,
//                         );
//                       }
                      
//                       // For edit mode, use editControllers
//                       if (isEdit && editControllers != null && editControllers!.containsKey(entry.key)) {
//                         return _buildTextField(
//                           context: context,
//                           field: entry.key,
//                           controller: editControllers![entry.key],
//                           buyer: buyer,
//                           isEdit: isEdit,
//                           setState: setState,
//                         );
//                       } else {
//                         // For view mode, show the value
//                         return _buildTextField(
//                           context: context,
//                           field: entry.key,
//                           value: entry.value?.toString() ?? '',
//                           buyer: buyer,
//                           isEdit: isEdit,
//                           setState: setState,
//                         );
//                       }
//                     }).toList(),
                    
//                     // More Detail section
//                     _buildMoreDetailsSection(
//                       buyer: buyer,
//                       isEdit: isEdit,
//                       setState: setState,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               if (isEdit)
//                 ElevatedButton(
//                   onPressed: () async {
//                     await updateBuyer(editingBuyerId!);
//                     Navigator.pop(context);
//                   },
//                   child: Text('Save'),
//                 ),
//               TextButton(
//                 onPressed: () {
//                   // Clean up edit controllers when closing dialog
//                   if (isEdit) {
//                     editControllers = null;
//                     editMoreDetailControllers = null;
//                     editingBuyerId = null;
//                     panAttachmentFile = null;
//                     gstAttachmentFile = null;
//                     panAttachmentFileName = null;
//                     gstAttachmentFileName = null;
//                   }
//                   Navigator.pop(context);
//                 },
//                 child: Text(isEdit ? 'Cancel' : 'Close'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required BuildContext context,
//     required String field,
//     TextEditingController? controller,
//     String? value,
//     required Map<String, dynamic> buyer,
//     required bool isEdit,
//     required StateSetter setState,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: controller,
//         readOnly: !isEdit,
//         decoration: InputDecoration(
//           labelText: field.replaceAll('_', ' ').toUpperCase(),
//           border: OutlineInputBorder(),
//         ),
//       ),
//     );
//   }

//   Widget _buildFileAttachmentField({
//     required BuildContext context,
//     required String field,
//     required String label,
//     required Map<String, dynamic> buyer,
//     required bool isEdit,
//     required StateSetter setState,
//   }) {
//     String? fileUrl = buyer[field];
    
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//             ),
//           ),
//           SizedBox(height: 4),
//           if (fileUrl != null && fileUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     // Open file in browser or show preview
//                     print('File URL: $fileUrl');
//                   },
//                   child: Text(
//                     'View Existing Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ),
//                 if (isEdit)
//                   SizedBox(height: 8),
//               ],
//             )
//           else
//             Text('No attachment'),
          
//           // File upload for edit mode
//           if (isEdit)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () async {
//                         await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
//                         setState(() {});
//                       },
//                         icon: Icon(Icons.attach_file),
//                         label: Text(
//                           field == 'pan_attachment' 
//                             ? (panAttachmentFileName ?? 'Select New PAN File')
//                             : (gstAttachmentFileName ?? 'Select New GST File'),
//                         ),
//                       ),
//                     ),
//                     if ((field == 'pan_attachment' && panAttachmentFileName != null) ||
//                         (field == 'gst_attachment' && gstAttachmentFileName != null))
//                       IconButton(
//                         icon: Icon(Icons.clear),
//                         onPressed: () {
//                           setState(() {
//                             if (field == 'pan_attachment') {
//                               panAttachmentFile = null;
//                               panAttachmentFileName = null;
//                             } else {
//                               gstAttachmentFile = null;
//                               gstAttachmentFileName = null;
//                             }
//                           });
//                         },
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMoreDetailsSection({
//     required Map<String, dynamic> buyer,
//     required bool isEdit,
//     required StateSetter setState,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'MORE DETAILS',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             if (isEdit)
//               ElevatedButton.icon(
//                 onPressed: () {
//                   setState(() {
//                     if (editMoreDetailControllers == null) {
//                       editMoreDetailControllers = [];
//                     }
//                     editMoreDetailControllers!.add({
//                       'dummy_name': TextEditingController(),
//                       'dummy_email': TextEditingController(),
//                       'dummy_mobile': TextEditingController(),
//                     });
//                   });
//                 },
//                 icon: Icon(Icons.add, size: 20),
//                 label: Text('Add'),
//               ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         // List of more details
//         if (isEdit && editMoreDetailControllers != null)
//           ...editMoreDetailControllers!.asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, TextEditingController> controllers = entry.value;
            
//             return Card(
//               margin: EdgeInsets.symmetric(vertical: 5),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Detail ${index + 1}',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           onPressed: () {
//                             setState(() {
//                               // Dispose controllers before removing
//                               controllers.forEach((key, controller) {
//                                 controller.dispose();
//                               });
//                               editMoreDetailControllers!.removeAt(index);
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                     TextField(
//                       controller: controllers['dummy_name'],
//                       decoration: InputDecoration(
//                         labelText: 'Name',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     TextField(
//                       controller: controllers['dummy_email'],
//                       decoration: InputDecoration(
//                         labelText: 'Email',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     TextField(
//                       controller: controllers['dummy_mobile'],
//                       decoration: InputDecoration(
//                         labelText: 'Mobile',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList()
//         else if (!isEdit && buyer['more_detail'] != null && buyer['more_detail'] is List)
//           ...List<Map<String, dynamic>>.from(buyer['more_detail']).asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, dynamic> detail = entry.value;
            
//             return Card(
//               margin: EdgeInsets.symmetric(vertical: 5),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Detail ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
//                     SizedBox(height: 4),
//                     Text('Name: ${detail['dummy_name'] ?? ''}'),
//                     Text('Email: ${detail['dummy_email'] ?? ''}'),
//                     Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//       ],
//     );
//   }

//   // Show add buyer dialog with scrollable content
//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields (excluding role only, include bp_code)
//     for (var field in dynamicFields) {
//       if (field.toLowerCase() != 'role' && 
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }
    
//     // Initialize moreDetails controllers
//     moreDetailControllers = [];
//     // Reset file selections
//     panAttachmentFile = null;
//     gstAttachmentFile = null;
//     panAttachmentFileName = null;
//     gstAttachmentFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Buyer'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Main fields - exclude role only (include bp_code)
//                     ...dynamicFields.where((field) => 
//                       field.toLowerCase() != 'role' && 
//                       field != 'more_detail'
//                     ).map((field) {
//                       if (!createControllers.containsKey(field)) {
//                         createControllers[field] = TextEditingController();
//                       }
                      
//                       // Check if this is a file attachment field
//                       if (field == 'pan_attachment' || field == 'gst_attachment') {
//                         return _buildCreateFileAttachmentField(
//                           context: context,
//                           field: field,
//                           label: field.replaceAll('_', ' ').toUpperCase(),
//                           setState: setState,
//                         );
//                       }
                      
//                       // Regular text fields
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: TextField(
//                           controller: createControllers[field],
//                           decoration: InputDecoration(
//                             labelText: field.replaceAll('_', ' ').toUpperCase(),
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       );
//                     }).toList(),
                    
//                     // More Detail section
//                     _buildCreateMoreDetailsSection(setState: setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await createBuyer();
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

//   Widget _buildCreateFileAttachmentField({
//     required BuildContext context,
//     required String field,
//     required String label,
//     required StateSetter setState,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//             ),
//           ),
//           SizedBox(height: 4),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
//                     setState(() {});
//                   },
//                   icon: Icon(Icons.attach_file),
//                   label: Text(
//                     field == 'pan_attachment' 
//                       ? (panAttachmentFileName ?? 'Select PAN File')
//                       : (gstAttachmentFileName ?? 'Select GST File'),
//                   ),
//                 ),
//               ),
//               if ((field == 'pan_attachment' && panAttachmentFileName != null) ||
//                   (field == 'gst_attachment' && gstAttachmentFileName != null))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       if (field == 'pan_attachment') {
//                         panAttachmentFile = null;
//                         panAttachmentFileName = null;
//                       } else {
//                         gstAttachmentFile = null;
//                         gstAttachmentFileName = null;
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

//   Widget _buildCreateMoreDetailsSection({required StateSetter setState}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'MORE DETAILS',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             ElevatedButton.icon(
//               onPressed: () {
//                 setState(() {
//                   moreDetailControllers.add({
//                     'dummy_name': TextEditingController(),
//                     'dummy_email': TextEditingController(),
//                     'dummy_mobile': TextEditingController(),
//                   });
//                 });
//               },
//               icon: Icon(Icons.add, size: 20),
//               label: Text('Add'),
//             ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         // List of more details
//         ...moreDetailControllers.asMap().entries.map((entry) {
//           int index = entry.key;
//           Map<String, TextEditingController> controllers = entry.value;
          
//           return Card(
//             margin: EdgeInsets.symmetric(vertical: 5),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Detail ${index + 1}',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.delete, color: Colors.red),
//                         onPressed: () {
//                           setState(() {
//                             // Dispose controllers before removing
//                             controllers.forEach((key, controller) {
//                               controller.dispose();
//                             });
//                             moreDetailControllers.removeAt(index);
//                           });
//                         },
//                       ),
//                     ],
//                   ),
//                   TextField(
//                     controller: controllers['dummy_name'],
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   TextField(
//                     controller: controllers['dummy_email'],
//                     decoration: InputDecoration(
//                       labelText: 'Email',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   TextField(
//                     controller: controllers['dummy_mobile'],
//                     decoration: InputDecoration(
//                       labelText: 'Mobile',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ],
//     );
//   }

//   Future<void> pickFile(String type) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         if (type == 'pan') {
//           panAttachmentFile = File(file.path);
//           panAttachmentFileName = path.basename(file.path);
//         } else {
//           gstAttachmentFile = File(file.path);
//           gstAttachmentFileName = path.basename(file.path);
//         }
//       });
//     }
//   }

//   Future<void> createBuyer() async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse(createApiUrl),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role only (include bp_code)
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'more_detail' &&
//             key.toLowerCase() != 'role') {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add PAN attachment if selected
//       if (panAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'pan_attachment',
//             panAttachmentFile!.path,
//             filename: panAttachmentFileName,
//           ),
//         );
//       }

//       // Add GST attachment if selected
//       if (gstAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'gst_attachment',
//             gstAttachmentFile!.path,
//             filename: gstAttachmentFileName,
//           ),
//         );
//       }

//       // Add more_detail fields with array indexing
//       for (int i = 0; i < moreDetailControllers.length; i++) {
//         var controllers = moreDetailControllers[i];
//         String name = controllers['dummy_name']?.text.trim() ?? '';
//         String email = controllers['dummy_email']?.text.trim() ?? '';
//         String mobile = controllers['dummy_mobile']?.text.trim() ?? '';
        
//         // Only add if at least one field has data
//         if (name.isNotEmpty || email.isNotEmpty || mobile.isNotEmpty) {
//           request.fields['more_detail[$i][dummy_name]'] = name;
//           request.fields['more_detail[$i][dummy_email]'] = email;
//           request.fields['more_detail[$i][dummy_mobile]'] = mobile;
//         }
//       }

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 201) {
//         // Clear controllers after successful creation
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });
        
//         // Clear more detail controllers
//         for (var controllers in moreDetailControllers) {
//           controllers.forEach((key, controller) {
//             controller.clear();
//           });
//         }
//         moreDetailControllers.clear();
        
//         panAttachmentFile = null;
//         gstAttachmentFile = null;
//         panAttachmentFileName = null;
//         gstAttachmentFileName = null;
        
//         // Refresh the buyer list
//         fetchBuyers();
        
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Buyer created successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         // Read response body for error details
//         final responseBody = await response.stream.bytesToString();
        
//         // Show error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to create buyer. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
        
//         // Print error response for debugging
//         print('Error response: $responseBody');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       print('Exception: $e');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> updateBuyer(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('$updateApiUrl$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role only (include bp_code)
//       editControllers!.forEach((key, controller) {
//         if (key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'more_detail' &&
//             key.toLowerCase() != 'role') {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add PAN attachment if a new one is selected
//       if (panAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'pan_attachment',
//             panAttachmentFile!.path,
//             filename: panAttachmentFileName,
//           ),
//         );
//       }

//       // Add GST attachment if a new one is selected
//       if (gstAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'gst_attachment',
//             gstAttachmentFile!.path,
//             filename: gstAttachmentFileName,
//           ),
//         );
//       }

//       // Add more_detail fields with array indexing
//       if (editMoreDetailControllers != null) {
//         for (int i = 0; i < editMoreDetailControllers!.length; i++) {
//           var controllers = editMoreDetailControllers![i];
//           String name = controllers['dummy_name']?.text.trim() ?? '';
//           String email = controllers['dummy_email']?.text.trim() ?? '';
//           String mobile = controllers['dummy_mobile']?.text.trim() ?? '';
          
//           // Only add if at least one field has data
//           if (name.isNotEmpty || email.isNotEmpty || mobile.isNotEmpty) {
//             request.fields['more_detail[$i][dummy_name]'] = name;
//             request.fields['more_detail[$i][dummy_email]'] = email;
//             request.fields['more_detail[$i][dummy_mobile]'] = mobile;
//           }
//         }
//       }

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 200) {
//         // Clear edit controllers after successful update
//         editControllers = null;
//         editMoreDetailControllers = null;
//         editingBuyerId = null;
        
//         panAttachmentFile = null;
//         gstAttachmentFile = null;
//         panAttachmentFileName = null;
//         gstAttachmentFileName = null;
        
//         // Refresh the buyer list
//         fetchBuyers();
        
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Buyer updated successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         // Read response body for error details
//         final responseBody = await response.stream.bytesToString();
        
//         // Show error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to update buyer. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
        
//         // Print error response for debugging
//         print('Error response: $responseBody');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       print('Exception: $e');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedFields = getSelectedFields();
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
//           // Field Selection button (Group By)
//           IconButton(
//             icon: Icon(Icons.view_column),
//             onPressed: showFieldSelectionDialog,
//             tooltip: 'Select Fields',
//           ),
//           // Filter button
//           IconButton(
//             icon: Icon(Icons.filter_list),
//             onPressed: showFilterDialog,
//             tooltip: 'Filter',
//           ),
//           // Sort button
//           IconButton(
//             icon: Icon(Icons.sort),
//             onPressed: showSortDialog,
//             tooltip: 'Sort',
//           ),
//           // Refresh button
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () => fetchBuyers(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddBuyerDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add New'),
//             ),
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : buyers.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('No buyers found'),
//                       if (filterParams.length > 1) ...[
//                         SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: clearFilters,
//                           child: Text('Clear Filters'),
//                         ),
//                       ],
//                       if (sortBy != null) ...[
//                         SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: clearSort,
//                           child: Text('Clear Sort'),
//                         ),
//                       ]
//                     ],
//                   ),
//                 )
//               : Column(
//                   children: [
//                     // Show field selection summary
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       color: Colors.purple.shade50,
//                       child: Row(
//                         children: [
//                           Icon(Icons.view_column, size: 16, color: Colors.purple),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'Showing ${selectedFields.length} fields',
//                               style: TextStyle(fontSize: 12),
//                             ),
//                           ),
//                           TextButton.icon(
//                             onPressed: showFieldSelectionDialog,
//                             icon: Icon(Icons.edit, size: 14),
//                             label: Text('Change', style: TextStyle(fontSize: 12)),
//                             style: TextButton.styleFrom(
//                               padding: EdgeInsets.zero,
//                               minimumSize: Size(0, 0),
//                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     // Show active filters if any (excluding role)
//                     if (filterParams.length > 1)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.blue.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Filters: ${filterParams.entries.where((e) => e.key != 'role').map((e) => '${e.key}=${e.value}').join(', ')}',
//                                 style: TextStyle(fontSize: 12),
//                               ),
//                             ),
//                             IconButton(
//                               icon: Icon(Icons.close, size: 16),
//                               onPressed: clearFilters,
//                               padding: EdgeInsets.zero,
//                               constraints: BoxConstraints(),
//                             ),
//                           ],
//                         ),
//                       ),
                    
//                     // Show active sort if any
//                     if (sortBy != null)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.green.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.sort, size: 16, color: Colors.green),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Sort: ${sortBy?.replaceAll('_', ' ')} (${sortOrder ?? 'asc'})',
//                                 style: TextStyle(fontSize: 12),
//                               ),
//                             ),
//                             IconButton(
//                               icon: Icon(Icons.close, size: 16),
//                               onPressed: clearSort,
//                               padding: EdgeInsets.zero,
//                               constraints: BoxConstraints(),
//                             ),
//                             if (sortBy != null)
//                               IconButton(
//                                 icon: Icon(sortOrder == 'desc' 
//                                     ? Icons.arrow_downward 
//                                     : Icons.arrow_upward),
//                                 onPressed: toggleSortOrder,
//                                 padding: EdgeInsets.zero,
//                                 constraints: BoxConstraints(),
//                               ),
//                           ],
//                         ),
//                       ),
                    
//                     // Page size selector
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       child: Row(
//                         children: [
//                           Text('Page size:'),
//                           SizedBox(width: 8),
//                           DropdownButton<int>(
//                             value: pageSize,
//                             items: [10, 20, 50, 100].map((size) {
//                               return DropdownMenuItem(
//                                 value: size,
//                                 child: Text('$size'),
//                               );
//                             }).toList(),
//                             onChanged: (value) {
//                               if (value != null) {
//                                 changePageSize(value);
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     Expanded(
//                       child: Scrollbar(
//                         thumbVisibility: true,
//                         trackVisibility: true,
//                         thickness: 8,
//                         radius: Radius.circular(10),
//                         controller: _horizontalScrollController,
//                         child: SingleChildScrollView(
//                           controller: _horizontalScrollController,
//                           scrollDirection: Axis.horizontal,
//                           child: SingleChildScrollView(
//                             scrollDirection: Axis.vertical,
//                             child: DataTable(
//                               columnSpacing: compactRows ? 15 : 20,
//                               dataRowHeight: compactRows ? 40 : null,
//                               headingRowHeight: compactRows ? 45 : null,
//                               showCheckboxColumn: false,
//                               columns: [
//                                 DataColumn(label: Text('Select', style: TextStyle(fontSize: compactRows ? 12 : 14))),
//                                 DataColumn(label: Text('Actions', style: TextStyle(fontSize: compactRows ? 12 : 14))),
//                                 ...selectedFields.map((f) => DataColumn(
//                                       label: GestureDetector(
//                                         onTap: () {
//                                           // Quick sort by clicking column header
//                                           if (sortBy == f['key']) {
//                                             toggleSortOrder();
//                                           } else {
//                                             applySort(f['key'], 'asc');
//                                           }
//                                         },
//                                         child: Row(
//                                           children: [
//                                             Text(
//                                               f['label'].toUpperCase(),
//                                               style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                             ),
//                                             if (sortBy == f['key'])
//                                               Icon(
//                                                 sortOrder == 'desc' 
//                                                     ? Icons.arrow_downward 
//                                                     : Icons.arrow_upward,
//                                                 size: compactRows ? 14 : 16,
//                                               ),
//                                           ],
//                                         ),
//                                       ),
//                                     )),
//                               ],
//                               rows: buyers.map((buyer) {
//                                 final id = buyer['id'];
//                                 final isSelected = selectedIds.contains(id);

//                                 return DataRow(
//                                   color: activeRowHighlighting && isSelected
//                                       ? MaterialStateProperty.resolveWith<Color?>(
//                                           (Set<MaterialState> states) {
//                                             return Colors.blue.shade50;
//                                           },
//                                         )
//                                       : null,
//                                   cells: [
//                                     DataCell(
//                                       Checkbox(
//                                         value: isSelected,
//                                         onChanged: (v) {
//                                           setState(() {
//                                             if (v == true) {
//                                               // Clear all other selections and select only this one
//                                               selectedIds.clear();
//                                               selectedIds.add(id);
//                                             } else {
//                                               selectedIds.remove(id);
//                                             }
//                                           });
//                                         },
//                                       ),
//                                     ),

//                                     // ACTIONS - Show only if this row is selected
//                                     DataCell(
//                                       isSelected
//                                           ? Row(
//                                               children: [
//                                                 // Show View button only if enableView is true
//                                                 if (enableView)
//                                                   ElevatedButton(
//                                                     onPressed: () => fetchBuyerDetails(id),
//                                                     child: Text(
//                                                       'View',
//                                                       style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                     ),
//                                                     style: ElevatedButton.styleFrom(
//                                                       padding: EdgeInsets.symmetric(horizontal: 8),
//                                                     ),
//                                                   ),
                                                
//                                                 // Show Edit button only if enableEdit is true
//                                                 if (enableEdit) ...[
//                                                   if (enableView) SizedBox(width: 8),
//                                                   ElevatedButton(
//                                                     onPressed: () => showBuyerDialog(buyer, true),
//                                                     child: Text(
//                                                       'Edit',
//                                                       style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                     ),
//                                                     style: ElevatedButton.styleFrom(
//                                                       padding: EdgeInsets.symmetric(horizontal: 8),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ],
//                                             )
//                                           : SizedBox.shrink(), // Empty widget when not selected
//                                     ),

//                                     // Selected fields only
//                                     ...selectedFields.map((f) {
//                                       String displayValue = getFieldValue(buyer, f['key']);
                                      
//                                       // Special handling for map_location to make it tappable
//                                       if (f['key'] == 'map_location' && displayValue.isNotEmpty) {
//                                         return DataCell(
//                                           GestureDetector(
//                                             onTap: () {
//                                               // Open map link
//                                               final url = buyer['map_location'];
//                                               if (url != null && url.toString().isNotEmpty) {
//                                                 print('Open map: $url');
//                                               }
//                                             },
//                                             child: Container(
//                                               padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.blue.shade50,
//                                                 borderRadius: BorderRadius.circular(4),
//                                               ),
//                                               child: Text(
//                                                 displayValue,
//                                                 style: TextStyle(
//                                                   color: Colors.blue,
//                                                   decoration: TextDecoration.underline,
//                                                   fontSize: compactRows ? 11 : 13,
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         );
//                                       }
                                      
//                                       // Special handling for attachments
//                                       if (f['key'].contains('attachment') && displayValue.isNotEmpty) {
//                                         return DataCell(
//                                           GestureDetector(
//                                             onTap: () {
//                                               final url = buyer[f['key']];
//                                               print('Open attachment: $url');
//                                             },
//                                             child: Container(
//                                               padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                               decoration: BoxDecoration(
//                                                 color: modernCellColoring 
//                                                     ? Colors.purple.shade50 
//                                                     : Colors.orange.shade50,
//                                                 borderRadius: BorderRadius.circular(4),
//                                               ),
//                                               child: Row(
//                                                 mainAxisSize: MainAxisSize.min,
//                                                 children: [
//                                                   Icon(Icons.attachment, 
//                                                     size: compactRows ? 10 : 12, 
//                                                     color: modernCellColoring ? Colors.purple : Colors.orange
//                                                   ),
//                                                   SizedBox(width: 2),
//                                                   Text(
//                                                     displayValue,
//                                                     style: TextStyle(
//                                                       fontSize: compactRows ? 10 : 12,
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ),
//                                         );
//                                       }
                                      
//                                       // Special handling for more_detail
//                                       if (f['key'] == 'more_detail') {
//                                         final details = buyer['more_detail'];
//                                         if (details != null && details is List) {
//                                           return DataCell(
//                                             Container(
//                                               padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.green.shade50,
//                                                 borderRadius: BorderRadius.circular(4),
//                                               ),
//                                               child: Text(
//                                                 '${details.length} details',
//                                                 style: TextStyle(
//                                                   fontSize: compactRows ? 11 : 13,
//                                                   color: Colors.green.shade800,
//                                                 ),
//                                               ),
//                                             ),
//                                           );
//                                         }
//                                       }
                                      
//                                       return DataCell(
//                                         Container(
//                                           child: Text(
//                                             displayValue,
//                                             style: TextStyle(
//                                               fontSize: compactRows ? 11 : 13,
//                                               color: modernCellColoring && isSelected 
//                                                   ? Colors.blue 
//                                                   : null,
//                                             ),
//                                           ),
//                                         ),
//                                       );
//                                     }).toList(),
//                                   ],
//                                 );
//                               }).toList(),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),

//                     // Pagination controls
//                     Container(
//                       padding: EdgeInsets.all(compactRows ? 8 : 12),
//                       decoration: BoxDecoration(
//                         border: Border(
//                           top: BorderSide(color: Colors.grey.shade300),
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage of ${(totalCount / pageSize).ceil()} | Total: $totalCount',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: compactRows ? 11 : 13,
//                             ),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: (prevUrl == null || prevUrl!.isEmpty) 
//                                     ? null 
//                                     : loadPrevPage,
//                                 child: Text(
//                                   'Previous',
//                                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: (prevUrl == null || prevUrl!.isEmpty) 
//                                       ? Colors.grey 
//                                       : null,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: compactRows ? 8 : 16,
//                                     vertical: compactRows ? 4 : 8,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(width: compactRows ? 8 : 12),
//                               ElevatedButton(
//                                 onPressed: (nextUrl == null || nextUrl!.isEmpty) 
//                                     ? null 
//                                     : loadNextPage,
//                                 child: Text(
//                                   'Next',
//                                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: (nextUrl == null || nextUrl!.isEmpty) 
//                                       ? Colors.grey 
//                                       : null,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: compactRows ? 8 : 16,
//                                     vertical: compactRows ? 4 : 8,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           )
//                         ],
//                       ),
//                     )
//                   ],
//                 ),
//     );
//   }
// }



// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../services/auth_service.dart';
// import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {}; // Keep as Set for potential multi-select in future
//   String? token;
//   List<String> dynamicFields = [];

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
//   final String filterApiUrl = 'http://127.0.0.1:8000/user/BusinessPartner/filter/';
//   final String createApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/detail/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/';

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   int pageSize = 20; // Default page size from backend
  
//   // Filter and sort variables
//   Map<String, String> filterParams = {
//     'role': 'buyer', // Always filter by buyer role
//   };
//   String? sortBy;
//   String? sortOrder; // 'asc' or 'desc'
  
//   // Search query for field selection
//   String fieldSearchQuery = '';
  
//   // List settings variables
//   bool compactRows = false;
//   bool activeRowHighlighting = false;
//   bool modernCellColoring = false;
//   bool enableView = false;
//   bool enableEdit = false;
  
//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
//     {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
//     {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
//     {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
//     {'key': 'landline', 'label': 'Landline', 'selected': false, 'order': 4},
//     {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 5},
//     {'key': 'company_name', 'label': 'Company Name', 'selected': true, 'order': 6},
//     {'key': 'gst_number', 'label': 'GST Number', 'selected': true, 'order': 7},
//     {'key': 'refered_by', 'label': 'Referred By', 'selected': false, 'order': 8},
//     {'key': 'pan_name', 'label': 'PAN Name', 'selected': false, 'order': 9},
//     {'key': 'pan_no', 'label': 'PAN Number', 'selected': false, 'order': 10},
//     {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 11},
//     {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 12},
//     {'key': 'more', 'label': 'More Info', 'selected': false, 'order': 13},
//     {'key': 'more_detail', 'label': 'More Details', 'selected': false, 'isComplex': true, 'order': 14},
//     {'key': 'door_no', 'label': 'Door No', 'selected': false, 'order': 15},
//     {'key': 'shop_no', 'label': 'Shop No', 'selected': false, 'order': 16},
//     {'key': 'complex_name', 'label': 'Complex Name', 'selected': false, 'order': 17},
//     {'key': 'building_name', 'label': 'Building Name', 'selected': false, 'order': 18},
//     {'key': 'street_name', 'label': 'Street Name', 'selected': false, 'order': 19},
//     {'key': 'area', 'label': 'Area', 'selected': false, 'order': 20},
//     {'key': 'pincode', 'label': 'Pincode', 'selected': false, 'order': 21},
//     {'key': 'city', 'label': 'City', 'selected': false, 'order': 22},
//     {'key': 'state', 'label': 'State', 'selected': false, 'order': 23},
//     {'key': 'country', 'label': 'Country', 'selected': false, 'order': 24},
//     {'key': 'map_location', 'label': 'Map Location', 'selected': false, 'order': 25},
//     {'key': 'location_guide', 'label': 'Location Guide', 'selected': false, 'order': 26},
//   ];
  
//   // Filter field controllers
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController bpNameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController companyNameController = TextEditingController();
//   final TextEditingController landlineController = TextEditingController();
//   final TextEditingController gstNumberController = TextEditingController();

//   // For creating new buyer
//   final Map<String, TextEditingController> createControllers = {};
//   // Store more details as controllers for create
//   List<Map<String, TextEditingController>> moreDetailControllers = [];
  
//   // For editing existing buyer
//   Map<String, TextEditingController>? editControllers;
//   List<Map<String, TextEditingController>>? editMoreDetailControllers;
//   int? editingBuyerId;
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;

//   // Currently viewed buyer for detail view
//   Map<String, dynamic>? currentViewedBuyer;

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
//     bpNameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     companyNameController.dispose();
//     landlineController.dispose();
//     gstNumberController.dispose();
    
//     // Dispose all text controllers
//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });
    
//     // Dispose edit controllers if they exist
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose create more detail controllers
//     for (var controllers in moreDetailControllers) {
//       controllers.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose edit more detail controllers
//     if (editMoreDetailControllers != null) {
//       for (var controllers in editMoreDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('buyer_fields');
//     String? savedOrder = prefs.getString('buyer_field_order');
    
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
    
//     await prefs.setString('buyer_fields', json.encode(selections));
    
//     // Save field order
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('buyer_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     setState(() {
//       compactRows = prefs.getBool('buyer_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('buyer_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('buyer_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('buyer_enable_view') ?? false;
//       enableEdit = prefs.getBool('buyer_enable_edit') ?? false;
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
    
//     await prefs.setBool('buyer_compact_rows', compactRows);
//     await prefs.setBool('buyer_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('buyer_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('buyer_enable_view', enableView);
//     await prefs.setBool('buyer_enable_edit', enableEdit);
//   }

//   // Get selected fields for display in correct order
//   List<Map<String, dynamic>> getSelectedFields() {
//     return availableFields
//         .where((field) => field['selected'] == true)
//         .toList()
//         ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
//   }

//   // Toggle field selection
//   void toggleFieldSelection(String key) {
//     setState(() {
//       final index = availableFields.indexWhere((field) => field['key'] == key);
//       if (index != -1) {
//         availableFields[index]['selected'] = !availableFields[index]['selected'];
//       }
//     });
//   }

//   // Reset to default fields
//   void resetToDefaultFields() {
//     setState(() {
//       // Reset selection and order
//       List<Map<String, dynamic>> defaultFields = [
//         {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//         {'key': 'business_name', 'label': 'Business Name', 'selected': true},
//         {'key': 'name', 'label': 'Name', 'selected': true},
//         {'key': 'mobile', 'label': 'Mobile', 'selected': true},
//         {'key': 'business_email', 'label': 'Email', 'selected': true},
//         {'key': 'company_name', 'label': 'Company Name', 'selected': true},
//         {'key': 'gst_number', 'label': 'GST Number', 'selected': true},
//         {'key': 'landline', 'label': 'Landline', 'selected': false},
//         {'key': 'refered_by', 'label': 'Referred By', 'selected': false},
//         {'key': 'pan_name', 'label': 'PAN Name', 'selected': false},
//         {'key': 'pan_no', 'label': 'PAN Number', 'selected': false},
//         {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
//         {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
//         {'key': 'more', 'label': 'More Info', 'selected': false},
//         {'key': 'more_detail', 'label': 'More Details', 'selected': false, 'isComplex': true},
//         {'key': 'door_no', 'label': 'Door No', 'selected': false},
//         {'key': 'shop_no', 'label': 'Shop No', 'selected': false},
//         {'key': 'complex_name', 'label': 'Complex Name', 'selected': false},
//         {'key': 'building_name', 'label': 'Building Name', 'selected': false},
//         {'key': 'street_name', 'label': 'Street Name', 'selected': false},
//         {'key': 'area', 'label': 'Area', 'selected': false},
//         {'key': 'pincode', 'label': 'Pincode', 'selected': false},
//         {'key': 'city', 'label': 'City', 'selected': false},
//         {'key': 'state', 'label': 'State', 'selected': false},
//         {'key': 'country', 'label': 'Country', 'selected': false},
//         {'key': 'map_location', 'label': 'Map Location', 'selected': false},
//         {'key': 'location_guide', 'label': 'Location Guide', 'selected': false},
//       ];
      
//       // Update existing fields while preserving additional properties
//       for (int i = 0; i < defaultFields.length; i++) {
//         final defaultField = defaultFields[i];
//         final existingIndex = availableFields.indexWhere((f) => f['key'] == defaultField['key']);
//         if (existingIndex != -1) {
//           availableFields[existingIndex]['selected'] = defaultField['selected'];
//           availableFields[existingIndex]['order'] = i;
//         }
//       }
//     });
    
//     // Save selections to SharedPreferences
//     saveFieldSelections();
    
//     // Show a snackbar to confirm reset
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Fields reset to default'),
//         duration: Duration(seconds: 2),
//       ),
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
//                         .toLowerCase()
//                         .contains(fieldSearchQuery.toLowerCase()) ||
//                         field['key']
//                         .toLowerCase()
//                         .contains(fieldSearchQuery.toLowerCase());
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
//                             'Personalize List Columns - Buyers',
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
//                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
//                                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
//                                             itemCount: filteredAvailableFields.length,
//                                             itemBuilder: (context, index) {
//                                               final field = filteredAvailableFields[index];
//                                               return ListTile(
//                                                 dense: true,
//                                                 title: Text(
//                                                   field['label'],
//                                                   style: TextStyle(fontSize: 14),
//                                                 ),
//                                                 subtitle: field['isComplex'] == true 
//                                                     ? Text('Complex field', style: TextStyle(fontSize: 11, color: Colors.grey))
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
//                                                     availableFieldsList.removeWhere((f) => f['key'] == field['key']);
//                                                     selectedFieldsList.add(field);
//                                                     selectedFieldIndex = selectedFieldsList.length - 1;
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
//                                           for (var field in filteredAvailableFields.toList()) {
//                                             field['selected'] = true;
//                                             availableFieldsList.removeWhere((f) => f['key'] == field['key']);
//                                             selectedFieldsList.add(field);
//                                           }
//                                           if (selectedFieldsList.isNotEmpty) {
//                                             selectedFieldIndex = selectedFieldsList.length - 1;
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
//                                           for (var field in selectedFieldsList.toList()) {
//                                             field['selected'] = false;
//                                             selectedFieldsList.removeWhere((f) => f['key'] == field['key']);
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
//                                   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
//                                                   for (var field in selectedFieldsList.toList()) {
//                                                     field['selected'] = false;
//                                                   }
//                                                   availableFieldsList.addAll(selectedFieldsList);
//                                                   selectedFieldsList.clear();
//                                                   selectedFieldIndex = -1;
//                                                 });
//                                               },
//                                               style: TextButton.styleFrom(
//                                                 padding: EdgeInsets.zero,
//                                                 minimumSize: Size(0, 0),
//                                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                                               ),
//                                               child: Text(
//                                                 'Remove all',
//                                                 style: TextStyle(fontSize: 12, color: Colors.red),
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
//                                                     fontWeight: selectedFieldIndex == index 
//                                                         ? FontWeight.bold 
//                                                         : FontWeight.w500,
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
//                                                       selectedFieldsList.removeAt(index);
//                                                       availableFieldsList.add(field);
//                                                       if (selectedFieldIndex >= selectedFieldsList.length) {
//                                                         selectedFieldIndex = selectedFieldsList.length - 1;
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
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         IconButton(
//                                           icon: Icon(Icons.arrow_upward, color: Colors.blue),
//                                           onPressed: selectedFieldIndex > 0
//                                               ? () {
//                                                   setState(() {
//                                                     // Move selected field up
//                                                     final field = selectedFieldsList.removeAt(selectedFieldIndex);
//                                                     selectedFieldsList.insert(selectedFieldIndex - 1, field);
//                                                     selectedFieldIndex = selectedFieldIndex - 1;
//                                                   });
//                                                 }
//                                               : null,
//                                         ),
//                                         SizedBox(width: 30),
//                                         IconButton(
//                                           icon: Icon(Icons.arrow_downward, color: Colors.blue),
//                                           onPressed: selectedFieldIndex < selectedFieldsList.length - 1
//                                               ? () {
//                                                   setState(() {
//                                                     // Move selected field down
//                                                     final field = selectedFieldsList.removeAt(selectedFieldIndex);
//                                                     selectedFieldsList.insert(selectedFieldIndex + 1, field);
//                                                     selectedFieldIndex = selectedFieldIndex + 1;
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
//                           // Second row of checkboxes
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
//                               Text('Enable view'),
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
//                               Text('Enable edit'),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     // Footer with Reset button and metadata
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'business_name', 'label': 'Business Name', 'selected': true},
//                                   {'key': 'name', 'label': 'Name', 'selected': true},
//                                   {'key': 'mobile', 'label': 'Mobile', 'selected': true},
//                                   {'key': 'business_email', 'label': 'Email', 'selected': true},
//                                   {'key': 'company_name', 'label': 'Company Name', 'selected': true},
//                                   {'key': 'gst_number', 'label': 'GST Number', 'selected': true},
//                                 ];
                                
//                                 for (var field in availableFields) {
//                                   bool isDefaultSelected = defaultFields.any((df) => df['key'] == field['key']);
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
//                                 localEnableView = false;
//                                 localEnableEdit = false;
                                
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
//                                 'Buyers - Field Selection',
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
//                                 for (int i = 0; i < selectedFieldsList.length; i++) {
//                                   final selectedField = selectedFieldsList[i];
//                                   final index = availableFields.indexWhere(
//                                     (f) => f['key'] == selectedField['key']
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
//                                   (a['order'] ?? 0).compareTo(b['order'] ?? 0)
//                                 );
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

//   // Format complex field for display
//   String formatComplexField(dynamic value) {
//     if (value == null) return '';
//     if (value is List) {
//       if (value.isEmpty) return '[]';
//       if (value.length > 1) {
//         return '[${value.length} items]';
//       } else {
//         // Show first item summary
//         final firstItem = value.first;
//         if (firstItem is Map) {
//           final name = firstItem['dummy_name'] ?? '';
//           final email = firstItem['dummy_email'] ?? '';
//           return '$name, $email';
//         }
//       }
//     }
//     return value.toString();
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> buyer, String key) {
//     final value = buyer[key];
    
//     if (value == null) return '';
    
//     // Handle complex fields
//     if (key == 'more_detail' && value is List) {
//       return formatComplexField(value);
//     }
    
//     // Handle map location - show as link text
//     if (key == 'map_location' && value.toString().isNotEmpty) {
//       return '📍 Map Link';
//     }
    
//     // Handle attachments
//     if (key.contains('attachment') && value.toString().isNotEmpty) {
//       return '📎 Attachment';
//     }
    
//     return value.toString();
//   }

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchBuyers();
//   }

//   // Helper method to safely get int from dynamic value
//   int safeParseInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is double) return value.toInt();
//     if (value is String) return int.tryParse(value) ?? 0;
//     return 0;
//   }

//   // Build URL with filter and sort parameters
//   String buildRequestUrl({String? baseUrl}) {
//     // Start with base filter URL
//     String url = filterApiUrl;
    
//     // Build query parameters
//     Map<String, String> queryParams = {};
    
//     // Add role filter (always present)
//     queryParams['role'] = 'buyer';
    
//     // Add additional filter parameters from filterParams
//     filterParams.forEach((key, value) {
//       if (key != 'role' && value.isNotEmpty) {
//         queryParams[key] = value;
//       }
//     });
    
//     // Add sort parameters if set
//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
      
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }
    
//     // Add pagination parameters
//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
    
//     // Add page number for pagination if not first page
//     if (currentPage > 1) {
//       queryParams['page'] = currentPage.toString();
//     }
    
//     // Build URI with query parameters
//     Uri uri = Uri.parse(url);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Use provided URL for pagination, otherwise build URL with filters
//       final requestUrl = url ?? buildRequestUrl();
      
//       print('Fetching: $requestUrl'); // For debugging
      
//       final response = await http.get(
//         Uri.parse(requestUrl),
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           // Include bp_code in dynamic fields to make it visible
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id' && k.toLowerCase() != 'role')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = safeParseInt(data['count']);
          
//           // Calculate current page from URL if possible
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
//         print('Error response: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   // Fetch single buyer details
//   Future<void> fetchBuyerDetails(int id) async {
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
//           currentViewedBuyer = data;
//           isLoading = false;
//         });
        
//         // Show detail dialog with fetched data
//         showBuyerDetailDialog();
//       } else {
//         print('Error fetching details: ${response.statusCode}');
//         setState(() => isLoading = false);
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to fetch buyer details'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       print('Exception fetching details: $e');
//       setState(() => isLoading = false);
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   // Apply all filters at once
//   Future<void> applyFilters() async {
//     // Clear existing filter params but keep role
//     filterParams.clear();
//     filterParams['role'] = 'buyer';
    
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (bpNameController.text.isNotEmpty) {
//       filterParams['name'] = bpNameController.text;
//     }
//     if (emailController.text.isNotEmpty) {
//       filterParams['business_email'] = emailController.text;
//     }
//     if (phoneController.text.isNotEmpty) {
//       filterParams['mobile'] = phoneController.text;
//     }
//     if (companyNameController.text.isNotEmpty) {
//       filterParams['company_name'] = companyNameController.text;
//     }
//     if (landlineController.text.isNotEmpty) {
//       filterParams['landline'] = landlineController.text;
//     }
//     if (gstNumberController.text.isNotEmpty) {
//       filterParams['gst_number'] = gstNumberController.text;
//     }
    
//     // Reset to first page when applying filters
//     currentPage = 1;
//     await fetchBuyers();
//   }

//   // Clear all filters
//   Future<void> clearFilters() async {
//     filterParams.clear();
//     filterParams['role'] = 'buyer'; // Keep role filter
    
//     bpCodeController.clear();
//     bpNameController.clear();
//     emailController.clear();
//     phoneController.clear();
//     companyNameController.clear();
//     landlineController.clear();
//     gstNumberController.clear();
    
//     await fetchBuyers();
//   }

//   // Show filter dialog
//   void showFilterDialog() {
//     // Initialize controllers with current filter values
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     bpNameController.text = filterParams['name'] ?? '';
//     emailController.text = filterParams['business_email'] ?? '';
//     phoneController.text = filterParams['mobile'] ?? '';
//     companyNameController.text = filterParams['company_name'] ?? '';
//     landlineController.text = filterParams['landline'] ?? '';
//     gstNumberController.text = filterParams['gst_number'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Filter Buyers'),
//           content: Container(
//             width: double.maxFinite,
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField(
//                     controller: bpCodeController,
//                     decoration: InputDecoration(
//                       labelText: 'BP Code',
//                       hintText: 'e.g., BV009',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.code),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: bpNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.person),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: emailController,
//                     decoration: InputDecoration(
//                       labelText: 'Email',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.email),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: phoneController,
//                     decoration: InputDecoration(
//                       labelText: 'Phone',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: companyNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Company Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.business),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: landlineController,
//                     decoration: InputDecoration(
//                       labelText: 'LandLine',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.call),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: gstNumberController,
//                     decoration: InputDecoration(
//                       labelText: 'GST Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.numbers),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 clearFilters();
//               },
//               child: Text('Clear All'),
//             ),
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 applyFilters();
//               },
//               child: Text('Apply Filters'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // Apply sort
//   Future<void> applySort(String field, String order) async {
//     print('Applying sort: $field, $order'); // Debug print
    
//     setState(() {
//       sortBy = field;
//       sortOrder = order;
//     });
    
//     // Reset to first page when sorting
//     currentPage = 1;
//     await fetchBuyers();
//   }

//   // Clear sort
//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchBuyers();
//   }

//   // Toggle sort order
//   void toggleSortOrder() {
//     if (sortBy == null) return;
    
//     String newOrder;
//     if (sortOrder == null || sortOrder == 'asc') {
//       newOrder = 'desc';
//     } else {
//       newOrder = 'asc';
//     }
    
//     applySort(sortBy!, newOrder);
//   }

//   // Show sort options
//   void showSortDialog() {
//     List<Map<String, String>> sortFields = [
//       {'value': 'bp_code', 'label': 'BP Code'},
//       {'value': 'name', 'label': 'Name'},
//       {'value': 'business_name', 'label': 'Business Name'},
//       {'value': 'business_email', 'label': 'Email'},
//       {'value': 'mobile', 'label': 'Phone'},
//       {'value': 'company_name', 'label': 'Company Name'},
//       {'value': 'landline', 'label': 'LandLine'},
//       {'value': 'gst_number', 'label': 'GST Number'},
//       {'value': 'created_at', 'label': 'Created Date'},
//       {'value': 'id', 'label': 'ID'},
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
//                       // Sort field selection
//                       ...sortFields.map((field) {
//                         return RadioListTile<String>(
//                           title: Text(field['label']!),
//                           value: field['value']!,
//                           groupValue: sortBy,
//                           onChanged: (value) {
//                             setState(() {
//                               this.sortBy = value;
//                               // Set default sort order if not set
//                               if (sortOrder == null) {
//                                 sortOrder = 'asc';
//                               }
//                             });
//                           },
//                           secondary: sortBy == field['value'] ? IconButton(
//                             icon: Icon(sortOrder == 'desc' 
//                                 ? Icons.arrow_downward 
//                                 : Icons.arrow_upward),
//                             onPressed: () {
//                               setState(() {
//                                 sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
//                               });
//                             },
//                           ) : null,
//                         );
//                       }).toList(),
                      
//                       SizedBox(height: 16),
                      
//                       // Sort order selection
//                       if (sortBy != null)
//                         Container(
//                           padding: EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade300),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Sort Order:', 
//                                 style: TextStyle(fontWeight: FontWeight.bold)),
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
//                       // Ensure sortOrder is set
//                       if (sortOrder == null) {
//                         sortOrder = 'asc';
//                       }
//                       fetchBuyers();
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

//   // Pagination methods
//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   // Change page size
//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
    
//     await fetchBuyers();
//   }

//   // Show buyer detail dialog using fetched data
//   void showBuyerDetailDialog() {
//     if (currentViewedBuyer == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Buyer Details'),
//         content: Container(
//           width: double.maxFinite,
//           constraints: BoxConstraints(
//             maxHeight: MediaQuery.of(context).size.height * 0.7,
//           ),
//           child: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // Include all fields including bp_code
//                 ...currentViewedBuyer!.entries.where((entry) {
//                   String key = entry.key;
//                   return key.toLowerCase() != 'id' && key != 'more_detail';
//                 }).map((entry) {
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 4),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         SizedBox(
//                           width: 120,
//                           child: Text(
//                             '${entry.key.replaceAll('_', ' ')}:',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: _buildDetailValue(entry.key, entry.value),
//                         ),
//                       ],
//                     ),
//                   );
//                 }).toList(),
                
//                 // More Detail section
//                 if (currentViewedBuyer!['more_detail'] != null)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'MORE DETAILS',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                         SizedBox(height: 8),
//                         ...List<Map<String, dynamic>>.from(currentViewedBuyer!['more_detail']).asMap().entries.map((entry) {
//                           int index = entry.key;
//                           Map<String, dynamic> detail = entry.value;
                          
//                           return Card(
//                             margin: EdgeInsets.symmetric(vertical: 4),
//                             child: Padding(
//                               padding: const EdgeInsets.all(8.0),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text('Detail ${index + 1}', 
//                                     style: TextStyle(fontWeight: FontWeight.bold)),
//                                   SizedBox(height: 4),
//                                   Text('Name: ${detail['dummy_name'] ?? ''}'),
//                                   Text('Email: ${detail['dummy_email'] ?? ''}'),
//                                   Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                                 ],
//                               ),
//                             ),
//                           );
//                         }).toList(),
//                       ],
//                     ),
//                   ),
//               ],
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

//   // Helper to build detail value with proper formatting
//   Widget _buildDetailValue(String key, dynamic value) {
//     if (key == 'pan_attachment' || key == 'gst_attachment') {
//       if (value != null && value.toString().isNotEmpty) {
//         return InkWell(
//           onTap: () {
//             // Open file URL
//             print('Open: $value');
//           },
//           child: Text(
//             'View File',
//             style: TextStyle(
//               color: Colors.blue,
//               decoration: TextDecoration.underline,
//             ),
//           ),
//         );
//       }
//       return Text('No file');
//     }
    
//     if (value == null) return Text('');
//     if (value is bool) return Text(value.toString());
//     if (value is Map || value is List) return Text(value.toString());
//     return Text(value.toString());
//   }

//   // Show buyer dialog with scrollable content (for view/edit)
//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     // If editing, initialize controllers with buyer data
//     if (isEdit) {
//       editingBuyerId = buyer['id'];
//       editControllers = {};
      
//       // Initialize all field controllers except id and role (include bp_code for editing)
//       for (var field in buyer.keys) {
//         if (field.toLowerCase() != 'id' && 
//             field.toLowerCase() != 'role' &&
//             field != 'more_detail') {
//           editControllers![field] = TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           );
//         }
//       }
      
//       // Initialize more detail controllers with existing data
//       editMoreDetailControllers = [];
//       if (buyer['more_detail'] != null && buyer['more_detail'] is List) {
//         List<Map<String, dynamic>> existingMoreDetails = 
//             List<Map<String, dynamic>>.from(buyer['more_detail']);
        
//         for (var detail in existingMoreDetails) {
//           editMoreDetailControllers!.add({
//             'dummy_name': TextEditingController(text: detail['dummy_name']?.toString() ?? ''),
//             'dummy_email': TextEditingController(text: detail['dummy_email']?.toString() ?? ''),
//             'dummy_mobile': TextEditingController(text: detail['dummy_mobile']?.toString() ?? ''),
//           });
//         }
//       }
      
//       // Reset file selections for edit
//       panAttachmentFile = null;
//       gstAttachmentFile = null;
//       panAttachmentFileName = null;
//       gstAttachmentFileName = null;
//     }

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Show all fields except 'id', 'role', and 'more_detail' (include bp_code)
//                     ...buyer.entries.where((entry) {
//                       String key = entry.key;
//                       return key.toLowerCase() != 'id' && 
//                              key.toLowerCase() != 'role' &&
//                              key != 'more_detail';
//                     }).map((entry) {
//                       // Check if this is a file attachment field
//                       if (entry.key == 'pan_attachment' || entry.key == 'gst_attachment') {
//                         return _buildFileAttachmentField(
//                           context: context,
//                           field: entry.key,
//                           label: entry.key.replaceAll('_', ' ').toUpperCase(),
//                           buyer: buyer,
//                           isEdit: isEdit,
//                           setState: setState,
//                         );
//                       }
                      
//                       // For edit mode, use editControllers
//                       if (isEdit && editControllers != null && editControllers!.containsKey(entry.key)) {
//                         return _buildTextField(
//                           context: context,
//                           field: entry.key,
//                           controller: editControllers![entry.key],
//                           buyer: buyer,
//                           isEdit: isEdit,
//                           setState: setState,
//                         );
//                       } else {
//                         // For view mode, show the value
//                         return _buildTextField(
//                           context: context,
//                           field: entry.key,
//                           value: entry.value?.toString() ?? '',
//                           buyer: buyer,
//                           isEdit: isEdit,
//                           setState: setState,
//                         );
//                       }
//                     }).toList(),
                    
//                     // More Detail section
//                     _buildMoreDetailsSection(
//                       buyer: buyer,
//                       isEdit: isEdit,
//                       setState: setState,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               if (isEdit)
//                 ElevatedButton(
//                   onPressed: () async {
//                     await updateBuyer(editingBuyerId!);
//                     Navigator.pop(context);
//                   },
//                   child: Text('Save'),
//                 ),
//               TextButton(
//                 onPressed: () {
//                   // Clean up edit controllers when closing dialog
//                   if (isEdit) {
//                     editControllers = null;
//                     editMoreDetailControllers = null;
//                     editingBuyerId = null;
//                     panAttachmentFile = null;
//                     gstAttachmentFile = null;
//                     panAttachmentFileName = null;
//                     gstAttachmentFileName = null;
//                   }
//                   Navigator.pop(context);
//                 },
//                 child: Text(isEdit ? 'Cancel' : 'Close'),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required BuildContext context,
//     required String field,
//     TextEditingController? controller,
//     String? value,
//     required Map<String, dynamic> buyer,
//     required bool isEdit,
//     required StateSetter setState,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: controller,
//         readOnly: !isEdit,
//         decoration: InputDecoration(
//           labelText: field.replaceAll('_', ' ').toUpperCase(),
//           border: OutlineInputBorder(),
//         ),
//       ),
//     );
//   }

//   Widget _buildFileAttachmentField({
//     required BuildContext context,
//     required String field,
//     required String label,
//     required Map<String, dynamic> buyer,
//     required bool isEdit,
//     required StateSetter setState,
//   }) {
//     String? fileUrl = buyer[field];
    
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//             ),
//           ),
//           SizedBox(height: 4),
//           if (fileUrl != null && fileUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     // Open file in browser or show preview
//                     print('File URL: $fileUrl');
//                   },
//                   child: Text(
//                     'View Existing Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ),
//                 if (isEdit)
//                   SizedBox(height: 8),
//               ],
//             )
//           else
//             Text('No attachment'),
          
//           // File upload for edit mode
//           if (isEdit)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton.icon(
//                         onPressed: () async {
//                         await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
//                         setState(() {});
//                       },
//                         icon: Icon(Icons.attach_file),
//                         label: Text(
//                           field == 'pan_attachment' 
//                             ? (panAttachmentFileName ?? 'Select New PAN File')
//                             : (gstAttachmentFileName ?? 'Select New GST File'),
//                         ),
//                       ),
//                     ),
//                     if ((field == 'pan_attachment' && panAttachmentFileName != null) ||
//                         (field == 'gst_attachment' && gstAttachmentFileName != null))
//                       IconButton(
//                         icon: Icon(Icons.clear),
//                         onPressed: () {
//                           setState(() {
//                             if (field == 'pan_attachment') {
//                               panAttachmentFile = null;
//                               panAttachmentFileName = null;
//                             } else {
//                               gstAttachmentFile = null;
//                               gstAttachmentFileName = null;
//                             }
//                           });
//                         },
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMoreDetailsSection({
//     required Map<String, dynamic> buyer,
//     required bool isEdit,
//     required StateSetter setState,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'MORE DETAILS',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             if (isEdit)
//               ElevatedButton.icon(
//                 onPressed: () {
//                   setState(() {
//                     if (editMoreDetailControllers == null) {
//                       editMoreDetailControllers = [];
//                     }
//                     editMoreDetailControllers!.add({
//                       'dummy_name': TextEditingController(),
//                       'dummy_email': TextEditingController(),
//                       'dummy_mobile': TextEditingController(),
//                     });
//                   });
//                 },
//                 icon: Icon(Icons.add, size: 20),
//                 label: Text('Add'),
//               ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         // List of more details
//         if (isEdit && editMoreDetailControllers != null)
//           ...editMoreDetailControllers!.asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, TextEditingController> controllers = entry.value;
            
//             return Card(
//               margin: EdgeInsets.symmetric(vertical: 5),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Detail ${index + 1}',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           onPressed: () {
//                             setState(() {
//                               // Dispose controllers before removing
//                               controllers.forEach((key, controller) {
//                                 controller.dispose();
//                               });
//                               editMoreDetailControllers!.removeAt(index);
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                     TextField(
//                       controller: controllers['dummy_name'],
//                       decoration: InputDecoration(
//                         labelText: 'Name',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     TextField(
//                       controller: controllers['dummy_email'],
//                       decoration: InputDecoration(
//                         labelText: 'Email',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     TextField(
//                       controller: controllers['dummy_mobile'],
//                       decoration: InputDecoration(
//                         labelText: 'Mobile',
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList()
//         else if (!isEdit && buyer['more_detail'] != null && buyer['more_detail'] is List)
//           ...List<Map<String, dynamic>>.from(buyer['more_detail']).asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, dynamic> detail = entry.value;
            
//             return Card(
//               margin: EdgeInsets.symmetric(vertical: 5),
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Detail ${index + 1}', style: TextStyle(fontWeight: FontWeight.bold)),
//                     SizedBox(height: 4),
//                     Text('Name: ${detail['dummy_name'] ?? ''}'),
//                     Text('Email: ${detail['dummy_email'] ?? ''}'),
//                     Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//       ],
//     );
//   }

//   // Show add buyer dialog with scrollable content
//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields (excluding role only, include bp_code)
//     for (var field in dynamicFields) {
//       if (field.toLowerCase() != 'role' && 
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }
    
//     // Initialize moreDetails controllers
//     moreDetailControllers = [];
//     // Reset file selections
//     panAttachmentFile = null;
//     gstAttachmentFile = null;
//     panAttachmentFileName = null;
//     gstAttachmentFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Buyer'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     // Main fields - exclude role only (include bp_code)
//                     ...dynamicFields.where((field) => 
//                       field.toLowerCase() != 'role' && 
//                       field != 'more_detail'
//                     ).map((field) {
//                       if (!createControllers.containsKey(field)) {
//                         createControllers[field] = TextEditingController();
//                       }
                      
//                       // Check if this is a file attachment field
//                       if (field == 'pan_attachment' || field == 'gst_attachment') {
//                         return _buildCreateFileAttachmentField(
//                           context: context,
//                           field: field,
//                           label: field.replaceAll('_', ' ').toUpperCase(),
//                           setState: setState,
//                         );
//                       }
                      
//                       // Regular text fields
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: TextField(
//                           controller: createControllers[field],
//                           decoration: InputDecoration(
//                             labelText: field.replaceAll('_', ' ').toUpperCase(),
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       );
//                     }).toList(),
                    
//                     // More Detail section
//                     _buildCreateMoreDetailsSection(setState: setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await createBuyer();
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

//   Widget _buildCreateFileAttachmentField({
//     required BuildContext context,
//     required String field,
//     required String label,
//     required StateSetter setState,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               fontSize: 12,
//             ),
//           ),
//           SizedBox(height: 4),
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
//                     setState(() {});
//                   },
//                   icon: Icon(Icons.attach_file),
//                   label: Text(
//                     field == 'pan_attachment' 
//                       ? (panAttachmentFileName ?? 'Select PAN File')
//                       : (gstAttachmentFileName ?? 'Select GST File'),
//                   ),
//                 ),
//               ),
//               if ((field == 'pan_attachment' && panAttachmentFileName != null) ||
//                   (field == 'gst_attachment' && gstAttachmentFileName != null))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       if (field == 'pan_attachment') {
//                         panAttachmentFile = null;
//                         panAttachmentFileName = null;
//                       } else {
//                         gstAttachmentFile = null;
//                         gstAttachmentFileName = null;
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

//   Widget _buildCreateMoreDetailsSection({required StateSetter setState}) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'MORE DETAILS',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             ElevatedButton.icon(
//               onPressed: () {
//                 setState(() {
//                   moreDetailControllers.add({
//                     'dummy_name': TextEditingController(),
//                     'dummy_email': TextEditingController(),
//                     'dummy_mobile': TextEditingController(),
//                   });
//                 });
//               },
//               icon: Icon(Icons.add, size: 20),
//               label: Text('Add'),
//             ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         // List of more details
//         ...moreDetailControllers.asMap().entries.map((entry) {
//           int index = entry.key;
//           Map<String, TextEditingController> controllers = entry.value;
          
//           return Card(
//             margin: EdgeInsets.symmetric(vertical: 5),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         'Detail ${index + 1}',
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       IconButton(
//                         icon: Icon(Icons.delete, color: Colors.red),
//                         onPressed: () {
//                           setState(() {
//                             // Dispose controllers before removing
//                             controllers.forEach((key, controller) {
//                               controller.dispose();
//                             });
//                             moreDetailControllers.removeAt(index);
//                           });
//                         },
//                       ),
//                     ],
//                   ),
//                   TextField(
//                     controller: controllers['dummy_name'],
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   TextField(
//                     controller: controllers['dummy_email'],
//                     decoration: InputDecoration(
//                       labelText: 'Email',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                   SizedBox(height: 8),
//                   TextField(
//                     controller: controllers['dummy_mobile'],
//                     decoration: InputDecoration(
//                       labelText: 'Mobile',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ],
//     );
//   }

//   Future<void> pickFile(String type) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         if (type == 'pan') {
//           panAttachmentFile = File(file.path);
//           panAttachmentFileName = path.basename(file.path);
//         } else {
//           gstAttachmentFile = File(file.path);
//           gstAttachmentFileName = path.basename(file.path);
//         }
//       });
//     }
//   }

//   Future<void> createBuyer() async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'POST',
//         Uri.parse(createApiUrl),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role only (include bp_code)
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'more_detail' &&
//             key.toLowerCase() != 'role') {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add PAN attachment if selected
//       if (panAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'pan_attachment',
//             panAttachmentFile!.path,
//             filename: panAttachmentFileName,
//           ),
//         );
//       }

//       // Add GST attachment if selected
//       if (gstAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'gst_attachment',
//             gstAttachmentFile!.path,
//             filename: gstAttachmentFileName,
//           ),
//         );
//       }

//       // Add more_detail fields with array indexing
//       for (int i = 0; i < moreDetailControllers.length; i++) {
//         var controllers = moreDetailControllers[i];
//         String name = controllers['dummy_name']?.text.trim() ?? '';
//         String email = controllers['dummy_email']?.text.trim() ?? '';
//         String mobile = controllers['dummy_mobile']?.text.trim() ?? '';
        
//         // Only add if at least one field has data
//         if (name.isNotEmpty || email.isNotEmpty || mobile.isNotEmpty) {
//           request.fields['more_detail[$i][dummy_name]'] = name;
//           request.fields['more_detail[$i][dummy_email]'] = email;
//           request.fields['more_detail[$i][dummy_mobile]'] = mobile;
//         }
//       }

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 201) {
//         // Clear controllers after successful creation
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });
        
//         // Clear more detail controllers
//         for (var controllers in moreDetailControllers) {
//           controllers.forEach((key, controller) {
//             controller.clear();
//           });
//         }
//         moreDetailControllers.clear();
        
//         panAttachmentFile = null;
//         gstAttachmentFile = null;
//         panAttachmentFileName = null;
//         gstAttachmentFileName = null;
        
//         // Refresh the buyer list
//         fetchBuyers();
        
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Buyer created successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         // Read response body for error details
//         final responseBody = await response.stream.bytesToString();
        
//         // Show error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to create buyer. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
        
//         // Print error response for debugging
//         print('Error response: $responseBody');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       print('Exception: $e');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> updateBuyer(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('$updateApiUrl$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role only (include bp_code)
//       editControllers!.forEach((key, controller) {
//         if (key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'more_detail' &&
//             key.toLowerCase() != 'role') {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add PAN attachment if a new one is selected
//       if (panAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'pan_attachment',
//             panAttachmentFile!.path,
//             filename: panAttachmentFileName,
//           ),
//         );
//       }

//       // Add GST attachment if a new one is selected
//       if (gstAttachmentFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'gst_attachment',
//             gstAttachmentFile!.path,
//             filename: gstAttachmentFileName,
//           ),
//         );
//       }

//       // Add more_detail fields with array indexing
//       if (editMoreDetailControllers != null) {
//         for (int i = 0; i < editMoreDetailControllers!.length; i++) {
//           var controllers = editMoreDetailControllers![i];
//           String name = controllers['dummy_name']?.text.trim() ?? '';
//           String email = controllers['dummy_email']?.text.trim() ?? '';
//           String mobile = controllers['dummy_mobile']?.text.trim() ?? '';
          
//           // Only add if at least one field has data
//           if (name.isNotEmpty || email.isNotEmpty || mobile.isNotEmpty) {
//             request.fields['more_detail[$i][dummy_name]'] = name;
//             request.fields['more_detail[$i][dummy_email]'] = email;
//             request.fields['more_detail[$i][dummy_mobile]'] = mobile;
//           }
//         }
//       }

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 200) {
//         // Clear edit controllers after successful update
//         editControllers = null;
//         editMoreDetailControllers = null;
//         editingBuyerId = null;
        
//         panAttachmentFile = null;
//         gstAttachmentFile = null;
//         panAttachmentFileName = null;
//         gstAttachmentFileName = null;
        
//         // Refresh the buyer list
//         fetchBuyers();
        
//         // Show success message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Buyer updated successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         // Read response body for error details
//         final responseBody = await response.stream.bytesToString();
        
//         // Show error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to update buyer. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
        
//         // Print error response for debugging
//         print('Error response: $responseBody');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       print('Exception: $e');
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedFields = getSelectedFields();
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
//           // Field Selection button (Group By)
//           IconButton(
//             icon: Icon(Icons.view_column),
//             onPressed: showFieldSelectionDialog,
//             tooltip: 'Select Fields',
//           ),
//           // Filter button
//           IconButton(
//             icon: Icon(Icons.filter_list),
//             onPressed: showFilterDialog,
//             tooltip: 'Filter',
//           ),
//           // Sort button
//           IconButton(
//             icon: Icon(Icons.sort),
//             onPressed: showSortDialog,
//             tooltip: 'Sort',
//           ),
//           // Refresh button
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: () => fetchBuyers(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddBuyerDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add New'),
//             ),
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : buyers.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('No buyers found'),
//                       if (filterParams.length > 1) ...[
//                         SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: clearFilters,
//                           child: Text('Clear Filters'),
//                         ),
//                       ],
//                       if (sortBy != null) ...[
//                         SizedBox(height: 16),
//                         ElevatedButton(
//                           onPressed: clearSort,
//                           child: Text('Clear Sort'),
//                         ),
//                       ]
//                     ],
//                   ),
//                 )
//               : Column(
//                   children: [
//                     // Show field selection summary
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       color: Colors.purple.shade50,
//                       child: Row(
//                         children: [
//                           Icon(Icons.view_column, size: 16, color: Colors.purple),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'Showing ${selectedFields.length} fields',
//                               style: TextStyle(fontSize: 12),
//                             ),
//                           ),
//                           TextButton.icon(
//                             onPressed: showFieldSelectionDialog,
//                             icon: Icon(Icons.edit, size: 14),
//                             label: Text('Change', style: TextStyle(fontSize: 12)),
//                             style: TextButton.styleFrom(
//                               padding: EdgeInsets.zero,
//                               minimumSize: Size(0, 0),
//                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     // Show active filters if any (excluding role)
//                     if (filterParams.length > 1)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.blue.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Filters: ${filterParams.entries.where((e) => e.key != 'role').map((e) => '${e.key}=${e.value}').join(', ')}',
//                                 style: TextStyle(fontSize: 12),
//                               ),
//                             ),
//                             IconButton(
//                               icon: Icon(Icons.close, size: 16),
//                               onPressed: clearFilters,
//                               padding: EdgeInsets.zero,
//                               constraints: BoxConstraints(),
//                             ),
//                           ],
//                         ),
//                       ),
                    
//                     // Show active sort if any
//                     if (sortBy != null)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.green.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.sort, size: 16, color: Colors.green),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Sort: ${sortBy?.replaceAll('_', ' ')} (${sortOrder ?? 'asc'})',
//                                 style: TextStyle(fontSize: 12),
//                               ),
//                             ),
//                             IconButton(
//                               icon: Icon(Icons.close, size: 16),
//                               onPressed: clearSort,
//                               padding: EdgeInsets.zero,
//                               constraints: BoxConstraints(),
//                             ),
//                             if (sortBy != null)
//                               IconButton(
//                                 icon: Icon(sortOrder == 'desc' 
//                                     ? Icons.arrow_downward 
//                                     : Icons.arrow_upward),
//                                 onPressed: toggleSortOrder,
//                                 padding: EdgeInsets.zero,
//                                 constraints: BoxConstraints(),
//                               ),
//                           ],
//                         ),
//                       ),
                    
//                     // Page size selector
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                       child: Row(
//                         children: [
//                           Text('Page size:'),
//                           SizedBox(width: 8),
//                           DropdownButton<int>(
//                             value: pageSize,
//                             items: [10, 20, 50, 100].map((size) {
//                               return DropdownMenuItem(
//                                 value: size,
//                                 child: Text('$size'),
//                               );
//                             }).toList(),
//                             onChanged: (value) {
//                               if (value != null) {
//                                 changePageSize(value);
//                               }
//                             },
//                           ),
//                         ],
//                       ),
//                     ),
                    
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: compactRows ? 15 : 20,
//                             dataRowHeight: compactRows ? 40 : null,
//                             headingRowHeight: compactRows ? 45 : null,
//                             showCheckboxColumn: false,
//                             columns: [
//                               DataColumn(label: Text('Select', style: TextStyle(fontSize: compactRows ? 12 : 14))),
//                               DataColumn(label: Text('Actions', style: TextStyle(fontSize: compactRows ? 12 : 14))),
//                               ...selectedFields.map((f) => DataColumn(
//                                     label: GestureDetector(
//                                       onTap: () {
//                                         // Quick sort by clicking column header
//                                         if (sortBy == f['key']) {
//                                           toggleSortOrder();
//                                         } else {
//                                           applySort(f['key'], 'asc');
//                                         }
//                                       },
//                                       child: Row(
//                                         children: [
//                                           Text(
//                                             f['label'].toUpperCase(),
//                                             style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                           ),
//                                           if (sortBy == f['key'])
//                                             Icon(
//                                               sortOrder == 'desc' 
//                                                   ? Icons.arrow_downward 
//                                                   : Icons.arrow_upward,
//                                               size: compactRows ? 14 : 16,
//                                             ),
//                                         ],
//                                       ),
//                                     ),
//                                   )),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
//                                 color: activeRowHighlighting && isSelected
//                                     ? MaterialStateProperty.resolveWith<Color?>(
//                                         (Set<MaterialState> states) {
//                                           return Colors.blue.shade50;
//                                         },
//                                       )
//                                     : null,
//                                 cells: [
//                                   DataCell(
//                                     Checkbox(
//                                       value: isSelected,
//                                       onChanged: (v) {
//                                         setState(() {
//                                           if (v == true) {
//                                             // Clear all other selections and select only this one
//                                             selectedIds.clear();
//                                             selectedIds.add(id);
//                                           } else {
//                                             selectedIds.remove(id);
//                                           }
//                                         });
//                                       },
//                                     ),
//                                   ),

//                                   // ACTIONS - Show only if this row is selected
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               // Show View button only if enableView is true
//                                               if (enableView)
//                                                 ElevatedButton(
//                                                   onPressed: () => fetchBuyerDetails(id),
//                                                   child: Text(
//                                                     'View',
//                                                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                   ),
//                                                   style: ElevatedButton.styleFrom(
//                                                     padding: EdgeInsets.symmetric(horizontal: 8),
//                                                   ),
//                                                 ),
                                              
//                                               // Show Edit button only if enableEdit is true
//                                               if (enableEdit) ...[
//                                                 if (enableView) SizedBox(width: 8),
//                                                 ElevatedButton(
//                                                   onPressed: () => showBuyerDialog(buyer, true),
//                                                   child: Text(
//                                                     'Edit',
//                                                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                   ),
//                                                   style: ElevatedButton.styleFrom(
//                                                     padding: EdgeInsets.symmetric(horizontal: 8),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ],
//                                           )
//                                         : SizedBox.shrink(), // Empty widget when not selected
//                                   ),

//                                   // Selected fields only
//                                   ...selectedFields.map((f) {
//                                     String displayValue = getFieldValue(buyer, f['key']);
                                    
//                                     // Special handling for map_location to make it tappable
//                                     if (f['key'] == 'map_location' && displayValue.isNotEmpty) {
//                                       return DataCell(
//                                         GestureDetector(
//                                           onTap: () {
//                                             // Open map link
//                                             final url = buyer['map_location'];
//                                             if (url != null && url.toString().isNotEmpty) {
//                                               print('Open map: $url');
//                                             }
//                                           },
//                                           child: Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: Colors.blue.shade50,
//                                               borderRadius: BorderRadius.circular(4),
//                                             ),
//                                             child: Text(
//                                               displayValue,
//                                               style: TextStyle(
//                                                 color: Colors.blue,
//                                                 decoration: TextDecoration.underline,
//                                                 fontSize: compactRows ? 11 : 13,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       );
//                                     }
                                    
//                                     // Special handling for attachments
//                                     if (f['key'].contains('attachment') && displayValue.isNotEmpty) {
//                                       return DataCell(
//                                         GestureDetector(
//                                           onTap: () {
//                                             final url = buyer[f['key']];
//                                             print('Open attachment: $url');
//                                           },
//                                           child: Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: modernCellColoring 
//                                                   ? Colors.purple.shade50 
//                                                   : Colors.orange.shade50,
//                                               borderRadius: BorderRadius.circular(4),
//                                             ),
//                                             child: Row(
//                                               mainAxisSize: MainAxisSize.min,
//                                               children: [
//                                                 Icon(Icons.attachment, 
//                                                   size: compactRows ? 10 : 12, 
//                                                   color: modernCellColoring ? Colors.purple : Colors.orange
//                                                 ),
//                                                 SizedBox(width: 2),
//                                                 Text(
//                                                   displayValue,
//                                                   style: TextStyle(
//                                                     fontSize: compactRows ? 10 : 12,
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ),
//                                       );
//                                     }
                                    
//                                     // Special handling for more_detail
//                                     if (f['key'] == 'more_detail') {
//                                       final details = buyer['more_detail'];
//                                       if (details != null && details is List) {
//                                         return DataCell(
//                                           Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: Colors.green.shade50,
//                                               borderRadius: BorderRadius.circular(4),
//                                             ),
//                                             child: Text(
//                                               '${details.length} details',
//                                               style: TextStyle(
//                                                 fontSize: compactRows ? 11 : 13,
//                                                 color: Colors.green.shade800,
//                                               ),
//                                             ),
//                                           ),
//                                         );
//                                       }
//                                     }
                                    
//                                     return DataCell(
//                                       Container(
//                                         child: Text(
//                                           displayValue,
//                                           style: TextStyle(
//                                             fontSize: compactRows ? 11 : 13,
//                                             color: modernCellColoring && isSelected 
//                                                 ? Colors.blue 
//                                                 : null,
//                                           ),
//                                         ),
//                                       ),
//                                     );
//                                   }).toList(),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     // Pagination controls
//                     Container(
//                       padding: EdgeInsets.all(compactRows ? 8 : 12),
//                       decoration: BoxDecoration(
//                         border: Border(
//                           top: BorderSide(color: Colors.grey.shade300),
//                         ),
//                       ),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage of ${(totalCount / pageSize).ceil()} | Total: $totalCount',
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: compactRows ? 11 : 13,
//                             ),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: (prevUrl == null || prevUrl!.isEmpty) 
//                                     ? null 
//                                     : loadPrevPage,
//                                 child: Text(
//                                   'Previous',
//                                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: (prevUrl == null || prevUrl!.isEmpty) 
//                                       ? Colors.grey 
//                                       : null,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: compactRows ? 8 : 16,
//                                     vertical: compactRows ? 4 : 8,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(width: compactRows ? 8 : 12),
//                               ElevatedButton(
//                                 onPressed: (nextUrl == null || nextUrl!.isEmpty) 
//                                     ? null 
//                                     : loadNextPage,
//                                 child: Text(
//                                   'Next',
//                                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                 ),
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: (nextUrl == null || nextUrl!.isEmpty) 
//                                       ? Colors.grey 
//                                       : null,
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: compactRows ? 8 : 16,
//                                     vertical: compactRows ? 4 : 8,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           )
//                         ],
//                       ),
//                     )
//                   ],
//                 ),
//     );
//   }
// }

