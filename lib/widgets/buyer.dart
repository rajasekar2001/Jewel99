import 'package:flutter/material.dart';
import '../models/buyer.dart';
import '../services/api_service.dart';

class BuyerPage extends StatefulWidget {
  @override
  _BuyerPageState createState() => _BuyerPageState();
}

class _BuyerPageState extends State<BuyerPage> {
  late Future<List<Buyer>> futureBuyers;
  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    futureBuyers = BuyerApiService.fetchBuyers();
  }

  Future<void> _refreshData() async {
    setState(() {
      futureBuyers = BuyerApiService.fetchBuyers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Buyers'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: FutureBuilder<List<Buyer>>(
        future: futureBuyers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No buyers found'));
          } else {
            return _buildBuyerList(snapshot.data!);
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add navigation to create new buyer
        },
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildBuyerList(List<Buyer> buyers) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: buyers.length,
        itemBuilder: (context, index) {
          final buyer = buyers[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: CircleAvatar(
                child: Text(buyer.businessName.substring(0, 1)),
              ),
              title: Text(
                buyer.businessName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text('Contact: ${buyer.name}'),
                  Text('Mobile: ${buyer.mobile}'),
                  Text('Email: ${buyer.email}'),
                  Text('Pincode: ${buyer.pincode}'),
                ],
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () {
                _showBuyerDetails(context, buyer);
              },
            ),
          );
        },
      ),
    );
  }

  void _showBuyerDetails(BuildContext context, Buyer buyer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(buyer.businessName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('BP Code', buyer.bpCode),
              _buildDetailRow('Contact Person', buyer.name),
              _buildDetailRow('Mobile', buyer.mobile),
              _buildDetailRow('Email', buyer.email),
              _buildDetailRow('Pincode', buyer.pincode),
              _buildDetailRow('Role', buyer.role),
            ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'N/A' : value),
          ),
        ],
      ),
    );
  }
}