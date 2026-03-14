import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';

class CataloguePage extends StatefulWidget {
  @override
  _CataloguePageState createState() => _CataloguePageState();
}

class _CataloguePageState extends State<CataloguePage> {
  // Data lists
  List<Map<String, dynamic>> catalogues = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  Map<String, dynamic>? currentViewedCatalogue;

  // API Endpoints
  final String listApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/lists/';
  final String createApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/create/';
  final String detailApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/details/';
  final String updateApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/update/';

  // Additional API Endpoints for dropdowns
  final String buyerApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
  final String productApiUrl = 'http://127.0.0.1:8000/Products/products/list/';

  // Data for dropdowns - store both display value and actual ID
  List<Map<String, dynamic>> buyerOptions = []; // Each item: {'display': 'BP001 - Name', 'id': 123}
  List<Map<String, dynamic>> productOptions = []; // Each item: {'display': 'P001 - Product Name', 'id': 456}

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
    {'key': 'id', 'label': 'ID', 'selected': false, 'order': 0},
    {'key': 'catalogue_name', 'label': 'Catalogue Name', 'selected': true, 'order': 1},
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 2},
    {'key': 'product_code', 'label': 'Product Codes', 'selected': true, 'order': 3},
    {'key': 'add_image', 'label': 'Image', 'selected': false, 'isFile': true, 'order': 4},
    {'key': 'add_video', 'label': 'Video', 'selected': false, 'isFile': true, 'order': 5},
  ];

  // Filter controllers
  final TextEditingController catalogueNameController = TextEditingController();
  final TextEditingController bpCodeController = TextEditingController();
  final TextEditingController productCodeController = TextEditingController();

  // Create controllers
  final Map<String, TextEditingController> createControllers = {};

  // Create dropdown values - store IDs instead of display strings
  int? selectedCreateBpId;
  List<int> selectedCreateProductIds = []; // Multiple product IDs

  // Edit controllers
  Map<String, TextEditingController>? editControllers;
  int? editingCatalogueId;

  // Edit dropdown values - store IDs instead of display strings
  int? selectedEditBpId;
  List<int> selectedEditProductIds = []; // Multiple product IDs

  // File uploads - Use XFile for better cross-platform support
  XFile? imageXFile;
  XFile? videoXFile;

  // Required fields for catalogue
  final List<String> requiredFields = [
    'catalogue_name',
    'bp_code',
    'product_code',
    'add_image',
    'add_video',
  ];

  // Fields to exclude from certain operations
  final List<String> excludeFromCreate = [];
  final List<String> excludeFromEdit = [];
  final List<String> excludeFromDisplay = [];

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
    catalogueNameController.dispose();
    bpCodeController.dispose();
    productCodeController.dispose();

    createControllers.forEach((key, controller) {
      controller.dispose();
    });

    if (editControllers != null) {
      editControllers!.forEach((key, controller) {
        controller.dispose();
      });
    }

    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Load saved field selections from SharedPreferences
  Future<void> loadSavedFieldSelections() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedSelections = prefs.getString('catalogue_fields');
    String? savedOrder = prefs.getString('catalogue_field_order');

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

    if (savedOrder != null) {
      try {
        List<dynamic> savedOrderList = json.decode(savedOrder);
        setState(() {
          List<Map<String, dynamic>> reorderedFields = [];
          for (String key in savedOrderList) {
            final index = availableFields.indexWhere((f) => f['key'] == key);
            if (index != -1) {
              reorderedFields.add(availableFields[index]);
            }
          }
          for (var field in availableFields) {
            if (!reorderedFields.any((f) => f['key'] == field['key'])) {
              reorderedFields.add(field);
            }
          }
          availableFields = reorderedFields;

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

    await prefs.setString('catalogue_fields', json.encode(selections));
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('catalogue_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      compactRows = prefs.getBool('catalogue_compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('catalogue_active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('catalogue_modern_cell_coloring') ?? false;
      enableView = prefs.getBool('catalogue_enable_view') ?? true;
      enableEdit = prefs.getBool('catalogue_enable_edit') ?? true;
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

    await prefs.setBool('catalogue_compact_rows', compactRows);
    await prefs.setBool('catalogue_active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('catalogue_modern_cell_coloring', modernCellColoring);
    await prefs.setBool('catalogue_enable_view', enableView);
    await prefs.setBool('catalogue_enable_edit', enableEdit);
  }

  // Get selected fields for display in correct order
  List<Map<String, dynamic>> getSelectedFields() {
    return availableFields
        .where((field) => field['selected'] == true)
        .toList()
      ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
  }

  // Load token and initial data
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
    });

    if (token != null && token!.isNotEmpty) {
      try {
        await Future.wait([
          fetchBuyerOptions(),
          fetchProductOptions(),
        ]);
        await fetchCatalogues();
      } catch (e) {
        print('Error loading data: $e');
        setState(() => isLoading = false);
        _showSnackBar('Error loading data: $e', isError: true);
      }
    } else {
      setState(() => isLoading = false);
      print('⚠️ No token found. Please login again.');
      _showSnackBar('No authentication token found. Please login again.', isError: true);
    }
  }

  // Fetch Buyer Options (with both display value and ID)
  Future<void> fetchBuyerOptions() async {
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(buyerApiUrl),
        headers: {'Authorization': 'Token $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> buyerList = [];

        if (data is Map && data.containsKey('results')) {
          buyerList = List<Map<String, dynamic>>.from(data['results'] ?? []);
        } else if (data is List) {
          buyerList = List<Map<String, dynamic>>.from(data);
        }

        List<Map<String, dynamic>> options = [];
        buyerList.forEach((buyer) {
          final id = buyer['id'];
          final bpCode = buyer['bp_code']?.toString() ?? '';
          final bpName = buyer['bp_name']?.toString() ?? '';
          final displayValue = bpName.isNotEmpty ? '$bpCode - $bpName' : bpCode;
          if (id != null && bpCode.isNotEmpty) {
            options.add({
              'id': id,
              'display': displayValue,
              'code': bpCode,
            });
          }
        });

        setState(() {
          buyerOptions = options..sort((a, b) => a['display'].compareTo(b['display']));
        });
      } else {
        print('Failed to fetch buyers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  // Fetch Product Options (with both display value and ID)
  Future<void> fetchProductOptions() async {
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(productApiUrl),
        headers: {'Authorization': 'Token $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> productList = [];

        if (data is Map && data.containsKey('results')) {
          productList = List<Map<String, dynamic>>.from(data['results'] ?? []);
        } else if (data is List) {
          productList = List<Map<String, dynamic>>.from(data);
        }

        List<Map<String, dynamic>> options = [];
        productList.forEach((product) {
          final id = product['id'];
          final productCode = product['product_code']?.toString() ?? '';
          final productName = product['product_name']?.toString() ?? '';
          final displayValue = productName.isNotEmpty ? '$productCode - $productName' : productCode;
          if (id != null && productCode.isNotEmpty) {
            options.add({
              'id': id,
              'display': displayValue,
              'code': productCode,
            });
          }
        });

        setState(() {
          productOptions = options..sort((a, b) => a['display'].compareTo(b['display']));
        });
      } else {
        print('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching products: $e');
    }
  }

  // Helper Methods
  int safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(value);
      if (doubleParsed != null) return doubleParsed.toInt();
    }
    return 0;
  }

  String formatFieldName(String field) {
    return field.replaceAll('_', ' ').toUpperCase();
  }

  bool isFileField(String field) {
    return field == 'add_image' || field == 'add_video';
  }

  bool isFieldDisplayable(String field) {
    return !excludeFromDisplay.contains(field);
  }

  // Get field value with proper formatting
  String getFieldValue(Map<String, dynamic> catalogue, String key) {
    final value = catalogue[key];

    if (value == null) return '-';

    if (value is bool) {
      return value.toString();
    }

    if (key == 'product_code') {
      if (value is List) {
        if (value.isEmpty) return '-';
        List<String> displays = [];
        for (var id in value) {
          final product = productOptions.firstWhere(
            (p) => p['id'] == id,
            orElse: () => {'display': id.toString()},
          );
          displays.add(product['display']);
        }
        return displays.join(', ');
      }
      return value.toString();
    }

    if (key == 'bp_code') {
      // Convert ID to display value if possible
      final buyer = buyerOptions.firstWhere(
        (b) => b['id'] == value,
        orElse: () => {'display': value.toString()},
      );
      return buyer['display'];
    }

    return value.toString();
  }

  // Get buyer display from ID
  String getBuyerDisplay(int? id) {
    if (id == null) return '-';
    final buyer = buyerOptions.firstWhere(
      (b) => b['id'] == id,
      orElse: () => {'display': id.toString()},
    );
    return buyer['display'];
  }

  // Get product display from ID
  String getProductDisplay(int id) {
    final product = productOptions.firstWhere(
      (p) => p['id'] == id,
      orElse: () => {'display': id.toString()},
    );
    return product['display'];
  }

  // API Request Building
  String buildRequestUrl() {
    if (filterParams.isEmpty && sortBy == null) {
      return listApiUrl;
    }
    
    Map<String, String> queryParams = {};

    filterParams.forEach((key, value) {
      if (value.isNotEmpty) {
        queryParams[key] = value;
      }
    });

    if (sortBy != null && sortBy!.isNotEmpty) {
      queryParams['sort_by'] = sortBy!;
      if (sortOrder != null && sortOrder!.isNotEmpty) {
        queryParams['sort_order'] = sortOrder!;
      }
    }

    if (pageSize != 20) {
      queryParams['page_size'] = pageSize.toString();
    }
    if (currentPage > 1) {
      queryParams['page'] = currentPage.toString();
    }

    Uri uri = Uri.parse(listApiUrl);
    return uri.replace(queryParameters: queryParams).toString();
  }

  // Fetch Catalogues
  Future<void> fetchCatalogues({String? url}) async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final requestUrl = url ?? buildRequestUrl();
      print('Fetching: $requestUrl');

      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {'Authorization': 'Token $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<Map<String, dynamic>> results = [];
        
        if (data is List) {
          results = List<Map<String, dynamic>>.from(data);
          setState(() {
            catalogues = results;
            nextUrl = null;
            prevUrl = null;
            totalCount = results.length;
            currentPage = 1;
            selectedIds.clear();
            isLoading = false;
          });
        } else if (data is Map) {
          if (data.containsKey('results')) {
            results = List<Map<String, dynamic>>.from(data['results'] ?? []);
          }
          
          setState(() {
            catalogues = results;
            nextUrl = data['next'];
            prevUrl = data['previous'];
            totalCount = safeParseInt(data['count']);

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

            selectedIds.clear();
            isLoading = false;
          });
        } else {
          setState(() {
            catalogues = [];
            isLoading = false;
          });
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch catalogues: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
      _showSnackBar('Connection error: Please check if backend server is running', isError: true);
    }
  }

  // Fetch Single Catalogue Details
  Future<void> fetchCatalogueDetails(int id) async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$detailApiUrl$id/'),
        headers: {'Authorization': 'Token $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          currentViewedCatalogue = data;
          isLoading = false;
        });
        showCatalogueDetailDialog();
      } else {
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch catalogue details', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // Filter Methods
  Future<void> applyFilters() async {
    filterParams.clear();

    if (catalogueNameController.text.isNotEmpty) {
      filterParams['catalogue_name'] = catalogueNameController.text;
    }
    if (bpCodeController.text.isNotEmpty) {
      filterParams['bp_code'] = bpCodeController.text;
    }
    if (productCodeController.text.isNotEmpty) {
      filterParams['product_code'] = productCodeController.text;
    }

    currentPage = 1;
    await fetchCatalogues();
    Navigator.pop(context);
  }

  Future<void> clearFilters() async {
    filterParams.clear();

    catalogueNameController.clear();
    bpCodeController.clear();
    productCodeController.clear();

    await fetchCatalogues();
  }

  void showFilterDialog() {
    catalogueNameController.text = filterParams['catalogue_name'] ?? '';
    bpCodeController.text = filterParams['bp_code'] ?? '';
    productCodeController.text = filterParams['product_code'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Catalogues'),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterField(catalogueNameController, 'Catalogue Name', Icons.book),
                      _buildFilterField(bpCodeController, 'BP Code', Icons.qr_code),
                      _buildFilterField(productCodeController, 'Product Code', Icons.code),
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

  Widget _buildFilterField(TextEditingController controller, String label, IconData icon) {
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
    await fetchCatalogues();
  }

  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchCatalogues();
  }

  void toggleSortOrder() {
    if (sortBy == null) return;
    String newOrder = sortOrder == 'asc' ? 'desc' : 'asc';
    applySort(sortBy!, newOrder);
  }

  void showSortDialog() {
    List<Map<String, String>> sortFields = [
      {'value': 'catalogue_name', 'label': 'Catalogue Name'},
      {'value': 'bp_code', 'label': 'BP Code'},
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
                            border: Border.all(color: Colors.grey.shade300),
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
                      fetchCatalogues();
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
      fetchCatalogues(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchCatalogues(url: prevUrl);
    }
  }

  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    await fetchCatalogues();
  }

  // Create Catalogue Methods
  void showAddCatalogueDialog() {
    for (var field in requiredFields) {
      if (!excludeFromCreate.contains(field) &&
          !isFileField(field) &&
          !createControllers.containsKey(field)) {
        createControllers[field] = TextEditingController();
      }
    }

    // Reset selections
    imageXFile = null;
    videoXFile = null;
    selectedCreateBpId = null;
    selectedCreateProductIds = []; // Reset multiple product IDs

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Catalogue'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCreateTextField('catalogue_name', 'Catalogue Name', Icons.book, isRequired: true),
                    
                    // BP Code dropdown (using IDs)
                    _buildCreateDropdownField(
                      value: selectedCreateBpId,
                      label: 'BP Code *',
                      icon: Icons.qr_code,
                      items: buyerOptions.map((option) => DropdownMenuItem<int>(
                        value: option['id'],
                        child: Text(option['display']),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedCreateBpId = value),
                    ),

                    // Product Codes multi-select
                    _buildCreateMultiSelectField(
                      selectedIds: selectedCreateProductIds,
                      label: 'Product Codes *',
                      icon: Icons.code,
                      options: productOptions,
                      onChanged: (ids) => setState(() => selectedCreateProductIds = ids),
                    ),

                    // Image file field
                    _buildCreateFileField(
                      field: 'add_image',
                      label: 'Image',
                      icon: Icons.image,
                      file: imageXFile,
                      onPickFile: () => pickImage(setState),
                      onClearFile: () {
                        setState(() {
                          imageXFile = null;
                        });
                      },
                    ),

                    // Video file field
                    _buildCreateFileField(
                      field: 'add_video',
                      label: 'Video',
                      icon: Icons.video_library,
                      file: videoXFile,
                      onPickFile: () => pickVideo(setState),
                      onClearFile: () {
                        setState(() {
                          videoXFile = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (createControllers['catalogue_name']?.text.isEmpty == true) {
                    _showSnackBar('Please enter catalogue name', isError: true);
                    return;
                  }
                  if (selectedCreateBpId == null) {
                    _showSnackBar('Please select BP Code', isError: true);
                    return;
                  }
                  if (selectedCreateProductIds.isEmpty) {
                    _showSnackBar('Please select at least one Product Code', isError: true);
                    return;
                  }
                  await createCatalogue();
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
      {bool isRequired = false, int maxLines = 1}) {
    if (!createControllers.containsKey(field)) {
      createControllers[field] = TextEditingController();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: createControllers[field],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildCreateDropdownField({
    required int? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<int>> items,
    required Function(int?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        items: items,
        onChanged: items.isEmpty ? null : onChanged,
        validator: (value) {
          if (value == null) {
            return 'Please select an option';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildCreateMultiSelectField({
    required List<int> selectedIds,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required Function(List<int>) onChanged,
  }) {
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Selected chips
                if (selectedIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: selectedIds.map((id) {
                        final option = options.firstWhere(
                          (o) => o['id'] == id,
                          orElse: () => {'display': id.toString()},
                        );
                        return Chip(
                          label: Text(option['display']),
                          onDeleted: () {
                            List<int> newIds = List.from(selectedIds);
                            newIds.remove(id);
                            onChanged(newIds);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                
                // Dropdown to add new items
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: DropdownButton<int>(
                    isExpanded: true,
                    hint: Text('Select product code to add'),
                    value: null,
                    items: options
                        .where((option) => !selectedIds.contains(option['id']))
                        .map((option) {
                      return DropdownMenuItem<int>(
                        value: option['id'],
                        child: Text(option['display']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        List<int> newIds = List.from(selectedIds);
                        newIds.add(value);
                        onChanged(newIds);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFileField({
    required String field,
    required String label,
    required IconData icon,
    required XFile? file,
    required VoidCallback onPickFile,
    required VoidCallback onClearFile,
  }) {
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
                  onPressed: onPickFile,
                  icon: Icon(icon),
                  label: Text(
                    file != null ? path.basename(file.path) : 'Select $label',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (file != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: onClearFile,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> pickImage(StateSetter setState) async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          imageXFile = file;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> pickVideo(StateSetter setState) async {
    try {
      final XFile? file = await _imagePicker.pickVideo(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          videoXFile = file;
        });
      }
    } catch (e) {
      print('Error picking video: $e');
      _showSnackBar('Error picking video: $e', isError: true);
    }
  }

  Future<void> createCatalogue() async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse(createApiUrl));
      request.headers['Authorization'] = 'Token $token';

      // Add text fields
      createControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty && !isFileField(key)) {
          request.fields[key] = controller.text;
        }
      });

      // Add BP code (send ID, not display string)
      if (selectedCreateBpId != null) {
        request.fields['bp_code'] = selectedCreateBpId!.toString();
      }

      // Add product codes as JSON array (send IDs as list)
      if (selectedCreateProductIds.isNotEmpty) {
        request.fields['product_code'] = json.encode(selectedCreateProductIds);
      }

      // Add image if selected with proper filename
      if (imageXFile != null) {
        String filename = path.basename(imageXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(imageXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          final bytes = await imageXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'add_image',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(imageXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'add_image',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      // Add video if selected with proper filename
      if (videoXFile != null) {
        String filename = path.basename(videoXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(videoXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.mp4'; // Default to .mp4
          }
        }

        if (kIsWeb) {
          final bytes = await videoXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'add_video',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(videoXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'add_video',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201 || response.statusCode == 200) {
        createControllers.forEach((key, controller) {
          controller.clear();
        });

        imageXFile = null;
        videoXFile = null;
        selectedCreateBpId = null;
        selectedCreateProductIds.clear();

        await fetchCatalogues();
        _showSnackBar('Catalogue created successfully!');
      } else {
        print('Error response: $responseBody');
        _showSnackBar('Failed to create catalogue: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error in createCatalogue: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Edit Catalogue Methods
  void showEditCatalogueDialog(Map<String, dynamic> catalogue) {
    editingCatalogueId = catalogue['id'];
    editControllers = {};

    for (var field in requiredFields) {
      if (!excludeFromEdit.contains(field) && !isFileField(field)) {
        editControllers![field] = TextEditingController(
          text: catalogue[field]?.toString() ?? '',
        );
      }
    }

    // Set dropdown values for edit (using IDs)
    selectedEditBpId = catalogue['bp_code'];
    
    // Handle product codes (list of IDs)
    if (catalogue['product_code'] != null && catalogue['product_code'] is List) {
      selectedEditProductIds = List<int>.from(catalogue['product_code']);
    } else {
      selectedEditProductIds = [];
    }

    // Reset file selections
    imageXFile = null;
    videoXFile = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit Catalogue'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditTextField('catalogue_name', 'Catalogue Name', Icons.book),

                    // BP Code dropdown (using IDs)
                    _buildEditDropdownField(
                      value: selectedEditBpId,
                      label: 'BP Code',
                      icon: Icons.qr_code,
                      items: buyerOptions.map((option) => DropdownMenuItem<int>(
                        value: option['id'],
                        child: Text(option['display']),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedEditBpId = value),
                    ),

                    // Product Codes multi-select
                    _buildEditMultiSelectField(
                      selectedIds: selectedEditProductIds,
                      label: 'Product Codes',
                      icon: Icons.code,
                      options: productOptions,
                      onChanged: (ids) => setState(() => selectedEditProductIds = ids),
                    ),

                    // Image file field
                    _buildEditFileField(
                      field: 'add_image',
                      label: 'Image',
                      icon: Icons.image,
                      file: imageXFile,
                      existingUrl: catalogue['add_image'],
                      onPickFile: () => pickImage(setState),
                      onClearFile: () {
                        setState(() {
                          imageXFile = null;
                        });
                      },
                    ),

                    // Video file field
                    _buildEditFileField(
                      field: 'add_video',
                      label: 'Video',
                      icon: Icons.video_library,
                      file: videoXFile,
                      existingUrl: catalogue['add_video'],
                      onPickFile: () => pickVideo(setState),
                      onClearFile: () {
                        setState(() {
                          videoXFile = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await updateCatalogue(editingCatalogueId!);
                  Navigator.pop(context);
                },
                child: Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  editControllers = null;
                  editingCatalogueId = null;
                  imageXFile = null;
                  videoXFile = null;
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

  Widget _buildEditTextField(String field, String label, IconData icon,
      {int maxLines = 1}) {
    if (editControllers == null || !editControllers!.containsKey(field)) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: editControllers![field],
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildEditDropdownField({
    required int? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<int>> items,
    required Function(int?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        items: items,
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget _buildEditMultiSelectField({
    required List<int> selectedIds,
    required String label,
    required IconData icon,
    required List<Map<String, dynamic>> options,
    required Function(List<int>) onChanged,
  }) {
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Selected chips
                if (selectedIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: selectedIds.map((id) {
                        final option = options.firstWhere(
                          (o) => o['id'] == id,
                          orElse: () => {'display': id.toString()},
                        );
                        return Chip(
                          label: Text(option['display']),
                          onDeleted: () {
                            List<int> newIds = List.from(selectedIds);
                            newIds.remove(id);
                            onChanged(newIds);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                
                // Dropdown to add new items
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: DropdownButton<int>(
                    isExpanded: true,
                    hint: Text('Select product code to add'),
                    value: null,
                    items: options
                        .where((option) => !selectedIds.contains(option['id']))
                        .map((option) {
                      return DropdownMenuItem<int>(
                        value: option['id'],
                        child: Text(option['display']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        List<int> newIds = List.from(selectedIds);
                        newIds.add(value);
                        onChanged(newIds);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditFileField({
    required String field,
    required String label,
    required IconData icon,
    required XFile? file,
    required dynamic existingUrl,
    required VoidCallback onPickFile,
    required VoidCallback onClearFile,
  }) {
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
          
          // Show existing file if available
          if (existingUrl != null && existingUrl.toString().isNotEmpty && file == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _showFileDialog(label, existingUrl.toString()),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        field == 'add_image' ? Icons.image : Icons.video_library,
                        size: 16,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'View Existing $label',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // File picker
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPickFile,
                  icon: Icon(icon),
                  label: Text(
                    file != null ? path.basename(file.path) : 'Select New $label',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (file != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: onClearFile,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> updateCatalogue(int id) async {
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
        if (!isFileField(key)) {
          request.fields[key] = controller.text;
        }
      });

      // Add BP code (send ID, not display string)
      if (selectedEditBpId != null) {
        request.fields['bp_code'] = selectedEditBpId!.toString();
      }

      // Add product codes as JSON array (send IDs as list)
      if (selectedEditProductIds.isNotEmpty) {
        request.fields['product_code'] = json.encode(selectedEditProductIds);
      }

      // Add image if selected with proper filename
      if (imageXFile != null) {
        String filename = path.basename(imageXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(imageXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await imageXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'add_image',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(imageXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'add_image',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      // Add video if selected with proper filename
      if (videoXFile != null) {
        String filename = path.basename(videoXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(videoXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.mp4'; // Default to .mp4
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await videoXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'add_video',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(videoXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'add_video',
              file.path,
              filename: filename,
            ),
          );
        }
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        editControllers = null;
        editingCatalogueId = null;
        imageXFile = null;
        videoXFile = null;
        selectedEditBpId = null;
        selectedEditProductIds.clear();

        await fetchCatalogues();
        _showSnackBar('Catalogue updated successfully!');
      } else {
        print('Error response: $responseBody');
        _showSnackBar('Failed to update catalogue: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error in updateCatalogue: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // View Catalogue Details
  void showCatalogueDetailDialog() {
    if (currentViewedCatalogue == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Catalogue Details'),
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
    dynamic value = currentViewedCatalogue?[field];

    String displayValue = '-';
    if (field == 'product_code' && value is List) {
      if (value.isEmpty) {
        displayValue = '-';
      } else {
        List<String> displays = [];
        for (var id in value) {
          final product = productOptions.firstWhere(
            (p) => p['id'] == id,
            orElse: () => {'display': id.toString()},
          );
          displays.add(product['display']);
        }
        displayValue = displays.join(', ');
      }
    } else if (field == 'bp_code' && value != null) {
      final buyer = buyerOptions.firstWhere(
        (b) => b['id'] == value,
        orElse: () => {'display': value.toString()},
      );
      displayValue = buyer['display'];
    } else {
      displayValue = value?.toString() ?? '-';
    }

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
            child: _buildDetailValue(field, displayValue),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailValue(String field, String displayValue) {
    if (isFileField(field)) {
      if (displayValue != '-' && displayValue.isNotEmpty) {
        return InkWell(
          onTap: () => _showFileDialog(formatFieldName(field), displayValue),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'View ${field == 'add_image' ? 'Image' : 'Video'}',
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

    return Text(displayValue);
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
            if (title.toLowerCase().contains('image'))
              fileUrl.startsWith('http')
                  ? Image.network(
                      fileUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 100),
                    )
                  : Icon(Icons.image, size: 100)
            else
              Container(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library, size: 50, color: Colors.blue),
                      SizedBox(height: 8),
                      Text('Video file'),
                    ],
                  ),
                ),
              ),
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
        ],
      ),
    );
  }

  // Show Field Selection Dialog
  void showFieldSelectionDialog() {
    fieldSearchQuery = '';

    bool localCompactRows = compactRows;
    bool localActiveRowHighlighting = activeRowHighlighting;
    bool localModernCellColoring = modernCellColoring;
    bool localEnableView = enableView;
    bool localEnableEdit = enableEdit;

    int selectedFieldIndex = -1;

    List<Map<String, dynamic>> availableFieldsList = [];
    List<Map<String, dynamic>> selectedFieldsList = [];

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
                            'Personalize List Columns - Catalogues',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

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

                    Expanded(
                      child: Row(
                        children: [
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
                                        ? Center(child: Text('No fields found'))
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
                                                subtitle: field['isFile'] == true
                                                    ? Text('File field',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey))
                                                    : null,
                                                trailing: Icon(
                                                  Icons.add_circle_outline,
                                                  color: Colors.blue,
                                                  size: 22,
                                                ),
                                                onTap: () {
                                                  setState(() {
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

                          Container(
                            width: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  child: IconButton(
                                    icon: Icon(Icons.arrow_forward, size: 30),
                                    color: Colors.blue,
                                    onPressed: () {
                                      setState(() {
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
                                Container(
                                  margin: EdgeInsets.only(top: 16),
                                  child: IconButton(
                                    icon: Icon(Icons.arrow_back, size: 30),
                                    color: Colors.orange,
                                    onPressed: () {
                                      setState(() {
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
                                      ? Center(child: Text('No fields selected'))
                                      : ListView.builder(
                                          itemCount: selectedFieldsList.length,
                                          itemBuilder: (context, index) {
                                            final field = selectedFieldsList[index];
                                            return Container(
                                              color: selectedFieldIndex == index ? Colors.blue.shade50 : null,
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
                                                    fontWeight: selectedFieldIndex == index ? FontWeight.bold : FontWeight.w500,
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
                                availableFieldsList.clear();
                                selectedFieldsList.clear();

                                List<Map<String, dynamic>> defaultFields = [
                                  {'key': 'catalogue_name', 'label': 'Catalogue Name', 'selected': true},
                                  {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
                                  {'key': 'product_code', 'label': 'Product Codes', 'selected': true},
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
                                'Catalogues - Field Selection',
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
                              this.setState(() {
                                for (var field in availableFields) {
                                  field['selected'] = false;
                                }

                                for (int i = 0; i < selectedFieldsList.length; i++) {
                                  final selectedField = selectedFieldsList[i];
                                  final index = availableFields.indexWhere(
                                    (f) => f['key'] == selectedField['key'],
                                  );
                                  if (index != -1) {
                                    availableFields[index]['selected'] = true;
                                    availableFields[index]['order'] = i;
                                  }
                                }

                                int nextOrder = selectedFieldsList.length;
                                for (var field in availableFields) {
                                  if (field['selected'] != true) {
                                    field['order'] = nextOrder;
                                    nextOrder++;
                                  }
                                }

                                availableFields.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
                              });

                              await saveFieldSelections();

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

  void applyListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableView,
    required bool enableEdit,
  }) {
    saveListSettings(
      compactRows: compactRows,
      activeRowHighlighting: activeRowHighlighting,
      modernCellColoring: modernCellColoring,
      enableView: enableView,
      enableEdit: enableEdit,
    );

    setState(() {
      this.compactRows = compactRows;
      this.activeRowHighlighting = activeRowHighlighting;
      this.modernCellColoring = modernCellColoring;
      this.enableView = enableView;
      this.enableEdit = enableEdit;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('List settings applied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
                    sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
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
    if (catalogues.isEmpty) {
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

    return catalogues.map((catalogue) {
      final id = catalogue['id'];
      final isSelected = selectedIds.contains(id);

      List<DataCell> cells = [
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  selectedIds.clear();
                  selectedIds.add(id);
                } else {
                  selectedIds.remove(id);
                }
              });
            },
          ),
        ),

        DataCell(
          isSelected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (enableView)
                      ElevatedButton(
                        onPressed: () => fetchCatalogueDetails(id),
                        child: Text(
                          'View',
                          style: TextStyle(fontSize: compactRows ? 11 : 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(60, 30),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    
                    if (enableEdit) ...[
                      if (enableView) SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () => showEditCatalogueDialog(catalogue),
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

      for (var field in selectedFields) {
        String displayValue = getFieldValue(catalogue, field['key']);

        if (field['isFile'] == true && displayValue != '-') {
          cells.add(
            DataCell(
              InkWell(
                onTap: () => _showFileDialog(field['label'], catalogue[field['key']]?.toString() ?? ''),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: modernCellColoring ? Colors.purple.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        field['key'] == 'add_image' ? Icons.image : Icons.video_library,
                        size: compactRows ? 10 : 12,
                        color: modernCellColoring ? Colors.purple : Colors.blue,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: compactRows ? 10 : 12,
                          color: modernCellColoring ? Colors.purple : Colors.blue,
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
                    color: modernCellColoring && isSelected ? Colors.blue : null,
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
        title: Text('Catalogues'),
        actions: [
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
            onPressed: () => fetchCatalogues(),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: showAddCatalogueDialog,
              icon: Icon(Icons.add),
              label: Text('Add Catalogue'),
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
                            sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
                          ),
                          onPressed: toggleSortOrder,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

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
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                            onPressed: (prevUrl == null || prevUrl!.isEmpty) ? null : loadPrevPage,
                            child: Text(
                              'Previous',
                              style: TextStyle(fontSize: compactRows ? 11 : 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (prevUrl == null || prevUrl!.isEmpty) ? Colors.grey : null,
                              padding: EdgeInsets.symmetric(
                                horizontal: compactRows ? 8 : 16,
                                vertical: compactRows ? 4 : 8,
                              ),
                            ),
                          ),
                          SizedBox(width: compactRows ? 8 : 12),
                          ElevatedButton(
                            onPressed: (nextUrl == null || nextUrl!.isEmpty) ? null : loadNextPage,
                            child: Text(
                              'Next',
                              style: TextStyle(fontSize: compactRows ? 11 : 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (nextUrl == null || nextUrl!.isEmpty) ? Colors.grey : null,
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
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

// class CataloguePage extends StatefulWidget {
//   @override
//   _CataloguePageState createState() => _CataloguePageState();
// }

// class _CataloguePageState extends State<CataloguePage> {
//   // Data lists
//   List<Map<String, dynamic>> catalogues = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   Map<String, dynamic>? currentViewedCatalogue;

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/lists/';
//   final String createApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/create/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/details/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/Catalogue/Catalogue/update/';

//   // Additional API Endpoints for dropdowns
//   final String buyerApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
//   final String productApiUrl = 'http://127.0.0.1:8000/Products/products/list/';

//   // Data for dropdowns
//   List<String> buyerBpCodes = [];
//   List<String> productCodes = [];

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
//     {'key': 'id', 'label': 'ID', 'selected': false, 'order': 0},
//     {'key': 'catalogue_name', 'label': 'Catalogue Name', 'selected': true, 'order': 1},
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 2},
//     {'key': 'product_code', 'label': 'Product Codes', 'selected': true, 'order': 3},
//     {'key': 'add_image', 'label': 'Image', 'selected': false, 'isFile': true, 'order': 4},
//     {'key': 'add_video', 'label': 'Video', 'selected': false, 'isFile': true, 'order': 5},
//   ];

//   // Filter controllers
//   final TextEditingController catalogueNameController = TextEditingController();
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController productCodeController = TextEditingController();

//   // Create controllers
//   final Map<String, TextEditingController> createControllers = {};

//   // Create dropdown values
//   String? selectedCreateBpCode;
//   List<String> selectedCreateProductCodes = [];

//   // Edit controllers
//   Map<String, TextEditingController>? editControllers;
//   int? editingCatalogueId;

//   // Edit dropdown values
//   String? selectedEditBpCode;
//   List<String> selectedEditProductCodes = [];

//   // File uploads
//   File? imageFile;
//   String? imageFileName;
//   File? videoFile;
//   String? videoFileName;

//   // Required fields for catalogue
//   final List<String> requiredFields = [
//     'catalogue_name',
//     'bp_code',
//     'product_code',
//     'add_image',
//     'add_video',
//   ];

//   // Fields to exclude from certain operations
//   final List<String> excludeFromCreate = [];
//   final List<String> excludeFromEdit = [];
//   final List<String> excludeFromDisplay = [];

//   @override
//   void initState() {
//     super.initState();
//     loadSavedFieldSelections();
//     loadListSettings();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     catalogueNameController.dispose();
//     bpCodeController.dispose();
//     productCodeController.dispose();

//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });

//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }

//     _horizontalScrollController.dispose();
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('catalogue_fields');
//     String? savedOrder = prefs.getString('catalogue_field_order');

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

//     if (savedOrder != null) {
//       try {
//         List<dynamic> savedOrderList = json.decode(savedOrder);
//         setState(() {
//           List<Map<String, dynamic>> reorderedFields = [];
//           for (String key in savedOrderList) {
//             final index = availableFields.indexWhere((f) => f['key'] == key);
//             if (index != -1) {
//               reorderedFields.add(availableFields[index]);
//             }
//           }
//           for (var field in availableFields) {
//             if (!reorderedFields.any((f) => f['key'] == field['key'])) {
//               reorderedFields.add(field);
//             }
//           }
//           availableFields = reorderedFields;

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

//     await prefs.setString('catalogue_fields', json.encode(selections));
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('catalogue_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     setState(() {
//       compactRows = prefs.getBool('catalogue_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('catalogue_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('catalogue_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('catalogue_enable_view') ?? true;
//       enableEdit = prefs.getBool('catalogue_enable_edit') ?? true;
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

//     await prefs.setBool('catalogue_compact_rows', compactRows);
//     await prefs.setBool('catalogue_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('catalogue_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('catalogue_enable_view', enableView);
//     await prefs.setBool('catalogue_enable_edit', enableEdit);
//   }

//   // Get selected fields for display in correct order
//   List<Map<String, dynamic>> getSelectedFields() {
//     return availableFields
//         .where((field) => field['selected'] == true)
//         .toList()
//       ..sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
//   }

//   // Load token and initial data
//   Future<void> loadToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedToken = prefs.getString('token');

//     setState(() {
//       token = savedToken;
//     });

//     if (token != null && token!.isNotEmpty) {
//       try {
//         await Future.wait([
//           fetchBuyerBpCodes(),
//           fetchProductCodes(),
//         ]);
//         await fetchCatalogues();
//       } catch (e) {
//         print('Error loading data: $e');
//         setState(() => isLoading = false);
//         _showSnackBar('Error loading data: $e', isError: true);
//       }
//     } else {
//       setState(() => isLoading = false);
//       print('⚠️ No token found. Please login again.');
//       _showSnackBar('No authentication token found. Please login again.', isError: true);
//     }
//   }

//   // Fetch Buyer BP Codes
//   Future<void> fetchBuyerBpCodes() async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse(buyerApiUrl),
//         headers: {'Authorization': 'Token $token'},
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         List<Map<String, dynamic>> buyerList = [];

//         if (data is Map && data.containsKey('results')) {
//           buyerList = List<Map<String, dynamic>>.from(data['results'] ?? []);
//         } else if (data is List) {
//           buyerList = List<Map<String, dynamic>>.from(data);
//         }

//         // Create a Set to ensure unique values
//         Set<String> uniqueBpCodes = {};
//         buyerList.forEach((buyer) {
//           final bpCode = buyer['bp_code']?.toString() ?? '';
//           final bpName = buyer['bp_name']?.toString() ?? '';
//           final displayValue = bpName.isNotEmpty ? '$bpCode - $bpName' : bpCode;
//           if (bpCode.isNotEmpty) {
//             uniqueBpCodes.add(displayValue);
//           }
//         });

//         setState(() {
//           buyerBpCodes = uniqueBpCodes.toList()..sort();
//         });
//       } else {
//         print('Failed to fetch buyers: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching buyers: $e');
//     }
//   }

//   // Fetch Product Codes
//   Future<void> fetchProductCodes() async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse(productApiUrl),
//         headers: {'Authorization': 'Token $token'},
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         List<Map<String, dynamic>> productList = [];

//         if (data is Map && data.containsKey('results')) {
//           productList = List<Map<String, dynamic>>.from(data['results'] ?? []);
//         } else if (data is List) {
//           productList = List<Map<String, dynamic>>.from(data);
//         }

//         Set<String> uniqueProductCodes = {};
//         productList.forEach((product) {
//           final productCode = product['product_code']?.toString() ?? '';
//           final productName = product['product_name']?.toString() ?? '';
//           final displayValue = productName.isNotEmpty ? '$productCode - $productName' : productCode;
//           if (productCode.isNotEmpty) {
//             uniqueProductCodes.add(displayValue);
//           }
//         });

//         setState(() {
//           productCodes = uniqueProductCodes.toList()..sort();
//         });
//       } else {
//         print('Failed to fetch products: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching products: $e');
//     }
//   }

//   // Helper Methods
//   int safeParseInt(dynamic value) {
//     if (value == null) return 0;
//     if (value is int) return value;
//     if (value is double) return value.toInt();
//     if (value is String) {
//       final parsed = int.tryParse(value);
//       if (parsed != null) return parsed;
//       final doubleParsed = double.tryParse(value);
//       if (doubleParsed != null) return doubleParsed.toInt();
//     }
//     return 0;
//   }

//   String formatFieldName(String field) {
//     return field.replaceAll('_', ' ').toUpperCase();
//   }

//   bool isFileField(String field) {
//     return field == 'add_image' || field == 'add_video';
//   }

//   bool isFieldDisplayable(String field) {
//     return !excludeFromDisplay.contains(field);
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> catalogue, String key) {
//     final value = catalogue[key];

//     if (value == null) return '-';

//     if (value is bool) {
//       return value.toString();
//     }

//     if (key == 'product_code' && value is List) {
//       if (value.isEmpty) return '-';
//       return value.join(', ');
//     }

//     return value.toString();
//   }

//   // API Request Building
//   String buildRequestUrl() {
//     if (filterParams.isEmpty && sortBy == null) {
//       return listApiUrl;
//     }
    
//     Map<String, String> queryParams = {};

//     filterParams.forEach((key, value) {
//       if (value.isNotEmpty) {
//         queryParams[key] = value;
//       }
//     });

//     if (sortBy != null && sortBy!.isNotEmpty) {
//       queryParams['sort_by'] = sortBy!;
//       if (sortOrder != null && sortOrder!.isNotEmpty) {
//         queryParams['sort_order'] = sortOrder!;
//       }
//     }

//     if (pageSize != 20) {
//       queryParams['page_size'] = pageSize.toString();
//     }
//     if (currentPage > 1) {
//       queryParams['page'] = currentPage.toString();
//     }

//     Uri uri = Uri.parse(listApiUrl);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Fetch Catalogues
//   Future<void> fetchCatalogues({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final requestUrl = url ?? buildRequestUrl();
//       print('Fetching: $requestUrl');

//       final response = await http.get(
//         Uri.parse(requestUrl),
//         headers: {'Authorization': 'Token $token'},
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         List<Map<String, dynamic>> results = [];
        
//         if (data is List) {
//           results = List<Map<String, dynamic>>.from(data);
//           setState(() {
//             catalogues = results;
//             nextUrl = null;
//             prevUrl = null;
//             totalCount = results.length;
//             currentPage = 1;
//             selectedIds.clear();
//             isLoading = false;
//           });
//         } else if (data is Map) {
//           if (data.containsKey('results')) {
//             results = List<Map<String, dynamic>>.from(data['results'] ?? []);
//           }
          
//           setState(() {
//             catalogues = results;
//             nextUrl = data['next'];
//             prevUrl = data['previous'];
//             totalCount = safeParseInt(data['count']);

//             if (prevUrl == null && nextUrl != null) {
//               currentPage = 1;
//             } else if (prevUrl != null) {
//               final uri = Uri.parse(prevUrl!);
//               final pageParam = uri.queryParameters['page'];
//               if (pageParam != null) {
//                 currentPage = int.parse(pageParam) + 1;
//               }
//             } else if (nextUrl != null) {
//               final uri = Uri.parse(nextUrl!);
//               final pageParam = uri.queryParameters['page'];
//               if (pageParam != null) {
//                 currentPage = int.parse(pageParam) - 1;
//               }
//             }

//             selectedIds.clear();
//             isLoading = false;
//           });
//         } else {
//           setState(() {
//             catalogues = [];
//             isLoading = false;
//           });
//         }
//       } else {
//         print('Error: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch catalogues: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Connection error: Please check if backend server is running', isError: true);
//     }
//   }

//   // Fetch Single Catalogue Details
//   Future<void> fetchCatalogueDetails(int id) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       final response = await http.get(
//         Uri.parse('$detailApiUrl$id/'),
//         headers: {'Authorization': 'Token $token'},
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           currentViewedCatalogue = data;
//           isLoading = false;
//         });
//         showCatalogueDetailDialog();
//       } else {
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch catalogue details', isError: true);
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Filter Methods
//   Future<void> applyFilters() async {
//     filterParams.clear();

//     if (catalogueNameController.text.isNotEmpty) {
//       filterParams['catalogue_name'] = catalogueNameController.text;
//     }
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (productCodeController.text.isNotEmpty) {
//       filterParams['product_code'] = productCodeController.text;
//     }

//     currentPage = 1;
//     await fetchCatalogues();
//     Navigator.pop(context);
//   }

//   Future<void> clearFilters() async {
//     filterParams.clear();

//     catalogueNameController.clear();
//     bpCodeController.clear();
//     productCodeController.clear();

//     await fetchCatalogues();
//   }

//   void showFilterDialog() {
//     catalogueNameController.text = filterParams['catalogue_name'] ?? '';
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     productCodeController.text = filterParams['product_code'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Filter Catalogues'),
//               content: Container(
//                 width: double.maxFinite,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       _buildFilterField(catalogueNameController, 'Catalogue Name', Icons.book),
//                       _buildFilterField(bpCodeController, 'BP Code', Icons.qr_code),
//                       _buildFilterField(productCodeController, 'Product Code', Icons.code),
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

//   Widget _buildFilterField(TextEditingController controller, String label, IconData icon) {
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
//     await fetchCatalogues();
//   }

//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchCatalogues();
//   }

//   void toggleSortOrder() {
//     if (sortBy == null) return;
//     String newOrder = sortOrder == 'asc' ? 'desc' : 'asc';
//     applySort(sortBy!, newOrder);
//   }

//   void showSortDialog() {
//     List<Map<String, String>> sortFields = [
//       {'value': 'catalogue_name', 'label': 'Catalogue Name'},
//       {'value': 'bp_code', 'label': 'BP Code'},
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
//                             border: Border.all(color: Colors.grey.shade300),
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
//                       fetchCatalogues();
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
//       fetchCatalogues(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchCatalogues(url: prevUrl);
//     }
//   }

//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
//     await fetchCatalogues();
//   }

//   // Create Catalogue Methods
//   void showAddCatalogueDialog() {
//     for (var field in requiredFields) {
//       if (!excludeFromCreate.contains(field) &&
//           !isFileField(field) &&
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }

//     // Reset selections
//     imageFile = null;
//     imageFileName = null;
//     videoFile = null;
//     videoFileName = null;
//     selectedCreateBpCode = null;
//     selectedCreateProductCodes = [];

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Catalogue'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildCreateTextField('catalogue_name', 'Catalogue Name', Icons.book, isRequired: true),
                    
//                     // BP Code dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: buyerBpCodes,
//                       onChanged: (value) => setState(() => selectedCreateBpCode = value),
//                     ),

//                     // Product Codes multi-select
//                     _buildCreateMultiSelectField(
//                       selectedValues: selectedCreateProductCodes,
//                       label: 'Product Codes',
//                       icon: Icons.code,
//                       items: productCodes,
//                       onChanged: (values) => setState(() => selectedCreateProductCodes = values),
//                     ),

//                     // Image file field
//                     _buildCreateFileField(
//                       field: 'add_image',
//                       label: 'Image',
//                       icon: Icons.image,
//                       file: imageFile,
//                       fileName: imageFileName,
//                       onPickFile: () => pickImage(setState),
//                       onClearFile: () {
//                         setState(() {
//                           imageFile = null;
//                           imageFileName = null;
//                         });
//                       },
//                     ),

//                     // Video file field
//                     _buildCreateFileField(
//                       field: 'add_video',
//                       label: 'Video',
//                       icon: Icons.video_library,
//                       file: videoFile,
//                       fileName: videoFileName,
//                       onPickFile: () => pickVideo(setState),
//                       onClearFile: () {
//                         setState(() {
//                           videoFile = null;
//                           videoFileName = null;
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   if (createControllers['catalogue_name']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter catalogue name', isError: true);
//                     return;
//                   }
//                   await createCatalogue();
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
//       {bool isRequired = false, int maxLines = 1}) {
//     if (!createControllers.containsKey(field)) {
//       createControllers[field] = TextEditingController();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: createControllers[field],
//         maxLines: maxLines,
//         decoration: InputDecoration(
//           labelText: isRequired ? '$label *' : label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//       ),
//     );
//   }

//   Widget _buildCreateDropdownField({
//     required String? value,
//     required String label,
//     required IconData icon,
//     required List<String> items,
//     required Function(String?) onChanged,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: DropdownButtonFormField<String>(
//         value: value,
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//         items: items.map((item) {
//           return DropdownMenuItem<String>(
//             value: item,
//             child: Text(item),
//           );
//         }).toList(),
//         onChanged: items.isEmpty ? null : onChanged,
//       ),
//     );
//   }

//   Widget _buildCreateMultiSelectField({
//     required List<String> selectedValues,
//     required String label,
//     required IconData icon,
//     required List<String> items,
//     required Function(List<String>) onChanged,
//   }) {
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
//           Container(
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey.shade400),
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Column(
//               children: [
//                 // Selected chips
//                 if (selectedValues.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Wrap(
//                       spacing: 4,
//                       runSpacing: 4,
//                       children: selectedValues.map((value) {
//                         return Chip(
//                           label: Text(value),
//                           onDeleted: () {
//                             List<String> newValues = List.from(selectedValues);
//                             newValues.remove(value);
//                             onChanged(newValues);
//                           },
//                         );
//                       }).toList(),
//                     ),
//                   ),
                
//                 // Dropdown to add new items
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8),
//                   decoration: BoxDecoration(
//                     border: Border(top: BorderSide(color: Colors.grey.shade300)),
//                   ),
//                   child: DropdownButton<String>(
//                     isExpanded: true,
//                     hint: Text('Select product code to add'),
//                     value: null,
//                     items: items
//                         .where((item) => !selectedValues.contains(item))
//                         .map((item) {
//                       return DropdownMenuItem<String>(
//                         value: item,
//                         child: Text(item),
//                       );
//                     }).toList(),
//                     onChanged: (value) {
//                       if (value != null) {
//                         List<String> newValues = List.from(selectedValues);
//                         newValues.add(value);
//                         onChanged(newValues);
//                       }
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildCreateFileField({
//     required String field,
//     required String label,
//     required IconData icon,
//     required File? file,
//     required String? fileName,
//     required VoidCallback onPickFile,
//     required VoidCallback onClearFile,
//   }) {
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
//                   onPressed: onPickFile,
//                   icon: Icon(icon),
//                   label: Text(
//                     fileName ?? 'Select $label',
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               if (fileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: onClearFile,
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> pickImage(StateSetter setState) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);

//     if (file != null) {
//       setState(() {
//         imageFile = File(file.path);
//         imageFileName = path.basename(file.path);
//       });
//     }
//   }

//   Future<void> pickVideo(StateSetter setState) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickVideo(source: ImageSource.gallery);

//     if (file != null) {
//       setState(() {
//         videoFile = File(file.path);
//         videoFileName = path.basename(file.path);
//       });
//     }
//   }

//   Future<void> createCatalogue() async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     try {
//       var request = http.MultipartRequest('POST', Uri.parse(createApiUrl));
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && !isFileField(key)) {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add BP code
//       if (selectedCreateBpCode != null) {
//         final bpValue = selectedCreateBpCode!.split('-').first.trim();
//         request.fields['bp_code'] = bpValue;
//       }

//       // Add product codes as JSON array
//       if (selectedCreateProductCodes.isNotEmpty) {
//         List<String> productCodeValues = selectedCreateProductCodes
//             .map((code) => code.split('-').first.trim())
//             .toList();
//         request.fields['product_code'] = json.encode(productCodeValues);
//       }

//       // Add image if selected
//       if (imageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'add_image',
//             imageFile!.path,
//             filename: imageFileName,
//           ),
//         );
//       }

//       // Add video if selected
//       if (videoFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'add_video',
//             videoFile!.path,
//             filename: videoFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });

//         imageFile = null;
//         imageFileName = null;
//         videoFile = null;
//         videoFileName = null;
//         selectedCreateBpCode = null;
//         selectedCreateProductCodes.clear();

//         await fetchCatalogues();
//         _showSnackBar('Catalogue created successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to create catalogue: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // Edit Catalogue Methods
//   void showEditCatalogueDialog(Map<String, dynamic> catalogue) {
//     editingCatalogueId = catalogue['id'];
//     editControllers = {};

//     for (var field in requiredFields) {
//       if (!excludeFromEdit.contains(field) && !isFileField(field)) {
//         editControllers![field] = TextEditingController(
//           text: catalogue[field]?.toString() ?? '',
//         );
//       }
//     }

//     // Set dropdown values for edit
//     selectedEditBpCode = catalogue['bp_code'];
    
//     // Handle product codes
//     if (catalogue['product_code'] != null && catalogue['product_code'] is List) {
//       selectedEditProductCodes = List<String>.from(catalogue['product_code']);
//     } else {
//       selectedEditProductCodes = [];
//     }

//     // Reset file selections
//     imageFile = null;
//     imageFileName = null;
//     videoFile = null;
//     videoFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Edit Catalogue'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildEditTextField('catalogue_name', 'Catalogue Name', Icons.book),

//                     // BP Code dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: buyerBpCodes,
//                       onChanged: (value) => setState(() => selectedEditBpCode = value),
//                     ),

//                     // Product Codes multi-select
//                     _buildEditMultiSelectField(
//                       selectedValues: selectedEditProductCodes,
//                       label: 'Product Codes',
//                       icon: Icons.code,
//                       items: productCodes,
//                       onChanged: (values) => setState(() => selectedEditProductCodes = values),
//                     ),

//                     // Image file field
//                     _buildEditFileField(
//                       field: 'add_image',
//                       label: 'Image',
//                       icon: Icons.image,
//                       file: imageFile,
//                       fileName: imageFileName,
//                       existingUrl: catalogue['add_image'],
//                       onPickFile: () => pickImage(setState),
//                       onClearFile: () {
//                         setState(() {
//                           imageFile = null;
//                           imageFileName = null;
//                         });
//                       },
//                     ),

//                     // Video file field
//                     _buildEditFileField(
//                       field: 'add_video',
//                       label: 'Video',
//                       icon: Icons.video_library,
//                       file: videoFile,
//                       fileName: videoFileName,
//                       existingUrl: catalogue['add_video'],
//                       onPickFile: () => pickVideo(setState),
//                       onClearFile: () {
//                         setState(() {
//                           videoFile = null;
//                           videoFileName = null;
//                         });
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await updateCatalogue(editingCatalogueId!);
//                   Navigator.pop(context);
//                 },
//                 child: Text('Save'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   editControllers = null;
//                   editingCatalogueId = null;
//                   imageFile = null;
//                   imageFileName = null;
//                   videoFile = null;
//                   videoFileName = null;
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

//   Widget _buildEditTextField(String field, String label, IconData icon,
//       {int maxLines = 1}) {
//     if (editControllers == null || !editControllers!.containsKey(field)) {
//       return SizedBox.shrink();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: editControllers![field],
//         maxLines: maxLines,
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//       ),
//     );
//   }

//   Widget _buildEditDropdownField({
//     required String? value,
//     required String label,
//     required IconData icon,
//     required List<String> items,
//     required Function(String?) onChanged,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: DropdownButtonFormField<String>(
//         value: value,
//         decoration: InputDecoration(
//           labelText: label,
//           border: OutlineInputBorder(),
//           prefixIcon: Icon(icon),
//         ),
//         items: items.map((item) {
//           return DropdownMenuItem<String>(
//             value: item,
//             child: Text(item),
//           );
//         }).toList(),
//         onChanged: items.isEmpty ? null : onChanged,
//       ),
//     );
//   }

//   Widget _buildEditMultiSelectField({
//     required List<String> selectedValues,
//     required String label,
//     required IconData icon,
//     required List<String> items,
//     required Function(List<String>) onChanged,
//   }) {
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
//           Container(
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey.shade400),
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Column(
//               children: [
//                 // Selected chips
//                 if (selectedValues.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Wrap(
//                       spacing: 4,
//                       runSpacing: 4,
//                       children: selectedValues.map((value) {
//                         return Chip(
//                           label: Text(value),
//                           onDeleted: () {
//                             List<String> newValues = List.from(selectedValues);
//                             newValues.remove(value);
//                             onChanged(newValues);
//                           },
//                         );
//                       }).toList(),
//                     ),
//                   ),
                
//                 // Dropdown to add new items
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8),
//                   decoration: BoxDecoration(
//                     border: Border(top: BorderSide(color: Colors.grey.shade300)),
//                   ),
//                   child: DropdownButton<String>(
//                     isExpanded: true,
//                     hint: Text('Select product code to add'),
//                     value: null,
//                     items: items
//                         .where((item) => !selectedValues.contains(item))
//                         .map((item) {
//                       return DropdownMenuItem<String>(
//                         value: item,
//                         child: Text(item),
//                       );
//                     }).toList(),
//                     onChanged: (value) {
//                       if (value != null) {
//                         List<String> newValues = List.from(selectedValues);
//                         newValues.add(value);
//                         onChanged(newValues);
//                       }
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEditFileField({
//     required String field,
//     required String label,
//     required IconData icon,
//     required File? file,
//     required String? fileName,
//     required dynamic existingUrl,
//     required VoidCallback onPickFile,
//     required VoidCallback onClearFile,
//   }) {
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
          
//           // Show existing file if available
//           if (existingUrl != null && existingUrl.toString().isNotEmpty && fileName == null)
//             Padding(
//               padding: const EdgeInsets.only(bottom: 8),
//               child: InkWell(
//                 onTap: () => _showFileDialog(label, existingUrl.toString()),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         field == 'add_image' ? Icons.image : Icons.video_library,
//                         size: 16,
//                         color: Colors.blue,
//                       ),
//                       SizedBox(width: 4),
//                       Text(
//                         'View Existing $label',
//                         style: TextStyle(
//                           color: Colors.blue,
//                           fontWeight: FontWeight.w500,
//                           fontSize: 12,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
          
//           // File picker
//           Row(
//             children: [
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: onPickFile,
//                   icon: Icon(icon),
//                   label: Text(
//                     fileName ?? 'Select New $label',
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               if (fileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: onClearFile,
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> updateCatalogue(int id) async {
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

//       // Add BP code
//       if (selectedEditBpCode != null) {
//         final bpValue = selectedEditBpCode!.split('-').first.trim();
//         request.fields['bp_code'] = bpValue;
//       }

//       // Add product codes as JSON array
//       if (selectedEditProductCodes.isNotEmpty) {
//         List<String> productCodeValues = selectedEditProductCodes
//             .map((code) => code.split('-').first.trim())
//             .toList();
//         request.fields['product_code'] = json.encode(productCodeValues);
//       }

//       // Add image if selected
//       if (imageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'add_image',
//             imageFile!.path,
//             filename: imageFileName,
//           ),
//         );
//       }

//       // Add video if selected
//       if (videoFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'add_video',
//             videoFile!.path,
//             filename: videoFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         editControllers = null;
//         editingCatalogueId = null;
//         imageFile = null;
//         imageFileName = null;
//         videoFile = null;
//         videoFileName = null;
//         selectedEditBpCode = null;
//         selectedEditProductCodes.clear();

//         await fetchCatalogues();
//         _showSnackBar('Catalogue updated successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to update catalogue: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // View Catalogue Details
//   void showCatalogueDetailDialog() {
//     if (currentViewedCatalogue == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Catalogue Details'),
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
//     dynamic value = currentViewedCatalogue?[field];

//     String displayValue = '-';
//     if (field == 'product_code' && value is List) {
//       displayValue = value.isNotEmpty ? value.join(', ') : '-';
//     } else {
//       displayValue = value?.toString() ?? '-';
//     }

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
//             child: _buildDetailValue(field, displayValue),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailValue(String field, String displayValue) {
//     if (isFileField(field)) {
//       if (displayValue != '-' && displayValue.isNotEmpty) {
//         return InkWell(
//           onTap: () => _showFileDialog(formatFieldName(field), displayValue),
//           child: Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade50,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Text(
//               'View ${field == 'add_image' ? 'Image' : 'Video'}',
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

//     return Text(displayValue);
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
//             if (title.toLowerCase().contains('image'))
//               fileUrl.startsWith('http')
//                   ? Image.network(
//                       fileUrl,
//                       height: 200,
//                       width: 200,
//                       fit: BoxFit.cover,
//                       errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 100),
//                     )
//                   : Icon(Icons.image, size: 100)
//             else
//               Container(
//                 height: 100,
//                 child: Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.video_library, size: 50, color: Colors.blue),
//                       SizedBox(height: 8),
//                       Text('Video file'),
//                     ],
//                   ),
//                 ),
//               ),
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
//         ],
//       ),
//     );
//   }

//   // Show Field Selection Dialog
//   void showFieldSelectionDialog() {
//     fieldSearchQuery = '';

//     bool localCompactRows = compactRows;
//     bool localActiveRowHighlighting = activeRowHighlighting;
//     bool localModernCellColoring = modernCellColoring;
//     bool localEnableView = enableView;
//     bool localEnableEdit = enableEdit;

//     int selectedFieldIndex = -1;

//     List<Map<String, dynamic>> availableFieldsList = [];
//     List<Map<String, dynamic>> selectedFieldsList = [];

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
//                             'Personalize List Columns - Catalogues',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

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

//                     Expanded(
//                       child: Row(
//                         children: [
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
//                                         ? Center(child: Text('No fields found'))
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
//                                                 subtitle: field['isFile'] == true
//                                                     ? Text('File field',
//                                                         style: TextStyle(fontSize: 11, color: Colors.grey))
//                                                     : null,
//                                                 trailing: Icon(
//                                                   Icons.add_circle_outline,
//                                                   color: Colors.blue,
//                                                   size: 22,
//                                                 ),
//                                                 onTap: () {
//                                                   setState(() {
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

//                           Container(
//                             width: 60,
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Container(
//                                   margin: EdgeInsets.only(bottom: 16),
//                                   child: IconButton(
//                                     icon: Icon(Icons.arrow_forward, size: 30),
//                                     color: Colors.blue,
//                                     onPressed: () {
//                                       setState(() {
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
//                                 Container(
//                                   margin: EdgeInsets.only(top: 16),
//                                   child: IconButton(
//                                     icon: Icon(Icons.arrow_back, size: 30),
//                                     color: Colors.orange,
//                                     onPressed: () {
//                                       setState(() {
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
//                                       ? Center(child: Text('No fields selected'))
//                                       : ListView.builder(
//                                           itemCount: selectedFieldsList.length,
//                                           itemBuilder: (context, index) {
//                                             final field = selectedFieldsList[index];
//                                             return Container(
//                                               color: selectedFieldIndex == index ? Colors.blue.shade50 : null,
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
//                                                     fontWeight: selectedFieldIndex == index ? FontWeight.bold : FontWeight.w500,
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
//                                 availableFieldsList.clear();
//                                 selectedFieldsList.clear();

//                                 List<Map<String, dynamic>> defaultFields = [
//                                   {'key': 'catalogue_name', 'label': 'Catalogue Name', 'selected': true},
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'product_code', 'label': 'Product Codes', 'selected': true},
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
//                                 'Catalogues - Field Selection',
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
//                               this.setState(() {
//                                 for (var field in availableFields) {
//                                   field['selected'] = false;
//                                 }

//                                 for (int i = 0; i < selectedFieldsList.length; i++) {
//                                   final selectedField = selectedFieldsList[i];
//                                   final index = availableFields.indexWhere(
//                                     (f) => f['key'] == selectedField['key'],
//                                   );
//                                   if (index != -1) {
//                                     availableFields[index]['selected'] = true;
//                                     availableFields[index]['order'] = i;
//                                   }
//                                 }

//                                 int nextOrder = selectedFieldsList.length;
//                                 for (var field in availableFields) {
//                                   if (field['selected'] != true) {
//                                     field['order'] = nextOrder;
//                                     nextOrder++;
//                                   }
//                                 }

//                                 availableFields.sort((a, b) => (a['order'] ?? 0).compareTo(b['order'] ?? 0));
//                               });

//                               await saveFieldSelections();

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

//   void applyListSettings({
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableView,
//     required bool enableEdit,
//   }) {
//     saveListSettings(
//       compactRows: compactRows,
//       activeRowHighlighting: activeRowHighlighting,
//       modernCellColoring: modernCellColoring,
//       enableView: enableView,
//       enableEdit: enableEdit,
//     );

//     setState(() {
//       this.compactRows = compactRows;
//       this.activeRowHighlighting = activeRowHighlighting;
//       this.modernCellColoring = modernCellColoring;
//       this.enableView = enableView;
//       this.enableEdit = enableEdit;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('List settings applied'),
//         duration: Duration(seconds: 2),
//       ),
//     );
//   }

//   void _showSnackBar(String message, {bool isError = false}) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: isError ? Colors.red : Colors.green,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

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
//                     sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
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
//     if (catalogues.isEmpty) {
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

//     return catalogues.map((catalogue) {
//       final id = catalogue['id'];
//       final isSelected = selectedIds.contains(id);

//       List<DataCell> cells = [
//         DataCell(
//           Checkbox(
//             value: isSelected,
//             onChanged: (v) {
//               setState(() {
//                 if (v == true) {
//                   selectedIds.clear();
//                   selectedIds.add(id);
//                 } else {
//                   selectedIds.remove(id);
//                 }
//               });
//             },
//           ),
//         ),

//         DataCell(
//           isSelected
//               ? Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     if (enableView)
//                       ElevatedButton(
//                         onPressed: () => fetchCatalogueDetails(id),
//                         child: Text(
//                           'View',
//                           style: TextStyle(fontSize: compactRows ? 11 : 13),
//                         ),
//                         style: ElevatedButton.styleFrom(
//                           minimumSize: Size(60, 30),
//                           padding: EdgeInsets.symmetric(horizontal: 8),
//                         ),
//                       ),
                    
//                     if (enableEdit) ...[
//                       if (enableView) SizedBox(width: 4),
//                       ElevatedButton(
//                         onPressed: () => showEditCatalogueDialog(catalogue),
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

//       for (var field in selectedFields) {
//         String displayValue = getFieldValue(catalogue, field['key']);

//         if (field['isFile'] == true && displayValue != '-') {
//           cells.add(
//             DataCell(
//               InkWell(
//                 onTap: () => _showFileDialog(field['label'], catalogue[field['key']]?.toString() ?? ''),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: modernCellColoring ? Colors.purple.shade50 : Colors.blue.shade50,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         field['key'] == 'add_image' ? Icons.image : Icons.video_library,
//                         size: compactRows ? 10 : 12,
//                         color: modernCellColoring ? Colors.purple : Colors.blue,
//                       ),
//                       SizedBox(width: 2),
//                       Text(
//                         'View',
//                         style: TextStyle(
//                           fontSize: compactRows ? 10 : 12,
//                           color: modernCellColoring ? Colors.purple : Colors.blue,
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
//                     color: modernCellColoring && isSelected ? Colors.blue : null,
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
//         title: Text('Catalogues'),
//         actions: [
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
//             onPressed: () => fetchCatalogues(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddCatalogueDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add Catalogue'),
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
//                         label: Text('Change', style: TextStyle(fontSize: 12)),
//                         style: TextButton.styleFrom(
//                           padding: EdgeInsets.zero,
//                           minimumSize: Size(0, 0),
//                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 if (filterParams.isNotEmpty)
//                   Container(
//                     padding: EdgeInsets.all(8),
//                     color: Colors.blue.shade50,
//                     child: Row(
//                       children: [
//                         Icon(Icons.filter_alt, size: 16, color: Colors.blue),
//                         SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             'Filters: ${filterParams.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
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
//                             sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
//                           ),
//                           onPressed: toggleSortOrder,
//                           padding: EdgeInsets.zero,
//                           constraints: BoxConstraints(),
//                         ),
//                       ],
//                     ),
//                   ),

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
//                         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
//                             onPressed: (prevUrl == null || prevUrl!.isEmpty) ? null : loadPrevPage,
//                             child: Text(
//                               'Previous',
//                               style: TextStyle(fontSize: compactRows ? 11 : 13),
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: (prevUrl == null || prevUrl!.isEmpty) ? Colors.grey : null,
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: compactRows ? 8 : 16,
//                                 vertical: compactRows ? 4 : 8,
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: compactRows ? 8 : 12),
//                           ElevatedButton(
//                             onPressed: (nextUrl == null || nextUrl!.isEmpty) ? null : loadNextPage,
//                             child: Text(
//                               'Next',
//                               style: TextStyle(fontSize: compactRows ? 11 : 13),
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: (nextUrl == null || nextUrl!.isEmpty) ? Colors.grey : null,
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