import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show File;

class WorkOrderPage extends StatefulWidget {
  @override
  _WorkOrderPageState createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage> {
  List<Map<String, dynamic>> workOrders = [];
  List<Map<String, dynamic>> allWorkOrders = [];
  bool isLoading = true;
  String? token;
  Set<int> selectedIds = {};
  List<String> buyerBpCodes = [];

  // Pagination variables
  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;

  final fields = [
    'order_no',
    'bp_code',
    'customer_name',
    'reference_no',
    'order_date',
    'due_date',
    'product_category',
    'quantity',
    'type',
    'order_type',
    'weight_from',
    'weight_to',
    'narration_craftsman',
    'narration_admin',
    'open_close',
    'hallmark',
    'rodium',
    'hook',
    'size',
    'stone',
    'enamel',
    'length',
    'product_code',
    'relabel_code',
    'product_name',
    'craftsman_due_date',
    'status',
    'product_image',
  ];

  final readOnlyFields = ['order_no', 'order_date', 'status'];

  final List<String> productCategories = [
    'Rings',
    'Chains',
    'Pendants',
    'Bangles',
    'Anklets',
    'Necklaces',
    'Bracelets',
    'Earrings',
  ];

  final List<String> typeOptions = ['Piece', 'Pair'];

  final List<String> orderTypeOptions = ['Regular', 'Urgent', 'Super Urgent'];

  final List<String> openCloseOptions = ['open', 'close'];

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
    });
    
    if (token != null && token!.isNotEmpty) {
      fetchWorkOrders();
      fetchBuyerBpCodes();
    } else {
      setState(() => isLoading = false);
      _showSnackBar('No token found. Please login again.', isError: true);
    }
  }

  // Helper method to extract list from response
  List<Map<String, dynamic>> extractListFromResponse(dynamic decoded) {
    List<Map<String, dynamic>> list = [];
    
    print('Response type: ${decoded.runtimeType}');
    
    if (decoded is List) {
      // Direct list response
      print('Response is a List with ${decoded.length} items');
      list = List<Map<String, dynamic>>.from(decoded);
    } else if (decoded is Map) {
      print('Response is a Map with keys: ${decoded.keys}');
      
      // Check if it's a paginated response with 'results' key
      if (decoded.containsKey('results')) {
        print('Found "results" key');
        
        var results = decoded['results'];
        
        // Store pagination info
        setState(() {
          nextUrl = decoded['next'];
          prevUrl = decoded['previous'];
          totalCount = decoded['count'] ?? 0;
        });
        
        // Check if results contains an 'orders' key (your specific API structure)
        if (results is Map && results.containsKey('orders')) {
          print('Found "orders" key inside results');
          var orders = results['orders'];
          if (orders is List) {
            list = List<Map<String, dynamic>>.from(orders);
            print('Extracted ${list.length} items from orders');
          }
        }
        // Check if results itself is a List
        else if (results is List) {
          list = List<Map<String, dynamic>>.from(results);
          print('Extracted ${list.length} items from results');
        }
      } else {
        // Check if it's a single object
        print('No "results" key, treating as single object');
        list = [Map<String, dynamic>.from(decoded)];
      }
    }
    
    return list;
  }

  Future<void> fetchWorkOrders({String? url}) async {
    if (token == null) return;
    
    setState(() => isLoading = true);
    
    final requestUrl = url ?? 'http://127.0.0.1:8000/order/orders/list/';
    final uri = Uri.parse(requestUrl);
    
    try {
      print('Fetching work orders from: $requestUrl');
      final resp = await http.get(
        uri,
        headers: {'Authorization': 'Token $token'},
      );
      
      print('Response status: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        final list = extractListFromResponse(decoded);
        
        setState(() {
          if (url == null) {
            // First page or refresh
            allWorkOrders = list;
            workOrders = list;
          } else {
            // For pagination, replace current list
            workOrders = list;
          }
          isLoading = false;
        });
        
        print('Work orders loaded: ${list.length} items');
      } else {
        print('Failed to fetch work orders: ${resp.statusCode} | ${resp.body}');
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch work orders: ${resp.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error fetching work orders: $e');
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> fetchBuyerBpCodes() async {
    if (token == null) return;
    
    final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
    try {
      print('Fetching buyers from: $url');
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
      
      print('Buyers response status: ${resp.statusCode}');
      
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> buyerList = [];
        
        if (decoded is List) {
          buyerList = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded.containsKey('results')) {
          var results = decoded['results'];
          if (results is List) {
            buyerList = List<Map<String, dynamic>>.from(results);
          } else if (results is Map && results.containsKey('buyers')) {
            buyerList = List<Map<String, dynamic>>.from(results['buyers']);
          }
        }
        
        setState(() {
          buyerBpCodes = buyerList.map((buyer) => "${buyer['bp_code']} - ${buyer['name'] ?? ''}").toList();
        });
        
        print('Buyers loaded: ${buyerList.length} items');
      } else {
        print('Failed to fetch buyers: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  Future<void> addOrUpdateWorkOrder(Map<String, dynamic> data, {bool isEdit = false}) async {
    if (token == null) return;
    
    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/order/orders/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/order/orders/create/');
    
    try {
      print('Saving work order to: $url');
      var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
      request.headers['Authorization'] = 'Token $token';

      // Add text fields with proper null handling
      data.forEach((key, value) {
        if (key != 'product_image' && value != null) {
          try {
            // Skip complex objects and only add simple values
            if (value is String || value is num || value is bool) {
              String valStr = value.toString();
              
              // Handle date format conversion
              if ((key == 'due_date' || key == 'craftsman_due_date') &&
                  RegExp(r'\d{2}-\d{2}-\d{4}').hasMatch(valStr)) {
                List<String> parts = valStr.split('-');
                valStr = "${parts[2]}-${parts[1]}-${parts[0]}";
              }
              
              request.fields[key] = valStr;
              print('Added field: $key = $valStr');
            } else {
              print('Skipping complex field: $key = $value (${value.runtimeType})');
            }
          } catch (e) {
            print('Error processing field $key: $e');
          }
        }
      });

      // Add product image if selected
      if (data['product_image'] != null &&
          data['product_image'].toString().isNotEmpty &&
          !data['product_image'].toString().startsWith('http')) {
        try {
          final filePath = data['product_image'].toString();
          final file = File(filePath);
          if (await file.exists()) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'product_image',
                file.path,
              ),
            );
            print('Added product image: $filePath');
          }
        } catch (e) {
          print('Error adding product image: $e');
        }
      }

      print('Request fields: ${request.fields}');
      print('Request files: ${request.files.length}');

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      
      print('Save response status: ${response.statusCode}');
      print('Save response body: $respStr');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        fetchWorkOrders();
        _showSnackBar(isEdit ? 'Work order updated successfully!' : 'Work order created successfully!');
      } else {
        _showSnackBar('Failed to save work order: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error saving work order: $e');
      print('Stack trace: ${StackTrace.current}');
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> pickImage(Function(String) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) onSelected(picked.path);
  }

  // Status Filter with API integration for New orders
  void filterWorkOrdersByStatus(String status) async {
    if (token == null) return;
    
    if (status == 'All') {
      setState(() {
        workOrders = allWorkOrders;
      });
      return;
    }

    if (status == 'New') {
      // Fetch new orders from API
      final url = Uri.parse('http://127.0.0.1:8000/order/orders/new-orders/');
      try {
        setState(() => isLoading = true);
        print('Fetching new orders from: $url');
        
        final resp = await http.get(
          url,
          headers: {'Authorization': 'Token $token'},
        );
        
        print('New orders response status: ${resp.statusCode}');
        
        if (resp.statusCode == 200) {
          final decoded = json.decode(resp.body);
          final list = extractListFromResponse(decoded);
          
          setState(() {
            workOrders = list;
            isLoading = false;
          });
          
          print('New orders loaded: ${list.length} items');
        } else {
          print('Failed to fetch new orders: ${resp.statusCode} | ${resp.body}');
          setState(() => isLoading = false);
          _showSnackBar('Failed to fetch new orders', isError: true);
        }
      } catch (e) {
        print('Error fetching new orders: $e');
        setState(() => isLoading = false);
        _showSnackBar('Error: $e', isError: true);
      }
    } else {
      // Local filter for other statuses
      setState(() {
        workOrders = allWorkOrders.where((order) {
          final orderStatus = order['status']?.toString().toLowerCase() ?? '';
          return orderStatus == status.toLowerCase();
        }).toList();
      });
    }
  }

  // Pagination methods
  void loadNextPage() {
    if (nextUrl != null && nextUrl!.isNotEmpty) {
      currentPage++;
      fetchWorkOrders(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchWorkOrders(url: prevUrl);
    }
  }

  // Navigate to AllocatedToPage
  void _navigateToAllocatedToPage() {
    if (selectedIds.isEmpty) {
      _showSnackBar('Please select at least one order to allocate', isError: true);
      return;
    }

    // Get the first selected order
    final selectedOrder = workOrders.firstWhere((order) => selectedIds.contains(order['id']));
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllocatedToPage(
          order: selectedOrder,
          token: token!,
        ),
      ),
    ).then((value) {
      if (value == true) {
        fetchWorkOrders();
        setState(() {
          selectedIds.clear();
        });
      }
    });
  }

  Widget _buildStatusButton(String status) {
    return OutlinedButton(
      onPressed: isLoading ? null : () => filterWorkOrdersByStatus(status),
      child: Text(status),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        side: BorderSide(color: Colors.blue),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work Orders'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: token != null ? fetchWorkOrders : null,
          ),
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: token != null ? () => showWorkOrderForm(isEdit: false) : null,
            child: Text('Add New'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusButton('All'),
                  SizedBox(width: 8),
                  _buildStatusButton('New'),
                  SizedBox(width: 8),
                  _buildStatusButton('Allocated'),
                  SizedBox(width: 8),
                  _buildStatusButton('In Process'),
                  SizedBox(width: 8),
                  _buildStatusButton('Approval'),
                  SizedBox(width: 8),
                  _buildStatusButton('Completed'),
                  SizedBox(width: 8),
                  _buildStatusButton('Rejected'),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _navigateToAllocatedToPage,
                    icon: Icon(Icons.send),
                    label: Text('Allocate To'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: token == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No authentication token found'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadToken,
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : isLoading
              ? Center(child: CircularProgressIndicator())
              : workOrders.isEmpty
                  ? Center(child: Text('No work orders found'))
                  : Column(
                      children: [
                        // Selection info
                        if (selectedIds.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(8),
                            color: Colors.blue.shade50,
                            child: Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Selected: ${selectedIds.length} orders'),
                                Spacer(),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      selectedIds.clear();
                                    });
                                  },
                                  child: Text('Clear Selection'),
                                ),
                              ],
                            ),
                          ),
                        
                        // Data table
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                columnSpacing: 20,
                                showCheckboxColumn: false,
                                columns: [
                                  DataColumn(label: Text('Select', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ...fields.map((f) => DataColumn(
                                    label: Text(
                                      f.toUpperCase(),
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  )),
                                ],
                                rows: workOrders.map((workOrder) {
                                  int id = workOrder['id'] ?? 0;
                                  bool isSelected = selectedIds.contains(id);

                                  return DataRow(
                                    selected: isSelected,
                                    cells: [
                                      DataCell(
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true) {
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
                                                  ElevatedButton(
                                                    onPressed: () => showViewDialog(workOrder), 
                                                    child: Text('View'),
                                                    style: ElevatedButton.styleFrom(
                                                      minimumSize: Size(60, 30),
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                  SizedBox(width: 4),
                                                  ElevatedButton(
                                                    onPressed: () => showWorkOrderForm(workOrder: workOrder, isEdit: true),
                                                    child: Text('Edit'),
                                                    style: ElevatedButton.styleFrom(
                                                      minimumSize: Size(60, 30),
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox.shrink(),
                                      ),
                                      ...fields.map((f) {
                                        final val = workOrder[f];
                                        if (f == 'product_image') {
                                          return DataCell(
                                            val != null && val.toString().isNotEmpty
                                                ? Image.network(
                                                    val,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => 
                                                      Icon(Icons.image_not_supported, color: Colors.grey),
                                                  )
                                                : Icon(Icons.image, color: Colors.grey),
                                          );
                                        }
                                        return DataCell(
                                          Container(
                                            constraints: BoxConstraints(maxWidth: 150),
                                            child: Text(
                                              val?.toString() ?? '',
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
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
                        
                        // Pagination
                        if (nextUrl != null || prevUrl != null)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: (prevUrl == null || prevUrl!.isEmpty) ? null : loadPrevPage,
                                  child: Text('Previous'),
                                ),
                                SizedBox(width: 16),
                                Text('Page $currentPage'),
                                SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: (nextUrl == null || nextUrl!.isEmpty) ? null : loadNextPage,
                                  child: Text('Next'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
    );
  }

  void showViewDialog(Map<String, dynamic> workOrder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Work Order'),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: fields.map((f) {
                final val = workOrder[f];
                if (f == 'product_image') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text(f.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      val != null && val.toString().isNotEmpty
                          ? Image.network(
                              val,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => 
                                Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            )
                          : Text('No Image'),
                      SizedBox(height: 10),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: Text(f.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text(val?.toString() ?? '-')),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
      ),
    );
  }

  void showWorkOrderForm({Map<String, dynamic>? workOrder, bool isEdit = false}) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> data = Map.from(workOrder ?? {});
    String profilePath = data['product_image'] ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Work Order' : 'Add Work Order'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
              maxWidth: 500,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    // BP Code Dropdown
                    DropdownButtonFormField<String>(
                      value: data['bp_code'] != null &&
                              buyerBpCodes.any((bp) => bp.split('-').first.trim() == data['bp_code'])
                          ? data['bp_code']
                          : null,
                      items: buyerBpCodes.map((bp) {
                        final bpCode = bp.split('-').first.trim();
                        return DropdownMenuItem<String>(
                          value: bpCode,
                          child: Text(bp, style: TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          data['bp_code'] = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'BP Code *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Please select BP Code' : null,
                    ),
                    SizedBox(height: 10),
                    
                    // Product Image
                    Row(children: [
                      ElevatedButton(
                        onPressed: () async {
                          await pickImage((path) {
                            setStateDialog(() => profilePath = path);
                            data['product_image'] = path;
                          });
                        },
                        child: Text('Order Image'),
                      ),
                      SizedBox(width: 10),
                      if (profilePath.isNotEmpty) 
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 4),
                            Text('Image selected'),
                          ],
                        ),
                    ]),
                    SizedBox(height: 10),
                    
                    // Dynamic fields
                    ...fields.where((f) {
                      if (!isEdit && readOnlyFields.contains(f)) return false;
                      return f != 'product_image' && f != 'bp_code';
                    }).map((f) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildFormField(f, data, setStateDialog),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                addOrUpdateWorkOrder(data, isEdit: isEdit);
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String f, Map<String, dynamic> data, StateSetter setStateDialog) {
    // Category dropdown
    if (f == 'product_category') {
      return DropdownButtonFormField<String>(
        value: data[f] != null && productCategories.contains(data[f]) ? data[f] : null,
        items: productCategories
            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
            .toList(),
        onChanged: (val) => data[f] = val,
        decoration: InputDecoration(
          labelText: f.toUpperCase(),
          border: OutlineInputBorder(),
        ),
      );
    } 
    // Type dropdown
    else if (f == 'type') {
      return DropdownButtonFormField<String>(
        value: data[f] != null && typeOptions.contains(data[f]) ? data[f] : null,
        items: typeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (val) => data[f] = val,
        decoration: InputDecoration(
          labelText: 'TYPE',
          border: OutlineInputBorder(),
        ),
      );
    } 
    // Order type dropdown
    else if (f == 'order_type') {
      return DropdownButtonFormField<String>(
        value: data[f] != null && orderTypeOptions.contains(data[f]) ? data[f] : null,
        items: orderTypeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (val) => data[f] = val,
        decoration: InputDecoration(
          labelText: 'ORDER TYPE',
          border: OutlineInputBorder(),
        ),
      );
    } 
    // Open/Close dropdown
    else if (f == 'open_close') {
      return DropdownButtonFormField<String>(
        value: data[f] != null && openCloseOptions.contains(data[f]) ? data[f] : null,
        items: openCloseOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (val) => data[f] = val,
        decoration: InputDecoration(
          labelText: 'OPEN/CLOSE',
          border: OutlineInputBorder(),
        ),
      );
    } 
    // Yes/No dropdown fields
    else if (['hallmark', 'rodium', 'hook', 'stone'].contains(f)) {
      final yesNoOptions = ['Yes', 'No'];
      return DropdownButtonFormField<String>(
        value: data[f] != null && yesNoOptions.contains(data[f]) ? data[f] : null,
        items: yesNoOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (val) => data[f] = val,
        decoration: InputDecoration(
          labelText: f.toUpperCase(),
          border: OutlineInputBorder(),
        ),
      );
    } 
    // Size dropdown
    else if (f == 'size') {
      final sizeOptions = ['Large', 'Medium', 'Small'];
      return DropdownButtonFormField<String>(
        value: data[f] != null && sizeOptions.contains(data[f]) ? data[f] : null,
        items: sizeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
        onChanged: (val) => data[f] = val,
        decoration: InputDecoration(
          labelText: 'SIZE',
          border: OutlineInputBorder(),
        ),
      );
    } 
    // Date fields
    else if (f == 'due_date' || f == 'craftsman_due_date') {
      return InkWell(
        onTap: () async {
          DateTime initialDate = DateTime.now();
          if (data[f] != null && data[f].toString().isNotEmpty) {
            try {
              List<String> parts = data[f].toString().split('-');
              if (parts.length == 3) {
                initialDate = DateTime(
                  int.parse(parts[2]),
                  int.parse(parts[1]),
                  int.parse(parts[0]),
                );
              }
            } catch (_) {}
          }
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setStateDialog(() => data[f] = "${picked.day.toString().padLeft(2,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.year}");
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            controller: TextEditingController(text: data[f]?.toString() ?? ''),
            decoration: InputDecoration(
              labelText: f.toUpperCase(),
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
        ),
      );
    } 
    // Regular text fields
    else {
      return TextFormField(
        initialValue: data[f]?.toString() ?? '',
        readOnly: readOnlyFields.contains(f),
        decoration: InputDecoration(
          labelText: f.toUpperCase(),
          border: OutlineInputBorder(),
        ),
        onChanged: (val) => data[f] = val,
      );
    }
  }
}

class AllocatedToPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final String token;

  AllocatedToPage({required this.order, required this.token});

  @override
  _AllocatedToPageState createState() => _AllocatedToPageState();
}

class _AllocatedToPageState extends State<AllocatedToPage> {
  final _formKey = GlobalKey<FormState>();
  String? selectedBpCode;
  String? dueDate;
  List<Map<String, String>> craftsmanList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCraftsmans();
  }

  Future<void> fetchCraftsmans() async {
    final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Craftsmans/');
    try {
      print('Fetching craftsmen from: $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Token ${widget.token}'},
      );

      print('Craftsmen response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<dynamic> craftsmenListRaw = [];

        if (jsonData is List) {
          craftsmenListRaw = jsonData;
        } else if (jsonData is Map && jsonData.containsKey('results')) {
          var results = jsonData['results'];
          if (results is List) {
            craftsmenListRaw = results;
          } else if (results is Map && results.containsKey('craftsmen')) {
            craftsmenListRaw = results['craftsmen'];
          }
        }

        // Remove duplicates and prepare bp_code + name
        final seen = <String>{};
        List<Map<String, String>> uniqueList = [];
        for (var item in craftsmenListRaw) {
          String bpCode = item['bp_code'].toString();
          if (!seen.contains(bpCode)) {
            seen.add(bpCode);
            uniqueList.add({
              'bp_code': bpCode,
              'name': item['name'] ?? '',
            });
          }
        }

        setState(() {
          craftsmanList = uniqueList;
          isLoading = false;
        });
        
        print('Craftsmen loaded: ${uniqueList.length} items');
      } else {
        throw Exception('Failed to load craftsmen');
      }
    } catch (e) {
      print('Error fetching craftsmen: $e');
      setState(() => isLoading = false);
      _showSnackBar('Error fetching craftsmen', isError: true);
    }
  }

  Future<void> allocateOrder() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final url = Uri.parse('http://127.0.0.1:8000/order/orders/assign-orders/');
    try {
      print('Allocating order to: $url');
      
      Map<String, dynamic> body = {
        "order_id": widget.order['id'],
        "bp_code": selectedBpCode!,
      };

      if (dueDate != null && dueDate!.isNotEmpty) {
        List<String> parts = dueDate!.split('-');
        body['due_date'] = "${parts[2]}-${parts[1]}-${parts[0]}";
      }

      print('Request body: $body');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      print('Allocate response status: ${response.statusCode}');
      print('Allocate response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Order allocated successfully');
        Navigator.pop(context, true);
      } else {
        _showSnackBar('Failed: ${response.body}', isError: true);
      }
    } catch (e) {
      print('Error allocating order: $e');
      _showSnackBar('Error allocating order', isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Allocate Order')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Details',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('Order No: ${widget.order['order_no'] ?? ''}'),
                            Text('Customer: ${widget.order['customer_name'] ?? ''}'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Craftsman *',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedBpCode,
                      items: craftsmanList.map((item) {
                        return DropdownMenuItem(
                          value: item['bp_code'],
                          child: Text("${item['bp_code']} - ${item['name']}"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedBpCode = val),
                      validator: (val) => val == null ? 'Please select BP Code' : null,
                    ),
                    SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            dueDate =
                                "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                          });
                        }    
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Due Date (Optional)',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(text: dueDate ?? ''),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: allocateOrder,
                        child: Text('Allocate'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:file_picker/file_picker.dart';
// import 'package:image_picker/image_picker.dart';
// // import 'dart:io' show File;
// // import 'package:path/path.dart' as path;



// class WorkOrderPage extends StatefulWidget {
//   @override
//   _WorkOrderPageState createState() => _WorkOrderPageState();
// }

// class _WorkOrderPageState extends State<WorkOrderPage> {
//   List<Map<String, dynamic>> workOrders = [];
//   List<Map<String, dynamic>> allWorkOrders = [];
//   bool isLoading = true;
//   String token = "c4d39cfb658de543df3719a86ff8bee85ea8da85";
//   Set<int> selectedIds = {};
//   List<String> buyerBpCodes = [];

//   final fields = [
//     'order_no',
//     'bp_code',
//     'customer_name',
//     'reference_no',
//     'order_date',
//     'due_date',
//     'product_category',
//     'quantity',
//     'type',
//     'order_type',
//     'weight_from',
//     'weight_to',
//     'narration_craftsman',
//     'narration_admin',
//     'open_close',
//     'hallmark',
//     'rodium',
//     'hook',
//     'size',
//     'stone',
//     'enamel',
//     'length',
//     'product_code',
//     'relabel_code',
//     'product_name',
//     'craftsman_due_date',
//     'status',
//     'product_image',
//   ];

//   final readOnlyFields = ['order_no', 'order_date', 'status'];

//   final List<String> productCategories = [
//     'Rings',
//     'Chains',
//     'Pendants',
//     'Bangles',
//     'Anklets',
//     'Necklaces',
//     'Bracelets',
//     'Earrings',
//   ];

//   final List<String> typeOptions = ['Piece', 'Pair'];

//   final List<String> orderTypeOptions = ['Regular', 'Urgent', 'Super Urgent'];

//   final List<String> openCloseOptions = ['open', 'close'];

//   @override
//   void initState() {
//     super.initState();
//     fetchWorkOrders();
//     fetchBuyerBpCodes();
//   }

//   Future<void> fetchWorkOrders() async {
//     setState(() => isLoading = true);
//     final url = Uri.parse('http://127.0.0.1:8000/order/orders/list/');
//     try {
//       final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
//       if (resp.statusCode == 200) {
//         final decoded = json.decode(resp.body);
//         List<Map<String, dynamic>> list = [];
//         if (decoded is List) {
//           list = List<Map<String, dynamic>>.from(decoded);
//         } else if (decoded is Map && decoded.containsKey('results')) {
//           list = List<Map<String, dynamic>>.from(decoded['results']);
//         }
//         setState(() {
//           allWorkOrders = list;
//           workOrders = list;
//           isLoading = false;
//         });
//       } else {
//         print('Failed to fetch work orders: ${resp.statusCode} | ${resp.body}');
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print('Error fetching work orders: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> fetchBuyerBpCodes() async {
//     final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
//     try {
//       final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
//       if (resp.statusCode == 200) {
//         final decoded = json.decode(resp.body);
//         List<Map<String, dynamic>> buyerList = [];
//         if (decoded is Map && decoded.containsKey('results')) {
//           buyerList = List<Map<String, dynamic>>.from(decoded['results']);
//         }
//         setState(() {
//           buyerBpCodes = buyerList.map((buyer) => "${buyer['bp_code']}").toList();
//         });
//       } else {
//         print('Failed to fetch buyers: ${resp.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching buyers: $e');
//     }
//   }

//   Future<void> addOrUpdateWorkOrder(Map<String, dynamic> data, {bool isEdit = false}) async {
//     Uri url = isEdit
//         ? Uri.parse('http://127.0.0.1:8000/order/orders/update/${data['id']}/')
//         : Uri.parse('http://127.0.0.1:8000/order/orders/create/');
//     try {
//       var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
//       request.headers['Authorization'] = 'Token $token';

//       data.forEach((key, value) async {
//         if (value != null && key != 'product_image') {
//           String valStr = value.toString();
//           if ((key == 'due_date' || key == 'craftsman_due_date') &&
//               RegExp(r'\d{2}-\d{2}-\d{4}').hasMatch(valStr)) {
//             List<String> parts = valStr.split('-');
//             valStr = "${parts[2]}-${parts[1]}-${parts[0]}";
//           }
//           request.fields[key] = valStr;
//         }
//       });

//       if (data['product_image'] != null &&
//           data['product_image'].toString().isNotEmpty &&
//           !data['product_image'].toString().startsWith('http')) {
//         request.files.add(await http.MultipartFile.fromPath('product_image', data['product_image']));
//       }

//       var response = await request.send();
//       var respStr = await response.stream.bytesToString();
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         Navigator.pop(context);
//         fetchWorkOrders();
//       } else {
//         print('Failed to save work order: ${response.statusCode} | $respStr');
//       }
//     } catch (e) {
//       print('Error saving work order: $e');
//     }
//   }

//   Future<void> pickImage(Function(String) onSelected) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
//     if (picked != null) onSelected(picked.path);
//   }

//   // ✅ Status Filter with API integration for New orders
//   void filterWorkOrdersByStatus(String status) async {
//     if (status == 'All') {
//       setState(() {
//         workOrders = allWorkOrders;
//       });
//       return;
//     }

//     if (status == 'New') {
//       // Fetch new orders from API
//       final url = Uri.parse('http://127.0.0.1:8000/order/orders/new-orders/');
//       try {
//         setState(() => isLoading = true);
//         final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
//         if (resp.statusCode == 200) {
//           final decoded = json.decode(resp.body);
//           List<Map<String, dynamic>> list = [];
//           if (decoded is List) {
//             list = List<Map<String, dynamic>>.from(decoded);
//           } else if (decoded is Map && decoded.containsKey('results')) {
//             list = List<Map<String, dynamic>>.from(decoded['results']);
//           }
//           setState(() {
//             workOrders = list;
//             isLoading = false;
//           });
//         } else {
//           print('Failed to fetch new orders: ${resp.statusCode} | ${resp.body}');
//           setState(() => isLoading = false);
//         }
//       } catch (e) {
//         print('Error fetching new orders: $e');
//         setState(() => isLoading = false);
//       }
//     } else {
//       // Local filter for other statuses
//       setState(() {
//         workOrders = allWorkOrders.where((order) {
//           return (order['status']?.toString().toLowerCase() == status.toLowerCase());
//         }).toList();
//       });
//     }
//   }

//   // ✅ Navigate to AllocatedToPage
//   void _navigateToAllocatedToPage() {
//     if (selectedIds.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Please select at least one order to allocate'))
//       );
//       return;
//     }

//     // Get the first selected order (you might want to handle multiple selections differently)
//     final selectedOrder = workOrders.firstWhere((order) => selectedIds.contains(order['id']));
    
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => AllocatedToPage(
//           order: selectedOrder,
//           token: token,
//         ),
//       ),
//     ).then((value) {
//       if (value == true) {
//         fetchWorkOrders();
//         setState(() {
//           selectedIds.clear();
//         });
//       }
//     });
//   }

//   Widget _buildStatusButton(String status) {
//     return OutlinedButton(
//       onPressed: () {
//         filterWorkOrdersByStatus(status);
//       },
//       child: Text(status),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Work Orders'),
//         actions: [
//           ElevatedButton(
//             onPressed: () => showWorkOrderForm(isEdit: false),
//             child: Text('Add New'),
//           ),
//           SizedBox(width: 8),
//           Wrap(
//             spacing: 8,
//             children: [
//               _buildStatusButton('All'),
//               _buildStatusButton('New'),
//               _buildStatusButton('Allocated'),
//               _buildStatusButton('In Process'),
//               _buildStatusButton('Approval'),
//               _buildStatusButton('Completed'),
//               _buildStatusButton('Rejected'),
//               ElevatedButton(
//                 onPressed: _navigateToAllocatedToPage,
//                 child: Text('Allocated To'),
//               ),
//             ],
//           ),
//           SizedBox(width: 8),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : workOrders.isEmpty
//               ? Center(child: Text('No work orders found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columns: [
//                       DataColumn(label: Text('Select')),
//                       DataColumn(label: Text('Actions')),
//                       ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
//                     ],
//                     rows: workOrders.map((workOrder) {
//                       int id = workOrder['id'];
//                       bool isSelected = selectedIds.contains(id);

//                       return DataRow(
//                         selected: isSelected,
//                         cells: [
//                           DataCell(Checkbox(
//                             value: isSelected,
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true) {
//                                   selectedIds.add(id);
//                                 } else {
//                                   selectedIds.remove(id);
//                                 }
//                               });
//                             },
//                           )),
//                           DataCell(
//                             Row(
//                               children: isSelected
//                                   ? [
//                                       ElevatedButton(onPressed: () => showViewDialog(workOrder), child: Text('View')),
//                                       SizedBox(width: 8),
//                                       ElevatedButton(
//                                           onPressed: () => showWorkOrderForm(workOrder: workOrder, isEdit: true),
//                                           child: Text('Edit')),
//                                     ]
//                                   : [Text('')],
//                             ),
//                           ),
//                           ...fields.map((f) {
//                             final val = workOrder[f];
//                             if (f == 'product_image') {
//                               return DataCell(val != null
//                                   ? Image.network(val, width: 40, height: 40, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
//                                   : Icon(Icons.image));
//                             }
//                             return DataCell(Text(val?.toString() ?? ''));
//                           }).toList(),
//                         ],
//                       );
//                     }).toList(),
//                   ),
//                 ),
//     );
//   }
//   void showViewDialog(Map<String, dynamic> workOrder) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('View Work Order'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: fields.map((f) {
//               final val = workOrder[f];
//               if (f == 'product_image') {
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(f.toUpperCase()),
//                     val != null
//                         ? Image.network(val, width: 100, height: 100, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
//                         : Text('No Image'),
//                     SizedBox(height: 10),
//                   ],
//                 );
//               }
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 4),
//                 child: Row(
//                   children: [Expanded(flex: 2, child: Text(f.toUpperCase())), Expanded(flex: 3, child: Text(val?.toString() ?? ''))],
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//         actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
//       ),
//     );
//   }

//   void showWorkOrderForm({Map<String, dynamic>? workOrder, bool isEdit = false}) {
//     final formKey = GlobalKey<FormState>();
//     Map<String, dynamic> data = Map.from(workOrder ?? {});
//     String profilePath = data['product_image'] ?? '';

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Work Order' : 'Add Work Order'),
//         content: StatefulBuilder(
//           builder: (context, setStateDialog) => SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 children: [
//                   DropdownButtonFormField<String>(
//                     value: data['bp_code'] != null &&
//                             buyerBpCodes.any((bp) => bp.split('-').first.trim() == data['bp_code'])
//                         ? data['bp_code']
//                         : null,
//                     items: buyerBpCodes.map((bp) {
//                       final bpCode = bp.split('-').first.trim();
//                       return DropdownMenuItem<String>(
//                         value: bpCode,
//                         child: Text(bp),
//                       );
//                     }).toList(),
//                     onChanged: (value) {
//                       setStateDialog(() {
//                         data['bp_code'] = value!;
//                       });
//                     },
//                     decoration: InputDecoration(labelText: 'BP Code'),
//                   ),
//                   SizedBox(height: 10),
//                   Row(children: [
//                     ElevatedButton(
//                       onPressed: () async {
//                         await pickImage((path) {
//                           setStateDialog(() => profilePath = path);
//                           data['product_image'] = path;
//                         });
//                       },
//                       child: Text('Order Image'),
//                     ),
//                     SizedBox(width: 10),
//                     if (profilePath.isNotEmpty) Icon(Icons.check_circle, color: Colors.green),
//                   ]),
//                   SizedBox(height: 10),
//                   ...fields.where((f) {
//                     if (!isEdit && readOnlyFields.contains(f)) return false;
//                     return f != 'product_image' && f != 'bp_code';
//                   }).map((f) {
//                     if (f == 'product_category') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: DropdownButtonFormField<String>(
//                           value: data[f] != null && productCategories.contains(data[f]) ? data[f] : null,
//                           items: productCategories
//                               .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
//                               .toList(),
//                           onChanged: (val) => data[f] = val,
//                           decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder()),
//                         ),
//                       );
//                     } else if (f == 'type') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: DropdownButtonFormField<String>(
//                           value: data[f] != null && typeOptions.contains(data[f]) ? data[f] : null,
//                           items: typeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
//                           onChanged: (val) => data[f] = val,
//                           decoration: InputDecoration(labelText: 'TYPE', border: OutlineInputBorder()),
//                         ),
//                       );
//                     } else if (f == 'order_type') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: DropdownButtonFormField<String>(
//                           value: data[f] != null && orderTypeOptions.contains(data[f]) ? data[f] : null,
//                           items: orderTypeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
//                           onChanged: (val) => data[f] = val,
//                           decoration: InputDecoration(labelText: 'ORDER TYPE', border: OutlineInputBorder()),
//                         ),
//                       );
//                     } else if (f == 'open_close') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: DropdownButtonFormField<String>(
//                           value: data[f] != null && openCloseOptions.contains(data[f]) ? data[f] : null,
//                           items: openCloseOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
//                           onChanged: (val) => data[f] = val,
//                           decoration: InputDecoration(labelText: 'OPEN/CLOSE', border: OutlineInputBorder()),
//                         ),
//                       );
//                     } else if (['hallmark', 'rodium', 'hook', 'stone'].contains(f)) {
//                       final yesNoOptions = ['Yes', 'No'];
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: DropdownButtonFormField<String>(
//                           value: data[f] != null && yesNoOptions.contains(data[f]) ? data[f] : null,
//                           items: yesNoOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
//                           onChanged: (val) => data[f] = val,
//                           decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder()),
//                         ),
//                       );
//                     } else if (f == 'size') {
//                       final sizeOptions = ['Large', 'Medium', 'Small'];
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: DropdownButtonFormField<String>(
//                           value: data[f] != null && sizeOptions.contains(data[f]) ? data[f] : null,
//                           items: sizeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
//                           onChanged: (val) => data[f] = val,
//                           decoration: InputDecoration(labelText: 'SIZE', border: OutlineInputBorder()),
//                         ),
//                       );
//                     } else if (f == 'due_date' || f == 'craftsman_due_date') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: InkWell(
//                           onTap: () async {
//                             DateTime initialDate = DateTime.now();
//                             if (data[f] != null && data[f].toString().isNotEmpty) {
//                               try {
//                                 List<String> parts = data[f].toString().split('-');
//                                 if (parts.length == 3) initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
//                               } catch (_) {}
//                             }
//                             DateTime? picked = await showDatePicker(
//                               context: context,
//                               initialDate: initialDate,
//                               firstDate: DateTime(2000),
//                               lastDate: DateTime(2100),
//                             );
//                             if (picked != null) setStateDialog(() => data[f] = "${picked.day.toString().padLeft(2,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.year}");
//                           },
//                           child: AbsorbPointer(
//                             child: TextFormField(
//                               controller: TextEditingController(text: data[f]?.toString() ?? ''),
//                               decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
//                             ),
//                           ),
//                         ),
//                       );
//                     } else {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 4),
//                         child: TextFormField(
//                           initialValue: data[f]?.toString() ?? '',
//                           readOnly: readOnlyFields.contains(f),
//                           decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder()),
//                           onChanged: (val) => data[f] = val,
//                         ),
//                       );
//                     }
//                   }).toList(),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
//           ElevatedButton(
//             onPressed: () {
//               addOrUpdateWorkOrder(data, isEdit: isEdit);
//             },
//             child: Text(isEdit ? 'Update' : 'Create'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class AllocatedToPage extends StatefulWidget {
//   final Map<String, dynamic> order;
//   final String token;

//   AllocatedToPage({required this.order, required this.token});

//   @override
//   _AllocatedToPageState createState() => _AllocatedToPageState();
// }

// class _AllocatedToPageState extends State<AllocatedToPage> {
//   final _formKey = GlobalKey<FormState>();
//   String? selectedBpCode;
//   String? dueDate;
//   List<Map<String, String>> craftsmanList = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchCraftsmans();
//   }

//   Future<void> fetchCraftsmans() async {
//     final url = Uri.parse(
//         'https://veto.co.in/BusinessPartner/BusinessPartner/Craftsmans/');
//     try {
//       final response =
//           await http.get(url, headers: {'Authorization': 'Token ${widget.token}'});

//       if (response.statusCode == 200) {
//         final jsonData = json.decode(response.body);
//         List<dynamic> craftsmenListRaw = [];

//         if (jsonData is List) {
//           craftsmenListRaw = jsonData;
//         } else if (jsonData is Map && jsonData.containsKey('results')) {
//           craftsmenListRaw = jsonData['results'];
//         }

//         // Remove duplicates and prepare bp_code + name
//         final seen = <String>{};
//         List<Map<String, String>> uniqueList = [];
//         for (var item in craftsmenListRaw) {
//           String bpCode = item['bp_code'].toString();
//           if (!seen.contains(bpCode)) {
//             seen.add(bpCode);
//             uniqueList.add({
//               'bp_code': bpCode,
//               'name': item['name'] ?? '',
//             });
//           }
//         }

//         setState(() {
//           craftsmanList = uniqueList;
//           isLoading = false;
//         });
//       } else {
//         throw Exception('Failed to load craftsmen');
//       }
//     } catch (e) {
//       print('Error fetching craftsmen: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> allocateOrder() async {
//     if (!_formKey.currentState!.validate()) return;
//     _formKey.currentState!.save();

//     final url = Uri.parse('https://veto.co.in/order/orders/assign-orders/');
//     try {
//       Map<String, dynamic> body = {
//         "order_id": widget.order['id'],
//         "bp_code": selectedBpCode!,
//       };

//       if (dueDate != null) {
//         List<String> parts = dueDate!.split('-');
//         body['due_date'] = "${parts[2]}-${parts[1]}-${parts[0]}";
//       }

//       final response = await http.post(
//         url,
//         headers: {
//           'Authorization': 'Token ${widget.token}',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode(body),
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Order allocated successfully')),
//         );
//         Navigator.pop(context, true);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed: ${response.body}')),
//         );
//       }
//     } catch (e) {
//       print('Error allocating order: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error allocating order')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Allocate Order')),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16.0),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text('Order No: ${widget.order['order_no']}',
//                         style: TextStyle(fontSize: 16)),
//                     SizedBox(height: 16),
//                     DropdownButtonFormField<String>(
//                       decoration: InputDecoration(
//                         labelText: 'Select BP Code',
//                         border: OutlineInputBorder(),
//                       ),
//                       value: selectedBpCode,
//                       items: craftsmanList.map((item) {
//                         return DropdownMenuItem(
//                           value: item['bp_code'],
//                           child: Text("${item['bp_code']}"),
//                         );
//                       }).toList(),
//                       onChanged: (val) => setState(() => selectedBpCode = val),
//                       validator: (val) =>
//                           val == null ? 'Please select BP Code' : null,
//                     ),
//                     SizedBox(height: 16),
//                     InkWell(
//                       onTap: () async {
//                         DateTime? picked = await showDatePicker(
//                           context: context,
//                           initialDate: DateTime.now(),
//                           firstDate: DateTime(2000),
//                           lastDate: DateTime(2100),
//                         );
//                         if (picked != null) {
//                           setState(() {
//                             dueDate =
//                                 "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
//                           });
//                         }    
//                       },
//                       child: AbsorbPointer(
//                         child: TextFormField(
//                           decoration: InputDecoration(
//                             labelText: 'Due Date',
//                             border: OutlineInputBorder(),
//                           ),
//                           controller: TextEditingController(text: dueDate ?? ''),
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 24),
//                     ElevatedButton(onPressed: allocateOrder, child: Text('Allocate')),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }
// }
// void main() {
//   runApp(MaterialApp(
//     // home: PurchaseOrderPage(),
//     theme: ThemeData(
//       primaryColor: Colors.blueGrey[900],
//       colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.blue),
//       appBarTheme: AppBarTheme(
//         backgroundColor: Colors.blueGrey[900],
//         foregroundColor: Colors.white,
//       ),
//     ),
//   ));
// }