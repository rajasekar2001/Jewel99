import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart';

class ProductPage extends StatefulWidget {
  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  // Data lists
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  Map<String, dynamic>? currentViewedProduct;

  // API Endpoints
  final String listApiUrl = 'http://127.0.0.1:8000/Products/products/list/';
  final String filterApiUrl = 'http://127.0.0.1:8000/Products/products/filter/';
  final String createApiUrl = 'http://127.0.0.1:8000/Products/products/create/';
  final String detailApiUrl = 'http://127.0.0.1:8000/Products/products/details/';
  final String updateApiUrl = 'http://127.0.0.1:8000/Products/products/update/';
  
  // Additional API Endpoints
  final String buyerApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
  final String categoryApiUrl = 'http://127.0.0.1:8000/Products/products/categories/';
  final String subcategoryApiUrl = 'http://127.0.0.1:8000/Products/products/subcategories/';
  final String categoryDetailApiUrl = 'http://127.0.0.1:8000/Products/products/categories/detail/';

  // Data for dropdowns
  List<String> buyerBpCodes = [];
  List<Map<String, dynamic>> categories = [];
  Map<int, List<Map<String, dynamic>>> categorySubcategories = {};

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
    {'key': 'product_code', 'label': 'Product Code', 'selected': true, 'order': 1},
    {'key': 'product_name', 'label': 'Product Name', 'selected': true, 'order': 2},
    {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 3},
    {'key': 'product_category', 'label': 'Category', 'selected': true, 'order': 4},
    {'key': 'sub_category', 'label': 'Sub Category', 'selected': true, 'order': 5},
    {'key': 'type', 'label': 'Type', 'selected': true, 'order': 6},
    {'key': 'quantity', 'label': 'Quantity', 'selected': true, 'order': 7},
    {'key': 'weight_from', 'label': 'Weight From', 'selected': false, 'order': 8},
    {'key': 'weight_to', 'label': 'Weight To', 'selected': false, 'order': 9},
    {'key': 'order_type', 'label': 'Order Type', 'selected': true, 'order': 10},
    {'key': 'open_close', 'label': 'Open/Close', 'selected': true, 'order': 11},
    {'key': 'hallmark', 'label': 'Hallmark', 'selected': true, 'order': 12},
    {'key': 'rodium', 'label': 'Rodium', 'selected': true, 'order': 13},
    {'key': 'hook', 'label': 'Hook', 'selected': true, 'order': 14},
    {'key': 'size', 'label': 'Size', 'selected': true, 'order': 15},
    {'key': 'stone', 'label': 'Stone', 'selected': true, 'order': 16},
    {'key': 'enamel', 'label': 'Enamel', 'selected': false, 'order': 17},
    {'key': 'length', 'label': 'Length', 'selected': true, 'order': 18},
    {'key': 'relabel_code', 'label': 'Relabel Code', 'selected': false, 'order': 19},
    {'key': 'design_code', 'label': 'Design Code', 'selected': false, 'order': 20},
    {'key': 'narration_craftsman', 'label': 'Craftsman Notes', 'selected': false, 'order': 21},
    {'key': 'narration_admin', 'label': 'Admin Notes', 'selected': false, 'order': 22},
    {'key': 'notes', 'label': 'Notes', 'selected': false, 'order': 23},
    {'key': 'status', 'label': 'Status', 'selected': true, 'order': 24},
    {'key': 'product_image', 'label': 'Product Image', 'selected': false, 'isFile': true, 'order': 25},
    {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 26},
    {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 27},
    {'key': 'created_by', 'label': 'Created By', 'selected': false, 'order': 28},
  ];

  // Filter controllers
  final TextEditingController productCodeController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController bpCodeController = TextEditingController();
  final TextEditingController designCodeController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController weightFromController = TextEditingController();
  final TextEditingController weightToController = TextEditingController();

  // Create controllers
  final Map<String, TextEditingController> createControllers = {};

  // Dropdown values for create
  String? selectedCreateBpCode;
  int? selectedCreateCategoryId;
  int? selectedCreateSubCategoryId;
  String? selectedCreateType;
  String? selectedCreateOrderType;
  String? selectedCreateOpenClose;
  String? selectedCreateHallmark;
  String? selectedCreateRodium;
  String? selectedCreateHook;
  String? selectedCreateSize;
  String? selectedCreateStone;
  String? selectedCreateStatus;

  // Edit controllers
  Map<String, TextEditingController>? editControllers;
  int? editingProductId;

  // Dropdown values for edit
  String? selectedEditBpCode;
  int? selectedEditCategoryId;
  int? selectedEditSubCategoryId;
  String? selectedEditType;
  String? selectedEditOrderType;
  String? selectedEditOpenClose;
  String? selectedEditHallmark;
  String? selectedEditRodium;
  String? selectedEditHook;
  String? selectedEditSize;
  String? selectedEditStone;
  String? selectedEditStatus;

  // File uploads - Use XFile for better cross-platform support
  XFile? productImageXFile;

  // Options for dropdowns based on backend choices
  final List<String> typeOptions = ['Piece', 'Pair'];
  final List<String> orderTypeOptions = ['Regular', 'Urgent', 'Super Urgent'];
  final List<String> openCloseOptions = ['open', 'close', 'solid', 'pokal'];
  final List<String> hallmarkOptions = ['Yes', 'No'];
  final List<String> rodiumOptions = ['Yes', 'No'];
  final List<String> hookOptions = ['Yes', 'No'];
  final List<String> stoneOptions = ['Yes', 'No'];
  final List<String> sizeOptions = ['Large', 'Medium', 'Small'];
  final List<String> statusOptions = ['Active', 'Inactive', 'Draft'];

  // Required fields for product
  final List<String> requiredFields = [
    'product_code',
    'product_name',
    'bp_code',
    'product_category',
    'sub_category',
    'type',
    'quantity',
    'weight_from',
    'weight_to',
    'order_type',
    'open_close',
    'hallmark',
    'rodium',
    'hook',
    'size',
    'stone',
    'enamel',
    'length',
    'relabel_code',
    'design_code',
    'narration_craftsman',
    'narration_admin',
    'notes',
    'status',
    'product_image',
    'created_at',
    'updated_at',
    'created_by'
  ];

  // Fields to exclude from certain operations
  final List<String> excludeFromCreate = ['created_at', 'updated_at', 'created_by'];
  final List<String> excludeFromEdit = ['created_at', 'updated_at', 'created_by'];
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
    productCodeController.dispose();
    productNameController.dispose();
    bpCodeController.dispose();
    designCodeController.dispose();
    statusController.dispose();
    quantityController.dispose();
    weightFromController.dispose();
    weightToController.dispose();

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
    String? savedSelections = prefs.getString('product_fields');
    String? savedOrder = prefs.getString('product_field_order');

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

    await prefs.setString('product_fields', json.encode(selections));
    List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
    await prefs.setString('product_field_order', json.encode(orderList));
  }

  // Load list settings from SharedPreferences
  Future<void> loadListSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      compactRows = prefs.getBool('product_compact_rows') ?? false;
      activeRowHighlighting = prefs.getBool('product_active_row_highlighting') ?? false;
      modernCellColoring = prefs.getBool('product_modern_cell_coloring') ?? false;
      enableView = prefs.getBool('product_enable_view') ?? true;
      enableEdit = prefs.getBool('product_enable_edit') ?? true;
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

    await prefs.setBool('product_compact_rows', compactRows);
    await prefs.setBool('product_active_row_highlighting', activeRowHighlighting);
    await prefs.setBool('product_modern_cell_coloring', modernCellColoring);
    await prefs.setBool('product_enable_view', enableView);
    await prefs.setBool('product_enable_edit', enableEdit);
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
          fetchBuyerBpCodes(),
          fetchCategories(),
        ]);
        await fetchProducts();
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

  // Fetch Buyer BP Codes
  Future<void> fetchBuyerBpCodes() async {
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

        // Create a Set to ensure unique values
        Set<String> uniqueBpCodes = {};
        buyerList.forEach((buyer) {
          final bpCode = buyer['bp_code']?.toString() ?? '';
          final bpName = buyer['bp_name']?.toString() ?? '';
          final displayValue = bpName.isNotEmpty ? '$bpCode - $bpName' : bpCode;
          uniqueBpCodes.add(displayValue);
        });

        setState(() {
          buyerBpCodes = uniqueBpCodes.toList()..sort();
        });
      } else {
        print('Failed to fetch buyers: ${response.statusCode}');
        _showSnackBar('Failed to fetch buyers: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error fetching buyers: $e');
      _showSnackBar('Error fetching buyers: $e', isError: true);
    }
  }

  // Fetch Categories
  Future<void> fetchCategories() async {
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse(categoryApiUrl),
        headers: {'Authorization': 'Token $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data.containsKey('results')) {
          setState(() {
            categories = List<Map<String, dynamic>>.from(data['results'] ?? []);
          });
        } else if (data is List) {
          setState(() {
            categories = List<Map<String, dynamic>>.from(data);
          });
        }
      } else {
        print('Failed to fetch categories: ${response.statusCode}');
        _showSnackBar('Failed to fetch categories: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error fetching categories: $e');
      _showSnackBar('Error fetching categories: $e', isError: true);
    }
  }

  // Fetch Subcategories for a specific category
  Future<void> fetchSubcategories(int categoryId) async {
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$categoryDetailApiUrl$categoryId/'),
        headers: {'Authorization': 'Token $token'},
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<Map<String, dynamic>> subcatList = [];
        if (data is Map && data.containsKey('results')) {
          subcatList = List<Map<String, dynamic>>.from(data['results'] ?? []);
        } else if (data is List) {
          subcatList = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          categorySubcategories[categoryId] = subcatList;
        });
      } else {
        print('Failed to fetch subcategories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching subcategories: $e');
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
  String getFieldValue(Map<String, dynamic> product, String key) {
    final value = product[key];

    if (value == null) return '-';

    if (value is bool) {
      return value.toString();
    }

    if (key == 'product_category' && value != null) {
      return getCategoryNameById(int.tryParse(value.toString()));
    }
    if (key == 'sub_category' && value != null) {
      return getSubcategoryNameById(int.tryParse(value.toString()));
    }
    if (key == 'created_by' && value != null) {
      if (value is Map) {
        return value['username']?.toString() ?? value['email']?.toString() ?? 'User';
      }
      return value.toString();
    }

    return value.toString();
  }

  // Get category name by ID
  String getCategoryNameById(int? id) {
    if (id == null) return '-';
    final category = categories.firstWhere(
      (cat) => cat['id'] == id,
      orElse: () => {'name': 'Unknown'},
    );
    return category['name'] ?? 'Unknown';
  }

  // Get subcategory name by ID
  String getSubcategoryNameById(int? id) {
    if (id == null) return '-';
    for (var entry in categorySubcategories.entries) {
      final subcat = entry.value.firstWhere(
        (sub) => sub['id'] == id,
        orElse: () => {'name': null},
      );
      if (subcat['name'] != null) return subcat['name'];
    }
    return 'Unknown';
  }

  // API Request Building
  String buildRequestUrl({String? baseUrl}) {
    if (filterParams.isEmpty && sortBy == null) {
      return listApiUrl;
    }
    
    String url = filterApiUrl;
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

    Uri uri = Uri.parse(url);
    return uri.replace(queryParameters: queryParams).toString();
  }

  // Fetch Products
  Future<void> fetchProducts({String? url}) async {
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
            products = results;
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
            products = results;
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
            products = [];
            isLoading = false;
          });
        }
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch products: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
      _showSnackBar('Connection error: Please check if backend server is running', isError: true);
    }
  }

  // Fetch Single Product Details
  Future<void> fetchProductDetails(int id) async {
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
          currentViewedProduct = data;
          isLoading = false;
        });
        showProductDetailDialog();
      } else {
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch product details', isError: true);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
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
    if (designCodeController.text.isNotEmpty) {
      filterParams['design_code'] = designCodeController.text;
    }
    if (statusController.text.isNotEmpty) {
      filterParams['status'] = statusController.text;
    }
    if (quantityController.text.isNotEmpty) {
      filterParams['quantity'] = quantityController.text;
    }
    if (weightFromController.text.isNotEmpty) {
      filterParams['weight_from'] = weightFromController.text;
    }
    if (weightToController.text.isNotEmpty) {
      filterParams['weight_to'] = weightToController.text;
    }

    currentPage = 1;
    await fetchProducts();
    Navigator.pop(context);
  }

  Future<void> clearFilters() async {
    filterParams.clear();

    productCodeController.clear();
    productNameController.clear();
    bpCodeController.clear();
    designCodeController.clear();
    statusController.clear();
    quantityController.clear();
    weightFromController.clear();
    weightToController.clear();

    await fetchProducts();
  }

  void showFilterDialog() {
    productCodeController.text = filterParams['product_code'] ?? '';
    productNameController.text = filterParams['product_name'] ?? '';
    bpCodeController.text = filterParams['bp_code'] ?? '';
    designCodeController.text = filterParams['design_code'] ?? '';
    statusController.text = filterParams['status'] ?? '';
    quantityController.text = filterParams['quantity'] ?? '';
    weightFromController.text = filterParams['weight_from'] ?? '';
    weightToController.text = filterParams['weight_to'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Filter Products'),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFilterField(productCodeController, 'Product Code', Icons.code),
                      _buildFilterField(productNameController, 'Product Name', Icons.shopping_bag),
                      _buildFilterField(bpCodeController, 'BP Code', Icons.qr_code),
                      _buildFilterField(designCodeController, 'Design Code', Icons.design_services),
                      _buildFilterField(statusController, 'Status', Icons.info),
                      _buildFilterField(quantityController, 'Quantity', Icons.numbers),
                      _buildFilterField(weightFromController, 'Weight From', Icons.arrow_downward),
                      _buildFilterField(weightToController, 'Weight To', Icons.arrow_upward),
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
    await fetchProducts();
  }

  Future<void> clearSort() async {
    setState(() {
      sortBy = null;
      sortOrder = null;
    });
    await fetchProducts();
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
      {'value': 'design_code', 'label': 'Design Code'},
      {'value': 'quantity', 'label': 'Quantity'},
      {'value': 'weight_from', 'label': 'Weight From'},
      {'value': 'weight_to', 'label': 'Weight To'},
      {'value': 'order_type', 'label': 'Order Type'},
      {'value': 'status', 'label': 'Status'},
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
                      fetchProducts();
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
      fetchProducts(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchProducts(url: prevUrl);
    }
  }

  Future<void> changePageSize(int newSize) async {
    setState(() {
      pageSize = newSize;
      currentPage = 1;
    });
    await fetchProducts();
  }

  // Add Category Dialog
  void showAddCategoryDialog() {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Category Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter category name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await createCategory(nameController.text);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // Create Category
  Future<void> createCategory(String name) async {
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse(categoryApiUrl),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': name}),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchCategories();
        _showSnackBar('Category added successfully!');
      } else {
        print('Error: ${response.body}');
        _showSnackBar('Failed to add category: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error: $e');
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // Add Subcategory Dialog
  void showAddSubcategoryDialog(int categoryId) {
    final TextEditingController nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Subcategory'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Subcategory Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter subcategory name';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await createSubcategory(categoryId, nameController.text);
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // Create Subcategory
  Future<void> createSubcategory(int categoryId, String name) async {
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse(subcategoryApiUrl),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name,
          'category_name': categoryId,
        }),
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchSubcategories(categoryId);
        _showSnackBar('Subcategory added successfully!');
      } else {
        print('Error: ${response.body}');
        _showSnackBar('Failed to add subcategory: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error: $e');
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // Create Product Methods
  void showAddProductDialog() {
    for (var field in requiredFields) {
      if (!excludeFromCreate.contains(field) &&
          !isFileField(field) &&
          !createControllers.containsKey(field)) {
        createControllers[field] = TextEditingController();
      }
    }

    // Reset selections
    productImageXFile = null;
    selectedCreateBpCode = null;
    selectedCreateCategoryId = null;
    selectedCreateSubCategoryId = null;
    selectedCreateType = null;
    selectedCreateOrderType = null;
    selectedCreateOpenClose = null;
    selectedCreateHallmark = null;
    selectedCreateRodium = null;
    selectedCreateHook = null;
    selectedCreateSize = null;
    selectedCreateStone = null;
    selectedCreateStatus = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Product'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCreateTextField('product_code', 'Product Code', Icons.code, isRequired: true),
                    _buildCreateTextField('product_name', 'Product Name', Icons.shopping_bag, isRequired: true),
                    
                    // BP Code dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateBpCode,
                      label: 'BP Code',
                      icon: Icons.qr_code,
                      items: buyerBpCodes,
                      onChanged: (value) => setState(() => selectedCreateBpCode = value),
                    ),

                    // Category dropdown with Add button
                    Row(
                      children: [
                        Expanded(
                          child: _buildCreateDropdownField(
                            value: selectedCreateCategoryId != null 
                                ? categories.firstWhere(
                                    (cat) => cat['id'] == selectedCreateCategoryId,
                                    orElse: () => {'name': null},
                                  )['name']
                                : null,
                            label: 'Category',
                            icon: Icons.category,
                            items: categories.map((cat) => cat['name'].toString()).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final selectedCat = categories.firstWhere(
                                  (cat) => cat['name'] == value,
                                );
                                setState(() {
                                  selectedCreateCategoryId = selectedCat['id'];
                                  selectedCreateSubCategoryId = null;
                                });
                                fetchSubcategories(selectedCat['id']);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: Colors.green),
                          onPressed: showAddCategoryDialog,
                          tooltip: 'Add New Category',
                        ),
                      ],
                    ),

                    // Sub Category dropdown with Add button (only if category selected)
                    if (selectedCreateCategoryId != null)
                      Row(
                        children: [
                          Expanded(
                            child: _buildCreateDropdownField(
                              value: selectedCreateSubCategoryId != null
                                  ? (categorySubcategories[selectedCreateCategoryId] ?? [])
                                      .firstWhere(
                                        (sub) => sub['id'] == selectedCreateSubCategoryId,
                                        orElse: () => {'name': null},
                                      )['name']
                                  : null,
                              label: 'Sub Category',
                              icon: Icons.category_outlined,
                              items: (categorySubcategories[selectedCreateCategoryId] ?? [])
                                  .map((sub) => sub['name'].toString())
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  final subcatList = categorySubcategories[selectedCreateCategoryId] ?? [];
                                  final selectedSub = subcatList.firstWhere(
                                    (sub) => sub['name'] == value,
                                  );
                                  setState(() {
                                    selectedCreateSubCategoryId = selectedSub['id'];
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () => showAddSubcategoryDialog(selectedCreateCategoryId!),
                            tooltip: 'Add New Subcategory',
                          ),
                        ],
                      ),

                    // Type dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateType,
                      label: 'Type',
                      icon: Icons.type_specimen,
                      items: typeOptions,
                      onChanged: (value) => setState(() => selectedCreateType = value),
                    ),

                    _buildCreateTextField('quantity', 'Quantity', Icons.numbers, isRequired: true),
                    _buildCreateTextField('weight_from', 'Weight From', Icons.arrow_downward),
                    _buildCreateTextField('weight_to', 'Weight To', Icons.arrow_upward),

                    // Order Type dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateOrderType,
                      label: 'Order Type',
                      icon: Icons.shopping_cart,
                      items: orderTypeOptions,
                      onChanged: (value) => setState(() => selectedCreateOrderType = value),
                    ),

                    // Open/Close dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateOpenClose,
                      label: 'Open/Close',
                      icon: Icons.lock_open,
                      items: openCloseOptions,
                      onChanged: (value) => setState(() => selectedCreateOpenClose = value),
                    ),

                    // Hallmark dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateHallmark,
                      label: 'Hallmark',
                      icon: Icons.verified,
                      items: hallmarkOptions,
                      onChanged: (value) => setState(() => selectedCreateHallmark = value),
                    ),

                    // Rodium dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateRodium,
                      label: 'Rodium',
                      icon: Icons.science,
                      items: rodiumOptions,
                      onChanged: (value) => setState(() => selectedCreateRodium = value),
                    ),

                    // Hook dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateHook,
                      label: 'Hook',
                      icon: Icons.attach_file,
                      items: hookOptions,
                      onChanged: (value) => setState(() => selectedCreateHook = value),
                    ),

                    // Size dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateSize,
                      label: 'Size',
                      icon: Icons.straighten,
                      items: sizeOptions,
                      onChanged: (value) => setState(() => selectedCreateSize = value),
                    ),

                    // Stone dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateStone,
                      label: 'Stone',
                      icon: Icons.diamond,
                      items: stoneOptions,
                      onChanged: (value) => setState(() => selectedCreateStone = value),
                    ),

                    _buildCreateTextField('enamel', 'Enamel', Icons.color_lens),
                    
                    // Length field
                    _buildCreateTextField('length', 'Length', Icons.height),

                    // Design Code
                    _buildCreateTextField('design_code', 'Design Code', Icons.design_services),

                    // Relabel Code
                    _buildCreateTextField('relabel_code', 'Relabel Code', Icons.tag),

                    // Craftsman Notes
                    _buildCreateTextField('narration_craftsman', 'Craftsman Notes', Icons.note, maxLines: 3),

                    // Admin Notes
                    _buildCreateTextField('narration_admin', 'Admin Notes', Icons.admin_panel_settings, maxLines: 3),

                    // Notes
                    _buildCreateTextField('notes', 'Notes', Icons.note_alt, maxLines: 3),

                    // Status dropdown
                    _buildCreateDropdownField(
                      value: selectedCreateStatus,
                      label: 'Status',
                      icon: Icons.info,
                      items: statusOptions,
                      onChanged: (value) => setState(() => selectedCreateStatus = value),
                    ),

                    _buildCreateFileField('product_image', 'Product Image', Icons.image, setState),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (createControllers['product_code']?.text.isEmpty == true) {
                    _showSnackBar('Please enter product code', isError: true);
                    return;
                  }
                  if (createControllers['product_name']?.text.isEmpty == true) {
                    _showSnackBar('Please enter product name', isError: true);
                    return;
                  }
                  await createProduct();
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
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget _buildCreateFileField(
      String field, String label, IconData icon, StateSetter setState) {
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
                    await pickImage();
                    setState(() {});
                  },
                  icon: Icon(icon),
                  label: Text(
                    productImageXFile != null 
                        ? path.basename(productImageXFile!.path)
                        : 'Select Image',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (productImageXFile != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      productImageXFile = null;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> createProduct() async {
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

      // Add dropdown selections
      if (selectedCreateBpCode != null) {
        final bpValue = selectedCreateBpCode!.split('-').first.trim();
        request.fields['bp_code'] = bpValue;
      }
      if (selectedCreateCategoryId != null) {
        request.fields['product_category'] = selectedCreateCategoryId!.toString();
      }
      if (selectedCreateSubCategoryId != null) {
        request.fields['sub_category'] = selectedCreateSubCategoryId!.toString();
      }
      if (selectedCreateType != null) {
        request.fields['type'] = selectedCreateType!;
      }
      if (selectedCreateOrderType != null) {
        request.fields['order_type'] = selectedCreateOrderType!;
      }
      if (selectedCreateOpenClose != null) {
        request.fields['open_close'] = selectedCreateOpenClose!;
      }
      if (selectedCreateHallmark != null) {
        request.fields['hallmark'] = selectedCreateHallmark!;
      }
      if (selectedCreateRodium != null) {
        request.fields['rodium'] = selectedCreateRodium!;
      }
      if (selectedCreateHook != null) {
        request.fields['hook'] = selectedCreateHook!;
      }
      if (selectedCreateSize != null) {
        request.fields['size'] = selectedCreateSize!;
      }
      if (selectedCreateStone != null) {
        request.fields['stone'] = selectedCreateStone!;
      }
      if (selectedCreateStatus != null) {
        request.fields['status'] = selectedCreateStatus!;
      }

      // Add image if selected with proper filename
      if (productImageXFile != null) {
        String filename = path.basename(productImageXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(productImageXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          final bytes = await productImageXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'product_image',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(productImageXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'product_image',
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

        productImageXFile = null;
        selectedCreateBpCode = null;
        selectedCreateCategoryId = null;
        selectedCreateSubCategoryId = null;
        selectedCreateType = null;
        selectedCreateOrderType = null;
        selectedCreateOpenClose = null;
        selectedCreateHallmark = null;
        selectedCreateRodium = null;
        selectedCreateHook = null;
        selectedCreateSize = null;
        selectedCreateStone = null;
        selectedCreateStatus = null;

        await fetchProducts();
        _showSnackBar('Product created successfully!');
      } else {
        print('Error response: $responseBody');
        _showSnackBar('Failed to create product: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error in createProduct: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Pick Image
  Future<void> pickImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(source: ImageSource.gallery);
      
      if (file != null) {
        setState(() {
          productImageXFile = file;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  // View Product Details
  void showProductDetailDialog() {
    if (currentViewedProduct == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Product Details'),
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
    dynamic value = currentViewedProduct?[field];

    String displayValue = '-';
    if (field == 'product_category' && value != null) {
      displayValue = getCategoryNameById(int.tryParse(value.toString()));
    } else if (field == 'sub_category' && value != null) {
      displayValue = getSubcategoryNameById(int.tryParse(value.toString()));
    } else if (field == 'bp_code' && value != null) {
      // Try to find the BP code display value
      final bpValue = buyerBpCodes.firstWhere(
        (bp) => bp.startsWith(value.toString()),
        orElse: () => value.toString(),
      );
      displayValue = bpValue;
    } else if (field == 'created_by' && value != null) {
      if (value is Map) {
        displayValue = value['username']?.toString() ?? value['email']?.toString() ?? 'User';
      } else {
        displayValue = value.toString();
      }
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
            child: _buildDetailValue(field, value, displayValue),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailValue(String field, dynamic value, String displayValue) {
    if (isFileField(field)) {
      if (value != null && value.toString().isNotEmpty) {
        return InkWell(
          onTap: () => _showImageDialog(formatFieldName(field), value.toString()),
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
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image, size: 100),
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
                            'Personalize List Columns - Products',
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
                                  {'key': 'product_code', 'label': 'Product Code', 'selected': true},
                                  {'key': 'product_name', 'label': 'Product Name', 'selected': true},
                                  {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
                                  {'key': 'product_category', 'label': 'Category', 'selected': true},
                                  {'key': 'sub_category', 'label': 'Sub Category', 'selected': true},
                                  {'key': 'type', 'label': 'Type', 'selected': true},
                                  {'key': 'quantity', 'label': 'Quantity', 'selected': true},
                                  {'key': 'order_type', 'label': 'Order Type', 'selected': true},
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
                                'Products - Field Selection',
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
    if (products.isEmpty) {
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

    return products.map((product) {
      final id = product['id'];
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
                        onPressed: () => fetchProductDetails(id),
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
                        onPressed: () => showEditProductDialog(product),
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
        String displayValue = getFieldValue(product, field['key']);

        if (field['isFile'] == true && displayValue != '-') {
          cells.add(
            DataCell(
              InkWell(
                onTap: () => _showImageDialog(field['label'], product[field['key']]?.toString() ?? ''),
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

  // Edit Product Methods
  void showEditProductDialog(Map<String, dynamic> product) {
    editingProductId = product['id'];
    editControllers = {};

    for (var field in requiredFields) {
      if (!excludeFromEdit.contains(field) && !isFileField(field)) {
        editControllers![field] = TextEditingController(
          text: product[field]?.toString() ?? '',
        );
      }
    }

    // Set dropdown values for edit
    selectedEditBpCode = product['bp_code'];
    
    final catId = product['product_category'];
    if (catId != null) {
      selectedEditCategoryId = int.tryParse(catId.toString());
      if (selectedEditCategoryId != null) {
        fetchSubcategories(selectedEditCategoryId!);
      }
    }
    
    final subId = product['sub_category'];
    if (subId != null) {
      selectedEditSubCategoryId = int.tryParse(subId.toString());
    }
    
    selectedEditType = product['type'];
    selectedEditOrderType = product['order_type'];
    selectedEditOpenClose = product['open_close'];
    selectedEditHallmark = product['hallmark'];
    selectedEditRodium = product['rodium'];
    selectedEditHook = product['hook'];
    selectedEditSize = product['size'];
    selectedEditStone = product['stone'];
    selectedEditStatus = product['status'];

    // Reset file selections
    productImageXFile = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Edit Product'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEditTextField('product_code', 'Product Code', Icons.code),
                    _buildEditTextField('product_name', 'Product Name', Icons.shopping_bag),

                    // BP Code dropdown for edit
                    _buildEditDropdownField(
                      value: selectedEditBpCode,
                      label: 'BP Code',
                      icon: Icons.qr_code,
                      items: buyerBpCodes,
                      onChanged: (value) => setState(() => selectedEditBpCode = value),
                    ),

                    // Category dropdown with Add button
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditDropdownField(
                            value: selectedEditCategoryId != null 
                                ? categories.firstWhere(
                                    (cat) => cat['id'] == selectedEditCategoryId,
                                    orElse: () => {'name': null},
                                  )['name']
                                : null,
                            label: 'Category',
                            icon: Icons.category,
                            items: categories.map((cat) => cat['name'].toString()).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final selectedCat = categories.firstWhere(
                                  (cat) => cat['name'] == value,
                                );
                                setState(() {
                                  selectedEditCategoryId = selectedCat['id'];
                                  selectedEditSubCategoryId = null;
                                });
                                fetchSubcategories(selectedCat['id']);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: Colors.green),
                          onPressed: showAddCategoryDialog,
                          tooltip: 'Add New Category',
                        ),
                      ],
                    ),

                    // Sub Category dropdown with Add button (only if category selected)
                    if (selectedEditCategoryId != null)
                      Row(
                        children: [
                          Expanded(
                            child: _buildEditDropdownField(
                              value: selectedEditSubCategoryId != null
                                  ? (categorySubcategories[selectedEditCategoryId] ?? [])
                                      .firstWhere(
                                        (sub) => sub['id'] == selectedEditSubCategoryId,
                                        orElse: () => {'name': null},
                                      )['name']
                                  : null,
                              label: 'Sub Category',
                              icon: Icons.category_outlined,
                              items: (categorySubcategories[selectedEditCategoryId] ?? [])
                                  .map((sub) => sub['name'].toString())
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  final subcatList = categorySubcategories[selectedEditCategoryId] ?? [];
                                  final selectedSub = subcatList.firstWhere(
                                    (sub) => sub['name'] == value,
                                  );
                                  setState(() {
                                    selectedEditSubCategoryId = selectedSub['id'];
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () => showAddSubcategoryDialog(selectedEditCategoryId!),
                            tooltip: 'Add New Subcategory',
                          ),
                        ],
                      ),

                    // Type dropdown
                    _buildEditDropdownField(
                      value: selectedEditType,
                      label: 'Type',
                      icon: Icons.type_specimen,
                      items: typeOptions,
                      onChanged: (value) => setState(() => selectedEditType = value),
                    ),

                    _buildEditTextField('quantity', 'Quantity', Icons.numbers),
                    _buildEditTextField('weight_from', 'Weight From', Icons.arrow_downward),
                    _buildEditTextField('weight_to', 'Weight To', Icons.arrow_upward),

                    // Order Type dropdown
                    _buildEditDropdownField(
                      value: selectedEditOrderType,
                      label: 'Order Type',
                      icon: Icons.shopping_cart,
                      items: orderTypeOptions,
                      onChanged: (value) => setState(() => selectedEditOrderType = value),
                    ),

                    // Open/Close dropdown
                    _buildEditDropdownField(
                      value: selectedEditOpenClose,
                      label: 'Open/Close',
                      icon: Icons.lock_open,
                      items: openCloseOptions,
                      onChanged: (value) => setState(() => selectedEditOpenClose = value),
                    ),

                    // Hallmark dropdown
                    _buildEditDropdownField(
                      value: selectedEditHallmark,
                      label: 'Hallmark',
                      icon: Icons.verified,
                      items: hallmarkOptions,
                      onChanged: (value) => setState(() => selectedEditHallmark = value),
                    ),

                    // Rodium dropdown
                    _buildEditDropdownField(
                      value: selectedEditRodium,
                      label: 'Rodium',
                      icon: Icons.science,
                      items: rodiumOptions,
                      onChanged: (value) => setState(() => selectedEditRodium = value),
                    ),

                    // Hook dropdown
                    _buildEditDropdownField(
                      value: selectedEditHook,
                      label: 'Hook',
                      icon: Icons.attach_file,
                      items: hookOptions,
                      onChanged: (value) => setState(() => selectedEditHook = value),
                    ),

                    // Size dropdown
                    _buildEditDropdownField(
                      value: selectedEditSize,
                      label: 'Size',
                      icon: Icons.straighten,
                      items: sizeOptions,
                      onChanged: (value) => setState(() => selectedEditSize = value),
                    ),

                    // Stone dropdown
                    _buildEditDropdownField(
                      value: selectedEditStone,
                      label: 'Stone',
                      icon: Icons.diamond,
                      items: stoneOptions,
                      onChanged: (value) => setState(() => selectedEditStone = value),
                    ),

                    _buildEditTextField('enamel', 'Enamel', Icons.color_lens),
                    _buildEditTextField('length', 'Length', Icons.height),
                    _buildEditTextField('design_code', 'Design Code', Icons.design_services),
                    _buildEditTextField('relabel_code', 'Relabel Code', Icons.tag),
                    _buildEditTextField('narration_craftsman', 'Craftsman Notes', Icons.note, maxLines: 3),
                    _buildEditTextField('narration_admin', 'Admin Notes', Icons.admin_panel_settings, maxLines: 3),
                    _buildEditTextField('notes', 'Notes', Icons.note_alt, maxLines: 3),

                    // Status dropdown
                    _buildEditDropdownField(
                      value: selectedEditStatus,
                      label: 'Status',
                      icon: Icons.info,
                      items: statusOptions,
                      onChanged: (value) => setState(() => selectedEditStatus = value),
                    ),

                    _buildEditFileField('product_image', 'Product Image', Icons.image, product, setState),
                  ],
                ),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await updateProduct(editingProductId!);
                  Navigator.pop(context);
                },
                child: Text('Save'),
              ),
              TextButton(
                onPressed: () {
                  editControllers = null;
                  editingProductId = null;
                  productImageXFile = null;
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
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: items.isEmpty ? null : onChanged,
      ),
    );
  }

  Widget _buildEditFileField(String field, String label, IconData icon,
      Map<String, dynamic> product, StateSetter setState) {
    String? imageUrl = product[field];

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
          if (imageUrl != null && imageUrl.isNotEmpty && productImageXFile == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showImageDialog(label, imageUrl),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'View Existing Image',
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
                    await pickImage();
                    setState(() {});
                  },
                  icon: Icon(icon),
                  label: Text(
                    productImageXFile != null
                        ? path.basename(productImageXFile!.path)
                        : 'Select New Image',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (productImageXFile != null)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      productImageXFile = null;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> updateProduct(int id) async {
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

      // Add dropdown selections
      if (selectedEditBpCode != null) {
        final bpValue = selectedEditBpCode!.split('-').first.trim();
        request.fields['bp_code'] = bpValue;
      }
      if (selectedEditCategoryId != null) {
        request.fields['product_category'] = selectedEditCategoryId!.toString();
      }
      if (selectedEditSubCategoryId != null) {
        request.fields['sub_category'] = selectedEditSubCategoryId!.toString();
      }
      if (selectedEditType != null) {
        request.fields['type'] = selectedEditType!;
      }
      if (selectedEditOrderType != null) {
        request.fields['order_type'] = selectedEditOrderType!;
      }
      if (selectedEditOpenClose != null) {
        request.fields['open_close'] = selectedEditOpenClose!;
      }
      if (selectedEditHallmark != null) {
        request.fields['hallmark'] = selectedEditHallmark!;
      }
      if (selectedEditRodium != null) {
        request.fields['rodium'] = selectedEditRodium!;
      }
      if (selectedEditHook != null) {
        request.fields['hook'] = selectedEditHook!;
      }
      if (selectedEditSize != null) {
        request.fields['size'] = selectedEditSize!;
      }
      if (selectedEditStone != null) {
        request.fields['stone'] = selectedEditStone!;
      }
      if (selectedEditStatus != null) {
        request.fields['status'] = selectedEditStatus!;
      }

      // Add image if selected with proper filename
      if (productImageXFile != null) {
        String filename = path.basename(productImageXFile!.path);
        // Ensure filename has an extension
        if (!filename.contains('.')) {
          // Try to detect mime type and add appropriate extension
          final mimeType = lookupMimeType(productImageXFile!.path);
          if (mimeType != null) {
            String extension = mimeType.split('/').last;
            filename = '$filename.$extension';
          } else {
            filename = '$filename.jpg'; // Default to .jpg
          }
        }

        if (kIsWeb) {
          Uint8List bytes = await productImageXFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'product_image',
              bytes,
              filename: filename,
            ),
          );
        } else {
          final file = File(productImageXFile!.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'product_image',
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
        editingProductId = null;
        productImageXFile = null;
        selectedEditBpCode = null;
        selectedEditCategoryId = null;
        selectedEditSubCategoryId = null;
        selectedEditType = null;
        selectedEditOrderType = null;
        selectedEditOpenClose = null;
        selectedEditHallmark = null;
        selectedEditRodium = null;
        selectedEditHook = null;
        selectedEditSize = null;
        selectedEditStone = null;
        selectedEditStatus = null;

        await fetchProducts();
        _showSnackBar('Product updated successfully!');
      } else {
        print('Error response: $responseBody');
        _showSnackBar('Failed to update product: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error in updateProduct: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Products'),
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
            onPressed: () => fetchProducts(),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: showAddProductDialog,
              icon: Icon(Icons.add),
              label: Text('Add Product'),
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

// class ProductPage extends StatefulWidget {
//   @override
//   _ProductPageState createState() => _ProductPageState();
// }

// class _ProductPageState extends State<ProductPage> {
//   // Data lists
//   List<Map<String, dynamic>> products = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   Map<String, dynamic>? currentViewedProduct;

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/Products/products/list/';
//   final String filterApiUrl = 'http://127.0.0.1:8000/Products/products/filter/';
//   final String createApiUrl = 'http://127.0.0.1:8000/Products/products/create/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/Products/products/details/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/Products/products/update/';
  
//   // Additional API Endpoints
//   final String buyerApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
//   final String categoryApiUrl = 'http://127.0.0.1:8000/Products/products/categories/';
//   final String subcategoryApiUrl = 'http://127.0.0.1:8000/Products/products/subcategories/';
//   final String categoryDetailApiUrl = 'http://127.0.0.1:8000/Products/products/categories/detail/';

//   // Data for dropdowns
//   List<String> buyerBpCodes = [];
//   List<Map<String, dynamic>> categories = [];
//   Map<int, List<Map<String, dynamic>>> categorySubcategories = {};

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
//     {'key': 'product_code', 'label': 'Product Code', 'selected': true, 'order': 1},
//     {'key': 'product_name', 'label': 'Product Name', 'selected': true, 'order': 2},
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 3},
//     {'key': 'product_category', 'label': 'Category', 'selected': true, 'order': 4},
//     {'key': 'sub_category', 'label': 'Sub Category', 'selected': true, 'order': 5},
//     {'key': 'type', 'label': 'Type', 'selected': true, 'order': 6},
//     {'key': 'quantity', 'label': 'Quantity', 'selected': true, 'order': 7},
//     {'key': 'weight_from', 'label': 'Weight From', 'selected': false, 'order': 8},
//     {'key': 'weight_to', 'label': 'Weight To', 'selected': false, 'order': 9},
//     {'key': 'order_type', 'label': 'Order Type', 'selected': true, 'order': 10},
//     {'key': 'open_close', 'label': 'Open/Close', 'selected': true, 'order': 11},
//     {'key': 'hallmark', 'label': 'Hallmark', 'selected': true, 'order': 12},
//     {'key': 'rodium', 'label': 'Rodium', 'selected': true, 'order': 13},
//     {'key': 'hook', 'label': 'Hook', 'selected': true, 'order': 14},
//     {'key': 'size', 'label': 'Size', 'selected': true, 'order': 15},
//     {'key': 'stone', 'label': 'Stone', 'selected': true, 'order': 16},
//     {'key': 'enamel', 'label': 'Enamel', 'selected': false, 'order': 17},
//     {'key': 'length', 'label': 'Length', 'selected': true, 'order': 18},
//     {'key': 'relabel_code', 'label': 'Relabel Code', 'selected': false, 'order': 19},
//     {'key': 'design_code', 'label': 'Design Code', 'selected': false, 'order': 20},
//     {'key': 'narration_craftsman', 'label': 'Craftsman Notes', 'selected': false, 'order': 21},
//     {'key': 'narration_admin', 'label': 'Admin Notes', 'selected': false, 'order': 22},
//     {'key': 'notes', 'label': 'Notes', 'selected': false, 'order': 23},
//     {'key': 'status', 'label': 'Status', 'selected': true, 'order': 24},
//     {'key': 'product_image', 'label': 'Product Image', 'selected': false, 'isFile': true, 'order': 25},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 26},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 27},
//     {'key': 'created_by', 'label': 'Created By', 'selected': false, 'order': 28},
//   ];

//   // Filter controllers
//   final TextEditingController productCodeController = TextEditingController();
//   final TextEditingController productNameController = TextEditingController();
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController designCodeController = TextEditingController();
//   final TextEditingController statusController = TextEditingController();
//   final TextEditingController quantityController = TextEditingController();
//   final TextEditingController weightFromController = TextEditingController();
//   final TextEditingController weightToController = TextEditingController();

//   // Create controllers
//   final Map<String, TextEditingController> createControllers = {};

//   // Dropdown values for create
//   String? selectedCreateBpCode;
//   int? selectedCreateCategoryId;
//   int? selectedCreateSubCategoryId;
//   String? selectedCreateType;
//   String? selectedCreateOrderType;
//   String? selectedCreateOpenClose;
//   String? selectedCreateHallmark;
//   String? selectedCreateRodium;
//   String? selectedCreateHook;
//   String? selectedCreateSize;
//   String? selectedCreateStone;
//   String? selectedCreateStatus;

//   // Edit controllers
//   Map<String, TextEditingController>? editControllers;
//   int? editingProductId;

//   // Dropdown values for edit
//   String? selectedEditBpCode;
//   int? selectedEditCategoryId;
//   int? selectedEditSubCategoryId;
//   String? selectedEditType;
//   String? selectedEditOrderType;
//   String? selectedEditOpenClose;
//   String? selectedEditHallmark;
//   String? selectedEditRodium;
//   String? selectedEditHook;
//   String? selectedEditSize;
//   String? selectedEditStone;
//   String? selectedEditStatus;

//   // File uploads
//   File? productImageFile;
//   String? productImageFileName;

//   // Options for dropdowns based on backend choices
//   final List<String> typeOptions = ['Piece', 'Pair'];
//   final List<String> orderTypeOptions = ['Regular', 'Urgent', 'Super Urgent'];
//   final List<String> openCloseOptions = ['open', 'close', 'solid', 'pokal'];
//   final List<String> hallmarkOptions = ['Yes', 'No'];
//   final List<String> rodiumOptions = ['Yes', 'No'];
//   final List<String> hookOptions = ['Yes', 'No'];
//   final List<String> stoneOptions = ['Yes', 'No'];
//   final List<String> sizeOptions = ['Large', 'Medium', 'Small'];
//   final List<String> statusOptions = ['Active', 'Inactive', 'Draft'];

//   // Required fields for product
//   final List<String> requiredFields = [
//     'product_code',
//     'product_name',
//     'bp_code',
//     'product_category',
//     'sub_category',
//     'type',
//     'quantity',
//     'weight_from',
//     'weight_to',
//     'order_type',
//     'open_close',
//     'hallmark',
//     'rodium',
//     'hook',
//     'size',
//     'stone',
//     'enamel',
//     'length',
//     'relabel_code',
//     'design_code',
//     'narration_craftsman',
//     'narration_admin',
//     'notes',
//     'status',
//     'product_image',
//     'created_at',
//     'updated_at',
//     'created_by'
//   ];

//   // Fields to exclude from certain operations
//   final List<String> excludeFromCreate = ['created_at', 'updated_at', 'created_by'];
//   final List<String> excludeFromEdit = ['created_at', 'updated_at', 'created_by'];
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
//     designCodeController.dispose();
//     statusController.dispose();
//     quantityController.dispose();
//     weightFromController.dispose();
//     weightToController.dispose();

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
//     String? savedSelections = prefs.getString('product_fields');
//     String? savedOrder = prefs.getString('product_field_order');

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

//     await prefs.setString('product_fields', json.encode(selections));
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('product_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     setState(() {
//       compactRows = prefs.getBool('product_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('product_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('product_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('product_enable_view') ?? true;
//       enableEdit = prefs.getBool('product_enable_edit') ?? true;
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

//     await prefs.setBool('product_compact_rows', compactRows);
//     await prefs.setBool('product_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('product_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('product_enable_view', enableView);
//     await prefs.setBool('product_enable_edit', enableEdit);
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
//           fetchCategories(),
//         ]);
//         await fetchProducts();
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
//           uniqueBpCodes.add(displayValue);
//         });

//         setState(() {
//           buyerBpCodes = uniqueBpCodes.toList()..sort();
//         });
//       } else {
//         print('Failed to fetch buyers: ${response.statusCode}');
//         _showSnackBar('Failed to fetch buyers: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Error fetching buyers: $e');
//       _showSnackBar('Error fetching buyers: $e', isError: true);
//     }
//   }

//   // Fetch Categories
//   Future<void> fetchCategories() async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse(categoryApiUrl),
//         headers: {'Authorization': 'Token $token'},
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         if (data is Map && data.containsKey('results')) {
//           setState(() {
//             categories = List<Map<String, dynamic>>.from(data['results'] ?? []);
//           });
//         } else if (data is List) {
//           setState(() {
//             categories = List<Map<String, dynamic>>.from(data);
//           });
//         }
//       } else {
//         print('Failed to fetch categories: ${response.statusCode}');
//         _showSnackBar('Failed to fetch categories: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Error fetching categories: $e');
//       _showSnackBar('Error fetching categories: $e', isError: true);
//     }
//   }

//   // Fetch Subcategories for a specific category
//   Future<void> fetchSubcategories(int categoryId) async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse('$categoryDetailApiUrl$categoryId/'),
//         headers: {'Authorization': 'Token $token'},
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         List<Map<String, dynamic>> subcatList = [];
//         if (data is Map && data.containsKey('results')) {
//           subcatList = List<Map<String, dynamic>>.from(data['results'] ?? []);
//         } else if (data is List) {
//           subcatList = List<Map<String, dynamic>>.from(data);
//         }

//         setState(() {
//           categorySubcategories[categoryId] = subcatList;
//         });
//       } else {
//         print('Failed to fetch subcategories: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching subcategories: $e');
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
//   String getFieldValue(Map<String, dynamic> product, String key) {
//     final value = product[key];

//     if (value == null) return '-';

//     if (value is bool) {
//       return value.toString();
//     }

//     if (key == 'product_category' && value != null) {
//       return getCategoryNameById(int.tryParse(value.toString()));
//     }
//     if (key == 'sub_category' && value != null) {
//       return getSubcategoryNameById(int.tryParse(value.toString()));
//     }
//     if (key == 'created_by' && value != null) {
//       if (value is Map) {
//         return value['username']?.toString() ?? value['email']?.toString() ?? 'User';
//       }
//       return value.toString();
//     }

//     return value.toString();
//   }

//   // Get category name by ID
//   String getCategoryNameById(int? id) {
//     if (id == null) return '-';
//     final category = categories.firstWhere(
//       (cat) => cat['id'] == id,
//       orElse: () => {'name': 'Unknown'},
//     );
//     return category['name'] ?? 'Unknown';
//   }

//   // Get subcategory name by ID
//   String getSubcategoryNameById(int? id) {
//     if (id == null) return '-';
//     for (var entry in categorySubcategories.entries) {
//       final subcat = entry.value.firstWhere(
//         (sub) => sub['id'] == id,
//         orElse: () => {'name': null},
//       );
//       if (subcat['name'] != null) return subcat['name'];
//     }
//     return 'Unknown';
//   }

//   // API Request Building
//   String buildRequestUrl({String? baseUrl}) {
//     if (filterParams.isEmpty && sortBy == null) {
//       return listApiUrl;
//     }
    
//     String url = filterApiUrl;
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

//     Uri uri = Uri.parse(url);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Fetch Products
//   Future<void> fetchProducts({String? url}) async {
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
//             products = results;
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
//             products = results;
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
//             products = [];
//             isLoading = false;
//           });
//         }
//       } else {
//         print('Error: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch products: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Connection error: Please check if backend server is running', isError: true);
//     }
//   }

//   // Fetch Single Product Details
//   Future<void> fetchProductDetails(int id) async {
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
//           currentViewedProduct = data;
//           isLoading = false;
//         });
//         showProductDetailDialog();
//       } else {
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch product details', isError: true);
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
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
//     if (designCodeController.text.isNotEmpty) {
//       filterParams['design_code'] = designCodeController.text;
//     }
//     if (statusController.text.isNotEmpty) {
//       filterParams['status'] = statusController.text;
//     }
//     if (quantityController.text.isNotEmpty) {
//       filterParams['quantity'] = quantityController.text;
//     }
//     if (weightFromController.text.isNotEmpty) {
//       filterParams['weight_from'] = weightFromController.text;
//     }
//     if (weightToController.text.isNotEmpty) {
//       filterParams['weight_to'] = weightToController.text;
//     }

//     currentPage = 1;
//     await fetchProducts();
//     Navigator.pop(context);
//   }

//   Future<void> clearFilters() async {
//     filterParams.clear();

//     productCodeController.clear();
//     productNameController.clear();
//     bpCodeController.clear();
//     designCodeController.clear();
//     statusController.clear();
//     quantityController.clear();
//     weightFromController.clear();
//     weightToController.clear();

//     await fetchProducts();
//   }

//   void showFilterDialog() {
//     productCodeController.text = filterParams['product_code'] ?? '';
//     productNameController.text = filterParams['product_name'] ?? '';
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     designCodeController.text = filterParams['design_code'] ?? '';
//     statusController.text = filterParams['status'] ?? '';
//     quantityController.text = filterParams['quantity'] ?? '';
//     weightFromController.text = filterParams['weight_from'] ?? '';
//     weightToController.text = filterParams['weight_to'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Filter Products'),
//               content: Container(
//                 width: double.maxFinite,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       _buildFilterField(productCodeController, 'Product Code', Icons.code),
//                       _buildFilterField(productNameController, 'Product Name', Icons.shopping_bag),
//                       _buildFilterField(bpCodeController, 'BP Code', Icons.qr_code),
//                       _buildFilterField(designCodeController, 'Design Code', Icons.design_services),
//                       _buildFilterField(statusController, 'Status', Icons.info),
//                       _buildFilterField(quantityController, 'Quantity', Icons.numbers),
//                       _buildFilterField(weightFromController, 'Weight From', Icons.arrow_downward),
//                       _buildFilterField(weightToController, 'Weight To', Icons.arrow_upward),
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
//     await fetchProducts();
//   }

//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchProducts();
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
//       {'value': 'design_code', 'label': 'Design Code'},
//       {'value': 'quantity', 'label': 'Quantity'},
//       {'value': 'weight_from', 'label': 'Weight From'},
//       {'value': 'weight_to', 'label': 'Weight To'},
//       {'value': 'order_type', 'label': 'Order Type'},
//       {'value': 'status', 'label': 'Status'},
//       {'value': 'created_at', 'label': 'Created Date'},
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
//                       fetchProducts();
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
//       fetchProducts(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchProducts(url: prevUrl);
//     }
//   }

//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
//     await fetchProducts();
//   }

//   // Add Category Dialog
//   void showAddCategoryDialog() {
//     final TextEditingController nameController = TextEditingController();
//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add New Category'),
//         content: Form(
//           key: formKey,
//           child: TextFormField(
//             controller: nameController,
//             decoration: InputDecoration(
//               labelText: 'Category Name',
//               border: OutlineInputBorder(),
//               prefixIcon: Icon(Icons.category),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter category name';
//               }
//               return null;
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (formKey.currentState!.validate()) {
//                 await createCategory(nameController.text);
//                 Navigator.pop(context);
//               }
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Create Category
//   Future<void> createCategory(String name) async {
//     if (token == null) return;

//     try {
//       final response = await http.post(
//         Uri.parse(categoryApiUrl),
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({'name': name}),
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         await fetchCategories();
//         _showSnackBar('Category added successfully!');
//       } else {
//         print('Error: ${response.body}');
//         _showSnackBar('Failed to add category: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Error: $e');
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Add Subcategory Dialog
//   void showAddSubcategoryDialog(int categoryId) {
//     final TextEditingController nameController = TextEditingController();
//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add New Subcategory'),
//         content: Form(
//           key: formKey,
//           child: TextFormField(
//             controller: nameController,
//             decoration: InputDecoration(
//               labelText: 'Subcategory Name',
//               border: OutlineInputBorder(),
//               prefixIcon: Icon(Icons.category_outlined),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter subcategory name';
//               }
//               return null;
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (formKey.currentState!.validate()) {
//                 await createSubcategory(categoryId, nameController.text);
//                 Navigator.pop(context);
//               }
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Create Subcategory
//   Future<void> createSubcategory(int categoryId, String name) async {
//     if (token == null) return;

//     try {
//       final response = await http.post(
//         Uri.parse(subcategoryApiUrl),
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({
//           'name': name,
//           'category_name': categoryId,
//         }),
//       ).timeout(Duration(seconds: 10));

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         await fetchSubcategories(categoryId);
//         _showSnackBar('Subcategory added successfully!');
//       } else {
//         print('Error: ${response.body}');
//         _showSnackBar('Failed to add subcategory: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Error: $e');
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Create Product Methods
//   void showAddProductDialog() {
//     for (var field in requiredFields) {
//       if (!excludeFromCreate.contains(field) &&
//           !isFileField(field) &&
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }

//     // Reset selections
//     productImageFile = null;
//     productImageFileName = null;
//     selectedCreateBpCode = null;
//     selectedCreateCategoryId = null;
//     selectedCreateSubCategoryId = null;
//     selectedCreateType = null;
//     selectedCreateOrderType = null;
//     selectedCreateOpenClose = null;
//     selectedCreateHallmark = null;
//     selectedCreateRodium = null;
//     selectedCreateHook = null;
//     selectedCreateSize = null;
//     selectedCreateStone = null;
//     selectedCreateStatus = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Product'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildCreateTextField('product_code', 'Product Code', Icons.code, isRequired: true),
//                     _buildCreateTextField('product_name', 'Product Name', Icons.shopping_bag, isRequired: true),
                    
//                     // BP Code dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: buyerBpCodes,
//                       onChanged: (value) => setState(() => selectedCreateBpCode = value),
//                     ),

//                     // Category dropdown with Add button
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildCreateDropdownField(
//                             value: selectedCreateCategoryId != null 
//                                 ? categories.firstWhere(
//                                     (cat) => cat['id'] == selectedCreateCategoryId,
//                                     orElse: () => {'name': null},
//                                   )['name']
//                                 : null,
//                             label: 'Category',
//                             icon: Icons.category,
//                             items: categories.map((cat) => cat['name'].toString()).toList(),
//                             onChanged: (value) {
//                               if (value != null) {
//                                 final selectedCat = categories.firstWhere(
//                                   (cat) => cat['name'] == value,
//                                 );
//                                 setState(() {
//                                   selectedCreateCategoryId = selectedCat['id'];
//                                   selectedCreateSubCategoryId = null;
//                                 });
//                                 fetchSubcategories(selectedCat['id']);
//                               }
//                             },
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add_circle, color: Colors.green),
//                           onPressed: showAddCategoryDialog,
//                           tooltip: 'Add New Category',
//                         ),
//                       ],
//                     ),

//                     // Sub Category dropdown with Add button (only if category selected)
//                     if (selectedCreateCategoryId != null)
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _buildCreateDropdownField(
//                               value: selectedCreateSubCategoryId != null
//                                   ? (categorySubcategories[selectedCreateCategoryId] ?? [])
//                                       .firstWhere(
//                                         (sub) => sub['id'] == selectedCreateSubCategoryId,
//                                         orElse: () => {'name': null},
//                                       )['name']
//                                   : null,
//                               label: 'Sub Category',
//                               icon: Icons.category_outlined,
//                               items: (categorySubcategories[selectedCreateCategoryId] ?? [])
//                                   .map((sub) => sub['name'].toString())
//                                   .toList(),
//                               onChanged: (value) {
//                                 if (value != null) {
//                                   final subcatList = categorySubcategories[selectedCreateCategoryId] ?? [];
//                                   final selectedSub = subcatList.firstWhere(
//                                     (sub) => sub['name'] == value,
//                                   );
//                                   setState(() {
//                                     selectedCreateSubCategoryId = selectedSub['id'];
//                                   });
//                                 }
//                               },
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.add_circle, color: Colors.green),
//                             onPressed: () => showAddSubcategoryDialog(selectedCreateCategoryId!),
//                             tooltip: 'Add New Subcategory',
//                           ),
//                         ],
//                       ),

//                     // Type dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateType,
//                       label: 'Type',
//                       icon: Icons.type_specimen,
//                       items: typeOptions,
//                       onChanged: (value) => setState(() => selectedCreateType = value),
//                     ),

//                     _buildCreateTextField('quantity', 'Quantity', Icons.numbers, isRequired: true),
//                     _buildCreateTextField('weight_from', 'Weight From', Icons.arrow_downward),
//                     _buildCreateTextField('weight_to', 'Weight To', Icons.arrow_upward),

//                     // Order Type dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateOrderType,
//                       label: 'Order Type',
//                       icon: Icons.shopping_cart,
//                       items: orderTypeOptions,
//                       onChanged: (value) => setState(() => selectedCreateOrderType = value),
//                     ),

//                     // Open/Close dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateOpenClose,
//                       label: 'Open/Close',
//                       icon: Icons.lock_open,
//                       items: openCloseOptions,
//                       onChanged: (value) => setState(() => selectedCreateOpenClose = value),
//                     ),

//                     // Hallmark dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateHallmark,
//                       label: 'Hallmark',
//                       icon: Icons.verified,
//                       items: hallmarkOptions,
//                       onChanged: (value) => setState(() => selectedCreateHallmark = value),
//                     ),

//                     // Rodium dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateRodium,
//                       label: 'Rodium',
//                       icon: Icons.science,
//                       items: rodiumOptions,
//                       onChanged: (value) => setState(() => selectedCreateRodium = value),
//                     ),

//                     // Hook dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateHook,
//                       label: 'Hook',
//                       icon: Icons.attach_file,
//                       items: hookOptions,
//                       onChanged: (value) => setState(() => selectedCreateHook = value),
//                     ),

//                     // Size dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateSize,
//                       label: 'Size',
//                       icon: Icons.straighten,
//                       items: sizeOptions,
//                       onChanged: (value) => setState(() => selectedCreateSize = value),
//                     ),

//                     // Stone dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateStone,
//                       label: 'Stone',
//                       icon: Icons.diamond,
//                       items: stoneOptions,
//                       onChanged: (value) => setState(() => selectedCreateStone = value),
//                     ),

//                     _buildCreateTextField('enamel', 'Enamel', Icons.color_lens),
                    
//                     // Length field
//                     _buildCreateTextField('length', 'Length', Icons.height),

//                     // Design Code
//                     _buildCreateTextField('design_code', 'Design Code', Icons.design_services),

//                     // Relabel Code
//                     _buildCreateTextField('relabel_code', 'Relabel Code', Icons.tag),

//                     // Craftsman Notes
//                     _buildCreateTextField('narration_craftsman', 'Craftsman Notes', Icons.note, maxLines: 3),

//                     // Admin Notes
//                     _buildCreateTextField('narration_admin', 'Admin Notes', Icons.admin_panel_settings, maxLines: 3),

//                     // Notes
//                     _buildCreateTextField('notes', 'Notes', Icons.note_alt, maxLines: 3),

//                     // Status dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateStatus,
//                       label: 'Status',
//                       icon: Icons.info,
//                       items: statusOptions,
//                       onChanged: (value) => setState(() => selectedCreateStatus = value),
//                     ),

//                     _buildCreateFileField('product_image', 'Product Image', Icons.image, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   if (createControllers['product_code']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter product code', isError: true);
//                     return;
//                   }
//                   if (createControllers['product_name']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter product name', isError: true);
//                     return;
//                   }
//                   await createProduct();
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
//                     await pickImage();
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     productImageFileName ?? 'Select Image',
//                   ),
//                 ),
//               ),
//               if (productImageFileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       productImageFile = null;
//                       productImageFileName = null;
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> createProduct() async {
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

//       // Add dropdown selections
//       if (selectedCreateBpCode != null) {
//         final bpValue = selectedCreateBpCode!.split('-').first.trim();
//         request.fields['bp_code'] = bpValue;
//       }
//       if (selectedCreateCategoryId != null) {
//         request.fields['product_category'] = selectedCreateCategoryId!.toString();
//       }
//       if (selectedCreateSubCategoryId != null) {
//         request.fields['sub_category'] = selectedCreateSubCategoryId!.toString();
//       }
//       if (selectedCreateType != null) {
//         request.fields['type'] = selectedCreateType!;
//       }
//       if (selectedCreateOrderType != null) {
//         request.fields['order_type'] = selectedCreateOrderType!;
//       }
//       if (selectedCreateOpenClose != null) {
//         request.fields['open_close'] = selectedCreateOpenClose!;
//       }
//       if (selectedCreateHallmark != null) {
//         request.fields['hallmark'] = selectedCreateHallmark!;
//       }
//       if (selectedCreateRodium != null) {
//         request.fields['rodium'] = selectedCreateRodium!;
//       }
//       if (selectedCreateHook != null) {
//         request.fields['hook'] = selectedCreateHook!;
//       }
//       if (selectedCreateSize != null) {
//         request.fields['size'] = selectedCreateSize!;
//       }
//       if (selectedCreateStone != null) {
//         request.fields['stone'] = selectedCreateStone!;
//       }
//       if (selectedCreateStatus != null) {
//         request.fields['status'] = selectedCreateStatus!;
//       }

//       // Add image if selected
//       if (productImageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'product_image',
//             productImageFile!.path,
//             filename: productImageFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });

//         productImageFile = null;
//         productImageFileName = null;
//         selectedCreateBpCode = null;
//         selectedCreateCategoryId = null;
//         selectedCreateSubCategoryId = null;
//         selectedCreateType = null;
//         selectedCreateOrderType = null;
//         selectedCreateOpenClose = null;
//         selectedCreateHallmark = null;
//         selectedCreateRodium = null;
//         selectedCreateHook = null;
//         selectedCreateSize = null;
//         selectedCreateStone = null;
//         selectedCreateStatus = null;

//         await fetchProducts();
//         _showSnackBar('Product created successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to create product: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // Pick Image
//   Future<void> pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);

//     if (file != null) {
//       setState(() {
//         productImageFile = File(file.path);
//         productImageFileName = path.basename(file.path);
//       });
//     }
//   }

//   // View Product Details
//   void showProductDetailDialog() {
//     if (currentViewedProduct == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Product Details'),
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
//     dynamic value = currentViewedProduct?[field];

//     String displayValue = '-';
//     if (field == 'product_category' && value != null) {
//       displayValue = getCategoryNameById(int.tryParse(value.toString()));
//     } else if (field == 'sub_category' && value != null) {
//       displayValue = getSubcategoryNameById(int.tryParse(value.toString()));
//     } else if (field == 'bp_code' && value != null) {
//       // Try to find the BP code display value
//       final bpValue = buyerBpCodes.firstWhere(
//         (bp) => bp.startsWith(value.toString()),
//         orElse: () => value.toString(),
//       );
//       displayValue = bpValue;
//     } else if (field == 'created_by' && value != null) {
//       if (value is Map) {
//         displayValue = value['username']?.toString() ?? value['email']?.toString() ?? 'User';
//       } else {
//         displayValue = value.toString();
//       }
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
//             child: _buildDetailValue(field, value, displayValue),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailValue(String field, dynamic value, String displayValue) {
//     if (isFileField(field)) {
//       if (value != null && value.toString().isNotEmpty) {
//         return InkWell(
//           onTap: () => _showImageDialog(formatFieldName(field), value.toString()),
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
//                             'Personalize List Columns - Products',
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
//                                   {'key': 'product_code', 'label': 'Product Code', 'selected': true},
//                                   {'key': 'product_name', 'label': 'Product Name', 'selected': true},
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'product_category', 'label': 'Category', 'selected': true},
//                                   {'key': 'sub_category', 'label': 'Sub Category', 'selected': true},
//                                   {'key': 'type', 'label': 'Type', 'selected': true},
//                                   {'key': 'quantity', 'label': 'Quantity', 'selected': true},
//                                   {'key': 'order_type', 'label': 'Order Type', 'selected': true},
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
//                                 'Products - Field Selection',
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
//     if (products.isEmpty) {
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

//     return products.map((product) {
//       final id = product['id'];
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
//                         onPressed: () => fetchProductDetails(id),
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
//                         onPressed: () => showEditProductDialog(product),
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
//         String displayValue = getFieldValue(product, field['key']);

//         if (field['isFile'] == true && displayValue != '-') {
//           cells.add(
//             DataCell(
//               InkWell(
//                 onTap: () => _showImageDialog(field['label'], product[field['key']]?.toString() ?? ''),
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

//   // Edit Product Methods
//   void showEditProductDialog(Map<String, dynamic> product) {
//     editingProductId = product['id'];
//     editControllers = {};

//     for (var field in requiredFields) {
//       if (!excludeFromEdit.contains(field) && !isFileField(field)) {
//         editControllers![field] = TextEditingController(
//           text: product[field]?.toString() ?? '',
//         );
//       }
//     }

//     // Set dropdown values for edit
//     selectedEditBpCode = product['bp_code'];
    
//     final catId = product['product_category'];
//     if (catId != null) {
//       selectedEditCategoryId = int.tryParse(catId.toString());
//       if (selectedEditCategoryId != null) {
//         fetchSubcategories(selectedEditCategoryId!);
//       }
//     }
    
//     final subId = product['sub_category'];
//     if (subId != null) {
//       selectedEditSubCategoryId = int.tryParse(subId.toString());
//     }
    
//     selectedEditType = product['type'];
//     selectedEditOrderType = product['order_type'];
//     selectedEditOpenClose = product['open_close'];
//     selectedEditHallmark = product['hallmark'];
//     selectedEditRodium = product['rodium'];
//     selectedEditHook = product['hook'];
//     selectedEditSize = product['size'];
//     selectedEditStone = product['stone'];
//     selectedEditStatus = product['status'];

//     // Reset file selections
//     productImageFile = null;
//     productImageFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Edit Product'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildEditTextField('product_code', 'Product Code', Icons.code),
//                     _buildEditTextField('product_name', 'Product Name', Icons.shopping_bag),

//                     // BP Code dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: buyerBpCodes,
//                       onChanged: (value) => setState(() => selectedEditBpCode = value),
//                     ),

//                     // Category dropdown with Add button
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildEditDropdownField(
//                             value: selectedEditCategoryId != null 
//                                 ? categories.firstWhere(
//                                     (cat) => cat['id'] == selectedEditCategoryId,
//                                     orElse: () => {'name': null},
//                                   )['name']
//                                 : null,
//                             label: 'Category',
//                             icon: Icons.category,
//                             items: categories.map((cat) => cat['name'].toString()).toList(),
//                             onChanged: (value) {
//                               if (value != null) {
//                                 final selectedCat = categories.firstWhere(
//                                   (cat) => cat['name'] == value,
//                                 );
//                                 setState(() {
//                                   selectedEditCategoryId = selectedCat['id'];
//                                   selectedEditSubCategoryId = null;
//                                 });
//                                 fetchSubcategories(selectedCat['id']);
//                               }
//                             },
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add_circle, color: Colors.green),
//                           onPressed: showAddCategoryDialog,
//                           tooltip: 'Add New Category',
//                         ),
//                       ],
//                     ),

//                     // Sub Category dropdown with Add button (only if category selected)
//                     if (selectedEditCategoryId != null)
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _buildEditDropdownField(
//                               value: selectedEditSubCategoryId != null
//                                   ? (categorySubcategories[selectedEditCategoryId] ?? [])
//                                       .firstWhere(
//                                         (sub) => sub['id'] == selectedEditSubCategoryId,
//                                         orElse: () => {'name': null},
//                                       )['name']
//                                   : null,
//                               label: 'Sub Category',
//                               icon: Icons.category_outlined,
//                               items: (categorySubcategories[selectedEditCategoryId] ?? [])
//                                   .map((sub) => sub['name'].toString())
//                                   .toList(),
//                               onChanged: (value) {
//                                 if (value != null) {
//                                   final subcatList = categorySubcategories[selectedEditCategoryId] ?? [];
//                                   final selectedSub = subcatList.firstWhere(
//                                     (sub) => sub['name'] == value,
//                                   );
//                                   setState(() {
//                                     selectedEditSubCategoryId = selectedSub['id'];
//                                   });
//                                 }
//                               },
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.add_circle, color: Colors.green),
//                             onPressed: () => showAddSubcategoryDialog(selectedEditCategoryId!),
//                             tooltip: 'Add New Subcategory',
//                           ),
//                         ],
//                       ),

//                     // Type dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditType,
//                       label: 'Type',
//                       icon: Icons.type_specimen,
//                       items: typeOptions,
//                       onChanged: (value) => setState(() => selectedEditType = value),
//                     ),

//                     _buildEditTextField('quantity', 'Quantity', Icons.numbers),
//                     _buildEditTextField('weight_from', 'Weight From', Icons.arrow_downward),
//                     _buildEditTextField('weight_to', 'Weight To', Icons.arrow_upward),

//                     // Order Type dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditOrderType,
//                       label: 'Order Type',
//                       icon: Icons.shopping_cart,
//                       items: orderTypeOptions,
//                       onChanged: (value) => setState(() => selectedEditOrderType = value),
//                     ),

//                     // Open/Close dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditOpenClose,
//                       label: 'Open/Close',
//                       icon: Icons.lock_open,
//                       items: openCloseOptions,
//                       onChanged: (value) => setState(() => selectedEditOpenClose = value),
//                     ),

//                     // Hallmark dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditHallmark,
//                       label: 'Hallmark',
//                       icon: Icons.verified,
//                       items: hallmarkOptions,
//                       onChanged: (value) => setState(() => selectedEditHallmark = value),
//                     ),

//                     // Rodium dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditRodium,
//                       label: 'Rodium',
//                       icon: Icons.science,
//                       items: rodiumOptions,
//                       onChanged: (value) => setState(() => selectedEditRodium = value),
//                     ),

//                     // Hook dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditHook,
//                       label: 'Hook',
//                       icon: Icons.attach_file,
//                       items: hookOptions,
//                       onChanged: (value) => setState(() => selectedEditHook = value),
//                     ),

//                     // Size dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditSize,
//                       label: 'Size',
//                       icon: Icons.straighten,
//                       items: sizeOptions,
//                       onChanged: (value) => setState(() => selectedEditSize = value),
//                     ),

//                     // Stone dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditStone,
//                       label: 'Stone',
//                       icon: Icons.diamond,
//                       items: stoneOptions,
//                       onChanged: (value) => setState(() => selectedEditStone = value),
//                     ),

//                     _buildEditTextField('enamel', 'Enamel', Icons.color_lens),
//                     _buildEditTextField('length', 'Length', Icons.height),
//                     _buildEditTextField('design_code', 'Design Code', Icons.design_services),
//                     _buildEditTextField('relabel_code', 'Relabel Code', Icons.tag),
//                     _buildEditTextField('narration_craftsman', 'Craftsman Notes', Icons.note, maxLines: 3),
//                     _buildEditTextField('narration_admin', 'Admin Notes', Icons.admin_panel_settings, maxLines: 3),
//                     _buildEditTextField('notes', 'Notes', Icons.note_alt, maxLines: 3),

//                     // Status dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditStatus,
//                       label: 'Status',
//                       icon: Icons.info,
//                       items: statusOptions,
//                       onChanged: (value) => setState(() => selectedEditStatus = value),
//                     ),

//                     _buildEditFileField('product_image', 'Product Image', Icons.image, product, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await updateProduct(editingProductId!);
//                   Navigator.pop(context);
//                 },
//                 child: Text('Save'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   editControllers = null;
//                   editingProductId = null;
//                   productImageFile = null;
//                   productImageFileName = null;
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

//   Widget _buildEditFileField(String field, String label, IconData icon,
//       Map<String, dynamic> product, StateSetter setState) {
//     String? imageUrl = product[field];

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
//           if (imageUrl != null && imageUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () => _showImageDialog(label, imageUrl),
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       'View Existing Image',
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
//                     await pickImage();
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     productImageFileName ?? 'Select New Image',
//                   ),
//                 ),
//               ),
//               if (productImageFileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       productImageFile = null;
//                       productImageFileName = null;
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> updateProduct(int id) async {
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

//       // Add dropdown selections
//       if (selectedEditBpCode != null) {
//         final bpValue = selectedEditBpCode!.split('-').first.trim();
//         request.fields['bp_code'] = bpValue;
//       }
//       if (selectedEditCategoryId != null) {
//         request.fields['product_category'] = selectedEditCategoryId!.toString();
//       }
//       if (selectedEditSubCategoryId != null) {
//         request.fields['sub_category'] = selectedEditSubCategoryId!.toString();
//       }
//       if (selectedEditType != null) {
//         request.fields['type'] = selectedEditType!;
//       }
//       if (selectedEditOrderType != null) {
//         request.fields['order_type'] = selectedEditOrderType!;
//       }
//       if (selectedEditOpenClose != null) {
//         request.fields['open_close'] = selectedEditOpenClose!;
//       }
//       if (selectedEditHallmark != null) {
//         request.fields['hallmark'] = selectedEditHallmark!;
//       }
//       if (selectedEditRodium != null) {
//         request.fields['rodium'] = selectedEditRodium!;
//       }
//       if (selectedEditHook != null) {
//         request.fields['hook'] = selectedEditHook!;
//       }
//       if (selectedEditSize != null) {
//         request.fields['size'] = selectedEditSize!;
//       }
//       if (selectedEditStone != null) {
//         request.fields['stone'] = selectedEditStone!;
//       }
//       if (selectedEditStatus != null) {
//         request.fields['status'] = selectedEditStatus!;
//       }

//       // Add image if selected
//       if (productImageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'product_image',
//             productImageFile!.path,
//             filename: productImageFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         editControllers = null;
//         editingProductId = null;
//         productImageFile = null;
//         productImageFileName = null;
//         selectedEditBpCode = null;
//         selectedEditCategoryId = null;
//         selectedEditSubCategoryId = null;
//         selectedEditType = null;
//         selectedEditOrderType = null;
//         selectedEditOpenClose = null;
//         selectedEditHallmark = null;
//         selectedEditRodium = null;
//         selectedEditHook = null;
//         selectedEditSize = null;
//         selectedEditStone = null;
//         selectedEditStatus = null;

//         await fetchProducts();
//         _showSnackBar('Product updated successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to update product: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Products'),
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
//             onPressed: () => fetchProducts(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddProductDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add Product'),
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


// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

// class ProductPage extends StatefulWidget {
//   @override
//   _ProductPageState createState() => _ProductPageState();
// }

// class _ProductPageState extends State<ProductPage> {
//   // Data lists
//   List<Map<String, dynamic>> products = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   Map<String, dynamic>? currentViewedProduct;

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/Products/products/list/';
//   final String filterApiUrl = 'http://127.0.0.1:8000/Products/products/filter/';
//   final String createApiUrl = 'http://127.0.0.1:8000/Products/products/create/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/Products/products/detail/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/Products/products/update/';
  
//   // New API Endpoints
//   final String buyerApiUrl = 'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/';
//   final String categoryApiUrl = 'http://127.0.0.1:8000/Products/products/categories/';
//   final String subcategoryApiUrl = 'http://127.0.0.1:8000/Products/products/subcategories/';
//   final String categoryDetailApiUrl = 'http://127.0.0.1:8000/Products/products/categories/detail/';

//   // Data for dropdowns
//   List<String> buyerBpCodes = [];
//   List<Map<String, dynamic>> categories = [];
//   List<Map<String, dynamic>> subcategories = [];
//   Map<int, List<Map<String, dynamic>>> categorySubcategories = {};

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
//     {'key': 'product_code', 'label': 'Product Code', 'selected': true, 'order': 0},
//     {'key': 'product_name', 'label': 'Product Name', 'selected': true, 'order': 1},
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 2},
//     {'key': 'product_category', 'label': 'Category', 'selected': true, 'order': 3},
//     {'key': 'sub_category', 'label': 'Sub Category', 'selected': true, 'order': 4},
//     {'key': 'type', 'label': 'Type', 'selected': true, 'order': 5},
//     {'key': 'quantity', 'label': 'Quantity', 'selected': true, 'order': 6},
//     {'key': 'weight_from', 'label': 'Weight From', 'selected': false, 'order': 7},
//     {'key': 'weight_to', 'label': 'Weight To', 'selected': false, 'order': 8},
//     {'key': 'order_type', 'label': 'Order Type', 'selected': true, 'order': 9},
//     {'key': 'open_close', 'label': 'Open/Close', 'selected': false, 'order': 10},
//     {'key': 'hallmark', 'label': 'Hallmark', 'selected': true, 'order': 11},
//     {'key': 'rodium', 'label': 'Rodium', 'selected': false, 'order': 12},
//     {'key': 'hook', 'label': 'Hook', 'selected': false, 'order': 13},
//     {'key': 'size', 'label': 'Size', 'selected': true, 'order': 14},
//     {'key': 'stone', 'label': 'Stone', 'selected': true, 'order': 15},
//     {'key': 'enamel', 'label': 'Enamel', 'selected': false, 'order': 16},
//     {'key': 'length', 'label': 'Length', 'selected': true, 'order': 17},
//     {'key': 'relabel_code', 'label': 'Relabel Code', 'selected': false, 'order': 18},
//     {'key': 'product_image', 'label': 'Product Image', 'selected': false, 'isFile': true, 'order': 19},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 20},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 21},
//   ];

//   // Filter controllers
//   final TextEditingController productCodeController = TextEditingController();
//   final TextEditingController productNameController = TextEditingController();
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController categoryController = TextEditingController();
//   final TextEditingController subCategoryController = TextEditingController();
//   final TextEditingController typeController = TextEditingController();
//   final TextEditingController quantityController = TextEditingController();
//   final TextEditingController weightFromController = TextEditingController();
//   final TextEditingController weightToController = TextEditingController();

//   // Create controllers
//   final Map<String, TextEditingController> createControllers = {};

//   // Dropdown values for create
//   String? selectedCreateBpCode;
//   int? selectedCreateCategoryId;
//   int? selectedCreateSubCategoryId;
//   String? selectedCreateType;
//   String? selectedCreateOrderType;
//   String? selectedCreateOpenClose;
//   String? selectedCreateHallmark;
//   String? selectedCreateRodium;
//   String? selectedCreateHook;
//   String? selectedCreateSize;
//   String? selectedCreateStone;
//   String? selectedCreateLength;

//   // Edit controllers
//   Map<String, TextEditingController>? editControllers;
//   int? editingProductId;

//   // Dropdown values for edit
//   String? selectedEditBpCode;
//   int? selectedEditCategoryId;
//   int? selectedEditSubCategoryId;
//   String? selectedEditType;
//   String? selectedEditOrderType;
//   String? selectedEditOpenClose;
//   String? selectedEditHallmark;
//   String? selectedEditRodium;
//   String? selectedEditHook;
//   String? selectedEditSize;
//   String? selectedEditStone;
//   String? selectedEditLength;

//   // File uploads
//   File? productImageFile;
//   String? productImageFileName;

//   // Options for dropdowns (static)
//   final List<String> typeOptions = ['New', 'Used', 'Antique', 'Custom'];
//   final List<String> orderTypeOptions = ['Standard', 'Express', 'Priority'];
//   final List<String> openCloseOptions = ['Open', 'Close'];
//   final List<String> hallmarkOptions = ['916', '750', '585', '375', '999'];
//   final List<String> rodiumOptions = ['Yes', 'No'];
//   final List<String> hookOptions = ['Yes', 'No'];
//   final List<String> sizeOptions = ['Small', 'Medium', 'Large', 'XL', 'XXL'];
//   final List<String> stoneOptions = ['Diamond', 'Ruby', 'Emerald', 'Sapphire', 'None'];
//   final List<String> lengthOptions = ['16"', '18"', '20"', '22"', '24"'];

//   // Required fields for product
//   final List<String> requiredFields = [
//     'product_code',
//     'product_name',
//     'bp_code',
//     'product_category',
//     'sub_category',
//     'type',
//     'quantity',
//     'weight_from',
//     'weight_to',
//     'order_type',
//     'open_close',
//     'hallmark',
//     'rodium',
//     'hook',
//     'size',
//     'stone',
//     'enamel',
//     'length',
//     'relabel_code',
//     'product_image',
//     'created_at',
//     'updated_at'
//   ];

//   // Fields to exclude from certain operations
//   final List<String> excludeFromCreate = ['created_at', 'updated_at'];
//   final List<String> excludeFromEdit = ['created_at', 'updated_at'];
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
//     categoryController.dispose();
//     subCategoryController.dispose();
//     typeController.dispose();
//     quantityController.dispose();
//     weightFromController.dispose();
//     weightToController.dispose();

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
//     String? savedSelections = prefs.getString('product_fields');
//     String? savedOrder = prefs.getString('product_field_order');

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

//     await prefs.setString('product_fields', json.encode(selections));
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('product_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     setState(() {
//       compactRows = prefs.getBool('product_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('product_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('product_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('product_enable_view') ?? true;
//       enableEdit = prefs.getBool('product_enable_edit') ?? true;
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

//     await prefs.setBool('product_compact_rows', compactRows);
//     await prefs.setBool('product_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('product_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('product_enable_view', enableView);
//     await prefs.setBool('product_enable_edit', enableEdit);
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
//       await Future.wait([
//         fetchBuyerBpCodes(),
//         fetchCategories(),
//       ]);
//       await fetchProducts();
//     } else {
//       setState(() => isLoading = false);
//       print('⚠️ No token found. Please login again.');
//     }
//   }

//   // Fetch Buyer BP Codes
//   Future<void> fetchBuyerBpCodes() async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse(buyerApiUrl),
//         headers: {'Authorization': 'Token $token'},
//       );

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
//           uniqueBpCodes.add(displayValue);
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

//   // Fetch Categories
//   Future<void> fetchCategories() async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse(categoryApiUrl),
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         if (data is Map && data.containsKey('results')) {
//           setState(() {
//             categories = List<Map<String, dynamic>>.from(data['results'] ?? []);
//           });
//         } else if (data is List) {
//           setState(() {
//             categories = List<Map<String, dynamic>>.from(data);
//           });
//         }
//       } else {
//         print('Failed to fetch categories: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching categories: $e');
//     }
//   }

//   // Fetch Subcategories for a specific category
//   Future<void> fetchSubcategories(int categoryId) async {
//     if (token == null) return;

//     try {
//       final response = await http.get(
//         Uri.parse('$categoryDetailApiUrl$categoryId/'),
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         List<Map<String, dynamic>> subcatList = [];
//         if (data is Map && data.containsKey('results')) {
//           subcatList = List<Map<String, dynamic>>.from(data['results'] ?? []);
//         } else if (data is List) {
//           subcatList = List<Map<String, dynamic>>.from(data);
//         }

//         setState(() {
//           categorySubcategories[categoryId] = subcatList;
//         });
//       } else {
//         print('Failed to fetch subcategories: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching subcategories: $e');
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
//   String getFieldValue(Map<String, dynamic> product, String key) {
//     final value = product[key];

//     if (value == null) return '-';

//     if (value is bool) {
//       return value.toString();
//     }

//     return value.toString();
//   }

//   // Get category name by ID
//   String getCategoryNameById(int? id) {
//     if (id == null) return '-';
//     final category = categories.firstWhere(
//       (cat) => cat['id'] == id,
//       orElse: () => {'name': 'Unknown'},
//     );
//     return category['name'] ?? 'Unknown';
//   }

//   // Get subcategory name by ID
//   String getSubcategoryNameById(int? id) {
//     if (id == null) return '-';
//     for (var entry in categorySubcategories.entries) {
//       final subcat = entry.value.firstWhere(
//         (sub) => sub['id'] == id,
//         orElse: () => {'name': null},
//       );
//       if (subcat['name'] != null) return subcat['name'];
//     }
//     return 'Unknown';
//   }

//   // API Request Building
//   String buildRequestUrl({String? baseUrl}) {
//     if (filterParams.isEmpty && sortBy == null) {
//       return listApiUrl;
//     }
    
//     String url = filterApiUrl;
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

//     Uri uri = Uri.parse(url);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Fetch Products
//   Future<void> fetchProducts({String? url}) async {
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
        
//         List<Map<String, dynamic>> results = [];
        
//         if (data is List) {
//           results = List<Map<String, dynamic>>.from(data);
//           setState(() {
//             products = results;
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
//             products = results;
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
//             products = [];
//             isLoading = false;
//           });
//         }
//       } else {
//         print('Error: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch products: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Fetch Single Product Details
//   Future<void> fetchProductDetails(int id) async {
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
//           currentViewedProduct = data;
//           isLoading = false;
//         });
//         showProductDetailDialog();
//       } else {
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch product details', isError: true);
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
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
//     if (categoryController.text.isNotEmpty) {
//       filterParams['product_category'] = categoryController.text;
//     }
//     if (subCategoryController.text.isNotEmpty) {
//       filterParams['sub_category'] = subCategoryController.text;
//     }
//     if (typeController.text.isNotEmpty) {
//       filterParams['type'] = typeController.text;
//     }
//     if (quantityController.text.isNotEmpty) {
//       filterParams['quantity'] = quantityController.text;
//     }
//     if (weightFromController.text.isNotEmpty) {
//       filterParams['weight_from'] = weightFromController.text;
//     }
//     if (weightToController.text.isNotEmpty) {
//       filterParams['weight_to'] = weightToController.text;
//     }

//     currentPage = 1;
//     await fetchProducts();
//     Navigator.pop(context);
//   }

//   Future<void> clearFilters() async {
//     filterParams.clear();

//     productCodeController.clear();
//     productNameController.clear();
//     bpCodeController.clear();
//     categoryController.clear();
//     subCategoryController.clear();
//     typeController.clear();
//     quantityController.clear();
//     weightFromController.clear();
//     weightToController.clear();

//     await fetchProducts();
//   }

//   void showFilterDialog() {
//     productCodeController.text = filterParams['product_code'] ?? '';
//     productNameController.text = filterParams['product_name'] ?? '';
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     categoryController.text = filterParams['product_category'] ?? '';
//     subCategoryController.text = filterParams['sub_category'] ?? '';
//     typeController.text = filterParams['type'] ?? '';
//     quantityController.text = filterParams['quantity'] ?? '';
//     weightFromController.text = filterParams['weight_from'] ?? '';
//     weightToController.text = filterParams['weight_to'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Filter Products'),
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
//                       _buildFilterField(typeController, 'Type', Icons.type_specimen),
//                       _buildFilterField(quantityController, 'Quantity', Icons.numbers),
//                       _buildFilterField(weightFromController, 'Weight From', Icons.arrow_downward),
//                       _buildFilterField(weightToController, 'Weight To', Icons.arrow_upward),
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
//     await fetchProducts();
//   }

//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchProducts();
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
//       {'value': 'quantity', 'label': 'Quantity'},
//       {'value': 'weight_from', 'label': 'Weight From'},
//       {'value': 'weight_to', 'label': 'Weight To'},
//       {'value': 'order_type', 'label': 'Order Type'},
//       {'value': 'hallmark', 'label': 'Hallmark'},
//       {'value': 'size', 'label': 'Size'},
//       {'value': 'stone', 'label': 'Stone'},
//       {'value': 'length', 'label': 'Length'},
//       {'value': 'created_at', 'label': 'Created Date'},
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
//                       fetchProducts();
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
//       fetchProducts(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchProducts(url: prevUrl);
//     }
//   }

//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
//     await fetchProducts();
//   }

//   // Add Category Dialog
//   void showAddCategoryDialog() {
//     final TextEditingController nameController = TextEditingController();
//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add New Category'),
//         content: Form(
//           key: formKey,
//           child: TextFormField(
//             controller: nameController,
//             decoration: InputDecoration(
//               labelText: 'Category Name',
//               border: OutlineInputBorder(),
//               prefixIcon: Icon(Icons.category),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter category name';
//               }
//               return null;
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (formKey.currentState!.validate()) {
//                 await createCategory(nameController.text);
//                 Navigator.pop(context);
//               }
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Create Category
//   Future<void> createCategory(String name) async {
//     if (token == null) return;

//     try {
//       final response = await http.post(
//         Uri.parse(categoryApiUrl),
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({'name': name}),
//       );

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         await fetchCategories();
//         _showSnackBar('Category added successfully!');
//       } else {
//         print('Error: ${response.body}');
//         _showSnackBar('Failed to add category', isError: true);
//       }
//     } catch (e) {
//       print('Error: $e');
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Add Subcategory Dialog
//   void showAddSubcategoryDialog(int categoryId) {
//     final TextEditingController nameController = TextEditingController();
//     final formKey = GlobalKey<FormState>();

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Add New Subcategory'),
//         content: Form(
//           key: formKey,
//           child: TextFormField(
//             controller: nameController,
//             decoration: InputDecoration(
//               labelText: 'Subcategory Name',
//               border: OutlineInputBorder(),
//               prefixIcon: Icon(Icons.category_outlined),
//             ),
//             validator: (value) {
//               if (value == null || value.isEmpty) {
//                 return 'Please enter subcategory name';
//               }
//               return null;
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               if (formKey.currentState!.validate()) {
//                 await createSubcategory(categoryId, nameController.text);
//                 Navigator.pop(context);
//               }
//             },
//             child: Text('Add'),
//           ),
//         ],
//       ),
//     );
//   }

//   // Create Subcategory
//   Future<void> createSubcategory(int categoryId, String name) async {
//     if (token == null) return;

//     try {
//       final response = await http.post(
//         Uri.parse(subcategoryApiUrl),
//         headers: {
//           'Authorization': 'Token $token',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode({
//           'name': name,
//           'category': categoryId,
//         }),
//       );

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         await fetchSubcategories(categoryId);
//         _showSnackBar('Subcategory added successfully!');
//       } else {
//         print('Error: ${response.body}');
//         _showSnackBar('Failed to add subcategory', isError: true);
//       }
//     } catch (e) {
//       print('Error: $e');
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Create Product Methods
//   void showAddProductDialog() {
//     for (var field in requiredFields) {
//       if (!excludeFromCreate.contains(field) &&
//           !isFileField(field) &&
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }

//     // Reset selections
//     productImageFile = null;
//     productImageFileName = null;
//     selectedCreateBpCode = null;
//     selectedCreateCategoryId = null;
//     selectedCreateSubCategoryId = null;
//     selectedCreateType = null;
//     selectedCreateOrderType = null;
//     selectedCreateOpenClose = null;
//     selectedCreateHallmark = null;
//     selectedCreateRodium = null;
//     selectedCreateHook = null;
//     selectedCreateSize = null;
//     selectedCreateStone = null;
//     selectedCreateLength = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Product'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildCreateTextField('product_code', 'Product Code', Icons.code, isRequired: true),
//                     _buildCreateTextField('product_name', 'Product Name', Icons.shopping_bag, isRequired: true),
                    
//                     // BP Code dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: buyerBpCodes,
//                       onChanged: (value) => setState(() => selectedCreateBpCode = value),
//                     ),

//                     // Category dropdown with Add button
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildCreateDropdownField(
//                             value: selectedCreateCategoryId?.toString(),
//                             label: 'Category',
//                             icon: Icons.category,
//                             items: categories.map((cat) => cat['name'].toString()).toList(),
//                             onChanged: (value) {
//                               if (value != null) {
//                                 final selectedCat = categories.firstWhere(
//                                   (cat) => cat['name'] == value,
//                                 );
//                                 setState(() {
//                                   selectedCreateCategoryId = selectedCat['id'];
//                                   selectedCreateSubCategoryId = null;
//                                 });
//                                 fetchSubcategories(selectedCat['id']);
//                               }
//                             },
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add_circle, color: Colors.green),
//                           onPressed: showAddCategoryDialog,
//                           tooltip: 'Add New Category',
//                         ),
//                       ],
//                     ),

//                     // Sub Category dropdown with Add button (only if category selected)
//                     if (selectedCreateCategoryId != null)
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _buildCreateDropdownField(
//                               value: selectedCreateSubCategoryId?.toString(),
//                               label: 'Sub Category',
//                               icon: Icons.category_outlined,
//                               items: (categorySubcategories[selectedCreateCategoryId] ?? [])
//                                   .map((sub) => sub['name'].toString())
//                                   .toList(),
//                               onChanged: (value) {
//                                 if (value != null) {
//                                   final subcatList = categorySubcategories[selectedCreateCategoryId] ?? [];
//                                   final selectedSub = subcatList.firstWhere(
//                                     (sub) => sub['name'] == value,
//                                   );
//                                   setState(() {
//                                     selectedCreateSubCategoryId = selectedSub['id'];
//                                   });
//                                 }
//                               },
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.add_circle, color: Colors.green),
//                             onPressed: () => showAddSubcategoryDialog(selectedCreateCategoryId!),
//                             tooltip: 'Add New Subcategory',
//                           ),
//                         ],
//                       ),

//                     // Type dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateType,
//                       label: 'Type',
//                       icon: Icons.type_specimen,
//                       items: typeOptions,
//                       onChanged: (value) => setState(() => selectedCreateType = value),
//                     ),

//                     _buildCreateTextField('quantity', 'Quantity', Icons.numbers, isRequired: true),
//                     _buildCreateTextField('weight_from', 'Weight From', Icons.arrow_downward),
//                     _buildCreateTextField('weight_to', 'Weight To', Icons.arrow_upward),

//                     // Order Type dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateOrderType,
//                       label: 'Order Type',
//                       icon: Icons.shopping_cart,
//                       items: orderTypeOptions,
//                       onChanged: (value) => setState(() => selectedCreateOrderType = value),
//                     ),

//                     // Open/Close dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateOpenClose,
//                       label: 'Open/Close',
//                       icon: Icons.lock_open,
//                       items: openCloseOptions,
//                       onChanged: (value) => setState(() => selectedCreateOpenClose = value),
//                     ),

//                     // Hallmark dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateHallmark,
//                       label: 'Hallmark',
//                       icon: Icons.verified,
//                       items: hallmarkOptions,
//                       onChanged: (value) => setState(() => selectedCreateHallmark = value),
//                     ),

//                     // Rodium dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateRodium,
//                       label: 'Rodium',
//                       icon: Icons.science,
//                       items: rodiumOptions,
//                       onChanged: (value) => setState(() => selectedCreateRodium = value),
//                     ),

//                     // Hook dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateHook,
//                       label: 'Hook',
//                       icon: Icons.attach_file,
//                       items: hookOptions,
//                       onChanged: (value) => setState(() => selectedCreateHook = value),
//                     ),

//                     // Size dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateSize,
//                       label: 'Size',
//                       icon: Icons.straighten,
//                       items: sizeOptions,
//                       onChanged: (value) => setState(() => selectedCreateSize = value),
//                     ),

//                     // Stone dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateStone,
//                       label: 'Stone',
//                       icon: Icons.diamond,
//                       items: stoneOptions,
//                       onChanged: (value) => setState(() => selectedCreateStone = value),
//                     ),

//                     _buildCreateTextField('enamel', 'Enamel', Icons.color_lens),
                    
//                     // Length dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateLength,
//                       label: 'Length',
//                       icon: Icons.height,
//                       items: lengthOptions,
//                       onChanged: (value) => setState(() => selectedCreateLength = value),
//                     ),

//                     _buildCreateTextField('relabel_code', 'Relabel Code', Icons.tag),

//                     _buildCreateFileField('product_image', 'Product Image', Icons.image, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   if (createControllers['product_code']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter product code', isError: true);
//                     return;
//                   }
//                   if (createControllers['product_name']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter product name', isError: true);
//                     return;
//                   }
//                   await createProduct();
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
//       {bool isRequired = false}) {
//     if (!createControllers.containsKey(field)) {
//       createControllers[field] = TextEditingController();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: createControllers[field],
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
//                     await pickImage();
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     productImageFileName ?? 'Select Image',
//                   ),
//                 ),
//               ),
//               if (productImageFileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       productImageFile = null;
//                       productImageFileName = null;
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> createProduct() async {
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

//       // Add dropdown selections
//       if (selectedCreateBpCode != null) {
//         // Extract just the BP code part before the dash
//         final bpValue = selectedCreateBpCode!.split('-').first.trim();
//         request.fields['bp_code'] = bpValue;
//       }
//       if (selectedCreateCategoryId != null) {
//         request.fields['product_category'] = selectedCreateCategoryId!.toString();
//       }
//       if (selectedCreateSubCategoryId != null) {
//         request.fields['sub_category'] = selectedCreateSubCategoryId!.toString();
//       }
//       if (selectedCreateType != null) {
//         request.fields['type'] = selectedCreateType!;
//       }
//       if (selectedCreateOrderType != null) {
//         request.fields['order_type'] = selectedCreateOrderType!;
//       }
//       if (selectedCreateOpenClose != null) {
//         request.fields['open_close'] = selectedCreateOpenClose!;
//       }
//       if (selectedCreateHallmark != null) {
//         request.fields['hallmark'] = selectedCreateHallmark!;
//       }
//       if (selectedCreateRodium != null) {
//         request.fields['rodium'] = selectedCreateRodium!;
//       }
//       if (selectedCreateHook != null) {
//         request.fields['hook'] = selectedCreateHook!;
//       }
//       if (selectedCreateSize != null) {
//         request.fields['size'] = selectedCreateSize!;
//       }
//       if (selectedCreateStone != null) {
//         request.fields['stone'] = selectedCreateStone!;
//       }
//       if (selectedCreateLength != null) {
//         request.fields['length'] = selectedCreateLength!;
//       }

//       // Add image if selected
//       if (productImageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'product_image',
//             productImageFile!.path,
//             filename: productImageFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });

//         productImageFile = null;
//         productImageFileName = null;
//         selectedCreateBpCode = null;
//         selectedCreateCategoryId = null;
//         selectedCreateSubCategoryId = null;
//         selectedCreateType = null;
//         selectedCreateOrderType = null;
//         selectedCreateOpenClose = null;
//         selectedCreateHallmark = null;
//         selectedCreateRodium = null;
//         selectedCreateHook = null;
//         selectedCreateSize = null;
//         selectedCreateStone = null;
//         selectedCreateLength = null;

//         await fetchProducts();
//         _showSnackBar('Product created successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to create product: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // Pick Image
//   Future<void> pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);

//     if (file != null) {
//       setState(() {
//         productImageFile = File(file.path);
//         productImageFileName = path.basename(file.path);
//       });
//     }
//   }

//   // View Product Details
//   void showProductDetailDialog() {
//     if (currentViewedProduct == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Product Details'),
//         content: Container(
//           width: double.maxFinite,
//           constraints: BoxConstraints(
//             maxHeight: MediaQuery.of context).size.height * 0.7,
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
//     dynamic value = currentViewedProduct?[field];

//     String displayValue = '-';
//     if (field == 'product_category' && value != null) {
//       displayValue = getCategoryNameById(int.tryParse(value.toString()));
//     } else if (field == 'sub_category' && value != null) {
//       displayValue = getSubcategoryNameById(int.tryParse(value.toString()));
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
//             child: _buildDetailValue(field, value, displayValue),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailValue(String field, dynamic value, String displayValue) {
//     if (isFileField(field)) {
//       if (value != null && value.toString().isNotEmpty) {
//         return InkWell(
//           onTap: () => _showImageDialog(formatFieldName(field), value.toString()),
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
//                             'Personalize List Columns - Products',
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
//                                   {'key': 'product_code', 'label': 'Product Code', 'selected': true},
//                                   {'key': 'product_name', 'label': 'Product Name', 'selected': true},
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'product_category', 'label': 'Category', 'selected': true},
//                                   {'key': 'sub_category', 'label': 'Sub Category', 'selected': true},
//                                   {'key': 'type', 'label': 'Type', 'selected': true},
//                                   {'key': 'quantity', 'label': 'Quantity', 'selected': true},
//                                   {'key': 'order_type', 'label': 'Order Type', 'selected': true},
//                                   {'key': 'hallmark', 'label': 'Hallmark', 'selected': true},
//                                   {'key': 'size', 'label': 'Size', 'selected': true},
//                                   {'key': 'stone', 'label': 'Stone', 'selected': true},
//                                   {'key': 'length', 'label': 'Length', 'selected': true},
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
//                                 'Products - Field Selection',
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
//     if (products.isEmpty) {
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

//     return products.map((product) {
//       final id = product['id'];
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
//                         onPressed: () => fetchProductDetails(id),
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
//                         onPressed: () => showEditProductDialog(product),
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
//         String displayValue = getFieldValue(product, field['key']);

//         // Handle special fields
//         if (field['key'] == 'product_category') {
//           final catId = product['product_category'];
//           displayValue = getCategoryNameById(catId != null ? int.tryParse(catId.toString()) : null);
//         } else if (field['key'] == 'sub_category') {
//           final subId = product['sub_category'];
//           displayValue = getSubcategoryNameById(subId != null ? int.tryParse(subId.toString()) : null);
//         }

//         if (field['isFile'] == true && displayValue != '-') {
//           cells.add(
//             DataCell(
//               InkWell(
//                 onTap: () => _showImageDialog(field['label'], product[field['key']].toString()),
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

//   // Edit Product Methods
//   void showEditProductDialog(Map<String, dynamic> product) {
//     editingProductId = product['id'];
//     editControllers = {};

//     for (var field in requiredFields) {
//       if (!excludeFromEdit.contains(field) && !isFileField(field)) {
//         editControllers![field] = TextEditingController(
//           text: product[field]?.toString() ?? '',
//         );
//       }
//     }

//     // Set dropdown values for edit
//     selectedEditBpCode = product['bp_code'];
    
//     final catId = product['product_category'];
//     if (catId != null) {
//       selectedEditCategoryId = int.tryParse(catId.toString());
//       if (selectedEditCategoryId != null) {
//         fetchSubcategories(selectedEditCategoryId!);
//       }
//     }
    
//     final subId = product['sub_category'];
//     if (subId != null) {
//       selectedEditSubCategoryId = int.tryParse(subId.toString());
//     }
    
//     selectedEditType = product['type'];
//     selectedEditOrderType = product['order_type'];
//     selectedEditOpenClose = product['open_close'];
//     selectedEditHallmark = product['hallmark'];
//     selectedEditRodium = product['rodium'];
//     selectedEditHook = product['hook'];
//     selectedEditSize = product['size'];
//     selectedEditStone = product['stone'];
//     selectedEditLength = product['length'];

//     // Reset file selections
//     productImageFile = null;
//     productImageFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Edit Product'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildEditTextField('product_code', 'Product Code', Icons.code),
//                     _buildEditTextField('product_name', 'Product Name', Icons.shopping_bag),

//                     // BP Code dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: buyerBpCodes,
//                       onChanged: (value) => setState(() => selectedEditBpCode = value),
//                     ),

//                     // Category dropdown with Add button
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _buildEditDropdownField(
//                             value: selectedEditCategoryId != null 
//                                 ? categories.firstWhere(
//                                     (cat) => cat['id'] == selectedEditCategoryId,
//                                     orElse: () => {'name': null},
//                                   )['name']
//                                 : null,
//                             label: 'Category',
//                             icon: Icons.category,
//                             items: categories.map((cat) => cat['name'].toString()).toList(),
//                             onChanged: (value) {
//                               if (value != null) {
//                                 final selectedCat = categories.firstWhere(
//                                   (cat) => cat['name'] == value,
//                                 );
//                                 setState(() {
//                                   selectedEditCategoryId = selectedCat['id'];
//                                   selectedEditSubCategoryId = null;
//                                 });
//                                 fetchSubcategories(selectedCat['id']);
//                               }
//                             },
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.add_circle, color: Colors.green),
//                           onPressed: showAddCategoryDialog,
//                           tooltip: 'Add New Category',
//                         ),
//                       ],
//                     ),

//                     // Sub Category dropdown with Add button (only if category selected)
//                     if (selectedEditCategoryId != null)
//                       Row(
//                         children: [
//                           Expanded(
//                             child: _buildEditDropdownField(
//                               value: selectedEditSubCategoryId != null
//                                   ? (categorySubcategories[selectedEditCategoryId] ?? [])
//                                       .firstWhere(
//                                         (sub) => sub['id'] == selectedEditSubCategoryId,
//                                         orElse: () => {'name': null},
//                                       )['name']
//                                   : null,
//                               label: 'Sub Category',
//                               icon: Icons.category_outlined,
//                               items: (categorySubcategories[selectedEditCategoryId] ?? [])
//                                   .map((sub) => sub['name'].toString())
//                                   .toList(),
//                               onChanged: (value) {
//                                 if (value != null) {
//                                   final subcatList = categorySubcategories[selectedEditCategoryId] ?? [];
//                                   final selectedSub = subcatList.firstWhere(
//                                     (sub) => sub['name'] == value,
//                                   );
//                                   setState(() {
//                                     selectedEditSubCategoryId = selectedSub['id'];
//                                   });
//                                 }
//                               },
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.add_circle, color: Colors.green),
//                             onPressed: () => showAddSubcategoryDialog(selectedEditCategoryId!),
//                             tooltip: 'Add New Subcategory',
//                           ),
//                         ],
//                       ),

//                     // Type dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditType,
//                       label: 'Type',
//                       icon: Icons.type_specimen,
//                       items: typeOptions,
//                       onChanged: (value) => setState(() => selectedEditType = value),
//                     ),

//                     _buildEditTextField('quantity', 'Quantity', Icons.numbers),
//                     _buildEditTextField('weight_from', 'Weight From', Icons.arrow_downward),
//                     _buildEditTextField('weight_to', 'Weight To', Icons.arrow_upward),

//                     // Order Type dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditOrderType,
//                       label: 'Order Type',
//                       icon: Icons.shopping_cart,
//                       items: orderTypeOptions,
//                       onChanged: (value) => setState(() => selectedEditOrderType = value),
//                     ),

//                     // Open/Close dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditOpenClose,
//                       label: 'Open/Close',
//                       icon: Icons.lock_open,
//                       items: openCloseOptions,
//                       onChanged: (value) => setState(() => selectedEditOpenClose = value),
//                     ),

//                     // Hallmark dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditHallmark,
//                       label: 'Hallmark',
//                       icon: Icons.verified,
//                       items: hallmarkOptions,
//                       onChanged: (value) => setState(() => selectedEditHallmark = value),
//                     ),

//                     // Rodium dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditRodium,
//                       label: 'Rodium',
//                       icon: Icons.science,
//                       items: rodiumOptions,
//                       onChanged: (value) => setState(() => selectedEditRodium = value),
//                     ),

//                     // Hook dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditHook,
//                       label: 'Hook',
//                       icon: Icons.attach_file,
//                       items: hookOptions,
//                       onChanged: (value) => setState(() => selectedEditHook = value),
//                     ),

//                     // Size dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditSize,
//                       label: 'Size',
//                       icon: Icons.straighten,
//                       items: sizeOptions,
//                       onChanged: (value) => setState(() => selectedEditSize = value),
//                     ),

//                     // Stone dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditStone,
//                       label: 'Stone',
//                       icon: Icons.diamond,
//                       items: stoneOptions,
//                       onChanged: (value) => setState(() => selectedEditStone = value),
//                     ),

//                     _buildEditTextField('enamel', 'Enamel', Icons.color_lens),

//                     // Length dropdown
//                     _buildEditDropdownField(
//                       value: selectedEditLength,
//                       label: 'Length',
//                       icon: Icons.height,
//                       items: lengthOptions,
//                       onChanged: (value) => setState(() => selectedEditLength = value),
//                     ),

//                     _buildEditTextField('relabel_code', 'Relabel Code', Icons.tag),

//                     _buildEditFileField('product_image', 'Product Image', Icons.image, product, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await updateProduct(editingProductId!);
//                   Navigator.pop(context);
//                 },
//                 child: Text('Save'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   editControllers = null;
//                   editingProductId = null;
//                   productImageFile = null;
//                   productImageFileName = null;
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

//   Widget _buildEditFileField(String field, String label, IconData icon,
//       Map<String, dynamic> product, StateSetter setState) {
//     String? imageUrl = product[field];

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
//           if (imageUrl != null && imageUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () => _showImageDialog(label, imageUrl),
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       'View Existing Image',
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
//                     await pickImage();
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     productImageFileName ?? 'Select New Image',
//                   ),
//                 ),
//               ),
//               if (productImageFileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       productImageFile = null;
//                       productImageFileName = null;
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> updateProduct(int id) async {
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

//       // Add dropdown selections
//       if (selectedEditBpCode != null) {
//         final bpValue = selectedEditBpCode!.split('-').first.trim();
//         request.fields['bp_code'] = bpValue;
//       }
//       if (selectedEditCategoryId != null) {
//         request.fields['product_category'] = selectedEditCategoryId!.toString();
//       }
//       if (selectedEditSubCategoryId != null) {
//         request.fields['sub_category'] = selectedEditSubCategoryId!.toString();
//       }
//       if (selectedEditType != null) {
//         request.fields['type'] = selectedEditType!;
//       }
//       if (selectedEditOrderType != null) {
//         request.fields['order_type'] = selectedEditOrderType!;
//       }
//       if (selectedEditOpenClose != null) {
//         request.fields['open_close'] = selectedEditOpenClose!;
//       }
//       if (selectedEditHallmark != null) {
//         request.fields['hallmark'] = selectedEditHallmark!;
//       }
//       if (selectedEditRodium != null) {
//         request.fields['rodium'] = selectedEditRodium!;
//       }
//       if (selectedEditHook != null) {
//         request.fields['hook'] = selectedEditHook!;
//       }
//       if (selectedEditSize != null) {
//         request.fields['size'] = selectedEditSize!;
//       }
//       if (selectedEditStone != null) {
//         request.fields['stone'] = selectedEditStone!;
//       }
//       if (selectedEditLength != null) {
//         request.fields['length'] = selectedEditLength!;
//       }

//       // Add image if selected
//       if (productImageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'product_image',
//             productImageFile!.path,
//             filename: productImageFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         editControllers = null;
//         editingProductId = null;
//         productImageFile = null;
//         productImageFileName = null;
//         selectedEditBpCode = null;
//         selectedEditCategoryId = null;
//         selectedEditSubCategoryId = null;
//         selectedEditType = null;
//         selectedEditOrderType = null;
//         selectedEditOpenClose = null;
//         selectedEditHallmark = null;
//         selectedEditRodium = null;
//         selectedEditHook = null;
//         selectedEditSize = null;
//         selectedEditStone = null;
//         selectedEditLength = null;

//         await fetchProducts();
//         _showSnackBar('Product updated successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to update product: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Products'),
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
//             onPressed: () => fetchProducts(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddProductDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add Product'),
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

// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;
// import 'package:path/path.dart' as path;

// class ProductPage extends StatefulWidget {
//   @override
//   _ProductPageState createState() => _ProductPageState();
// }

// class _ProductPageState extends State<ProductPage> {
//   // Data lists
//   List<Map<String, dynamic>> products = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   Map<String, dynamic>? currentViewedProduct;

//   // API Endpoints
//   final String listApiUrl = 'http://127.0.0.1:8000/Products/products/list/';
//   final String filterApiUrl = 'http://127.0.0.1:8000/Products/products/filter/';
//   final String createApiUrl = 'http://127.0.0.1:8000/Products/products/create/';
//   final String detailApiUrl = 'http://127.0.0.1:8000/Products/products/detail/';
//   final String updateApiUrl = 'http://127.0.0.1:8000/Products/products/update/';

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
//     {'key': 'product_code', 'label': 'Product Code', 'selected': true, 'order': 0},
//     {'key': 'product_name', 'label': 'Product Name', 'selected': true, 'order': 1},
//     {'key': 'bp_code', 'label': 'BP Code', 'selected': true, 'order': 2},
//     {'key': 'product_category', 'label': 'Category', 'selected': true, 'order': 3},
//     {'key': 'sub_category', 'label': 'Sub Category', 'selected': true, 'order': 4},
//     {'key': 'type', 'label': 'Type', 'selected': true, 'order': 5},
//     {'key': 'quantity', 'label': 'Quantity', 'selected': true, 'order': 6},
//     {'key': 'weight_from', 'label': 'Weight From', 'selected': false, 'order': 7},
//     {'key': 'weight_to', 'label': 'Weight To', 'selected': false, 'order': 8},
//     {'key': 'order_type', 'label': 'Order Type', 'selected': true, 'order': 9},
//     {'key': 'open_close', 'label': 'Open/Close', 'selected': false, 'order': 10},
//     {'key': 'hallmark', 'label': 'Hallmark', 'selected': true, 'order': 11},
//     {'key': 'rodium', 'label': 'Rodium', 'selected': false, 'order': 12},
//     {'key': 'hook', 'label': 'Hook', 'selected': false, 'order': 13},
//     {'key': 'size', 'label': 'Size', 'selected': true, 'order': 14},
//     {'key': 'stone', 'label': 'Stone', 'selected': true, 'order': 15},
//     {'key': 'enamel', 'label': 'Enamel', 'selected': false, 'order': 16},
//     {'key': 'length', 'label': 'Length', 'selected': true, 'order': 17},
//     {'key': 'relabel_code', 'label': 'Relabel Code', 'selected': false, 'order': 18},
//     {'key': 'product_image', 'label': 'Product Image', 'selected': false, 'isFile': true, 'order': 19},
//     {'key': 'created_at', 'label': 'Created Date', 'selected': false, 'order': 20},
//     {'key': 'updated_at', 'label': 'Updated Date', 'selected': false, 'order': 21},
//   ];

//   // Filter controllers
//   final TextEditingController productCodeController = TextEditingController();
//   final TextEditingController productNameController = TextEditingController();
//   final TextEditingController bpCodeController = TextEditingController();
//   final TextEditingController categoryController = TextEditingController();
//   final TextEditingController subCategoryController = TextEditingController();
//   final TextEditingController typeController = TextEditingController();
//   final TextEditingController quantityController = TextEditingController();
//   final TextEditingController weightFromController = TextEditingController();
//   final TextEditingController weightToController = TextEditingController();

//   // Create controllers
//   final Map<String, TextEditingController> createControllers = {};

//   // Dropdown values for create
//   String? selectedCreateBpCode;
//   String? selectedCreateCategory;
//   String? selectedCreateSubCategory;
//   String? selectedCreateType;
//   String? selectedCreateOrderType;
//   String? selectedCreateOpenClose;
//   String? selectedCreateHallmark;
//   String? selectedCreateRodium;
//   String? selectedCreateHook;
//   String? selectedCreateSize;
//   String? selectedCreateStone;
//   String? selectedCreateLength;

//   // Edit controllers
//   Map<String, TextEditingController>? editControllers;
//   int? editingProductId;

//   // Dropdown values for edit
//   String? selectedEditBpCode;
//   String? selectedEditCategory;
//   String? selectedEditSubCategory;
//   String? selectedEditType;
//   String? selectedEditOrderType;
//   String? selectedEditOpenClose;
//   String? selectedEditHallmark;
//   String? selectedEditRodium;
//   String? selectedEditHook;
//   String? selectedEditSize;
//   String? selectedEditStone;
//   String? selectedEditLength;

//   // File uploads
//   File? productImageFile;
//   String? productImageFileName;

//   // Options for dropdowns
//   final List<String> bpCodeOptions = ['BP001', 'BP002', 'BP003', 'BP004', 'BP005'];
//   final List<String> categoryOptions = ['Ring', 'Necklace', 'Earring', 'Bracelet', 'Chain', 'Pendant'];
//   final List<String> subCategoryOptions = ['Gold', 'Silver', 'Platinum', 'Diamond', 'Gemstone'];
//   final List<String> typeOptions = ['New', 'Used', 'Antique', 'Custom'];
//   final List<String> orderTypeOptions = ['Standard', 'Express', 'Priority'];
//   final List<String> openCloseOptions = ['Open', 'Close'];
//   final List<String> hallmarkOptions = ['916', '750', '585', '375', '999'];
//   final List<String> rodiumOptions = ['Yes', 'No'];
//   final List<String> hookOptions = ['Yes', 'No'];
//   final List<String> sizeOptions = ['Small', 'Medium', 'Large', 'XL', 'XXL'];
//   final List<String> stoneOptions = ['Diamond', 'Ruby', 'Emerald', 'Sapphire', 'None'];
//   final List<String> lengthOptions = ['16"', '18"', '20"', '22"', '24"'];

//   // Required fields for product
//   final List<String> requiredFields = [
//     'product_code',
//     'product_name',
//     'bp_code',
//     'product_category',
//     'sub_category',
//     'type',
//     'quantity',
//     'weight_from',
//     'weight_to',
//     'order_type',
//     'open_close',
//     'hallmark',
//     'rodium',
//     'hook',
//     'size',
//     'stone',
//     'enamel',
//     'length',
//     'relabel_code',
//     'product_image',
//     'created_at',
//     'updated_at'
//   ];

//   // Fields to exclude from certain operations
//   final List<String> excludeFromCreate = ['created_at', 'updated_at'];
//   final List<String> excludeFromEdit = ['created_at', 'updated_at'];
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
//     categoryController.dispose();
//     subCategoryController.dispose();
//     typeController.dispose();
//     quantityController.dispose();
//     weightFromController.dispose();
//     weightToController.dispose();

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
//     String? savedSelections = prefs.getString('product_fields');
//     String? savedOrder = prefs.getString('product_field_order');

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

//     await prefs.setString('product_fields', json.encode(selections));
//     List<String> orderList = availableFields.map((f) => f['key'] as String).toList();
//     await prefs.setString('product_field_order', json.encode(orderList));
//   }

//   // Load list settings from SharedPreferences
//   Future<void> loadListSettings() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();

//     setState(() {
//       compactRows = prefs.getBool('product_compact_rows') ?? false;
//       activeRowHighlighting = prefs.getBool('product_active_row_highlighting') ?? false;
//       modernCellColoring = prefs.getBool('product_modern_cell_coloring') ?? false;
//       enableView = prefs.getBool('product_enable_view') ?? true;
//       enableEdit = prefs.getBool('product_enable_edit') ?? true;
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

//     await prefs.setBool('product_compact_rows', compactRows);
//     await prefs.setBool('product_active_row_highlighting', activeRowHighlighting);
//     await prefs.setBool('product_modern_cell_coloring', modernCellColoring);
//     await prefs.setBool('product_enable_view', enableView);
//     await prefs.setBool('product_enable_edit', enableEdit);
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
//       await fetchProducts();
//     } else {
//       setState(() => isLoading = false);
//       print('⚠️ No token found. Please login again.');
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
//   String getFieldValue(Map<String, dynamic> product, String key) {
//     final value = product[key];

//     if (value == null) return '-';

//     if (value is bool) {
//       return value.toString();
//     }

//     return value.toString();
//   }

//   // API Request Building
//   String buildRequestUrl({String? baseUrl}) {
//     if (filterParams.isEmpty && sortBy == null) {
//       return listApiUrl;
//     }
    
//     String url = filterApiUrl;
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

//     Uri uri = Uri.parse(url);
//     return uri.replace(queryParameters: queryParams).toString();
//   }

//   // Fetch Products
//   Future<void> fetchProducts({String? url}) async {
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
        
//         List<Map<String, dynamic>> results = [];
        
//         if (data is List) {
//           results = List<Map<String, dynamic>>.from(data);
//           setState(() {
//             products = results;
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
//             products = results;
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
//             products = [];
//             isLoading = false;
//           });
//         }
//       } else {
//         print('Error: ${response.statusCode} - ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch products: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Exception: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Fetch Single Product Details
//   Future<void> fetchProductDetails(int id) async {
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
//           currentViewedProduct = data;
//           isLoading = false;
//         });
//         showProductDetailDialog();
//       } else {
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch product details', isError: true);
//       }
//     } catch (e) {
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
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
//     if (categoryController.text.isNotEmpty) {
//       filterParams['product_category'] = categoryController.text;
//     }
//     if (subCategoryController.text.isNotEmpty) {
//       filterParams['sub_category'] = subCategoryController.text;
//     }
//     if (typeController.text.isNotEmpty) {
//       filterParams['type'] = typeController.text;
//     }
//     if (quantityController.text.isNotEmpty) {
//       filterParams['quantity'] = quantityController.text;
//     }
//     if (weightFromController.text.isNotEmpty) {
//       filterParams['weight_from'] = weightFromController.text;
//     }
//     if (weightToController.text.isNotEmpty) {
//       filterParams['weight_to'] = weightToController.text;
//     }

//     currentPage = 1;
//     await fetchProducts();
//     Navigator.pop(context);
//   }

//   Future<void> clearFilters() async {
//     filterParams.clear();

//     productCodeController.clear();
//     productNameController.clear();
//     bpCodeController.clear();
//     categoryController.clear();
//     subCategoryController.clear();
//     typeController.clear();
//     quantityController.clear();
//     weightFromController.clear();
//     weightToController.clear();

//     await fetchProducts();
//   }

//   void showFilterDialog() {
//     productCodeController.text = filterParams['product_code'] ?? '';
//     productNameController.text = filterParams['product_name'] ?? '';
//     bpCodeController.text = filterParams['bp_code'] ?? '';
//     categoryController.text = filterParams['product_category'] ?? '';
//     subCategoryController.text = filterParams['sub_category'] ?? '';
//     typeController.text = filterParams['type'] ?? '';
//     quantityController.text = filterParams['quantity'] ?? '';
//     weightFromController.text = filterParams['weight_from'] ?? '';
//     weightToController.text = filterParams['weight_to'] ?? '';

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: Text('Filter Products'),
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
//                       _buildFilterField(typeController, 'Type', Icons.type_specimen),
//                       _buildFilterField(quantityController, 'Quantity', Icons.numbers),
//                       _buildFilterField(weightFromController, 'Weight From', Icons.arrow_downward),
//                       _buildFilterField(weightToController, 'Weight To', Icons.arrow_upward),
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
//     await fetchProducts();
//   }

//   Future<void> clearSort() async {
//     setState(() {
//       sortBy = null;
//       sortOrder = null;
//     });
//     await fetchProducts();
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
//       {'value': 'quantity', 'label': 'Quantity'},
//       {'value': 'weight_from', 'label': 'Weight From'},
//       {'value': 'weight_to', 'label': 'Weight To'},
//       {'value': 'order_type', 'label': 'Order Type'},
//       {'value': 'hallmark', 'label': 'Hallmark'},
//       {'value': 'size', 'label': 'Size'},
//       {'value': 'stone', 'label': 'Stone'},
//       {'value': 'length', 'label': 'Length'},
//       {'value': 'created_at', 'label': 'Created Date'},
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
//                       fetchProducts();
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
//       fetchProducts(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchProducts(url: prevUrl);
//     }
//   }

//   Future<void> changePageSize(int newSize) async {
//     setState(() {
//       pageSize = newSize;
//       currentPage = 1;
//     });
//     await fetchProducts();
//   }

//   // Create Product Methods
//   void showAddProductDialog() {
//     for (var field in requiredFields) {
//       if (!excludeFromCreate.contains(field) &&
//           !isFileField(field) &&
//           !createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }

//     // Reset selections
//     productImageFile = null;
//     productImageFileName = null;
//     selectedCreateBpCode = null;
//     selectedCreateCategory = null;
//     selectedCreateSubCategory = null;
//     selectedCreateType = null;
//     selectedCreateOrderType = null;
//     selectedCreateOpenClose = null;
//     selectedCreateHallmark = null;
//     selectedCreateRodium = null;
//     selectedCreateHook = null;
//     selectedCreateSize = null;
//     selectedCreateStone = null;
//     selectedCreateLength = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Add New Product'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildCreateTextField('product_code', 'Product Code', Icons.code, isRequired: true),
//                     _buildCreateTextField('product_name', 'Product Name', Icons.shopping_bag, isRequired: true),
                    
//                     // BP Code dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: bpCodeOptions,
//                       onChanged: (value) => setState(() => selectedCreateBpCode = value),
//                     ),

//                     // Category dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateCategory,
//                       label: 'Category',
//                       icon: Icons.category,
//                       items: categoryOptions,
//                       onChanged: (value) => setState(() => selectedCreateCategory = value),
//                     ),

//                     // Sub Category dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateSubCategory,
//                       label: 'Sub Category',
//                       icon: Icons.category_outlined,
//                       items: subCategoryOptions,
//                       onChanged: (value) => setState(() => selectedCreateSubCategory = value),
//                     ),

//                     // Type dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateType,
//                       label: 'Type',
//                       icon: Icons.type_specimen,
//                       items: typeOptions,
//                       onChanged: (value) => setState(() => selectedCreateType = value),
//                     ),

//                     _buildCreateTextField('quantity', 'Quantity', Icons.numbers, isRequired: true),
//                     _buildCreateTextField('weight_from', 'Weight From', Icons.arrow_downward),
//                     _buildCreateTextField('weight_to', 'Weight To', Icons.arrow_upward),

//                     // Order Type dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateOrderType,
//                       label: 'Order Type',
//                       icon: Icons.shopping_cart,
//                       items: orderTypeOptions,
//                       onChanged: (value) => setState(() => selectedCreateOrderType = value),
//                     ),

//                     // Open/Close dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateOpenClose,
//                       label: 'Open/Close',
//                       icon: Icons.lock_open,
//                       items: openCloseOptions,
//                       onChanged: (value) => setState(() => selectedCreateOpenClose = value),
//                     ),

//                     // Hallmark dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateHallmark,
//                       label: 'Hallmark',
//                       icon: Icons.verified,
//                       items: hallmarkOptions,
//                       onChanged: (value) => setState(() => selectedCreateHallmark = value),
//                     ),

//                     // Rodium dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateRodium,
//                       label: 'Rodium',
//                       icon: Icons.science,
//                       items: rodiumOptions,
//                       onChanged: (value) => setState(() => selectedCreateRodium = value),
//                     ),

//                     // Hook dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateHook,
//                       label: 'Hook',
//                       icon: Icons.attach_file,
//                       items: hookOptions,
//                       onChanged: (value) => setState(() => selectedCreateHook = value),
//                     ),

//                     // Size dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateSize,
//                       label: 'Size',
//                       icon: Icons.straighten,
//                       items: sizeOptions,
//                       onChanged: (value) => setState(() => selectedCreateSize = value),
//                     ),

//                     // Stone dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateStone,
//                       label: 'Stone',
//                       icon: Icons.diamond,
//                       items: stoneOptions,
//                       onChanged: (value) => setState(() => selectedCreateStone = value),
//                     ),

//                     _buildCreateTextField('enamel', 'Enamel', Icons.color_lens),
                    
//                     // Length dropdown
//                     _buildCreateDropdownField(
//                       value: selectedCreateLength,
//                       label: 'Length',
//                       icon: Icons.height,
//                       items: lengthOptions,
//                       onChanged: (value) => setState(() => selectedCreateLength = value),
//                     ),

//                     _buildCreateTextField('relabel_code', 'Relabel Code', Icons.tag),

//                     _buildCreateFileField('product_image', 'Product Image', Icons.image, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   if (createControllers['product_code']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter product code', isError: true);
//                     return;
//                   }
//                   if (createControllers['product_name']?.text.isEmpty == true) {
//                     _showSnackBar('Please enter product name', isError: true);
//                     return;
//                   }
//                   await createProduct();
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
//       {bool isRequired = false}) {
//     if (!createControllers.containsKey(field)) {
//       createControllers[field] = TextEditingController();
//     }

//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextField(
//         controller: createControllers[field],
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
//         onChanged: onChanged,
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
//                     await pickImage();
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     productImageFileName ?? 'Select Image',
//                   ),
//                 ),
//               ),
//               if (productImageFileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       productImageFile = null;
//                       productImageFileName = null;
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> createProduct() async {
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

//       // Add dropdown selections
//       if (selectedCreateBpCode != null) {
//         request.fields['bp_code'] = selectedCreateBpCode!;
//       }
//       if (selectedCreateCategory != null) {
//         request.fields['product_category'] = selectedCreateCategory!;
//       }
//       if (selectedCreateSubCategory != null) {
//         request.fields['sub_category'] = selectedCreateSubCategory!;
//       }
//       if (selectedCreateType != null) {
//         request.fields['type'] = selectedCreateType!;
//       }
//       if (selectedCreateOrderType != null) {
//         request.fields['order_type'] = selectedCreateOrderType!;
//       }
//       if (selectedCreateOpenClose != null) {
//         request.fields['open_close'] = selectedCreateOpenClose!;
//       }
//       if (selectedCreateHallmark != null) {
//         request.fields['hallmark'] = selectedCreateHallmark!;
//       }
//       if (selectedCreateRodium != null) {
//         request.fields['rodium'] = selectedCreateRodium!;
//       }
//       if (selectedCreateHook != null) {
//         request.fields['hook'] = selectedCreateHook!;
//       }
//       if (selectedCreateSize != null) {
//         request.fields['size'] = selectedCreateSize!;
//       }
//       if (selectedCreateStone != null) {
//         request.fields['stone'] = selectedCreateStone!;
//       }
//       if (selectedCreateLength != null) {
//         request.fields['length'] = selectedCreateLength!;
//       }

//       // Add image if selected
//       if (productImageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'product_image',
//             productImageFile!.path,
//             filename: productImageFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });

//         productImageFile = null;
//         productImageFileName = null;
//         selectedCreateBpCode = null;
//         selectedCreateCategory = null;
//         selectedCreateSubCategory = null;
//         selectedCreateType = null;
//         selectedCreateOrderType = null;
//         selectedCreateOpenClose = null;
//         selectedCreateHallmark = null;
//         selectedCreateRodium = null;
//         selectedCreateHook = null;
//         selectedCreateSize = null;
//         selectedCreateStone = null;
//         selectedCreateLength = null;

//         await fetchProducts();
//         _showSnackBar('Product created successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to create product: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // Pick Image
//   Future<void> pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? file = await picker.pickImage(source: ImageSource.gallery);

//     if (file != null) {
//       setState(() {
//         productImageFile = File(file.path);
//         productImageFileName = path.basename(file.path);
//       });
//     }
//   }

//   // View Product Details
//   void showProductDetailDialog() {
//     if (currentViewedProduct == null) return;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Product Details'),
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
//     dynamic value = currentViewedProduct?[field];

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
//           onTap: () => _showImageDialog(formatFieldName(field), value.toString()),
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

//     if (value == null) return Text('-');
//     if (value is bool) return Text(value.toString());
//     return Text(value.toString());
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
//                             'Personalize List Columns - Products',
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
//                                   {'key': 'product_code', 'label': 'Product Code', 'selected': true},
//                                   {'key': 'product_name', 'label': 'Product Name', 'selected': true},
//                                   {'key': 'bp_code', 'label': 'BP Code', 'selected': true},
//                                   {'key': 'product_category', 'label': 'Category', 'selected': true},
//                                   {'key': 'sub_category', 'label': 'Sub Category', 'selected': true},
//                                   {'key': 'type', 'label': 'Type', 'selected': true},
//                                   {'key': 'quantity', 'label': 'Quantity', 'selected': true},
//                                   {'key': 'order_type', 'label': 'Order Type', 'selected': true},
//                                   {'key': 'hallmark', 'label': 'Hallmark', 'selected': true},
//                                   {'key': 'size', 'label': 'Size', 'selected': true},
//                                   {'key': 'stone', 'label': 'Stone', 'selected': true},
//                                   {'key': 'length', 'label': 'Length', 'selected': true},
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
//                                 'Products - Field Selection',
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
//     if (products.isEmpty) {
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

//     return products.map((product) {
//       final id = product['id'];
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
//                         onPressed: () => fetchProductDetails(id),
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
//                         onPressed: () => showEditProductDialog(product),
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
//         String displayValue = getFieldValue(product, field['key']);

//         if (field['isFile'] == true && displayValue != '-') {
//           cells.add(
//             DataCell(
//               InkWell(
//                 onTap: () => _showImageDialog(field['label'], product[field['key']].toString()),
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

//   // Edit Product Methods
//   void showEditProductDialog(Map<String, dynamic> product) {
//     editingProductId = product['id'];
//     editControllers = {};

//     for (var field in requiredFields) {
//       if (!excludeFromEdit.contains(field) && !isFileField(field)) {
//         editControllers![field] = TextEditingController(
//           text: product[field]?.toString() ?? '',
//         );
//       }
//     }

//     // Set dropdown values for edit
//     selectedEditBpCode = product['bp_code'];
//     selectedEditCategory = product['product_category'];
//     selectedEditSubCategory = product['sub_category'];
//     selectedEditType = product['type'];
//     selectedEditOrderType = product['order_type'];
//     selectedEditOpenClose = product['open_close'];
//     selectedEditHallmark = product['hallmark'];
//     selectedEditRodium = product['rodium'];
//     selectedEditHook = product['hook'];
//     selectedEditSize = product['size'];
//     selectedEditStone = product['stone'];
//     selectedEditLength = product['length'];

//     // Reset file selections
//     productImageFile = null;
//     productImageFileName = null;

//     showDialog(
//       context: context,
//       builder: (_) => StatefulBuilder(
//         builder: (context, setState) {
//           return AlertDialog(
//             title: Text('Edit Product'),
//             content: Container(
//               width: double.maxFinite,
//               constraints: BoxConstraints(
//                 maxHeight: MediaQuery.of(context).size.height * 0.7,
//               ),
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildEditTextField('product_code', 'Product Code', Icons.code),
//                     _buildEditTextField('product_name', 'Product Name', Icons.shopping_bag),

//                     // BP Code dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditBpCode,
//                       label: 'BP Code',
//                       icon: Icons.qr_code,
//                       items: bpCodeOptions,
//                       onChanged: (value) => setState(() => selectedEditBpCode = value),
//                     ),

//                     // Category dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditCategory,
//                       label: 'Category',
//                       icon: Icons.category,
//                       items: categoryOptions,
//                       onChanged: (value) => setState(() => selectedEditCategory = value),
//                     ),

//                     // Sub Category dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditSubCategory,
//                       label: 'Sub Category',
//                       icon: Icons.category_outlined,
//                       items: subCategoryOptions,
//                       onChanged: (value) => setState(() => selectedEditSubCategory = value),
//                     ),

//                     // Type dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditType,
//                       label: 'Type',
//                       icon: Icons.type_specimen,
//                       items: typeOptions,
//                       onChanged: (value) => setState(() => selectedEditType = value),
//                     ),

//                     _buildEditTextField('quantity', 'Quantity', Icons.numbers),
//                     _buildEditTextField('weight_from', 'Weight From', Icons.arrow_downward),
//                     _buildEditTextField('weight_to', 'Weight To', Icons.arrow_upward),

//                     // Order Type dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditOrderType,
//                       label: 'Order Type',
//                       icon: Icons.shopping_cart,
//                       items: orderTypeOptions,
//                       onChanged: (value) => setState(() => selectedEditOrderType = value),
//                     ),

//                     // Open/Close dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditOpenClose,
//                       label: 'Open/Close',
//                       icon: Icons.lock_open,
//                       items: openCloseOptions,
//                       onChanged: (value) => setState(() => selectedEditOpenClose = value),
//                     ),

//                     // Hallmark dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditHallmark,
//                       label: 'Hallmark',
//                       icon: Icons.verified,
//                       items: hallmarkOptions,
//                       onChanged: (value) => setState(() => selectedEditHallmark = value),
//                     ),

//                     // Rodium dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditRodium,
//                       label: 'Rodium',
//                       icon: Icons.science,
//                       items: rodiumOptions,
//                       onChanged: (value) => setState(() => selectedEditRodium = value),
//                     ),

//                     // Hook dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditHook,
//                       label: 'Hook',
//                       icon: Icons.attach_file,
//                       items: hookOptions,
//                       onChanged: (value) => setState(() => selectedEditHook = value),
//                     ),

//                     // Size dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditSize,
//                       label: 'Size',
//                       icon: Icons.straighten,
//                       items: sizeOptions,
//                       onChanged: (value) => setState(() => selectedEditSize = value),
//                     ),

//                     // Stone dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditStone,
//                       label: 'Stone',
//                       icon: Icons.diamond,
//                       items: stoneOptions,
//                       onChanged: (value) => setState(() => selectedEditStone = value),
//                     ),

//                     _buildEditTextField('enamel', 'Enamel', Icons.color_lens),

//                     // Length dropdown for edit
//                     _buildEditDropdownField(
//                       value: selectedEditLength,
//                       label: 'Length',
//                       icon: Icons.height,
//                       items: lengthOptions,
//                       onChanged: (value) => setState(() => selectedEditLength = value),
//                     ),

//                     _buildEditTextField('relabel_code', 'Relabel Code', Icons.tag),

//                     _buildEditFileField('product_image', 'Product Image', Icons.image, product, setState),
//                   ],
//                 ),
//               ),
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   await updateProduct(editingProductId!);
//                   Navigator.pop(context);
//                 },
//                 child: Text('Save'),
//               ),
//               TextButton(
//                 onPressed: () {
//                   editControllers = null;
//                   editingProductId = null;
//                   productImageFile = null;
//                   productImageFileName = null;
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
//         onChanged: onChanged,
//       ),
//     );
//   }

//   Widget _buildEditFileField(String field, String label, IconData icon,
//       Map<String, dynamic> product, StateSetter setState) {
//     String? imageUrl = product[field];

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
//           if (imageUrl != null && imageUrl.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () => _showImageDialog(label, imageUrl),
//                   child: Container(
//                     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: Colors.blue.shade50,
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: Text(
//                       'View Existing Image',
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
//                     await pickImage();
//                     setState(() {});
//                   },
//                   icon: Icon(icon),
//                   label: Text(
//                     productImageFileName ?? 'Select New Image',
//                   ),
//                 ),
//               ),
//               if (productImageFileName != null)
//                 IconButton(
//                   icon: Icon(Icons.clear),
//                   onPressed: () {
//                     setState(() {
//                       productImageFile = null;
//                       productImageFileName = null;
//                     });
//                   },
//                 ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> updateProduct(int id) async {
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

//       // Add dropdown selections
//       if (selectedEditBpCode != null) {
//         request.fields['bp_code'] = selectedEditBpCode!;
//       }
//       if (selectedEditCategory != null) {
//         request.fields['product_category'] = selectedEditCategory!;
//       }
//       if (selectedEditSubCategory != null) {
//         request.fields['sub_category'] = selectedEditSubCategory!;
//       }
//       if (selectedEditType != null) {
//         request.fields['type'] = selectedEditType!;
//       }
//       if (selectedEditOrderType != null) {
//         request.fields['order_type'] = selectedEditOrderType!;
//       }
//       if (selectedEditOpenClose != null) {
//         request.fields['open_close'] = selectedEditOpenClose!;
//       }
//       if (selectedEditHallmark != null) {
//         request.fields['hallmark'] = selectedEditHallmark!;
//       }
//       if (selectedEditRodium != null) {
//         request.fields['rodium'] = selectedEditRodium!;
//       }
//       if (selectedEditHook != null) {
//         request.fields['hook'] = selectedEditHook!;
//       }
//       if (selectedEditSize != null) {
//         request.fields['size'] = selectedEditSize!;
//       }
//       if (selectedEditStone != null) {
//         request.fields['stone'] = selectedEditStone!;
//       }
//       if (selectedEditLength != null) {
//         request.fields['length'] = selectedEditLength!;
//       }

//       // Add image if selected
//       if (productImageFile != null) {
//         request.files.add(
//           await http.MultipartFile.fromPath(
//             'product_image',
//             productImageFile!.path,
//             filename: productImageFileName,
//           ),
//         );
//       }

//       var response = await request.send();
//       var responseBody = await response.stream.bytesToString();

//       if (response.statusCode == 200) {
//         editControllers = null;
//         editingProductId = null;
//         productImageFile = null;
//         productImageFileName = null;
//         selectedEditBpCode = null;
//         selectedEditCategory = null;
//         selectedEditSubCategory = null;
//         selectedEditType = null;
//         selectedEditOrderType = null;
//         selectedEditOpenClose = null;
//         selectedEditHallmark = null;
//         selectedEditRodium = null;
//         selectedEditHook = null;
//         selectedEditSize = null;
//         selectedEditStone = null;
//         selectedEditLength = null;

//         await fetchProducts();
//         _showSnackBar('Product updated successfully!');
//       } else {
//         print('Error response: $responseBody');
//         _showSnackBar('Failed to update product: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Products'),
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
//             onPressed: () => fetchProducts(),
//             tooltip: 'Refresh',
//           ),
//           Padding(
//             padding: const EdgeInsets.only(right: 12),
//             child: ElevatedButton.icon(
//               onPressed: showAddProductDialog,
//               icon: Icon(Icons.add),
//               label: Text('Add Product'),
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