import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DesignPage extends StatefulWidget {
  @override
  _DesignPageState createState() => _DesignPageState();
}

class _DesignPageState extends State<DesignPage> {
  // Data lists
  List<Map<String, dynamic>> designs = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  Map<String, dynamic>? currentViewedDesign;

  // API Endpoints
  final String listApiUrl = 'http://127.0.0.1:8000/Designs/Designs/productslist/';
  
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

  // Group By / Display Fields variables
  List<Map<String, dynamic>> availableFields = [
    {'key': 'id', 'label': 'ID', 'selected': false, 'order': 0},
    {'key': 'product_code', 'label': 'Product Code', 'selected': true, 'order': 1},
    {'key': 'product_name', 'label': 'Product Name', 'selected': true, 'order': 2},
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 3},
    {'key': 'product_category', 'label': 'Category', 'selected': true, 'order': 4},
    {'key': 'sub_category', 'label': 'Sub Category', 'selected': true, 'order': 5},
    {'key': 'type', 'label': 'Type', 'selected': true, 'order': 6},
    {'key': 'order_type', 'label': 'Order Type', 'selected': true, 'order': 7},
    {'key': 'open_close', 'label': 'Open/Close', 'selected': true, 'order': 8},
    {'key': 'hallmark', 'label': 'Hallmark', 'selected': true, 'order': 9},
    {'key': 'rodium', 'label': 'Rodium', 'selected': true, 'order': 10},
    {'key': 'hook', 'label': 'Hook', 'selected': true, 'order': 11},
    {'key': 'size', 'label': 'Size', 'selected': true, 'order': 12},
    {'key': 'stone', 'label': 'Stone', 'selected': true, 'order': 13},
    {'key': 'enamel', 'label': 'Enamel', 'selected': false, 'order': 14},
    {'key': 'length', 'label': 'Length', 'selected': true, 'order': 15},
    {'key': 'status', 'label': 'Status', 'selected': true, 'order': 16},
    {'key': 'product_image', 'label': 'Product Image', 'selected': false, 'isFile': true, 'order': 17},
  ];

  // Filter controllers
  final TextEditingController productCodeController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController bpCodeController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController subCategoryController = TextEditingController();

  // Options for filtering based on available values
  final List<String> typeOptions = ['Piece', 'Pair'];
  final List<String> orderTypeOptions = ['Regular', 'Urgent', 'Super Urgent'];
  final List<String> openCloseOptions = ['open', 'close', 'solid', 'pokal'];
  final List<String> hallmarkOptions = ['Yes', 'No'];
  final List<String> rodiumOptions = ['Yes', 'No'];
  final List<String> hookOptions = ['Yes', 'No'];
  final List<String> stoneOptions = ['Yes', 'No'];
  final List<String> sizeOptions = ['Large', 'Medium', 'Small'];
  final List<String> statusOptions = ['Accept', 'Pending', 'Reject', 'Draft'];

  // Fields to exclude from display
  final List<String> excludeFromDisplay = [];

  @override
  void initState() {
    super.initState();
    loadSavedFieldSelections();
    loadListSettings();
    loadToken();
  }

  @override
  void dispose() {
    productCodeController.dispose();
    productNameController.dispose();
    bpCodeController.dispose();
    statusController.dispose();
    categoryController.dispose();
    subCategoryController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // Load saved field selections from SharedPreferences
  Future<void> loadSavedFieldSelections() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedSelections = prefs.getString('design_fields');
    String? savedOrder = prefs.getString('design_field_order');

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

    await prefs.setString('design_fields', json.encode(selections));
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('design_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      compactRows = prefs.getBool('design_compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('design_active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('design_modern_cell_coloring') ?? false;
      enableView = prefs.getBool('design_enable_view') ?? true;
    });
  }

  // Save list settings to SharedPreferences
  Future<void> saveListSettings({
    required bool compactRows,
    required bool activeRowHighlighting,
    required bool modernCellColoring,
    required bool enableView,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setBool('design_compact_rows', compactRows);
    await prefs.setBool('design_active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('design_modern_cell_coloring', modernCellColoring);
    await prefs.setBool('design_enable_view', enableView);
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
        await fetchDesigns();
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
    return field == 'product_image';
  }

  bool isFieldDisplayable(String field) {
    return !excludeFromDisplay.contains(field);
  }

  // Get field value with proper formatting
  String getFieldValue(Map<String, dynamic> design, String key) {
    final value = design[key];

    if (value == null) return '-';

    if (value is bool) {
      return value.toString();
    }

    return value.toString();
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

  // Fetch Designs
  Future<void> fetchDesigns({String? url}) async {
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
        final Map<String, dynamic>? data = json.decode(response.body);
        
        List<Map<String, dynamic>> results = [];
        
        if (data != null) {
          // Check for different possible response structures
          if (data.containsKey('results')) {
            final resultsData = data['results'];
            if (resultsData is List) {
              results = List<Map<String, dynamic>>.from(resultsData);
            } else if (resultsData is Map && resultsData.containsKey('products')) {
              final products = resultsData['products'];
              if (products is List) {
                results = List<Map<String, dynamic>>.from(products);
              }
            } else if (resultsData is Map) {
              // If results is a map, try to get data from it
              final dataList = resultsData['data'] ?? resultsData['items'] ?? [];
              if (dataList is List) {
                results = List<Map<String, dynamic>>.from(dataList);
              }
            }
          } else if (data.containsKey('data')) {
            final dataList = data['data'];
            if (dataList is List) {
              results = List<Map<String, dynamic>>.from(dataList);
            }
          } else if (data.containsKey('items')) {
            final dataList = data['items'];
            if (dataList is List) {
              results = List<Map<String, dynamic>>.from(dataList);
            }
          } else if (data.containsKey('products')) {
            final dataList = data['products'];
            if (dataList is List) {
              results = List<Map<String, dynamic>>.from(dataList);
            }
          } else {
            // Try to parse as direct list by checking if all values are maps
            final values = data.values.toList();
            if (values.isNotEmpty && values.every((v) => v is Map)) {
              results = List<Map<String, dynamic>>.from(values);
            }
          }
          
          setState(() {
            designs = results;
            nextUrl = data['next']?.toString();
            prevUrl = data['previous']?.toString();
            totalCount = safeParseInt(data['count'] ?? results.length);

            if (prevUrl == null && nextUrl != null) {
              currentPage = 1;
            } else if (prevUrl != null) {
              try {
                final uri = Uri.parse(prevUrl!);
                final pageParam = uri.queryParameters['page'];
                if (pageParam != null) {
                  currentPage = int.parse(pageParam) + 1;
                }
              } catch (e) {
                print('Error parsing prevUrl: $e');
              }
            } else if (nextUrl != null) {
              try {
                final uri = Uri.parse(nextUrl!);
                final pageParam = uri.queryParameters['page'];
                if (pageParam != null) {
                  currentPage = int.parse(pageParam) - 1;
                }
              } catch (e) {
                print('Error parsing nextUrl: $e');
              }
            }

            selectedIds.clear();
            isLoading = false;
          });
        } else {
          setState(() {
            designs = [];
            isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() => isLoading = false);
        _showSnackBar('Session expired. Please login again.', isError: true);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch designs: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
      _showSnackBar('Connection error: Please check if backend server is running', isError: true);
    }
  }

  // View Design Details
  void viewDesignDetails(Map<String, dynamic> design) {
    setState(() {
      currentViewedDesign = design;
    });
    showDesignDetailDialog();
  }

  // Filter Methods
  Future<void> applyFilters() async {
    filterParams.clear();

    if (productCodeController.text.isNotEmpty) {
      filterParams['product_code'] = productCodeController.text;
    }
    if (productNameController.text.isNotEmpty) {
      filterParams['product_name'] = productNameController.text;
    }
    if (bpCodeController.text.isNotEmpty) {
      filterParams['bp_code'] = bpCodeController.text;
    }
    if (statusController.text.isNotEmpty) {
      filterParams['status'] = statusController.text;
    }
    if (categoryController.text.isNotEmpty) {
      filterParams['product_category'] = categoryController.text;
    }
    if (subCategoryController.text.isNotEmpty) {
      filterParams['sub_category'] = subCategoryController.text;
    }

    currentPage = 1;
    await fetchDesigns();
    Navigator.pop(context);
  }

  Future<void> clearFilters() async {
    filterParams.clear();

    productCodeController.clear();
    productNameController.clear();
    bpCodeController.clear();
    statusController.clear();
    categoryController.clear();
    subCategoryController.clear();

    await fetchDesigns();
  }

  void showFilterDialog() {
    productCodeController.text = filterParams['product_code'] ?? '';
    productNameController.text = filterParams['product_name'] ?? '';
    bpCodeController.text = filterParams['bp_code'] ?? '';
    statusController.text = filterParams['status'] ?? '';
    categoryController.text = filterParams['product_category'] ?? '';
    subCategoryController.text = filterParams['sub_category'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Designs'),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterField(productCodeController, 'Product Code', Icons.code),
                      _buildFilterField(productNameController, 'Product Name', Icons.shopping_bag),
                      _buildFilterField(bpCodeController, 'BP Code', Icons.qr_code),
                      _buildFilterField(categoryController, 'Category', Icons.category),
                      _buildFilterField(subCategoryController, 'Sub Category', Icons.category_outlined),
                      _buildFilterField(statusController, 'Status', Icons.info),
                      
                      // Additional filter options can be added as dropdowns if needed
                      SizedBox(height: 16),
                      Text(
                        'Note: Additional filters like Type, Size, etc. can be added based on requirements',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
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
    await fetchDesigns();
  }

  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchDesigns();
  }

  void toggleSortOrder() {
    if (sortBy == null) return;
    String newOrder = sortOrder == 'asc' ? 'desc' : 'asc';
    applySort(sortBy!, newOrder);
  }

  void showSortDialog() {
    List<Map<String, String>> sortFields = [
      {'value': 'product_code', 'label': 'Product Code'},
      {'value': 'product_name', 'label': 'Product Name'},
      {'value': 'bp_code', 'label': 'BP Code'},
      {'value': 'product_category', 'label': 'Category'},
      {'value': 'sub_category', 'label': 'Sub Category'},
      {'value': 'type', 'label': 'Type'},
      {'value': 'order_type', 'label': 'Order Type'},
      {'value': 'status', 'label': 'Status'},
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
                      fetchDesigns();
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
      fetchDesigns(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchDesigns(url: prevUrl);
    }
  }

  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    await fetchDesigns();
  }

  // Show Design Detail Dialog
  void showDesignDetailDialog() {
    if (currentViewedDesign == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Design Details'),
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
                // Product Image
                if (currentViewedDesign!['product_image'] != null && 
                    currentViewedDesign!['product_image'].toString().isNotEmpty)
                  Center(
                    child: InkWell(
                      onTap: () => _showImageDialog(
                        'Product Image', 
                        currentViewedDesign!['product_image'].toString()
                      ),
                      child: Container(
                        height: 150,
                        width: 150,
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            currentViewedDesign!['product_image'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 50, color: Colors.grey),
                                Text('Image not available', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // All fields
                ...currentViewedDesign!.keys
                    .where((field) => isFieldDisplayable(field) && field != 'product_image')
                    .map((field) => _buildDetailField(field))
                    .toList(),
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

  Widget _buildDetailField(String field) {
    dynamic value = currentViewedDesign?[field];

    String displayValue = value?.toString() ?? '-';

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
          onTap: () => _showImageDialog(formatFieldName(field), displayValue),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'View Image',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
      return Text('No image');
    }

    return Text(displayValue);
  }

  // Image Dialog
  void _showImageDialog(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            imageUrl.startsWith('http')
                ? Image.network(
                    imageUrl,
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
                    errorBuilder: (_, __, ___) => Column(
                      children: [
                        Icon(Icons.broken_image, size: 100, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Failed to load image', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  )
                : Icon(Icons.image, size: 100),
            SizedBox(height: 16),
            Text('Image URL:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                imageUrl,
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
                            'Personalize List Columns - Designs',
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
                      child: Row(
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
                          Text('Enable View'),
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
                                  {'key': 'product_code', 'label': 'Product Code', 'selected': true},
                                  {'key': 'product_name', 'label': 'Product Name', 'selected': true},
                                  {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
                                  {'key': 'product_category', 'label': 'Category', 'selected': true},
                                  {'key': 'sub_category', 'label': 'Sub Category', 'selected': true},
                                  {'key': 'type', 'label': 'Type', 'selected': true},
                                  {'key': 'status', 'label': 'Status', 'selected': true},
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
                                'Designs - Field Selection',
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
  }) {
    saveListSettings(
      compactRows: compactRows,
      activeRowHighlighting: activeRowHighlighting,
      modernCellColoring: modernCellColoring,
      enableView: enableView,
    );

    setState(() {
      this.compactRows = compactRows;
      this.activeRowHighlighting = activeRowHighlighting;
      this.modernCellColoring = modernCellColoring;
      this.enableView = enableView;
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
    if (designs.isEmpty) {
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

    return designs.map((design) {
      final id = design['id'];
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
              ? (enableView
                  ? ElevatedButton(
                      onPressed: () => viewDesignDetails(design),
                      child: Text(
                        'View',
                        style: TextStyle(fontSize: compactRows ? 11 : 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(60, 30),
                        padding: EdgeInsets.symmetric(horizontal: 8),
                      ),
                    )
                  : SizedBox.shrink())
              : SizedBox.shrink(),
        ),
      ];

      for (var field in selectedFields) {
        String displayValue = getFieldValue(design, field['key']);

        if (field['isFile'] == true && displayValue != '-') {
          cells.add(
            DataCell(
              InkWell(
                onTap: () => _showImageDialog(field['label'], design[field['key']]?.toString() ?? ''),
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
                        Icons.image,
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
        title: Text('Designs'),
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
            onPressed: () => fetchDesigns(),
            tooltip: 'Refresh',
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

// class DesignPage extends StatefulWidget {
//   @override
//   _DesignPageState createState() => _DesignPageState();
// }

// class _DesignPageState extends State<DesignPage> {
//   // Data lists
//   List<Map<String, dynamic>> designs = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   Map<String, dynamic>? currentViewedDesign;

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/Designs/Designs/productslist/';
  
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

//   // Group By / Display Fields variables
//   List<Map<String, dynamic>> availableFields = [
//     {'key': 'id', 'label': 'ID', 'selected': false, 'order': 0},
//     {'key': 'product_code', 'label': 'Product Code', 'selected': true, 'order': 1},
//     {'key': 'product_name', 'label': 'Product Name', 'selected': true, 'order': 2},
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 3},
//     {'key': 'product_category', 'label': 'Category', 'selected': true, 'order': 4},
//     {'key': 'sub_category', 'label': 'Sub Category', 'selected': true, 'order': 5},
//     {'key': 'type', 'label': 'Type', 'selected': true, 'order': 6},
//     {'key': 'order_type', 'label': 'Order Type', 'selected': true, 'order': 7},
//     {'key': 'open_close', 'label': 'Open/Close', 'selected': true, 'order': 8},
//     {'key': 'hallmark', 'label': 'Hallmark', 'selected': true, 'order': 9},
//     {'key': 'rodium', 'label': 'Rodium', 'selected': true, 'order': 10},
//     {'key': 'hook', 'label': 'Hook', 'selected': true, 'order': 11},
//     {'key': 'size', 'label': 'Size', 'selected': true, 'order': 12},
//     {'key': 'stone', 'label': 'Stone', 'selected': true, 'order': 13},
//     {'key': 'enamel', 'label': 'Enamel', 'selected': false, 'order': 14},
//     {'key': 'length', 'label': 'Length', 'selected': true, 'order': 15},
//     {'key': 'status', 'label': 'Status', 'selected': true, 'order': 16},
//     {'key': 'product_image', 'label': 'Product Image', 'selected': false, 'isFile': true, 'order': 17},
//   ];

//   // Filter controllers
//   final TextEditingController productCodeController = TextEditingController();
//   final TextEditingController productNameController = TextEditingController();
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController statusController = TextEditingController();
//   final TextEditingController categoryController = TextEditingController();
//   final TextEditingController subCategoryController = TextEditingController();

//   // Options for filtering based on available values
//   final List<String> typeOptions = ['Piece', 'Pair'];
//   final List<String> orderTypeOptions = ['Regular', 'Urgent', 'Super Urgent'];
//   final List<String> openCloseOptions = ['open', 'close', 'solid', 'pokal'];
//   final List<String> hallmarkOptions = ['Yes', 'No'];
//   final List<String> rodiumOptions = ['Yes', 'No'];
//   final List<String> hookOptions = ['Yes', 'No'];
//   final List<String> stoneOptions = ['Yes', 'No'];
//   final List<String> sizeOptions = ['Large', 'Medium', 'Small'];
//   final List<String> statusOptions = ['Accept', 'Pending', 'Reject', 'Draft'];

//   // Fields to exclude from display
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
//     productCodeController.dispose();
//     productNameController.dispose();
//     bpCodeController.dispose();
//     statusController.dispose();
//     categoryController.dispose();
//     subCategoryController.dispose();
//     _horizontalScrollController.dispose();
//     super.dispose();
//   }

//   // Load saved field selections from SharedPreferences
//   Future<void> loadSavedFieldSelections() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? savedSelections = prefs.getString('design_fields');
//     String? savedOrder = prefs.getString('design_field_order');

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

//     await prefs.setString('design_fields', json.encode(selections));
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('design_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     setState(() {
//       compactRows = prefs.getBool('design_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('design_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('design_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('design_enable_view') ?? true;
//     });
//   }

//   // Save list settings to SharedPreferences
//   Future<void> saveListSettings({
//     required bool compactRows,
//     required bool activeRowHighlighting,
//     required bool modernCellColoring,
//     required bool enableView,
//   }) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     await prefs.setBool('design_compact_rows', compactRows);
//     await prefs.setBool('design_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('design_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('design_enable_view', enableView);
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
//         await fetchDesigns();
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
//     return field == 'product_image';
//   }

//   bool isFieldDisplayable(String field) {
//     return !excludeFromDisplay.contains(field);
//   }

//   // Get field value with proper formatting
//   String getFieldValue(Map<String, dynamic> design, String key) {
//     final value = design[key];

//     if (value == null) return '-';

//     if (value is bool) {
//       return value.toString();
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

//   // Fetch Designs
//   Future<void> fetchDesigns({String? url}) async {
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
        
//         if (data is Map) {
//           // Handle nested structure
//           if (data.containsKey('results')) {
//             final resultsData = data['results'];
//             if (resultsData is Map && resultsData.containsKey('products')) {
//               results = List<Map<String, dynamic>>.from(resultsData['products'] ?? []);
//             }
//           }
          
//           setState(() {
//             designs = results;
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
//             designs = [];
//             isLoading = false;
//           });
//         }
//       } else {
//         print('Error: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch designs: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Connection error: Please check if backend server is running', isError: true);
//     }
//   }

//   // View Design Details
//   void viewDesignDetails(Map<String, dynamic> design) {
//     setState(() {
//       currentViewedDesign = design;
//     });
//     showDesignDetailDialog();
//   }

//   // Filter Methods
//   Future<void> applyFilters() async {
//     filterParams.clear();

//     if (productCodeController.text.isNotEmpty) {
//       filterParams['product_code'] = productCodeController.text;
//     }
//     if (productNameController.text.isNotEmpty) {
//       filterParams['product_name'] = productNameController.text;
//     }
//     if (bpCodeController.text.isNotEmpty) {
//       filterParams['bp_code'] = bpCodeController.text;
//     }
//     if (statusController.text.isNotEmpty) {
//       filterParams['status'] = statusController.text;
//     }
//     if (categoryController.text.isNotEmpty) {
//       filterParams['product_category'] = categoryController.text;
//     }
//     if (subCategoryController.text.isNotEmpty) {
//       filterParams['sub_category'] = subCategoryController.text;
//     }

//     currentPage = 1;
//     await fetchDesigns();
//     Navigator.pop(context);
//   }

//   Future<void> clearFilters() async {
//     filterParams.clear();

//     productCodeController.clear();
//     productNameController.clear();
//     bpCodeController.clear();
//     statusController.clear();
//     categoryController.clear();
//     subCategoryController.clear();

//     await fetchDesigns();
//   }

//   void showFilterDialog() {
//     productCodeController.text = filterParams['product_code'] ?? '';
//     productNameController.text = filterParams['product_name'] ?? '';
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     statusController.text = filterParams['status'] ?? '';
//     categoryController.text = filterParams['product_category'] ?? '';
//     subCategoryController.text = filterParams['sub_category'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Filter Designs'),
//               content: Container(
//                 width: double.maxFinite,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       _buildFilterField(productCodeController, 'Product Code', Icons.code),
//                       _buildFilterField(productNameController, 'Product Name', Icons.shopping_bag),
//                       _buildFilterField(bpCodeController, 'BP Code', Icons.qr_code),
//                       _buildFilterField(categoryController, 'Category', Icons.category),
//                       _buildFilterField(subCategoryController, 'Sub Category', Icons.category_outlined),
//                       _buildFilterField(statusController, 'Status', Icons.info),
                      
//                       // Additional filter options can be added as dropdowns if needed
//                       SizedBox(height: 16),
//                       Text(
//                         'Note: Additional filters like Type, Size, etc. can be added based on requirements',
//                         style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
//                       ),
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
//     await fetchDesigns();
//   }

//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchDesigns();
//   }

//   void toggleSortOrder() {
//     if (sortBy == null) return;
//     String newOrder = sortOrder == 'asc' ? 'desc' : 'asc';
//     applySort(sortBy!, newOrder);
//   }

//   void showSortDialog() {
//     List<Map<String, String>> sortFields = [
//       {'value': 'product_code', 'label': 'Product Code'},
//       {'value': 'product_name', 'label': 'Product Name'},
//       {'value': 'bp_code', 'label': 'BP Code'},
//       {'value': 'product_category', 'label': 'Category'},
//       {'value': 'sub_category', 'label': 'Sub Category'},
//       {'value': 'type', 'label': 'Type'},
//       {'value': 'order_type', 'label': 'Order Type'},
//       {'value': 'status', 'label': 'Status'},
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
//                       fetchDesigns();
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
//       fetchDesigns(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchDesigns(url: prevUrl);
//     }
//   }

//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
//     await fetchDesigns();
//   }

//   // Show Design Detail Dialog
//   void showDesignDetailDialog() {
//     if (currentViewedDesign == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Design Details'),
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
//                 // Product Image
//                 if (currentViewedDesign!['product_image'] != null && 
//                     currentViewedDesign!['product_image'].toString().isNotEmpty)
//                   Center(
//                     child: InkWell(
//                       onTap: () => _showImageDialog(
//                         'Product Image', 
//                         currentViewedDesign!['product_image'].toString()
//                       ),
//                       child: Container(
//                         height: 150,
//                         width: 150,
//                         margin: EdgeInsets.only(bottom: 16),
//                         decoration: BoxDecoration(
//                           border: Border.all(color: Colors.grey.shade300),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: Image.network(
//                             currentViewedDesign!['product_image'].toString(),
//                             fit: BoxFit.cover,
//                             errorBuilder: (_, __, ___) => Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: [
//                                 Icon(Icons.broken_image, size: 50, color: Colors.grey),
//                                 Text('Image not available', style: TextStyle(fontSize: 12)),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),

//                 // All fields
//                 ...currentViewedDesign!.keys
//                     .where((field) => isFieldDisplayable(field))
//                     .map((field) => _buildDetailField(field))
//                     .toList(),
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

//   Widget _buildDetailField(String field) {
//     dynamic value = currentViewedDesign?[field];

//     String displayValue = value?.toString() ?? '-';

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
//           onTap: () => _showImageDialog(formatFieldName(field), displayValue),
//           child: Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade50,
//               borderRadius: BorderRadius.circular(4),
//             ),
//             child: Text(
//               'View Image',
//               style: TextStyle(
//                 color: Colors.blue,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         );
//       }
//       return Text('No image');
//     }

//     return Text(displayValue);
//   }

//   // Image Dialog
//   void _showImageDialog(String title, String imageUrl) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(title),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             imageUrl.startsWith('http')
//                 ? Image.network(
//                     imageUrl,
//                     height: 200,
//                     width: 200,
//                     fit: BoxFit.cover,
//                     errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 100),
//                   )
//                 : Icon(Icons.image, size: 100),
//             SizedBox(height: 16),
//             Text('Image URL:'),
//             SizedBox(height: 8),
//             Container(
//               padding: EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.grey.shade100,
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: SelectableText(
//                 imageUrl,
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
//                             'Personalize List Columns - Designs',
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
//                       child: Row(
//                         children: [
//                           SizedBox(
//                             width: 24,
//                             height: 24,
//                             child: Checkbox(
//                               value: localCompactRows,
//                               onChanged: (value) {
//                                 setState(() {
//                                   localCompactRows = value ?? false;
//                                 });
//                               },
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Text('Compact rows'),
//                           SizedBox(width: 32),
//                           SizedBox(
//                             width: 24,
//                             height: 24,
//                             child: Checkbox(
//                               value: localActiveRowHighlighting,
//                               onChanged: (value) {
//                                 setState(() {
//                                   localActiveRowHighlighting = value ?? false;
//                                 });
//                               },
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Text('Active row highlighting'),
//                           SizedBox(width: 32),
//                           SizedBox(
//                             width: 24,
//                             height: 24,
//                             child: Checkbox(
//                               value: localModernCellColoring,
//                               onChanged: (value) {
//                                 setState(() {
//                                   localModernCellColoring = value ?? false;
//                                 });
//                               },
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Text('Modern cell coloring'),
//                           SizedBox(width: 32),
//                           SizedBox(
//                             width: 24,
//                             height: 24,
//                             child: Checkbox(
//                               value: localEnableView,
//                               onChanged: (value) {
//                                 setState(() {
//                                   localEnableView = value ?? false;
//                                 });
//                               },
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Text('Enable View'),
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
//                                   {'key': 'product_code', 'label': 'Product Code', 'selected': true},
//                                   {'key': 'product_name', 'label': 'Product Name', 'selected': true},
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'product_category', 'label': 'Category', 'selected': true},
//                                   {'key': 'sub_category', 'label': 'Sub Category', 'selected': true},
//                                   {'key': 'type', 'label': 'Type', 'selected': true},
//                                   {'key': 'status', 'label': 'Status', 'selected': true},
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
//                                 'Designs - Field Selection',
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
//   }) {
//     saveListSettings(
//       compactRows: compactRows,
//       activeRowHighlighting: activeRowHighlighting,
//       modernCellColoring: modernCellColoring,
//       enableView: enableView,
//     );

//     setState(() {
//       this.compactRows = compactRows;
//       this.activeRowHighlighting = activeRowHighlighting;
//       this.modernCellColoring = modernCellColoring;
//       this.enableView = enableView;
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
//     if (designs.isEmpty) {
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

//     return designs.map((design) {
//       final id = design['id'];
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
//           isSelected && enableView
//               ? ElevatedButton(
//                   onPressed: () => viewDesignDetails(design),
//                   child: Text(
//                     'View',
//                     style: TextStyle(fontSize: compactRows ? 11 : 13),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     minimumSize: Size(60, 30),
//                     padding: EdgeInsets.symmetric(horizontal: 8),
//                   ),
//                 )
//               : SizedBox.shrink(),
//         ),
//       ];

//       for (var field in selectedFields) {
//         String displayValue = getFieldValue(design, field['key']);

//         if (field['isFile'] == true && displayValue != '-') {
//           cells.add(
//             DataCell(
//               InkWell(
//                 onTap: () => _showImageDialog(field['label'], design[field['key']]?.toString() ?? ''),
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
//                         Icons.image,
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
//         title: Text('Designs'),
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
//             onPressed: () => fetchDesigns(),
//             tooltip: 'Refresh',
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