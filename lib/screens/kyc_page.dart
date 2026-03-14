import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';

class KYCPage extends StatefulWidget {
  @override
  _KYCPageState createState() => _KYCPageState();
}

class _KYCPageState extends State<KYCPage> {
  List<Map<String, dynamic>> kycRecords = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  List<String> dynamicFields = [];

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
  bool enableEdit = false;
  bool enableView = false;
  
  // Scroll controller for horizontal scrolling
  final ScrollController _horizontalScrollController = ScrollController();
  
  // Filter field controllers
  final TextEditingController bpCodeController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController gstNoController = TextEditingController();
  final TextEditingController panNoController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  
  // Group By / Display Fields variables
  List<Map<String, dynamic>> availableFields = [
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
    {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
    {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
    {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
    {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 4},
    {'key': 'gst_no', 'label': 'GST Number', 'selected': true, 'order': 5},
    {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 6},
    {'key': 'pan_no', 'label': 'PAN Number', 'selected': true, 'order': 7},
    {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 8},
    {'key': 'bis_name', 'label': 'BIS Name', 'selected': false, 'order': 9},
    {'key': 'bis_no', 'label': 'BIS Number', 'selected': false, 'order': 10},
    {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false, 'order': 11},
    {'key': 'msme_name', 'label': 'MSME Name', 'selected': false, 'order': 12},
    {'key': 'msme_no', 'label': 'MSME Number', 'selected': false, 'order': 13},
    {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false, 'order': 14},
    {'key': 'tan_name', 'label': 'TAN Name', 'selected': false, 'order': 15},
    {'key': 'tan_no', 'label': 'TAN Number', 'selected': false, 'order': 16},
    {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false, 'order': 17},
    {'key': 'cin_name', 'label': 'CIN Name', 'selected': false, 'order': 18},
    {'key': 'cin_no', 'label': 'CIN Number', 'selected': false, 'order': 19},
    {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false, 'order': 20},
    {'key': 'note', 'label': 'Note', 'selected': false, 'order': 21},
    {'key': 'is_completed', 'label': 'Status', 'selected': true, 'order': 22},
    {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false, 'isComplex': true, 'order': 23},
    {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false, 'isComplex': true, 'order': 24},
    {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false, 'isComplex': true, 'order': 25},
    {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 26},
    {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 27},
  ];

  // For editing KYC
  Map<String, TextEditingController>? editControllers;
  List<Map<String, TextEditingController>>? editAadharDetailControllers;
  List<Map<String, TextEditingController>>? editPanDetailControllers;
  List<Map<String, TextEditingController>>? editBankDetailControllers;
  int? editingKycId;
  
  // For file uploads - Use XFile for better cross-platform support
  XFile? panAttachmentXFile;
  XFile? gstAttachmentXFile;
  XFile? bisAttachmentXFile;
  XFile? msmeAttachmentXFile;
  XFile? tanAttachmentXFile;
  XFile? cinAttachmentXFile;
  
  // For nested array file uploads
  Map<int, XFile> aadharAttachmentXFiles = {};
  Map<int, XFile> panDetailAttachmentXFiles = {};
  Map<int, XFile> bankChequeLeafXFiles = {};
  
  // Store existing file URLs to preserve them
  String? existingPanAttachmentUrl;
  String? existingGstAttachmentUrl;
  String? existingBisAttachmentUrl;
  String? existingMsmeAttachmentUrl;
  String? existingTanAttachmentUrl;
  String? existingCinAttachmentUrl;
  
  // Store existing file URLs for nested arrays
  List<String?> existingAadharAttachmentUrls = [];
  List<String?> existingPanAttachmentUrls = [];
  List<String?> existingChequeLeafUrls = [];

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
    _disposeAllControllers();
    bpCodeController.dispose();
    businessNameController.dispose();
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    gstNoController.dispose();
    panNoController.dispose();
    statusController.dispose();
    
    // Dispose scroll controller
    _horizontalScrollController.dispose();
    
    super.dispose();
  }

  // Load saved field selections from SharedPreferences
  Future<void> loadSavedFieldSelections() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedSelections = prefs.getString('kyc_fields');
    String? savedOrder = prefs.getString('kyc_field_order');
    
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
    
    await prefs.setString('kyc_fields', json.encode(selections));
    
    // Save field order
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('kyc_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    setState(() {
      compactRows = prefs.getBool('kyc_compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('kyc_active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('kyc_modern_cell_coloring') ?? false;
      enableEdit = prefs.getBool('kyc_enable_edit') ?? false;
      enableView = prefs.getBool('kyc_enable_view') ?? false;
    });
  }

  // Save list settings to SharedPreferences
  Future<void> saveListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableEdit,
    required bool enableView,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('kyc_compact_rows', compactRows);
    await prefs.setBool('kyc_active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('kyc_modern_cell_coloring', modernCellColoring);
    await prefs.setBool('kyc_enable_edit', enableEdit);
    await prefs.setBool('kyc_enable_view', enableView);
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
        {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
        {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
        {'key': 'is_completed', 'label': 'Status', 'selected': true},
        {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
        {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
        {'key': 'bis_name', 'label': 'BIS Name', 'selected': false},
        {'key': 'bis_no', 'label': 'BIS Number', 'selected': false},
        {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false},
        {'key': 'msme_name', 'label': 'MSME Name', 'selected': false},
        {'key': 'msme_no', 'label': 'MSME Number', 'selected': false},
        {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false},
        {'key': 'tan_name', 'label': 'TAN Name', 'selected': false},
        {'key': 'tan_no', 'label': 'TAN Number', 'selected': false},
        {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false},
        {'key': 'cin_name', 'label': 'CIN Name', 'selected': false},
        {'key': 'cin_no', 'label': 'CIN Number', 'selected': false},
        {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false},
        {'key': 'note', 'label': 'Note', 'selected': false},
        {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false},
        {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false},
        {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false},
        {'key': 'created_at', 'label': 'Created Date', 'selected': false},
        {'key': 'updated_at', 'label': 'Updated Date', 'selected': false},
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
    required bool enableEdit,
    required bool enableView,
  }) {
    // Save these settings to SharedPreferences
    saveListSettings(
      compactRows: compactRows,
      activeRowHighlighting: activeRowHighlighting,
      modernCellColoring: modernCellColoring,
      enableEdit: enableEdit,
      enableView: enableView,
    );
    
    // Apply the settings to the current view
    setState(() {
      this.compactRows = compactRows;
      this.activeRowHighlighting = activeRowHighlighting;
      this.modernCellColoring = modernCellColoring;
      this.enableEdit = enableEdit;
      this.enableView = enableView;
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
    bool localEnableEdit = enableEdit;
    bool localEnableView = enableView;
    
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
                            'Personalize List Columns - KYC Records',
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
                              SizedBox(width: 32),
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
                                  {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
                                  {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
                                  {'key': 'is_completed', 'label': 'Status', 'selected': true},
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
                                localEnableEdit = false;
                                localEnableView = false;
                                
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
                                'KYC - Field Selection',
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
                                enableEdit: localEnableEdit,
                                enableView: localEnableView,
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
      return '[${value.length} items]';
    }
    return value.toString();
  }

  // Get field value with proper formatting
  String getFieldValue(Map<String, dynamic> record, String key) {
    final value = record[key];
    
    if (value == null) return '';
    
    // Handle complex fields (arrays)
    if (key == 'aadhar_detail' || key == 'pan_detail' || key == 'bank_detail') {
      if (value is List) {
        return '${value.length} items';
      }
    }
    
    // Handle attachments
    if (key.endsWith('_attachment') || key == 'cin_attach') {
      if (value.toString().isNotEmpty) {
        if (key == 'cin_attach') {
          return '📄 CIN';
        }
        return '📎 ' + key.replaceAll('_attachment', '').toUpperCase();
      }
    }
    
    // Handle status
    if (key == 'is_completed') {
      return value == true ? '✅ Completed' : '⏳ In Progress';
    }
    
    return value.toString();
  }

  // Build URL with filter and sort parameters
  String buildRequestUrl({String? baseUrl}) {
    Uri uri;
    
    if (baseUrl != null) {
      uri = Uri.parse(baseUrl);
    } else {
      uri = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/');
    }
    
    // Create a new Uri with additional query parameters
    Map<String, String> queryParams = {};
    
    // Add existing query parameters from the URL
    queryParams.addAll(uri.queryParameters);
    
    // Add filter parameters
    queryParams.addAll(filterParams);
    
    // Add sort parameters
    if (sortBy != null && sortBy!.isNotEmpty) {
      queryParams['sort_by'] = sortBy!;
      
      if (sortOrder != null && sortOrder!.isNotEmpty) {
        queryParams['sort_order'] = sortOrder!;
      }
    }
    
    // Add page size
    if (pageSize != 20) {
      queryParams['page_size'] = pageSize.toString();
    }
    
    // Rebuild URI with all parameters
    return uri.replace(queryParameters: queryParams).toString();
  }

  // Apply all filters at once
  Future<void> applyFilters() async {
    filterParams.clear();
    
    if (bpCodeController.text.isNotEmpty) {
      filterParams['bp_code'] = bpCodeController.text;
    }
    if (businessNameController.text.isNotEmpty) {
      filterParams['business_name'] = businessNameController.text;
    }
    if (nameController.text.isNotEmpty) {
      filterParams['name'] = nameController.text;
    }
    if (mobileController.text.isNotEmpty) {
      filterParams['mobile'] = mobileController.text;
    }
    if (emailController.text.isNotEmpty) {
      filterParams['business_email'] = emailController.text;
    }
    if (gstNoController.text.isNotEmpty) {
      filterParams['gst_no'] = gstNoController.text;
    }
    if (panNoController.text.isNotEmpty) {
      filterParams['pan_no'] = panNoController.text;
    }
    if (statusController.text.isNotEmpty) {
      if (statusController.text.toLowerCase() == 'completed') {
        filterParams['is_completed'] = 'true';
      } else if (statusController.text.toLowerCase() == 'in progress') {
        filterParams['is_completed'] = 'false';
      }
    }
    
    // Reset to first page when applying filters
    currentPage = 1;
    await fetchKYCRecords();
  }

  // Clear all filters
  Future<void> clearFilters() async {
    filterParams.clear();
    bpCodeController.clear();
    businessNameController.clear();
    nameController.clear();
    mobileController.clear();
    emailController.clear();
    gstNoController.clear();
    panNoController.clear();
    statusController.clear();
    
    await fetchKYCRecords();
  }

  // Show filter dialog
  void showFilterDialog() {
    // Initialize controllers with current filter values
    bpCodeController.text = filterParams['bp_code'] ?? '';
    businessNameController.text = filterParams['business_name'] ?? '';
    nameController.text = filterParams['name'] ?? '';
    mobileController.text = filterParams['mobile'] ?? '';
    emailController.text = filterParams['business_email'] ?? '';
    gstNoController.text = filterParams['gst_no'] ?? '';
    panNoController.text = filterParams['pan_no'] ?? '';
    
    // Convert boolean filter to text for status
    if (filterParams.containsKey('is_completed')) {
      if (filterParams['is_completed'] == 'true') {
        statusController.text = 'completed';
      } else if (filterParams['is_completed'] == 'false') {
        statusController.text = 'in progress';
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filter KYC Records'),
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
                      hintText: 'e.g., KYC001',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: businessNameController,
                    decoration: InputDecoration(
                      labelText: 'Business Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
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
                    controller: gstNoController,
                    decoration: InputDecoration(
                      labelText: 'GST Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: panNoController,
                    decoration: InputDecoration(
                      labelText: 'PAN Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: statusController.text.isNotEmpty ? statusController.text : null,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info),
                    ),
                    items: [
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
                    ],
                    onChanged: (value) {
                      statusController.text = value ?? '';
                    },
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
    setState(() {
      sortBy = field;
      sortOrder = order;
    });
    
    // Reset to first page when sorting
    currentPage = 1;
    await fetchKYCRecords();
  }

  // Clear sort
  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchKYCRecords();
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
      {'value': 'business_name', 'label': 'Business Name'},
      {'value': 'name', 'label': 'Name'},
      {'value': 'mobile', 'label': 'Mobile'},
      {'value': 'business_email', 'label': 'Email'},
      {'value': 'gst_no', 'label': 'GST Number'},
      {'value': 'pan_no', 'label': 'PAN Number'},
      {'value': 'is_completed', 'label': 'Status'},
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
                      fetchKYCRecords();
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

  // Change page size
  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    
    // Add page_size to URL
    filterParams['page_size'] = newSize.toString();
    await fetchKYCRecords();
  }

  void _disposeAllControllers() {
    if (editControllers != null) {
      editControllers!.forEach((key, controller) {
        controller.dispose();
      });
    }
    
    if (editAadharDetailControllers != null) {
      for (var controllers in editAadharDetailControllers!) {
        controllers.forEach((key, controller) {
          controller.dispose();
        });
      }
    }
    
    if (editPanDetailControllers != null) {
      for (var controllers in editPanDetailControllers!) {
        controllers.forEach((key, controller) {
          controller.dispose();
        });
      }
    }
    
    if (editBankDetailControllers != null) {
      for (var controllers in editBankDetailControllers!) {
        controllers.forEach((key, controller) {
          controller.dispose();
        });
      }
    }
  }

  void _resetFileSelections() {
    panAttachmentXFile = null;
    gstAttachmentXFile = null;
    bisAttachmentXFile = null;
    msmeAttachmentXFile = null;
    tanAttachmentXFile = null;
    cinAttachmentXFile = null;
    aadharAttachmentXFiles.clear();
    panDetailAttachmentXFiles.clear();
    bankChequeLeafXFiles.clear();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null || token!.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    fetchKYCRecords();
  }

  Future<void> fetchKYCRecords({String? url}) async {
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
          dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
        }

        setState(() {
          kycRecords = results;
          nextUrl = data['next'];
          prevUrl = data['previous'];
          totalCount = data['count'] ?? 0;
          
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
        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void loadNextPage() {
    if (nextUrl != null && nextUrl!.isNotEmpty) {
      currentPage++;
      fetchKYCRecords(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty && currentPage > 1) {
      currentPage--;
      fetchKYCRecords(url: prevUrl);
    }
  }

  Future<Map<String, dynamic>> fetchKycDetail(int id) async {
    if (token == null) throw Exception('No token available');

    final Uri apiUrl = Uri.parse(
      'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/detail/$id/',
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
        throw Exception('Failed to fetch KYC details');
      }
    } catch (e) {
      throw Exception('Error fetching KYC details: $e');
    }
  }

  // Function to mark KYC as completed
  Future<void> completeKYC(int id, bool completed) async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final Uri apiUrl = Uri.parse(
        'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/complete/$id/',
      );

      final response = await http.post(
        apiUrl,
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'completed': completed}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['detail'] ?? 'Operation successful'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the list to update the status
        fetchKYCRecords();
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['detail'] ?? 'Failed to update KYC status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Function to show confirmation dialog for complete/reopen
  void _showCompletionDialog(Map<String, dynamic> kycRecord) {
    final id = kycRecord['id'];
    final bool isCompleted = kycRecord['is_completed'] == true;
    final String businessName = kycRecord['business_name']?.toString() ?? 'KYC';
    final String bpCode = kycRecord['bp_code']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isCompleted ? 'Reopen KYC' : 'Complete KYC'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KYC Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Business Name: $businessName'),
            Text('BP Code: $bpCode'),
            SizedBox(height: 16),
            Text(
              isCompleted 
                ? 'Are you sure you want to reopen this KYC? This will unlock it for editing.'
                : 'Are you sure you want to mark this KYC as completed? This will lock it from further editing.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await completeKYC(id, !isCompleted);
            },
            child: Text(isCompleted ? 'Reopen' : 'Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCompleted ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
    if (isEdit) {
      try {
        setState(() => isLoading = true);
        final detailedRecord = await fetchKycDetail(kycRecord['id']);
        setState(() => isLoading = false);
        
        _initializeEditMode(detailedRecord);
      } catch (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load KYC details for editing: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit KYC' : 'KYC Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show completion status prominently
                  if (!isEdit && kycRecord['is_completed'] == true)
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'KYC Completed (Locked)',
                              style: TextStyle(
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (isEdit && editControllers != null)
                    ..._buildEditFields(setState)
                  else
                    ..._buildViewFields(kycRecord),
                  
                  if (!isEdit)
                    ..._buildNestedArraysView(kycRecord),
                ],
              ),
            ),
            actions: [
              if (isEdit)
                ElevatedButton(
                  onPressed: () async {
                    await updateKYC(editingKycId!);
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
              TextButton(
                onPressed: () {
                  if (isEdit) {
                    _disposeAllControllers();
                    editControllers = null;
                    editAadharDetailControllers = null;
                    editPanDetailControllers = null;
                    editBankDetailControllers = null;
                    editingKycId = null;
                    _resetFileSelections();
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

  void _initializeEditMode(Map<String, dynamic> kycRecord) {
    editingKycId = kycRecord['id'];
    editControllers = {};
    
    // Check if KYC is completed and locked
    bool isCompleted = kycRecord['is_completed'] == true;
    if (isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('KYC is completed and locked. Cannot edit.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Initialize main field controllers
    for (var field in kycRecord.keys) {
      if (field.toLowerCase() != 'id' && 
          field != 'aadhar_detail' && 
          field != 'pan_detail' && 
          field != 'bank_detail') {
        editControllers![field] = TextEditingController(
          text: kycRecord[field]?.toString() ?? '',
        );
        
        // Store existing file URLs to preserve them
        if (field == 'pan_attachment' && kycRecord[field] != null) {
          existingPanAttachmentUrl = kycRecord[field].toString();
        } else if (field == 'gst_attachment' && kycRecord[field] != null) {
          existingGstAttachmentUrl = kycRecord[field].toString();
        } else if (field == 'bis_attachment' && kycRecord[field] != null) {
          existingBisAttachmentUrl = kycRecord[field].toString();
        } else if (field == 'msme_attachment' && kycRecord[field] != null) {
          existingMsmeAttachmentUrl = kycRecord[field].toString();
        } else if (field == 'tan_attachment' && kycRecord[field] != null) {
          existingTanAttachmentUrl = kycRecord[field].toString();
        } else if (field == 'cin_attach' && kycRecord[field] != null) {
          existingCinAttachmentUrl = kycRecord[field].toString();
        }
      }
    }
    
    // Initialize aadhar detail controllers
    editAadharDetailControllers = [];
    existingAadharAttachmentUrls.clear();
    if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
      List<Map<String, dynamic>> existingDetails = 
          List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
      for (var detail in existingDetails) {
        editAadharDetailControllers!.add({
          'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
          'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
        });
        existingAadharAttachmentUrls.add(detail['aadhar_attach']?.toString());
      }
    }
    
    // Initialize pan detail controllers
    editPanDetailControllers = [];
    existingPanAttachmentUrls.clear();
    if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
      List<Map<String, dynamic>> existingDetails = 
          List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
      for (var detail in existingDetails) {
        editPanDetailControllers!.add({
          'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
          'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
        });
        existingPanAttachmentUrls.add(detail['pan_attachment']?.toString());
      }
    }
    
    // Initialize bank detail controllers
    editBankDetailControllers = [];
    existingChequeLeafUrls.clear();
    if (kycRecord['bank_detail'] != null && kycRecord['bank_detail'] is List) {
      List<Map<String, dynamic>> existingDetails = 
          List<Map<String, dynamic>>.from(kycRecord['bank_detail']);
      
      for (var detail in existingDetails) {
        editBankDetailControllers!.add({
          'bank_name': TextEditingController(text: detail['bank_name']?.toString() ?? ''),
          'account_name': TextEditingController(text: detail['account_name']?.toString() ?? ''),
          'account_no': TextEditingController(text: detail['account_no']?.toString() ?? ''),
          'ifsc_code': TextEditingController(text: detail['ifsc_code']?.toString() ?? ''),
          'branch': TextEditingController(text: detail['branch']?.toString() ?? ''),
          'bank_city': TextEditingController(text: detail['bank_city']?.toString() ?? ''),
          'bank_state': TextEditingController(text: detail['bank_state']?.toString() ?? ''),
        });
        existingChequeLeafUrls.add(detail['cheque_leaf']?.toString());
      }
    }
    
    _resetFileSelections();
  }

  List<Widget> _buildEditFields(StateSetter setState) {
    List<Widget> fields = [];
    
    if (editControllers == null) return fields;
    
    List<String> fieldOrder = [
      'bp_code', 'mobile', 'name', 'business_name', 'business_email',
      'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
      'bis_name', 'bis_no', 'bis_attachment',
      'msme_name', 'msme_no', 'msme_attachment',
      'tan_name', 'tan_no', 'tan_attachment',
      'cin_name', 'cin_no', 'cin_attach',
      'note', 'is_completed'
    ];
    
    for (var field in fieldOrder) {
      if (editControllers!.containsKey(field)) {
        if (field.endsWith('_attachment') || field == 'cin_attach') {
          fields.add(_buildEditFileAttachmentField(
            field: field,
            label: _getFieldLabel(field),
            currentValue: editControllers![field]!.text,
            setState: setState,
          ));
        } else if (field == 'is_completed') {
          fields.add(_buildBooleanField(
            field: field,
            label: _getFieldLabel(field),
            setState: setState,
          ));
        } else {
          fields.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: editControllers![field],
              decoration: InputDecoration(
                labelText: _getFieldLabel(field),
                border: OutlineInputBorder(),
              ),
            ),
          ));
        }
      }
    }
    
    fields.addAll(_buildNestedArraysEdit(setState));
    
    return fields;
  }

  String _getFieldLabel(String field) {
    return field
        .replaceAll('_', ' ')
        .toUpperCase()
        .replaceAll('ATTACH', 'ATTACHMENT');
  }

  Widget _buildBooleanField({
    required String field,
    required String label,
    required StateSetter setState,
  }) {
    bool value = editControllers![field]!.text.toLowerCase() == 'true';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                editControllers![field]!.text = newValue.toString();
              });
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildViewFields(Map<String, dynamic> kycRecord) {
    List<Widget> fields = [];
    
    List<String> displayOrder = [
      'bp_code', 'mobile', 'name', 'business_name', 'business_email',
      'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
      'bis_name', 'bis_no', 'bis_attachment',
      'msme_name', 'msme_no', 'msme_attachment',
      'tan_name', 'tan_no', 'tan_attachment',
      'cin_name', 'cin_no', 'cin_attach',
      'note', 'is_completed'
    ];
    
    for (var field in displayOrder) {
      if (kycRecord.containsKey(field)) {
        if (field.endsWith('_attachment') || field == 'cin_attach') {
          fields.add(_buildFileAttachmentField(
            field: field,
            label: _getFieldLabel(field),
            value: kycRecord[field],
          ));
        } else if (field == 'is_completed') {
          fields.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFieldLabel(field),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      kycRecord[field] == true ? Icons.lock : Icons.lock_open,
                      color: kycRecord[field] == true ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      kycRecord[field] == true ? 'Completed (Locked)' : 'In Progress',
                      style: TextStyle(
                        fontSize: 14,
                        color: kycRecord[field] == true ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ));
        } else {
          fields.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFieldLabel(field),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  kycRecord[field]?.toString() ?? 'Not provided',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ));
        }
      }
    }
    
    return fields;
  }

  List<Widget> _buildNestedArraysView(Map<String, dynamic> kycRecord) {
    List<Widget> arrays = [];
    
    if (kycRecord['aadhar_detail'] != null && 
        kycRecord['aadhar_detail'] is List && 
        (kycRecord['aadhar_detail'] as List).isNotEmpty) {
      arrays.add(_buildNestedArraySection(
        title: 'Aadhar Details',
        details: List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']),
        fields: ['aadhar_name', 'aadhar_no'],
        fileFields: ['aadhar_attach'],
      ));
    }
    
    if (kycRecord['pan_detail'] != null && 
        kycRecord['pan_detail'] is List && 
        (kycRecord['pan_detail'] as List).isNotEmpty) {
      arrays.add(_buildNestedArraySection(
        title: 'PAN Details',
        details: List<Map<String, dynamic>>.from(kycRecord['pan_detail']),
        fields: ['pan_name', 'pan_no'],
        fileFields: ['pan_attachment'],
      ));
    }
    
    if (kycRecord['bank_detail'] != null && 
        kycRecord['bank_detail'] is List && 
        (kycRecord['bank_detail'] as List).isNotEmpty) {
      arrays.add(_buildNestedArraySection(
        title: 'Bank Details',
        details: List<Map<String, dynamic>>.from(kycRecord['bank_detail']),
        fields: ['bank_name', 'account_name', 'account_no', 'ifsc_code', 'branch', 'bank_city', 'bank_state'],
        fileFields: ['cheque_leaf'],
      ));
    }
    
    return arrays;
  }

  Widget _buildNestedArraySection({
    required String title,
    required List<Map<String, dynamic>> details,
    required List<String> fields,
    required List<String> fileFields,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 10),
        ...details.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> detail = entry.value;
          
          return Card(
            margin: EdgeInsets.symmetric(vertical: 5),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${title} ${index + 1}', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ...fields.map((field) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '${field.replaceAll('_', ' ').toUpperCase()}: ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Expanded(
                            child: Text(detail[field]?.toString() ?? 'Not provided'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  ...fileFields.map((field) {
                    final fileUrl = detail[field];
                    if (fileUrl != null && fileUrl.toString().isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          onTap: () {
                            print('File URL: $fileUrl');
                          },
                          child: Row(
                            children: [
                              Icon(Icons.attach_file, size: 16, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                '${field.replaceAll('_', ' ').toUpperCase()}',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  List<Widget> _buildNestedArraysEdit(StateSetter setState) {
    List<Widget> arrays = [];
    
    arrays.add(_buildNestedArrayEditSection(
      title: 'Aadhar Details',
      controllersList: editAadharDetailControllers,
      fields: [
        {'key': 'aadhar_name', 'label': 'Aadhar Name'},
        {'key': 'aadhar_no', 'label': 'Aadhar Number'},
      ],
      hasFileAttachment: true,
      fileFieldKey: 'aadhar_attach',
      fileFieldLabel: 'Aadhar Attachment',
      fileMap: aadharAttachmentXFiles,
      existingUrls: existingAadharAttachmentUrls,
      onAdd: () {
        setState(() {
          editAadharDetailControllers ??= [];
          editAadharDetailControllers!.add({
            'aadhar_name': TextEditingController(),
            'aadhar_no': TextEditingController(),
          });
          existingAadharAttachmentUrls.add(null);
        });
      },
      onDelete: (index) {
        setState(() {
          editAadharDetailControllers![index].forEach((key, controller) {
            controller.dispose();
          });
          editAadharDetailControllers!.removeAt(index);
          aadharAttachmentXFiles.remove(index);
          existingAadharAttachmentUrls.removeAt(index);
        });
      },
      onPickFile: (index) async {
        await pickNestedArrayFile('aadhar', index);
        setState(() {});
      },
      onClearFile: (index) {
        setState(() {
          aadharAttachmentXFiles.remove(index);
        });
      },
    ));
    
    arrays.add(_buildNestedArrayEditSection(
      title: 'PAN Details',
      controllersList: editPanDetailControllers,
      fields: [
        {'key': 'pan_name', 'label': 'PAN Name'},
        {'key': 'pan_no', 'label': 'PAN Number'},
      ],
      hasFileAttachment: true,
      fileFieldKey: 'pan_attachment',
      fileFieldLabel: 'PAN Attachment',
      fileMap: panDetailAttachmentXFiles,
      existingUrls: existingPanAttachmentUrls,
      onAdd: () {
        setState(() {
          editPanDetailControllers ??= [];
          editPanDetailControllers!.add({
            'pan_name': TextEditingController(),
            'pan_no': TextEditingController(),
          });
          existingPanAttachmentUrls.add(null);
        });
      },
      onDelete: (index) {
        setState(() {
          editPanDetailControllers![index].forEach((key, controller) {
            controller.dispose();
          });
          editPanDetailControllers!.removeAt(index);
          panDetailAttachmentXFiles.remove(index);
          existingPanAttachmentUrls.removeAt(index);
        });
      },
      onPickFile: (index) async {
        await pickNestedArrayFile('pan_detail', index);
        setState(() {});
      },
      onClearFile: (index) {
        setState(() {
          panDetailAttachmentXFiles.remove(index);
        });
      },
    ));
    
    arrays.add(_buildNestedArrayEditSection(
      title: 'Bank Details',
      controllersList: editBankDetailControllers,
      fields: [
        {'key': 'bank_name', 'label': 'Bank Name'},
        {'key': 'account_name', 'label': 'Account Name'},
        {'key': 'account_no', 'label': 'Account Number'},
        {'key': 'ifsc_code', 'label': 'IFSC Code'},
        {'key': 'branch', 'label': 'Branch'},
        {'key': 'bank_city', 'label': 'Bank City'},
        {'key': 'bank_state', 'label': 'Bank State'},
      ],
      hasFileAttachment: true,
      fileFieldKey: 'cheque_leaf',
      fileFieldLabel: 'Cheque Leaf',
      fileMap: bankChequeLeafXFiles,
      existingUrls: existingChequeLeafUrls,
      onAdd: () {
        setState(() {
          editBankDetailControllers ??= [];
          editBankDetailControllers!.add({
            'bank_name': TextEditingController(),
            'account_name': TextEditingController(),
            'account_no': TextEditingController(),
            'ifsc_code': TextEditingController(),
            'branch': TextEditingController(),
            'bank_city': TextEditingController(),
            'bank_state': TextEditingController(),
          });
          existingChequeLeafUrls.add(null);
        });
      },
      onDelete: (index) {
        setState(() {
          editBankDetailControllers![index].forEach((key, controller) {
            controller.dispose();
          });
          editBankDetailControllers!.removeAt(index);
          bankChequeLeafXFiles.remove(index);
          existingChequeLeafUrls.removeAt(index);
        });
      },
      onPickFile: (index) async {
        await pickNestedArrayFile('cheque_leaf', index);
        setState(() {});
      },
      onClearFile: (index) {
        setState(() {
          bankChequeLeafXFiles.remove(index);
        });
      },
    ));
    
    return arrays;
  }

  Widget _buildNestedArrayEditSection({
    required String title,
    required List<Map<String, TextEditingController>>? controllersList,
    required List<Map<String, String>> fields,
    required bool hasFileAttachment,
    required String fileFieldKey,
    required String fileFieldLabel,
    required Map<int, XFile> fileMap,
    required List<String?> existingUrls,
    required VoidCallback onAdd,
    required Function(int) onDelete,
    required Function(int) onPickFile,
    required Function(int) onClearFile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.add, size: 20),
              label: Text('Add'),
            ),
          ],
        ),
        SizedBox(height: 10),
        
        if (controllersList != null)
          ...controllersList.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, TextEditingController> controllers = entry.value;
            String? existingUrl = index < existingUrls.length ? existingUrls[index] : null;
            XFile? currentFile = fileMap[index];
            
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
                          '${title} ${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onDelete(index),
                        ),
                      ],
                    ),
                    ...fields.map((field) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: controllers[field['key']],
                          decoration: InputDecoration(
                            labelText: field['label'],
                            border: OutlineInputBorder(),
                          ),
                        ),
                      );
                    }).toList(),
                    
                    if (hasFileAttachment)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileFieldLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 4),
                            
                            // Show existing file link if exists and no new file selected
                            if (existingUrl != null && existingUrl.isNotEmpty && currentFile == null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      print('Existing File URL: $existingUrl');
                                    },
                                    child: Text(
                                      'View Existing Attachment',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
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
                                    onPressed: () => onPickFile(index),
                                    icon: Icon(Icons.attach_file),
                                    label: Text(
                                      currentFile != null 
                                          ? path.basename(currentFile.path)
                                          : (existingUrl != null && existingUrl.isNotEmpty 
                                              ? 'Keep Existing / Select New' 
                                              : 'Select $fileFieldLabel'),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (currentFile != null)
                                  IconButton(
                                    icon: Icon(Icons.clear),
                                    onPressed: () => onClearFile(index),
                                  ),
                              ],
                            ),
                          ],
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

  Widget _buildFileAttachmentField({
    required String field,
    required String label,
    required String? value,
  }) {
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
          if (value != null && value.isNotEmpty)
            InkWell(
              onTap: () {
                print('File URL: $value');
              },
              child: Row(
                children: [
                  Icon(Icons.attach_file, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'View Attachment',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            )
          else
            Text('No attachment provided', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEditFileAttachmentField({
    required String field,
    required String label,
    required String currentValue,
    required StateSetter setState,
  }) {
    // Get existing URL based on field
    String? existingUrl;
    XFile? currentFile;
    switch (field) {
      case 'pan_attachment':
        existingUrl = existingPanAttachmentUrl;
        currentFile = panAttachmentXFile;
        break;
      case 'gst_attachment':
        existingUrl = existingGstAttachmentUrl;
        currentFile = gstAttachmentXFile;
        break;
      case 'bis_attachment':
        existingUrl = existingBisAttachmentUrl;
        currentFile = bisAttachmentXFile;
        break;
      case 'msme_attachment':
        existingUrl = existingMsmeAttachmentUrl;
        currentFile = msmeAttachmentXFile;
        break;
      case 'tan_attachment':
        existingUrl = existingTanAttachmentUrl;
        currentFile = tanAttachmentXFile;
        break;
      case 'cin_attach':
        existingUrl = existingCinAttachmentUrl;
        currentFile = cinAttachmentXFile;
        break;
    }
    
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
          
          // Show existing file link if exists and no new file selected
          if (existingUrl != null && existingUrl.isNotEmpty && currentFile == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    print('Existing File URL: $existingUrl');
                  },
                  child: Text(
                    'View Existing Attachment',
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            ),
          
          // File upload for edit mode
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await pickFile(field);
                    setState(() {});
                  },
                  icon: Icon(Icons.attach_file),
                  label: Text(
                    currentFile != null 
                        ? path.basename(currentFile.path)
                        : (existingUrl != null && existingUrl.isNotEmpty 
                            ? 'Keep Existing / Select New' 
                            : 'Select File'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (currentFile != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      switch (field) {
                        case 'pan_attachment':
                          panAttachmentXFile = null;
                          break;
                        case 'gst_attachment':
                          gstAttachmentXFile = null;
                          break;
                        case 'bis_attachment':
                          bisAttachmentXFile = null;
                          break;
                        case 'msme_attachment':
                          msmeAttachmentXFile = null;
                          break;
                        case 'tan_attachment':
                          tanAttachmentXFile = null;
                          break;
                        case 'cin_attach':
                          cinAttachmentXFile = null;
                          break;
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

  Future<void> pickFile(String field) async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          switch (field) {
            case 'pan_attachment':
              panAttachmentXFile = file;
              break;
            case 'gst_attachment':
              gstAttachmentXFile = file;
              break;
            case 'bis_attachment':
              bisAttachmentXFile = file;
              break;
            case 'msme_attachment':
              msmeAttachmentXFile = file;
              break;
            case 'tan_attachment':
              tanAttachmentXFile = file;
              break;
            case 'cin_attach':
              cinAttachmentXFile = file;
              break;
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

  Future<void> pickNestedArrayFile(String type, int index) async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          switch (type) {
            case 'aadhar':
              aadharAttachmentXFiles[index] = file;
              break;
            case 'pan_detail':
              panDetailAttachmentXFiles[index] = file;
              break;
            case 'cheque_leaf':
              bankChequeLeafXFiles[index] = file;
              break;
          }
        });
      }
    } catch (e) {
      print('Error picking nested array file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addFileAttachments(http.MultipartRequest request) async {
    // Helper function to ensure filename has extension
    Future<http.MultipartFile> prepareFile(String field, XFile file) async {
      String filename = path.basename(file.path);
      // Ensure filename has an extension
      if (!filename.contains('.')) {
        // Try to detect mime type and add appropriate extension
        final mimeType = lookupMimeType(file.path);
        if (mimeType != null) {
          String extension = mimeType.split('/').last;
          filename = '$filename.$extension';
        } else {
          filename = '$filename.jpg'; // Default to .jpg
        }
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        return http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
        );
      } else {
        final diskFile = File(file.path);
        return await http.MultipartFile.fromPath(
          field,
          diskFile.path,
          filename: filename,
        );
      }
    }

    // Add PAN attachment only if new file is selected
    if (panAttachmentXFile != null) {
      request.files.add(await prepareFile('pan_attachment', panAttachmentXFile!));
    } else if (existingPanAttachmentUrl != null && existingPanAttachmentUrl!.isNotEmpty) {
      request.fields['pan_attachment'] = existingPanAttachmentUrl!;
    }

    // Add GST attachment
    if (gstAttachmentXFile != null) {
      request.files.add(await prepareFile('gst_attachment', gstAttachmentXFile!));
    } else if (existingGstAttachmentUrl != null && existingGstAttachmentUrl!.isNotEmpty) {
      request.fields['gst_attachment'] = existingGstAttachmentUrl!;
    }

    // Add BIS attachment
    if (bisAttachmentXFile != null) {
      request.files.add(await prepareFile('bis_attachment', bisAttachmentXFile!));
    } else if (existingBisAttachmentUrl != null && existingBisAttachmentUrl!.isNotEmpty) {
      request.fields['bis_attachment'] = existingBisAttachmentUrl!;
    }

    // Add MSME attachment
    if (msmeAttachmentXFile != null) {
      request.files.add(await prepareFile('msme_attachment', msmeAttachmentXFile!));
    } else if (existingMsmeAttachmentUrl != null && existingMsmeAttachmentUrl!.isNotEmpty) {
      request.fields['msme_attachment'] = existingMsmeAttachmentUrl!;
    }

    // Add TAN attachment
    if (tanAttachmentXFile != null) {
      request.files.add(await prepareFile('tan_attachment', tanAttachmentXFile!));
    } else if (existingTanAttachmentUrl != null && existingTanAttachmentUrl!.isNotEmpty) {
      request.fields['tan_attachment'] = existingTanAttachmentUrl!;
    }

    // Add CIN attachment
    if (cinAttachmentXFile != null) {
      request.files.add(await prepareFile('cin_attach', cinAttachmentXFile!));
    } else if (existingCinAttachmentUrl != null && existingCinAttachmentUrl!.isNotEmpty) {
      request.fields['cin_attach'] = existingCinAttachmentUrl!;
    }
  }

  Future<void> _addNestedArrays(http.MultipartRequest request) async {
    // Helper function for nested array files
    Future<http.MultipartFile?> prepareNestedFile(String fieldKey, XFile? file) async {
      if (file == null) return null;
      
      String filename = path.basename(file.path);
      if (!filename.contains('.')) {
        final mimeType = lookupMimeType(file.path);
        if (mimeType != null) {
          String extension = mimeType.split('/').last;
          filename = '$filename.$extension';
        } else {
          filename = '$filename.jpg';
        }
      }

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        return http.MultipartFile.fromBytes(
          fieldKey,
          bytes,
          filename: filename,
        );
      } else {
        final diskFile = File(file.path);
        return await http.MultipartFile.fromPath(
          fieldKey,
          diskFile.path,
          filename: filename,
        );
      }
    }

    // Add aadhar details
    if (editAadharDetailControllers != null) {
      for (int i = 0; i < editAadharDetailControllers!.length; i++) {
        var controllers = editAadharDetailControllers![i];
        String name = controllers['aadhar_name']?.text.trim() ?? '';
        String number = controllers['aadhar_no']?.text.trim() ?? '';
        
        // Add text fields
        if (name.isNotEmpty) {
          request.fields['aadhar_detail[$i][aadhar_name]'] = name;
        }
        if (number.isNotEmpty) {
          request.fields['aadhar_detail[$i][aadhar_no]'] = number;
        }
        
        // Add file attachment if new file is selected
        if (aadharAttachmentXFiles.containsKey(i)) {
          XFile? file = aadharAttachmentXFiles[i];
          if (file != null) {
            var preparedFile = await prepareNestedFile('aadhar_detail[$i][aadhar_attach]', file);
            if (preparedFile != null) {
              request.files.add(preparedFile);
            }
          }
        } else if (i < existingAadharAttachmentUrls.length && 
                   existingAadharAttachmentUrls[i] != null && 
                   existingAadharAttachmentUrls[i]!.isNotEmpty) {
          request.fields['aadhar_detail[$i][aadhar_attach]'] = existingAadharAttachmentUrls[i]!;
        }
      }
    }

    // Add pan details
    if (editPanDetailControllers != null) {
      for (int i = 0; i < editPanDetailControllers!.length; i++) {
        var controllers = editPanDetailControllers![i];
        String name = controllers['pan_name']?.text.trim() ?? '';
        String number = controllers['pan_no']?.text.trim() ?? '';
        
        // Add text fields
        if (name.isNotEmpty) {
          request.fields['pan_detail[$i][pan_name]'] = name;
        }
        if (number.isNotEmpty) {
          request.fields['pan_detail[$i][pan_no]'] = number;
        }
        
        // Add file attachment if new file is selected
        if (panDetailAttachmentXFiles.containsKey(i)) {
          XFile? file = panDetailAttachmentXFiles[i];
          if (file != null) {
            var preparedFile = await prepareNestedFile('pan_detail[$i][pan_attachment]', file);
            if (preparedFile != null) {
              request.files.add(preparedFile);
            }
          }
        } else if (i < existingPanAttachmentUrls.length && 
                   existingPanAttachmentUrls[i] != null && 
                   existingPanAttachmentUrls[i]!.isNotEmpty) {
          request.fields['pan_detail[$i][pan_attachment]'] = existingPanAttachmentUrls[i]!;
        }
      }
    }

    // Add bank details
    if (editBankDetailControllers != null) {
      for (int i = 0; i < editBankDetailControllers!.length; i++) {
        var controllers = editBankDetailControllers![i];
        
        // Add text fields
        if (controllers['bank_name']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][bank_name]'] = controllers['bank_name']!.text.trim();
        }
        if (controllers['account_name']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][account_name]'] = controllers['account_name']!.text.trim();
        }
        if (controllers['account_no']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][account_no]'] = controllers['account_no']!.text.trim();
        }
        if (controllers['ifsc_code']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][ifsc_code]'] = controllers['ifsc_code']!.text.trim();
        }
        if (controllers['branch']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][branch]'] = controllers['branch']!.text.trim();
        }
        if (controllers['bank_city']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][bank_city]'] = controllers['bank_city']!.text.trim();
        }
        if (controllers['bank_state']?.text.trim().isNotEmpty ?? false) {
          request.fields['bank_detail[$i][bank_state]'] = controllers['bank_state']!.text.trim();
        }
        
        // Add file attachment if new file is selected
        if (bankChequeLeafXFiles.containsKey(i)) {
          XFile? file = bankChequeLeafXFiles[i];
          if (file != null) {
            var preparedFile = await prepareNestedFile('bank_detail[$i][cheque_leaf]', file);
            if (preparedFile != null) {
              request.files.add(preparedFile);
            }
          }
        } else if (i < existingChequeLeafUrls.length && 
                   existingChequeLeafUrls[i] != null && 
                   existingChequeLeafUrls[i]!.isNotEmpty) {
          request.fields['bank_detail[$i][cheque_leaf]'] = existingChequeLeafUrls[i]!;
        }
      }
    }
  }

  Future<void> updateKYC(int id) async {
    if (token == null || editControllers == null) return;

    setState(() => isLoading = true);

    try {
      // Use PUT method to update
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Token $token';

      // Add ALL text fields (even empty ones)
      editControllers!.forEach((key, controller) {
        // Skip file attachment fields as text
        if (!key.endsWith('_attachment') && key != 'cin_attach') {
          request.fields[key] = controller.text.trim();
        }
      });

      // Add file attachments - only if new files are selected
      // If no new file is selected, the existing file should be preserved
      await _addFileAttachments(request);

      // Add nested arrays
      await _addNestedArrays(request);

      // Send request
      var response = await request.send();
      
      if (response.statusCode == 200) {
        // Clear all controllers after successful update
        _disposeAllControllers();
        editControllers = null;
        editAadharDetailControllers = null;
        editPanDetailControllers = null;
        editBankDetailControllers = null;
        editingKycId = null;
        
        // Reset all file selections
        _resetFileSelections();
        
        // Clear existing URLs
        existingPanAttachmentUrl = null;
        existingGstAttachmentUrl = null;
        existingBisAttachmentUrl = null;
        existingMsmeAttachmentUrl = null;
        existingTanAttachmentUrl = null;
        existingCinAttachmentUrl = null;
        existingAadharAttachmentUrls.clear();
        existingPanAttachmentUrls.clear();
        existingChequeLeafUrls.clear();
        
        // Refresh the KYC list
        fetchKYCRecords();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KYC updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final responseBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update KYC. Status: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
        print('Error response: $responseBody');
      }
    } catch (e) {
      print('Exception in updateKYC: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFields = getSelectedFields();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('KYC Records'),
        actions: [
          // Field Selection button
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
            onPressed: () => fetchKYCRecords(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : kycRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('No KYC records found'),
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
                              columnSpacing: compactRows ? 15 : 24,
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
                              rows: kycRecords.map((record) {
                                final id = record['id'];
                                final isSelected = selectedIds.contains(id);
                                final bool isCompleted = record['is_completed'] == true;

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

                                    // ACTIONS - Only show if row is selected and based on enableView/enableEdit settings
                                    DataCell(
                                      isSelected
                                          ? Row(
                                              children: [
                                                // View button - Show only if enableView is true
                                                if (enableView)
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        showKYCDetailDialog(record, false),
                                                    child: Text(
                                                      'View',
                                                      style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                
                                                // Edit button - Show only if enableEdit is true AND KYC is not completed
                                                if (enableEdit && !isCompleted) ...[
                                                  if (enableView) SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        showKYCDetailDialog(record, true),
                                                    child: Text(
                                                      'Edit',
                                                      style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                ],
                                                
                                                // Complete/Reopen button - Always show regardless of enableView/enableEdit
                                                if (isSelected) ...[
                                                  if ((enableView || enableEdit) && 
                                                      (enableView || enableEdit)) 
                                                    SizedBox(width: 8),
                                                  ElevatedButton(
                                                    onPressed: () => _showCompletionDialog(record),
                                                    child: Text(
                                                      isCompleted ? 'Reopen' : 'Complete',
                                                      style: TextStyle(fontSize: compactRows ? 11 : 13),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: isCompleted ? Colors.orange : Colors.green,
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            )
                                          : SizedBox.shrink(),
                                    ),

                                    // Selected fields only
                                    ...selectedFields.map((f) {
                                      String displayValue = getFieldValue(record, f['key']);
                                      
                                      // Special handling for attachments
                                      if ((f['key'].endsWith('_attachment') || f['key'] == 'cin_attach') && displayValue.isNotEmpty) {
                                        return DataCell(
                                          GestureDetector(
                                            onTap: () {
                                              final url = record[f['key']];
                                              print('Open file: $url');
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
                                                  Icon(
                                                    f['key'] == 'cin_attach' ? Icons.description : Icons.attachment,
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
                                      
                                      // Special handling for complex fields (arrays)
                                      if (f['isComplex'] == true) {
                                        final details = record[f['key']];
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
                                      
                                      // Special handling for status
                                      if (f['key'] == 'is_completed') {
                                        bool completed = record['is_completed'] == true;
                                        return DataCell(
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: completed ? Colors.green.shade50 : Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  completed ? Icons.lock : Icons.lock_open,
                                                  size: compactRows ? 12 : 14,
                                                  color: completed ? Colors.green : Colors.orange,
                                                ),
                                                SizedBox(width: 2),
                                                Text(
                                                  completed ? 'Completed' : 'In Progress',
                                                  style: TextStyle(
                                                    fontSize: compactRows ? 11 : 13,
                                                    color: completed ? Colors.green.shade800 : Colors.orange.shade800,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
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
                            'Page $currentPage | Total: $totalCount',
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


// class KYCPage extends StatefulWidget {
//   @override
//   _KYCPageState createState() => _KYCPageState();
// }

// class _KYCPageState extends State<KYCPage> {
//   List<Map<String, dynamic>> kycRecords = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   int pageSize = 20;

//   // Filter and sort variables
//   Map<String, String> filterParams = {};
//   String? sortBy;
//   String? sortOrder;

//   // Search query for field selection
//   String fieldSearchQuery = '';
  
//   // List settings variables - REMOVED wrapColumnText
//   bool compactRows = false;
//   bool activeRowHighlighting = false;
//   bool modernCellColoring = false;
//   bool enableEdit = false;
//   bool enableView = false;
  
//   // Scroll controller for horizontal scrolling
//   final ScrollController _horizontalScrollController = ScrollController();
  
//   // Filter field controllers
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController businessNameController = TextEditingController();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController mobileController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController gstNoController = TextEditingController();
//   final TextEditingController panNoController = TextEditingController();
//   final TextEditingController statusController = TextEditingController();
  
//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
//     {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
//     {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
//     {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
//     {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 4},
//     {'key': 'gst_no', 'label': 'GST Number', 'selected': true, 'order': 5},
//     {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 6},
//     {'key': 'pan_no', 'label': 'PAN Number', 'selected': true, 'order': 7},
//     {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 8},
//     {'key': 'bis_name', 'label': 'BIS Name', 'selected': false, 'order': 9},
//     {'key': 'bis_no', 'label': 'BIS Number', 'selected': false, 'order': 10},
//     {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false, 'order': 11},
//     {'key': 'msme_name', 'label': 'MSME Name', 'selected': false, 'order': 12},
//     {'key': 'msme_no', 'label': 'MSME Number', 'selected': false, 'order': 13},
//     {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false, 'order': 14},
//     {'key': 'tan_name', 'label': 'TAN Name', 'selected': false, 'order': 15},
//     {'key': 'tan_no', 'label': 'TAN Number', 'selected': false, 'order': 16},
//     {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false, 'order': 17},
//     {'key': 'cin_name', 'label': 'CIN Name', 'selected': false, 'order': 18},
//     {'key': 'cin_no', 'label': 'CIN Number', 'selected': false, 'order': 19},
//     {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false, 'order': 20},
//     {'key': 'note', 'label': 'Note', 'selected': false, 'order': 21},
//     {'key': 'is_completed', 'label': 'Status', 'selected': true, 'order': 22},
//     {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false, 'isComplex': true, 'order': 23},
//     {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false, 'isComplex': true, 'order': 24},
//     {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false, 'isComplex': true, 'order': 25},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 26},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 27},
//   ];

//   // For editing KYC
//   Map<String, TextEditingController>? editControllers;
//   List<Map<String, TextEditingController>>? editAadharDetailControllers;
//   List<Map<String, TextEditingController>>? editPanDetailControllers;
//   List<Map<String, TextEditingController>>? editBankDetailControllers;
//   int? editingKycId;
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   File? bisAttachmentFile;
//   File? msmeAttachmentFile;
//   File? tanAttachmentFile;
//   File? cinAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;
//   String? bisAttachmentFileName;
//   String? msmeAttachmentFileName;
//   String? tanAttachmentFileName;
//   String? cinAttachmentFileName;
  
//   // Store existing file URLs to preserve them
//   String? existingPanAttachmentUrl;
//   String? existingGstAttachmentUrl;
//   String? existingBisAttachmentUrl;
//   String? existingMsmeAttachmentUrl;
//   String? existingTanAttachmentUrl;
//   String? existingCinAttachmentUrl;
  
//   // For nested array file uploads
//   Map<int, File> aadharAttachmentFiles = {};
//   Map<int, String> aadharAttachmentFileNames = {};
//   Map<int, File> panDetailAttachmentFiles = {};
//   Map<int, String> panDetailAttachmentFileNames = {};
//   Map<int, File> bankChequeLeafFiles = {};
//   Map<int, String> bankChequeLeafFileNames = {};
  
//   // Store existing file URLs for nested arrays
//   List<String?> existingAadharAttachmentUrls = [];
//   List<String?> existingPanAttachmentUrls = [];
//   List<String?> existingChequeLeafUrls = [];

//   @override
//   void initState() {
//     super.initState();
//     loadSavedFieldSelections();
//     loadListSettings();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     _disposeAllControllers();
//     bpCodeController.dispose();
//     businessNameController.dispose();
//     nameController.dispose();
//     mobileController.dispose();
//     emailController.dispose();
//     gstNoController.dispose();
//     panNoController.dispose();
//     statusController.dispose();
    
//     // Dispose scroll controller
//     _horizontalScrollController.dispose();
    
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('kyc_fields');
//     String? savedOrder = prefs.getString('kyc_field_order');
    
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
    
//     await prefs.setString('kyc_fields', json.encode(selections));
    
//     // Save field order
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('kyc_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     setState(() {
//       compactRows = prefs.getBool('kyc_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('kyc_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('kyc_modern_cell_coloring') ?? false;
//       enableEdit = prefs.getBool('kyc_enable_edit') ?? false;
//       enableView = prefs.getBool('kyc_enable_view') ?? false;
//     });
//   }

//   // Save list settings to SharedPreferences
//   Future<void> saveListSettings({
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableEdit,
//     required bool enableView,
//   }) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     await prefs.setBool('kyc_compact_rows', compactRows);
//     await prefs.setBool('kyc_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('kyc_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('kyc_enable_edit', enableEdit);
//     await prefs.setBool('kyc_enable_view', enableView);
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
//         {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
//         {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
//         {'key': 'is_completed', 'label': 'Status', 'selected': true},
//         {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
//         {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
//         {'key': 'bis_name', 'label': 'BIS Name', 'selected': false},
//         {'key': 'bis_no', 'label': 'BIS Number', 'selected': false},
//         {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false},
//         {'key': 'msme_name', 'label': 'MSME Name', 'selected': false},
//         {'key': 'msme_no', 'label': 'MSME Number', 'selected': false},
//         {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false},
//         {'key': 'tan_name', 'label': 'TAN Name', 'selected': false},
//         {'key': 'tan_no', 'label': 'TAN Number', 'selected': false},
//         {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false},
//         {'key': 'cin_name', 'label': 'CIN Name', 'selected': false},
//         {'key': 'cin_no', 'label': 'CIN Number', 'selected': false},
//         {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false},
//         {'key': 'note', 'label': 'Note', 'selected': false},
//         {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false},
//         {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false},
//         {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false},
//         {'key': 'created_at', 'label': 'Created Date', 'selected': false},
//         {'key': 'updated_at', 'label': 'Updated Date', 'selected': false},
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
//     required bool enableEdit,
//     required bool enableView,
//   }) {
//     // Save these settings to SharedPreferences
//     saveListSettings(
//       compactRows: compactRows,
//       activeRowHighlighting: activeRowHighlighting,
//       modernCellColoring: modernCellColoring,
//       enableEdit: enableEdit,
//       enableView: enableView,
//     );
    
//     // Apply the settings to the current view
//     setState(() {
//       this.compactRows = compactRows;
//       this.activeRowHighlighting = activeRowHighlighting;
//       this.modernCellColoring = modernCellColoring;
//       this.enableEdit = enableEdit;
//       this.enableView = enableView;
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
    
//     // Local variables for checkbox states - REMOVED wrapColumnText
//     bool localCompactRows = compactRows;
//     bool localActiveRowHighlighting = activeRowHighlighting;
//     bool localModernCellColoring = modernCellColoring;
//     bool localEnableEdit = enableEdit;
//     bool localEnableView = enableView;
    
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
//                             'Personalize List Columns - KYC Records',
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
                    
//                     // Bottom options section - REMOVED wrapColumnText checkbox
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
//                               SizedBox(width: 32),
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
//                                   {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
//                                   {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
//                                   {'key': 'is_completed', 'label': 'Status', 'selected': true},
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
//                                 localEnableEdit = false;
//                                 localEnableView = false;
                                
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
//                                 'KYC - Field Selection',
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
                              
//                               // Apply other settings - REMOVED wrapColumnText
//                               applyListSettings(
//                                 compactRows: localCompactRows,
//                                 activeRowHighlighting: localActiveRowHighlighting,
//                                 modernCellColoring: localModernCellColoring,
//                                 enableEdit: localEnableEdit,
//                                 enableView: localEnableView,
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
//       return '[${value.length} items]';
//     }
//     return value.toString();
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> record, String key) {
//     final value = record[key];
    
//     if (value == null) return '';
    
//     // Handle complex fields (arrays)
//     if (key == 'aadhar_detail' || key == 'pan_detail' || key == 'bank_detail') {
//       if (value is List) {
//         return '${value.length} items';
//       }
//     }
    
//     // Handle attachments
//     if (key.endsWith('_attachment') || key == 'cin_attach') {
//       if (value.toString().isNotEmpty) {
//         if (key == 'cin_attach') {
//           return '📄 CIN';
//         }
//         return '📎 ' + key.replaceAll('_attachment', '').toUpperCase();
//       }
//     }
    
//     // Handle status
//     if (key == 'is_completed') {
//       return value == true ? '✅ Completed' : '⏳ In Progress';
//     }
    
//     return value.toString();
//   }

//   // Build URL with filter and sort parameters
//   String buildRequestUrl({String? baseUrl}) {
//     Uri uri;
    
//     if (baseUrl != null) {
//       uri = Uri.parse(baseUrl);
//     } else {
//       uri = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/');
//     }
    
//     // Create a new Uri with additional query parameters
//     Map<String, String> queryParams = {};
    
//     // Add existing query parameters from the URL
//     queryParams.addAll(uri.queryParameters);
    
//     // Add filter parameters
//     queryParams.addAll(filterParams);
    
//     // Add sort parameters
//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
      
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }
    
//     // Add page size
//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
    
//     // Rebuild URI with all parameters
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Apply all filters at once
//   Future<void> applyFilters() async {
//     filterParams.clear();
    
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (businessNameController.text.isNotEmpty) {
//       filterParams['business_name'] = businessNameController.text;
//     }
//     if (nameController.text.isNotEmpty) {
//       filterParams['name'] = nameController.text;
//     }
//     if (mobileController.text.isNotEmpty) {
//       filterParams['mobile'] = mobileController.text;
//     }
//     if (emailController.text.isNotEmpty) {
//       filterParams['business_email'] = emailController.text;
//     }
//     if (gstNoController.text.isNotEmpty) {
//       filterParams['gst_no'] = gstNoController.text;
//     }
//     if (panNoController.text.isNotEmpty) {
//       filterParams['pan_no'] = panNoController.text;
//     }
//     if (statusController.text.isNotEmpty) {
//       if (statusController.text.toLowerCase() == 'completed') {
//         filterParams['is_completed'] = 'true';
//       } else if (statusController.text.toLowerCase() == 'in progress') {
//         filterParams['is_completed'] = 'false';
//       }
//     }
    
//     // Reset to first page when applying filters
//     currentPage = 1;
//     await fetchKYCRecords();
//   }

//   // Clear all filters
//   Future<void> clearFilters() async {
//     filterParams.clear();
//     bpCodeController.clear();
//     businessNameController.clear();
//     nameController.clear();
//     mobileController.clear();
//     emailController.clear();
//     gstNoController.clear();
//     panNoController.clear();
//     statusController.clear();
    
//     await fetchKYCRecords();
//   }

//   // Show filter dialog
//   void showFilterDialog() {
//     // Initialize controllers with current filter values
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     businessNameController.text = filterParams['business_name'] ?? '';
//     nameController.text = filterParams['name'] ?? '';
//     mobileController.text = filterParams['mobile'] ?? '';
//     emailController.text = filterParams['business_email'] ?? '';
//     gstNoController.text = filterParams['gst_no'] ?? '';
//     panNoController.text = filterParams['pan_no'] ?? '';
    
//     // Convert boolean filter to text for status
//     if (filterParams.containsKey('is_completed')) {
//       if (filterParams['is_completed'] == 'true') {
//         statusController.text = 'completed';
//       } else if (filterParams['is_completed'] == 'false') {
//         statusController.text = 'in progress';
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Filter KYC Records'),
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
//                       hintText: 'e.g., KYC001',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.code),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: businessNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Business Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.business),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: nameController,
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.person),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: mobileController,
//                     decoration: InputDecoration(
//                       labelText: 'Mobile',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
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
//                     controller: gstNoController,
//                     decoration: InputDecoration(
//                       labelText: 'GST Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.numbers),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: panNoController,
//                     decoration: InputDecoration(
//                       labelText: 'PAN Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.credit_card),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   DropdownButtonFormField<String>(
//                     value: statusController.text.isNotEmpty ? statusController.text : null,
//                     decoration: InputDecoration(
//                       labelText: 'Status',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.info),
//                     ),
//                     items: [
//                       DropdownMenuItem(value: 'completed', child: Text('Completed')),
//                       DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
//                     ],
//                     onChanged: (value) {
//                       statusController.text = value ?? '';
//                     },
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
//     setState(() {
//       sortBy = field;
//       sortOrder = order;
//     });
    
//     // Reset to first page when sorting
//     currentPage = 1;
//     await fetchKYCRecords();
//   }

//   // Clear sort
//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchKYCRecords();
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
//       {'value': 'business_name', 'label': 'Business Name'},
//       {'value': 'name', 'label': 'Name'},
//       {'value': 'mobile', 'label': 'Mobile'},
//       {'value': 'business_email', 'label': 'Email'},
//       {'value': 'gst_no', 'label': 'GST Number'},
//       {'value': 'pan_no', 'label': 'PAN Number'},
//       {'value': 'is_completed', 'label': 'Status'},
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
//                       fetchKYCRecords();
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

//   // Change page size
//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
    
//     // Add page_size to URL
//     filterParams['page_size'] = newSize.toString();
//     await fetchKYCRecords();
//   }

//   void _disposeAllControllers() {
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     if (editAadharDetailControllers != null) {
//       for (var controllers in editAadharDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     if (editPanDetailControllers != null) {
//       for (var controllers in editPanDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     if (editBankDetailControllers != null) {
//       for (var controllers in editBankDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
//   }

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchKYCRecords();
//   }

//   Future<void> fetchKYCRecords({String? url}) async {
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
//           dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
//         }

//         setState(() {
//           kycRecords = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
          
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
          
//           isLoading = false;
//         });
//       } else {
//         setState(() => isLoading = false);
//       }
//     } catch (_) {
//       setState(() => isLoading = false);
//     }
//   }

//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty && currentPage > 1) {
//       currentPage--;
//       fetchKYCRecords(url: prevUrl);
//     }
//   }

//   Future<Map<String, dynamic>> fetchKycDetail(int id) async {
//     if (token == null) throw Exception('No token available');

//     final Uri apiUrl = Uri.parse(
//       'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/detail/$id/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data;
//       } else {
//         throw Exception('Failed to fetch KYC details');
//       }
//     } catch (e) {
//       throw Exception('Error fetching KYC details: $e');
//     }
//   }

//   // Function to mark KYC as completed
//   Future<void> completeKYC(int id, bool completed) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final Uri apiUrl = Uri.parse(
//         'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/complete/$id/',
//       );

//       final response = await http.post(
//         apiUrl,
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({'completed': completed}),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(data['detail'] ?? 'Operation successful'),
//             backgroundColor: Colors.green,
//           ),
//         );
        
//         // Refresh the list to update the status
//         fetchKYCRecords();
//       } else {
//         final errorData = json.decode(response.body);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(errorData['detail'] ?? 'Failed to update KYC status'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // Function to show confirmation dialog for complete/reopen
//   void _showCompletionDialog(Map<String, dynamic> kycRecord) {
//     final id = kycRecord['id'];
//     final bool isCompleted = kycRecord['is_completed'] == true;
//     final String businessName = kycRecord['business_name']?.toString() ?? 'KYC';
//     final String bpCode = kycRecord['bp_code']?.toString() ?? '';

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(isCompleted ? 'Reopen KYC' : 'Complete KYC'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'KYC Details:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text('Business Name: $businessName'),
//             Text('BP Code: $bpCode'),
//             SizedBox(height: 16),
//             Text(
//               isCompleted 
//                 ? 'Are you sure you want to reopen this KYC? This will unlock it for editing.'
//                 : 'Are you sure you want to mark this KYC as completed? This will lock it from further editing.',
//               style: TextStyle(color: Colors.grey[700]),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               await completeKYC(id, !isCompleted);
//             },
//             child: Text(isCompleted ? 'Reopen' : 'Complete'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: isCompleted ? Colors.orange : Colors.green,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
//     if (isEdit) {
//       try {
//         setState(() => isLoading = true);
//         final detailedRecord = await fetchKycDetail(kycRecord['id']);
//         setState(() => isLoading = false);
        
//         _initializeEditMode(detailedRecord);
//       } catch (e) {
//         setState(() => isLoading = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to load KYC details for editing: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text(isEdit ? 'Edit KYC' : 'KYC Details'),
//             content: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Show completion status prominently
//                   if (!isEdit && kycRecord['is_completed'] == true)
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       margin: EdgeInsets.only(bottom: 16),
//                       decoration: BoxDecoration(
//                         color: Colors.green[50],
//                         border: Border.all(color: Colors.green),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.lock, color: Colors.green, size: 20),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'KYC Completed (Locked)',
//                               style: TextStyle(
//                                 color: Colors.green[800],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   if (isEdit && editControllers != null)
//                     ..._buildEditFields(setState)
//                   else
//                     ..._buildViewFields(kycRecord),
                  
//                   if (!isEdit)
//                     ..._buildNestedArraysView(kycRecord),
//                 ],
//               ),
//             ),
//             actions: [
//               if (isEdit)
//                 ElevatedButton(
//                   onPressed: () async {
//                     await updateKYC(editingKycId!);
//                     Navigator.pop(context);
//                   },
//                   child: Text('Save'),
//                 ),
//               TextButton(
//                 onPressed: () {
//                   if (isEdit) {
//                     _disposeAllControllers();
//                     editControllers = null;
//                     editAadharDetailControllers = null;
//                     editPanDetailControllers = null;
//                     editBankDetailControllers = null;
//                     editingKycId = null;
//                     _resetFileSelections();
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

//   void _initializeEditMode(Map<String, dynamic> kycRecord) {
//     editingKycId = kycRecord['id'];
//     editControllers = {};
    
//     // Check if KYC is completed and locked
//     bool isCompleted = kycRecord['is_completed'] == true;
//     if (isCompleted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('KYC is completed and locked. Cannot edit.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
    
//     // Initialize main field controllers
//     for (var field in kycRecord.keys) {
//       if (field.toLowerCase() != 'id' && 
//           field != 'aadhar_detail' && 
//           field != 'pan_detail' && 
//           field != 'bank_detail') {
//         editControllers![field] = TextEditingController(
//           text: kycRecord[field]?.toString() ?? '',
//         );
        
//         // Store existing file URLs to preserve them
//         if (field == 'pan_attachment' && kycRecord[field] != null) {
//           existingPanAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'gst_attachment' && kycRecord[field] != null) {
//           existingGstAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'bis_attachment' && kycRecord[field] != null) {
//           existingBisAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'msme_attachment' && kycRecord[field] != null) {
//           existingMsmeAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'tan_attachment' && kycRecord[field] != null) {
//           existingTanAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'cin_attach' && kycRecord[field] != null) {
//           existingCinAttachmentUrl = kycRecord[field].toString();
//         }
//       }
//     }
    
//     // Initialize aadhar detail controllers
//     editAadharDetailControllers = [];
//     existingAadharAttachmentUrls.clear();
//     if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
//       for (var detail in existingDetails) {
//         editAadharDetailControllers!.add({
//           'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
//           'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
//         });
//         existingAadharAttachmentUrls.add(detail['aadhar_attach']?.toString());
//       }
//     }
    
//     // Initialize pan detail controllers
//     editPanDetailControllers = [];
//     existingPanAttachmentUrls.clear();
//     if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
//       for (var detail in existingDetails) {
//         editPanDetailControllers!.add({
//           'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
//           'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
//         });
//         existingPanAttachmentUrls.add(detail['pan_attachment']?.toString());
//       }
//     }
    
//     // Initialize bank detail controllers
//     editBankDetailControllers = [];
//     existingChequeLeafUrls.clear();
//     if (kycRecord['bank_detail'] != null && kycRecord['bank_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['bank_detail']);
      
//       for (var detail in existingDetails) {
//         editBankDetailControllers!.add({
//           'bank_name': TextEditingController(text: detail['bank_name']?.toString() ?? ''),
//           'account_name': TextEditingController(text: detail['account_name']?.toString() ?? ''),
//           'account_no': TextEditingController(text: detail['account_no']?.toString() ?? ''),
//           'ifsc_code': TextEditingController(text: detail['ifsc_code']?.toString() ?? ''),
//           'branch': TextEditingController(text: detail['branch']?.toString() ?? ''),
//           'bank_city': TextEditingController(text: detail['bank_city']?.toString() ?? ''),
//           'bank_state': TextEditingController(text: detail['bank_state']?.toString() ?? ''),
//         });
//         existingChequeLeafUrls.add(detail['cheque_leaf']?.toString());
//       }
//     }
    
//     _resetFileSelections();
//   }

//   void _resetFileSelections() {
//     panAttachmentFile = null;
//     gstAttachmentFile = null;
//     bisAttachmentFile = null;
//     msmeAttachmentFile = null;
//     tanAttachmentFile = null;
//     cinAttachmentFile = null;
//     panAttachmentFileName = null;
//     gstAttachmentFileName = null;
//     bisAttachmentFileName = null;
//     msmeAttachmentFileName = null;
//     tanAttachmentFileName = null;
//     cinAttachmentFileName = null;
//     aadharAttachmentFiles.clear();
//     aadharAttachmentFileNames.clear();
//     panDetailAttachmentFiles.clear();
//     panDetailAttachmentFileNames.clear();
//     bankChequeLeafFiles.clear();
//     bankChequeLeafFileNames.clear();
//   }

//   List<Widget> _buildEditFields(StateSetter setState) {
//     List<Widget> fields = [];
    
//     if (editControllers == null) return fields;
    
//     List<String> fieldOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     for (var field in fieldOrder) {
//       if (editControllers!.containsKey(field)) {
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildEditFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             currentValue: editControllers![field]!.text,
//             setState: setState,
//           ));
//         } else if (field == 'is_completed') {
//           fields.add(_buildBooleanField(
//             field: field,
//             label: _getFieldLabel(field),
//             setState: setState,
//           ));
//         } else {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: TextField(
//               controller: editControllers![field],
//               decoration: InputDecoration(
//                 labelText: _getFieldLabel(field),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ));
//         }
//       }
//     }
    
//     fields.addAll(_buildNestedArraysEdit(setState));
    
//     return fields;
//   }

//   String _getFieldLabel(String field) {
//     return field
//         .replaceAll('_', ' ')
//         .toUpperCase()
//         .replaceAll('ATTACH', 'ATTACHMENT');
//   }

//   Widget _buildBooleanField({
//     required String field,
//     required String label,
//     required StateSetter setState,
//   }) {
//     bool value = editControllers![field]!.text.toLowerCase() == 'true';
    
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           SizedBox(width: 10),
//           Switch(
//             value: value,
//             onChanged: (newValue) {
//               setState(() {
//                 editControllers![field]!.text = newValue.toString();
//               });
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildViewFields(Map<String, dynamic> kycRecord) {
//     List<Widget> fields = [];
    
//     List<String> displayOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     for (var field in displayOrder) {
//       if (kycRecord.containsKey(field)) {
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             value: kycRecord[field],
//           ));
//         } else if (field == 'is_completed') {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getFieldLabel(field),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(
//                       kycRecord[field] == true ? Icons.lock : Icons.lock_open,
//                       color: kycRecord[field] == true ? Colors.green : Colors.orange,
//                       size: 16,
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       kycRecord[field] == true ? 'Completed (Locked)' : 'In Progress',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: kycRecord[field] == true ? Colors.green : Colors.orange,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ));
//         } else {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getFieldLabel(field),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   kycRecord[field]?.toString() ?? 'Not provided',
//                   style: TextStyle(fontSize: 14),
//                 ),
//               ],
//             ),
//           ));
//         }
//       }
//     }
    
//     return fields;
//   }

//   List<Widget> _buildNestedArraysView(Map<String, dynamic> kycRecord) {
//     List<Widget> arrays = [];
    
//     if (kycRecord['aadhar_detail'] != null && 
//         kycRecord['aadhar_detail'] is List && 
//         (kycRecord['aadhar_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Aadhar Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']),
//         fields: ['aadhar_name', 'aadhar_no'],
//         fileFields: ['aadhar_attach'],
//       ));
//     }
    
//     if (kycRecord['pan_detail'] != null && 
//         kycRecord['pan_detail'] is List && 
//         (kycRecord['pan_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'PAN Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['pan_detail']),
//         fields: ['pan_name', 'pan_no'],
//         fileFields: ['pan_attachment'],
//       ));
//     }
    
//     if (kycRecord['bank_detail'] != null && 
//         kycRecord['bank_detail'] is List && 
//         (kycRecord['bank_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Bank Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['bank_detail']),
//         fields: ['bank_name', 'account_name', 'account_no', 'ifsc_code', 'branch', 'bank_city', 'bank_state'],
//         fileFields: ['cheque_leaf'],
//       ));
//     }
    
//     return arrays;
//   }

//   Widget _buildNestedArraySection({
//     required String title,
//     required List<Map<String, dynamic>> details,
//     required List<String> fields,
//     required List<String> fileFields,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Text(
//           title,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         ),
//         SizedBox(height: 10),
//         ...details.asMap().entries.map((entry) {
//           int index = entry.key;
//           Map<String, dynamic> detail = entry.value;
          
//           return Card(
//             margin: EdgeInsets.symmetric(vertical: 5),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('${title} ${index + 1}', 
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   SizedBox(height: 8),
//                   ...fields.map((field) {
//                     return Padding(
//                       padding: const EdgeInsets.only(bottom: 4),
//                       child: Row(
//                         children: [
//                           Text(
//                             '${field.replaceAll('_', ' ').toUpperCase()}: ',
//                             style: TextStyle(fontWeight: FontWeight.w500),
//                           ),
//                           Expanded(
//                             child: Text(detail[field]?.toString() ?? 'Not provided'),
//                           ),
//                         ],
//                       ),
//                     );
//                   }).toList(),
//                   ...fileFields.map((field) {
//                     final fileUrl = detail[field];
//                     if (fileUrl != null && fileUrl.toString().isNotEmpty) {
//                       return Padding(
//                         padding: const EdgeInsets.only(top: 4),
//                         child: InkWell(
//                           onTap: () {
//                             print('File URL: $fileUrl');
//                           },
//                           child: Row(
//                             children: [
//                               Icon(Icons.attach_file, size: 16, color: Colors.blue),
//                               SizedBox(width: 4),
//                               Text(
//                                 '${field.replaceAll('_', ' ').toUpperCase()}',
//                                 style: TextStyle(
//                                   color: Colors.blue,
//                                   decoration: TextDecoration.underline,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }
//                     return SizedBox.shrink();
//                   }).toList(),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ],
//     );
//   }

//   List<Widget> _buildNestedArraysEdit(StateSetter setState) {
//     List<Widget> arrays = [];
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Aadhar Details',
//       controllersList: editAadharDetailControllers,
//       fields: [
//         {'key': 'aadhar_name', 'label': 'Aadhar Name'},
//         {'key': 'aadhar_no', 'label': 'Aadhar Number'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'aadhar_attach',
//       fileFieldLabel: 'Aadhar Attachment',
//       fileMap: aadharAttachmentFiles,
//       fileNameMap: aadharAttachmentFileNames,
//       existingUrls: existingAadharAttachmentUrls,
//       onAdd: () {
//         setState(() {
//           editAadharDetailControllers ??= [];
//           editAadharDetailControllers!.add({
//             'aadhar_name': TextEditingController(),
//             'aadhar_no': TextEditingController(),
//           });
//           existingAadharAttachmentUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editAadharDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editAadharDetailControllers!.removeAt(index);
//           aadharAttachmentFiles.remove(index);
//           aadharAttachmentFileNames.remove(index);
//           existingAadharAttachmentUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('aadhar', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           aadharAttachmentFiles.remove(index);
//           aadharAttachmentFileNames.remove(index);
//         });
//       },
//     ));
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'PAN Details',
//       controllersList: editPanDetailControllers,
//       fields: [
//         {'key': 'pan_name', 'label': 'PAN Name'},
//         {'key': 'pan_no', 'label': 'PAN Number'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'pan_attachment',
//       fileFieldLabel: 'PAN Attachment',
//       fileMap: panDetailAttachmentFiles,
//       fileNameMap: panDetailAttachmentFileNames,
//       existingUrls: existingPanAttachmentUrls,
//       onAdd: () {
//         setState(() {
//           editPanDetailControllers ??= [];
//           editPanDetailControllers!.add({
//             'pan_name': TextEditingController(),
//             'pan_no': TextEditingController(),
//           });
//           existingPanAttachmentUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editPanDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editPanDetailControllers!.removeAt(index);
//           panDetailAttachmentFiles.remove(index);
//           panDetailAttachmentFileNames.remove(index);
//           existingPanAttachmentUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('pan_detail', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           panDetailAttachmentFiles.remove(index);
//           panDetailAttachmentFileNames.remove(index);
//         });
//       },
//     ));
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Bank Details',
//       controllersList: editBankDetailControllers,
//       fields: [
//         {'key': 'bank_name', 'label': 'Bank Name'},
//         {'key': 'account_name', 'label': 'Account Name'},
//         {'key': 'account_no', 'label': 'Account Number'},
//         {'key': 'ifsc_code', 'label': 'IFSC Code'},
//         {'key': 'branch', 'label': 'Branch'},
//         {'key': 'bank_city', 'label': 'Bank City'},
//         {'key': 'bank_state', 'label': 'Bank State'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'cheque_leaf',
//       fileFieldLabel: 'Cheque Leaf',
//       fileMap: bankChequeLeafFiles,
//       fileNameMap: bankChequeLeafFileNames,
//       existingUrls: existingChequeLeafUrls,
//       onAdd: () {
//         setState(() {
//           editBankDetailControllers ??= [];
//           editBankDetailControllers!.add({
//             'bank_name': TextEditingController(),
//             'account_name': TextEditingController(),
//             'account_no': TextEditingController(),
//             'ifsc_code': TextEditingController(),
//             'branch': TextEditingController(),
//             'bank_city': TextEditingController(),
//             'bank_state': TextEditingController(),
//           });
//           existingChequeLeafUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editBankDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editBankDetailControllers!.removeAt(index);
//           bankChequeLeafFiles.remove(index);
//           bankChequeLeafFileNames.remove(index);
//           existingChequeLeafUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('cheque_leaf', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           bankChequeLeafFiles.remove(index);
//           bankChequeLeafFileNames.remove(index);
//         });
//       },
//     ));
    
//     return arrays;
//   }

//   Widget _buildNestedArrayEditSection({
//     required String title,
//     required List<Map<String, TextEditingController>>? controllersList,
//     required List<Map<String, String>> fields,
//     required bool hasFileAttachment,
//     required String fileFieldKey,
//     required String fileFieldLabel,
//     required Map<int, File> fileMap,
//     required Map<int, String> fileNameMap,
//     required List<String?> existingUrls,
//     required VoidCallback onAdd,
//     required Function(int) onDelete,
//     required Function(int) onPickFile,
//     required Function(int) onClearFile,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             ElevatedButton.icon(
//               onPressed: onAdd,
//               icon: Icon(Icons.add, size: 20),
//               label: Text('Add'),
//             ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         if (controllersList != null)
//           ...controllersList.asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, TextEditingController> controllers = entry.value;
//             String? existingUrl = index < existingUrls.length ? existingUrls[index] : null;
            
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
//                           '${title} ${index + 1}',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           onPressed: () => onDelete(index),
//                         ),
//                       ],
//                     ),
//                     ...fields.map((field) {
//                       return Padding(
//                         padding: const EdgeInsets.only(bottom: 8),
//                         child: TextField(
//                           controller: controllers[field['key']],
//                           decoration: InputDecoration(
//                             labelText: field['label'],
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       );
//                     }).toList(),
                    
//                     if (hasFileAttachment)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 8),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               fileFieldLabel,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
                            
//                             // Show existing file link if exists
//                             if (existingUrl != null && existingUrl.isNotEmpty)
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   InkWell(
//                                     onTap: () {
//                                       print('Existing File URL: $existingUrl');
//                                     },
//                                     child: Text(
//                                       'View Existing Attachment',
//                                       style: TextStyle(
//                                         color: Colors.blue,
//                                         decoration: TextDecoration.underline,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                 ],
//                               ),
                            
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () => onPickFile(index),
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(
//                                       fileNameMap[index] ?? 
//                                       (existingUrl != null && existingUrl.isNotEmpty ? 
//                                         'Keep Existing / Select New' : 
//                                         'Select $fileFieldLabel'),
//                                     ),
//                                   ),
//                                 ),
//                                 if (fileNameMap.containsKey(index))
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () => onClearFile(index),
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//       ],
//     );
//   }

//   Widget _buildFileAttachmentField({
//     required String field,
//     required String label,
//     required String? value,
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
//           if (value != null && value.isNotEmpty)
//             InkWell(
//               onTap: () {
//                 print('File URL: $value');
//               },
//               child: Row(
//                 children: [
//                   Icon(Icons.attach_file, size: 16, color: Colors.blue),
//                   SizedBox(width: 4),
//                   Text(
//                     'View Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             Text('No attachment provided', style: TextStyle(fontSize: 14)),
//         ],
//       ),
//     );
//   }

//   Widget _buildEditFileAttachmentField({
//     required String field,
//     required String label,
//     required String currentValue,
//     required StateSetter setState,
//   }) {
//     // Get existing URL based on field
//     String? existingUrl;
//     switch (field) {
//       case 'pan_attachment':
//         existingUrl = existingPanAttachmentUrl;
//         break;
//       case 'gst_attachment':
//         existingUrl = existingGstAttachmentUrl;
//         break;
//       case 'bis_attachment':
//         existingUrl = existingBisAttachmentUrl;
//         break;
//       case 'msme_attachment':
//         existingUrl = existingMsmeAttachmentUrl;
//         break;
//       case 'tan_attachment':
//         existingUrl = existingTanAttachmentUrl;
//         break;
//       case 'cin_attach':
//         existingUrl = existingCinAttachmentUrl;
//         break;
//     }
    
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
          
//           // Show existing file link if exists
//           if (existingUrl != null && existingUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     print('Existing File URL: $existingUrl');
//                   },
//                   child: Text(
//                     'View Existing Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 8),
//               ],
//             ),
          
//           // File upload for edit mode
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field);
//                     setState(() {});
//                   },
//                   icon: Icon(Icons.attach_file),
//                   label: Text(
//                     _getFileName(field) ?? 
//                     (existingUrl != null && existingUrl.isNotEmpty ? 
//                       'Keep Existing / Select New' : 
//                       'Select File'),
//                   ),
//                 ),
//               ),
//               if (_hasFileSelected(field))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       _clearFileSelection(field);
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   String? _getFileName(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         return panAttachmentFileName;
//       case 'gst_attachment':
//         return gstAttachmentFileName;
//       case 'bis_attachment':
//         return bisAttachmentFileName;
//       case 'msme_attachment':
//         return msmeAttachmentFileName;
//       case 'tan_attachment':
//         return tanAttachmentFileName;
//       case 'cin_attach':
//         return cinAttachmentFileName;
//       default:
//         return null;
//     }
//   }

//   bool _hasFileSelected(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         return panAttachmentFileName != null;
//       case 'gst_attachment':
//         return gstAttachmentFileName != null;
//       case 'bis_attachment':
//         return bisAttachmentFileName != null;
//       case 'msme_attachment':
//         return msmeAttachmentFileName != null;
//       case 'tan_attachment':
//         return tanAttachmentFileName != null;
//       case 'cin_attach':
//         return cinAttachmentFileName != null;
//       default:
//         return false;
//     }
//   }

//   void _clearFileSelection(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         panAttachmentFile = null;
//         panAttachmentFileName = null;
//         break;
//       case 'gst_attachment':
//         gstAttachmentFile = null;
//         gstAttachmentFileName = null;
//         break;
//       case 'bis_attachment':
//         bisAttachmentFile = null;
//         bisAttachmentFileName = null;
//         break;
//       case 'msme_attachment':
//         msmeAttachmentFile = null;
//         msmeAttachmentFileName = null;
//         break;
//       case 'tan_attachment':
//         tanAttachmentFile = null;
//         tanAttachmentFileName = null;
//         break;
//       case 'cin_attach':
//         cinAttachmentFile = null;
//         cinAttachmentFileName = null;
//         break;
//     }
//   }

//   Future<void> pickFile(String field) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         switch (field) {
//           case 'pan_attachment':
//             panAttachmentFile = File(file.path);
//             panAttachmentFileName = path.basename(file.path);
//             break;
//           case 'gst_attachment':
//             gstAttachmentFile = File(file.path);
//             gstAttachmentFileName = path.basename(file.path);
//             break;
//           case 'bis_attachment':
//             bisAttachmentFile = File(file.path);
//             bisAttachmentFileName = path.basename(file.path);
//             break;
//           case 'msme_attachment':
//             msmeAttachmentFile = File(file.path);
//             msmeAttachmentFileName = path.basename(file.path);
//             break;
//           case 'tan_attachment':
//             tanAttachmentFile = File(file.path);
//             tanAttachmentFileName = path.basename(file.path);
//             break;
//           case 'cin_attach':
//             cinAttachmentFile = File(file.path);
//             cinAttachmentFileName = path.basename(file.path);
//             break;
//         }
//       });
//     }
//   }

//   Future<void> pickNestedArrayFile(String type, int index) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         switch (type) {
//           case 'aadhar':
//             aadharAttachmentFiles[index] = File(file.path);
//             aadharAttachmentFileNames[index] = path.basename(file.path);
//             break;
//           case 'pan_detail':
//             panDetailAttachmentFiles[index] = File(file.path);
//             panDetailAttachmentFileNames[index] = path.basename(file.path);
//             break;
//           case 'cheque_leaf':
//             bankChequeLeafFiles[index] = File(file.path);
//             bankChequeLeafFileNames[index] = path.basename(file.path);
//             break;
//         }
//       });
//     }
//   }

//   Future<void> updateKYC(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Use PUT method to update
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add ALL text fields (even empty ones)
//       editControllers!.forEach((key, controller) {
//         // Skip file attachment fields as text
//         if (!key.endsWith('_attachment') && key != 'cin_attach') {
//           request.fields[key] = controller.text.trim();
//         }
//       });

//       // Add file attachments - only if new files are selected
//       // If no new file is selected, the existing file should be preserved
//       await _addFileAttachments(request);

//       // Add nested arrays
//       await _addNestedArrays(request);

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 200) {
//         // Clear all controllers after successful update
//         _disposeAllControllers();
//         editControllers = null;
//         editAadharDetailControllers = null;
//         editPanDetailControllers = null;
//         editBankDetailControllers = null;
//         editingKycId = null;
        
//         // Reset all file selections
//         _resetFileSelections();
        
//         // Clear existing URLs
//         existingPanAttachmentUrl = null;
//         existingGstAttachmentUrl = null;
//         existingBisAttachmentUrl = null;
//         existingMsmeAttachmentUrl = null;
//         existingTanAttachmentUrl = null;
//         existingCinAttachmentUrl = null;
//         existingAadharAttachmentUrls.clear();
//         existingPanAttachmentUrls.clear();
//         existingChequeLeafUrls.clear();
        
//         // Refresh the KYC list
//         fetchKYCRecords();
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('KYC updated successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         final responseBody = await response.stream.bytesToString();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to update KYC. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
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

//   Future<void> _addFileAttachments(http.MultipartRequest request) async {
//     // Add PAN attachment only if new file is selected
//     if (panAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'pan_attachment',
//           panAttachmentFile!.path,
//           filename: panAttachmentFileName,
//         ),
//       );
//     } else if (existingPanAttachmentUrl != null && existingPanAttachmentUrl!.isNotEmpty) {
//       request.fields['pan_attachment'] = existingPanAttachmentUrl!;
//     }

//     // Add GST attachment
//     if (gstAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'gst_attachment',
//           gstAttachmentFile!.path,
//           filename: gstAttachmentFileName,
//         ),
//       );
//     } else if (existingGstAttachmentUrl != null && existingGstAttachmentUrl!.isNotEmpty) {
//       request.fields['gst_attachment'] = existingGstAttachmentUrl!;
//     }

//     // Add BIS attachment
//     if (bisAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'bis_attachment',
//           bisAttachmentFile!.path,
//           filename: bisAttachmentFileName,
//         ),
//       );
//     } else if (existingBisAttachmentUrl != null && existingBisAttachmentUrl!.isNotEmpty) {
//       request.fields['bis_attachment'] = existingBisAttachmentUrl!;
//     }

//     // Add MSME attachment
//     if (msmeAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'msme_attachment',
//           msmeAttachmentFile!.path,
//           filename: msmeAttachmentFileName,
//         ),
//       );
//     } else if (existingMsmeAttachmentUrl != null && existingMsmeAttachmentUrl!.isNotEmpty) {
//       request.fields['msme_attachment'] = existingMsmeAttachmentUrl!;
//     }

//     // Add TAN attachment
//     if (tanAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'tan_attachment',
//           tanAttachmentFile!.path,
//           filename: tanAttachmentFileName,
//         ),
//       );
//     } else if (existingTanAttachmentUrl != null && existingTanAttachmentUrl!.isNotEmpty) {
//       request.fields['tan_attachment'] = existingTanAttachmentUrl!;
//     }

//     // Add CIN attachment
//     if (cinAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'cin_attach',
//           cinAttachmentFile!.path,
//           filename: cinAttachmentFileName,
//         ),
//       );
//     } else if (existingCinAttachmentUrl != null && existingCinAttachmentUrl!.isNotEmpty) {
//       request.fields['cin_attach'] = existingCinAttachmentUrl!;
//     }
//   }

//   Future<void> _addNestedArrays(http.MultipartRequest request) async {
//     // Add aadhar details
//     if (editAadharDetailControllers != null) {
//       for (int i = 0; i < editAadharDetailControllers!.length; i++) {
//         var controllers = editAadharDetailControllers![i];
//         String name = controllers['aadhar_name']?.text.trim() ?? '';
//         String number = controllers['aadhar_no']?.text.trim() ?? '';
        
//         // Add text fields
//         if (name.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_name]'] = name;
//         }
//         if (number.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_no]'] = number;
//         }
        
//         // Add file attachment if new file is selected
//         if (aadharAttachmentFiles.containsKey(i)) {
//           File? file = aadharAttachmentFiles[i];
//           String? filename = aadharAttachmentFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'aadhar_detail[$i][aadhar_attach]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingAadharAttachmentUrls.length && 
//                    existingAadharAttachmentUrls[i] != null && 
//                    existingAadharAttachmentUrls[i]!.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_attach]'] = existingAadharAttachmentUrls[i]!;
//         }
//       }
//     }

//     // Add pan details
//     if (editPanDetailControllers != null) {
//       for (int i = 0; i < editPanDetailControllers!.length; i++) {
//         var controllers = editPanDetailControllers![i];
//         String name = controllers['pan_name']?.text.trim() ?? '';
//         String number = controllers['pan_no']?.text.trim() ?? '';
        
//         // Add text fields
//         if (name.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_name]'] = name;
//         }
//         if (number.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_no]'] = number;
//         }
        
//         // Add file attachment if new file is selected
//         if (panDetailAttachmentFiles.containsKey(i)) {
//           File? file = panDetailAttachmentFiles[i];
//           String? filename = panDetailAttachmentFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'pan_detail[$i][pan_attachment]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingPanAttachmentUrls.length && 
//                    existingPanAttachmentUrls[i] != null && 
//                    existingPanAttachmentUrls[i]!.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_attachment]'] = existingPanAttachmentUrls[i]!;
//         }
//       }
//     }

//     // Add bank details
//     if (editBankDetailControllers != null) {
//       for (int i = 0; i < editBankDetailControllers!.length; i++) {
//         var controllers = editBankDetailControllers![i];
        
//         // Add text fields
//         request.fields['bank_detail[$i][bank_name]'] = controllers['bank_name']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][account_name]'] = controllers['account_name']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][account_no]'] = controllers['account_no']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][ifsc_code]'] = controllers['ifsc_code']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][branch]'] = controllers['branch']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][bank_city]'] = controllers['bank_city']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][bank_state]'] = controllers['bank_state']?.text.trim() ?? '';
        
//         // Add file attachment if new file is selected
//         if (bankChequeLeafFiles.containsKey(i)) {
//           File? file = bankChequeLeafFiles[i];
//           String? filename = bankChequeLeafFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'bank_detail[$i][cheque_leaf]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingChequeLeafUrls.length && 
//                    existingChequeLeafUrls[i] != null && 
//                    existingChequeLeafUrls[i]!.isNotEmpty) {
//           request.fields['bank_detail[$i][cheque_leaf]'] = existingChequeLeafUrls[i]!;
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedFields = getSelectedFields();
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//         actions: [
//           // Field Selection button
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
//             onPressed: () => fetchKYCRecords(),
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('No KYC records found'),
//                       if (filterParams.isNotEmpty) ...[
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
                    
//                     // Show active filters if any
//                     if (filterParams.isNotEmpty)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.blue.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Filters: ${filterParams.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
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
//                               columnSpacing: compactRows ? 15 : 24,
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
//                               rows: kycRecords.map((record) {
//                                 final id = record['id'];
//                                 final isSelected = selectedIds.contains(id);
//                                 final bool isCompleted = record['is_completed'] == true;

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

//                                     // ACTIONS - Only show if row is selected and based on enableView/enableEdit settings
//                                     DataCell(
//                                       isSelected
//                                           ? Row(
//                                               children: [
//                                                 // View button - Show only if enableView is true
//                                                 if (enableView)
//                                                   ElevatedButton(
//                                                     onPressed: () =>
//                                                         showKYCDetailDialog(record, false),
//                                                     child: Text(
//                                                       'View',
//                                                       style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                     ),
//                                                     style: ElevatedButton.styleFrom(
//                                                       padding: EdgeInsets.symmetric(horizontal: 8),
//                                                     ),
//                                                   ),
                                                
//                                                 // Edit button - Show only if enableEdit is true AND KYC is not completed
//                                                 if (enableEdit && !isCompleted) ...[
//                                                   if (enableView) SizedBox(width: 8),
//                                                   ElevatedButton(
//                                                     onPressed: () =>
//                                                         showKYCDetailDialog(record, true),
//                                                     child: Text(
//                                                       'Edit',
//                                                       style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                     ),
//                                                     style: ElevatedButton.styleFrom(
//                                                       padding: EdgeInsets.symmetric(horizontal: 8),
//                                                     ),
//                                                   ),
//                                                 ],
                                                
//                                                 // Complete/Reopen button - Always show regardless of enableView/enableEdit
//                                                 if (isSelected) ...[
//                                                   if ((enableView || enableEdit) && 
//                                                       (enableView || enableEdit)) 
//                                                     SizedBox(width: 8),
//                                                   ElevatedButton(
//                                                     onPressed: () => _showCompletionDialog(record),
//                                                     child: Text(
//                                                       isCompleted ? 'Reopen' : 'Complete',
//                                                       style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                     ),
//                                                     style: ElevatedButton.styleFrom(
//                                                       backgroundColor: isCompleted ? Colors.orange : Colors.green,
//                                                       padding: EdgeInsets.symmetric(horizontal: 8),
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ],
//                                             )
//                                           : SizedBox.shrink(),
//                                     ),

//                                     // Selected fields only
//                                     ...selectedFields.map((f) {
//                                       String displayValue = getFieldValue(record, f['key']);
                                      
//                                       // Special handling for attachments
//                                       if ((f['key'].endsWith('_attachment') || f['key'] == 'cin_attach') && displayValue.isNotEmpty) {
//                                         return DataCell(
//                                           GestureDetector(
//                                             onTap: () {
//                                               final url = record[f['key']];
//                                               print('Open file: $url');
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
//                                                   Icon(
//                                                     f['key'] == 'cin_attach' ? Icons.description : Icons.attachment,
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
                                      
//                                       // Special handling for complex fields (arrays)
//                                       if (f['isComplex'] == true) {
//                                         final details = record[f['key']];
//                                         if (details != null && details is List) {
//                                           return DataCell(
//                                             Container(
//                                               padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                               decoration: BoxDecoration(
//                                                 color: Colors.green.shade50,
//                                                 borderRadius: BorderRadius.circular(4),
//                                               ),
//                                               child: Text(
//                                                 '${details.length} items',
//                                                 style: TextStyle(
//                                                   fontSize: compactRows ? 11 : 13,
//                                                   color: Colors.green.shade800,
//                                                 ),
//                                               ),
//                                             ),
//                                           );
//                                         }
//                                       }
                                      
//                                       // Special handling for status
//                                       if (f['key'] == 'is_completed') {
//                                         bool completed = record['is_completed'] == true;
//                                         return DataCell(
//                                           Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: completed ? Colors.green.shade50 : Colors.orange.shade50,
//                                               borderRadius: BorderRadius.circular(4),
//                                             ),
//                                             child: Row(
//                                               mainAxisSize: MainAxisSize.min,
//                                               children: [
//                                                 Icon(
//                                                   completed ? Icons.lock : Icons.lock_open,
//                                                   size: compactRows ? 12 : 14,
//                                                   color: completed ? Colors.green : Colors.orange,
//                                                 ),
//                                                 SizedBox(width: 2),
//                                                 Text(
//                                                   completed ? 'Completed' : 'In Progress',
//                                                   style: TextStyle(
//                                                     fontSize: compactRows ? 11 : 13,
//                                                     color: completed ? Colors.green.shade800 : Colors.orange.shade800,
//                                                     fontWeight: FontWeight.w500,
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         );
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
//                             'Page $currentPage | Total: $totalCount',
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


// class KYCPage extends StatefulWidget {
//   @override
//   _KYCPageState createState() => _KYCPageState();
// }

// class _KYCPageState extends State<KYCPage> {
//   List<Map<String, dynamic>> kycRecords = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   int pageSize = 20;

//   // Filter and sort variables
//   Map<String, String> filterParams = {};
//   String? sortBy;
//   String? sortOrder;

//   // Search query for field selection
//   String fieldSearchQuery = '';
  
//   // List settings variables - REMOVED wrapColumnText
//   bool compactRows = false;
//   bool activeRowHighlighting = false;
//   bool modernCellColoring = false;
//   bool enableEdit = false;
//   bool enableView = false;
  
//   // Filter field controllers
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController businessNameController = TextEditingController();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController mobileController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController gstNoController = TextEditingController();
//   final TextEditingController panNoController = TextEditingController();
//   final TextEditingController statusController = TextEditingController();
  
//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
//     {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
//     {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
//     {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
//     {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 4},
//     {'key': 'gst_no', 'label': 'GST Number', 'selected': true, 'order': 5},
//     {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 6},
//     {'key': 'pan_no', 'label': 'PAN Number', 'selected': true, 'order': 7},
//     {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 8},
//     {'key': 'bis_name', 'label': 'BIS Name', 'selected': false, 'order': 9},
//     {'key': 'bis_no', 'label': 'BIS Number', 'selected': false, 'order': 10},
//     {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false, 'order': 11},
//     {'key': 'msme_name', 'label': 'MSME Name', 'selected': false, 'order': 12},
//     {'key': 'msme_no', 'label': 'MSME Number', 'selected': false, 'order': 13},
//     {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false, 'order': 14},
//     {'key': 'tan_name', 'label': 'TAN Name', 'selected': false, 'order': 15},
//     {'key': 'tan_no', 'label': 'TAN Number', 'selected': false, 'order': 16},
//     {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false, 'order': 17},
//     {'key': 'cin_name', 'label': 'CIN Name', 'selected': false, 'order': 18},
//     {'key': 'cin_no', 'label': 'CIN Number', 'selected': false, 'order': 19},
//     {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false, 'order': 20},
//     {'key': 'note', 'label': 'Note', 'selected': false, 'order': 21},
//     {'key': 'is_completed', 'label': 'Status', 'selected': true, 'order': 22},
//     {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false, 'isComplex': true, 'order': 23},
//     {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false, 'isComplex': true, 'order': 24},
//     {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false, 'isComplex': true, 'order': 25},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 26},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 27},
//   ];

//   // For editing KYC
//   Map<String, TextEditingController>? editControllers;
//   List<Map<String, TextEditingController>>? editAadharDetailControllers;
//   List<Map<String, TextEditingController>>? editPanDetailControllers;
//   List<Map<String, TextEditingController>>? editBankDetailControllers;
//   int? editingKycId;
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   File? bisAttachmentFile;
//   File? msmeAttachmentFile;
//   File? tanAttachmentFile;
//   File? cinAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;
//   String? bisAttachmentFileName;
//   String? msmeAttachmentFileName;
//   String? tanAttachmentFileName;
//   String? cinAttachmentFileName;
  
//   // Store existing file URLs to preserve them
//   String? existingPanAttachmentUrl;
//   String? existingGstAttachmentUrl;
//   String? existingBisAttachmentUrl;
//   String? existingMsmeAttachmentUrl;
//   String? existingTanAttachmentUrl;
//   String? existingCinAttachmentUrl;
  
//   // For nested array file uploads
//   Map<int, File> aadharAttachmentFiles = {};
//   Map<int, String> aadharAttachmentFileNames = {};
//   Map<int, File> panDetailAttachmentFiles = {};
//   Map<int, String> panDetailAttachmentFileNames = {};
//   Map<int, File> bankChequeLeafFiles = {};
//   Map<int, String> bankChequeLeafFileNames = {};
  
//   // Store existing file URLs for nested arrays
//   List<String?> existingAadharAttachmentUrls = [];
//   List<String?> existingPanAttachmentUrls = [];
//   List<String?> existingChequeLeafUrls = [];

//   @override
//   void initState() {
//     super.initState();
//     loadSavedFieldSelections();
//     loadListSettings();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     _disposeAllControllers();
//     bpCodeController.dispose();
//     businessNameController.dispose();
//     nameController.dispose();
//     mobileController.dispose();
//     emailController.dispose();
//     gstNoController.dispose();
//     panNoController.dispose();
//     statusController.dispose();
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('kyc_fields');
//     String? savedOrder = prefs.getString('kyc_field_order');
    
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
    
//     await prefs.setString('kyc_fields', json.encode(selections));
    
//     // Save field order
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('kyc_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     setState(() {
//       compactRows = prefs.getBool('kyc_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('kyc_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('kyc_modern_cell_coloring') ?? false;
//       enableEdit = prefs.getBool('kyc_enable_edit') ?? false;
//       enableView = prefs.getBool('kyc_enable_view') ?? false;
//     });
//   }

//   // Save list settings to SharedPreferences
//   Future<void> saveListSettings({
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableEdit,
//     required bool enableView,
//   }) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     await prefs.setBool('kyc_compact_rows', compactRows);
//     await prefs.setBool('kyc_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('kyc_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('kyc_enable_edit', enableEdit);
//     await prefs.setBool('kyc_enable_view', enableView);
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
//         {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
//         {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
//         {'key': 'is_completed', 'label': 'Status', 'selected': true},
//         {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
//         {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
//         {'key': 'bis_name', 'label': 'BIS Name', 'selected': false},
//         {'key': 'bis_no', 'label': 'BIS Number', 'selected': false},
//         {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false},
//         {'key': 'msme_name', 'label': 'MSME Name', 'selected': false},
//         {'key': 'msme_no', 'label': 'MSME Number', 'selected': false},
//         {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false},
//         {'key': 'tan_name', 'label': 'TAN Name', 'selected': false},
//         {'key': 'tan_no', 'label': 'TAN Number', 'selected': false},
//         {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false},
//         {'key': 'cin_name', 'label': 'CIN Name', 'selected': false},
//         {'key': 'cin_no', 'label': 'CIN Number', 'selected': false},
//         {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false},
//         {'key': 'note', 'label': 'Note', 'selected': false},
//         {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false},
//         {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false},
//         {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false},
//         {'key': 'created_at', 'label': 'Created Date', 'selected': false},
//         {'key': 'updated_at', 'label': 'Updated Date', 'selected': false},
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
//     required bool enableEdit,
//     required bool enableView,
//   }) {
//     // Save these settings to SharedPreferences
//     saveListSettings(
//       compactRows: compactRows,
//       activeRowHighlighting: activeRowHighlighting,
//       modernCellColoring: modernCellColoring,
//       enableEdit: enableEdit,
//       enableView: enableView,
//     );
    
//     // Apply the settings to the current view
//     setState(() {
//       this.compactRows = compactRows;
//       this.activeRowHighlighting = activeRowHighlighting;
//       this.modernCellColoring = modernCellColoring;
//       this.enableEdit = enableEdit;
//       this.enableView = enableView;
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
    
//     // Local variables for checkbox states - REMOVED wrapColumnText
//     bool localCompactRows = compactRows;
//     bool localActiveRowHighlighting = activeRowHighlighting;
//     bool localModernCellColoring = modernCellColoring;
//     bool localEnableEdit = enableEdit;
//     bool localEnableView = enableView;
    
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
//                             'Personalize List Columns - KYC Records',
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
                    
//                     // Bottom options section - REMOVED wrapColumnText checkbox
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
//                               SizedBox(width: 32),
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
//                                   {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
//                                   {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
//                                   {'key': 'is_completed', 'label': 'Status', 'selected': true},
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
//                                 localEnableEdit = false;
//                                 localEnableView = false;
                                
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
//                                 'KYC - Field Selection',
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
                              
//                               // Apply other settings - REMOVED wrapColumnText
//                               applyListSettings(
//                                 compactRows: localCompactRows,
//                                 activeRowHighlighting: localActiveRowHighlighting,
//                                 modernCellColoring: localModernCellColoring,
//                                 enableEdit: localEnableEdit,
//                                 enableView: localEnableView,
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
//       return '[${value.length} items]';
//     }
//     return value.toString();
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> record, String key) {
//     final value = record[key];
    
//     if (value == null) return '';
    
//     // Handle complex fields (arrays)
//     if (key == 'aadhar_detail' || key == 'pan_detail' || key == 'bank_detail') {
//       if (value is List) {
//         return '${value.length} items';
//       }
//     }
    
//     // Handle attachments
//     if (key.endsWith('_attachment') || key == 'cin_attach') {
//       if (value.toString().isNotEmpty) {
//         if (key == 'cin_attach') {
//           return '📄 CIN';
//         }
//         return '📎 ' + key.replaceAll('_attachment', '').toUpperCase();
//       }
//     }
    
//     // Handle status
//     if (key == 'is_completed') {
//       return value == true ? '✅ Completed' : '⏳ In Progress';
//     }
    
//     return value.toString();
//   }

//   // Build URL with filter and sort parameters
//   String buildRequestUrl({String? baseUrl}) {
//     Uri uri;
    
//     if (baseUrl != null) {
//       uri = Uri.parse(baseUrl);
//     } else {
//       uri = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/');
//     }
    
//     // Create a new Uri with additional query parameters
//     Map<String, String> queryParams = {};
    
//     // Add existing query parameters from the URL
//     queryParams.addAll(uri.queryParameters);
    
//     // Add filter parameters
//     queryParams.addAll(filterParams);
    
//     // Add sort parameters
//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
      
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }
    
//     // Add page size
//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
    
//     // Rebuild URI with all parameters
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Apply all filters at once
//   Future<void> applyFilters() async {
//     filterParams.clear();
    
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (businessNameController.text.isNotEmpty) {
//       filterParams['business_name'] = businessNameController.text;
//     }
//     if (nameController.text.isNotEmpty) {
//       filterParams['name'] = nameController.text;
//     }
//     if (mobileController.text.isNotEmpty) {
//       filterParams['mobile'] = mobileController.text;
//     }
//     if (emailController.text.isNotEmpty) {
//       filterParams['business_email'] = emailController.text;
//     }
//     if (gstNoController.text.isNotEmpty) {
//       filterParams['gst_no'] = gstNoController.text;
//     }
//     if (panNoController.text.isNotEmpty) {
//       filterParams['pan_no'] = panNoController.text;
//     }
//     if (statusController.text.isNotEmpty) {
//       if (statusController.text.toLowerCase() == 'completed') {
//         filterParams['is_completed'] = 'true';
//       } else if (statusController.text.toLowerCase() == 'in progress') {
//         filterParams['is_completed'] = 'false';
//       }
//     }
    
//     // Reset to first page when applying filters
//     currentPage = 1;
//     await fetchKYCRecords();
//   }

//   // Clear all filters
//   Future<void> clearFilters() async {
//     filterParams.clear();
//     bpCodeController.clear();
//     businessNameController.clear();
//     nameController.clear();
//     mobileController.clear();
//     emailController.clear();
//     gstNoController.clear();
//     panNoController.clear();
//     statusController.clear();
    
//     await fetchKYCRecords();
//   }

//   // Show filter dialog
//   void showFilterDialog() {
//     // Initialize controllers with current filter values
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     businessNameController.text = filterParams['business_name'] ?? '';
//     nameController.text = filterParams['name'] ?? '';
//     mobileController.text = filterParams['mobile'] ?? '';
//     emailController.text = filterParams['business_email'] ?? '';
//     gstNoController.text = filterParams['gst_no'] ?? '';
//     panNoController.text = filterParams['pan_no'] ?? '';
    
//     // Convert boolean filter to text for status
//     if (filterParams.containsKey('is_completed')) {
//       if (filterParams['is_completed'] == 'true') {
//         statusController.text = 'completed';
//       } else if (filterParams['is_completed'] == 'false') {
//         statusController.text = 'in progress';
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Filter KYC Records'),
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
//                       hintText: 'e.g., KYC001',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.code),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: businessNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Business Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.business),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: nameController,
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.person),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: mobileController,
//                     decoration: InputDecoration(
//                       labelText: 'Mobile',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
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
//                     controller: gstNoController,
//                     decoration: InputDecoration(
//                       labelText: 'GST Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.numbers),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: panNoController,
//                     decoration: InputDecoration(
//                       labelText: 'PAN Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.credit_card),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   DropdownButtonFormField<String>(
//                     value: statusController.text.isNotEmpty ? statusController.text : null,
//                     decoration: InputDecoration(
//                       labelText: 'Status',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.info),
//                     ),
//                     items: [
//                       DropdownMenuItem(value: 'completed', child: Text('Completed')),
//                       DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
//                     ],
//                     onChanged: (value) {
//                       statusController.text = value ?? '';
//                     },
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
//     setState(() {
//       sortBy = field;
//       sortOrder = order;
//     });
    
//     // Reset to first page when sorting
//     currentPage = 1;
//     await fetchKYCRecords();
//   }

//   // Clear sort
//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchKYCRecords();
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
//       {'value': 'business_name', 'label': 'Business Name'},
//       {'value': 'name', 'label': 'Name'},
//       {'value': 'mobile', 'label': 'Mobile'},
//       {'value': 'business_email', 'label': 'Email'},
//       {'value': 'gst_no', 'label': 'GST Number'},
//       {'value': 'pan_no', 'label': 'PAN Number'},
//       {'value': 'is_completed', 'label': 'Status'},
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
//                       fetchKYCRecords();
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

//   // Change page size
//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
    
//     // Add page_size to URL
//     filterParams['page_size'] = newSize.toString();
//     await fetchKYCRecords();
//   }

//   void _disposeAllControllers() {
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     if (editAadharDetailControllers != null) {
//       for (var controllers in editAadharDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     if (editPanDetailControllers != null) {
//       for (var controllers in editPanDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     if (editBankDetailControllers != null) {
//       for (var controllers in editBankDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
//   }

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchKYCRecords();
//   }

//   Future<void> fetchKYCRecords({String? url}) async {
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
//           dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
//         }

//         setState(() {
//           kycRecords = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
          
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
          
//           isLoading = false;
//         });
//       } else {
//         setState(() => isLoading = false);
//       }
//     } catch (_) {
//       setState(() => isLoading = false);
//     }
//   }

//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty && currentPage > 1) {
//       currentPage--;
//       fetchKYCRecords(url: prevUrl);
//     }
//   }

//   Future<Map<String, dynamic>> fetchKycDetail(int id) async {
//     if (token == null) throw Exception('No token available');

//     final Uri apiUrl = Uri.parse(
//       'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/detail/$id/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data;
//       } else {
//         throw Exception('Failed to fetch KYC details');
//       }
//     } catch (e) {
//       throw Exception('Error fetching KYC details: $e');
//     }
//   }

//   // Function to mark KYC as completed
//   Future<void> completeKYC(int id, bool completed) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final Uri apiUrl = Uri.parse(
//         'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/complete/$id/',
//       );

//       final response = await http.post(
//         apiUrl,
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({'completed': completed}),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(data['detail'] ?? 'Operation successful'),
//             backgroundColor: Colors.green,
//           ),
//         );
        
//         // Refresh the list to update the status
//         fetchKYCRecords();
//       } else {
//         final errorData = json.decode(response.body);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(errorData['detail'] ?? 'Failed to update KYC status'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // Function to show confirmation dialog for complete/reopen
//   void _showCompletionDialog(Map<String, dynamic> kycRecord) {
//     final id = kycRecord['id'];
//     final bool isCompleted = kycRecord['is_completed'] == true;
//     final String businessName = kycRecord['business_name']?.toString() ?? 'KYC';
//     final String bpCode = kycRecord['bp_code']?.toString() ?? '';

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(isCompleted ? 'Reopen KYC' : 'Complete KYC'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'KYC Details:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text('Business Name: $businessName'),
//             Text('BP Code: $bpCode'),
//             SizedBox(height: 16),
//             Text(
//               isCompleted 
//                 ? 'Are you sure you want to reopen this KYC? This will unlock it for editing.'
//                 : 'Are you sure you want to mark this KYC as completed? This will lock it from further editing.',
//               style: TextStyle(color: Colors.grey[700]),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               await completeKYC(id, !isCompleted);
//             },
//             child: Text(isCompleted ? 'Reopen' : 'Complete'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: isCompleted ? Colors.orange : Colors.green,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
//     if (isEdit) {
//       try {
//         setState(() => isLoading = true);
//         final detailedRecord = await fetchKycDetail(kycRecord['id']);
//         setState(() => isLoading = false);
        
//         _initializeEditMode(detailedRecord);
//       } catch (e) {
//         setState(() => isLoading = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to load KYC details for editing: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text(isEdit ? 'Edit KYC' : 'KYC Details'),
//             content: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Show completion status prominently
//                   if (!isEdit && kycRecord['is_completed'] == true)
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       margin: EdgeInsets.only(bottom: 16),
//                       decoration: BoxDecoration(
//                         color: Colors.green[50],
//                         border: Border.all(color: Colors.green),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.lock, color: Colors.green, size: 20),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'KYC Completed (Locked)',
//                               style: TextStyle(
//                                 color: Colors.green[800],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   if (isEdit && editControllers != null)
//                     ..._buildEditFields(setState)
//                   else
//                     ..._buildViewFields(kycRecord),
                  
//                   if (!isEdit)
//                     ..._buildNestedArraysView(kycRecord),
//                 ],
//               ),
//             ),
//             actions: [
//               if (isEdit)
//                 ElevatedButton(
//                   onPressed: () async {
//                     await updateKYC(editingKycId!);
//                     Navigator.pop(context);
//                   },
//                   child: Text('Save'),
//                 ),
//               TextButton(
//                 onPressed: () {
//                   if (isEdit) {
//                     _disposeAllControllers();
//                     editControllers = null;
//                     editAadharDetailControllers = null;
//                     editPanDetailControllers = null;
//                     editBankDetailControllers = null;
//                     editingKycId = null;
//                     _resetFileSelections();
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

//   void _initializeEditMode(Map<String, dynamic> kycRecord) {
//     editingKycId = kycRecord['id'];
//     editControllers = {};
    
//     // Check if KYC is completed and locked
//     bool isCompleted = kycRecord['is_completed'] == true;
//     if (isCompleted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('KYC is completed and locked. Cannot edit.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
    
//     // Initialize main field controllers
//     for (var field in kycRecord.keys) {
//       if (field.toLowerCase() != 'id' && 
//           field != 'aadhar_detail' && 
//           field != 'pan_detail' && 
//           field != 'bank_detail') {
//         editControllers![field] = TextEditingController(
//           text: kycRecord[field]?.toString() ?? '',
//         );
        
//         // Store existing file URLs to preserve them
//         if (field == 'pan_attachment' && kycRecord[field] != null) {
//           existingPanAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'gst_attachment' && kycRecord[field] != null) {
//           existingGstAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'bis_attachment' && kycRecord[field] != null) {
//           existingBisAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'msme_attachment' && kycRecord[field] != null) {
//           existingMsmeAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'tan_attachment' && kycRecord[field] != null) {
//           existingTanAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'cin_attach' && kycRecord[field] != null) {
//           existingCinAttachmentUrl = kycRecord[field].toString();
//         }
//       }
//     }
    
//     // Initialize aadhar detail controllers
//     editAadharDetailControllers = [];
//     existingAadharAttachmentUrls.clear();
//     if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
//       for (var detail in existingDetails) {
//         editAadharDetailControllers!.add({
//           'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
//           'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
//         });
//         existingAadharAttachmentUrls.add(detail['aadhar_attach']?.toString());
//       }
//     }
    
//     // Initialize pan detail controllers
//     editPanDetailControllers = [];
//     existingPanAttachmentUrls.clear();
//     if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
//       for (var detail in existingDetails) {
//         editPanDetailControllers!.add({
//           'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
//           'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
//         });
//         existingPanAttachmentUrls.add(detail['pan_attachment']?.toString());
//       }
//     }
    
//     // Initialize bank detail controllers
//     editBankDetailControllers = [];
//     existingChequeLeafUrls.clear();
//     if (kycRecord['bank_detail'] != null && kycRecord['bank_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['bank_detail']);
      
//       for (var detail in existingDetails) {
//         editBankDetailControllers!.add({
//           'bank_name': TextEditingController(text: detail['bank_name']?.toString() ?? ''),
//           'account_name': TextEditingController(text: detail['account_name']?.toString() ?? ''),
//           'account_no': TextEditingController(text: detail['account_no']?.toString() ?? ''),
//           'ifsc_code': TextEditingController(text: detail['ifsc_code']?.toString() ?? ''),
//           'branch': TextEditingController(text: detail['branch']?.toString() ?? ''),
//           'bank_city': TextEditingController(text: detail['bank_city']?.toString() ?? ''),
//           'bank_state': TextEditingController(text: detail['bank_state']?.toString() ?? ''),
//         });
//         existingChequeLeafUrls.add(detail['cheque_leaf']?.toString());
//       }
//     }
    
//     _resetFileSelections();
//   }

//   void _resetFileSelections() {
//     panAttachmentFile = null;
//     gstAttachmentFile = null;
//     bisAttachmentFile = null;
//     msmeAttachmentFile = null;
//     tanAttachmentFile = null;
//     cinAttachmentFile = null;
//     panAttachmentFileName = null;
//     gstAttachmentFileName = null;
//     bisAttachmentFileName = null;
//     msmeAttachmentFileName = null;
//     tanAttachmentFileName = null;
//     cinAttachmentFileName = null;
//     aadharAttachmentFiles.clear();
//     aadharAttachmentFileNames.clear();
//     panDetailAttachmentFiles.clear();
//     panDetailAttachmentFileNames.clear();
//     bankChequeLeafFiles.clear();
//     bankChequeLeafFileNames.clear();
//   }

//   List<Widget> _buildEditFields(StateSetter setState) {
//     List<Widget> fields = [];
    
//     if (editControllers == null) return fields;
    
//     List<String> fieldOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     for (var field in fieldOrder) {
//       if (editControllers!.containsKey(field)) {
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildEditFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             currentValue: editControllers![field]!.text,
//             setState: setState,
//           ));
//         } else if (field == 'is_completed') {
//           fields.add(_buildBooleanField(
//             field: field,
//             label: _getFieldLabel(field),
//             setState: setState,
//           ));
//         } else {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: TextField(
//               controller: editControllers![field],
//               decoration: InputDecoration(
//                 labelText: _getFieldLabel(field),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ));
//         }
//       }
//     }
    
//     fields.addAll(_buildNestedArraysEdit(setState));
    
//     return fields;
//   }

//   String _getFieldLabel(String field) {
//     return field
//         .replaceAll('_', ' ')
//         .toUpperCase()
//         .replaceAll('ATTACH', 'ATTACHMENT');
//   }

//   Widget _buildBooleanField({
//     required String field,
//     required String label,
//     required StateSetter setState,
//   }) {
//     bool value = editControllers![field]!.text.toLowerCase() == 'true';
    
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           SizedBox(width: 10),
//           Switch(
//             value: value,
//             onChanged: (newValue) {
//               setState(() {
//                 editControllers![field]!.text = newValue.toString();
//               });
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildViewFields(Map<String, dynamic> kycRecord) {
//     List<Widget> fields = [];
    
//     List<String> displayOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     for (var field in displayOrder) {
//       if (kycRecord.containsKey(field)) {
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             value: kycRecord[field],
//           ));
//         } else if (field == 'is_completed') {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getFieldLabel(field),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(
//                       kycRecord[field] == true ? Icons.lock : Icons.lock_open,
//                       color: kycRecord[field] == true ? Colors.green : Colors.orange,
//                       size: 16,
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       kycRecord[field] == true ? 'Completed (Locked)' : 'In Progress',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: kycRecord[field] == true ? Colors.green : Colors.orange,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ));
//         } else {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getFieldLabel(field),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   kycRecord[field]?.toString() ?? 'Not provided',
//                   style: TextStyle(fontSize: 14),
//                 ),
//               ],
//             ),
//           ));
//         }
//       }
//     }
    
//     return fields;
//   }

//   List<Widget> _buildNestedArraysView(Map<String, dynamic> kycRecord) {
//     List<Widget> arrays = [];
    
//     if (kycRecord['aadhar_detail'] != null && 
//         kycRecord['aadhar_detail'] is List && 
//         (kycRecord['aadhar_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Aadhar Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']),
//         fields: ['aadhar_name', 'aadhar_no'],
//         fileFields: ['aadhar_attach'],
//       ));
//     }
    
//     if (kycRecord['pan_detail'] != null && 
//         kycRecord['pan_detail'] is List && 
//         (kycRecord['pan_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'PAN Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['pan_detail']),
//         fields: ['pan_name', 'pan_no'],
//         fileFields: ['pan_attachment'],
//       ));
//     }
    
//     if (kycRecord['bank_detail'] != null && 
//         kycRecord['bank_detail'] is List && 
//         (kycRecord['bank_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Bank Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['bank_detail']),
//         fields: ['bank_name', 'account_name', 'account_no', 'ifsc_code', 'branch', 'bank_city', 'bank_state'],
//         fileFields: ['cheque_leaf'],
//       ));
//     }
    
//     return arrays;
//   }

//   Widget _buildNestedArraySection({
//     required String title,
//     required List<Map<String, dynamic>> details,
//     required List<String> fields,
//     required List<String> fileFields,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Text(
//           title,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         ),
//         SizedBox(height: 10),
//         ...details.asMap().entries.map((entry) {
//           int index = entry.key;
//           Map<String, dynamic> detail = entry.value;
          
//           return Card(
//             margin: EdgeInsets.symmetric(vertical: 5),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('${title} ${index + 1}', 
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   SizedBox(height: 8),
//                   ...fields.map((field) {
//                     return Padding(
//                       padding: const EdgeInsets.only(bottom: 4),
//                       child: Row(
//                         children: [
//                           Text(
//                             '${field.replaceAll('_', ' ').toUpperCase()}: ',
//                             style: TextStyle(fontWeight: FontWeight.w500),
//                           ),
//                           Expanded(
//                             child: Text(detail[field]?.toString() ?? 'Not provided'),
//                           ),
//                         ],
//                       ),
//                     );
//                   }).toList(),
//                   ...fileFields.map((field) {
//                     final fileUrl = detail[field];
//                     if (fileUrl != null && fileUrl.toString().isNotEmpty) {
//                       return Padding(
//                         padding: const EdgeInsets.only(top: 4),
//                         child: InkWell(
//                           onTap: () {
//                             print('File URL: $fileUrl');
//                           },
//                           child: Row(
//                             children: [
//                               Icon(Icons.attach_file, size: 16, color: Colors.blue),
//                               SizedBox(width: 4),
//                               Text(
//                                 '${field.replaceAll('_', ' ').toUpperCase()}',
//                                 style: TextStyle(
//                                   color: Colors.blue,
//                                   decoration: TextDecoration.underline,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }
//                     return SizedBox.shrink();
//                   }).toList(),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ],
//     );
//   }

//   List<Widget> _buildNestedArraysEdit(StateSetter setState) {
//     List<Widget> arrays = [];
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Aadhar Details',
//       controllersList: editAadharDetailControllers,
//       fields: [
//         {'key': 'aadhar_name', 'label': 'Aadhar Name'},
//         {'key': 'aadhar_no', 'label': 'Aadhar Number'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'aadhar_attach',
//       fileFieldLabel: 'Aadhar Attachment',
//       fileMap: aadharAttachmentFiles,
//       fileNameMap: aadharAttachmentFileNames,
//       existingUrls: existingAadharAttachmentUrls,
//       onAdd: () {
//         setState(() {
//           editAadharDetailControllers ??= [];
//           editAadharDetailControllers!.add({
//             'aadhar_name': TextEditingController(),
//             'aadhar_no': TextEditingController(),
//           });
//           existingAadharAttachmentUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editAadharDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editAadharDetailControllers!.removeAt(index);
//           aadharAttachmentFiles.remove(index);
//           aadharAttachmentFileNames.remove(index);
//           existingAadharAttachmentUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('aadhar', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           aadharAttachmentFiles.remove(index);
//           aadharAttachmentFileNames.remove(index);
//         });
//       },
//     ));
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'PAN Details',
//       controllersList: editPanDetailControllers,
//       fields: [
//         {'key': 'pan_name', 'label': 'PAN Name'},
//         {'key': 'pan_no', 'label': 'PAN Number'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'pan_attachment',
//       fileFieldLabel: 'PAN Attachment',
//       fileMap: panDetailAttachmentFiles,
//       fileNameMap: panDetailAttachmentFileNames,
//       existingUrls: existingPanAttachmentUrls,
//       onAdd: () {
//         setState(() {
//           editPanDetailControllers ??= [];
//           editPanDetailControllers!.add({
//             'pan_name': TextEditingController(),
//             'pan_no': TextEditingController(),
//           });
//           existingPanAttachmentUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editPanDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editPanDetailControllers!.removeAt(index);
//           panDetailAttachmentFiles.remove(index);
//           panDetailAttachmentFileNames.remove(index);
//           existingPanAttachmentUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('pan_detail', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           panDetailAttachmentFiles.remove(index);
//           panDetailAttachmentFileNames.remove(index);
//         });
//       },
//     ));
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Bank Details',
//       controllersList: editBankDetailControllers,
//       fields: [
//         {'key': 'bank_name', 'label': 'Bank Name'},
//         {'key': 'account_name', 'label': 'Account Name'},
//         {'key': 'account_no', 'label': 'Account Number'},
//         {'key': 'ifsc_code', 'label': 'IFSC Code'},
//         {'key': 'branch', 'label': 'Branch'},
//         {'key': 'bank_city', 'label': 'Bank City'},
//         {'key': 'bank_state', 'label': 'Bank State'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'cheque_leaf',
//       fileFieldLabel: 'Cheque Leaf',
//       fileMap: bankChequeLeafFiles,
//       fileNameMap: bankChequeLeafFileNames,
//       existingUrls: existingChequeLeafUrls,
//       onAdd: () {
//         setState(() {
//           editBankDetailControllers ??= [];
//           editBankDetailControllers!.add({
//             'bank_name': TextEditingController(),
//             'account_name': TextEditingController(),
//             'account_no': TextEditingController(),
//             'ifsc_code': TextEditingController(),
//             'branch': TextEditingController(),
//             'bank_city': TextEditingController(),
//             'bank_state': TextEditingController(),
//           });
//           existingChequeLeafUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editBankDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editBankDetailControllers!.removeAt(index);
//           bankChequeLeafFiles.remove(index);
//           bankChequeLeafFileNames.remove(index);
//           existingChequeLeafUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('cheque_leaf', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           bankChequeLeafFiles.remove(index);
//           bankChequeLeafFileNames.remove(index);
//         });
//       },
//     ));
    
//     return arrays;
//   }

//   Widget _buildNestedArrayEditSection({
//     required String title,
//     required List<Map<String, TextEditingController>>? controllersList,
//     required List<Map<String, String>> fields,
//     required bool hasFileAttachment,
//     required String fileFieldKey,
//     required String fileFieldLabel,
//     required Map<int, File> fileMap,
//     required Map<int, String> fileNameMap,
//     required List<String?> existingUrls,
//     required VoidCallback onAdd,
//     required Function(int) onDelete,
//     required Function(int) onPickFile,
//     required Function(int) onClearFile,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             ElevatedButton.icon(
//               onPressed: onAdd,
//               icon: Icon(Icons.add, size: 20),
//               label: Text('Add'),
//             ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         if (controllersList != null)
//           ...controllersList.asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, TextEditingController> controllers = entry.value;
//             String? existingUrl = index < existingUrls.length ? existingUrls[index] : null;
            
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
//                           '${title} ${index + 1}',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           onPressed: () => onDelete(index),
//                         ),
//                       ],
//                     ),
//                     ...fields.map((field) {
//                       return Padding(
//                         padding: const EdgeInsets.only(bottom: 8),
//                         child: TextField(
//                           controller: controllers[field['key']],
//                           decoration: InputDecoration(
//                             labelText: field['label'],
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       );
//                     }).toList(),
                    
//                     if (hasFileAttachment)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 8),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               fileFieldLabel,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
                            
//                             // Show existing file link if exists
//                             if (existingUrl != null && existingUrl.isNotEmpty)
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   InkWell(
//                                     onTap: () {
//                                       print('Existing File URL: $existingUrl');
//                                     },
//                                     child: Text(
//                                       'View Existing Attachment',
//                                       style: TextStyle(
//                                         color: Colors.blue,
//                                         decoration: TextDecoration.underline,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                 ],
//                               ),
                            
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () => onPickFile(index),
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(
//                                       fileNameMap[index] ?? 
//                                       (existingUrl != null && existingUrl.isNotEmpty ? 
//                                         'Keep Existing / Select New' : 
//                                         'Select $fileFieldLabel'),
//                                     ),
//                                   ),
//                                 ),
//                                 if (fileNameMap.containsKey(index))
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () => onClearFile(index),
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//       ],
//     );
//   }

//   Widget _buildFileAttachmentField({
//     required String field,
//     required String label,
//     required String? value,
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
//           if (value != null && value.isNotEmpty)
//             InkWell(
//               onTap: () {
//                 print('File URL: $value');
//               },
//               child: Row(
//                 children: [
//                   Icon(Icons.attach_file, size: 16, color: Colors.blue),
//                   SizedBox(width: 4),
//                   Text(
//                     'View Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             Text('No attachment provided', style: TextStyle(fontSize: 14)),
//         ],
//       ),
//     );
//   }

//   Widget _buildEditFileAttachmentField({
//     required String field,
//     required String label,
//     required String currentValue,
//     required StateSetter setState,
//   }) {
//     // Get existing URL based on field
//     String? existingUrl;
//     switch (field) {
//       case 'pan_attachment':
//         existingUrl = existingPanAttachmentUrl;
//         break;
//       case 'gst_attachment':
//         existingUrl = existingGstAttachmentUrl;
//         break;
//       case 'bis_attachment':
//         existingUrl = existingBisAttachmentUrl;
//         break;
//       case 'msme_attachment':
//         existingUrl = existingMsmeAttachmentUrl;
//         break;
//       case 'tan_attachment':
//         existingUrl = existingTanAttachmentUrl;
//         break;
//       case 'cin_attach':
//         existingUrl = existingCinAttachmentUrl;
//         break;
//     }
    
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
          
//           // Show existing file link if exists
//           if (existingUrl != null && existingUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     print('Existing File URL: $existingUrl');
//                   },
//                   child: Text(
//                     'View Existing Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 8),
//               ],
//             ),
          
//           // File upload for edit mode
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field);
//                     setState(() {});
//                   },
//                   icon: Icon(Icons.attach_file),
//                   label: Text(
//                     _getFileName(field) ?? 
//                     (existingUrl != null && existingUrl.isNotEmpty ? 
//                       'Keep Existing / Select New' : 
//                       'Select File'),
//                   ),
//                 ),
//               ),
//               if (_hasFileSelected(field))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       _clearFileSelection(field);
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   String? _getFileName(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         return panAttachmentFileName;
//       case 'gst_attachment':
//         return gstAttachmentFileName;
//       case 'bis_attachment':
//         return bisAttachmentFileName;
//       case 'msme_attachment':
//         return msmeAttachmentFileName;
//       case 'tan_attachment':
//         return tanAttachmentFileName;
//       case 'cin_attach':
//         return cinAttachmentFileName;
//       default:
//         return null;
//     }
//   }

//   bool _hasFileSelected(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         return panAttachmentFileName != null;
//       case 'gst_attachment':
//         return gstAttachmentFileName != null;
//       case 'bis_attachment':
//         return bisAttachmentFileName != null;
//       case 'msme_attachment':
//         return msmeAttachmentFileName != null;
//       case 'tan_attachment':
//         return tanAttachmentFileName != null;
//       case 'cin_attach':
//         return cinAttachmentFileName != null;
//       default:
//         return false;
//     }
//   }

//   void _clearFileSelection(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         panAttachmentFile = null;
//         panAttachmentFileName = null;
//         break;
//       case 'gst_attachment':
//         gstAttachmentFile = null;
//         gstAttachmentFileName = null;
//         break;
//       case 'bis_attachment':
//         bisAttachmentFile = null;
//         bisAttachmentFileName = null;
//         break;
//       case 'msme_attachment':
//         msmeAttachmentFile = null;
//         msmeAttachmentFileName = null;
//         break;
//       case 'tan_attachment':
//         tanAttachmentFile = null;
//         tanAttachmentFileName = null;
//         break;
//       case 'cin_attach':
//         cinAttachmentFile = null;
//         cinAttachmentFileName = null;
//         break;
//     }
//   }

//   Future<void> pickFile(String field) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         switch (field) {
//           case 'pan_attachment':
//             panAttachmentFile = File(file.path);
//             panAttachmentFileName = path.basename(file.path);
//             break;
//           case 'gst_attachment':
//             gstAttachmentFile = File(file.path);
//             gstAttachmentFileName = path.basename(file.path);
//             break;
//           case 'bis_attachment':
//             bisAttachmentFile = File(file.path);
//             bisAttachmentFileName = path.basename(file.path);
//             break;
//           case 'msme_attachment':
//             msmeAttachmentFile = File(file.path);
//             msmeAttachmentFileName = path.basename(file.path);
//             break;
//           case 'tan_attachment':
//             tanAttachmentFile = File(file.path);
//             tanAttachmentFileName = path.basename(file.path);
//             break;
//           case 'cin_attach':
//             cinAttachmentFile = File(file.path);
//             cinAttachmentFileName = path.basename(file.path);
//             break;
//         }
//       });
//     }
//   }

//   Future<void> pickNestedArrayFile(String type, int index) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         switch (type) {
//           case 'aadhar':
//             aadharAttachmentFiles[index] = File(file.path);
//             aadharAttachmentFileNames[index] = path.basename(file.path);
//             break;
//           case 'pan_detail':
//             panDetailAttachmentFiles[index] = File(file.path);
//             panDetailAttachmentFileNames[index] = path.basename(file.path);
//             break;
//           case 'cheque_leaf':
//             bankChequeLeafFiles[index] = File(file.path);
//             bankChequeLeafFileNames[index] = path.basename(file.path);
//             break;
//         }
//       });
//     }
//   }

//   Future<void> updateKYC(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Use PUT method to update
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add ALL text fields (even empty ones)
//       editControllers!.forEach((key, controller) {
//         // Skip file attachment fields as text
//         if (!key.endsWith('_attachment') && key != 'cin_attach') {
//           request.fields[key] = controller.text.trim();
//         }
//       });

//       // Add file attachments - only if new files are selected
//       // If no new file is selected, the existing file should be preserved
//       await _addFileAttachments(request);

//       // Add nested arrays
//       await _addNestedArrays(request);

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 200) {
//         // Clear all controllers after successful update
//         _disposeAllControllers();
//         editControllers = null;
//         editAadharDetailControllers = null;
//         editPanDetailControllers = null;
//         editBankDetailControllers = null;
//         editingKycId = null;
        
//         // Reset all file selections
//         _resetFileSelections();
        
//         // Clear existing URLs
//         existingPanAttachmentUrl = null;
//         existingGstAttachmentUrl = null;
//         existingBisAttachmentUrl = null;
//         existingMsmeAttachmentUrl = null;
//         existingTanAttachmentUrl = null;
//         existingCinAttachmentUrl = null;
//         existingAadharAttachmentUrls.clear();
//         existingPanAttachmentUrls.clear();
//         existingChequeLeafUrls.clear();
        
//         // Refresh the KYC list
//         fetchKYCRecords();
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('KYC updated successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         final responseBody = await response.stream.bytesToString();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to update KYC. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
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

//   Future<void> _addFileAttachments(http.MultipartRequest request) async {
//     // Add PAN attachment only if new file is selected
//     if (panAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'pan_attachment',
//           panAttachmentFile!.path,
//           filename: panAttachmentFileName,
//         ),
//       );
//     } else if (existingPanAttachmentUrl != null && existingPanAttachmentUrl!.isNotEmpty) {
//       request.fields['pan_attachment'] = existingPanAttachmentUrl!;
//     }

//     // Add GST attachment
//     if (gstAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'gst_attachment',
//           gstAttachmentFile!.path,
//           filename: gstAttachmentFileName,
//         ),
//       );
//     } else if (existingGstAttachmentUrl != null && existingGstAttachmentUrl!.isNotEmpty) {
//       request.fields['gst_attachment'] = existingGstAttachmentUrl!;
//     }

//     // Add BIS attachment
//     if (bisAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'bis_attachment',
//           bisAttachmentFile!.path,
//           filename: bisAttachmentFileName,
//         ),
//       );
//     } else if (existingBisAttachmentUrl != null && existingBisAttachmentUrl!.isNotEmpty) {
//       request.fields['bis_attachment'] = existingBisAttachmentUrl!;
//     }

//     // Add MSME attachment
//     if (msmeAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'msme_attachment',
//           msmeAttachmentFile!.path,
//           filename: msmeAttachmentFileName,
//         ),
//       );
//     } else if (existingMsmeAttachmentUrl != null && existingMsmeAttachmentUrl!.isNotEmpty) {
//       request.fields['msme_attachment'] = existingMsmeAttachmentUrl!;
//     }

//     // Add TAN attachment
//     if (tanAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'tan_attachment',
//           tanAttachmentFile!.path,
//           filename: tanAttachmentFileName,
//         ),
//       );
//     } else if (existingTanAttachmentUrl != null && existingTanAttachmentUrl!.isNotEmpty) {
//       request.fields['tan_attachment'] = existingTanAttachmentUrl!;
//     }

//     // Add CIN attachment
//     if (cinAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'cin_attach',
//           cinAttachmentFile!.path,
//           filename: cinAttachmentFileName,
//         ),
//       );
//     } else if (existingCinAttachmentUrl != null && existingCinAttachmentUrl!.isNotEmpty) {
//       request.fields['cin_attach'] = existingCinAttachmentUrl!;
//     }
//   }

//   Future<void> _addNestedArrays(http.MultipartRequest request) async {
//     // Add aadhar details
//     if (editAadharDetailControllers != null) {
//       for (int i = 0; i < editAadharDetailControllers!.length; i++) {
//         var controllers = editAadharDetailControllers![i];
//         String name = controllers['aadhar_name']?.text.trim() ?? '';
//         String number = controllers['aadhar_no']?.text.trim() ?? '';
        
//         // Add text fields
//         if (name.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_name]'] = name;
//         }
//         if (number.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_no]'] = number;
//         }
        
//         // Add file attachment if new file is selected
//         if (aadharAttachmentFiles.containsKey(i)) {
//           File? file = aadharAttachmentFiles[i];
//           String? filename = aadharAttachmentFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'aadhar_detail[$i][aadhar_attach]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingAadharAttachmentUrls.length && 
//                    existingAadharAttachmentUrls[i] != null && 
//                    existingAadharAttachmentUrls[i]!.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_attach]'] = existingAadharAttachmentUrls[i]!;
//         }
//       }
//     }

//     // Add pan details
//     if (editPanDetailControllers != null) {
//       for (int i = 0; i < editPanDetailControllers!.length; i++) {
//         var controllers = editPanDetailControllers![i];
//         String name = controllers['pan_name']?.text.trim() ?? '';
//         String number = controllers['pan_no']?.text.trim() ?? '';
        
//         // Add text fields
//         if (name.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_name]'] = name;
//         }
//         if (number.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_no]'] = number;
//         }
        
//         // Add file attachment if new file is selected
//         if (panDetailAttachmentFiles.containsKey(i)) {
//           File? file = panDetailAttachmentFiles[i];
//           String? filename = panDetailAttachmentFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'pan_detail[$i][pan_attachment]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingPanAttachmentUrls.length && 
//                    existingPanAttachmentUrls[i] != null && 
//                    existingPanAttachmentUrls[i]!.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_attachment]'] = existingPanAttachmentUrls[i]!;
//         }
//       }
//     }

//     // Add bank details
//     if (editBankDetailControllers != null) {
//       for (int i = 0; i < editBankDetailControllers!.length; i++) {
//         var controllers = editBankDetailControllers![i];
        
//         // Add text fields
//         request.fields['bank_detail[$i][bank_name]'] = controllers['bank_name']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][account_name]'] = controllers['account_name']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][account_no]'] = controllers['account_no']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][ifsc_code]'] = controllers['ifsc_code']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][branch]'] = controllers['branch']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][bank_city]'] = controllers['bank_city']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][bank_state]'] = controllers['bank_state']?.text.trim() ?? '';
        
//         // Add file attachment if new file is selected
//         if (bankChequeLeafFiles.containsKey(i)) {
//           File? file = bankChequeLeafFiles[i];
//           String? filename = bankChequeLeafFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'bank_detail[$i][cheque_leaf]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingChequeLeafUrls.length && 
//                    existingChequeLeafUrls[i] != null && 
//                    existingChequeLeafUrls[i]!.isNotEmpty) {
//           request.fields['bank_detail[$i][cheque_leaf]'] = existingChequeLeafUrls[i]!;
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedFields = getSelectedFields();
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//         actions: [
//           // Field Selection button
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
//             onPressed: () => fetchKYCRecords(),
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('No KYC records found'),
//                       if (filterParams.isNotEmpty) ...[
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
                    
//                     // Show active filters if any
//                     if (filterParams.isNotEmpty)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.blue.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Filters: ${filterParams.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
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
//                             columnSpacing: compactRows ? 15 : 24,
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
//                             rows: kycRecords.map((record) {
//                               final id = record['id'];
//                               final isSelected = selectedIds.contains(id);
//                               final bool isCompleted = record['is_completed'] == true;

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

//                                   // ACTIONS - Only show if row is selected and based on enableView/enableEdit settings
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               // View button - Show only if enableView is true
//                                               if (enableView)
//                                                 ElevatedButton(
//                                                   onPressed: () =>
//                                                       showKYCDetailDialog(record, false),
//                                                   child: Text(
//                                                     'View',
//                                                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                   ),
//                                                   style: ElevatedButton.styleFrom(
//                                                     padding: EdgeInsets.symmetric(horizontal: 8),
//                                                   ),
//                                                 ),
                                              
//                                               // Edit button - Show only if enableEdit is true AND KYC is not completed
//                                               if (enableEdit && !isCompleted) ...[
//                                                 if (enableView) SizedBox(width: 8),
//                                                 ElevatedButton(
//                                                   onPressed: () =>
//                                                       showKYCDetailDialog(record, true),
//                                                   child: Text(
//                                                     'Edit',
//                                                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                   ),
//                                                   style: ElevatedButton.styleFrom(
//                                                     padding: EdgeInsets.symmetric(horizontal: 8),
//                                                   ),
//                                                 ),
//                                               ],
                                              
//                                               // Complete/Reopen button - Always show regardless of enableView/enableEdit
//                                               if (isSelected) ...[
//                                                 if ((enableView || enableEdit) && 
//                                                     (enableView || enableEdit)) 
//                                                   SizedBox(width: 8),
//                                                 ElevatedButton(
//                                                   onPressed: () => _showCompletionDialog(record),
//                                                   child: Text(
//                                                     isCompleted ? 'Reopen' : 'Complete',
//                                                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                   ),
//                                                   style: ElevatedButton.styleFrom(
//                                                     backgroundColor: isCompleted ? Colors.orange : Colors.green,
//                                                     padding: EdgeInsets.symmetric(horizontal: 8),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   // Selected fields only
//                                   ...selectedFields.map((f) {
//                                     String displayValue = getFieldValue(record, f['key']);
                                    
//                                     // Special handling for attachments
//                                     if ((f['key'].endsWith('_attachment') || f['key'] == 'cin_attach') && displayValue.isNotEmpty) {
//                                       return DataCell(
//                                         GestureDetector(
//                                           onTap: () {
//                                             final url = record[f['key']];
//                                             print('Open file: $url');
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
//                                                 Icon(
//                                                   f['key'] == 'cin_attach' ? Icons.description : Icons.attachment,
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
                                    
//                                     // Special handling for complex fields (arrays)
//                                     if (f['isComplex'] == true) {
//                                       final details = record[f['key']];
//                                       if (details != null && details is List) {
//                                         return DataCell(
//                                           Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: Colors.green.shade50,
//                                               borderRadius: BorderRadius.circular(4),
//                                             ),
//                                             child: Text(
//                                               '${details.length} items',
//                                               style: TextStyle(
//                                                 fontSize: compactRows ? 11 : 13,
//                                                 color: Colors.green.shade800,
//                                               ),
//                                             ),
//                                           ),
//                                         );
//                                       }
//                                     }
                                    
//                                     // Special handling for status
//                                     if (f['key'] == 'is_completed') {
//                                       bool completed = record['is_completed'] == true;
//                                       return DataCell(
//                                         Container(
//                                           padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                           decoration: BoxDecoration(
//                                             color: completed ? Colors.green.shade50 : Colors.orange.shade50,
//                                             borderRadius: BorderRadius.circular(4),
//                                           ),
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 completed ? Icons.lock : Icons.lock_open,
//                                                 size: compactRows ? 12 : 14,
//                                                 color: completed ? Colors.green : Colors.orange,
//                                               ),
//                                               SizedBox(width: 2),
//                                               Text(
//                                                 completed ? 'Completed' : 'In Progress',
//                                                 style: TextStyle(
//                                                   fontSize: compactRows ? 11 : 13,
//                                                   color: completed ? Colors.green.shade800 : Colors.orange.shade800,
//                                                   fontWeight: FontWeight.w500,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       );
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
//                             'Page $currentPage | Total: $totalCount',
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


// class KYCPage extends StatefulWidget {
//   @override
//   _KYCPageState createState() => _KYCPageState();
// }

// class _KYCPageState extends State<KYCPage> {
//   List<Map<String, dynamic>> kycRecords = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   int pageSize = 20;

//   // Filter and sort variables
//   Map<String, String> filterParams = {};
//   String? sortBy;
//   String? sortOrder;

//   // Search query for field selection
//   String fieldSearchQuery = '';
  
//   // List settings variables
//   bool wrapColumnText = false;
//   bool compactRows = false;
//   bool activeRowHighlighting = false;
//   bool modernCellColoring = false;
//   bool enableListEdit = false;
//   bool doubleClickToEdit = false;
  
//   // Filter field controllers
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController businessNameController = TextEditingController();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController mobileController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController gstNoController = TextEditingController();
//   final TextEditingController panNoController = TextEditingController();
//   final TextEditingController statusController = TextEditingController();
  
//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 0},
//     {'key': 'business_name', 'label': 'Business Name', 'selected': true, 'order': 1},
//     {'key': 'name', 'label': 'Name', 'selected': true, 'order': 2},
//     {'key': 'mobile', 'label': 'Mobile', 'selected': true, 'order': 3},
//     {'key': 'business_email', 'label': 'Email', 'selected': true, 'order': 4},
//     {'key': 'gst_no', 'label': 'GST Number', 'selected': true, 'order': 5},
//     {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false, 'order': 6},
//     {'key': 'pan_no', 'label': 'PAN Number', 'selected': true, 'order': 7},
//     {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false, 'order': 8},
//     {'key': 'bis_name', 'label': 'BIS Name', 'selected': false, 'order': 9},
//     {'key': 'bis_no', 'label': 'BIS Number', 'selected': false, 'order': 10},
//     {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false, 'order': 11},
//     {'key': 'msme_name', 'label': 'MSME Name', 'selected': false, 'order': 12},
//     {'key': 'msme_no', 'label': 'MSME Number', 'selected': false, 'order': 13},
//     {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false, 'order': 14},
//     {'key': 'tan_name', 'label': 'TAN Name', 'selected': false, 'order': 15},
//     {'key': 'tan_no', 'label': 'TAN Number', 'selected': false, 'order': 16},
//     {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false, 'order': 17},
//     {'key': 'cin_name', 'label': 'CIN Name', 'selected': false, 'order': 18},
//     {'key': 'cin_no', 'label': 'CIN Number', 'selected': false, 'order': 19},
//     {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false, 'order': 20},
//     {'key': 'note', 'label': 'Note', 'selected': false, 'order': 21},
//     {'key': 'is_completed', 'label': 'Status', 'selected': true, 'order': 22},
//     {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false, 'isComplex': true, 'order': 23},
//     {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false, 'isComplex': true, 'order': 24},
//     {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false, 'isComplex': true, 'order': 25},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 26},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 27},
//   ];

//   // For editing KYC
//   Map<String, TextEditingController>? editControllers;
//   List<Map<String, TextEditingController>>? editAadharDetailControllers;
//   List<Map<String, TextEditingController>>? editPanDetailControllers;
//   List<Map<String, TextEditingController>>? editBankDetailControllers;
//   int? editingKycId;
  
//   // For file uploads - NEW: Track existing file URLs
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   File? bisAttachmentFile;
//   File? msmeAttachmentFile;
//   File? tanAttachmentFile;
//   File? cinAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;
//   String? bisAttachmentFileName;
//   String? msmeAttachmentFileName;
//   String? tanAttachmentFileName;
//   String? cinAttachmentFileName;
  
//   // Store existing file URLs to preserve them
//   String? existingPanAttachmentUrl;
//   String? existingGstAttachmentUrl;
//   String? existingBisAttachmentUrl;
//   String? existingMsmeAttachmentUrl;
//   String? existingTanAttachmentUrl;
//   String? existingCinAttachmentUrl;
  
//   // For nested array file uploads - NEW: Track existing file URLs
//   Map<int, File> aadharAttachmentFiles = {};
//   Map<int, String> aadharAttachmentFileNames = {};
//   Map<int, File> panDetailAttachmentFiles = {};
//   Map<int, String> panDetailAttachmentFileNames = {};
//   Map<int, File> bankChequeLeafFiles = {};
//   Map<int, String> bankChequeLeafFileNames = {};
  
//   // Store existing file URLs for nested arrays
//   List<String?> existingAadharAttachmentUrls = [];
//   List<String?> existingPanAttachmentUrls = [];
//   List<String?> existingChequeLeafUrls = [];

//   @override
//   void initState() {
//     super.initState();
//     loadSavedFieldSelections();
//     loadListSettings();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     _disposeAllControllers();
//     bpCodeController.dispose();
//     businessNameController.dispose();
//     nameController.dispose();
//     mobileController.dispose();
//     emailController.dispose();
//     gstNoController.dispose();
//     panNoController.dispose();
//     statusController.dispose();
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('kyc_fields');
//     String? savedOrder = prefs.getString('kyc_field_order');
    
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
    
//     await prefs.setString('kyc_fields', json.encode(selections));
    
//     // Save field order
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('kyc_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     setState(() {
//       wrapColumnText = prefs.getBool('kyc_wrap_column_text') ?? false;
//       compactRows = prefs.getBool('kyc_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('kyc_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('kyc_modern_cell_coloring') ?? false;
//       enableListEdit = prefs.getBool('kyc_enable_list_edit') ?? false;
//       doubleClickToEdit = prefs.getBool('kyc_double_click_to_edit') ?? false;
//     });
//   }

//   // Save list settings to SharedPreferences
//   Future<void> saveListSettings({
//     required bool wrapColumnText,
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableListEdit,
//     required bool doubleClickToEdit,
//   }) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
    
//     await prefs.setBool('kyc_wrap_column_text', wrapColumnText);
//     await prefs.setBool('kyc_compact_rows', compactRows);
//     await prefs.setBool('kyc_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('kyc_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('kyc_enable_list_edit', enableListEdit);
//     await prefs.setBool('kyc_double_click_to_edit', doubleClickToEdit);
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
//         {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
//         {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
//         {'key': 'is_completed', 'label': 'Status', 'selected': true},
//         {'key': 'gst_attachment', 'label': 'GST Attachment', 'selected': false},
//         {'key': 'pan_attachment', 'label': 'PAN Attachment', 'selected': false},
//         {'key': 'bis_name', 'label': 'BIS Name', 'selected': false},
//         {'key': 'bis_no', 'label': 'BIS Number', 'selected': false},
//         {'key': 'bis_attachment', 'label': 'BIS Attachment', 'selected': false},
//         {'key': 'msme_name', 'label': 'MSME Name', 'selected': false},
//         {'key': 'msme_no', 'label': 'MSME Number', 'selected': false},
//         {'key': 'msme_attachment', 'label': 'MSME Attachment', 'selected': false},
//         {'key': 'tan_name', 'label': 'TAN Name', 'selected': false},
//         {'key': 'tan_no', 'label': 'TAN Number', 'selected': false},
//         {'key': 'tan_attachment', 'label': 'TAN Attachment', 'selected': false},
//         {'key': 'cin_name', 'label': 'CIN Name', 'selected': false},
//         {'key': 'cin_no', 'label': 'CIN Number', 'selected': false},
//         {'key': 'cin_attach', 'label': 'CIN Attachment', 'selected': false},
//         {'key': 'note', 'label': 'Note', 'selected': false},
//         {'key': 'aadhar_detail', 'label': 'Aadhar Details', 'selected': false},
//         {'key': 'pan_detail', 'label': 'PAN Details', 'selected': false},
//         {'key': 'bank_detail', 'label': 'Bank Details', 'selected': false},
//         {'key': 'created_at', 'label': 'Created Date', 'selected': false},
//         {'key': 'updated_at', 'label': 'Updated Date', 'selected': false},
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
//     required bool wrapColumnText,
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableListEdit,
//     required bool doubleClickToEdit,
//   }) {
//     // Save these settings to SharedPreferences
//     saveListSettings(
//       wrapColumnText: wrapColumnText,
//       compactRows: compactRows,
//       activeRowHighlighting: activeRowHighlighting,
//       modernCellColoring: modernCellColoring,
//       enableListEdit: enableListEdit,
//       doubleClickToEdit: doubleClickToEdit,
//     );
    
//     // Apply the settings to the current view
//     setState(() {
//       this.wrapColumnText = wrapColumnText;
//       this.compactRows = compactRows;
//       this.activeRowHighlighting = activeRowHighlighting;
//       this.modernCellColoring = modernCellColoring;
//       this.enableListEdit = enableListEdit;
//       this.doubleClickToEdit = doubleClickToEdit;
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
//     bool localWrapColumnText = wrapColumnText;
//     bool localCompactRows = compactRows;
//     bool localActiveRowHighlighting = activeRowHighlighting;
//     bool localModernCellColoring = modernCellColoring;
//     bool localEnableListEdit = enableListEdit;
//     bool localDoubleClickToEdit = doubleClickToEdit;
    
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
//                             'Personalize List Columns - KYC Records',
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
                    
//                     // Bottom options section with working checkboxes
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
//                                   value: localWrapColumnText,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localWrapColumnText = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Wrap column text'),
//                               SizedBox(width: 32),
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
//                               SizedBox(width: 32),
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localEnableListEdit,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localEnableListEdit = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Enable edit'),
//                               SizedBox(width: 32),
//                               SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: Checkbox(
//                                   value: localDoubleClickToEdit,
//                                   onChanged: (value) {
//                                     setState(() {
//                                       localDoubleClickToEdit = value ?? false;
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Text('Enable view'),
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
//                                   {'key': 'gst_no', 'label': 'GST Number', 'selected': true},
//                                   {'key': 'pan_no', 'label': 'PAN Number', 'selected': true},
//                                   {'key': 'is_completed', 'label': 'Status', 'selected': true},
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
//                                 localWrapColumnText = false;
//                                 localCompactRows = false;
//                                 localActiveRowHighlighting = false;
//                                 localModernCellColoring = false;
//                                 localEnableListEdit = false;
//                                 localDoubleClickToEdit = false;
                                
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
//                                 'KYC - Field Selection',
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
//                                 wrapColumnText: localWrapColumnText,
//                                 compactRows: localCompactRows,
//                                 activeRowHighlighting: localActiveRowHighlighting,
//                                 modernCellColoring: localModernCellColoring,
//                                 enableListEdit: localEnableListEdit,
//                                 doubleClickToEdit: localDoubleClickToEdit,
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
//       return '[${value.length} items]';
//     }
//     return value.toString();
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> record, String key) {
//     final value = record[key];
    
//     if (value == null) return '';
    
//     // Handle complex fields (arrays)
//     if (key == 'aadhar_detail' || key == 'pan_detail' || key == 'bank_detail') {
//       if (value is List) {
//         return '${value.length} items';
//       }
//     }
    
//     // Handle attachments
//     if (key.endsWith('_attachment') || key == 'cin_attach') {
//       if (value.toString().isNotEmpty) {
//         if (key == 'cin_attach') {
//           return '📄 CIN';
//         }
//         return '📎 ' + key.replaceAll('_attachment', '').toUpperCase();
//       }
//     }
    
//     // Handle status
//     if (key == 'is_completed') {
//       return value == true ? '✅ Completed' : '⏳ In Progress';
//     }
    
//     return value.toString();
//   }

//   // Build URL with filter and sort parameters
//   String buildRequestUrl({String? baseUrl}) {
//     Uri uri;
    
//     if (baseUrl != null) {
//       uri = Uri.parse(baseUrl);
//     } else {
//       uri = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/');
//     }
    
//     // Create a new Uri with additional query parameters
//     Map<String, String> queryParams = {};
    
//     // Add existing query parameters from the URL
//     queryParams.addAll(uri.queryParameters);
    
//     // Add filter parameters
//     queryParams.addAll(filterParams);
    
//     // Add sort parameters
//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
      
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }
    
//     // Add page size
//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
    
//     // Rebuild URI with all parameters
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Apply all filters at once
//   Future<void> applyFilters() async {
//     filterParams.clear();
    
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (businessNameController.text.isNotEmpty) {
//       filterParams['business_name'] = businessNameController.text;
//     }
//     if (nameController.text.isNotEmpty) {
//       filterParams['name'] = nameController.text;
//     }
//     if (mobileController.text.isNotEmpty) {
//       filterParams['mobile'] = mobileController.text;
//     }
//     if (emailController.text.isNotEmpty) {
//       filterParams['business_email'] = emailController.text;
//     }
//     if (gstNoController.text.isNotEmpty) {
//       filterParams['gst_no'] = gstNoController.text;
//     }
//     if (panNoController.text.isNotEmpty) {
//       filterParams['pan_no'] = panNoController.text;
//     }
//     if (statusController.text.isNotEmpty) {
//       if (statusController.text.toLowerCase() == 'completed') {
//         filterParams['is_completed'] = 'true';
//       } else if (statusController.text.toLowerCase() == 'in progress') {
//         filterParams['is_completed'] = 'false';
//       }
//     }
    
//     // Reset to first page when applying filters
//     currentPage = 1;
//     await fetchKYCRecords();
//   }

//   // Clear all filters
//   Future<void> clearFilters() async {
//     filterParams.clear();
//     bpCodeController.clear();
//     businessNameController.clear();
//     nameController.clear();
//     mobileController.clear();
//     emailController.clear();
//     gstNoController.clear();
//     panNoController.clear();
//     statusController.clear();
    
//     await fetchKYCRecords();
//   }

//   // Show filter dialog
//   void showFilterDialog() {
//     // Initialize controllers with current filter values
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     businessNameController.text = filterParams['business_name'] ?? '';
//     nameController.text = filterParams['name'] ?? '';
//     mobileController.text = filterParams['mobile'] ?? '';
//     emailController.text = filterParams['business_email'] ?? '';
//     gstNoController.text = filterParams['gst_no'] ?? '';
//     panNoController.text = filterParams['pan_no'] ?? '';
    
//     // Convert boolean filter to text for status
//     if (filterParams.containsKey('is_completed')) {
//       if (filterParams['is_completed'] == 'true') {
//         statusController.text = 'completed';
//       } else if (filterParams['is_completed'] == 'false') {
//         statusController.text = 'in progress';
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Filter KYC Records'),
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
//                       hintText: 'e.g., KYC001',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.code),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: businessNameController,
//                     decoration: InputDecoration(
//                       labelText: 'Business Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.business),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: nameController,
//                     decoration: InputDecoration(
//                       labelText: 'Name',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.person),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: mobileController,
//                     decoration: InputDecoration(
//                       labelText: 'Mobile',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.phone),
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
//                     controller: gstNoController,
//                     decoration: InputDecoration(
//                       labelText: 'GST Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.numbers),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   TextField(
//                     controller: panNoController,
//                     decoration: InputDecoration(
//                       labelText: 'PAN Number',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.credit_card),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//                   DropdownButtonFormField<String>(
//                     value: statusController.text.isNotEmpty ? statusController.text : null,
//                     decoration: InputDecoration(
//                       labelText: 'Status',
//                       border: OutlineInputBorder(),
//                       prefixIcon: Icon(Icons.info),
//                     ),
//                     items: [
//                       DropdownMenuItem(value: 'completed', child: Text('Completed')),
//                       DropdownMenuItem(value: 'in progress', child: Text('In Progress')),
//                     ],
//                     onChanged: (value) {
//                       statusController.text = value ?? '';
//                     },
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
//     setState(() {
//       sortBy = field;
//       sortOrder = order;
//     });
    
//     // Reset to first page when sorting
//     currentPage = 1;
//     await fetchKYCRecords();
//   }

//   // Clear sort
//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchKYCRecords();
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
//       {'value': 'business_name', 'label': 'Business Name'},
//       {'value': 'name', 'label': 'Name'},
//       {'value': 'mobile', 'label': 'Mobile'},
//       {'value': 'business_email', 'label': 'Email'},
//       {'value': 'gst_no', 'label': 'GST Number'},
//       {'value': 'pan_no', 'label': 'PAN Number'},
//       {'value': 'is_completed', 'label': 'Status'},
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
//                       fetchKYCRecords();
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

//   // Change page size
//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
    
//     // Add page_size to URL
//     filterParams['page_size'] = newSize.toString();
//     await fetchKYCRecords();
//   }

//   void _disposeAllControllers() {
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     if (editAadharDetailControllers != null) {
//       for (var controllers in editAadharDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     if (editPanDetailControllers != null) {
//       for (var controllers in editPanDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     if (editBankDetailControllers != null) {
//       for (var controllers in editBankDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
//   }

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchKYCRecords();
//   }

//   Future<void> fetchKYCRecords({String? url}) async {
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
//           dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
//         }

//         setState(() {
//           kycRecords = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
          
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
          
//           isLoading = false;
//         });
//       } else {
//         setState(() => isLoading = false);
//       }
//     } catch (_) {
//       setState(() => isLoading = false);
//     }
//   }

//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty && currentPage > 1) {
//       currentPage--;
//       fetchKYCRecords(url: prevUrl);
//     }
//   }

//   Future<Map<String, dynamic>> fetchKycDetail(int id) async {
//     if (token == null) throw Exception('No token available');

//     final Uri apiUrl = Uri.parse(
//       'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/detail/$id/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data;
//       } else {
//         throw Exception('Failed to fetch KYC details');
//       }
//     } catch (e) {
//       throw Exception('Error fetching KYC details: $e');
//     }
//   }

//   // NEW: Function to mark KYC as completed
//   Future<void> completeKYC(int id, bool completed) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final Uri apiUrl = Uri.parse(
//         'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/complete/$id/',
//       );

//       final response = await http.post(
//         apiUrl,
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({'completed': completed}),
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(data['detail'] ?? 'Operation successful'),
//             backgroundColor: Colors.green,
//           ),
//         );
        
//         // Refresh the list to update the status
//         fetchKYCRecords();
//       } else {
//         final errorData = json.decode(response.body);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(errorData['detail'] ?? 'Failed to update KYC status'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // NEW: Function to show confirmation dialog for complete/reopen
//   void _showCompletionDialog(Map<String, dynamic> kycRecord) {
//     final id = kycRecord['id'];
//     final bool isCompleted = kycRecord['is_completed'] == true;
//     final String businessName = kycRecord['business_name']?.toString() ?? 'KYC';
//     final String bpCode = kycRecord['bp_code']?.toString() ?? '';

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(isCompleted ? 'Reopen KYC' : 'Complete KYC'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'KYC Details:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text('Business Name: $businessName'),
//             Text('BP Code: $bpCode'),
//             SizedBox(height: 16),
//             Text(
//               isCompleted 
//                 ? 'Are you sure you want to reopen this KYC? This will unlock it for editing.'
//                 : 'Are you sure you want to mark this KYC as completed? This will lock it from further editing.',
//               style: TextStyle(color: Colors.grey[700]),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               await completeKYC(id, !isCompleted);
//             },
//             child: Text(isCompleted ? 'Reopen' : 'Complete'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: isCompleted ? Colors.orange : Colors.green,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
//     if (isEdit) {
//       try {
//         setState(() => isLoading = true);
//         final detailedRecord = await fetchKycDetail(kycRecord['id']);
//         setState(() => isLoading = false);
        
//         _initializeEditMode(detailedRecord);
//       } catch (e) {
//         setState(() => isLoading = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to load KYC details for editing: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
//     }

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text(isEdit ? 'Edit KYC' : 'KYC Details'),
//             content: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // NEW: Show completion status prominently
//                   if (!isEdit && kycRecord['is_completed'] == true)
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       margin: EdgeInsets.only(bottom: 16),
//                       decoration: BoxDecoration(
//                         color: Colors.green[50],
//                         border: Border.all(color: Colors.green),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.lock, color: Colors.green, size: 20),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'KYC Completed (Locked)',
//                               style: TextStyle(
//                                 color: Colors.green[800],
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   if (isEdit && editControllers != null)
//                     ..._buildEditFields(setState)
//                   else
//                     ..._buildViewFields(kycRecord),
                  
//                   if (!isEdit)
//                     ..._buildNestedArraysView(kycRecord),
//                 ],
//               ),
//             ),
//             actions: [
//               if (isEdit)
//                 ElevatedButton(
//                   onPressed: () async {
//                     await updateKYC(editingKycId!);
//                     Navigator.pop(context);
//                   },
//                   child: Text('Save'),
//                 ),
//               TextButton(
//                 onPressed: () {
//                   if (isEdit) {
//                     _disposeAllControllers();
//                     editControllers = null;
//                     editAadharDetailControllers = null;
//                     editPanDetailControllers = null;
//                     editBankDetailControllers = null;
//                     editingKycId = null;
//                     _resetFileSelections();
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

//   void _initializeEditMode(Map<String, dynamic> kycRecord) {
//     editingKycId = kycRecord['id'];
//     editControllers = {};
    
//     // Check if KYC is completed and locked
//     bool isCompleted = kycRecord['is_completed'] == true;
//     if (isCompleted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('KYC is completed and locked. Cannot edit.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }
    
//     // Initialize main field controllers
//     for (var field in kycRecord.keys) {
//       if (field.toLowerCase() != 'id' && 
//           field != 'aadhar_detail' && 
//           field != 'pan_detail' && 
//           field != 'bank_detail') {
//         editControllers![field] = TextEditingController(
//           text: kycRecord[field]?.toString() ?? '',
//         );
        
//         // Store existing file URLs to preserve them
//         if (field == 'pan_attachment' && kycRecord[field] != null) {
//           existingPanAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'gst_attachment' && kycRecord[field] != null) {
//           existingGstAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'bis_attachment' && kycRecord[field] != null) {
//           existingBisAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'msme_attachment' && kycRecord[field] != null) {
//           existingMsmeAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'tan_attachment' && kycRecord[field] != null) {
//           existingTanAttachmentUrl = kycRecord[field].toString();
//         } else if (field == 'cin_attach' && kycRecord[field] != null) {
//           existingCinAttachmentUrl = kycRecord[field].toString();
//         }
//       }
//     }
    
//     // Initialize aadhar detail controllers
//     editAadharDetailControllers = [];
//     existingAadharAttachmentUrls.clear();
//     if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
//       for (var detail in existingDetails) {
//         editAadharDetailControllers!.add({
//           'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
//           'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
//         });
//         existingAadharAttachmentUrls.add(detail['aadhar_attach']?.toString());
//       }
//     }
    
//     // Initialize pan detail controllers
//     editPanDetailControllers = [];
//     existingPanAttachmentUrls.clear();
//     if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
//       for (var detail in existingDetails) {
//         editPanDetailControllers!.add({
//           'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
//           'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
//         });
//         existingPanAttachmentUrls.add(detail['pan_attachment']?.toString());
//       }
//     }
    
//     // Initialize bank detail controllers
//     editBankDetailControllers = [];
//     existingChequeLeafUrls.clear();
//     if (kycRecord['bank_detail'] != null && kycRecord['bank_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['bank_detail']);
      
//       for (var detail in existingDetails) {
//         editBankDetailControllers!.add({
//           'bank_name': TextEditingController(text: detail['bank_name']?.toString() ?? ''),
//           'account_name': TextEditingController(text: detail['account_name']?.toString() ?? ''),
//           'account_no': TextEditingController(text: detail['account_no']?.toString() ?? ''),
//           'ifsc_code': TextEditingController(text: detail['ifsc_code']?.toString() ?? ''),
//           'branch': TextEditingController(text: detail['branch']?.toString() ?? ''),
//           'bank_city': TextEditingController(text: detail['bank_city']?.toString() ?? ''),
//           'bank_state': TextEditingController(text: detail['bank_state']?.toString() ?? ''),
//         });
//         existingChequeLeafUrls.add(detail['cheque_leaf']?.toString());
//       }
//     }
    
//     _resetFileSelections();
//   }

//   void _resetFileSelections() {
//     panAttachmentFile = null;
//     gstAttachmentFile = null;
//     bisAttachmentFile = null;
//     msmeAttachmentFile = null;
//     tanAttachmentFile = null;
//     cinAttachmentFile = null;
//     panAttachmentFileName = null;
//     gstAttachmentFileName = null;
//     bisAttachmentFileName = null;
//     msmeAttachmentFileName = null;
//     tanAttachmentFileName = null;
//     cinAttachmentFileName = null;
//     aadharAttachmentFiles.clear();
//     aadharAttachmentFileNames.clear();
//     panDetailAttachmentFiles.clear();
//     panDetailAttachmentFileNames.clear();
//     bankChequeLeafFiles.clear();
//     bankChequeLeafFileNames.clear();
//   }

//   List<Widget> _buildEditFields(StateSetter setState) {
//     List<Widget> fields = [];
    
//     if (editControllers == null) return fields;
    
//     List<String> fieldOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     for (var field in fieldOrder) {
//       if (editControllers!.containsKey(field)) {
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildEditFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             currentValue: editControllers![field]!.text,
//             setState: setState,
//           ));
//         } else if (field == 'is_completed') {
//           fields.add(_buildBooleanField(
//             field: field,
//             label: _getFieldLabel(field),
//             setState: setState,
//           ));
//         } else {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: TextField(
//               controller: editControllers![field],
//               decoration: InputDecoration(
//                 labelText: _getFieldLabel(field),
//                 border: OutlineInputBorder(),
//               ),
//             ),
//           ));
//         }
//       }
//     }
    
//     fields.addAll(_buildNestedArraysEdit(setState));
    
//     return fields;
//   }

//   String _getFieldLabel(String field) {
//     return field
//         .replaceAll('_', ' ')
//         .toUpperCase()
//         .replaceAll('ATTACH', 'ATTACHMENT');
//   }

//   Widget _buildBooleanField({
//     required String field,
//     required String label,
//     required StateSetter setState,
//   }) {
//     bool value = editControllers![field]!.text.toLowerCase() == 'true';
    
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Text(
//             label,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           SizedBox(width: 10),
//           Switch(
//             value: value,
//             onChanged: (newValue) {
//               setState(() {
//                 editControllers![field]!.text = newValue.toString();
//               });
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> _buildViewFields(Map<String, dynamic> kycRecord) {
//     List<Widget> fields = [];
    
//     List<String> displayOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     for (var field in displayOrder) {
//       if (kycRecord.containsKey(field)) {
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             value: kycRecord[field],
//           ));
//         } else if (field == 'is_completed') {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getFieldLabel(field),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Icon(
//                       kycRecord[field] == true ? Icons.lock : Icons.lock_open,
//                       color: kycRecord[field] == true ? Colors.green : Colors.orange,
//                       size: 16,
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       kycRecord[field] == true ? 'Completed (Locked)' : 'In Progress',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: kycRecord[field] == true ? Colors.green : Colors.orange,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ));
//         } else {
//           fields.add(Padding(
//             padding: const EdgeInsets.symmetric(vertical: 6),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   _getFieldLabel(field),
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                   ),
//                 ),
//                 SizedBox(height: 4),
//                 Text(
//                   kycRecord[field]?.toString() ?? 'Not provided',
//                   style: TextStyle(fontSize: 14),
//                 ),
//               ],
//             ),
//           ));
//         }
//       }
//     }
    
//     return fields;
//   }

//   List<Widget> _buildNestedArraysView(Map<String, dynamic> kycRecord) {
//     List<Widget> arrays = [];
    
//     if (kycRecord['aadhar_detail'] != null && 
//         kycRecord['aadhar_detail'] is List && 
//         (kycRecord['aadhar_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Aadhar Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']),
//         fields: ['aadhar_name', 'aadhar_no'],
//         fileFields: ['aadhar_attach'],
//       ));
//     }
    
//     if (kycRecord['pan_detail'] != null && 
//         kycRecord['pan_detail'] is List && 
//         (kycRecord['pan_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'PAN Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['pan_detail']),
//         fields: ['pan_name', 'pan_no'],
//         fileFields: ['pan_attachment'],
//       ));
//     }
    
//     if (kycRecord['bank_detail'] != null && 
//         kycRecord['bank_detail'] is List && 
//         (kycRecord['bank_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Bank Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['bank_detail']),
//         fields: ['bank_name', 'account_name', 'account_no', 'ifsc_code', 'branch', 'bank_city', 'bank_state'],
//         fileFields: ['cheque_leaf'],
//       ));
//     }
    
//     return arrays;
//   }

//   Widget _buildNestedArraySection({
//     required String title,
//     required List<Map<String, dynamic>> details,
//     required List<String> fields,
//     required List<String> fileFields,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Text(
//           title,
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//           ),
//         ),
//         SizedBox(height: 10),
//         ...details.asMap().entries.map((entry) {
//           int index = entry.key;
//           Map<String, dynamic> detail = entry.value;
          
//           return Card(
//             margin: EdgeInsets.symmetric(vertical: 5),
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('${title} ${index + 1}', 
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   SizedBox(height: 8),
//                   ...fields.map((field) {
//                     return Padding(
//                       padding: const EdgeInsets.only(bottom: 4),
//                       child: Row(
//                         children: [
//                           Text(
//                             '${field.replaceAll('_', ' ').toUpperCase()}: ',
//                             style: TextStyle(fontWeight: FontWeight.w500),
//                           ),
//                           Expanded(
//                             child: Text(detail[field]?.toString() ?? 'Not provided'),
//                           ),
//                         ],
//                       ),
//                     );
//                   }).toList(),
//                   ...fileFields.map((field) {
//                     final fileUrl = detail[field];
//                     if (fileUrl != null && fileUrl.toString().isNotEmpty) {
//                       return Padding(
//                         padding: const EdgeInsets.only(top: 4),
//                         child: InkWell(
//                           onTap: () {
//                             print('File URL: $fileUrl');
//                           },
//                           child: Row(
//                             children: [
//                               Icon(Icons.attach_file, size: 16, color: Colors.blue),
//                               SizedBox(width: 4),
//                               Text(
//                                 '${field.replaceAll('_', ' ').toUpperCase()}',
//                                 style: TextStyle(
//                                   color: Colors.blue,
//                                   decoration: TextDecoration.underline,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     }
//                     return SizedBox.shrink();
//                   }).toList(),
//                 ],
//               ),
//             ),
//           );
//         }).toList(),
//       ],
//     );
//   }

//   List<Widget> _buildNestedArraysEdit(StateSetter setState) {
//     List<Widget> arrays = [];
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Aadhar Details',
//       controllersList: editAadharDetailControllers,
//       fields: [
//         {'key': 'aadhar_name', 'label': 'Aadhar Name'},
//         {'key': 'aadhar_no', 'label': 'Aadhar Number'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'aadhar_attach',
//       fileFieldLabel: 'Aadhar Attachment',
//       fileMap: aadharAttachmentFiles,
//       fileNameMap: aadharAttachmentFileNames,
//       existingUrls: existingAadharAttachmentUrls,
//       onAdd: () {
//         setState(() {
//           editAadharDetailControllers ??= [];
//           editAadharDetailControllers!.add({
//             'aadhar_name': TextEditingController(),
//             'aadhar_no': TextEditingController(),
//           });
//           existingAadharAttachmentUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editAadharDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editAadharDetailControllers!.removeAt(index);
//           aadharAttachmentFiles.remove(index);
//           aadharAttachmentFileNames.remove(index);
//           existingAadharAttachmentUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('aadhar', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           aadharAttachmentFiles.remove(index);
//           aadharAttachmentFileNames.remove(index);
//         });
//       },
//     ));
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'PAN Details',
//       controllersList: editPanDetailControllers,
//       fields: [
//         {'key': 'pan_name', 'label': 'PAN Name'},
//         {'key': 'pan_no', 'label': 'PAN Number'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'pan_attachment',
//       fileFieldLabel: 'PAN Attachment',
//       fileMap: panDetailAttachmentFiles,
//       fileNameMap: panDetailAttachmentFileNames,
//       existingUrls: existingPanAttachmentUrls,
//       onAdd: () {
//         setState(() {
//           editPanDetailControllers ??= [];
//           editPanDetailControllers!.add({
//             'pan_name': TextEditingController(),
//             'pan_no': TextEditingController(),
//           });
//           existingPanAttachmentUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editPanDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editPanDetailControllers!.removeAt(index);
//           panDetailAttachmentFiles.remove(index);
//           panDetailAttachmentFileNames.remove(index);
//           existingPanAttachmentUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('pan_detail', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           panDetailAttachmentFiles.remove(index);
//           panDetailAttachmentFileNames.remove(index);
//         });
//       },
//     ));
    
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Bank Details',
//       controllersList: editBankDetailControllers,
//       fields: [
//         {'key': 'bank_name', 'label': 'Bank Name'},
//         {'key': 'account_name', 'label': 'Account Name'},
//         {'key': 'account_no', 'label': 'Account Number'},
//         {'key': 'ifsc_code', 'label': 'IFSC Code'},
//         {'key': 'branch', 'label': 'Branch'},
//         {'key': 'bank_city', 'label': 'Bank City'},
//         {'key': 'bank_state', 'label': 'Bank State'},
//       ],
//       hasFileAttachment: true,
//       fileFieldKey: 'cheque_leaf',
//       fileFieldLabel: 'Cheque Leaf',
//       fileMap: bankChequeLeafFiles,
//       fileNameMap: bankChequeLeafFileNames,
//       existingUrls: existingChequeLeafUrls,
//       onAdd: () {
//         setState(() {
//           editBankDetailControllers ??= [];
//           editBankDetailControllers!.add({
//             'bank_name': TextEditingController(),
//             'account_name': TextEditingController(),
//             'account_no': TextEditingController(),
//             'ifsc_code': TextEditingController(),
//             'branch': TextEditingController(),
//             'bank_city': TextEditingController(),
//             'bank_state': TextEditingController(),
//           });
//           existingChequeLeafUrls.add(null);
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editBankDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editBankDetailControllers!.removeAt(index);
//           bankChequeLeafFiles.remove(index);
//           bankChequeLeafFileNames.remove(index);
//           existingChequeLeafUrls.removeAt(index);
//         });
//       },
//       onPickFile: (index) async {
//         await pickNestedArrayFile('cheque_leaf', index);
//         setState(() {});
//       },
//       onClearFile: (index) {
//         setState(() {
//           bankChequeLeafFiles.remove(index);
//           bankChequeLeafFileNames.remove(index);
//         });
//       },
//     ));
    
//     return arrays;
//   }

//   Widget _buildNestedArrayEditSection({
//     required String title,
//     required List<Map<String, TextEditingController>>? controllersList,
//     required List<Map<String, String>> fields,
//     required bool hasFileAttachment,
//     required String fileFieldKey,
//     required String fileFieldLabel,
//     required Map<int, File> fileMap,
//     required Map<int, String> fileNameMap,
//     required List<String?> existingUrls,
//     required VoidCallback onAdd,
//     required Function(int) onDelete,
//     required Function(int) onPickFile,
//     required Function(int) onClearFile,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               title,
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//             ElevatedButton.icon(
//               onPressed: onAdd,
//               icon: Icon(Icons.add, size: 20),
//               label: Text('Add'),
//             ),
//           ],
//         ),
//         SizedBox(height: 10),
        
//         if (controllersList != null)
//           ...controllersList.asMap().entries.map((entry) {
//             int index = entry.key;
//             Map<String, TextEditingController> controllers = entry.value;
//             String? existingUrl = index < existingUrls.length ? existingUrls[index] : null;
            
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
//                           '${title} ${index + 1}',
//                           style: TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.delete, color: Colors.red),
//                           onPressed: () => onDelete(index),
//                         ),
//                       ],
//                     ),
//                     ...fields.map((field) {
//                       return Padding(
//                         padding: const EdgeInsets.only(bottom: 8),
//                         child: TextField(
//                           controller: controllers[field['key']],
//                           decoration: InputDecoration(
//                             labelText: field['label'],
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       );
//                     }).toList(),
                    
//                     if (hasFileAttachment)
//                       Padding(
//                         padding: const EdgeInsets.only(top: 8),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               fileFieldLabel,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
                            
//                             // Show existing file link if exists
//                             if (existingUrl != null && existingUrl.isNotEmpty)
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   InkWell(
//                                     onTap: () {
//                                       print('Existing File URL: $existingUrl');
//                                     },
//                                     child: Text(
//                                       'View Existing Attachment',
//                                       style: TextStyle(
//                                         color: Colors.blue,
//                                         decoration: TextDecoration.underline,
//                                       ),
//                                     ),
//                                   ),
//                                   SizedBox(height: 8),
//                                 ],
//                               ),
                            
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () => onPickFile(index),
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(
//                                       fileNameMap[index] ?? 
//                                       (existingUrl != null && existingUrl.isNotEmpty ? 
//                                         'Keep Existing / Select New' : 
//                                         'Select $fileFieldLabel'),
//                                     ),
//                                   ),
//                                 ),
//                                 if (fileNameMap.containsKey(index))
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () => onClearFile(index),
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             );
//           }).toList(),
//       ],
//     );
//   }

//   Widget _buildFileAttachmentField({
//     required String field,
//     required String label,
//     required String? value,
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
//           if (value != null && value.isNotEmpty)
//             InkWell(
//               onTap: () {
//                 print('File URL: $value');
//               },
//               child: Row(
//                 children: [
//                   Icon(Icons.attach_file, size: 16, color: Colors.blue),
//                   SizedBox(width: 4),
//                   Text(
//                     'View Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             Text('No attachment provided', style: TextStyle(fontSize: 14)),
//         ],
//       ),
//     );
//   }

//   Widget _buildEditFileAttachmentField({
//     required String field,
//     required String label,
//     required String currentValue,
//     required StateSetter setState,
//   }) {
//     // Get existing URL based on field
//     String? existingUrl;
//     switch (field) {
//       case 'pan_attachment':
//         existingUrl = existingPanAttachmentUrl;
//         break;
//       case 'gst_attachment':
//         existingUrl = existingGstAttachmentUrl;
//         break;
//       case 'bis_attachment':
//         existingUrl = existingBisAttachmentUrl;
//         break;
//       case 'msme_attachment':
//         existingUrl = existingMsmeAttachmentUrl;
//         break;
//       case 'tan_attachment':
//         existingUrl = existingTanAttachmentUrl;
//         break;
//       case 'cin_attach':
//         existingUrl = existingCinAttachmentUrl;
//         break;
//     }
    
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
          
//           // Show existing file link if exists
//           if (existingUrl != null && existingUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     print('Existing File URL: $existingUrl');
//                   },
//                   child: Text(
//                     'View Existing Attachment',
//                     style: TextStyle(
//                       color: Colors.blue,
//                       decoration: TextDecoration.underline,
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 8),
//               ],
//             ),
          
//           // File upload for edit mode
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     await pickFile(field);
//                     setState(() {});
//                   },
//                   icon: Icon(Icons.attach_file),
//                   label: Text(
//                     _getFileName(field) ?? 
//                     (existingUrl != null && existingUrl.isNotEmpty ? 
//                       'Keep Existing / Select New' : 
//                       'Select File'),
//                   ),
//                 ),
//               ),
//               if (_hasFileSelected(field))
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       _clearFileSelection(field);
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   String? _getFileName(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         return panAttachmentFileName;
//       case 'gst_attachment':
//         return gstAttachmentFileName;
//       case 'bis_attachment':
//         return bisAttachmentFileName;
//       case 'msme_attachment':
//         return msmeAttachmentFileName;
//       case 'tan_attachment':
//         return tanAttachmentFileName;
//       case 'cin_attach':
//         return cinAttachmentFileName;
//       default:
//         return null;
//     }
//   }

//   bool _hasFileSelected(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         return panAttachmentFileName != null;
//       case 'gst_attachment':
//         return gstAttachmentFileName != null;
//       case 'bis_attachment':
//         return bisAttachmentFileName != null;
//       case 'msme_attachment':
//         return msmeAttachmentFileName != null;
//       case 'tan_attachment':
//         return tanAttachmentFileName != null;
//       case 'cin_attach':
//         return cinAttachmentFileName != null;
//       default:
//         return false;
//     }
//   }

//   void _clearFileSelection(String field) {
//     switch (field) {
//       case 'pan_attachment':
//         panAttachmentFile = null;
//         panAttachmentFileName = null;
//         break;
//       case 'gst_attachment':
//         gstAttachmentFile = null;
//         gstAttachmentFileName = null;
//         break;
//       case 'bis_attachment':
//         bisAttachmentFile = null;
//         bisAttachmentFileName = null;
//         break;
//       case 'msme_attachment':
//         msmeAttachmentFile = null;
//         msmeAttachmentFileName = null;
//         break;
//       case 'tan_attachment':
//         tanAttachmentFile = null;
//         tanAttachmentFileName = null;
//         break;
//       case 'cin_attach':
//         cinAttachmentFile = null;
//         cinAttachmentFileName = null;
//         break;
//     }
//   }

//   Future<void> pickFile(String field) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         switch (field) {
//           case 'pan_attachment':
//             panAttachmentFile = File(file.path);
//             panAttachmentFileName = path.basename(file.path);
//             break;
//           case 'gst_attachment':
//             gstAttachmentFile = File(file.path);
//             gstAttachmentFileName = path.basename(file.path);
//             break;
//           case 'bis_attachment':
//             bisAttachmentFile = File(file.path);
//             bisAttachmentFileName = path.basename(file.path);
//             break;
//           case 'msme_attachment':
//             msmeAttachmentFile = File(file.path);
//             msmeAttachmentFileName = path.basename(file.path);
//             break;
//           case 'tan_attachment':
//             tanAttachmentFile = File(file.path);
//             tanAttachmentFileName = path.basename(file.path);
//             break;
//           case 'cin_attach':
//             cinAttachmentFile = File(file.path);
//             cinAttachmentFileName = path.basename(file.path);
//             break;
//         }
//       });
//     }
//   }

//   Future<void> pickNestedArrayFile(String type, int index) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
//     if (file != null) {
//       setState(() {
//         switch (type) {
//           case 'aadhar':
//             aadharAttachmentFiles[index] = File(file.path);
//             aadharAttachmentFileNames[index] = path.basename(file.path);
//             break;
//           case 'pan_detail':
//             panDetailAttachmentFiles[index] = File(file.path);
//             panDetailAttachmentFileNames[index] = path.basename(file.path);
//             break;
//           case 'cheque_leaf':
//             bankChequeLeafFiles[index] = File(file.path);
//             bankChequeLeafFileNames[index] = path.basename(file.path);
//             break;
//         }
//       });
//     }
//   }

//   Future<void> updateKYC(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Use PUT method to update
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add ALL text fields (even empty ones)
//       editControllers!.forEach((key, controller) {
//         // Skip file attachment fields as text
//         if (!key.endsWith('_attachment') && key != 'cin_attach') {
//           request.fields[key] = controller.text.trim();
//         }
//       });

//       // Add file attachments - only if new files are selected
//       // If no new file is selected, the existing file should be preserved
//       await _addFileAttachments(request);

//       // Add nested arrays
//       await _addNestedArrays(request);

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 200) {
//         // Clear all controllers after successful update
//         _disposeAllControllers();
//         editControllers = null;
//         editAadharDetailControllers = null;
//         editPanDetailControllers = null;
//         editBankDetailControllers = null;
//         editingKycId = null;
        
//         // Reset all file selections
//         _resetFileSelections();
        
//         // Clear existing URLs
//         existingPanAttachmentUrl = null;
//         existingGstAttachmentUrl = null;
//         existingBisAttachmentUrl = null;
//         existingMsmeAttachmentUrl = null;
//         existingTanAttachmentUrl = null;
//         existingCinAttachmentUrl = null;
//         existingAadharAttachmentUrls.clear();
//         existingPanAttachmentUrls.clear();
//         existingChequeLeafUrls.clear();
        
//         // Refresh the KYC list
//         fetchKYCRecords();
        
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('KYC updated successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );
//       } else {
//         final responseBody = await response.stream.bytesToString();
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to update KYC. Status: ${response.statusCode}'),
//             backgroundColor: Colors.red,
//           ),
//         );
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

//   Future<void> _addFileAttachments(http.MultipartRequest request) async {
//     // Add PAN attachment only if new file is selected
//     if (panAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'pan_attachment',
//           panAttachmentFile!.path,
//           filename: panAttachmentFileName,
//         ),
//       );
//     } else if (existingPanAttachmentUrl != null && existingPanAttachmentUrl!.isNotEmpty) {
//       request.fields['pan_attachment'] = existingPanAttachmentUrl!;
//     }

//     // Add GST attachment
//     if (gstAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'gst_attachment',
//           gstAttachmentFile!.path,
//           filename: gstAttachmentFileName,
//         ),
//       );
//     } else if (existingGstAttachmentUrl != null && existingGstAttachmentUrl!.isNotEmpty) {
//       request.fields['gst_attachment'] = existingGstAttachmentUrl!;
//     }

//     // Add BIS attachment
//     if (bisAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'bis_attachment',
//           bisAttachmentFile!.path,
//           filename: bisAttachmentFileName,
//         ),
//       );
//     } else if (existingBisAttachmentUrl != null && existingBisAttachmentUrl!.isNotEmpty) {
//       request.fields['bis_attachment'] = existingBisAttachmentUrl!;
//     }

//     // Add MSME attachment
//     if (msmeAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'msme_attachment',
//           msmeAttachmentFile!.path,
//           filename: msmeAttachmentFileName,
//         ),
//       );
//     } else if (existingMsmeAttachmentUrl != null && existingMsmeAttachmentUrl!.isNotEmpty) {
//       request.fields['msme_attachment'] = existingMsmeAttachmentUrl!;
//     }

//     // Add TAN attachment
//     if (tanAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'tan_attachment',
//           tanAttachmentFile!.path,
//           filename: tanAttachmentFileName,
//         ),
//       );
//     } else if (existingTanAttachmentUrl != null && existingTanAttachmentUrl!.isNotEmpty) {
//       request.fields['tan_attachment'] = existingTanAttachmentUrl!;
//     }

//     // Add CIN attachment
//     if (cinAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'cin_attach',
//           cinAttachmentFile!.path,
//           filename: cinAttachmentFileName,
//         ),
//       );
//     } else if (existingCinAttachmentUrl != null && existingCinAttachmentUrl!.isNotEmpty) {
//       request.fields['cin_attach'] = existingCinAttachmentUrl!;
//     }
//   }

//   Future<void> _addNestedArrays(http.MultipartRequest request) async {
//     // Add aadhar details
//     if (editAadharDetailControllers != null) {
//       for (int i = 0; i < editAadharDetailControllers!.length; i++) {
//         var controllers = editAadharDetailControllers![i];
//         String name = controllers['aadhar_name']?.text.trim() ?? '';
//         String number = controllers['aadhar_no']?.text.trim() ?? '';
        
//         // Add text fields
//         if (name.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_name]'] = name;
//         }
//         if (number.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_no]'] = number;
//         }
        
//         // Add file attachment if new file is selected
//         if (aadharAttachmentFiles.containsKey(i)) {
//           File? file = aadharAttachmentFiles[i];
//           String? filename = aadharAttachmentFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'aadhar_detail[$i][aadhar_attach]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingAadharAttachmentUrls.length && 
//                    existingAadharAttachmentUrls[i] != null && 
//                    existingAadharAttachmentUrls[i]!.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_attach]'] = existingAadharAttachmentUrls[i]!;
//         }
//       }
//     }

//     // Add pan details
//     if (editPanDetailControllers != null) {
//       for (int i = 0; i < editPanDetailControllers!.length; i++) {
//         var controllers = editPanDetailControllers![i];
//         String name = controllers['pan_name']?.text.trim() ?? '';
//         String number = controllers['pan_no']?.text.trim() ?? '';
        
//         // Add text fields
//         if (name.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_name]'] = name;
//         }
//         if (number.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_no]'] = number;
//         }
        
//         // Add file attachment if new file is selected
//         if (panDetailAttachmentFiles.containsKey(i)) {
//           File? file = panDetailAttachmentFiles[i];
//           String? filename = panDetailAttachmentFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'pan_detail[$i][pan_attachment]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingPanAttachmentUrls.length && 
//                    existingPanAttachmentUrls[i] != null && 
//                    existingPanAttachmentUrls[i]!.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_attachment]'] = existingPanAttachmentUrls[i]!;
//         }
//       }
//     }

//     // Add bank details
//     if (editBankDetailControllers != null) {
//       for (int i = 0; i < editBankDetailControllers!.length; i++) {
//         var controllers = editBankDetailControllers![i];
        
//         // Add text fields
//         request.fields['bank_detail[$i][bank_name]'] = controllers['bank_name']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][account_name]'] = controllers['account_name']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][account_no]'] = controllers['account_no']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][ifsc_code]'] = controllers['ifsc_code']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][branch]'] = controllers['branch']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][bank_city]'] = controllers['bank_city']?.text.trim() ?? '';
//         request.fields['bank_detail[$i][bank_state]'] = controllers['bank_state']?.text.trim() ?? '';
        
//         // Add file attachment if new file is selected
//         if (bankChequeLeafFiles.containsKey(i)) {
//           File? file = bankChequeLeafFiles[i];
//           String? filename = bankChequeLeafFileNames[i];
          
//           if (file != null && filename != null && filename.isNotEmpty) {
//             request.files.add(
//               await http.MultipartFile.fromPath(
//                 'bank_detail[$i][cheque_leaf]',
//                 file.path,
//                 filename: filename,
//               ),
//             );
//           }
//         } else if (i < existingChequeLeafUrls.length && 
//                    existingChequeLeafUrls[i] != null && 
//                    existingChequeLeafUrls[i]!.isNotEmpty) {
//           request.fields['bank_detail[$i][cheque_leaf]'] = existingChequeLeafUrls[i]!;
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final selectedFields = getSelectedFields();
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//         actions: [
//           // Field Selection button
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
//             onPressed: () => fetchKYCRecords(),
//             tooltip: 'Refresh',
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Text('No KYC records found'),
//                       if (filterParams.isNotEmpty) ...[
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
                    
//                     // Show active filters if any
//                     if (filterParams.isNotEmpty)
//                       Container(
//                         padding: EdgeInsets.all(8),
//                         color: Colors.blue.shade50,
//                         child: Row(
//                           children: [
//                             Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                             SizedBox(width: 8),
//                             Expanded(
//                               child: Text(
//                                 'Filters: ${filterParams.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
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
//                             columnSpacing: compactRows ? 15 : 24,
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
//                             rows: kycRecords.map((record) {
//                               final id = record['id'];
//                               final isSelected = selectedIds.contains(id);
//                               final bool isCompleted = record['is_completed'] == true;

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
//                                           v == true
//                                               ? selectedIds.add(id)
//                                               : selectedIds.remove(id);
//                                         });
//                                       },
//                                     ),
//                                   ),

//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               // View button
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, false),
//                                                 child: Text(
//                                                   'View',
//                                                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                 ),
//                                                 style: ElevatedButton.styleFrom(
//                                                   padding: EdgeInsets.symmetric(horizontal: 8),
//                                                 ),
//                                               ),
//                                               SizedBox(width: 8),
                                              
//                                               // Edit button - disabled if completed
//                                               if (!isCompleted)
//                                                 ElevatedButton(
//                                                   onPressed: () =>
//                                                       showKYCDetailDialog(record, true),
//                                                   child: Text(
//                                                     'Edit',
//                                                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                   ),
//                                                   style: ElevatedButton.styleFrom(
//                                                     padding: EdgeInsets.symmetric(horizontal: 8),
//                                                   ),
//                                                 ),
//                                               SizedBox(width: isCompleted ? 0 : 8),
                                              
//                                               // Complete/Reopen button
//                                               ElevatedButton(
//                                                 onPressed: () => _showCompletionDialog(record),
//                                                 child: Text(
//                                                   isCompleted ? 'Reopen' : 'Complete',
//                                                   style: TextStyle(fontSize: compactRows ? 11 : 13),
//                                                 ),
//                                                 style: ElevatedButton.styleFrom(
//                                                   backgroundColor: isCompleted ? Colors.orange : Colors.green,
//                                                   padding: EdgeInsets.symmetric(horizontal: 8),
//                                                 ),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   // Selected fields only
//                                   ...selectedFields.map((f) {
//                                     String displayValue = getFieldValue(record, f['key']);
                                    
//                                     // Special handling for attachments
//                                     if ((f['key'].endsWith('_attachment') || f['key'] == 'cin_attach') && displayValue.isNotEmpty) {
//                                       return DataCell(
//                                         GestureDetector(
//                                           onTap: () {
//                                             final url = record[f['key']];
//                                             print('Open file: $url');
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
//                                                 Icon(
//                                                   f['key'] == 'cin_attach' ? Icons.description : Icons.attachment,
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
                                    
//                                     // Special handling for complex fields (arrays)
//                                     if (f['isComplex'] == true) {
//                                       final details = record[f['key']];
//                                       if (details != null && details is List) {
//                                         return DataCell(
//                                           Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                             decoration: BoxDecoration(
//                                               color: Colors.green.shade50,
//                                               borderRadius: BorderRadius.circular(4),
//                                             ),
//                                             child: Text(
//                                               '${details.length} items',
//                                               style: TextStyle(
//                                                 fontSize: compactRows ? 11 : 13,
//                                                 color: Colors.green.shade800,
//                                               ),
//                                             ),
//                                           ),
//                                         );
//                                       }
//                                     }
                                    
//                                     // Special handling for status
//                                     if (f['key'] == 'is_completed') {
//                                       bool completed = record['is_completed'] == true;
//                                       return DataCell(
//                                         Container(
//                                           padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                                           decoration: BoxDecoration(
//                                             color: completed ? Colors.green.shade50 : Colors.orange.shade50,
//                                             borderRadius: BorderRadius.circular(4),
//                                           ),
//                                           child: Row(
//                                             mainAxisSize: MainAxisSize.min,
//                                             children: [
//                                               Icon(
//                                                 completed ? Icons.lock : Icons.lock_open,
//                                                 size: compactRows ? 12 : 14,
//                                                 color: completed ? Colors.green : Colors.orange,
//                                               ),
//                                               SizedBox(width: 2),
//                                               Text(
//                                                 completed ? 'Completed' : 'In Progress',
//                                                 style: TextStyle(
//                                                   fontSize: compactRows ? 11 : 13,
//                                                   color: completed ? Colors.green.shade800 : Colors.orange.shade800,
//                                                   fontWeight: FontWeight.w500,
//                                                 ),
//                                               ),
//                                             ],
//                                           ),
//                                         ),
//                                       );
//                                     }
                                    
//                                     return DataCell(
//                                       Container(
//                                         constraints: wrapColumnText 
//                                             ? BoxConstraints(maxWidth: 200) 
//                                             : null,
//                                         child: Text(
//                                           displayValue,
//                                           style: TextStyle(
//                                             fontSize: compactRows ? 11 : 13,
//                                             color: modernCellColoring && isSelected 
//                                                 ? Colors.blue 
//                                                 : null,
//                                           ),
//                                           softWrap: wrapColumnText,
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
//                             'Page $currentPage | Total: $totalCount',
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