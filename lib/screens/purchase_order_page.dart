import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;

class PurchaseOrderPage extends StatefulWidget {
  @override
  _PurchaseOrderPageState createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  String selectedFilter = 'Specific';
  TextEditingController searchController = TextEditingController();
  String? token;
  bool isLoading = true;
  List<Map<String, dynamic>> purchaseOrders = [];
  Set<int> selectedIds = {};

  // Pagination variables
  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;
  final int pageSize = 20;

  final List<String> filters = ['Specific', 'All', 'Pending'];
  final List<String> tabs = ['Created', 'In Process', 'Presented', 'Rejected', 'Allocated'];
  int selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
    });
    
    if (token != null && token!.isNotEmpty) {
      fetchPurchaseOrders();
    } else {
      setState(() => isLoading = false);
      _showSnackBar('No token found. Please login again.', isError: true);
    }
  }

  // Helper method to extract list from response
  List<Map<String, dynamic>> extractListFromResponse(dynamic decoded) {
    List<Map<String, dynamic>> list = [];
    
    print('Response type: ${decoded.runtimeType}');
    
    if (decoded == null) {
      return list;
    }
    
    if (decoded is List) {
      // Direct list response
      print('Response is a List with ${decoded.length} items');
      try {
        list = List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        print('Error converting list: $e');
      }
    } else if (decoded is Map) {
      print('Response is a Map with keys: ${decoded.keys}');
      
      // Store pagination info if available
      if (decoded.containsKey('count')) {
        setState(() {
          totalCount = decoded['count'] ?? 0;
          nextUrl = decoded['next'];
          prevUrl = decoded['previous'];
        });
      }
      
      // Check if it's a paginated response with 'results' key
      if (decoded.containsKey('results')) {
        print('Found "results" key');
        
        var results = decoded['results'];
        
        if (results != null) {
          // Check if results contains an 'orders' key (your specific structure)
          if (results is Map && results.containsKey('orders')) {
            print('Found "orders" key inside results');
            var orders = results['orders'];
            if (orders is List) {
              try {
                list = List<Map<String, dynamic>>.from(orders);
                print('Extracted ${list.length} items from orders');
              } catch (e) {
                print('Error extracting orders: $e');
              }
            }
          }
          // Check if results contains a 'purchase_orders' key
          else if (results is Map && results.containsKey('purchase_orders')) {
            print('Found "purchase_orders" key inside results');
            var purchaseOrdersList = results['purchase_orders'];
            if (purchaseOrdersList is List) {
              try {
                list = List<Map<String, dynamic>>.from(purchaseOrdersList);
                print('Extracted ${list.length} items from purchase_orders');
              } catch (e) {
                print('Error extracting purchase_orders: $e');
              }
            }
          }
          // Check if results itself is a List
          else if (results is List) {
            try {
              list = List<Map<String, dynamic>>.from(results);
              print('Extracted ${list.length} items from results');
            } catch (e) {
              print('Error extracting from results list: $e');
            }
          }
        }
      } else {
        // Check if it's a single object
        print('No "results" key, treating as single object');
        try {
          list = [Map<String, dynamic>.from(decoded)];
        } catch (e) {
          print('Error converting single object: $e');
        }
      }
    }
    
    return list;
  }

  Future<void> fetchPurchaseOrders({String? url}) async {
    if (token == null) return;
    
    setState(() => isLoading = true);
    
    final requestUrl = url ?? 'http://127.0.0.1:8000/PurchaseOrder/PurchaseOrder/list/';
    final uri = Uri.parse(requestUrl);
    
    try {
      print('Fetching purchase orders from: $requestUrl');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Token $token'},
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final list = extractListFromResponse(decoded);
        
        setState(() {
          if (url == null) {
            purchaseOrders = list;
          } else {
            // For pagination, replace current list
            purchaseOrders = list;
          }
          isLoading = false;
          selectedIds.clear(); // Clear selections when data refreshes
        });
        
        print('Purchase orders loaded: ${list.length} items');
      } else {
        print('Failed to fetch purchase orders: ${response.statusCode} | ${response.body}');
        setState(() => isLoading = false);
        _showSnackBar('Failed to fetch purchase orders: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error fetching purchase orders: $e');
      setState(() => isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // Pagination methods
  void loadNextPage() {
    if (nextUrl != null && nextUrl!.isNotEmpty) {
      currentPage++;
      fetchPurchaseOrders(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && prevUrl!.isNotEmpty) {
      currentPage--;
      fetchPurchaseOrders(url: prevUrl);
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

  String _getSafeString(dynamic value, {String defaultValue = '-'}) {
    if (value == null) return defaultValue;
    if (value is String) {
      return value.isEmpty ? defaultValue : value;
    }
    return value.toString();
  }

  int _getSafeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  double _getSafeDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  void _showViewDialog(Map<String, dynamic> order) {
    if (order.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Purchase Order Details'),
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
                // Order Details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 8),
                        Text('Order No: ${_getSafeString(order['order_number'])}'),
                        Text('Order Date: ${_getSafeString(order['order_date'])}'),
                        Text('Due Date: ${_getSafeString(order['due_date'])}'),
                        Text('Status: ${_getSafeString(order['status'])}'),
                        Text('Note: ${_getSafeString(order['note'])}'),
                        Text('Total Weight: ${_getSafeDouble(order['total_weight_count']).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Items Header
                Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                
                // Items List
                if (order['items'] != null && order['items'] is List && (order['items'] as List).isNotEmpty)
                  ...List.generate((order['items'] as List).length, (index) {
                    final item = (order['items'] as List)[index];
                    if (item == null) return SizedBox.shrink();
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Item #${item['S_No'] ?? index + 1}', 
                                 style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Category: ${_getSafeString(item['product_category'])} - ${_getSafeString(item['sub_category'])}'),
                            
                            // Handle design which might be a list
                            if (item['design'] != null)
                              Text('Design: ${item['design'] is List ? (item['design'] as List).join(', ') : item['design'].toString()}'),
                            
                            Text('Grams: ${_getSafeString(item['grams'])}'),
                            Text('Quantity: ${_getSafeString(item['quantity'])}'),
                            Text('Total Weight: ${_getSafeDouble(item['total_weight']).toStringAsFixed(2)}'),
                            Text('Notes: ${_getSafeString(item['notes'])}'),
                            
                            if (item['image'] != null && item['image'].toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Image.network(
                                  item['image'].toString(),
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => 
                                    Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  })
                else
                  Text('No items found'),
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

  // New method to show allocation dialog
  void _showAllocationDialog() {
    if (selectedIds.isEmpty) {
      _showSnackBar('Please select orders to allocate', isError: true);
      return;
    }

    // Get selected order numbers
    final selectedOrders = purchaseOrders
        .where((order) => selectedIds.contains(_getSafeInt(order['id'])))
        .toList();

    showDialog(
      context: context,
      builder: (context) => AllocateOrderDialog(
        token: token!,
        selectedOrders: selectedOrders,
        onAllocationComplete: () {
          // Refresh the purchase orders list after allocation
          fetchPurchaseOrders();
          setState(() {
            selectedIds.clear();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Purchase Orders'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: token != null ? fetchPurchaseOrders : null,
          ),
        ],
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters, Search & Buttons Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedFilter,
                              items: filters.map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  selectedFilter = newValue!;
                                  filterByFilterType(newValue);
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          width: 200,
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: 'Search',
                              prefixIcon: Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            ),
                            onChanged: (value) {
                              searchOrders(value);
                            },
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreatePurchaseOrderPage(token: token!),
                              ),
                            ).then((value) {
                              if (value == true) {
                                fetchPurchaseOrders();
                              }
                            });
                          },
                          icon: Icon(Icons.add, size: 18),
                          label: Text('Add New'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: selectedIds.isEmpty ? null : () => _showEditDialog(),
                          child: Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: selectedIds.isEmpty ? null : () {
                            final selectedOrder = purchaseOrders.firstWhere(
                              (order) => selectedIds.contains(_getSafeInt(order['id'])),
                              orElse: () => {},
                            );
                            if (selectedOrder.isNotEmpty) {
                              _showViewDialog(selectedOrder);
                            }
                          },
                          child: Text('View'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showSortDialog();
                          },
                          child: Text('Sort'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _showFilterDialog();
                          },
                          child: Text('Filter'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _printOrders();
                          },
                          child: Text('Print'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: selectedIds.isEmpty ? null : () {
                            _showAllocationDialog();
                          },
                          child: Text('Allocate'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: selectedIds.isEmpty ? null : () {
                            _shareOrders();
                          },
                          child: Text('Share'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Selection info
                  if (selectedIds.isNotEmpty)
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
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
                            child: Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                  
                  // Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(tabs.length, (index) {
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(tabs[index]),
                            selected: selectedTabIndex == index,
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: selectedTabIndex == index ? Colors.white : Colors.black,
                            ),
                            onSelected: (bool selected) {
                              setState(() {
                                selectedTabIndex = selected ? index : 0;
                                filterByStatus(tabs[selectedTabIndex]);
                              });
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  // Table Header
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text('Select', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Order No', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Order Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Total Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  
                  // Table Data
                  Expanded(
                    child: isLoading
                        ? Center(child: CircularProgressIndicator())
                        : purchaseOrders.isEmpty
                            ? Center(
                                child: Text(
                                  'No Purchase Orders Available',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                itemCount: purchaseOrders.length,
                                itemBuilder: (context, index) {
                                  final order = purchaseOrders[index];
                                  if (order == null) return SizedBox.shrink();
                                  
                                  final id = _getSafeInt(order['id']);
                                  final isSelected = selectedIds.contains(id);
                                  
                                  // Safely get items count
                                  int itemsCount = 0;
                                  if (order.containsKey('items') && order['items'] != null && order['items'] is List) {
                                    itemsCount = (order['items'] as List).length;
                                  }
                                  
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue.shade50 : null,
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            selectedIds.remove(id);
                                          } else {
                                            selectedIds.add(id);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
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
                                            Expanded(flex: 2, child: Text(_getSafeString(order['order_number']))),
                                            Expanded(flex: 2, child: Text(_getSafeString(order['order_date']))),
                                            Expanded(flex: 2, child: Text(_getSafeString(order['due_date']))),
                                            Expanded(flex: 1, child: Text('$itemsCount')),
                                            Expanded(flex: 2, child: Text(
                                              _getSafeDouble(order['total_weight_count']).toStringAsFixed(2)
                                            )),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(_getSafeString(order['status'])),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  _getSafeString(order['status']),
                                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                  
                  // Pagination
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Page $currentPage of ${totalCount > 0 ? (totalCount / pageSize).ceil() : 1} | Total: $totalCount',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: (prevUrl == null || prevUrl!.isEmpty) ? null : loadPrevPage,
                              child: Text('Previous'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: (nextUrl == null || nextUrl!.isEmpty) ? null : loadNextPage,
                              child: Text('Next'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    switch (status.toLowerCase()) {
      case 'created':
        return Colors.blue;
      case 'in process':
        return Colors.orange;
      case 'presented':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'allocated':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void filterByStatus(String status) {
    // Implement status filtering
    print('Filtering by: $status');
    _showSnackBar('Filtering by: $status');
  }

  void filterByFilterType(String filterType) {
    // Implement filter type filtering
    print('Filtering by: $filterType');
    _showSnackBar('Filtering by: $filterType');
  }

  void searchOrders(String query) {
    // Implement search functionality
    print('Searching for: $query');
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sort By'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Order Number'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Sort by Order Number');
              },
            ),
            ListTile(
              title: Text('Order Date'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Sort by Order Date');
              },
            ),
            ListTile(
              title: Text('Due Date'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Sort by Due Date');
              },
            ),
            ListTile(
              title: Text('Status'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Sort by Status');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter Orders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('By Status'),
              onTap: () {
                Navigator.pop(context);
                _showFilterByStatusDialog();
              },
            ),
            ListTile(
              title: Text('By Date Range'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Filter by Date Range');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFilterByStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((status) {
            return ListTile(
              title: Text(status),
              onTap: () {
                Navigator.pop(context);
                filterByStatus(status);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    _showSnackBar('Edit functionality coming soon');
  }

  void _printOrders() {
    if (selectedIds.isEmpty) {
      _showSnackBar('Please select orders to print', isError: true);
      return;
    }
    _showSnackBar('Print functionality coming soon');
  }

  void _shareOrders() {
    if (selectedIds.isEmpty) {
      _showSnackBar('Please select orders to share', isError: true);
      return;
    }
    _showSnackBar('Share functionality coming soon');
  }
}

// Allocation Dialog Widget
class AllocateOrderDialog extends StatefulWidget {
  final String token;
  final List<Map<String, dynamic>> selectedOrders;
  final VoidCallback onAllocationComplete;

  const AllocateOrderDialog({
    Key? key,
    required this.token,
    required this.selectedOrders,
    required this.onAllocationComplete,
  }) : super(key: key);

  @override
  _AllocateOrderDialogState createState() => _AllocateOrderDialogState();
}

class _AllocateOrderDialogState extends State<AllocateOrderDialog> {
  bool isSubmitting = false;
  String? selectedOrderNumber;
  TextEditingController bpCodeController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  
  // For multiple orders selection
  Map<String, bool> selectedOrders = {};
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    // Initialize selected orders map
    for (var order in widget.selectedOrders) {
      selectedOrders[order['order_number'] ?? ''] = true;
    }
  }

  @override
  void dispose() {
    bpCodeController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> allocateOrders() async {
    if (bpCodeController.text.isEmpty) {
      _showSnackBar('Please enter BP Code', isError: true);
      return;
    }

    // Get selected order numbers
    final orderNumbers = selectedOrders.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .where((key) => key.isNotEmpty)
        .toList();

    if (orderNumbers.isEmpty) {
      _showSnackBar('Please select at least one order', isError: true);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final url = Uri.parse('http://127.0.0.1:8000/PurchaseOrder/PurchaseOrder/assign-orders/');
      
      // Prepare the data according to the API format
      // For multiple orders, we need to send multiple objects
      List<Map<String, dynamic>> allocationData = orderNumbers.map((orderNumber) {
        return {
          'order_number': orderNumber,
          'bp_code': bpCodeController.text,
          'note': noteController.text,
        };
      }).toList();

      print('Sending allocation data: $allocationData');

      // If there's only one order, send as single object, otherwise send as array
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(allocationData.length == 1 ? allocationData.first : allocationData),
      );

      print('Allocation response status: ${response.statusCode}');
      print('Allocation response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('${orderNumbers.length} order(s) allocated successfully!');
        Navigator.pop(context);
        widget.onAllocationComplete();
      } else {
        String errorMessage = 'Failed to allocate orders';
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map && errorData.containsKey('error')) {
            errorMessage = errorData['error'];
          } else if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          } else {
            errorMessage = response.body;
          }
        } catch (e) {
          errorMessage = response.body;
        }
        _showSnackBar(errorMessage, isError: true);
      }
    } catch (e) {
      print('Error allocating orders: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isSubmitting = false);
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    
    switch (status.toLowerCase()) {
      case 'created':
        return Colors.blue;
      case 'in process':
        return Colors.orange;
      case 'presented':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'allocated':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Allocate Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BP Code Input
                    TextField(
                      controller: bpCodeController,
                      decoration: InputDecoration(
                        labelText: 'BP Code *',
                        border: OutlineInputBorder(),
                        hintText: 'Enter BP Code',
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Note Input
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                        hintText: 'Enter allocation note (optional)',
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 16),
                    
                    // Selected Orders Header with Select All
                    Row(
                      children: [
                        Text(
                          'Selected Orders (${selectedOrders.values.where((v) => v).length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),
                        Row(
                          children: [
                            Text('Select All'),
                            Checkbox(
                              value: selectAll,
                              onChanged: (value) {
                                setState(() {
                                  selectAll = value ?? false;
                                  for (var key in selectedOrders.keys) {
                                    selectedOrders[key] = selectAll;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    
                    // Orders List
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: widget.selectedOrders.length,
                          itemBuilder: (context, index) {
                            final order = widget.selectedOrders[index];
                            final orderNumber = order['order_number'] ?? 'N/A';
                            
                            return CheckboxListTile(
                              title: Text('Order #: $orderNumber'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Due Date: ${order['due_date'] ?? 'N/A'}'),
                                  Text('Status: ${order['status'] ?? 'N/A'}'),
                                ],
                              ),
                              value: selectedOrders[orderNumber] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  selectedOrders[orderNumber] = value ?? false;
                                  // Update select all status
                                  selectAll = selectedOrders.values.every((v) => v);
                                });
                              },
                              secondary: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order['status']),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  order['status'] ?? 'Unknown',
                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer with buttons
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isSubmitting ? null : allocateOrders,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Allocate'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePurchaseOrderPage extends StatefulWidget {
  final String token;
  
  CreatePurchaseOrderPage({required this.token});

  @override
  _CreatePurchaseOrderPageState createState() => _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  DateTime? selectedDate;
  TextEditingController dueDateController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool isSubmitting = false;
  
  final List<String> categories = ["Gold", "Silver", "Diamond", "Platinum"];
  final List<String> subCategories = ["Rings", "Chains", "Pendants", "Bangles", "Earrings", "Necklaces", "Bracelets"];
  final List<String> designs = ["Knot Rope", "Plain", "Fancy", "Custom", "Traditional", "Modern"];

  @override
  void dispose() {
    dueDateController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> createPurchaseOrder() async {
    if (dueDateController.text.isEmpty) {
      _showSnackBar('Please select a due date', isError: true);
      return;
    }

    if (items.isEmpty) {
      _showSnackBar('Please add at least one item', isError: true);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final url = Uri.parse('http://127.0.0.1:8000/PurchaseOrder/PurchaseOrder/create/');
      
      // Prepare the data according to backend format
      Map<String, dynamic> orderData = {
        'due_date': dueDateController.text,
        'note': noteController.text,
        'items': items.map((item) {
          return {
            'product_category': item['category'] ?? '',
            'sub_category': item['subCategory'] ?? '',
            'design': [item['design'] ?? ''], // Backend expects array
            'grams': (item['grams'] ?? 0).toString(),
            'quantity': (item['qty'] ?? 0).toString(),
            'total_weight': (item['total'] ?? 0).toDouble(),
            'notes': item['note'] ?? '',
            'image': '', // Add image handling if needed
          };
        }).toList(),
      };

      print('Sending order data: $orderData');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(orderData),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar('Purchase order created successfully!');
        Navigator.pop(context, true);
      } else {
        _showSnackBar('Failed to create purchase order: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('Error creating purchase order: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => isSubmitting = false);
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
      appBar: AppBar(
        title: Text('Create Purchase Order'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Due Date + Note Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dueDateController,
                    decoration: InputDecoration(
                      labelText: "Due Date *",
                      border: OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDate = picked;
                              dueDateController.text =
                                  "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: "Note",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Table Header
            Container(
              color: Colors.grey[200],
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Sub Category", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Design", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Grams", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Notes", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // Dynamic Rows
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  var item = items[index];
                  if (item == null) return SizedBox.shrink();
                  
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text("${index + 1}")),

                        // Category Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: item.containsKey('category') && item['category'] != null && categories.contains(item['category'])
                                ? item['category']
                                : null,
                            hint: Text("Select"),
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item['category'] = val;
                              });
                            },
                          ),
                        ),

                        // Sub Category Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: item.containsKey('subCategory') && item['subCategory'] != null && subCategories.contains(item['subCategory'])
                                ? item['subCategory']
                                : null,
                            hint: Text("Select"),
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                            ),
                            items: subCategories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item['subCategory'] = val;
                              });
                            },
                          ),
                        ),

                        // Design Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: item.containsKey('design') && item['design'] != null && designs.contains(item['design'])
                                ? item['design']
                                : null,
                            hint: Text("Select"),
                            isExpanded: true,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                            ),
                            items: designs.map((des) {
                              return DropdownMenuItem(
                                value: des,
                                child: Text(des),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item['design'] = val;
                              });
                            },
                          ),
                        ),

                        // Grams
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "Grams",
                              border: InputBorder.none,
                            ),
                            initialValue: item['grams']?.toString() ?? '',
                            onChanged: (val) {
                              setState(() {
                                item['grams'] = double.tryParse(val) ?? 0;
                                item['total'] = (item['grams'] ?? 0) * (item['qty'] ?? 0);
                              });
                            },
                          ),
                        ),

                        // Quantity
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "Qty",
                              border: InputBorder.none,
                            ),
                            initialValue: item['qty']?.toString() ?? '',
                            onChanged: (val) {
                              setState(() {
                                item['qty'] = int.tryParse(val) ?? 0;
                                item['total'] = (item['grams'] ?? 0) * (item['qty'] ?? 0);
                              });
                            },
                          ),
                        ),

                        // Total Weight
                        Expanded(
                          flex: 2,
                          child: Text(
                            item['total'] != null 
                              ? item['total'].toStringAsFixed(2) 
                              : "0.00"
                          ),
                        ),

                        // Notes
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: item['note'] ?? '',
                            decoration: InputDecoration(
                              hintText: "Notes",
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              item['note'] = val;
                            },
                          ),
                        ),

                        // Remove Action
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                items.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      items.add({
                        "category": categories.isNotEmpty ? categories[0] : null,
                        "subCategory": subCategories.isNotEmpty ? subCategories[0] : null,
                        "design": designs.isNotEmpty ? designs[0] : null,
                        "grams": 0.0,
                        "qty": 0,
                        "total": 0.0,
                        "note": ""
                      });
                    });
                  },
                  icon: Icon(Icons.add),
                  label: Text("Add Item"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: isSubmitting ? null : createPurchaseOrder,
                  child: isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text("Create Order"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
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

// class PurchaseOrderPage extends StatefulWidget {
//   @override
//   _PurchaseOrderPageState createState() => _PurchaseOrderPageState();
// }

// class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
//   String selectedFilter = 'Specific';
//   TextEditingController searchController = TextEditingController();
//   String? token;
//   bool isLoading = true;
//   List<Map<String, dynamic>> purchaseOrders = [];
//   Set<int> selectedIds = {};

//   // Pagination variables
//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;
//   final int pageSize = 20;

//   final List<String> filters = ['Specific', 'All', 'Pending'];
//   final List<String> tabs = ['Created', 'In Process', 'Presented', 'Rejected', 'Allocated'];
//   int selectedTabIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadToken();
//   }

//   @override
//   void dispose() {
//     searchController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       token = prefs.getString('token');
//     });
    
//     if (token != null && token!.isNotEmpty) {
//       fetchPurchaseOrders();
//     } else {
//       setState(() => isLoading = false);
//       _showSnackBar('No token found. Please login again.', isError: true);
//     }
//   }

//   // Helper method to extract list from response
//   List<Map<String, dynamic>> extractListFromResponse(dynamic decoded) {
//     List<Map<String, dynamic>> list = [];
    
//     print('Response type: ${decoded.runtimeType}');
    
//     if (decoded == null) {
//       return list;
//     }
    
//     if (decoded is List) {
//       // Direct list response
//       print('Response is a List with ${decoded.length} items');
//       try {
//         list = List<Map<String, dynamic>>.from(decoded);
//       } catch (e) {
//         print('Error converting list: $e');
//       }
//     } else if (decoded is Map) {
//       print('Response is a Map with keys: ${decoded.keys}');
      
//       // Store pagination info if available
//       if (decoded.containsKey('count')) {
//         setState(() {
//           totalCount = decoded['count'] ?? 0;
//           nextUrl = decoded['next'];
//           prevUrl = decoded['previous'];
//         });
//       }
      
//       // Check if it's a paginated response with 'results' key
//       if (decoded.containsKey('results')) {
//         print('Found "results" key');
        
//         var results = decoded['results'];
        
//         if (results != null) {
//           // Check if results contains an 'orders' key (your specific structure)
//           if (results is Map && results.containsKey('orders')) {
//             print('Found "orders" key inside results');
//             var orders = results['orders'];
//             if (orders is List) {
//               try {
//                 list = List<Map<String, dynamic>>.from(orders);
//                 print('Extracted ${list.length} items from orders');
//               } catch (e) {
//                 print('Error extracting orders: $e');
//               }
//             }
//           }
//           // Check if results contains a 'purchase_orders' key
//           else if (results is Map && results.containsKey('purchase_orders')) {
//             print('Found "purchase_orders" key inside results');
//             var purchaseOrdersList = results['purchase_orders'];
//             if (purchaseOrdersList is List) {
//               try {
//                 list = List<Map<String, dynamic>>.from(purchaseOrdersList);
//                 print('Extracted ${list.length} items from purchase_orders');
//               } catch (e) {
//                 print('Error extracting purchase_orders: $e');
//               }
//             }
//           }
//           // Check if results itself is a List
//           else if (results is List) {
//             try {
//               list = List<Map<String, dynamic>>.from(results);
//               print('Extracted ${list.length} items from results');
//             } catch (e) {
//               print('Error extracting from results list: $e');
//             }
//           }
//         }
//       } else {
//         // Check if it's a single object
//         print('No "results" key, treating as single object');
//         try {
//           list = [Map<String, dynamic>.from(decoded)];
//         } catch (e) {
//           print('Error converting single object: $e');
//         }
//       }
//     }
    
//     return list;
//   }

//   Future<void> fetchPurchaseOrders({String? url}) async {
//     if (token == null) return;
    
//     setState(() => isLoading = true);
    
//     final requestUrl = url ?? 'http://127.0.0.1:8000/PurchaseOrder/PurchaseOrder/list/';
//     final uri = Uri.parse(requestUrl);
    
//     try {
//       print('Fetching purchase orders from: $requestUrl');
//       final response = await http.get(
//         uri,
//         headers: {'Authorization': 'Token $token'},
//       );
      
//       print('Response status: ${response.statusCode}');
      
//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);
//         final list = extractListFromResponse(decoded);
        
//         setState(() {
//           if (url == null) {
//             purchaseOrders = list;
//           } else {
//             // For pagination, replace current list
//             purchaseOrders = list;
//           }
//           isLoading = false;
//           selectedIds.clear(); // Clear selections when data refreshes
//         });
        
//         print('Purchase orders loaded: ${list.length} items');
//       } else {
//         print('Failed to fetch purchase orders: ${response.statusCode} | ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch purchase orders: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Error fetching purchase orders: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
//   }

//   // Pagination methods
//   void loadNextPage() {
//     if (nextUrl != null && nextUrl!.isNotEmpty) {
//       currentPage++;
//       fetchPurchaseOrders(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && prevUrl!.isNotEmpty) {
//       currentPage--;
//       fetchPurchaseOrders(url: prevUrl);
//     }
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

//   String _getSafeString(dynamic value, {String defaultValue = '-'}) {
//     if (value == null) return defaultValue;
//     if (value is String) {
//       return value.isEmpty ? defaultValue : value;
//     }
//     return value.toString();
//   }

//   int _getSafeInt(dynamic value, {int defaultValue = 0}) {
//     if (value == null) return defaultValue;
//     if (value is int) return value;
//     if (value is double) return value.toInt();
//     if (value is String) {
//       return int.tryParse(value) ?? defaultValue;
//     }
//     return defaultValue;
//   }

//   double _getSafeDouble(dynamic value, {double defaultValue = 0.0}) {
//     if (value == null) return defaultValue;
//     if (value is double) return value;
//     if (value is int) return value.toDouble();
//     if (value is String) {
//       return double.tryParse(value) ?? defaultValue;
//     }
//     return defaultValue;
//   }

//   void _showViewDialog(Map<String, dynamic> order) {
//     if (order.isEmpty) return;
    
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Purchase Order Details'),
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
//                 // Order Details
//                 Card(
//                   child: Padding(
//                     padding: const EdgeInsets.all(12.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text('Order Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                         SizedBox(height: 8),
//                         Text('Order No: ${_getSafeString(order['order_number'])}'),
//                         Text('Order Date: ${_getSafeString(order['order_date'])}'),
//                         Text('Due Date: ${_getSafeString(order['due_date'])}'),
//                         Text('Status: ${_getSafeString(order['status'])}'),
//                         Text('Note: ${_getSafeString(order['note'])}'),
//                         Text('Total Weight: ${_getSafeDouble(order['total_weight_count']).toStringAsFixed(2)}'),
//                       ],
//                     ),
//                   ),
//                 ),
//                 SizedBox(height: 16),
                
//                 // Items Header
//                 Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 SizedBox(height: 8),
                
//                 // Items List
//                 if (order['items'] != null && order['items'] is List && (order['items'] as List).isNotEmpty)
//                   ...List.generate((order['items'] as List).length, (index) {
//                     final item = (order['items'] as List)[index];
//                     if (item == null) return SizedBox.shrink();
                    
//                     return Card(
//                       margin: EdgeInsets.only(bottom: 8),
//                       child: Padding(
//                         padding: const EdgeInsets.all(8.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Item #${item['S_No'] ?? index + 1}', 
//                                  style: TextStyle(fontWeight: FontWeight.bold)),
//                             SizedBox(height: 4),
//                             Text('Category: ${_getSafeString(item['product_category'])} - ${_getSafeString(item['sub_category'])}'),
                            
//                             // Handle design which might be a list
//                             if (item['design'] != null)
//                               Text('Design: ${item['design'] is List ? (item['design'] as List).join(', ') : item['design'].toString()}'),
                            
//                             Text('Grams: ${_getSafeString(item['grams'])}'),
//                             Text('Quantity: ${_getSafeString(item['quantity'])}'),
//                             Text('Total Weight: ${_getSafeDouble(item['total_weight']).toStringAsFixed(2)}'),
//                             Text('Notes: ${_getSafeString(item['notes'])}'),
                            
//                             if (item['image'] != null && item['image'].toString().isNotEmpty)
//                               Padding(
//                                 padding: const EdgeInsets.only(top: 8),
//                                 child: Image.network(
//                                   item['image'].toString(),
//                                   height: 100,
//                                   width: 100,
//                                   fit: BoxFit.cover,
//                                   errorBuilder: (_, __, ___) => 
//                                     Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     );
//                   })
//                 else
//                   Text('No items found'),
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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Purchase Orders'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: token != null ? fetchPurchaseOrders : null,
//           ),
//         ],
//       ),
//       body: token == null
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text('No authentication token found'),
//                   SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: _loadToken,
//                     child: Text('Retry'),
//                   ),
//                 ],
//               ),
//             )
//           : Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Filters, Search & Buttons Row
//                   SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: [
//                         Container(
//                           padding: EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: DropdownButtonHideUnderline(
//                             child: DropdownButton<String>(
//                               value: selectedFilter,
//                               items: filters.map((String value) {
//                                 return DropdownMenuItem<String>(
//                                   value: value,
//                                   child: Text(value),
//                                 );
//                               }).toList(),
//                               onChanged: (newValue) {
//                                 setState(() {
//                                   selectedFilter = newValue!;
//                                   filterByFilterType(newValue);
//                                 });
//                               },
//                             ),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         Container(
//                           width: 200,
//                           child: TextField(
//                             controller: searchController,
//                             decoration: InputDecoration(
//                               hintText: 'Search',
//                               prefixIcon: Icon(Icons.search, size: 20),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                             ),
//                             onChanged: (value) {
//                               searchOrders(value);
//                             },
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton.icon(
//                           onPressed: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => CreatePurchaseOrderPage(token: token!),
//                               ),
//                             ).then((value) {
//                               if (value == true) {
//                                 fetchPurchaseOrders();
//                               }
//                             });
//                           },
//                           icon: Icon(Icons.add, size: 18),
//                           label: Text('Add New'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: selectedIds.isEmpty ? null : () => _showEditDialog(),
//                           child: Text('Edit'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: selectedIds.isEmpty ? null : () {
//                             final selectedOrder = purchaseOrders.firstWhere(
//                               (order) => selectedIds.contains(_getSafeInt(order['id'])),
//                               orElse: () => {},
//                             );
//                             if (selectedOrder.isNotEmpty) {
//                               _showViewDialog(selectedOrder);
//                             }
//                           },
//                           child: Text('View'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             _showSortDialog();
//                           },
//                           child: Text('Sort'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             _showFilterDialog();
//                           },
//                           child: Text('Filter'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             _printOrders();
//                           },
//                           child: Text('Print'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: selectedIds.isEmpty ? null : () {
//                             _allocateOrders();
//                           },
//                           child: Text('Allocate'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                             backgroundColor: Colors.green,
//                             foregroundColor: Colors.white,
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: selectedIds.isEmpty ? null : () {
//                             _shareOrders();
//                           },
//                           child: Text('Share'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 20),
                  
//                   // Selection info
//                   if (selectedIds.isNotEmpty)
//                     Container(
//                       padding: EdgeInsets.all(8),
//                       margin: EdgeInsets.only(bottom: 8),
//                       decoration: BoxDecoration(
//                         color: Colors.blue.shade50,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.info, color: Colors.blue),
//                           SizedBox(width: 8),
//                           Text('Selected: ${selectedIds.length} orders'),
//                           Spacer(),
//                           TextButton(
//                             onPressed: () {
//                               setState(() {
//                                 selectedIds.clear();
//                               });
//                             },
//                             child: Text('Clear'),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   // Tabs
//                   SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: List.generate(tabs.length, (index) {
//                         return Container(
//                           margin: EdgeInsets.only(right: 8),
//                           child: FilterChip(
//                             label: Text(tabs[index]),
//                             selected: selectedTabIndex == index,
//                             selectedColor: Colors.blue,
//                             labelStyle: TextStyle(
//                               color: selectedTabIndex == index ? Colors.white : Colors.black,
//                             ),
//                             onSelected: (bool selected) {
//                               setState(() {
//                                 selectedTabIndex = selected ? index : 0;
//                                 filterByStatus(tabs[selectedTabIndex]);
//                               });
//                             },
//                           ),
//                         );
//                       }),
//                     ),
//                   ),
//                   SizedBox(height: 20),
                  
//                   // Table Header
//                   Container(
//                     decoration: BoxDecoration(
//                       color: Colors.grey[200],
//                       border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//                       borderRadius: BorderRadius.only(
//                         topLeft: Radius.circular(4),
//                         topRight: Radius.circular(4),
//                       ),
//                     ),
//                     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                     child: Row(
//                       children: [
//                         Expanded(flex: 1, child: Text('Select', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Order No', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Order Date', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 1, child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Total Weight', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
//                       ],
//                     ),
//                   ),
                  
//                   // Table Data
//                   Expanded(
//                     child: isLoading
//                         ? Center(child: CircularProgressIndicator())
//                         : purchaseOrders.isEmpty
//                             ? Center(
//                                 child: Text(
//                                   'No Purchase Orders Available',
//                                   style: TextStyle(color: Colors.grey, fontSize: 16),
//                                 ),
//                               )
//                             : ListView.builder(
//                                 itemCount: purchaseOrders.length,
//                                 itemBuilder: (context, index) {
//                                   final order = purchaseOrders[index];
//                                   if (order == null) return SizedBox.shrink();
                                  
//                                   final id = _getSafeInt(order['id']);
//                                   final isSelected = selectedIds.contains(id);
                                  
//                                   // Safely get items count
//                                   int itemsCount = 0;
//                                   if (order.containsKey('items') && order['items'] != null && order['items'] is List) {
//                                     itemsCount = (order['items'] as List).length;
//                                   }
                                  
//                                   return Container(
//                                     decoration: BoxDecoration(
//                                       color: isSelected ? Colors.blue.shade50 : null,
//                                       border: Border(
//                                         bottom: BorderSide(color: Colors.grey[300]!),
//                                       ),
//                                     ),
//                                     child: InkWell(
//                                       onTap: () {
//                                         setState(() {
//                                           if (isSelected) {
//                                             selectedIds.remove(id);
//                                           } else {
//                                             selectedIds.add(id);
//                                           }
//                                         });
//                                       },
//                                       child: Padding(
//                                         padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                                         child: Row(
//                                           children: [
//                                             Expanded(
//                                               flex: 1,
//                                               child: Checkbox(
//                                                 value: isSelected,
//                                                 onChanged: (value) {
//                                                   setState(() {
//                                                     if (value == true) {
//                                                       selectedIds.add(id);
//                                                     } else {
//                                                       selectedIds.remove(id);
//                                                     }
//                                                   });
//                                                 },
//                                               ),
//                                             ),
//                                             Expanded(flex: 2, child: Text(_getSafeString(order['order_number']))),
//                                             Expanded(flex: 2, child: Text(_getSafeString(order['order_date']))),
//                                             Expanded(flex: 2, child: Text(_getSafeString(order['due_date']))),
//                                             Expanded(flex: 1, child: Text('$itemsCount')),
//                                             Expanded(flex: 2, child: Text(
//                                               _getSafeDouble(order['total_weight_count']).toStringAsFixed(2)
//                                             )),
//                                             Expanded(
//                                               flex: 2,
//                                               child: Container(
//                                                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                                 decoration: BoxDecoration(
//                                                   color: _getStatusColor(_getSafeString(order['status'])),
//                                                   borderRadius: BorderRadius.circular(12),
//                                                 ),
//                                                 child: Text(
//                                                   _getSafeString(order['status']),
//                                                   style: TextStyle(color: Colors.white, fontSize: 12),
//                                                   textAlign: TextAlign.center,
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                   ),
                  
//                   // Pagination
//                   Container(
//                     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                     decoration: BoxDecoration(
//                       border: Border(
//                         top: BorderSide(color: Colors.grey.shade300),
//                       ),
//                     ),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           'Page $currentPage of ${totalCount > 0 ? (totalCount / pageSize).ceil() : 1} | Total: $totalCount',
//                           style: TextStyle(fontWeight: FontWeight.w500),
//                         ),
//                         Row(
//                           children: [
//                             ElevatedButton(
//                               onPressed: (prevUrl == null || prevUrl!.isEmpty) ? null : loadPrevPage,
//                               child: Text('Previous'),
//                               style: ElevatedButton.styleFrom(
//                                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                               ),
//                             ),
//                             SizedBox(width: 8),
//                             ElevatedButton(
//                               onPressed: (nextUrl == null || nextUrl!.isEmpty) ? null : loadNextPage,
//                               child: Text('Next'),
//                               style: ElevatedButton.styleFrom(
//                                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Color _getStatusColor(String? status) {
//     if (status == null) return Colors.grey;
    
//     switch (status.toLowerCase()) {
//       case 'created':
//         return Colors.blue;
//       case 'in process':
//         return Colors.orange;
//       case 'presented':
//         return Colors.green;
//       case 'rejected':
//         return Colors.red;
//       case 'allocated':
//         return Colors.purple;
//       default:
//         return Colors.grey;
//     }
//   }

//   void filterByStatus(String status) {
//     // Implement status filtering
//     print('Filtering by: $status');
//     _showSnackBar('Filtering by: $status');
//   }

//   void filterByFilterType(String filterType) {
//     // Implement filter type filtering
//     print('Filtering by: $filterType');
//     _showSnackBar('Filtering by: $filterType');
//   }

//   void searchOrders(String query) {
//     // Implement search functionality
//     print('Searching for: $query');
//   }

//   void _showSortDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Sort By'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               title: Text('Order Number'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showSnackBar('Sort by Order Number');
//               },
//             ),
//             ListTile(
//               title: Text('Order Date'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showSnackBar('Sort by Order Date');
//               },
//             ),
//             ListTile(
//               title: Text('Due Date'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showSnackBar('Sort by Due Date');
//               },
//             ),
//             ListTile(
//               title: Text('Status'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showSnackBar('Sort by Status');
//               },
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showFilterDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Filter Orders'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               title: Text('By Status'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showFilterByStatusDialog();
//               },
//             ),
//             ListTile(
//               title: Text('By Date Range'),
//               onTap: () {
//                 Navigator.pop(context);
//                 _showSnackBar('Filter by Date Range');
//               },
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showFilterByStatusDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Filter by Status'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: tabs.map((status) {
//             return ListTile(
//               title: Text(status),
//               onTap: () {
//                 Navigator.pop(context);
//                 filterByStatus(status);
//               },
//             );
//           }).toList(),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showEditDialog() {
//     _showSnackBar('Edit functionality coming soon');
//   }

//   void _printOrders() {
//     if (selectedIds.isEmpty) {
//       _showSnackBar('Please select orders to print', isError: true);
//       return;
//     }
//     _showSnackBar('Print functionality coming soon');
//   }

//   void _allocateOrders() {
//     if (selectedIds.isEmpty) {
//       _showSnackBar('Please select orders to allocate', isError: true);
//       return;
//     }
//     _showSnackBar('Allocate functionality coming soon');
//   }

//   void _shareOrders() {
//     if (selectedIds.isEmpty) {
//       _showSnackBar('Please select orders to share', isError: true);
//       return;
//     }
//     _showSnackBar('Share functionality coming soon');
//   }
// }

// class CreatePurchaseOrderPage extends StatefulWidget {
//   final String token;
  
//   CreatePurchaseOrderPage({required this.token});

//   @override
//   _CreatePurchaseOrderPageState createState() => _CreatePurchaseOrderPageState();
// }

// class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
//   DateTime? selectedDate;
//   TextEditingController dueDateController = TextEditingController();
//   TextEditingController noteController = TextEditingController();
//   List<Map<String, dynamic>> items = [];
//   bool isSubmitting = false;
  
//   final List<String> categories = ["Gold", "Silver", "Diamond", "Platinum"];
//   final List<String> subCategories = ["Rings", "Chains", "Pendants", "Bangles", "Earrings", "Necklaces", "Bracelets"];
//   final List<String> designs = ["Knot Rope", "Plain", "Fancy", "Custom", "Traditional", "Modern"];

//   @override
//   void dispose() {
//     dueDateController.dispose();
//     noteController.dispose();
//     super.dispose();
//   }

//   Future<void> createPurchaseOrder() async {
//     if (dueDateController.text.isEmpty) {
//       _showSnackBar('Please select a due date', isError: true);
//       return;
//     }

//     if (items.isEmpty) {
//       _showSnackBar('Please add at least one item', isError: true);
//       return;
//     }

//     setState(() => isSubmitting = true);

//     try {
//       final url = Uri.parse('http://127.0.0.1:8000/PurchaseOrder/PurchaseOrder/create/');
      
//       // Prepare the data according to backend format
//       Map<String, dynamic> orderData = {
//         'due_date': dueDateController.text,
//         'note': noteController.text,
//         'items': items.map((item) {
//           return {
//             'product_category': item['category'] ?? '',
//             'sub_category': item['subCategory'] ?? '',
//             'design': [item['design'] ?? ''], // Backend expects array
//             'grams': (item['grams'] ?? 0).toString(),
//             'quantity': (item['qty'] ?? 0).toString(),
//             'total_weight': (item['total'] ?? 0).toDouble(),
//             'notes': item['note'] ?? '',
//             'image': '', // Add image handling if needed
//           };
//         }).toList(),
//       };

//       print('Sending order data: $orderData');

//       final response = await http.post(
//         url,
//         headers: {
//           'Authorization': 'Token ${widget.token}',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode(orderData),
//       );

//       print('Response status: ${response.statusCode}');
//       print('Response body: ${response.body}');

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         _showSnackBar('Purchase order created successfully!');
//         Navigator.pop(context, true);
//       } else {
//         _showSnackBar('Failed to create purchase order: ${response.statusCode}', isError: true);
//       }
//     } catch (e) {
//       print('Error creating purchase order: $e');
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isSubmitting = false);
//     }
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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create Purchase Order'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Due Date + Note Section
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: dueDateController,
//                     decoration: InputDecoration(
//                       labelText: "Due Date *",
//                       border: OutlineInputBorder(),
//                       suffixIcon: IconButton(
//                         icon: Icon(Icons.calendar_today),
//                         onPressed: () async {
//                           final DateTime? picked = await showDatePicker(
//                             context: context,
//                             initialDate: DateTime.now(),
//                             firstDate: DateTime(2000),
//                             lastDate: DateTime(2100),
//                           );
//                           if (picked != null) {
//                             setState(() {
//                               selectedDate = picked;
//                               dueDateController.text =
//                                   "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
//                             });
//                           }
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 20),
//                 Expanded(
//                   child: TextField(
//                     controller: noteController,
//                     decoration: InputDecoration(
//                       labelText: "Note",
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 20),

//             // Table Header
//             Container(
//               color: Colors.grey[200],
//               padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//               child: Row(
//                 children: [
//                   Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Sub Category", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Design", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Grams", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 1, child: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Notes", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 1, child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
//                 ],
//               ),
//             ),

//             // Dynamic Rows
//             Expanded(
//               child: ListView.builder(
//                 itemCount: items.length,
//                 itemBuilder: (context, index) {
//                   var item = items[index];
//                   if (item == null) return SizedBox.shrink();
                  
//                   return Container(
//                     padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//                     decoration: BoxDecoration(
//                       border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(flex: 1, child: Text("${index + 1}")),

//                         // Category Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<String>(
//                             value: item.containsKey('category') && item['category'] != null && categories.contains(item['category'])
//                                 ? item['category']
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             items: categories.map((cat) {
//                               return DropdownMenuItem(
//                                 value: cat,
//                                 child: Text(cat),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item['category'] = val;
//                               });
//                             },
//                           ),
//                         ),

//                         // Sub Category Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<String>(
//                             value: item.containsKey('subCategory') && item['subCategory'] != null && subCategories.contains(item['subCategory'])
//                                 ? item['subCategory']
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             items: subCategories.map((cat) {
//                               return DropdownMenuItem(
//                                 value: cat,
//                                 child: Text(cat),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item['subCategory'] = val;
//                               });
//                             },
//                           ),
//                         ),

//                         // Design Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<String>(
//                             value: item.containsKey('design') && item['design'] != null && designs.contains(item['design'])
//                                 ? item['design']
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             items: designs.map((des) {
//                               return DropdownMenuItem(
//                                 value: des,
//                                 child: Text(des),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item['design'] = val;
//                               });
//                             },
//                           ),
//                         ),

//                         // Grams
//                         Expanded(
//                           flex: 2,
//                           child: TextFormField(
//                             keyboardType: TextInputType.number,
//                             decoration: InputDecoration(
//                               hintText: "Grams",
//                               border: InputBorder.none,
//                             ),
//                             initialValue: item['grams']?.toString() ?? '',
//                             onChanged: (val) {
//                               setState(() {
//                                 item['grams'] = double.tryParse(val) ?? 0;
//                                 item['total'] = (item['grams'] ?? 0) * (item['qty'] ?? 0);
//                               });
//                             },
//                           ),
//                         ),

//                         // Quantity
//                         Expanded(
//                           flex: 1,
//                           child: TextFormField(
//                             keyboardType: TextInputType.number,
//                             decoration: InputDecoration(
//                               hintText: "Qty",
//                               border: InputBorder.none,
//                             ),
//                             initialValue: item['qty']?.toString() ?? '',
//                             onChanged: (val) {
//                               setState(() {
//                                 item['qty'] = int.tryParse(val) ?? 0;
//                                 item['total'] = (item['grams'] ?? 0) * (item['qty'] ?? 0);
//                               });
//                             },
//                           ),
//                         ),

//                         // Total Weight
//                         Expanded(
//                           flex: 2,
//                           child: Text(
//                             item['total'] != null 
//                               ? item['total'].toStringAsFixed(2) 
//                               : "0.00"
//                           ),
//                         ),

//                         // Notes
//                         Expanded(
//                           flex: 2,
//                           child: TextFormField(
//                             initialValue: item['note'] ?? '',
//                             decoration: InputDecoration(
//                               hintText: "Notes",
//                               border: InputBorder.none,
//                             ),
//                             onChanged: (val) {
//                               item['note'] = val;
//                             },
//                           ),
//                         ),

//                         // Remove Action
//                         Expanded(
//                           flex: 1,
//                           child: IconButton(
//                             icon: Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 items.removeAt(index);
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),

//             // Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     setState(() {
//                       items.add({
//                         "category": categories.isNotEmpty ? categories[0] : null,
//                         "subCategory": subCategories.isNotEmpty ? subCategories[0] : null,
//                         "design": designs.isNotEmpty ? designs[0] : null,
//                         "grams": 0.0,
//                         "qty": 0,
//                         "total": 0.0,
//                         "note": ""
//                       });
//                     });
//                   },
//                   icon: Icon(Icons.add),
//                   label: Text("Add Item"),
//                 ),
//                 SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: isSubmitting ? null : createPurchaseOrder,
//                   child: isSubmitting
//                       ? SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         )
//                       : Text("Create Order"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }









// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:image_picker/image_picker.dart';
// import 'dart:io' show File;

// class PurchaseOrderPage extends StatefulWidget {
//   @override
//   _PurchaseOrderPageState createState() => _PurchaseOrderPageState();
// }

// class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
//   String selectedFilter = 'Specific';
//   TextEditingController searchController = TextEditingController();
//   String? token;
//   bool isLoading = true;
//   List<Map<String, dynamic>> purchaseOrders = [];

//   final List<String> filters = ['Specific', 'All', 'Pending'];
//   final List<String> tabs = ['Created', 'In Process', 'Presented', 'Rejected'];
//   int selectedTabIndex = 0;

//   @override
//   void initState() {
//     super.initState();
//     _loadToken();
//   }

//   Future<void> _loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     setState(() {
//       token = prefs.getString('token');
//     });
    
//     if (token != null && token!.isNotEmpty) {
//       fetchPurchaseOrders();
//     } else {
//       setState(() => isLoading = false);
//       _showSnackBar('No token found. Please login again.', isError: true);
//     }
//   }

//   Future<void> fetchPurchaseOrders() async {
//     if (token == null) return;
    
//     setState(() => isLoading = true);
//     final url = Uri.parse('http://127.0.0.1:8000/PurchaseOrder/PurchaseOrder/list/');
//     try {
//       final response = await http.get(
//         url,
//         headers: {'Authorization': 'Token $token'},
//       );
      
//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);
//         List<Map<String, dynamic>> list = [];
//         if (decoded is List) {
//           list = List<Map<String, dynamic>>.from(decoded);
//         } else if (decoded is Map && decoded.containsKey('results')) {
//           list = List<Map<String, dynamic>>.from(decoded['results']);
//         }
//         setState(() {
//           purchaseOrders = list;
//           isLoading = false;
//         });
//       } else {
//         print('Failed to fetch purchase orders: ${response.statusCode} | ${response.body}');
//         setState(() => isLoading = false);
//         _showSnackBar('Failed to fetch purchase orders', isError: true);
//       }
//     } catch (e) {
//       print('Error fetching purchase orders: $e');
//       setState(() => isLoading = false);
//       _showSnackBar('Error: $e', isError: true);
//     }
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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Purchase Orders'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: token != null ? fetchPurchaseOrders : null,
//           ),
//         ],
//       ),
//       body: token == null
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text('No authentication token found'),
//                   SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: _loadToken,
//                     child: Text('Retry'),
//                   ),
//                 ],
//               ),
//             )
//           : Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Filters, Search & Buttons Row
//                   SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: [
//                         Container(
//                           padding: EdgeInsets.symmetric(horizontal: 12),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                           child: DropdownButtonHideUnderline(
//                             child: DropdownButton<String>(
//                               value: selectedFilter,
//                               items: filters.map((String value) {
//                                 return DropdownMenuItem<String>(
//                                   value: value,
//                                   child: Text(value),
//                                 );
//                               }).toList(),
//                               onChanged: (newValue) {
//                                 setState(() {
//                                   selectedFilter = newValue!;
//                                   // Apply filter based on selection
//                                   if (newValue == 'All') {
//                                     // Show all orders
//                                   } else if (newValue == 'Pending') {
//                                     // Show pending orders only
//                                   }
//                                 });
//                               },
//                             ),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         Container(
//                           width: 200,
//                           child: TextField(
//                             controller: searchController,
//                             decoration: InputDecoration(
//                               hintText: 'Search',
//                               prefixIcon: Icon(Icons.search, size: 20),
//                               border: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(4),
//                               ),
//                               contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                             ),
//                             onChanged: (value) {
//                               // Implement search functionality
//                             },
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton.icon(
//                           onPressed: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => CreatePurchaseOrderPage(token: token!),
//                               ),
//                             ).then((value) {
//                               if (value == true) {
//                                 fetchPurchaseOrders();
//                               }
//                             });
//                           },
//                           icon: Icon(Icons.add, size: 18),
//                           label: Text('Add New'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             // Edit functionality
//                           },
//                           child: Text('Edit'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             // View functionality
//                           },
//                           child: Text('View'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             _showSortDialog();
//                           },
//                           child: Text('Sort'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             _showFilterDialog();
//                           },
//                           child: Text('Filter'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             // Print functionality
//                           },
//                           child: Text('Print'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             // Allocate functionality
//                           },
//                           child: Text('Allocate'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                             backgroundColor: Colors.green,
//                             foregroundColor: Colors.white,
//                           ),
//                         ),
//                         SizedBox(width: 10),
//                         ElevatedButton(
//                           onPressed: () {
//                             // Share functionality
//                           },
//                           child: Text('Share'),
//                           style: ElevatedButton.styleFrom(
//                             padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   // Tabs
//                   SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: Row(
//                       children: List.generate(tabs.length, (index) {
//                         return Container(
//                           margin: EdgeInsets.only(right: 8),
//                           child: ChoiceChip(
//                             label: Text(tabs[index]),
//                             selected: selectedTabIndex == index,
//                             selectedColor: Colors.blue,
//                             labelStyle: TextStyle(
//                               color: selectedTabIndex == index ? Colors.white : Colors.black,
//                             ),
//                             onSelected: (bool selected) {
//                               setState(() {
//                                 selectedTabIndex = selected ? index : 0;
//                                 // Filter by status based on tab
//                                 filterByStatus(tabs[selectedTabIndex]);
//                               });
//                             },
//                           ),
//                         );
//                       }),
//                     ),
//                   ),
//                   SizedBox(height: 20),
//                   // Table Header
//                   Container(
//                     decoration: BoxDecoration(
//                       color: Colors.grey[200],
//                       border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//                     ),
//                     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                     child: Row(
//                       children: [
//                         Expanded(flex: 2, child: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 1, child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Total Weight', style: TextStyle(fontWeight: FontWeight.bold))),
//                         Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
//                       ],
//                     ),
//                   ),
//                   // Table Data
//                   Expanded(
//                     child: isLoading
//                         ? Center(child: CircularProgressIndicator())
//                         : purchaseOrders.isEmpty
//                             ? Center(
//                                 child: Text(
//                                   'No Purchase Orders Available',
//                                   style: TextStyle(color: Colors.grey, fontSize: 16),
//                                 ),
//                               )
//                             : ListView.builder(
//                                 itemCount: purchaseOrders.length,
//                                 itemBuilder: (context, index) {
//                                   final order = purchaseOrders[index];
//                                   return Container(
//                                     decoration: BoxDecoration(
//                                       border: Border(
//                                         bottom: BorderSide(color: Colors.grey[300]!),
//                                       ),
//                                     ),
//                                     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                                     child: Row(
//                                       children: [
//                                         Expanded(flex: 2, child: Text(order['order_no']?.toString() ?? '')),
//                                         Expanded(flex: 2, child: Text(order['created_date']?.toString() ?? '')),
//                                         Expanded(flex: 2, child: Text(order['due_date']?.toString() ?? '')),
//                                         Expanded(flex: 1, child: Text(order['items_count']?.toString() ?? '0')),
//                                         Expanded(flex: 2, child: Text(order['total_weight']?.toString() ?? '0')),
//                                         Expanded(
//                                           flex: 2,
//                                           child: Container(
//                                             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                                             decoration: BoxDecoration(
//                                               color: _getStatusColor(order['status']),
//                                               borderRadius: BorderRadius.circular(12),
//                                             ),
//                                             child: Text(
//                                               order['status']?.toString() ?? '',
//                                               style: TextStyle(color: Colors.white, fontSize: 12),
//                                               textAlign: TextAlign.center,
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                               ),
//                   ),
//                 ],
//               ),
//             ),
//     );
//   }

//   Color _getStatusColor(String? status) {
//     switch (status?.toLowerCase()) {
//       case 'created':
//         return Colors.blue;
//       case 'in process':
//         return Colors.orange;
//       case 'presented':
//         return Colors.green;
//       case 'rejected':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }

//   void filterByStatus(String status) {
//     // Implement status filtering
//     print('Filtering by: $status');
//   }

//   void _showSortDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Sort By'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ListTile(
//               title: Text('Order ID'),
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement sort by order ID
//               },
//             ),
//             ListTile(
//               title: Text('Created Date'),
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement sort by created date
//               },
//             ),
//             ListTile(
//               title: Text('Due Date'),
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement sort by due date
//               },
//             ),
//             ListTile(
//               title: Text('Status'),
//               onTap: () {
//                 Navigator.pop(context);
//                 // Implement sort by status
//               },
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showFilterDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Filter Orders'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Add filter options here
//             Text('Filter options coming soon...'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               // Apply filters
//             },
//             child: Text('Apply'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class CreatePurchaseOrderPage extends StatefulWidget {
//   final String token;
  
//   CreatePurchaseOrderPage({required this.token});

//   @override
//   _CreatePurchaseOrderPageState createState() => _CreatePurchaseOrderPageState();
// }

// class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
//   DateTime? selectedDate;
//   TextEditingController dueDateController = TextEditingController();
//   TextEditingController noteController = TextEditingController();
//   List<Map<String, dynamic>> items = [];
//   bool isSubmitting = false;
  
//   final List<String> categories = ["Bangles", "Chains", "Rings", "Earrings", "Pendants", "Necklaces"];
//   final List<String> designs = ["Knot Rope", "Plain", "Fancy", "Custom", "Traditional", "Modern"];

//   @override
//   void dispose() {
//     dueDateController.dispose();
//     noteController.dispose();
//     super.dispose();
//   }

//   Future<void> createPurchaseOrder() async {
//     if (dueDateController.text.isEmpty) {
//       _showSnackBar('Please select a due date', isError: true);
//       return;
//     }

//     if (items.isEmpty) {
//       _showSnackBar('Please add at least one item', isError: true);
//       return;
//     }

//     setState(() => isSubmitting = true);

//     try {
//       final url = Uri.parse('http://127.0.0.1:8000/purchase/orders/create/');
      
//       // Prepare the data
//       Map<String, dynamic> orderData = {
//         'due_date': dueDateController.text,
//         'note': noteController.text,
//         'items': items.map((item) => {
//           'category': item['category'],
//           'design': item['design'],
//           'grams': item['grams'] ?? 0,
//           'quantity': item['qty'] ?? 0,
//           'total_weight': item['total'] ?? 0,
//           'notes': item['note'] ?? '',
//         }).toList(),
//       };

//       final response = await http.post(
//         url,
//         headers: {
//           'Authorization': 'Token ${widget.token}',
//           'Content-Type': 'application/json',
//         },
//         body: json.encode(orderData),
//       );

//       if (response.statusCode == 201 || response.statusCode == 200) {
//         _showSnackBar('Purchase order created successfully!');
//         Navigator.pop(context, true);
//       } else {
//         print('Failed to create purchase order: ${response.statusCode} | ${response.body}');
//         _showSnackBar('Failed to create purchase order', isError: true);
//       }
//     } catch (e) {
//       print('Error creating purchase order: $e');
//       _showSnackBar('Error: $e', isError: true);
//     } finally {
//       setState(() => isSubmitting = false);
//     }
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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create Purchase Order'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Due Date + Note Section
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: dueDateController,
//                     decoration: InputDecoration(
//                       labelText: "Due Date *",
//                       border: OutlineInputBorder(),
//                       suffixIcon: IconButton(
//                         icon: Icon(Icons.calendar_today),
//                         onPressed: () async {
//                           final DateTime? picked = await showDatePicker(
//                             context: context,
//                             initialDate: DateTime.now(),
//                             firstDate: DateTime(2000),
//                             lastDate: DateTime(2100),
//                           );
//                           if (picked != null) {
//                             setState(() {
//                               selectedDate = picked;
//                               dueDateController.text =
//                                   "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
//                             });
//                           }
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 20),
//                 Expanded(
//                   child: TextField(
//                     controller: noteController,
//                     decoration: InputDecoration(
//                       labelText: "Note",
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 20),

//             // Table Header
//             Container(
//               color: Colors.grey[200],
//               padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//               child: Row(
//                 children: [
//                   Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Design", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Grams & Qty", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Total Weight", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Notes", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 1, child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
//                 ],
//               ),
//             ),

//             // Dynamic Rows
//             Expanded(
//               child: ListView.builder(
//                 itemCount: items.length,
//                 itemBuilder: (context, index) {
//                   var item = items[index];
//                   return Container(
//                     padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//                     decoration: BoxDecoration(
//                       border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(flex: 1, child: Text("${index + 1}")),

//                         // Category Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<String>(
//                             value: categories.contains(item["category"])
//                                 ? item["category"]
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             items: categories.map((cat) {
//                               return DropdownMenuItem(
//                                 value: cat,
//                                 child: Text(cat),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item["category"] = val!;
//                               });
//                             },
//                           ),
//                         ),

//                         // Design Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<String>(
//                             value: designs.contains(item["design"])
//                                 ? item["design"]
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             decoration: InputDecoration(
//                               border: InputBorder.none,
//                             ),
//                             items: designs.map((des) {
//                               return DropdownMenuItem(
//                                 value: des,
//                                 child: Text(des),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item["design"] = val!;
//                               });
//                             },
//                           ),
//                         ),

//                         // Grams & Quantity
//                         Expanded(
//                           flex: 2,
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: TextFormField(
//                                   keyboardType: TextInputType.number,
//                                   decoration: InputDecoration(
//                                     hintText: "Gram",
//                                     border: InputBorder.none,
//                                   ),
//                                   initialValue: item["grams"]?.toString() ?? '',
//                                   onChanged: (val) {
//                                     setState(() {
//                                       item["grams"] = int.tryParse(val) ?? 0;
//                                       item["total"] = (item["grams"] ?? 0) * (item["qty"] ?? 0);
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 5),
//                               Expanded(
//                                 child: TextFormField(
//                                   keyboardType: TextInputType.number,
//                                   decoration: InputDecoration(
//                                     hintText: "Qty",
//                                     border: InputBorder.none,
//                                   ),
//                                   initialValue: item["qty"]?.toString() ?? '',
//                                   onChanged: (val) {
//                                     setState(() {
//                                       item["qty"] = int.tryParse(val) ?? 0;
//                                       item["total"] = (item["grams"] ?? 0) * (item["qty"] ?? 0);
//                                     });
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         // Total Weight
//                         Expanded(
//                           flex: 2,
//                           child: Text(item["total"]?.toString() ?? "0"),
//                         ),

//                         // Notes
//                         Expanded(
//                           flex: 2,
//                           child: TextFormField(
//                             initialValue: item["note"] ?? '',
//                             decoration: InputDecoration(
//                               hintText: "Notes",
//                               border: InputBorder.none,
//                             ),
//                             onChanged: (val) {
//                               item["note"] = val;
//                             },
//                           ),
//                         ),

//                         // Remove Action
//                         Expanded(
//                           flex: 1,
//                           child: IconButton(
//                             icon: Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 items.removeAt(index);
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),

//             // Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     setState(() {
//                       items.add({
//                         "category": categories.isNotEmpty ? categories[0] : null,
//                         "design": designs.isNotEmpty ? designs[0] : null,
//                         "grams": 0,
//                         "qty": 0,
//                         "total": 0,
//                         "note": ""
//                       });
//                     });
//                   },
//                   icon: Icon(Icons.add),
//                   label: Text("Add Item"),
//                 ),
//                 SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: isSubmitting ? null : createPurchaseOrder,
//                   child: isSubmitting
//                       ? SizedBox(
//                           height: 20,
//                           width: 20,
//                           child: CircularProgressIndicator(strokeWidth: 2),
//                         )
//                       : Text("Create Order"),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }






// import 'package:flutter/material.dart';
// // import 'package:url_launcher/url_launcher.dart';
// // import '../services/auth_service.dart';
// // import 'package:intl/intl.dart';
// // import 'package:http/http.dart' as http;
// // import 'dart:convert';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'dart:io' show File;
// // import 'package:path/path.dart' as path;



// class PurchaseOrderPage extends StatefulWidget {
//   @override
//   _PurchaseOrderPageState createState() => _PurchaseOrderPageState();
// }

// class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
//   String selectedFilter = 'Specific';
//   TextEditingController searchController = TextEditingController();

//   final List<String> filters = ['Specific', 'All', 'Pending'];
//   final List<String> tabs = ['Created', 'In Process', 'Presented', 'Rejected'];
//   int selectedTabIndex = 0;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Purchase Orders'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Filters, Search & Buttons Row
//             SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: [
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 12),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.grey),
//                       borderRadius: BorderRadius.circular(4),
//                     ),
//                     child: DropdownButtonHideUnderline(
//                       child: DropdownButton<String>(
//                         value: selectedFilter,
//                         items: filters.map((String value) {
//                           return DropdownMenuItem<String>(
//                             value: value,
//                             child: Text(value),
//                           );
//                         }).toList(),
//                         onChanged: (newValue) {
//                           setState(() {
//                             selectedFilter = newValue!;
//                           });
//                         },
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   Container(
//                     width: 200,
//                     child: TextField(
//                       controller: searchController,
//                       decoration: InputDecoration(
//                         hintText: 'Search',
//                         prefixIcon: Icon(Icons.search, size: 20),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                         contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton.icon(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => CreatePurchaseOrderPage()),
//                       );
//                     },
//                     icon: Icon(Icons.add, size: 18),
//                     label: Text('Add New'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('Edit'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('View'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('Sort'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('Filter'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('Print'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('Allocate'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                       backgroundColor: Colors.green,
//                     ),
//                   ),
//                   SizedBox(width: 10),
//                   ElevatedButton(
//                     onPressed: () {},
//                     child: Text('Share'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(height: 20),
//             // Tabs
//             SingleChildScrollView(
//               scrollDirection: Axis.horizontal,
//               child: Row(
//                 children: List.generate(tabs.length, (index) {
//                   return Container(
//                     margin: EdgeInsets.only(right: 8),
//                     child: ChoiceChip(
//                       label: Text(tabs[index]),
//                       selected: selectedTabIndex == index,
//                       selectedColor: Colors.blue,
//                       labelStyle: TextStyle(
//                         color: selectedTabIndex == index ? Colors.white : Colors.black,
//                       ),
//                       onSelected: (bool selected) {
//                         setState(() {
//                           selectedTabIndex = selected ? index : 0;
//                         });
//                       },
//                     ),
//                   );
//                 }),
//               ),
//             ),
//             SizedBox(height: 20),
//             // Table Header
//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.grey[200],
//                 border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//               ),
//               padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//               child: Row(
//                 children: [
//                   Expanded(flex: 2, child: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 1, child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text('Total Weight', style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
//                 ],
//               ),
//             ),
//             // Table Data (Empty for now)
//             Expanded(
//               child: Center(
//                 child: Text(
//                   'No Purchase Orders Available',
//                   style: TextStyle(color: Colors.grey, fontSize: 16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }



// class CreatePurchaseOrderPage extends StatefulWidget {
//   @override
//   _CreatePurchaseOrderPageState createState() =>
//       _CreatePurchaseOrderPageState();
// }

// class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
//   DateTime? selectedDate;
//   TextEditingController dueDateController = TextEditingController();
//   TextEditingController noteController = TextEditingController();
//   List<Map<String, dynamic>> items = [];
//   final List<String> categories = ["Bangles", "Chains", "Rings", "Earrings"];
//   final List<String> designs = ["Knot Rope", "Plain", "Fancy", "Custom"];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Create Purchase Order'),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ✅ Due Date + Note Section
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: dueDateController,
//                     decoration: InputDecoration(
//                       labelText: "Due Date",
//                       border: OutlineInputBorder(),
//                       suffixIcon: IconButton(
//                         icon: Icon(Icons.calendar_today),
//                         onPressed: () async {
//                           final DateTime? picked = await showDatePicker(
//                             context: context,
//                             initialDate: DateTime.now(),
//                             firstDate: DateTime(2000),
//                             lastDate: DateTime(2100),
//                           );
//                           if (picked != null) {
//                             setState(() {
//                               selectedDate = picked;
//                               dueDateController.text =
//                                   "${picked.month}/${picked.day}/${picked.year}";
//                             });
//                           }
//                         },
//                       ),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 20),
//                 Expanded(
//                   child: TextField(
//                     controller: noteController,
//                     decoration: InputDecoration(
//                       labelText: "Note",
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 20),

//             // ✅ Table Header
//             Container(
//               color: Colors.grey[200],
//               padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//               child: Row(
//                 children: [
//                   Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Design", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Grams & Qty", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Total Weight", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 2, child: Text("Notes", style: TextStyle(fontWeight: FontWeight.bold))),
//                   Expanded(flex: 1, child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
//                 ],
//               ),
//             ),

//             // ✅ Dynamic Rows
//             Expanded(
//               child: ListView.builder(
//                 itemCount: items.length,
//                 itemBuilder: (context, index) {
//                   var item = items[index];
//                   return Container(
//                     padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
//                     decoration: BoxDecoration(
//                       border: Border(bottom: BorderSide(color: Colors.grey)),
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(flex: 1, child: Text("${index + 1}")), // ✅ S.No

//                         // ✅ Category Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButton<String>(
//                             value: categories.contains(item["category"])
//                                 ? item["category"]
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             items: categories.map((cat) {
//                               return DropdownMenuItem(
//                                 value: cat,
//                                 child: Text(cat),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item["category"] = val!;
//                               });
//                             },
//                           ),
//                         ),

//                         // ✅ Design Dropdown
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButton<String>(
//                             value: designs.contains(item["design"])
//                                 ? item["design"]
//                                 : null,
//                             hint: Text("Select"),
//                             isExpanded: true,
//                             items: designs.map((des) {
//                               return DropdownMenuItem(
//                                 value: des,
//                                 child: Text(des),
//                               );
//                             }).toList(),
//                             onChanged: (val) {
//                               setState(() {
//                                 item["design"] = val!;
//                               });
//                             },
//                           ),
//                         ),

//                         // ✅ Grams & Quantity
//                         Expanded(
//                           flex: 2,
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: TextField(
//                                   keyboardType: TextInputType.number,
//                                   decoration: InputDecoration(hintText: "Gram"),
//                                   onChanged: (val) {
//                                     setState(() {
//                                       item["grams"] = int.tryParse(val) ?? 0;
//                                       item["total"] =
//                                           item["grams"] * item["qty"];
//                                     });
//                                   },
//                                 ),
//                               ),
//                               SizedBox(width: 5),
//                               Expanded(
//                                 child: TextField(
//                                   keyboardType: TextInputType.number,
//                                   decoration: InputDecoration(hintText: "Qty"),
//                                   onChanged: (val) {
//                                     setState(() {
//                                       item["qty"] = int.tryParse(val) ?? 0;
//                                       item["total"] =
//                                           item["grams"] * item["qty"];
//                                     });
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         // ✅ Total Weight
//                         Expanded(
//                           flex: 2,
//                           child: Text("${item["total"]}"),
//                         ),

//                         // ✅ Notes
//                         Expanded(
//                           flex: 2,
//                           child: TextField(
//                             decoration: InputDecoration(hintText: "Notes"),
//                             onChanged: (val) {
//                               item["note"] = val;
//                             },
//                           ),
//                         ),
//                         // ✅ Remove Action
//                         Expanded(
//                           flex: 1,
//                           child: IconButton(
//                             icon: Icon(Icons.delete, color: Colors.red),
//                             onPressed: () {
//                               setState(() {
//                                 items.removeAt(index);
//                               });
//                             },
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       items.add({
//                         "category": categories.isNotEmpty ? categories[0] : null,
//                         "design": designs.isNotEmpty ? designs[0] : null,
//                         "grams": 0,
//                         "qty": 0,
//                         "total": 0,
//                         "note": ""
//                       });
//                     });
//                   },
//                   child: Text("Add Item"),
//                 ),
//                 SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: () {
//                     print("Final Items: $items");
//                   },
//                   child: Text("Create Order"),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
