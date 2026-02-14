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


class AppColors {
  static const background = Color(0xFFF8FAFC);
  static const primaryText = Color(0xFF1E293B);
  static const secondaryText = Color(0xFF64748B);
  static const cardBackground = Colors.white;
  static const iconBackground = Color(0xFFF1F5F9);
  static const warningColor = Color(0xFFFFA500);
  static const successColor = Color(0xFF22C55E);
}

class CustomCalendar extends StatefulWidget {
  @override
  _CustomCalendarState createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDay;
  List<DateTime> _daysWithMeetings = [
    DateTime.now().subtract(Duration(days: 1)),
    DateTime.now().add(Duration(days: 2)),
  ];

  static const double inch = 96.0;
  @override
  Widget build(BuildContext context) {
    List<DateTime> daysInMonth = _generateDaysForMonth(_currentMonth);

    return Center(
      child: Transform.translate(
        offset: Offset(55, -90),
        child: SizedBox(
          width: 3 * inch,
          height: 4 * inch,
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== HEADER WITH NAVIGATION =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(
                              _currentMonth.year,
                              _currentMonth.month - 1,
                            );
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_currentMonth),
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(
                              _currentMonth.year,
                              _currentMonth.month + 1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 6),

                  // ===== WEEKDAY HEADER =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10,
                                      color: Colors.grey[600]),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  SizedBox(height: 4),

                  // ===== CALENDAR GRID =====
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: daysInMonth.length,
                      itemBuilder: (context, index) {
                        DateTime day = daysInMonth[index];
                        bool isToday = _isSameDay(day, DateTime.now());
                        bool isSelected =
                            _isSameDay(day, _selectedDay ?? DateTime(2000));
                        bool isOtherMonth = day.month != _currentMonth.month;
                        bool hasMeetings = _daysWithMeetings
                            .any((m) => _isSameDay(m, day));
                        Color bgColor = Colors.transparent;
                        Color textColor = isOtherMonth
                            ? Colors.grey[400]!
                            : Colors.black87;
                        if (hasMeetings) textColor = Colors.white;
                        if (isSelected) {
                          bgColor = Colors.grey[600]!;
                          textColor = Colors.white;
                        }
                        if (isToday) {
                          bgColor = Color(0xFF1a73e8);
                          textColor = Colors.white;
                        }
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDay = day;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                    fontSize: 10, color: textColor),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8),

                  // ===== MEETINGS HEADER =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Meetings",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Colors.grey[800]),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1a73e8),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text(
                          "+ Add Meeting",
                          style:
                              TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),

                  // ===== MEETINGS LIST =====
                  Center(
                    child: Text(
                      "No meetings scheduled.",
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DateTime> _generateDaysForMonth(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = (firstDayOfMonth.weekday + 6) % 7;
    final daysBefore = firstWeekday;

    final lastDayOfMonth =
        DateTime(month.year, month.month + 1, 0).day;
    final totalDays = daysBefore + lastDayOfMonth;
    final weeks = (totalDays / 7).ceil();
    final daysAfter = weeks * 7 - totalDays;

    List<DateTime> days = [];
    for (int i = 0; i < daysBefore; i++) {
      days.add(firstDayOfMonth.subtract(Duration(days: daysBefore - i)));
    }
    for (int i = 0; i < lastDayOfMonth; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    for (int i = 0; i < daysAfter; i++) {
      days.add(DateTime(month.year, month.month + 1, i + 1));
    }
    return days;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// ------------------- DASHBOARD SCREEN -------------------
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int buyerCount = 0;
  int craftsmanCount = 0;
  final authService = AuthService.instance;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final buyers = await fetchBuyerCount();
    final craftsmen = await fetchCraftsmanCount();
    setState(() {
      buyerCount = buyers;
      craftsmanCount = craftsmen;
    });
  }

  Future<int> fetchBuyerCount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 4;
  }

  Future<int> fetchCraftsmanCount() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: const Color(0xFF1E1E2C),
            child: Column(
              children: [
                // Logo/Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu),
                        color: Colors.white,
                        iconSize: 24,
                        onPressed: () {},
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'JEWEL99',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ],
                  ),
                ),
                // User details
                _buildUserInfo(),
                // Scrollable menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _menuItem('Dashboard', Icons.dashboard),
                      _businessPartnersMenu(),
                      _menuItem('Admin', Icons.security),
                      _menuItem('Key Users', Icons.people_alt_outlined),
                      _menuItem('Users', Icons.groups),
                      _menuItem('Craftsman', Icons.shield),
                      _menuItem('Work Orders', Icons.assignment),
                      _menuItem('Purchase Order', Icons.assignment_turned_in),
                      _menuItem('Finance', Icons.currency_rupee),
                      _menuItem('Products', Icons.inventory_2),
                      _menuItem('Designs', Icons.draw),
                      _menuItem('My Catalogue', Icons.menu_book),
                      _menuItem("KYC Pending", Icons.warning_amber_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  Text('Welcome ${authService.fullName ?? 'User'}'),
                  const SizedBox(height: 20),
                  Expanded(
                    child: isWideScreen
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: _buildDashboardCards()),
                              SizedBox(width: 20),
                              Expanded(flex: 2, child: CustomCalendar()),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _buildDashboardCards(),
                                const SizedBox(height: 20),
                                CustomCalendar(),
                              ],
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

  Widget _buildUserInfo() {
  final auth = AuthService.instance;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey.shade700)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade800,
          backgroundImage: auth.profilePicture != null &&
                  auth.profilePicture!.isNotEmpty
              ? NetworkImage(auth.profilePicture!)
              : null,
          child: auth.profilePicture == null ||
                  auth.profilePicture!.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 30)
              : null,
        ),

        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              auth.fullName?.isNotEmpty == true ? auth.fullName! : 'User',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              auth.email?.isNotEmpty == true ? auth.email! : 'No Email',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              auth.role ?? '',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              auth.userCode ?? '',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Active',
                  style:
                      TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _menuItem(String title, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap ?? () {},
    );
  }

  Widget _businessPartnersMenu() {
    return ExpansionTile(
      collapsedIconColor: Colors.white,
      iconColor: Colors.white,
      leading: const Icon(Icons.business_center, color: Colors.white),
      title: const Text('Business Partners', style: TextStyle(color: Colors.white)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${buyerCount + craftsmanCount}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      children: [
        _menuItem("Buyer ($buyerCount)", Icons.shopping_cart),
        _menuItem("Craftsman ($craftsmanCount)", Icons.handyman),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Super Admin Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Logout'),
        ),
      ],
    );
  }


Widget _buildDashboardCards() {
  final mainChildren = <Widget>[
    _dashboardCard("BUSINESS PARTNER", 0, Icons.business_center,url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BusinessPartnerPage()),
  );
}),
    _dashboardCard("BUYERS", 12, Icons.shopping_cart, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BuyerPage()),
  );
}),
    _dashboardCard("CRAFTSMAN", 12, Icons.handyman, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CraftsmanPage()),
  );
}),
    _dashboardCard("KYC PENDING", 3, Icons.warning_amber_rounded, iconColor: AppColors.warningColor, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => KYCPage()),
  );
}),

    _dashboardCard("ADMINS",  2, Icons.security, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AdminPage()),
  );
}),
    _dashboardCard("BUYER",  2, Icons.people_alt_outlined, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => KeyUserPage()),
  );
}),
    _dashboardCard("KEYUSERS",  2, Icons.people_alt_outlined, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => KeyUserPage()),
  );
}),
    _dashboardCard("USERS",  2, Icons.groups, url: null, onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserPage()),
  );
}),
    _dashboardCard("CRAFTSMAN",  2, Icons.shield, url: null, onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CraftmanPage()),
      );
    }),
    _dashboardCard("FINANCE", 0, Icons.currency_rupee, iconColor: AppColors.successColor),
    _dashboardCard("WORK ORDERS",  2, Icons.assignment, url: null, onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WorkOrderPage()),
      );
    }),
    _dashboardCard("PURCHASE ORDERS",  4, Icons.assignment_turned_in, url: null, onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PurchaseOrderPage()),
      );
    }),
    _dashboardCard("PRODUCTS", 7, Icons.inventory_2),
    _dashboardCard("DESIGNS", 15, Icons.draw),
    _dashboardCard("CATALOGUE", 8, Icons.menu_book),
  ];

  final bottomChildren = <Widget>[
    _smallDashboardCard("TOP PICKS CRAFTSMAN", 15, Icons.trending_up),
    _smallDashboardCard("LEAST PICKS CRAFTSMAN", 15, Icons.trending_down),
    _smallDashboardCard("MOST SELLING PRODUCTS", 10, Icons.shopping_bag_outlined),
    _smallDashboardCard("LEAST SELLING PRODUCTS", 10, Icons.inventory_2_outlined),
    _smallDashboardCard("QUICK PAYMENTS", 15, Icons.trending_up),
    _smallDashboardCard("OVERDUE PAYMENTS", 15, Icons.trending_down),
    _smallDashboardCard("TOP PICKS CLIENTS", 10, Icons.shopping_bag_outlined),
    _smallDashboardCard("LEAST PICKS CLIENTS", 10, Icons.inventory_2_outlined),
  ];

  return Container(
    color: AppColors.background,
    // padding: const EdgeInsets.all(24),
    padding: const EdgeInsets.fromLTRB(24, 24, 40, 24),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          // Main Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 300 / 220,
            children: mainChildren,
          ),
          const SizedBox(height: 24),
          // Bottom horizontal cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: bottomChildren
                  .map((card) => Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: card,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 24), // extra padding to avoid bottom overflow
        ],
      ),
    ),
  );
}


Widget _smallDashboardCard(String title, int count, IconData icon,
    {Color iconColor = Colors.black}) {
  return Container(
    width: 140,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$count",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.bottomRight,
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ],
    ),
  );
}
}


Widget _dashboardCard(String title, int count, IconData icon,
    {String? url, Color iconColor = Colors.black, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap ?? () async {
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    },
    child: SizedBox(
      width: 288,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Text section takes flexible width
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "$count",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.iconBackground,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ],
        ),
      ),
    ),
  );
}

// class BusinessPartnerPage extends StatefulWidget {
//   @override
//   _BusinessPartnerPageState createState() => _BusinessPartnerPageState();
// }

// class _BusinessPartnerPageState extends State<BusinessPartnerPage> {
//   List<Map<String, dynamic>> partners = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   // Load token from SharedPreferences
//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token') ??
//         "01c5b132a0f3829ef42182997067cd1501f1009a"; // Default token
//     fetchAllBusinessPartners();
//   }

//   // Fetch both Business Partners and Craftsmans
//   Future<void> fetchAllBusinessPartners() async {
//     if (token == null || token!.isEmpty) return;
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       final buyersUrl = Uri.parse(
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
//       final craftsmansUrl = Uri.parse(
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Craftsmans/');

//       final headers = {'Authorization': 'Token $token'};

//       // Fetch both APIs in parallel
//       final responses = await Future.wait([
//         http.get(buyersUrl, headers: headers),
//         http.get(craftsmansUrl, headers: headers),
//       ]);

//       List<Map<String, dynamic>> combinedList = [];

//       for (final response in responses) {
//         if (response.statusCode == 200) {
//           final Map<String, dynamic> data = json.decode(response.body);
//           final List<Map<String, dynamic>> results =
//               List<Map<String, dynamic>>.from(data['results']);
//           combinedList.addAll(results);
//         } else {
//           print('Failed to load data: ${response.statusCode}');
//         }
//       }

//       setState(() {
//         partners = combinedList;
//         isLoading = false;
//       });
//     } catch (e) {
//       print('Error fetching data: $e');
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   // View Business Partner Dialog (read-only)
//   void showBusinessPartnerDialog(Map<String, dynamic> partner) {
//     final controllers = {
//       'role': TextEditingController(text: partner['role']),
//       'bp_code': TextEditingController(text: partner['bp_code']),
//       'business_name': TextEditingController(text: partner['business_name']),
//       'name': TextEditingController(text: partner['name']),
//       'mobile': TextEditingController(text: partner['mobile']),
//       'landline': TextEditingController(text: partner['landline']),
//       'email': TextEditingController(text: partner['email']),
//       'business_email': TextEditingController(text: partner['business_email']),
//       'refered_by': TextEditingController(text: partner['refered_by']),
//       'more': TextEditingController(text: partner['more']),
//       'door_no': TextEditingController(text: partner['door_no']),
//       'shop_no': TextEditingController(text: partner['shop_no']),
//       'complex_name': TextEditingController(text: partner['complex_name']),
//       'building_name': TextEditingController(text: partner['building_name']),
//       'street_name': TextEditingController(text: partner['street_name']),
//       'area': TextEditingController(text: partner['area']),
//       'pincode': TextEditingController(text: partner['pincode']),
//       'city': TextEditingController(text: partner['city']),
//       'state': TextEditingController(text: partner['state']),
//       'map_location': TextEditingController(text: partner['map_location']),
//       'location_guide': TextEditingController(text: partner['location_guide']),
//     };

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('View Business Partner'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: controllers.entries.map((entry) {
//                 return TextField(
//                   controller: entry.value,
//                   decoration: InputDecoration(
//                       labelText: entry.key.replaceAll('_', ' ').toUpperCase()),
//                   readOnly: true,
//                 );
//               }).toList(),
//             ),
//           ),
//           actions: [
//             TextButton(
//                 onPressed: () => Navigator.pop(context), child: Text('Close')),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final fields = [
//       'role',
//       'bp_code',
//       'business_name',
//       'name',
//       'mobile',
//       'landline',
//       'email',
//       'business_email',
//       'refered_by',
//       'more',
//       'door_no',
//       'shop_no',
//       'complex_name',
//       'building_name',
//       'street_name',
//       'area',
//       'pincode',
//       'city',
//       'state',
//       'map_location',
//       'location_guide'
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Business Partners & Craftsmans'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: fetchAllBusinessPartners,
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : partners.isEmpty
//               ? Center(child: Text('No business partners or craftsmans found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columnSpacing: 20,
//                     columns: [
//                       DataColumn(label: Text('Select')),
//                       DataColumn(label: Text('Action')),
//                       ...fields.map((f) => DataColumn(
//                           label: Text(f.replaceAll('_', ' ').toUpperCase()))),
//                     ],
//                     rows: partners.asMap().entries.map((entry) {
//                       final index = entry.key;
//                       final partner = entry.value;
//                       final id = partner['id'] ?? index;

//                       return DataRow(
//                         cells: [
//                           DataCell(Checkbox(
//                             value: selectedIds.contains(id),
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true)
//                                   selectedIds.add(id);
//                                 else
//                                   selectedIds.remove(id);
//                               });
//                             },
//                           )),
//                           DataCell(selectedIds.contains(id)
//                               ? ElevatedButton(
//                                   onPressed: () =>
//                                       showBusinessPartnerDialog(partner),
//                                   child: Text('View'),
//                                 )
//                               : SizedBox()),
//                           ...fields.map((f) =>
//                               DataCell(Text(partner[f]?.toString() ?? ''))),
//                         ],
//                       );
//                     }).toList(),
//                   ),
//                 ),
//     );
//   }
// }


// class BusinessPartnerPage extends StatefulWidget {
//   @override
//   _BusinessPartnerPageState createState() => _BusinessPartnerPageState();
// }

// class _BusinessPartnerPageState extends State<BusinessPartnerPage> {
//   List<Map<String, dynamic>> partners = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;

//   @override
//   void initState() {
//     super.initState();
//     loadTokenAndFetchData();
//   }

//   // Load token dynamically from SharedPreferences
//   Future<void> loadTokenAndFetchData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       print('❌ No token found. Please login first.');
//       setState(() => isLoading = false);
//       return;
//     }

//     print('✅ Loaded token: $token');
//     await fetchAllBusinessPartners();
//   }

//   // Fetch both Buyers and Craftsmans data
//   Future<void> fetchAllBusinessPartners() async {
//     if (token == null || token!.isEmpty) return;

//     setState(() => isLoading = true);

//     try {
//       final buyersUrl = Uri.parse(
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
//       final craftsmansUrl = Uri.parse(
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Craftsmans/');

//       final headers = {'Authorization': 'Token $token'};

//       // Run both requests simultaneously
//       final responses = await Future.wait([
//         http.get(buyersUrl, headers: headers),
//         http.get(craftsmansUrl, headers: headers),
//       ]);

//       List<Map<String, dynamic>> combinedList = [];

//       for (final response in responses) {
//         if (response.statusCode == 200) {
//           final Map<String, dynamic> data = json.decode(response.body);
//           final List<Map<String, dynamic>> results =
//               List<Map<String, dynamic>>.from(data['results']);
//           combinedList.addAll(results);
//         } else {
//           print('⚠️ Failed to load data: ${response.statusCode}');
//         }
//       }

//       setState(() {
//         partners = combinedList;
//         isLoading = false;
//       });
//     } catch (e) {
//       print('❌ Error fetching data: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   // View Business Partner Dialog (read-only)
//   void showBusinessPartnerDialog(Map<String, dynamic> partner) {
//     final controllers = {
//       'role': TextEditingController(text: partner['role'] ?? ''),
//       'bp_code': TextEditingController(text: partner['bp_code'] ?? ''),
//       'business_name': TextEditingController(text: partner['business_name'] ?? ''),
//       'name': TextEditingController(text: partner['name'] ?? ''),
//       'mobile': TextEditingController(text: partner['mobile'] ?? ''),
//       'landline': TextEditingController(text: partner['landline'] ?? ''),
//       'email': TextEditingController(text: partner['email'] ?? ''),
//       'business_email': TextEditingController(text: partner['business_email'] ?? ''),
//       'refered_by': TextEditingController(text: partner['refered_by'] ?? ''),
//       'more': TextEditingController(text: partner['more'] ?? ''),
//       'door_no': TextEditingController(text: partner['door_no'] ?? ''),
//       'shop_no': TextEditingController(text: partner['shop_no'] ?? ''),
//       'complex_name': TextEditingController(text: partner['complex_name'] ?? ''),
//       'building_name': TextEditingController(text: partner['building_name'] ?? ''),
//       'street_name': TextEditingController(text: partner['street_name'] ?? ''),
//       'area': TextEditingController(text: partner['area'] ?? ''),
//       'pincode': TextEditingController(text: partner['pincode'] ?? ''),
//       'city': TextEditingController(text: partner['city'] ?? ''),
//       'state': TextEditingController(text: partner['state'] ?? ''),
//       'map_location': TextEditingController(text: partner['map_location'] ?? ''),
//       'location_guide': TextEditingController(text: partner['location_guide'] ?? ''),
//     };

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: Text('View Business Partner'),
//           content: SingleChildScrollView(
//             child: Column(
//               children: controllers.entries.map((entry) {
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 4.0),
//                   child: TextField(
//                     controller: entry.value,
//                     readOnly: true,
//                     decoration: InputDecoration(
//                       labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final fields = [
//       'role',
//       'bp_code',
//       'business_name',
//       'name',
//       'mobile',
//       'landline',
//       'email',
//       'business_email',
//       'refered_by',
//       'more',
//       'door_no',
//       'shop_no',
//       'complex_name',
//       'building_name',
//       'street_name',
//       'area',
//       'pincode',
//       'city',
//       'state',
//       'map_location',
//       'location_guide'
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers & Craftsmans'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.refresh),
//             onPressed: fetchAllBusinessPartners,
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : partners.isEmpty
//               ? Center(child: Text('No Buyers or Craftsmans found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columnSpacing: 20,
//                     columns: [
//                       DataColumn(label: Text('Select')),
//                       DataColumn(label: Text('Action')),
//                       ...fields.map((f) =>
//                           DataColumn(label: Text(f.replaceAll('_', ' ').toUpperCase()))),
//                     ],
//                     rows: partners.asMap().entries.map((entry) {
//                       final index = entry.key;
//                       final partner = entry.value;
//                       final id = partner['id'] ?? index;

//                       return DataRow(
//                         cells: [
//                           DataCell(Checkbox(
//                             value: selectedIds.contains(id),
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true)
//                                   selectedIds.add(id);
//                                 else
//                                   selectedIds.remove(id);
//                               });
//                             },
//                           )),
//                           DataCell(selectedIds.contains(id)
//                               ? ElevatedButton(
//                                   onPressed: () => showBusinessPartnerDialog(partner),
//                                   child: Text('View'),
//                                 )
//                               : SizedBox()),
//                           ...fields.map(
//                             (f) => DataCell(Text(partner[f]?.toString() ?? '')),
//                           ),
//                         ],
//                       );
//                     }).toList(),
//                   ),
//                 ),
//     );
//   }
// }

class BusinessPartnerPage extends StatefulWidget {
  @override
  _BusinessPartnerPageState createState() => _BusinessPartnerPageState();
}

class _BusinessPartnerPageState extends State<BusinessPartnerPage> {
  List<Map<String, dynamic>> partners = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;

  @override
  void initState() {
    super.initState();
    loadTokenAndFetchData();
  }

  Future<void> loadTokenAndFetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');

    if (token == null || token!.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    await fetchAllBusinessPartners();
  }

  Future<void> fetchAllBusinessPartners() async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      final buyersUrl = Uri.parse(
          'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
      final craftsmansUrl = Uri.parse(
          'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Craftsmans/');

      final headers = {'Authorization': 'Token $token'};

      final responses = await Future.wait([
        http.get(buyersUrl, headers: headers),
        http.get(craftsmansUrl, headers: headers),
      ]);

      List<Map<String, dynamic>> combinedList = [];

      for (final response in responses) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          combinedList.addAll(
              List<Map<String, dynamic>>.from(data['results']));
        }
      }

      setState(() {
        partners = combinedList;
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void showBusinessPartnerDialog(Map<String, dynamic> partner) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Business Partner'),
        content: SingleChildScrollView(
          child: Column(
            children: partner.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller:
                      TextEditingController(text: e.value?.toString() ?? ''),
                  readOnly: true,
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
    final fields = partners.isNotEmpty
        ? partners.first.keys.where((k) => k != 'id').toList()
        : [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Buyers & Craftsmans'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchAllBusinessPartners,
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : partners.isEmpty
              ? Center(child: Text('No data found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical, // ✅ vertical scroll
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // ✅ horizontal scroll
                    child: DataTable(
                      columnSpacing: 20,
                      columns: [
                        DataColumn(label: Text('Select')),
                        DataColumn(label: Text('Action')),
                        ...fields.map((f) => DataColumn(
                              label: Text(
                                  f.replaceAll('_', ' ').toUpperCase()),
                            )),
                      ],
                      rows: partners.map((partner) {
                        final id = partner['id'];
                        return DataRow(
                          cells: [
                            DataCell(
                              Checkbox(
                                value: selectedIds.contains(id),
                                onChanged: (v) {
                                  setState(() {
                                    v == true
                                        ? selectedIds.add(id)
                                        : selectedIds.remove(id);
                                  });
                                },
                              ),
                            ),
                            DataCell(
                              selectedIds.contains(id)
                                  ? ElevatedButton(
                                      onPressed: () =>
                                          showBusinessPartnerDialog(partner),
                                      child: Text('View'),
                                    )
                                  : SizedBox(),
                            ),
                            ...fields.map((f) => DataCell(
                                  Text(partner[f]?.toString() ?? ''),
                                )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
    );
  }
}


// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

//   // For creating new buyer
//   final Map<String, TextEditingController> createControllers = {};
//   List<Map<String, String>> moreDetails = [];
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose all text controllers
//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });
//     super.dispose();
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

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     final Uri apiUrl = Uri.parse(
//       url ??
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results =
//             List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     final controllers = {
//       for (var field in buyer.keys)
//         if (field.toLowerCase() != 'id')
//           field: TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           )
//     };

//     // Check if buyer has more_detail
//     List<Map<String, dynamic>>? existingMoreDetails;
//     if (buyer['more_detail'] != null && buyer['more_detail'] is List) {
//       existingMoreDetails = List<Map<String, dynamic>>.from(buyer['more_detail']);
//     }

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
//         content: SingleChildScrollView(
//           child: Column(
//             children: [
//               // Main fields
//               ...controllers.entries.map((entry) {
//                 if (entry.key == 'pan_attachment' || entry.key == 'gst_attachment') {
//                   // Show file preview for attachments
//                   String? fileUrl = buyer[entry.key];
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 6),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           entry.key.replaceAll('_', ' ').toUpperCase(),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         if (fileUrl != null && fileUrl.isNotEmpty)
//                           InkWell(
//                             onTap: () {
//                               // Open file in browser or show preview
//                               print('File URL: $fileUrl');
//                             },
//                             child: Text(
//                               'View Attachment',
//                               style: TextStyle(
//                                 color: Colors.blue,
//                                 decoration: TextDecoration.underline,
//                               ),
//                             ),
//                           )
//                         else
//                           Text('No attachment'),
//                       ],
//                     ),
//                   );
//                 }
                
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 6),
//                   child: TextField(
//                     controller: entry.value,
//                     readOnly: !isEdit,
//                     decoration: InputDecoration(
//                       labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 );
//               }).toList(),
              
//               // More Detail section
//               if (existingMoreDetails != null && existingMoreDetails.isNotEmpty)
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(height: 20),
//                     Text(
//                       'MORE DETAILS',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     SizedBox(height: 10),
//                     ...existingMoreDetails.map((detail) {
//                       return Card(
//                         margin: EdgeInsets.symmetric(vertical: 5),
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Name: ${detail['dummy_name'] ?? ''}'),
//                               Text('Email: ${detail['dummy_email'] ?? ''}'),
//                               Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                             ],
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ],
//                 ),
//             ],
//           ),
//         ),
//         actions: [
//           if (isEdit)
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: Text('Save'),
//             ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields
//     for (var field in dynamicFields) {
//       if (!createControllers.containsKey(field)) {
//         createControllers[field] = TextEditingController();
//       }
//     }
    
//     // Initialize moreDetails list
//     moreDetails = [];
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields
//                   ...dynamicFields.map((field) {
//                     if (!createControllers.containsKey(field)) {
//                       createControllers[field] = TextEditingController();
//                     }
                    
//                     // Handle file upload fields differently
//                     if (field == 'pan_attachment') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'PAN ATTACHMENT',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () async {
//                                       await pickFile('pan');
//                                     },
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(panAttachmentFileName ?? 'Select PAN File'),
//                                   ),
//                                 ),
//                                 if (panAttachmentFileName != null)
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () {
//                                       setState(() {
//                                         panAttachmentFile = null;
//                                         panAttachmentFileName = null;
//                                       });
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }
                    
//                     if (field == 'gst_attachment') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'GST ATTACHMENT',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () async {
//                                       await pickFile('gst');
//                                     },
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(gstAttachmentFileName ?? 'Select GST File'),
//                                   ),
//                                 ),
//                                 if (gstAttachmentFileName != null)
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () {
//                                       setState(() {
//                                         gstAttachmentFile = null;
//                                         gstAttachmentFileName = null;
//                                       });
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }
                    
//                     // Regular text fields
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: TextField(
//                         controller: createControllers[field],
//                         decoration: InputDecoration(
//                           labelText: field.replaceAll('_', ' ').toUpperCase(),
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     );
//                   }).toList(),
                  
//                   // More Detail section
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(height: 20),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'MORE DETAILS',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           ElevatedButton.icon(
//                             onPressed: () {
//                               setState(() {
//                                 moreDetails.add({
//                                   'dummy_name': '',
//                                   'dummy_email': '',
//                                   'dummy_mobile': '',
//                                 });
//                               });
//                             },
//                             icon: Icon(Icons.add, size: 20),
//                             label: Text('Add'),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 10),
                      
//                       // List of more details
//                       ...moreDetails.asMap().entries.map((entry) {
//                         int index = entry.key;
//                         Map<String, String> detail = entry.value;
                        
//                         return Card(
//                           margin: EdgeInsets.symmetric(vertical: 5),
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Column(
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       'Detail ${index + 1}',
//                                       style: TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                     IconButton(
//                                       icon: Icon(Icons.delete, color: Colors.red),
//                                       onPressed: () {
//                                         setState(() {
//                                           moreDetails.removeAt(index);
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                                 TextField(
//                                   decoration: InputDecoration(
//                                     labelText: 'Name',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                   onChanged: (value) {
//                                     detail['dummy_name'] = value;
//                                   },
//                                 ),
//                                 SizedBox(height: 8),
//                                 TextField(
//                                   decoration: InputDecoration(
//                                     labelText: 'Email',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                   onChanged: (value) {
//                                     detail['dummy_email'] = value;
//                                   },
//                                 ),
//                                 SizedBox(height: 8),
//                                 TextField(
//                                   decoration: InputDecoration(
//                                     labelText: 'Mobile',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                   onChanged: (value) {
//                                     detail['dummy_mobile'] = value;
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 ],
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment') {
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

//       // Add more_detail if exists
//       if (moreDetails.isNotEmpty) {
//         // Filter out empty details
//         List<Map<String, String>> nonEmptyDetails = moreDetails
//             .where((detail) => 
//                 detail['dummy_name']!.isNotEmpty ||
//                 detail['dummy_email']!.isNotEmpty ||
//                 detail['dummy_mobile']!.isNotEmpty)
//             .toList();
        
//         if (nonEmptyDetails.isNotEmpty) {
//           request.fields['more_detail'] = json.encode(nonEmptyDetails);
//         }
//       }

//       // Send request
//       var response = await request.send();
      
//       if (response.statusCode == 201) {
//         // Clear controllers after successful creation
//         createControllers.forEach((key, controller) {
//           controller.clear();
//         });
//         moreDetails.clear();
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
//         final errorData = json.decode(responseBody);
        
//         // Show error message
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to create buyer: ${errorData.toString()}'),
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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
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
//               ? Center(child: Text('No buyers found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(field
//                                       .replaceAll('_', ' ')
//                                       .toUpperCase()),
//                                 ),
//                               ),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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

//                                   // ACTIONS ONLY IF SELECTED
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           if (f == 'pan_attachment' || f == 'gst_attachment') {
//                                             return buyer[f] != null && buyer[f].toString().isNotEmpty
//                                                 ? InkWell(
//                                                     onTap: () {
//                                                       // Open file URL
//                                                       print('Open: ${buyer[f]}');
//                                                     },
//                                                     child: Text(
//                                                       'View File',
//                                                       style: TextStyle(
//                                                         color: Colors.blue,
//                                                         decoration: TextDecoration.underline,
//                                                       ),
//                                                     ),
//                                                   )
//                                                 : Text('No file');
//                                           } else {
//                                             return Text(buyer[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

//   // For creating new buyer
//   final Map<String, TextEditingController> createControllers = {};
//   // Store more details as controllers
//   List<Map<String, TextEditingController>> moreDetailControllers = [];
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose all text controllers
//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });
//     // Dispose more detail controllers
//     for (var controllers in moreDetailControllers) {
//       controllers.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
//     super.dispose();
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

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     final Uri apiUrl = Uri.parse(
//       url ??
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results =
//             List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     final controllers = {
//       for (var field in buyer.keys)
//         if (field.toLowerCase() != 'id')
//           field: TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           )
//     };

//     // Check if buyer has more_detail
//     List<Map<String, dynamic>>? existingMoreDetails;
//     if (buyer['more_detail'] != null && buyer['more_detail'] is List) {
//       existingMoreDetails = List<Map<String, dynamic>>.from(buyer['more_detail']);
//     }

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
//         content: SingleChildScrollView(
//           child: Column(
//             children: [
//               // Main fields
//               ...controllers.entries.map((entry) {
//                 if (entry.key == 'pan_attachment' || entry.key == 'gst_attachment') {
//                   // Show file preview for attachments
//                   String? fileUrl = buyer[entry.key];
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 6),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           entry.key.replaceAll('_', ' ').toUpperCase(),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         if (fileUrl != null && fileUrl.isNotEmpty)
//                           InkWell(
//                             onTap: () {
//                               // Open file in browser or show preview
//                               print('File URL: $fileUrl');
//                             },
//                             child: Text(
//                               'View Attachment',
//                               style: TextStyle(
//                                 color: Colors.blue,
//                                 decoration: TextDecoration.underline,
//                               ),
//                             ),
//                           )
//                         else
//                           Text('No attachment'),
//                       ],
//                     ),
//                   );
//                 }
                
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 6),
//                   child: TextField(
//                     controller: entry.value,
//                     readOnly: !isEdit,
//                     decoration: InputDecoration(
//                       labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 );
//               }).toList(),
              
//               // More Detail section
//               if (existingMoreDetails != null && existingMoreDetails.isNotEmpty)
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(height: 20),
//                     Text(
//                       'MORE DETAILS',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     SizedBox(height: 10),
//                     ...existingMoreDetails.map((detail) {
//                       return Card(
//                         margin: EdgeInsets.symmetric(vertical: 5),
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Name: ${detail['dummy_name'] ?? ''}'),
//                               Text('Email: ${detail['dummy_email'] ?? ''}'),
//                               Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                             ],
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ],
//                 ),
//             ],
//           ),
//         ),
//         actions: [
//           if (isEdit)
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: Text('Save'),
//             ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields
//     for (var field in dynamicFields) {
//       if (!createControllers.containsKey(field)) {
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields
//                   ...dynamicFields.map((field) {
//                     if (!createControllers.containsKey(field)) {
//                       createControllers[field] = TextEditingController();
//                     }
                    
//                     // Handle file upload fields differently
//                     if (field == 'pan_attachment') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'PAN ATTACHMENT',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () async {
//                                       await pickFile('pan');
//                                     },
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(panAttachmentFileName ?? 'Select PAN File'),
//                                   ),
//                                 ),
//                                 if (panAttachmentFileName != null)
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () {
//                                       setState(() {
//                                         panAttachmentFile = null;
//                                         panAttachmentFileName = null;
//                                       });
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }
                    
//                     if (field == 'gst_attachment') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'GST ATTACHMENT',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () async {
//                                       await pickFile('gst');
//                                     },
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(gstAttachmentFileName ?? 'Select GST File'),
//                                   ),
//                                 ),
//                                 if (gstAttachmentFileName != null)
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () {
//                                       setState(() {
//                                         gstAttachmentFile = null;
//                                         gstAttachmentFileName = null;
//                                       });
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }
                    
//                     // Regular text fields
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: TextField(
//                         controller: createControllers[field],
//                         decoration: InputDecoration(
//                           labelText: field.replaceAll('_', ' ').toUpperCase(),
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     );
//                   }).toList(),
                  
//                   // More Detail section
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(height: 20),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'MORE DETAILS',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           ElevatedButton.icon(
//                             onPressed: () {
//                               setState(() {
//                                 moreDetailControllers.add({
//                                   'dummy_name': TextEditingController(),
//                                   'dummy_email': TextEditingController(),
//                                   'dummy_mobile': TextEditingController(),
//                                 });
//                               });
//                             },
//                             icon: Icon(Icons.add, size: 20),
//                             label: Text('Add'),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 10),
                      
//                       // List of more details
//                       ...moreDetailControllers.asMap().entries.map((entry) {
//                         int index = entry.key;
//                         Map<String, TextEditingController> controllers = entry.value;
                        
//                         return Card(
//                           margin: EdgeInsets.symmetric(vertical: 5),
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Column(
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       'Detail ${index + 1}',
//                                       style: TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                     IconButton(
//                                       icon: Icon(Icons.delete, color: Colors.red),
//                                       onPressed: () {
//                                         setState(() {
//                                           // Dispose controllers before removing
//                                           controllers.forEach((key, controller) {
//                                             controller.dispose();
//                                           });
//                                           moreDetailControllers.removeAt(index);
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                                 TextField(
//                                   controller: controllers['dummy_name'],
//                                   decoration: InputDecoration(
//                                     labelText: 'Name',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
//                                 TextField(
//                                   controller: controllers['dummy_email'],
//                                   decoration: InputDecoration(
//                                     labelText: 'Email',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
//                                 TextField(
//                                   controller: controllers['dummy_mobile'],
//                                   decoration: InputDecoration(
//                                     labelText: 'Mobile',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 ],
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment') {
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

//       // Debug: Print all fields
//       print('Request fields:');
//       request.fields.forEach((key, value) {
//         print('$key: $value');
//       });

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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
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
//               ? Center(child: Text('No buyers found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(field
//                                       .replaceAll('_', ' ')
//                                       .toUpperCase()),
//                                 ),
//                               ),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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

//                                   // ACTIONS ONLY IF SELECTED
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           if (f == 'pan_attachment' || f == 'gst_attachment') {
//                                             return buyer[f] != null && buyer[f].toString().isNotEmpty
//                                                 ? InkWell(
//                                                     onTap: () {
//                                                       // Open file URL
//                                                       print('Open: ${buyer[f]}');
//                                                     },
//                                                     child: Text(
//                                                       'View File',
//                                                       style: TextStyle(
//                                                         color: Colors.blue,
//                                                         decoration: TextDecoration.underline,
//                                                       ),
//                                                     ),
//                                                   )
//                                                 : Text('No file');
//                                           } else {
//                                             return Text(buyer[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

//   // For creating new buyer
//   final Map<String, TextEditingController> createControllers = {};
//   // Store more details as controllers
//   List<Map<String, TextEditingController>> moreDetailControllers = [];
  
//   // For file uploads
//   File? panAttachmentFile;
//   File? gstAttachmentFile;
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose all text controllers
//     createControllers.forEach((key, controller) {
//       controller.dispose();
//     });
//     // Dispose more detail controllers
//     for (var controllers in moreDetailControllers) {
//       controllers.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
//     super.dispose();
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

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     final Uri apiUrl = Uri.parse(
//       url ??
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results =
//             List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     final controllers = {
//       for (var field in buyer.keys)
//         if (field.toLowerCase() != 'id')
//           field: TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           )
//     };

//     // Check if buyer has more_detail
//     List<Map<String, dynamic>>? existingMoreDetails;
//     if (buyer['more_detail'] != null && buyer['more_detail'] is List) {
//       existingMoreDetails = List<Map<String, dynamic>>.from(buyer['more_detail']);
//     }

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
//         content: SingleChildScrollView(
//           child: Column(
//             children: [
//               // Main fields - exclude role, bp_code, more_detail
//               ...controllers.entries.where((entry) => 
//                 entry.key != 'role' && 
//                 entry.key != 'bp_code' && 
//                 entry.key != 'more_detail'
//               ).map((entry) {
//                 if (entry.key == 'pan_attachment' || entry.key == 'gst_attachment') {
//                   // Show file preview for attachments
//                   String? fileUrl = buyer[entry.key];
//                   return Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 6),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           entry.key.replaceAll('_', ' ').toUpperCase(),
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         if (fileUrl != null && fileUrl.isNotEmpty)
//                           InkWell(
//                             onTap: () {
//                               // Open file in browser or show preview
//                               print('File URL: $fileUrl');
//                             },
//                             child: Text(
//                               'View Attachment',
//                               style: TextStyle(
//                                 color: Colors.blue,
//                                 decoration: TextDecoration.underline,
//                               ),
//                             ),
//                           )
//                         else
//                           Text('No attachment'),
//                       ],
//                     ),
//                   );
//                 }
                
//                 return Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 6),
//                   child: TextField(
//                     controller: entry.value,
//                     readOnly: !isEdit,
//                     decoration: InputDecoration(
//                       labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 );
//               }).toList(),
              
//               // More Detail section
//               if (existingMoreDetails != null && existingMoreDetails.isNotEmpty)
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(height: 20),
//                     Text(
//                       'MORE DETAILS',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     SizedBox(height: 10),
//                     ...existingMoreDetails.map((detail) {
//                       return Card(
//                         margin: EdgeInsets.symmetric(vertical: 5),
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('Name: ${detail['dummy_name'] ?? ''}'),
//                               Text('Email: ${detail['dummy_email'] ?? ''}'),
//                               Text('Mobile: ${detail['dummy_mobile'] ?? ''}'),
//                             ],
//                           ),
//                         ),
//                       );
//                     }).toList(),
//                   ],
//                 ),
//             ],
//           ),
//         ),
//         actions: [
//           if (isEdit)
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: Text('Save'),
//             ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields
//     for (var field in dynamicFields) {
//       if (!createControllers.containsKey(field)) {
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields - exclude role, bp_code, more_detail
//                   ...dynamicFields.where((field) => 
//                     field != 'role' && 
//                     field != 'bp_code' && 
//                     field != 'more_detail'
//                   ).map((field) {
//                     if (!createControllers.containsKey(field)) {
//                       createControllers[field] = TextEditingController();
//                     }
                    
//                     // Handle file upload fields differently
//                     if (field == 'pan_attachment') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'PAN ATTACHMENT',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () async {
//                                       await pickFile('pan');
//                                     },
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(panAttachmentFileName ?? 'Select PAN File'),
//                                   ),
//                                 ),
//                                 if (panAttachmentFileName != null)
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () {
//                                       setState(() {
//                                         panAttachmentFile = null;
//                                         panAttachmentFileName = null;
//                                       });
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }
                    
//                     if (field == 'gst_attachment') {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 6),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'GST ATTACHMENT',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(height: 4),
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () async {
//                                       await pickFile('gst');
//                                     },
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(gstAttachmentFileName ?? 'Select GST File'),
//                                   ),
//                                 ),
//                                 if (gstAttachmentFileName != null)
//                                   IconButton(
//                                     icon: Icon(Icons.clear),
//                                     onPressed: () {
//                                       setState(() {
//                                         gstAttachmentFile = null;
//                                         gstAttachmentFileName = null;
//                                       });
//                                     },
//                                   ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       );
//                     }
                    
//                     // Regular text fields
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: TextField(
//                         controller: createControllers[field],
//                         decoration: InputDecoration(
//                           labelText: field.replaceAll('_', ' ').toUpperCase(),
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     );
//                   }).toList(),
                  
//                   // More Detail section - placed under GST Attachment
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(height: 20),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'MORE DETAILS',
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                           ElevatedButton.icon(
//                             onPressed: () {
//                               setState(() {
//                                 moreDetailControllers.add({
//                                   'dummy_name': TextEditingController(),
//                                   'dummy_email': TextEditingController(),
//                                   'dummy_mobile': TextEditingController(),
//                                 });
//                               });
//                             },
//                             icon: Icon(Icons.add, size: 20),
//                             label: Text('Add'),
//                           ),
//                         ],
//                       ),
//                       SizedBox(height: 10),
                      
//                       // List of more details
//                       ...moreDetailControllers.asMap().entries.map((entry) {
//                         int index = entry.key;
//                         Map<String, TextEditingController> controllers = entry.value;
                        
//                         return Card(
//                           margin: EdgeInsets.symmetric(vertical: 5),
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Column(
//                               children: [
//                                 Row(
//                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                   children: [
//                                     Text(
//                                       'Detail ${index + 1}',
//                                       style: TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                     IconButton(
//                                       icon: Icon(Icons.delete, color: Colors.red),
//                                       onPressed: () {
//                                         setState(() {
//                                           // Dispose controllers before removing
//                                           controllers.forEach((key, controller) {
//                                             controller.dispose();
//                                           });
//                                           moreDetailControllers.removeAt(index);
//                                         });
//                                       },
//                                     ),
//                                   ],
//                                 ),
//                                 TextField(
//                                   controller: controllers['dummy_name'],
//                                   decoration: InputDecoration(
//                                     labelText: 'Name',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
//                                 TextField(
//                                   controller: controllers['dummy_email'],
//                                   decoration: InputDecoration(
//                                     labelText: 'Email',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                 ),
//                                 SizedBox(height: 8),
//                                 TextField(
//                                   controller: controllers['dummy_mobile'],
//                                   decoration: InputDecoration(
//                                     labelText: 'Mobile',
//                                     border: OutlineInputBorder(),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 ],
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role, bp_code, more_detail
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'role' &&
//             key != 'bp_code' &&
//             key != 'more_detail') {
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

//       // Debug: Print all fields
//       print('Request fields:');
//       request.fields.forEach((key, value) {
//         print('$key: $value');
//       });

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

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
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
//               ? Center(child: Text('No buyers found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(field
//                                       .replaceAll('_', ' ')
//                                       .toUpperCase()),
//                                 ),
//                               ),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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

//                                   // ACTIONS ONLY IF SELECTED
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           if (f == 'pan_attachment' || f == 'gst_attachment') {
//                                             return buyer[f] != null && buyer[f].toString().isNotEmpty
//                                                 ? InkWell(
//                                                     onTap: () {
//                                                       // Open file URL
//                                                       print('Open: ${buyer[f]}');
//                                                     },
//                                                     child: Text(
//                                                       'View File',
//                                                       style: TextStyle(
//                                                         color: Colors.blue,
//                                                         decoration: TextDecoration.underline,
//                                                       ),
//                                                     ),
//                                                   )
//                                                 : Text('No file');
//                                           } else {
//                                             return Text(buyer[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

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

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
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

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchBuyers();
//   }

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     final Uri apiUrl = Uri.parse(
//       url ??
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results =
//             List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     // If editing, initialize controllers with buyer data
//     if (isEdit) {
//       editingBuyerId = buyer['id'];
//       editControllers = {};
      
//       // Initialize main field controllers
//       for (var field in buyer.keys) {
//         if (field.toLowerCase() != 'id' && 
//             field != 'role' && 
//             field != 'bp_code' && 
//             field != 'more_detail' &&
//             field != 'pan_attachment' &&
//             field != 'gst_attachment') {
//           editControllers![field] = TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           );
//         }
//       }
      
//       // Initialize more detail controllers
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields - exclude role, bp_code, more_detail, attachments
//                   if (isEdit)
//                     ...editControllers!.entries.where((entry) {
//                       String key = entry.key;
//                       return key != 'role' && 
//                             key != 'bp_code' && 
//                             key != 'more_detail' &&
//                             key != 'pan_attachment' &&
//                             key != 'gst_attachment';
//                     }).map((entry) {
//                       return _buildTextField(
//                         context: context,
//                         field: entry.key,
//                         controller: entry.value,
//                         buyer: buyer,
//                         isEdit: isEdit,
//                         setState: setState,
//                       );
//                     }).toList()
//                   else
//                     ...buyer.entries.where((entry) {
//                       String key = entry.key;
//                       return key != 'id' &&
//                             key != 'role' && 
//                             key != 'bp_code' && 
//                             key != 'more_detail' &&
//                             key != 'pan_attachment' &&
//                             key != 'gst_attachment';
//                     }).map((entry) {
//                       return _buildTextField(
//                         context: context,
//                         field: entry.key,
//                         value: entry.value?.toString() ?? '',
//                         buyer: buyer,
//                         isEdit: isEdit,
//                         setState: setState,
//                       );
//                     }).toList(),
                  
//                   // File attachment fields
//                   _buildFileAttachmentField(
//                     context: context,
//                     field: 'pan_attachment',
//                     label: 'PAN ATTACHMENT',
//                     buyer: buyer,
//                     isEdit: isEdit,
//                     setState: setState,
//                   ),
                  
//                   _buildFileAttachmentField(
//                     context: context,
//                     field: 'gst_attachment',
//                     label: 'GST ATTACHMENT',
//                     buyer: buyer,
//                     isEdit: isEdit,
//                     setState: setState,
//                   ),
                  
//                   // More Detail section
//                   _buildMoreDetailsSection(
//                     buyer: buyer,
//                     isEdit: isEdit,
//                     setState: setState,
//                   ),
//                 ],
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
//                           await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
//                           setState(() {});
//                         },
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

//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields
//     for (var field in dynamicFields) {
//       if (!createControllers.containsKey(field)) {
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields - exclude role, bp_code, more_detail
//                   ...dynamicFields.where((field) => 
//                     field != 'role' && 
//                     field != 'bp_code' && 
//                     field != 'more_detail' &&
//                     field != 'pan_attachment' &&
//                     field != 'gst_attachment'
//                   ).map((field) {
//                     if (!createControllers.containsKey(field)) {
//                       createControllers[field] = TextEditingController();
//                     }
                    
//                     // Regular text fields
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: TextField(
//                         controller: createControllers[field],
//                         decoration: InputDecoration(
//                           labelText: field.replaceAll('_', ' ').toUpperCase(),
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     );
//                   }).toList(),
                  
//                   // File attachment fields for create
//                   _buildCreateFileAttachmentField(
//                     context: context,
//                     field: 'pan_attachment',
//                     label: 'PAN ATTACHMENT',
//                     setState: setState,
//                   ),
                  
//                   _buildCreateFileAttachmentField(
//                     context: context,
//                     field: 'gst_attachment',
//                     label: 'GST ATTACHMENT',
//                     setState: setState,
//                   ),
                  
//                   // More Detail section - placed under GST Attachment
//                   _buildCreateMoreDetailsSection(setState: setState),
//                 ],
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role, bp_code, more_detail
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'role' &&
//             key != 'bp_code' &&
//             key != 'more_detail') {
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role, bp_code, more_detail
//       editControllers!.forEach((key, controller) {
//         if (key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'role' &&
//             key != 'bp_code' &&
//             key != 'more_detail') {
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
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
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
//               ? Center(child: Text('No buyers found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(field
//                                       .replaceAll('_', ' ')
//                                       .toUpperCase()),
//                                 ),
//                               ),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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

//                                   // ACTIONS ONLY IF SELECTED
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           if (f == 'pan_attachment' || f == 'gst_attachment') {
//                                             return buyer[f] != null && buyer[f].toString().isNotEmpty
//                                                 ? InkWell(
//                                                     onTap: () {
//                                                       // Open file URL
//                                                       print('Open: ${buyer[f]}');
//                                                     },
//                                                     child: Text(
//                                                       'View File',
//                                                       style: TextStyle(
//                                                         color: Colors.blue,
//                                                         decoration: TextDecoration.underline,
//                                                       ),
//                                                     ),
//                                                   )
//                                                 : Text('No file');
//                                           } else if (f == 'more_detail') {
//                                             // Show count of more details
//                                             final details = buyer[f];
//                                             if (details != null && details is List) {
//                                               return Text('${details.length} details');
//                                             }
//                                             return Text('No details');
//                                           } else {
//                                             return Text(buyer[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

// very important
// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

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

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
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

//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token');

//     if (token == null || token!.isEmpty) {
//       setState(() => isLoading = false);
//       return;
//     }

//     fetchBuyers();
//   }

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     final Uri apiUrl = Uri.parse(
//       url ??
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results =
//             List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     // If editing, initialize controllers with buyer data
//     if (isEdit) {
//       editingBuyerId = buyer['id'];
//       editControllers = {};
      
//       // Initialize main field controllers with existing data
//       for (var field in buyer.keys) {
//         if (field.toLowerCase() != 'id' && 
//             field != 'role' && 
//             field != 'bp_code' && 
//             field != 'more_detail' &&
//             field != 'pan_attachment' &&
//             field != 'gst_attachment') {
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields - exclude role, bp_code, more_detail, attachments
//                   ...buyer.entries.where((entry) {
//                     String key = entry.key;
//                     return key != 'id' &&
//                           key != 'role' && 
//                           key != 'bp_code' && 
//                           key != 'more_detail' &&
//                           key != 'pan_attachment' &&
//                           key != 'gst_attachment';
//                   }).map((entry) {
//                     // For edit mode, use editControllers, for view mode show the value directly
//                     if (isEdit && editControllers != null && editControllers!.containsKey(entry.key)) {
//                       return _buildTextField(
//                         context: context,
//                         field: entry.key,
//                         controller: editControllers![entry.key],
//                         buyer: buyer,
//                         isEdit: isEdit,
//                         setState: setState,
//                       );
//                     } else {
//                       return _buildTextField(
//                         context: context,
//                         field: entry.key,
//                         value: entry.value?.toString() ?? '',
//                         buyer: buyer,
//                         isEdit: isEdit,
//                         setState: setState,
//                       );
//                     }
//                   }).toList(),
                  
//                   // File attachment fields
//                   _buildFileAttachmentField(
//                     context: context,
//                     field: 'pan_attachment',
//                     label: 'PAN ATTACHMENT',
//                     buyer: buyer,
//                     isEdit: isEdit,
//                     setState: setState,
//                   ),
                  
//                   _buildFileAttachmentField(
//                     context: context,
//                     field: 'gst_attachment',
//                     label: 'GST ATTACHMENT',
//                     buyer: buyer,
//                     isEdit: isEdit,
//                     setState: setState,
//                   ),
                  
//                   // More Detail section
//                   _buildMoreDetailsSection(
//                     buyer: buyer,
//                     isEdit: isEdit,
//                     setState: setState,
//                   ),
//                 ],
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
//                           await pickFile(field == 'pan_attachment' ? 'pan' : 'gst');
//                           setState(() {});
//                         },
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

//   void showAddBuyerDialog() {
//     // Initialize controllers for dynamic fields
//     for (var field in dynamicFields) {
//       if (!createControllers.containsKey(field)) {
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
//             content: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Main fields - exclude role, bp_code, more_detail
//                   ...dynamicFields.where((field) => 
//                     field != 'role' && 
//                     field != 'bp_code' && 
//                     field != 'more_detail' &&
//                     field != 'pan_attachment' &&
//                     field != 'gst_attachment'
//                   ).map((field) {
//                     if (!createControllers.containsKey(field)) {
//                       createControllers[field] = TextEditingController();
//                     }
                    
//                     // Regular text fields
//                     return Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 6),
//                       child: TextField(
//                         controller: createControllers[field],
//                         decoration: InputDecoration(
//                           labelText: field.replaceAll('_', ' ').toUpperCase(),
//                           border: OutlineInputBorder(),
//                         ),
//                       ),
//                     );
//                   }).toList(),
                  
//                   // File attachment fields for create
//                   _buildCreateFileAttachmentField(
//                     context: context,
//                     field: 'pan_attachment',
//                     label: 'PAN ATTACHMENT',
//                     setState: setState,
//                   ),
                  
//                   _buildCreateFileAttachmentField(
//                     context: context,
//                     field: 'gst_attachment',
//                     label: 'GST ATTACHMENT',
//                     setState: setState,
//                   ),
                  
//                   // More Detail section - placed under GST Attachment
//                   _buildCreateMoreDetailsSection(setState: setState),
//                 ],
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role, bp_code, more_detail
//       createControllers.forEach((key, controller) {
//         if (controller.text.isNotEmpty && 
//             key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'role' &&
//             key != 'bp_code' &&
//             key != 'more_detail') {
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
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields - exclude role, bp_code, more_detail
//       editControllers!.forEach((key, controller) {
//         if (key != 'pan_attachment' && 
//             key != 'gst_attachment' &&
//             key != 'role' &&
//             key != 'bp_code' &&
//             key != 'more_detail') {
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
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
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
//               ? Center(child: Text('No buyers found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(field
//                                       .replaceAll('_', ' ')
//                                       .toUpperCase()),
//                                 ),
//                               ),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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

//                                   // ACTIONS ONLY IF SELECTED
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           if (f == 'pan_attachment' || f == 'gst_attachment') {
//                                             return buyer[f] != null && buyer[f].toString().isNotEmpty
//                                                 ? InkWell(
//                                                     onTap: () {
//                                                       // Open file URL
//                                                       print('Open: ${buyer[f]}');
//                                                     },
//                                                     child: Text(
//                                                       'View File',
//                                                       style: TextStyle(
//                                                         color: Colors.blue,
//                                                         decoration: TextDecoration.underline,
//                                                       ),
//                                                     ),
//                                                   )
//                                                 : Text('No file');
//                                           } else if (f == 'more_detail') {
//                                             // Show count of more details
//                                             final details = buyer[f];
//                                             if (details != null && details is List) {
//                                               return Text('${details.length} details');
//                                             }
//                                             return Text('No details');
//                                           } else {
//                                             return Text(buyer[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;

  // For creating new buyer
  final Map<String, TextEditingController> createControllers = {};
  // Store more details as controllers for create
  List<Map<String, TextEditingController>> moreDetailControllers = [];
  
  // For editing existing buyer
  Map<String, TextEditingController>? editControllers;
  List<Map<String, TextEditingController>>? editMoreDetailControllers;
  int? editingBuyerId;
  
  // For file uploads
  File? panAttachmentFile;
  File? gstAttachmentFile;
  String? panAttachmentFileName;
  String? gstAttachmentFileName;

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  @override
  void dispose() {
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
    
    super.dispose();
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

  Future<void> fetchBuyers({String? url}) async {
    if (token == null) return;

    setState(() => isLoading = true);

    final Uri apiUrl = Uri.parse(
      url ??
          'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
    );

    try {
      final response = await http.get(
        apiUrl,
        headers: {'Authorization': 'Token $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final results =
            List<Map<String, dynamic>>.from(data['results'] ?? []);

        if (results.isNotEmpty) {
          dynamicFields = results.first.keys
              .where((k) => k.toLowerCase() != 'id')
              .toList();
        }

        setState(() {
          buyers = results;
          nextUrl = data['next'];
          prevUrl = data['previous'];
          totalCount = data['count'] ?? 0;
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
    if (nextUrl != null) {
      currentPage++;
      fetchBuyers(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && currentPage > 1) {
      currentPage--;
      fetchBuyers(url: prevUrl);
    }
  }

  void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
    // If editing, initialize controllers with buyer data
    if (isEdit) {
      editingBuyerId = buyer['id'];
      editControllers = {};
      
      // Initialize all field controllers except id
      for (var field in buyer.keys) {
        if (field.toLowerCase() != 'id' && 
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
      panAttachmentFile = null;
      gstAttachmentFile = null;
      panAttachmentFileName = null;
      gstAttachmentFileName = null;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Show all fields except 'id' and 'more_detail'
                  ...buyer.entries.where((entry) {
                    String key = entry.key;
                    return key.toLowerCase() != 'id' && key != 'more_detail';
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
                    panAttachmentFile = null;
                    gstAttachmentFile = null;
                    panAttachmentFileName = null;
                    gstAttachmentFileName = null;
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
          if (fileUrl != null && fileUrl.isNotEmpty)
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
          else
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
                            ? (panAttachmentFileName ?? 'Select New PAN File')
                            : (gstAttachmentFileName ?? 'Select New GST File'),
                        ),
                      ),
                    ),
                    if ((field == 'pan_attachment' && panAttachmentFileName != null) ||
                        (field == 'gst_attachment' && gstAttachmentFileName != null))
                      IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            if (field == 'pan_attachment') {
                              panAttachmentFile = null;
                              panAttachmentFileName = null;
                            } else {
                              gstAttachmentFile = null;
                              gstAttachmentFileName = null;
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

  void showAddBuyerDialog() {
    // Initialize controllers for dynamic fields
    for (var field in dynamicFields) {
      if (!createControllers.containsKey(field)) {
        createControllers[field] = TextEditingController();
      }
    }
    
    // Initialize moreDetails controllers
    moreDetailControllers = [];
    // Reset file selections
    panAttachmentFile = null;
    gstAttachmentFile = null;
    panAttachmentFileName = null;
    gstAttachmentFileName = null;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add New Buyer'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  // Main fields - exclude role, bp_code, more_detail
                  ...dynamicFields.where((field) => 
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
                      ? (panAttachmentFileName ?? 'Select PAN File')
                      : (gstAttachmentFileName ?? 'Select GST File'),
                  ),
                ),
              ),
              if ((field == 'pan_attachment' && panAttachmentFileName != null) ||
                  (field == 'gst_attachment' && gstAttachmentFileName != null))
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      if (field == 'pan_attachment') {
                        panAttachmentFile = null;
                        panAttachmentFileName = null;
                      } else {
                        gstAttachmentFile = null;
                        gstAttachmentFileName = null;
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
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
    if (file != null) {
      setState(() {
        if (type == 'pan') {
          panAttachmentFile = File(file.path);
          panAttachmentFileName = path.basename(file.path);
        } else {
          gstAttachmentFile = File(file.path);
          gstAttachmentFileName = path.basename(file.path);
        }
      });
    }
  }

  Future<void> createBuyer() async {
    if (token == null) return;

    setState(() => isLoading = true);

    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/BUYER/create/'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Token $token';

      // Add text fields - exclude more_detail
      createControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty && 
            key != 'pan_attachment' && 
            key != 'gst_attachment' &&
            key != 'more_detail') {
          request.fields[key] = controller.text;
        }
      });

      // Add PAN attachment if selected
      if (panAttachmentFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'pan_attachment',
            panAttachmentFile!.path,
            filename: panAttachmentFileName,
          ),
        );
      }

      // Add GST attachment if selected
      if (gstAttachmentFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'gst_attachment',
            gstAttachmentFile!.path,
            filename: gstAttachmentFileName,
          ),
        );
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
        
        panAttachmentFile = null;
        gstAttachmentFile = null;
        panAttachmentFileName = null;
        gstAttachmentFileName = null;
        
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
        Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/$id/'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Token $token';

      // Add text fields - exclude more_detail
      editControllers!.forEach((key, controller) {
        if (key != 'pan_attachment' && 
            key != 'gst_attachment' &&
            key != 'more_detail') {
          request.fields[key] = controller.text;
        }
      });

      // Add PAN attachment if a new one is selected
      if (panAttachmentFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'pan_attachment',
            panAttachmentFile!.path,
            filename: panAttachmentFileName,
          ),
        );
      }

      // Add GST attachment if a new one is selected
      if (gstAttachmentFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'gst_attachment',
            gstAttachmentFile!.path,
            filename: gstAttachmentFileName,
          ),
        );
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
        
        panAttachmentFile = null;
        gstAttachmentFile = null;
        panAttachmentFileName = null;
        gstAttachmentFileName = null;
        
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Buyers'),
        actions: [
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
              ? Center(child: Text('No buyers found'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            columns: [
                              DataColumn(label: Text('Select')),
                              DataColumn(label: Text('Actions')),
                              ...dynamicFields.map(
                                (field) => DataColumn(
                                  label: Text(field
                                      .replaceAll('_', ' ')
                                      .toUpperCase()),
                                ),
                              ),
                            ],
                            rows: buyers.map((buyer) {
                              final id = buyer['id'];
                              final isSelected = selectedIds.contains(id);

                              return DataRow(
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

                                  // ACTIONS ONLY IF SELECTED
                                  DataCell(
                                    isSelected
                                        ? Row(
                                            children: [
                                              ElevatedButton(
                                                onPressed: () =>
                                                    showBuyerDialog(
                                                        buyer, false),
                                                child: Text('View'),
                                              ),
                                              SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    showBuyerDialog(
                                                        buyer, true),
                                                child: Text('Edit'),
                                              ),
                                            ],
                                          )
                                        : SizedBox.shrink(),
                                  ),

                                  ...dynamicFields.map(
                                    (f) => DataCell(
                                      Builder(
                                        builder: (context) {
                                          if (f == 'pan_attachment' || f == 'gst_attachment') {
                                            return buyer[f] != null && buyer[f].toString().isNotEmpty
                                                ? InkWell(
                                                    onTap: () {
                                                      // Open file URL
                                                      print('Open: ${buyer[f]}');
                                                    },
                                                    child: Text(
                                                      'View File',
                                                      style: TextStyle(
                                                        color: Colors.blue,
                                                        decoration: TextDecoration.underline,
                                                      ),
                                                    ),
                                                  )
                                                : Text('No file');
                                          } else if (f == 'more_detail') {
                                            // Show count of more details
                                            final details = buyer[f];
                                            if (details != null && details is List) {
                                              return Text('${details.length} details');
                                            }
                                            return Text('No details');
                                          } else {
                                            return Text(buyer[f]?.toString() ?? '');
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page $currentPage | Total: $totalCount',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: prevUrl == null ? null : loadPrevPage,
                                child: Text('Previous'),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: nextUrl == null ? null : loadNextPage,
                                child: Text('Next'),
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

// important
// class BuyerPage extends StatefulWidget {
//   @override
//   _BuyerPageState createState() => _BuyerPageState();
// }

// class _BuyerPageState extends State<BuyerPage> {
//   List<Map<String, dynamic>> buyers = [];
//   bool isLoading = true;
//   Set<int> selectedIds = {};
//   String? token;
//   List<String> dynamicFields = [];

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
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

//   Future<void> fetchBuyers({String? url}) async {
//     if (token == null) return;

//     setState(() => isLoading = true);

//     final Uri apiUrl = Uri.parse(
//       url ??
//           'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results =
//             List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           dynamicFields = results.first.keys
//               .where((k) => k.toLowerCase() != 'id')
//               .toList();
//         }

//         setState(() {
//           buyers = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchBuyers(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
//       currentPage--;
//       fetchBuyers(url: prevUrl);
//     }
//   }

//   void showBuyerDialog(Map<String, dynamic> buyer, bool isEdit) {
//     final controllers = {
//       for (var field in buyer.keys)
//         if (field.toLowerCase() != 'id')
//           field: TextEditingController(
//             text: buyer[field]?.toString() ?? '',
//           )
//     };

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Buyer' : 'View Buyer'),
//         content: SingleChildScrollView(
//           child: Column(
//             children: controllers.entries.map((entry) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 6),
//                 child: TextField(
//                   controller: entry.value,
//                   readOnly: !isEdit,
//                   decoration: InputDecoration(
//                     labelText:
//                         entry.key.replaceAll('_', ' ').toUpperCase(),
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//         actions: [
//           if (isEdit)
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//               },
//               child: Text('Save'),
//             ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   void showAddBuyerDialog() {
//     final controllers = {
//       for (var field in dynamicFields)
//         field: TextEditingController(),
//     };

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('Add New Buyer'),
//         content: SingleChildScrollView(
//           child: Column(
//             children: controllers.entries.map((entry) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 6),
//                 child: TextField(
//                   controller: entry.value,
//                   decoration: InputDecoration(
//                     labelText:
//                         entry.key.replaceAll('_', ' ').toUpperCase(),
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//         actions: [
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//             },
//             child: Text('Create'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Buyers'),
//         actions: [
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
//               ? Center(child: Text('No buyers found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(field
//                                       .replaceAll('_', ' ')
//                                       .toUpperCase()),
//                                 ),
//                               ),
//                             ],
//                             rows: buyers.map((buyer) {
//                               final id = buyer['id'];
//                               final isSelected =
//                                   selectedIds.contains(id);

//                               return DataRow(
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

//                                   /// ✅ ACTIONS ONLY IF SELECTED
//                                   DataCell(
//                                     isSelected
//                                         ? Row(
//                                             children: [
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showBuyerDialog(
//                                                         buyer, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Text(buyer[f]?.toString() ?? ''),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment:
//                             MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed:
//                                     prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed:
//                                     nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

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

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose all controllers
//     _disposeAllControllers();
//     super.dispose();
//   }

//   void _disposeAllControllers() {
//     // Dispose edit controllers
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose aadhar detail controllers
//     if (editAadharDetailControllers != null) {
//       for (var controllers in editAadharDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose pan detail controllers
//     if (editPanDetailControllers != null) {
//       for (var controllers in editPanDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose bank detail controllers
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

//     final Uri apiUrl = Uri.parse(
//       url ?? 'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           // Get all field names except id
//           dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
//         }

//         setState(() {
//           kycRecords = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
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

//   void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
//     if (isEdit) {
//       try {
//         // Fetch detailed data for editing
//         setState(() => isLoading = true);
//         final detailedRecord = await fetchKycDetail(kycRecord['id']);
//         setState(() => isLoading = false);
        
//         // Initialize edit mode with fetched data
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
//                   if (isEdit && editControllers != null)
//                     // Edit mode with text fields
//                     ..._buildEditFields(setState)
//                   else
//                     // View mode with read-only text
//                     ..._buildViewFields(kycRecord),
                  
//                   // Show nested arrays in view mode
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
//                     // Clean up all controllers
//                     _disposeAllControllers();
//                     editControllers = null;
//                     editAadharDetailControllers = null;
//                     editPanDetailControllers = null;
//                     editBankDetailControllers = null;
//                     editingKycId = null;
                    
//                     // Reset all file selections
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
    
//     // Initialize main field controllers except id
//     for (var field in kycRecord.keys) {
//       if (field.toLowerCase() != 'id' && 
//           field != 'aadhar_detail' && 
//           field != 'pan_detail' && 
//           field != 'bank_detail') {
//         editControllers![field] = TextEditingController(
//           text: kycRecord[field]?.toString() ?? '',
//         );
//       }
//     }
    
//     // Initialize aadhar detail controllers
//     editAadharDetailControllers = [];
//     if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
//       for (var detail in existingDetails) {
//         editAadharDetailControllers!.add({
//           'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
//           'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Initialize pan detail controllers
//     editPanDetailControllers = [];
//     if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
//       for (var detail in existingDetails) {
//         editPanDetailControllers!.add({
//           'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
//           'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Initialize bank detail controllers
//     editBankDetailControllers = [];
//     if (kycRecord['bank_detail'] != null && kycRecord['bank_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['bank_detail']);
      
//       for (var detail in existingDetails) {
//         editBankDetailControllers!.add({
//           'bank_name': TextEditingController(text: detail['bank_name']?.toString() ?? ''),
//           'account_no': TextEditingController(text: detail['account_no']?.toString() ?? ''),
//           'ifsc_code': TextEditingController(text: detail['ifsc_code']?.toString() ?? ''),
//           'branch': TextEditingController(text: detail['branch']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Reset file selections
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
//   }

//   List<Widget> _buildEditFields(StateSetter setState) {
//     List<Widget> fields = [];
    
//     if (editControllers == null) return fields;
    
//     // Define order of fields if needed
//     List<String> fieldOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     // Add fields in order
//     for (var field in fieldOrder) {
//       if (editControllers!.containsKey(field)) {
//         // Check if this is a file attachment field
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildEditFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             currentValue: editControllers![field]!.text,
//             setState: setState,
//           ));
//         } 
//         // Check if this is a boolean field
//         else if (field == 'is_completed') {
//           fields.add(_buildBooleanField(
//             field: field,
//             label: _getFieldLabel(field),
//             setState: setState,
//           ));
//         }
//         // Regular text field
//         else {
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
    
//     // Add nested arrays for edit mode
//     fields.addAll(_buildNestedArraysEdit(setState));
    
//     return fields;
//   }

//   String _getFieldLabel(String field) {
//     // Convert field name to readable label
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
    
//     // Define order for better display
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
//         // Check if this is a file attachment field
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             value: kycRecord[field],
//           ));
//         }
//         // Regular field
//         else {
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
    
//     // Aadhar Details
//     if (kycRecord['aadhar_detail'] != null && 
//         kycRecord['aadhar_detail'] is List && 
//         (kycRecord['aadhar_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Aadhar Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']),
//         fields: ['aadhar_name', 'aadhar_no'],
//       ));
//     }
    
//     // PAN Details
//     if (kycRecord['pan_detail'] != null && 
//         kycRecord['pan_detail'] is List && 
//         (kycRecord['pan_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'PAN Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['pan_detail']),
//         fields: ['pan_name', 'pan_no'],
//       ));
//     }
    
//     // Bank Details
//     if (kycRecord['bank_detail'] != null && 
//         kycRecord['bank_detail'] is List && 
//         (kycRecord['bank_detail'] as List).isNotEmpty) {
//       arrays.add(_buildNestedArraySection(
//         title: 'Bank Details',
//         details: List<Map<String, dynamic>>.from(kycRecord['bank_detail']),
//         fields: ['bank_name', 'account_no', 'ifsc_code', 'branch'],
//       ));
//     }
    
//     return arrays;
//   }

//   Widget _buildNestedArraySection({
//     required String title,
//     required List<Map<String, dynamic>> details,
//     required List<String> fields,
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
    
//     // Aadhar Details Edit
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Aadhar Details',
//       controllersList: editAadharDetailControllers,
//       fields: [
//         {'key': 'aadhar_name', 'label': 'Aadhar Name'},
//         {'key': 'aadhar_no', 'label': 'Aadhar Number'},
//       ],
//       onAdd: () {
//         setState(() {
//           editAadharDetailControllers ??= [];
//           editAadharDetailControllers!.add({
//             'aadhar_name': TextEditingController(),
//             'aadhar_no': TextEditingController(),
//           });
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editAadharDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editAadharDetailControllers!.removeAt(index);
//         });
//       },
//     ));
    
//     // PAN Details Edit
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'PAN Details',
//       controllersList: editPanDetailControllers,
//       fields: [
//         {'key': 'pan_name', 'label': 'PAN Name'},
//         {'key': 'pan_no', 'label': 'PAN Number'},
//       ],
//       onAdd: () {
//         setState(() {
//           editPanDetailControllers ??= [];
//           editPanDetailControllers!.add({
//             'pan_name': TextEditingController(),
//             'pan_no': TextEditingController(),
//           });
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editPanDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editPanDetailControllers!.removeAt(index);
//         });
//       },
//     ));
    
//     // Bank Details Edit
//     arrays.add(_buildNestedArrayEditSection(
//       title: 'Bank Details',
//       controllersList: editBankDetailControllers,
//       fields: [
//         {'key': 'bank_name', 'label': 'Bank Name'},
//         {'key': 'account_no', 'label': 'Account Number'},
//         {'key': 'ifsc_code', 'label': 'IFSC Code'},
//         {'key': 'branch', 'label': 'Branch'},
//       ],
//       onAdd: () {
//         setState(() {
//           editBankDetailControllers ??= [];
//           editBankDetailControllers!.add({
//             'bank_name': TextEditingController(),
//             'account_no': TextEditingController(),
//             'ifsc_code': TextEditingController(),
//             'branch': TextEditingController(),
//           });
//         });
//       },
//       onDelete: (index) {
//         setState(() {
//           editBankDetailControllers![index].forEach((key, controller) {
//             controller.dispose();
//           });
//           editBankDetailControllers!.removeAt(index);
//         });
//       },
//     ));
    
//     return arrays;
//   }

//   Widget _buildNestedArrayEditSection({
//     required String title,
//     required List<Map<String, TextEditingController>>? controllersList,
//     required List<Map<String, String>> fields,
//     required VoidCallback onAdd,
//     required Function(int) onDelete,
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
          
//           // Show current file if exists
//           if (currentValue.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     print('Current File URL: $currentValue');
//                   },
//                   child: Text(
//                     'View Current Attachment',
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
//                     _getFileName(field) ?? 'Select New File',
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
//         return panAttachmentFileName ?? 'Select New PAN File';
//       case 'gst_attachment':
//         return gstAttachmentFileName ?? 'Select New GST File';
//       case 'bis_attachment':
//         return bisAttachmentFileName ?? 'Select New BIS File';
//       case 'msme_attachment':
//         return msmeAttachmentFileName ?? 'Select New MSME File';
//       case 'tan_attachment':
//         return tanAttachmentFileName ?? 'Select New TAN File';
//       case 'cin_attach':
//         return cinAttachmentFileName ?? 'Select New CIN File';
//       default:
//         return 'Select New File';
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

//   Future<void> updateKYC(int id) async {
//     if (token == null || editControllers == null) return;

//     setState(() => isLoading = true);

//     try {
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       editControllers!.forEach((key, controller) {
//         // Don't add file fields as text
//         if (!key.endsWith('_attachment') && key != 'cin_attach') {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add file attachments
//       await _addFileAttachments(request);

//       // Add nested arrays
//       _addNestedArrays(request);

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
        
//         // Refresh the KYC list
//         fetchKYCRecords();
        
//         // Show success message
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
//     // Add PAN attachment
//     if (panAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'pan_attachment',
//           panAttachmentFile!.path,
//           filename: panAttachmentFileName,
//         ),
//       );
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
//     }
//   }

//   void _addNestedArrays(http.MultipartRequest request) {
//     // Add aadhar details
//     if (editAadharDetailControllers != null) {
//       for (int i = 0; i < editAadharDetailControllers!.length; i++) {
//         var controllers = editAadharDetailControllers![i];
//         String name = controllers['aadhar_name']?.text.trim() ?? '';
//         String number = controllers['aadhar_no']?.text.trim() ?? '';
        
//         if (name.isNotEmpty || number.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_name]'] = name;
//           request.fields['aadhar_detail[$i][aadhar_no]'] = number;
//         }
//       }
//     }

//     // Add pan details
//     if (editPanDetailControllers != null) {
//       for (int i = 0; i < editPanDetailControllers!.length; i++) {
//         var controllers = editPanDetailControllers![i];
//         String name = controllers['pan_name']?.text.trim() ?? '';
//         String number = controllers['pan_no']?.text.trim() ?? '';
        
//         if (name.isNotEmpty || number.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_name]'] = name;
//           request.fields['pan_detail[$i][pan_no]'] = number;
//         }
//       }
//     }

//     // Add bank details
//     if (editBankDetailControllers != null) {
//       for (int i = 0; i < editBankDetailControllers!.length; i++) {
//         var controllers = editBankDetailControllers![i];
//         String bankName = controllers['bank_name']?.text.trim() ?? '';
//         String accountNo = controllers['account_no']?.text.trim() ?? '';
//         String ifscCode = controllers['ifsc_code']?.text.trim() ?? '';
//         String branch = controllers['branch']?.text.trim() ?? '';
        
//         if (bankName.isNotEmpty || accountNo.isNotEmpty || 
//             ifscCode.isNotEmpty || branch.isNotEmpty) {
//           request.fields['bank_detail[$i][bank_name]'] = bankName;
//           request.fields['bank_detail[$i][account_no]'] = accountNo;
//           request.fields['bank_detail[$i][ifsc_code]'] = ifscCode;
//           request.fields['bank_detail[$i][branch]'] = branch;
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(child: Text('No KYC records found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(_getFieldLabel(field)),
//                                 ),
//                               ),
//                             ],
//                             rows: kycRecords.map((record) {
//                               final id = record['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           // Handle file attachment fields
//                                           if (f.endsWith('_attachment') || f == 'cin_attach') {
//                                             return record[f] != null && record[f].toString().isNotEmpty
//                                                 ? Row(
//                                                     children: [
//                                                       Icon(Icons.attach_file, size: 16),
//                                                       SizedBox(width: 4),
//                                                       InkWell(
//                                                         onTap: () {
//                                                           print('Open: ${record[f]}');
//                                                         },
//                                                         child: Text(
//                                                           'View',
//                                                           style: TextStyle(
//                                                             color: Colors.blue,
//                                                             decoration: TextDecoration.underline,
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   )
//                                                 : Text('No file');
//                                           }
//                                           // Handle nested arrays
//                                           else if (f == 'aadhar_detail' || f == 'pan_detail' || f == 'bank_detail') {
//                                             final details = record[f];
//                                             if (details != null && details is List) {
//                                               return Text('${details.length} items');
//                                             }
//                                             return Text('0 items');
//                                           }
//                                           // Handle boolean field
//                                           else if (f == 'is_completed') {
//                                             bool value = record[f] == true;
//                                             return Text(value ? 'Yes' : 'No');
//                                           }
//                                           // Regular field
//                                           else {
//                                             return Text(record[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     // Pagination controls
//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

  String? nextUrl;
  String? prevUrl;
  int totalCount = 0;
  int currentPage = 1;

  // For editing KYC
  Map<String, TextEditingController>? editControllers;
  List<Map<String, TextEditingController>>? editAadharDetailControllers;
  List<Map<String, TextEditingController>>? editPanDetailControllers;
  List<Map<String, TextEditingController>>? editBankDetailControllers;
  int? editingKycId;
  
  // For file uploads - NEW: Track existing file URLs
  File? panAttachmentFile;
  File? gstAttachmentFile;
  File? bisAttachmentFile;
  File? msmeAttachmentFile;
  File? tanAttachmentFile;
  File? cinAttachmentFile;
  String? panAttachmentFileName;
  String? gstAttachmentFileName;
  String? bisAttachmentFileName;
  String? msmeAttachmentFileName;
  String? tanAttachmentFileName;
  String? cinAttachmentFileName;
  
  // Store existing file URLs to preserve them
  String? existingPanAttachmentUrl;
  String? existingGstAttachmentUrl;
  String? existingBisAttachmentUrl;
  String? existingMsmeAttachmentUrl;
  String? existingTanAttachmentUrl;
  String? existingCinAttachmentUrl;
  
  // For nested array file uploads - NEW: Track existing file URLs
  Map<int, File> aadharAttachmentFiles = {};
  Map<int, String> aadharAttachmentFileNames = {};
  Map<int, File> panDetailAttachmentFiles = {};
  Map<int, String> panDetailAttachmentFileNames = {};
  Map<int, File> bankChequeLeafFiles = {};
  Map<int, String> bankChequeLeafFileNames = {};
  
  // Store existing file URLs for nested arrays
  List<String?> existingAadharAttachmentUrls = [];
  List<String?> existingPanAttachmentUrls = [];
  List<String?> existingChequeLeafUrls = [];

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  @override
  void dispose() {
    _disposeAllControllers();
    super.dispose();
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

    final Uri apiUrl = Uri.parse(
      url ?? 'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/',
    );

    try {
      final response = await http.get(
        apiUrl,
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
    if (nextUrl != null) {
      currentPage++;
      fetchKYCRecords(url: nextUrl);
    }
  }

  void loadPrevPage() {
    if (prevUrl != null && currentPage > 1) {
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

  // NEW: Function to mark KYC as completed
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

  // NEW: Function to show confirmation dialog for complete/reopen
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
                  // NEW: Show completion status prominently
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

  void _resetFileSelections() {
    panAttachmentFile = null;
    gstAttachmentFile = null;
    bisAttachmentFile = null;
    msmeAttachmentFile = null;
    tanAttachmentFile = null;
    cinAttachmentFile = null;
    panAttachmentFileName = null;
    gstAttachmentFileName = null;
    bisAttachmentFileName = null;
    msmeAttachmentFileName = null;
    tanAttachmentFileName = null;
    cinAttachmentFileName = null;
    aadharAttachmentFiles.clear();
    aadharAttachmentFileNames.clear();
    panDetailAttachmentFiles.clear();
    panDetailAttachmentFileNames.clear();
    bankChequeLeafFiles.clear();
    bankChequeLeafFileNames.clear();
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
      fileMap: aadharAttachmentFiles,
      fileNameMap: aadharAttachmentFileNames,
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
          aadharAttachmentFiles.remove(index);
          aadharAttachmentFileNames.remove(index);
          existingAadharAttachmentUrls.removeAt(index);
        });
      },
      onPickFile: (index) async {
        await pickNestedArrayFile('aadhar', index);
        setState(() {});
      },
      onClearFile: (index) {
        setState(() {
          aadharAttachmentFiles.remove(index);
          aadharAttachmentFileNames.remove(index);
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
      fileMap: panDetailAttachmentFiles,
      fileNameMap: panDetailAttachmentFileNames,
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
          panDetailAttachmentFiles.remove(index);
          panDetailAttachmentFileNames.remove(index);
          existingPanAttachmentUrls.removeAt(index);
        });
      },
      onPickFile: (index) async {
        await pickNestedArrayFile('pan_detail', index);
        setState(() {});
      },
      onClearFile: (index) {
        setState(() {
          panDetailAttachmentFiles.remove(index);
          panDetailAttachmentFileNames.remove(index);
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
      fileMap: bankChequeLeafFiles,
      fileNameMap: bankChequeLeafFileNames,
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
          bankChequeLeafFiles.remove(index);
          bankChequeLeafFileNames.remove(index);
          existingChequeLeafUrls.removeAt(index);
        });
      },
      onPickFile: (index) async {
        await pickNestedArrayFile('cheque_leaf', index);
        setState(() {});
      },
      onClearFile: (index) {
        setState(() {
          bankChequeLeafFiles.remove(index);
          bankChequeLeafFileNames.remove(index);
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
    required Map<int, File> fileMap,
    required Map<int, String> fileNameMap,
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
                            
                            // Show existing file link if exists
                            if (existingUrl != null && existingUrl.isNotEmpty)
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
                                      fileNameMap[index] ?? 
                                      (existingUrl != null && existingUrl.isNotEmpty ? 
                                        'Keep Existing / Select New' : 
                                        'Select $fileFieldLabel'),
                                    ),
                                  ),
                                ),
                                if (fileNameMap.containsKey(index))
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
    switch (field) {
      case 'pan_attachment':
        existingUrl = existingPanAttachmentUrl;
        break;
      case 'gst_attachment':
        existingUrl = existingGstAttachmentUrl;
        break;
      case 'bis_attachment':
        existingUrl = existingBisAttachmentUrl;
        break;
      case 'msme_attachment':
        existingUrl = existingMsmeAttachmentUrl;
        break;
      case 'tan_attachment':
        existingUrl = existingTanAttachmentUrl;
        break;
      case 'cin_attach':
        existingUrl = existingCinAttachmentUrl;
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
          
          // Show existing file link if exists
          if (existingUrl != null && existingUrl.isNotEmpty)
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
                    _getFileName(field) ?? 
                    (existingUrl != null && existingUrl.isNotEmpty ? 
                      'Keep Existing / Select New' : 
                      'Select File'),
                  ),
                ),
              ),
              if (_hasFileSelected(field))
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _clearFileSelection(field);
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _getFileName(String field) {
    switch (field) {
      case 'pan_attachment':
        return panAttachmentFileName;
      case 'gst_attachment':
        return gstAttachmentFileName;
      case 'bis_attachment':
        return bisAttachmentFileName;
      case 'msme_attachment':
        return msmeAttachmentFileName;
      case 'tan_attachment':
        return tanAttachmentFileName;
      case 'cin_attach':
        return cinAttachmentFileName;
      default:
        return null;
    }
  }

  bool _hasFileSelected(String field) {
    switch (field) {
      case 'pan_attachment':
        return panAttachmentFileName != null;
      case 'gst_attachment':
        return gstAttachmentFileName != null;
      case 'bis_attachment':
        return bisAttachmentFileName != null;
      case 'msme_attachment':
        return msmeAttachmentFileName != null;
      case 'tan_attachment':
        return tanAttachmentFileName != null;
      case 'cin_attach':
        return cinAttachmentFileName != null;
      default:
        return false;
    }
  }

  void _clearFileSelection(String field) {
    switch (field) {
      case 'pan_attachment':
        panAttachmentFile = null;
        panAttachmentFileName = null;
        break;
      case 'gst_attachment':
        gstAttachmentFile = null;
        gstAttachmentFileName = null;
        break;
      case 'bis_attachment':
        bisAttachmentFile = null;
        bisAttachmentFileName = null;
        break;
      case 'msme_attachment':
        msmeAttachmentFile = null;
        msmeAttachmentFileName = null;
        break;
      case 'tan_attachment':
        tanAttachmentFile = null;
        tanAttachmentFileName = null;
        break;
      case 'cin_attach':
        cinAttachmentFile = null;
        cinAttachmentFileName = null;
        break;
    }
  }

  Future<void> pickFile(String field) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
    if (file != null) {
      setState(() {
        switch (field) {
          case 'pan_attachment':
            panAttachmentFile = File(file.path);
            panAttachmentFileName = path.basename(file.path);
            break;
          case 'gst_attachment':
            gstAttachmentFile = File(file.path);
            gstAttachmentFileName = path.basename(file.path);
            break;
          case 'bis_attachment':
            bisAttachmentFile = File(file.path);
            bisAttachmentFileName = path.basename(file.path);
            break;
          case 'msme_attachment':
            msmeAttachmentFile = File(file.path);
            msmeAttachmentFileName = path.basename(file.path);
            break;
          case 'tan_attachment':
            tanAttachmentFile = File(file.path);
            tanAttachmentFileName = path.basename(file.path);
            break;
          case 'cin_attach':
            cinAttachmentFile = File(file.path);
            cinAttachmentFileName = path.basename(file.path);
            break;
        }
      });
    }
  }

  Future<void> pickNestedArrayFile(String type, int index) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    
    if (file != null) {
      setState(() {
        switch (type) {
          case 'aadhar':
            aadharAttachmentFiles[index] = File(file.path);
            aadharAttachmentFileNames[index] = path.basename(file.path);
            break;
          case 'pan_detail':
            panDetailAttachmentFiles[index] = File(file.path);
            panDetailAttachmentFileNames[index] = path.basename(file.path);
            break;
          case 'cheque_leaf':
            bankChequeLeafFiles[index] = File(file.path);
            bankChequeLeafFileNames[index] = path.basename(file.path);
            break;
        }
      });
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

  Future<void> _addFileAttachments(http.MultipartRequest request) async {
    // Add PAN attachment only if new file is selected
    if (panAttachmentFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'pan_attachment',
          panAttachmentFile!.path,
          filename: panAttachmentFileName,
        ),
      );
    } else if (existingPanAttachmentUrl != null && existingPanAttachmentUrl!.isNotEmpty) {
      request.fields['pan_attachment'] = existingPanAttachmentUrl!;
    }

    // Add GST attachment
    if (gstAttachmentFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'gst_attachment',
          gstAttachmentFile!.path,
          filename: gstAttachmentFileName,
        ),
      );
    } else if (existingGstAttachmentUrl != null && existingGstAttachmentUrl!.isNotEmpty) {
      request.fields['gst_attachment'] = existingGstAttachmentUrl!;
    }

    // Add BIS attachment
    if (bisAttachmentFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'bis_attachment',
          bisAttachmentFile!.path,
          filename: bisAttachmentFileName,
        ),
      );
    } else if (existingBisAttachmentUrl != null && existingBisAttachmentUrl!.isNotEmpty) {
      request.fields['bis_attachment'] = existingBisAttachmentUrl!;
    }

    // Add MSME attachment
    if (msmeAttachmentFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'msme_attachment',
          msmeAttachmentFile!.path,
          filename: msmeAttachmentFileName,
        ),
      );
    } else if (existingMsmeAttachmentUrl != null && existingMsmeAttachmentUrl!.isNotEmpty) {
      request.fields['msme_attachment'] = existingMsmeAttachmentUrl!;
    }

    // Add TAN attachment
    if (tanAttachmentFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'tan_attachment',
          tanAttachmentFile!.path,
          filename: tanAttachmentFileName,
        ),
      );
    } else if (existingTanAttachmentUrl != null && existingTanAttachmentUrl!.isNotEmpty) {
      request.fields['tan_attachment'] = existingTanAttachmentUrl!;
    }

    // Add CIN attachment
    if (cinAttachmentFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'cin_attach',
          cinAttachmentFile!.path,
          filename: cinAttachmentFileName,
        ),
      );
    } else if (existingCinAttachmentUrl != null && existingCinAttachmentUrl!.isNotEmpty) {
      request.fields['cin_attach'] = existingCinAttachmentUrl!;
    }
  }

  Future<void> _addNestedArrays(http.MultipartRequest request) async {
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
        if (aadharAttachmentFiles.containsKey(i)) {
          File? file = aadharAttachmentFiles[i];
          String? filename = aadharAttachmentFileNames[i];
          
          if (file != null && filename != null && filename.isNotEmpty) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'aadhar_detail[$i][aadhar_attach]',
                file.path,
                filename: filename,
              ),
            );
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
        if (panDetailAttachmentFiles.containsKey(i)) {
          File? file = panDetailAttachmentFiles[i];
          String? filename = panDetailAttachmentFileNames[i];
          
          if (file != null && filename != null && filename.isNotEmpty) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'pan_detail[$i][pan_attachment]',
                file.path,
                filename: filename,
              ),
            );
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
        request.fields['bank_detail[$i][bank_name]'] = controllers['bank_name']?.text.trim() ?? '';
        request.fields['bank_detail[$i][account_name]'] = controllers['account_name']?.text.trim() ?? '';
        request.fields['bank_detail[$i][account_no]'] = controllers['account_no']?.text.trim() ?? '';
        request.fields['bank_detail[$i][ifsc_code]'] = controllers['ifsc_code']?.text.trim() ?? '';
        request.fields['bank_detail[$i][branch]'] = controllers['branch']?.text.trim() ?? '';
        request.fields['bank_detail[$i][bank_city]'] = controllers['bank_city']?.text.trim() ?? '';
        request.fields['bank_detail[$i][bank_state]'] = controllers['bank_state']?.text.trim() ?? '';
        
        // Add file attachment if new file is selected
        if (bankChequeLeafFiles.containsKey(i)) {
          File? file = bankChequeLeafFiles[i];
          String? filename = bankChequeLeafFileNames[i];
          
          if (file != null && filename != null && filename.isNotEmpty) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'bank_detail[$i][cheque_leaf]',
                file.path,
                filename: filename,
              ),
            );
          }
        } else if (i < existingChequeLeafUrls.length && 
                   existingChequeLeafUrls[i] != null && 
                   existingChequeLeafUrls[i]!.isNotEmpty) {
          request.fields['bank_detail[$i][cheque_leaf]'] = existingChequeLeafUrls[i]!;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KYC Records'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : kycRecords.isEmpty
              ? Center(child: Text('No KYC records found'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 24,
                            columns: [
                              DataColumn(label: Text('Select')),
                              DataColumn(label: Text('Actions')),
                              ...dynamicFields.map(
                                (field) => DataColumn(
                                  label: Text(_getFieldLabel(field)),
                                ),
                              ),
                            ],
                            rows: kycRecords.map((record) {
                              final id = record['id'];
                              final isSelected = selectedIds.contains(id);
                              final bool isCompleted = record['is_completed'] == true;

                              return DataRow(
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

                                  DataCell(
                                    isSelected
                                        ? Row(
                                            children: [
                                              // View button
                                              ElevatedButton(
                                                onPressed: () =>
                                                    showKYCDetailDialog(record, false),
                                                child: Text('View'),
                                              ),
                                              SizedBox(width: 8),
                                              
                                              // Edit button - disabled if completed
                                              if (!isCompleted)
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      showKYCDetailDialog(record, true),
                                                  child: Text('Edit'),
                                                ),
                                              SizedBox(width: isCompleted ? 0 : 8),
                                              
                                              // Complete/Reopen button
                                              ElevatedButton(
                                                onPressed: () => _showCompletionDialog(record),
                                                child: Text(isCompleted ? 'Reopen' : 'Complete'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: isCompleted ? Colors.orange : Colors.green,
                                                ),
                                              ),
                                            ],
                                          )
                                        : SizedBox.shrink(),
                                  ),

                                  ...dynamicFields.map(
                                    (f) => DataCell(
                                      Builder(
                                        builder: (context) {
                                          if (f.endsWith('_attachment') || f == 'cin_attach') {
                                            return record[f] != null && record[f].toString().isNotEmpty
                                                ? Row(
                                                    children: [
                                                      Icon(Icons.attach_file, size: 16),
                                                      SizedBox(width: 4),
                                                      InkWell(
                                                        onTap: () {
                                                          print('Open: ${record[f]}');
                                                        },
                                                        child: Text(
                                                          'View',
                                                          style: TextStyle(
                                                            color: Colors.blue,
                                                            decoration: TextDecoration.underline,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Text('No file');
                                          }
                                          else if (f == 'aadhar_detail' || f == 'pan_detail' || f == 'bank_detail') {
                                            final details = record[f];
                                            if (details != null && details is List) {
                                              return Text('${details.length} items');
                                            }
                                            return Text('0 items');
                                          }
                                          else if (f == 'is_completed') {
                                            bool value = record[f] == true;
                                            return Row(
                                              children: [
                                                Icon(
                                                  value ? Icons.lock : Icons.lock_open,
                                                  color: value ? Colors.green : Colors.orange,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(value ? 'Completed' : 'In Progress'),
                                              ],
                                            );
                                          }
                                          else {
                                            return Text(record[f]?.toString() ?? '');
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page $currentPage | Total: $totalCount',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: prevUrl == null ? null : loadPrevPage,
                                child: Text('Previous'),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: nextUrl == null ? null : loadNextPage,
                                child: Text('Next'),
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

// very important
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

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

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
//     loadToken();
//   }

//   @override
//   void dispose() {
//     _disposeAllControllers();
//     super.dispose();
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

//     final Uri apiUrl = Uri.parse(
//       url ?? 'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
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
    
//     // Don't clear existing URLs here - they should persist
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
//           // Don't clear existing URL
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
//           // Don't clear existing URL
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
//           // Don't clear existing URL
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
//       // If no new file but existing file exists, we need to preserve it
//       // Check if your backend API supports sending the URL as a field
//       // Some backends handle this differently
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
//           // Preserve existing file URL
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
//           // Preserve existing file URL
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
//           // Preserve existing file URL
//           request.fields['bank_detail[$i][cheque_leaf]'] = existingChequeLeafUrls[i]!;
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(child: Text('No KYC records found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(_getFieldLabel(field)),
//                                 ),
//                               ),
//                             ],
//                             rows: kycRecords.map((record) {
//                               final id = record['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           if (f.endsWith('_attachment') || f == 'cin_attach') {
//                                             return record[f] != null && record[f].toString().isNotEmpty
//                                                 ? Row(
//                                                     children: [
//                                                       Icon(Icons.attach_file, size: 16),
//                                                       SizedBox(width: 4),
//                                                       InkWell(
//                                                         onTap: () {
//                                                           print('Open: ${record[f]}');
//                                                         },
//                                                         child: Text(
//                                                           'View',
//                                                           style: TextStyle(
//                                                             color: Colors.blue,
//                                                             decoration: TextDecoration.underline,
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   )
//                                                 : Text('No file');
//                                           }
//                                           else if (f == 'aadhar_detail' || f == 'pan_detail' || f == 'bank_detail') {
//                                             final details = record[f];
//                                             if (details != null && details is List) {
//                                               return Text('${details.length} items');
//                                             }
//                                             return Text('0 items');
//                                           }
//                                           else if (f == 'is_completed') {
//                                             bool value = record[f] == true;
//                                             return Text(value ? 'Yes' : 'No');
//                                           }
//                                           else {
//                                             return Text(record[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

// important
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

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

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
//   // For nested array file uploads
//   Map<int, File> aadharAttachmentFiles = {};
//   Map<int, String> aadharAttachmentFileNames = {};
//   Map<int, File> panDetailAttachmentFiles = {};
//   Map<int, String> panDetailAttachmentFileNames = {};
//   Map<int, File> bankChequeLeafFiles = {};
//   Map<int, String> bankChequeLeafFileNames = {};
  
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;
//   String? bisAttachmentFileName;
//   String? msmeAttachmentFileName;
//   String? tanAttachmentFileName;
//   String? cinAttachmentFileName;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose all controllers
//     _disposeAllControllers();
//     super.dispose();
//   }

//   void _disposeAllControllers() {
//     // Dispose edit controllers
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose aadhar detail controllers
//     if (editAadharDetailControllers != null) {
//       for (var controllers in editAadharDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose pan detail controllers
//     if (editPanDetailControllers != null) {
//       for (var controllers in editPanDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose bank detail controllers
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

//     final Uri apiUrl = Uri.parse(
//       url ?? 'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           // Get all field names except id
//           dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
//         }

//         setState(() {
//           kycRecords = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
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

//   void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
//     if (isEdit) {
//       try {
//         // Fetch detailed data for editing
//         setState(() => isLoading = true);
//         final detailedRecord = await fetchKycDetail(kycRecord['id']);
//         setState(() => isLoading = false);
        
//         // Initialize edit mode with fetched data
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
//                   if (isEdit && editControllers != null)
//                     // Edit mode with text fields
//                     ..._buildEditFields(setState)
//                   else
//                     // View mode with read-only text
//                     ..._buildViewFields(kycRecord),
                  
//                   // Show nested arrays in view mode
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
//                     // Clean up all controllers
//                     _disposeAllControllers();
//                     editControllers = null;
//                     editAadharDetailControllers = null;
//                     editPanDetailControllers = null;
//                     editBankDetailControllers = null;
//                     editingKycId = null;
                    
//                     // Reset all file selections
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
    
//     // Initialize main field controllers except id
//     for (var field in kycRecord.keys) {
//       if (field.toLowerCase() != 'id' && 
//           field != 'aadhar_detail' && 
//           field != 'pan_detail' && 
//           field != 'bank_detail') {
//         editControllers![field] = TextEditingController(
//           text: kycRecord[field]?.toString() ?? '',
//         );
//       }
//     }
    
//     // Initialize aadhar detail controllers with all fields
//     editAadharDetailControllers = [];
//     if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
//       for (var detail in existingDetails) {
//         editAadharDetailControllers!.add({
//           'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
//           'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Initialize pan detail controllers with all fields
//     editPanDetailControllers = [];
//     if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
//       for (var detail in existingDetails) {
//         editPanDetailControllers!.add({
//           'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
//           'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Initialize bank detail controllers with all fields
//     editBankDetailControllers = [];
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
//       }
//     }
    
//     // Reset file selections
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
    
//     // Define order of fields if needed
//     List<String> fieldOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     // Add fields in order
//     for (var field in fieldOrder) {
//       if (editControllers!.containsKey(field)) {
//         // Check if this is a file attachment field
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildEditFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             currentValue: editControllers![field]!.text,
//             setState: setState,
//           ));
//         } 
//         // Check if this is a boolean field
//         else if (field == 'is_completed') {
//           fields.add(_buildBooleanField(
//             field: field,
//             label: _getFieldLabel(field),
//             setState: setState,
//           ));
//         }
//         // Regular text field
//         else {
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
    
//     // Add nested arrays for edit mode
//     fields.addAll(_buildNestedArraysEdit(setState));
    
//     return fields;
//   }

//   String _getFieldLabel(String field) {
//     // Convert field name to readable label
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
    
//     // Define order for better display
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
//         // Check if this is a file attachment field
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             value: kycRecord[field],
//           ));
//         }
//         // Regular field
//         else {
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
    
//     // Aadhar Details
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
    
//     // PAN Details
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
    
//     // Bank Details
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
//                   // Text fields
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
//                   // File attachment fields
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
    
//     // Aadhar Details Edit
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
//       onAdd: () {
//         setState(() {
//           editAadharDetailControllers ??= [];
//           editAadharDetailControllers!.add({
//             'aadhar_name': TextEditingController(),
//             'aadhar_no': TextEditingController(),
//           });
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
    
//     // PAN Details Edit
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
//       onAdd: () {
//         setState(() {
//           editPanDetailControllers ??= [];
//           editPanDetailControllers!.add({
//             'pan_name': TextEditingController(),
//             'pan_no': TextEditingController(),
//           });
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
    
//     // Bank Details Edit
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
                    
//                     // File attachment for nested array
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
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () => onPickFile(index),
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(
//                                       fileNameMap[index] ?? 'Select $fileFieldLabel',
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
          
//           // Show current file if exists
//           if (currentValue.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     print('Current File URL: $currentValue');
//                   },
//                   child: Text(
//                     'View Current Attachment',
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
//                     _getFileName(field) ?? 'Select New File',
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
//         return panAttachmentFileName ?? 'Select New PAN File';
//       case 'gst_attachment':
//         return gstAttachmentFileName ?? 'Select New GST File';
//       case 'bis_attachment':
//         return bisAttachmentFileName ?? 'Select New BIS File';
//       case 'msme_attachment':
//         return msmeAttachmentFileName ?? 'Select New MSME File';
//       case 'tan_attachment':
//         return tanAttachmentFileName ?? 'Select New TAN File';
//       case 'cin_attach':
//         return cinAttachmentFileName ?? 'Select New CIN File';
//       default:
//         return 'Select New File';
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
//       // Use PATCH request instead of PUT to preserve existing files
//       // PATCH only updates the fields that are sent
//       var request = http.MultipartRequest(
//         'PUT', // Changed from PUT to PATCH
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add ONLY non-empty text fields
//       editControllers!.forEach((key, controller) {
//         // Skip file attachment fields as text
//         if (!key.endsWith('_attachment') && key != 'cin_attach') {
//           // Only add field if it has a value
//           if (controller.text.trim().isNotEmpty) {
//             request.fields[key] = controller.text.trim();
//           }
//         }
//       });

//       // Add file attachments ONLY if new files are selected
//       await _addFileAttachments(request);

//       // Add nested arrays - now async
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
        
//         // Refresh the KYC list
//         fetchKYCRecords();
        
//         // Show success message
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

//   Future<void> _addFileAttachments(http.MultipartRequest request) async {
//     // Add PAN attachment ONLY if new file is selected
//     if (panAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'pan_attachment',
//           panAttachmentFile!.path,
//           filename: panAttachmentFileName,
//         ),
//       );
//     }

//     // Add GST attachment ONLY if new file is selected
//     if (gstAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'gst_attachment',
//           gstAttachmentFile!.path,
//           filename: gstAttachmentFileName,
//         ),
//       );
//     }

//     // Add BIS attachment ONLY if new file is selected
//     if (bisAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'bis_attachment',
//           bisAttachmentFile!.path,
//           filename: bisAttachmentFileName,
//         ),
//       );
//     }

//     // Add MSME attachment ONLY if new file is selected
//     if (msmeAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'msme_attachment',
//           msmeAttachmentFile!.path,
//           filename: msmeAttachmentFileName,
//         ),
//       );
//     }

//     // Add TAN attachment ONLY if new file is selected
//     if (tanAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'tan_attachment',
//           tanAttachmentFile!.path,
//           filename: tanAttachmentFileName,
//         ),
//       );
//     }

//     // Add CIN attachment ONLY if new file is selected
//     if (cinAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'cin_attach',
//           cinAttachmentFile!.path,
//           filename: cinAttachmentFileName,
//         ),
//       );
//     }
//   }

//   Future<void> _addNestedArrays(http.MultipartRequest request) async {
//     // Add aadhar details with file attachments
//     if (editAadharDetailControllers != null) {
//       for (int i = 0; i < editAadharDetailControllers!.length; i++) {
//         var controllers = editAadharDetailControllers![i];
//         String name = controllers['aadhar_name']?.text.trim() ?? '';
//         String number = controllers['aadhar_no']?.text.trim() ?? '';
        
//         // Only add if at least one field has data
//         if (name.isNotEmpty || number.isNotEmpty) {
//           if (name.isNotEmpty) {
//             request.fields['aadhar_detail[$i][aadhar_name]'] = name;
//           }
//           if (number.isNotEmpty) {
//             request.fields['aadhar_detail[$i][aadhar_no]'] = number;
//           }
//         }
//       }
      
//       // Add aadhar file attachments ONLY if new files are selected
//       for (var entry in aadharAttachmentFiles.entries) {
//         int index = entry.key;
//         File file = entry.value;
//         String? filename = aadharAttachmentFileNames[index];
        
//         if (filename != null && filename.isNotEmpty) {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'aadhar_detail[$index][aadhar_attach]',
//               file.path,
//               filename: filename,
//             ),
//           );
//         }
//       }
//     }

//     // Add pan details with file attachments
//     if (editPanDetailControllers != null) {
//       for (int i = 0; i < editPanDetailControllers!.length; i++) {
//         var controllers = editPanDetailControllers![i];
//         String name = controllers['pan_name']?.text.trim() ?? '';
//         String number = controllers['pan_no']?.text.trim() ?? '';
        
//         // Only add if at least one field has data
//         if (name.isNotEmpty || number.isNotEmpty) {
//           if (name.isNotEmpty) {
//             request.fields['pan_detail[$i][pan_name]'] = name;
//           }
//           if (number.isNotEmpty) {
//             request.fields['pan_detail[$i][pan_no]'] = number;
//           }
//         }
//       }
      
//       // Add pan detail file attachments ONLY if new files are selected
//       for (var entry in panDetailAttachmentFiles.entries) {
//         int index = entry.key;
//         File file = entry.value;
//         String? filename = panDetailAttachmentFileNames[index];
        
//         if (filename != null && filename.isNotEmpty) {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'pan_detail[$index][pan_attachment]',
//               file.path,
//               filename: filename,
//             ),
//           );
//         }
//       }
//     }

//     // Add bank details with file attachments
//     if (editBankDetailControllers != null) {
//       for (int i = 0; i < editBankDetailControllers!.length; i++) {
//         var controllers = editBankDetailControllers![i];
//         String bankName = controllers['bank_name']?.text.trim() ?? '';
//         String accountName = controllers['account_name']?.text.trim() ?? '';
//         String accountNo = controllers['account_no']?.text.trim() ?? '';
//         String ifscCode = controllers['ifsc_code']?.text.trim() ?? '';
//         String branch = controllers['branch']?.text.trim() ?? '';
//         String bankCity = controllers['bank_city']?.text.trim() ?? '';
//         String bankState = controllers['bank_state']?.text.trim() ?? '';
        
//         // Only add fields that have data
//         if (bankName.isNotEmpty) {
//           request.fields['bank_detail[$i][bank_name]'] = bankName;
//         }
//         if (accountName.isNotEmpty) {
//           request.fields['bank_detail[$i][account_name]'] = accountName;
//         }
//         if (accountNo.isNotEmpty) {
//           request.fields['bank_detail[$i][account_no]'] = accountNo;
//         }
//         if (ifscCode.isNotEmpty) {
//           request.fields['bank_detail[$i][ifsc_code]'] = ifscCode;
//         }
//         if (branch.isNotEmpty) {
//           request.fields['bank_detail[$i][branch]'] = branch;
//         }
//         if (bankCity.isNotEmpty) {
//           request.fields['bank_detail[$i][bank_city]'] = bankCity;
//         }
//         if (bankState.isNotEmpty) {
//           request.fields['bank_detail[$i][bank_state]'] = bankState;
//         }
//       }
      
//       // Add bank cheque leaf file attachments ONLY if new files are selected
//       for (var entry in bankChequeLeafFiles.entries) {
//         int index = entry.key;
//         File file = entry.value;
//         String? filename = bankChequeLeafFileNames[index];
        
//         if (filename != null && filename.isNotEmpty) {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'bank_detail[$index][cheque_leaf]',
//               file.path,
//               filename: filename,
//             ),
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(child: Text('No KYC records found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(_getFieldLabel(field)),
//                                 ),
//                               ),
//                             ],
//                             rows: kycRecords.map((record) {
//                               final id = record['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           // Handle file attachment fields
//                                           if (f.endsWith('_attachment') || f == 'cin_attach') {
//                                             return record[f] != null && record[f].toString().isNotEmpty
//                                                 ? Row(
//                                                     children: [
//                                                       Icon(Icons.attach_file, size: 16),
//                                                       SizedBox(width: 4),
//                                                       InkWell(
//                                                         onTap: () {
//                                                           print('Open: ${record[f]}');
//                                                         },
//                                                         child: Text(
//                                                           'View',
//                                                           style: TextStyle(
//                                                             color: Colors.blue,
//                                                             decoration: TextDecoration.underline,
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   )
//                                                 : Text('No file');
//                                           }
//                                           // Handle nested arrays
//                                           else if (f == 'aadhar_detail' || f == 'pan_detail' || f == 'bank_detail') {
//                                             final details = record[f];
//                                             if (details != null && details is List) {
//                                               return Text('${details.length} items');
//                                             }
//                                             return Text('0 items');
//                                           }
//                                           // Handle boolean field
//                                           else if (f == 'is_completed') {
//                                             bool value = record[f] == true;
//                                             return Text(value ? 'Yes' : 'No');
//                                           }
//                                           // Regular field
//                                           else {
//                                             return Text(record[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     // Pagination controls
//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

//   String? nextUrl;
//   String? prevUrl;
//   int totalCount = 0;
//   int currentPage = 1;

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
//   // For nested array file uploads
//   Map<int, File> aadharAttachmentFiles = {};
//   Map<int, String> aadharAttachmentFileNames = {};
//   Map<int, File> panDetailAttachmentFiles = {};
//   Map<int, String> panDetailAttachmentFileNames = {};
//   Map<int, File> bankChequeLeafFiles = {};
//   Map<int, String> bankChequeLeafFileNames = {};
  
//   String? panAttachmentFileName;
//   String? gstAttachmentFileName;
//   String? bisAttachmentFileName;
//   String? msmeAttachmentFileName;
//   String? tanAttachmentFileName;
//   String? cinAttachmentFileName;

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   @override
//   void dispose() {
//     // Dispose all controllers
//     _disposeAllControllers();
//     super.dispose();
//   }

//   void _disposeAllControllers() {
//     // Dispose edit controllers
//     if (editControllers != null) {
//       editControllers!.forEach((key, controller) {
//         controller.dispose();
//       });
//     }
    
//     // Dispose aadhar detail controllers
//     if (editAadharDetailControllers != null) {
//       for (var controllers in editAadharDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose pan detail controllers
//     if (editPanDetailControllers != null) {
//       for (var controllers in editPanDetailControllers!) {
//         controllers.forEach((key, controller) {
//           controller.dispose();
//         });
//       }
//     }
    
//     // Dispose bank detail controllers
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

//     final Uri apiUrl = Uri.parse(
//       url ?? 'http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/list/',
//     );

//     try {
//       final response = await http.get(
//         apiUrl,
//         headers: {'Authorization': 'Token $token'},
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);

//         final results = List<Map<String, dynamic>>.from(data['results'] ?? []);

//         if (results.isNotEmpty) {
//           // Get all field names except id
//           dynamicFields = results.first.keys.where((k) => k.toLowerCase() != 'id').toList();
//         }

//         setState(() {
//           kycRecords = results;
//           nextUrl = data['next'];
//           prevUrl = data['previous'];
//           totalCount = data['count'] ?? 0;
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
//     if (nextUrl != null) {
//       currentPage++;
//       fetchKYCRecords(url: nextUrl);
//     }
//   }

//   void loadPrevPage() {
//     if (prevUrl != null && currentPage > 1) {
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

//   void showKYCDetailDialog(Map<String, dynamic> kycRecord, bool isEdit) async {
//     if (isEdit) {
//       try {
//         // Fetch detailed data for editing
//         setState(() => isLoading = true);
//         final detailedRecord = await fetchKycDetail(kycRecord['id']);
//         setState(() => isLoading = false);
        
//         // Initialize edit mode with fetched data
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
//                   if (isEdit && editControllers != null)
//                     // Edit mode with text fields
//                     ..._buildEditFields(setState)
//                   else
//                     // View mode with read-only text
//                     ..._buildViewFields(kycRecord),
                  
//                   // Show nested arrays in view mode
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
//                     // Clean up all controllers
//                     _disposeAllControllers();
//                     editControllers = null;
//                     editAadharDetailControllers = null;
//                     editPanDetailControllers = null;
//                     editBankDetailControllers = null;
//                     editingKycId = null;
                    
//                     // Reset all file selections
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
    
//     // Initialize main field controllers except id
//     for (var field in kycRecord.keys) {
//       if (field.toLowerCase() != 'id' && 
//           field != 'aadhar_detail' && 
//           field != 'pan_detail' && 
//           field != 'bank_detail') {
//         editControllers![field] = TextEditingController(
//           text: kycRecord[field]?.toString() ?? '',
//         );
//       }
//     }
    
//     // Initialize aadhar detail controllers with all fields
//     editAadharDetailControllers = [];
//     if (kycRecord['aadhar_detail'] != null && kycRecord['aadhar_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['aadhar_detail']);
      
//       for (var detail in existingDetails) {
//         editAadharDetailControllers!.add({
//           'aadhar_name': TextEditingController(text: detail['aadhar_name']?.toString() ?? ''),
//           'aadhar_no': TextEditingController(text: detail['aadhar_no']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Initialize pan detail controllers with all fields
//     editPanDetailControllers = [];
//     if (kycRecord['pan_detail'] != null && kycRecord['pan_detail'] is List) {
//       List<Map<String, dynamic>> existingDetails = 
//           List<Map<String, dynamic>>.from(kycRecord['pan_detail']);
      
//       for (var detail in existingDetails) {
//         editPanDetailControllers!.add({
//           'pan_name': TextEditingController(text: detail['pan_name']?.toString() ?? ''),
//           'pan_no': TextEditingController(text: detail['pan_no']?.toString() ?? ''),
//         });
//       }
//     }
    
//     // Initialize bank detail controllers with all fields
//     editBankDetailControllers = [];
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
//       }
//     }
    
//     // Reset file selections
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
    
//     // Define order of fields if needed
//     List<String> fieldOrder = [
//       'bp_code', 'mobile', 'name', 'business_name', 'business_email',
//       'gst_no', 'gst_attachment', 'pan_no', 'pan_attachment',
//       'bis_name', 'bis_no', 'bis_attachment',
//       'msme_name', 'msme_no', 'msme_attachment',
//       'tan_name', 'tan_no', 'tan_attachment',
//       'cin_name', 'cin_no', 'cin_attach',
//       'note', 'is_completed'
//     ];
    
//     // Add fields in order
//     for (var field in fieldOrder) {
//       if (editControllers!.containsKey(field)) {
//         // Check if this is a file attachment field
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildEditFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             currentValue: editControllers![field]!.text,
//             setState: setState,
//           ));
//         } 
//         // Check if this is a boolean field
//         else if (field == 'is_completed') {
//           fields.add(_buildBooleanField(
//             field: field,
//             label: _getFieldLabel(field),
//             setState: setState,
//           ));
//         }
//         // Regular text field
//         else {
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
    
//     // Add nested arrays for edit mode
//     fields.addAll(_buildNestedArraysEdit(setState));
    
//     return fields;
//   }

//   String _getFieldLabel(String field) {
//     // Convert field name to readable label
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
    
//     // Define order for better display
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
//         // Check if this is a file attachment field
//         if (field.endsWith('_attachment') || field == 'cin_attach') {
//           fields.add(_buildFileAttachmentField(
//             field: field,
//             label: _getFieldLabel(field),
//             value: kycRecord[field],
//           ));
//         }
//         // Regular field
//         else {
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
    
//     // Aadhar Details
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
    
//     // PAN Details
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
    
//     // Bank Details
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
//                   // Text fields
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
//                   // File attachment fields
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
    
//     // Aadhar Details Edit
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
//       onAdd: () {
//         setState(() {
//           editAadharDetailControllers ??= [];
//           editAadharDetailControllers!.add({
//             'aadhar_name': TextEditingController(),
//             'aadhar_no': TextEditingController(),
//           });
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
    
//     // PAN Details Edit
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
//       onAdd: () {
//         setState(() {
//           editPanDetailControllers ??= [];
//           editPanDetailControllers!.add({
//             'pan_name': TextEditingController(),
//             'pan_no': TextEditingController(),
//           });
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
    
//     // Bank Details Edit
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
                    
//                     // File attachment for nested array
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
//                             Row(
//                               children: [
//                                 Expanded(
//                                   child: ElevatedButton.icon(
//                                     onPressed: () => onPickFile(index),
//                                     icon: Icon(Icons.attach_file),
//                                     label: Text(
//                                       fileNameMap[index] ?? 'Select $fileFieldLabel',
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
          
//           // Show current file if exists
//           if (currentValue.isNotEmpty)
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 InkWell(
//                   onTap: () {
//                     print('Current File URL: $currentValue');
//                   },
//                   child: Text(
//                     'View Current Attachment',
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
//                     _getFileName(field) ?? 'Select New File',
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
//         return panAttachmentFileName ?? 'Select New PAN File';
//       case 'gst_attachment':
//         return gstAttachmentFileName ?? 'Select New GST File';
//       case 'bis_attachment':
//         return bisAttachmentFileName ?? 'Select New BIS File';
//       case 'msme_attachment':
//         return msmeAttachmentFileName ?? 'Select New MSME File';
//       case 'tan_attachment':
//         return tanAttachmentFileName ?? 'Select New TAN File';
//       case 'cin_attach':
//         return cinAttachmentFileName ?? 'Select New CIN File';
//       default:
//         return 'Select New File';
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
//       // Create multipart request
//       var request = http.MultipartRequest(
//         'PUT',
//         Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartnerKYC/update/$id/'),
//       );

//       // Add authorization header
//       request.headers['Authorization'] = 'Token $token';

//       // Add text fields
//       editControllers!.forEach((key, controller) {
//         // Don't add file fields as text
//         if (!key.endsWith('_attachment') && key != 'cin_attach') {
//           request.fields[key] = controller.text;
//         }
//       });

//       // Add file attachments
//       await _addFileAttachments(request);

//       // Add nested arrays - now async
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
        
//         // Refresh the KYC list
//         fetchKYCRecords();
        
//         // Show success message
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
//     // Add PAN attachment
//     if (panAttachmentFile != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'pan_attachment',
//           panAttachmentFile!.path,
//           filename: panAttachmentFileName,
//         ),
//       );
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
//     }
//   }

//   Future<void> _addNestedArrays(http.MultipartRequest request) async {
//     // Add aadhar details with file attachments
//     if (editAadharDetailControllers != null) {
//       for (int i = 0; i < editAadharDetailControllers!.length; i++) {
//         var controllers = editAadharDetailControllers![i];
//         String name = controllers['aadhar_name']?.text.trim() ?? '';
//         String number = controllers['aadhar_no']?.text.trim() ?? '';
        
//         if (name.isNotEmpty || number.isNotEmpty) {
//           request.fields['aadhar_detail[$i][aadhar_name]'] = name;
//           request.fields['aadhar_detail[$i][aadhar_no]'] = number;
//         }
//       }
      
//       // Add aadhar file attachments
//       for (var entry in aadharAttachmentFiles.entries) {
//         int index = entry.key;
//         File file = entry.value;
//         String? filename = aadharAttachmentFileNames[index];
        
//         if (filename != null && filename.isNotEmpty) {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'aadhar_detail[$index][aadhar_attach]',
//               file.path,
//               filename: filename,
//             ),
//           );
//         }
//       }
//     }

//     // Add pan details with file attachments
//     if (editPanDetailControllers != null) {
//       for (int i = 0; i < editPanDetailControllers!.length; i++) {
//         var controllers = editPanDetailControllers![i];
//         String name = controllers['pan_name']?.text.trim() ?? '';
//         String number = controllers['pan_no']?.text.trim() ?? '';
        
//         if (name.isNotEmpty || number.isNotEmpty) {
//           request.fields['pan_detail[$i][pan_name]'] = name;
//           request.fields['pan_detail[$i][pan_no]'] = number;
//         }
//       }
      
//       // Add pan detail file attachments
//       for (var entry in panDetailAttachmentFiles.entries) {
//         int index = entry.key;
//         File file = entry.value;
//         String? filename = panDetailAttachmentFileNames[index];
        
//         if (filename != null && filename.isNotEmpty) {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'pan_detail[$index][pan_attachment]',
//               file.path,
//               filename: filename,
//             ),
//           );
//         }
//       }
//     }

//     // Add bank details with file attachments
//     if (editBankDetailControllers != null) {
//       for (int i = 0; i < editBankDetailControllers!.length; i++) {
//         var controllers = editBankDetailControllers![i];
//         String bankName = controllers['bank_name']?.text.trim() ?? '';
//         String accountName = controllers['account_name']?.text.trim() ?? '';
//         String accountNo = controllers['account_no']?.text.trim() ?? '';
//         String ifscCode = controllers['ifsc_code']?.text.trim() ?? '';
//         String branch = controllers['branch']?.text.trim() ?? '';
//         String bankCity = controllers['bank_city']?.text.trim() ?? '';
//         String bankState = controllers['bank_state']?.text.trim() ?? '';
        
//         if (bankName.isNotEmpty || accountName.isNotEmpty || accountNo.isNotEmpty || 
//             ifscCode.isNotEmpty || branch.isNotEmpty || bankCity.isNotEmpty || bankState.isNotEmpty) {
//           request.fields['bank_detail[$i][bank_name]'] = bankName;
//           request.fields['bank_detail[$i][account_name]'] = accountName;
//           request.fields['bank_detail[$i][account_no]'] = accountNo;
//           request.fields['bank_detail[$i][ifsc_code]'] = ifscCode;
//           request.fields['bank_detail[$i][branch]'] = branch;
//           request.fields['bank_detail[$i][bank_city]'] = bankCity;
//           request.fields['bank_detail[$i][bank_state]'] = bankState;
//         }
//       }
      
//       // Add bank cheque leaf file attachments
//       for (var entry in bankChequeLeafFiles.entries) {
//         int index = entry.key;
//         File file = entry.value;
//         String? filename = bankChequeLeafFileNames[index];
        
//         if (filename != null && filename.isNotEmpty) {
//           request.files.add(
//             await http.MultipartFile.fromPath(
//               'bank_detail[$index][cheque_leaf]',
//               file.path,
//               filename: filename,
//             ),
//           );
//         }
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('KYC Records'),
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : kycRecords.isEmpty
//               ? Center(child: Text('No KYC records found'))
//               : Column(
//                   children: [
//                     Expanded(
//                       child: SingleChildScrollView(
//                         scrollDirection: Axis.vertical,
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: DataTable(
//                             columnSpacing: 24,
//                             columns: [
//                               DataColumn(label: Text('Select')),
//                               DataColumn(label: Text('Actions')),
//                               ...dynamicFields.map(
//                                 (field) => DataColumn(
//                                   label: Text(_getFieldLabel(field)),
//                                 ),
//                               ),
//                             ],
//                             rows: kycRecords.map((record) {
//                               final id = record['id'];
//                               final isSelected = selectedIds.contains(id);

//                               return DataRow(
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
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, false),
//                                                 child: Text('View'),
//                                               ),
//                                               SizedBox(width: 8),
//                                               ElevatedButton(
//                                                 onPressed: () =>
//                                                     showKYCDetailDialog(record, true),
//                                                 child: Text('Edit'),
//                                               ),
//                                             ],
//                                           )
//                                         : SizedBox.shrink(),
//                                   ),

//                                   ...dynamicFields.map(
//                                     (f) => DataCell(
//                                       Builder(
//                                         builder: (context) {
//                                           // Handle file attachment fields
//                                           if (f.endsWith('_attachment') || f == 'cin_attach') {
//                                             return record[f] != null && record[f].toString().isNotEmpty
//                                                 ? Row(
//                                                     children: [
//                                                       Icon(Icons.attach_file, size: 16),
//                                                       SizedBox(width: 4),
//                                                       InkWell(
//                                                         onTap: () {
//                                                           print('Open: ${record[f]}');
//                                                         },
//                                                         child: Text(
//                                                           'View',
//                                                           style: TextStyle(
//                                                             color: Colors.blue,
//                                                             decoration: TextDecoration.underline,
//                                                           ),
//                                                         ),
//                                                       ),
//                                                     ],
//                                                   )
//                                                 : Text('No file');
//                                           }
//                                           // Handle nested arrays
//                                           else if (f == 'aadhar_detail' || f == 'pan_detail' || f == 'bank_detail') {
//                                             final details = record[f];
//                                             if (details != null && details is List) {
//                                               return Text('${details.length} items');
//                                             }
//                                             return Text('0 items');
//                                           }
//                                           // Handle boolean field
//                                           else if (f == 'is_completed') {
//                                             bool value = record[f] == true;
//                                             return Text(value ? 'Yes' : 'No');
//                                           }
//                                           // Regular field
//                                           else {
//                                             return Text(record[f]?.toString() ?? '');
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                     ),

//                     // Pagination controls
//                     Container(
//                       padding: EdgeInsets.all(12),
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Page $currentPage | Total: $totalCount',
//                             style: TextStyle(fontWeight: FontWeight.w600),
//                           ),
//                           Row(
//                             children: [
//                               ElevatedButton(
//                                 onPressed: prevUrl == null ? null : loadPrevPage,
//                                 child: Text('Previous'),
//                               ),
//                               SizedBox(width: 12),
//                               ElevatedButton(
//                                 onPressed: nextUrl == null ? null : loadNextPage,
//                                 child: Text('Next'),
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

class BuyerFormPage extends StatefulWidget {
  final Map<String, dynamic> basicData;
  final VoidCallback onComplete;

  BuyerFormPage({required this.basicData, required this.onComplete});

  @override
  _BuyerFormPageState createState() => _BuyerFormPageState();
}

class _BuyerFormPageState extends State<BuyerFormPage> {
  String? token;

  // Existing controllers
  final TextEditingController bisNo = TextEditingController();
  final TextEditingController gstNo = TextEditingController();
  final TextEditingController msmeNo = TextEditingController();
  final TextEditingController panNo = TextEditingController();
  final TextEditingController tanNo = TextEditingController();
  final TextEditingController aadharNo = TextEditingController();
  final TextEditingController aadharName = TextEditingController();
  final TextEditingController bankName = TextEditingController();
  final TextEditingController accountNumber = TextEditingController();
  final TextEditingController ifscCode = TextEditingController();

  // File uploads
  PlatformFile? bisCertificate;
  PlatformFile? gstCertificate;
  PlatformFile? panCard;
  PlatformFile? aadharCard;
  PlatformFile? bankProof;

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token') ?? '';
    });
  }

  Future<void> pickFile(Function(PlatformFile) onPicked) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      onPicked(result.files.first);
    }
  }

  Future<void> submitForm() async {
  if (token == null || token!.isEmpty) return;

  final uri = Uri.parse('https://veto.co.in/BusinessPartner/BusinessPartnerKYC/create/');

  try {
    // Create multipart request
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Token $token';

    // Add basic + form fields
    Map<String, String> allFields = {
      ...widget.basicData.map((key, value) => MapEntry(key, value.toString())),
      'bis_no': bisNo.text,
      'gst_no': gstNo.text,
      'msme_no': msmeNo.text,
      'pan_no': panNo.text,
      'tan_no': tanNo.text,
      'aadhar_no': aadharNo.text,
      'aadhar_name': aadharName.text,
      'bank_name': bankName.text,
      'account_number': accountNumber.text,
      'ifsc_code': ifscCode.text,
    };

    request.fields.addAll(allFields);

    // Add files if selected
    if (bisCertificate != null) {
      request.files.add(await http.MultipartFile.fromPath('bis_certificate', bisCertificate!.path!));
    }
    if (gstCertificate != null) {
      request.files.add(await http.MultipartFile.fromPath('gst_certificate', gstCertificate!.path!));
    }
    if (panCard != null) {
      request.files.add(await http.MultipartFile.fromPath('pan_card', panCard!.path!));
    }
    if (aadharCard != null) {
      request.files.add(await http.MultipartFile.fromPath('aadhar_card', aadharCard!.path!));
    }
    if (bankProof != null) {
      request.files.add(await http.MultipartFile.fromPath('bank_proof', bankProof!.path!));
    }

    // Send request
    var response = await request.send();

    if (response.statusCode == 201) {
      print("Buyer created successfully");
      widget.onComplete(); // refresh buyer list
      Navigator.pop(context);
    } else {
      final respStr = await response.stream.bytesToString();
      print("Failed: ${response.statusCode} | $respStr");
    }
  } catch (e) {
    print("Error: $e");
  }
}



  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // KYC, Aadhar, Bank
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add New Buyer'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'KYC Information'),
              Tab(text: 'Aadhar Information'),
              Tab(text: 'Bank Details'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: bisNo, decoration: InputDecoration(labelText: 'BIS No'))),
                      SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        onPressed: () => pickFile((file) => setState(() => bisCertificate = file)),
                        child: Text(bisCertificate != null ? bisCertificate!.name : 'Upload BIS Certificate'),
                      )),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: gstNo, decoration: InputDecoration(labelText: 'GST No'))),
                      SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        onPressed: () => pickFile((file) => setState(() => gstCertificate = file)),
                        child: Text(gstCertificate != null ? gstCertificate!.name : 'Upload GST Certificate'),
                      )),
                    ],
                  ),
                  // Add other KYC fields
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(controller: aadharNo, decoration: InputDecoration(labelText: 'Aadhar No')),
                  TextFormField(controller: aadharName, decoration: InputDecoration(labelText: 'Aadhar Name')),
                  ElevatedButton(
                    onPressed: () => pickFile((file) => setState(() => aadharCard = file)),
                    child: Text(aadharCard != null ? aadharCard!.name : 'Upload Aadhar Card'),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(controller: bankName, decoration: InputDecoration(labelText: 'Bank Name')),
                  TextFormField(controller: accountNumber, decoration: InputDecoration(labelText: 'Account Number')),
                  TextFormField(controller: ifscCode, decoration: InputDecoration(labelText: 'IFSC Code')),
                  ElevatedButton(
                    onPressed: () => pickFile((file) => setState(() => bankProof = file)),
                    child: Text(bankProof != null ? bankProof!.name : 'Upload Passbook / Cheque'),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: submitForm,
          child: Icon(Icons.save),
        ),
      ),
    );
  }
}

class CraftsmanPage extends StatefulWidget {
  @override
  _CraftsmanPageState createState() => _CraftsmanPageState();
}

class _CraftsmanPageState extends State<CraftsmanPage> {
  List<Map<String, dynamic>> craftsmen = [];
  bool isLoading = true;
  Set<int> selectedIds = {};
  String? token;
  List<String> dynamicFields = [];

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? "01c5b132a0f3829ef42182997067cd1501f1009a";
    fetchCraftsmen();
  }

  /// 🔹 Fetch all Craftsmen dynamically
  Future<void> fetchCraftsmen() async {
    if (token == null || token!.isEmpty) return;
    setState(() => isLoading = true);

    final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Craftsmans/');

    try {
      final response = await http.get(url, headers: {'Authorization': 'Token $token'});
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
        if (results.isNotEmpty) {
          dynamicFields = results.first.keys.where((k) => k != 'id').toList();
        }
        setState(() {
          craftsmen = results;
          isLoading = false;
        });
      } else {
        print('Failed to load craftsmen: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching craftsmen: $e');
      setState(() => isLoading = false);
    }
  }

  /// 🔹 Create new Craftsman dynamically
  Future<void> createCraftsman(Map<String, dynamic> craftsmanData) async {
    if (token == null || token!.isEmpty) return;
    final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/CRAFTSMAN/create/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode(craftsmanData),
      );

      if (response.statusCode == 201) {
        print('Craftsman created successfully');
        fetchCraftsmen();
      } else {
        print('Failed to create craftsman: ${response.statusCode} | ${response.body}');
      }
    } catch (e) {
      print('Error creating craftsman: $e');
    }
  }

  /// 🔹 Update Craftsman dynamically
  Future<void> updateCraftsman(int id, Map<String, dynamic> craftsmanData) async {
    if (token == null || token!.isEmpty) return;
    final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/update/$id/');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode(craftsmanData),
      );

      if (response.statusCode == 200) {
        print('Craftsman updated successfully');
        fetchCraftsmen();
      } else {
        print('Failed to update craftsman: ${response.statusCode} | ${response.body}');
      }
    } catch (e) {
      print('Error updating craftsman: $e');
    }
  }

  /// 👁️ View/Edit Craftsman Dialog (Dynamic)
  void showCraftsmanDialog(Map<String, dynamic> craftsman, bool isEdit) {
    final controllers = {
      for (var field in craftsman.keys.where((f) => f != 'id'))
        field: TextEditingController(text: craftsman[field]?.toString() ?? '')
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Craftsman' : 'View Craftsman'),
        content: SingleChildScrollView(
          child: Column(
            children: controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: entry.value,
                  readOnly: !isEdit,
                  decoration: InputDecoration(
                    labelText: entry.key.replaceAll('_', ' ').toUpperCase(),
                    border: OutlineInputBorder(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
          if (isEdit)
            ElevatedButton(
              onPressed: () async {
                final updatedData = {
                  for (var e in controllers.entries) e.key: e.value.text
                };
                await updateCraftsman(craftsman['id'], updatedData);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
        ],
      ),
    );
  }

  /// ➕ Add New Craftsman Dialog (Dynamic)
  void showAddCraftsmanDialog() {
    final controllers = {for (var field in dynamicFields) field: TextEditingController()};

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add New Craftsman'),
        content: SingleChildScrollView(
          child: Column(
            children: controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newCraftsmanData = {
                for (var e in controllers.entries) e.key: e.value.text
              };
              await createCraftsman(newCraftsmanData);
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  /// 🧱 UI Rendering
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Craftsmen'),
        actions: [
          ElevatedButton(onPressed: showAddCraftsmanDialog, child: Text('Add New')),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : craftsmen.isEmpty
              ? Center(child: Text('No craftsmen found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    columns: [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Actions')),
                      ...dynamicFields.map(
                        (field) => DataColumn(
                          label: Text(field.replaceAll('_', ' ').toUpperCase()),
                        ),
                      ),
                    ],
                    rows: craftsmen.map((craftsman) {
                      final id = craftsman['id'] ?? craftsmen.indexOf(craftsman);
                      return DataRow(
                        cells: [
                          DataCell(Checkbox(
                            value: selectedIds.contains(id),
                            onChanged: (v) {
                              setState(() {
                                if (v == true)
                                  selectedIds.add(id);
                                else
                                  selectedIds.remove(id);
                              });
                            },
                          )),
                          DataCell(
                            selectedIds.contains(id)
                                ? Row(
                                    children: [
                                      ElevatedButton(
                                          onPressed: () =>
                                              showCraftsmanDialog(craftsman, false),
                                          child: Text('View')),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                          onPressed: () =>
                                              showCraftsmanDialog(craftsman, true),
                                          child: Text('Edit')),
                                    ],
                                  )
                                : SizedBox(),
                          ),
                          ...dynamicFields.map((f) =>
                              DataCell(Text(craftsman[f]?.toString() ?? ''))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}


class CraftsmanFormPage extends StatefulWidget {
  final Map<String, dynamic> basicData;
  final VoidCallback onComplete;

  CraftsmanFormPage({required this.basicData, required this.onComplete});

  @override
  _CraftsmanFormPageState createState() => _CraftsmanFormPageState();
}

class _CraftsmanFormPageState extends State<CraftsmanFormPage> {
  String? token;

  // Existing controllers
  final TextEditingController bisNo = TextEditingController();
  final TextEditingController gstNo = TextEditingController();
  final TextEditingController msmeNo = TextEditingController();
  final TextEditingController panNo = TextEditingController();
  final TextEditingController tanNo = TextEditingController();
  final TextEditingController aadharNo = TextEditingController();
  final TextEditingController aadharName = TextEditingController();
  final TextEditingController bankName = TextEditingController();
  final TextEditingController accountNumber = TextEditingController();
  final TextEditingController ifscCode = TextEditingController();

  // File uploads
  PlatformFile? bisCertificate;
  PlatformFile? gstCertificate;
  PlatformFile? panCard;
  PlatformFile? aadharCard;
  PlatformFile? bankProof;

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token') ?? '';
    });
  }

  Future<void> pickFile(Function(PlatformFile) onPicked) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      onPicked(result.files.first);
    }
  }

  Future<void> submitForm() async {
    if (token == null || token!.isEmpty) return;

    final uri = Uri.parse('https://veto.co.in/BusinessPartner/BusinessPartnerKYC/create/');

    try {
      // Create multipart request
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Token $token';
      Map<String, String> allFields = {
        ...widget.basicData.map((key, value) => MapEntry(key, value.toString())),
        'bis_no': bisNo.text,
        'gst_no': gstNo.text,
        'msme_no': msmeNo.text,
        'pan_no': panNo.text,
        'tan_no': tanNo.text,
        'aadhar_no': aadharNo.text,
        'aadhar_name': aadharName.text,
        'bank_name': bankName.text,
        'account_number': accountNumber.text,
        'ifsc_code': ifscCode.text,
      };

      request.fields.addAll(allFields);

      // Add files if selected
      if (bisCertificate != null) {
        request.files.add(await http.MultipartFile.fromPath('bis_certificate', bisCertificate!.path!));
      }
      if (gstCertificate != null) {
        request.files.add(await http.MultipartFile.fromPath('gst_certificate', gstCertificate!.path!));
      }
      if (panCard != null) {
        request.files.add(await http.MultipartFile.fromPath('pan_card', panCard!.path!));
      }
      if (aadharCard != null) {
        request.files.add(await http.MultipartFile.fromPath('aadhar_card', aadharCard!.path!));
      }
      if (bankProof != null) {
        request.files.add(await http.MultipartFile.fromPath('bank_proof', bankProof!.path!));
      }

      // Send request
      var response = await request.send();

      if (response.statusCode == 201) {
        print("Craftsman created successfully");
        widget.onComplete(); // refresh craftsman list
        Navigator.pop(context);
      } else {
        final respStr = await response.stream.bytesToString();
        print("Failed: ${response.statusCode} | $respStr");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // KYC, Aadhar, Bank
      child: Scaffold(
        appBar: AppBar(
          title: Text('Add New Craftsman'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'KYC Information'),
              Tab(text: 'Aadhar Information'),
              Tab(text: 'Bank Details'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: bisNo, decoration: InputDecoration(labelText: 'BIS No'))),
                      SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        onPressed: () => pickFile((file) => setState(() => bisCertificate = file)),
                        child: Text(bisCertificate != null ? bisCertificate!.name : 'Upload BIS Certificate'),
                      )),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: gstNo, decoration: InputDecoration(labelText: 'GST No'))),
                      SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        onPressed: () => pickFile((file) => setState(() => gstCertificate = file)),
                        child: Text(gstCertificate != null ? gstCertificate!.name : 'Upload GST Certificate'),
                      )),
                    ],
                  ),
                  // Add other KYC fields
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(controller: aadharNo, decoration: InputDecoration(labelText: 'Aadhar No')),
                  TextFormField(controller: aadharName, decoration: InputDecoration(labelText: 'Aadhar Name')),
                  ElevatedButton(
                    onPressed: () => pickFile((file) => setState(() => aadharCard = file)),
                    child: Text(aadharCard != null ? aadharCard!.name : 'Upload Aadhar Card'),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(controller: bankName, decoration: InputDecoration(labelText: 'Bank Name')),
                  TextFormField(controller: accountNumber, decoration: InputDecoration(labelText: 'Account Number')),
                  TextFormField(controller: ifscCode, decoration: InputDecoration(labelText: 'IFSC Code')),
                  ElevatedButton(
                    onPressed: () => pickFile((file) => setState(() => bankProof = file)),
                    child: Text(bankProof != null ? bankProof!.name : 'Upload Passbook / Cheque'),
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: submitForm,
          child: Icon(Icons.save),
        ),
      ),
    );
  }
}

// class AdminPage extends StatefulWidget {
//   @override
//   _AdminPageState createState() => _AdminPageState();
// }

// class _AdminPageState extends State<AdminPage> {
//   List<Map<String, dynamic>> admins = [];
//   bool isLoading = true;
//   String? token; // 🔹 Dynamic token
//   Set<int> selectedIndexes = {};

//   final fields = [
//     'profile_picture', 'role_name', 'user_code', 'bp_code',
//     'full_name', 'email_id', 'mobile_no', 'status', 'dob', 'city',
//     'state', 'country', 'pincode', 'aadhar_photo', 'aadhar_number',
//     'created_at', 'updated_at',
//     'view_only','copy','screenshot','print_perm','download','share','edit',
//     'delete_perm','manage_roles','approve','reject','archive','restore_perm',
//     'transfer','custom_access','full_control','delete_flag'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     loadToken(); // 🔹 Load token first
//   }

//   /// 🔹 Load token dynamically from SharedPreferences
//   Future<void> loadToken() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     token = prefs.getString('token') ?? "";
//     if (token == null || token!.isEmpty) {
//       print("⚠️ No token found in SharedPreferences");
//     } else {
//       print("✅ Token loaded successfully: $token");
//       fetchAdmins();
//     }
//   }

//   /// 🔹 Fetch admin list from API
//   Future<void> fetchAdmins() async {
//     if (token == null || token!.isEmpty) return;
//     setState(() => isLoading = true);

//     final url = Uri.parse('http://127.0.0.1:8000/user/admin/list/');
//     try {
//       final resp = await http.get(url, headers: {'Authorization': 'Token $token'});

//       if (resp.statusCode == 200) {
//         final decoded = json.decode(resp.body);
//         List<Map<String, dynamic>> list = [];

//         if (decoded is List) {
//           list = List<Map<String, dynamic>>.from(decoded);
//         } else if (decoded is Map && decoded.containsKey('results')) {
//           list = List<Map<String, dynamic>>.from(decoded['results']);
//         } else {
//           print('Unexpected API response format');
//         }

//         setState(() {
//           admins = list;
//           isLoading = false;
//         });
//       } else {
//         print('Failed to fetch admins: ${resp.statusCode} | ${resp.body}');
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print('Error fetching admins: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   /// 🔹 Add or Update Admin dynamically
//   Future<void> addOrUpdateAdmin(Map<String, dynamic> data, {bool isEdit = false}) async {
//     if (token == null || token!.isEmpty) return;

//     Uri url = isEdit
//         ? Uri.parse('http://127.0.0.1:8000/user/Admin/update/${data['id']}/')
//         : Uri.parse('http://127.0.0.1:8000/user/Admin/registration/');

//     try {
//       final resp = isEdit
//           ? await http.put(
//               url,
//               headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
//               body: json.encode(data),
//             )
//           : await http.post(
//               url,
//               headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
//               body: json.encode(data),
//             );

//       if (resp.statusCode == 200 || resp.statusCode == 201) {
//         Navigator.pop(context);
//         fetchAdmins();
//       } else {
//         print('Failed to save admin: ${resp.statusCode} | ${resp.body}');
//       }
//     } catch (e) {
//       print('Error saving admin: $e');
//     }
//   }

//   Future<void> pickImage(Function(String) onSelected) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
//     if (picked != null) onSelected(picked.path);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Admins'),
//         actions: [
//           ElevatedButton(
//             onPressed: () => showAdminForm(isEdit: false),
//             child: Text('Add New'),
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : admins.isEmpty
//               ? Center(child: Text('No admins found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columns: [
//                       DataColumn(label: Text('Select')),
//                       DataColumn(label: Text('Actions')),
//                       ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
//                     ],
//                     rows: admins.asMap().entries.map((entry) {
//                       int index = entry.key;
//                       Map<String, dynamic> admin = entry.value;
//                       bool isSelected = selectedIndexes.contains(index);

//                       return DataRow(
//                         selected: isSelected,
//                         cells: [
//                           DataCell(Checkbox(
//                             value: isSelected,
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true) {
//                                   selectedIndexes.add(index);
//                                 } else {
//                                   selectedIndexes.remove(index);
//                                 }
//                               });
//                             },
//                           )),
//                           DataCell(
//                             Row(
//                               children: isSelected
//                                   ? [
//                                       ElevatedButton(onPressed: () => showViewDialog(admin), child: Text('View')),
//                                       SizedBox(width: 8),
//                                       ElevatedButton(onPressed: () => showAdminForm(admin: admin, isEdit: true), child: Text('Edit')),
//                                     ]
//                                   : [Text('')],
//                             ),
//                           ),
//                           ...fields.map((f) {
//                             final val = admin[f];
//                             if (f == 'profile_picture' || f == 'aadhar_photo') {
//                               return DataCell(val != null
//                                   ? Image.network(val, width: 40, height: 40, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
//                                   : Icon(Icons.image));
//                             }
//                             if (val is bool) {
//                               return DataCell(Icon(val ? Icons.check_circle : Icons.cancel, color: val ? Colors.green : Colors.red));
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

//   void showViewDialog(Map<String, dynamic> admin) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('View Admin'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: fields.map((f) {
//               final val = admin[f];
//               if (f == 'profile_picture' || f == 'aadhar_photo') {
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
//                   children: [
//                     Expanded(flex: 2, child: Text(f.toUpperCase())),
//                     Expanded(flex: 3, child: Text(val?.toString() ?? '')),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//         actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
//       ),
//     );
//   }

//   void showAdminForm({Map<String, dynamic>? admin, bool isEdit = false}) {
//     final formKey = GlobalKey<FormState>();
//     Map<String, dynamic> data = Map.from(admin ?? {});
//     String profilePath = data['profile_picture'] ?? '';
//     String aadharPath = data['aadhar_photo'] ?? '';

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit Admin' : 'Add Admin'),
//         content: StatefulBuilder(
//           builder: (context, setStateDialog) => SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 children: [
//                   buildTextField('Full Name', 'full_name', data),
//                   buildTextField('Email', 'email_id', data),
//                   buildTextField('Mobile', 'mobile_no', data),
//                   buildTextField('User Code', 'user_code', data),
//                   buildTextField('BP Code', 'bp_code', data),
//                   buildTextField('DOB', 'dob', data),
//                   buildTextField('City', 'city', data),
//                   buildTextField('State', 'state', data),
//                   buildTextField('Country', 'country', data),
//                   buildTextField('Pincode', 'pincode', data),
//                   buildTextField('Aadhar Number', 'aadhar_number', data),
//                   SizedBox(height: 10),
//                   Row(children: [
//                     ElevatedButton(
//                       onPressed: () async {
//                         await pickImage((path) {
//                           setStateDialog(() => profilePath = path);
//                           data['profile_picture'] = path;
//                         });
//                       },
//                       child: Text('Profile Image'),
//                     ),
//                     SizedBox(width: 10),
//                     if (profilePath.isNotEmpty) Icon(Icons.check_circle, color: Colors.green),
//                   ]),
//                   Row(children: [
//                     ElevatedButton(
//                       onPressed: () async {
//                         await pickImage((path) {
//                           setStateDialog(() => aadharPath = path);
//                           data['aadhar_photo'] = path;
//                         });
//                       },
//                       child: Text('Aadhar Image'),
//                     ),
//                     SizedBox(width: 10),
//                     if (aadharPath.isNotEmpty) Icon(Icons.check_circle, color: Colors.green),
//                   ]),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
//           ElevatedButton(
//             onPressed: () {
//               if (formKey.currentState!.validate()) {
//                 addOrUpdateAdmin(data, isEdit: isEdit);
//               }
//             },
//             child: Text(isEdit ? 'Update' : 'Save'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget buildTextField(String label, String key, Map<String, dynamic> data) {
//     return TextFormField(
//       initialValue: data[key]?.toString(),
//       decoration: InputDecoration(labelText: label),
//       onChanged: (v) => data[key] = v,
//     );
//   }
// }

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> admins = [];
  bool isLoading = true;
  String? token;
  Set<int> selectedIndexes = {};

  final fields = [
    'profile_picture', 'role_name', 'user_code', 'bp_code',
    'full_name', 'email_id', 'mobile_no', 'status', 'dob', 'city',
    'state', 'country', 'pincode', 'aadhar_photo', 'aadhar_number','password',
    'created_at', 'updated_at',
    'view_only','copy','screenshot','print_perm','download','share','edit',
    'delete_perm','manage_roles','approve','reject','archive','restore_perm',
    'transfer','custom_access','full_control','delete_flag'
  ];

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  Future<void> loadToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? "";
    if (token == null || token!.isEmpty) {
      print("⚠️ No token found in SharedPreferences");
    } else {
      print("✅ Token loaded successfully: $token");
      fetchAdmins();
    }
  }

  Future<void> fetchAdmins() async {
    if (token == null || token!.isEmpty) return;
    setState(() => isLoading = true);

    final url = Uri.parse('http://127.0.0.1:8000/user/admin/list/');
    try {
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> list = [];

        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded.containsKey('results')) {
          list = List<Map<String, dynamic>>.from(decoded['results']);
        } else {
          print('Unexpected API response format');
        }

        setState(() {
          admins = list;
          isLoading = false;
        });
      } else {
        print('Failed to fetch admins: ${resp.statusCode} | ${resp.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching admins: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> addOrUpdateAdmin(Map<String, dynamic> data, {bool isEdit = false}) async {
    if (token == null || token!.isEmpty) return;

    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/user/Admin/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/user/Admin/registration/');

    try {
      var request = http.MultipartRequest(
        isEdit ? 'PUT' : 'POST',
        url,
      );

      request.headers['Authorization'] = 'Token $token';

      // ✅ Fixed bp_code - now treated as string
      data.forEach((key, value) {
        if (key != 'profile_picture' && key != 'aadhar_photo' && key != 'id') {
          if (value != null) {
            if (key == 'bp_code') {
              if (value.toString().isNotEmpty) {
                request.fields[key] = value.toString();
              }
            } else if (key == 'user_permissions') {
              if (value is String) {
                try {
                  final parsed = json.decode(value);
                  if (parsed is List) {
                    request.fields[key] = value;
                  }
                } catch (e) {
                  request.fields[key] = value;
                }
              } else {
                request.fields[key] = value.toString();
              }
            } else {
              request.fields[key] = value.toString();
            }
          }
        }
      });

      if (data['profile_picture'] != null && data['profile_picture'] is String) {
        String profilePath = data['profile_picture'];
        if (await File(profilePath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('profile_picture', profilePath));
        }
      }

      if (data['aadhar_photo'] != null && data['aadhar_photo'] is String) {
        String aadharPath = data['aadhar_photo'];
        if (await File(aadharPath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('aadhar_photo', aadharPath));
        }
      }

      final streamedResponse = await request.send();
      final resp = await http.Response.fromStream(streamedResponse);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.pop(context);
        fetchAdmins();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Admin updated successfully!' : 'Admin added successfully!')),
        );
      } else {
        print('Failed to save admin: ${resp.statusCode} | ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save admin: ${resp.body}')),
        );
      }
    } catch (e) {
      print('Error saving admin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> addOrUpdateAdminAlternative(Map<String, dynamic> data, {bool isEdit = false}) async {
    if (token == null || token!.isEmpty) return;

    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/user/Admin/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/user/Admin/registration/');

    try {
      Map<String, dynamic> requestData = Map.from(data);

      // ✅ Keep bp_code as string
      if (requestData.containsKey('bp_code') && requestData['bp_code'] != null) {
        final bpCode = requestData['bp_code'].toString();
        if (bpCode.isNotEmpty) {
          requestData['bp_code'] = bpCode;
        } else {
          requestData.remove('bp_code');
        }
      }

      if (requestData.containsKey('user_permissions') && requestData['user_permissions'] != null) {
        if (requestData['user_permissions'] is String) {
          try {
            final parsed = json.decode(requestData['user_permissions']);
            if (parsed is List) {
              requestData['user_permissions'] = parsed.map((e) => e.toString()).toList();
            }
          } catch (e) {
            final permissionsList = requestData['user_permissions'].toString().split(',').map((e) => e.trim()).toList();
            requestData['user_permissions'] = permissionsList;
          }
        }
      }

      requestData.remove('profile_picture');
      requestData.remove('aadhar_photo');

      var request = http.MultipartRequest(
        isEdit ? 'PUT' : 'POST',
        url,
      );

      request.headers['Authorization'] = 'Token $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      request.fields['data'] = json.encode(requestData);

      if (data['profile_picture'] != null && data['profile_picture'] is String) {
        String profilePath = data['profile_picture'];
        if (await File(profilePath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('profile_picture', profilePath));
        }
      }

      if (data['aadhar_photo'] != null && data['aadhar_photo'] is String) {
        String aadharPath = data['aadhar_photo'];
        if (await File(aadharPath).exists()) {
          request.files.add(await http.MultipartFile.fromPath('aadhar_photo', aadharPath));
        }
      }

      final streamedResponse = await request.send();
      final resp = await http.Response.fromStream(streamedResponse);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.pop(context);
        fetchAdmins();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEdit ? 'Admin updated successfully!' : 'Admin added successfully!')),
        );
      } else {
        print('Failed to save admin: ${resp.statusCode} | ${resp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save admin: ${resp.body}')),
        );
      }
    } catch (e) {
      print('Error saving admin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> pickImage(Function(File) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      onSelected(File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admins'),
        actions: [
          ElevatedButton(
            onPressed: () => showAdminForm(isEdit: false),
            child: Text('Add New'),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : admins.isEmpty
              ? Center(child: Text('No admins found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Actions')),
                      ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
                    ],
                    rows: admins.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> admin = entry.value;
                      bool isSelected = selectedIndexes.contains(index);

                      return DataRow(
                        selected: isSelected,
                        cells: [
                          DataCell(Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedIndexes.add(index);
                                } else {
                                  selectedIndexes.remove(index);
                                }
                              });
                            },
                          )),
                          DataCell(
                            Row(
                              children: isSelected
                                  ? [
                                      ElevatedButton(onPressed: () => showViewDialog(admin), child: Text('View')),
                                      SizedBox(width: 8),
                                      ElevatedButton(onPressed: () => showAdminForm(admin: admin, isEdit: true), child: Text('Edit')),
                                    ]
                                  : [Text('')],
                            ),
                          ),
                          ...fields.map((f) {
                            final val = admin[f];
                            if (f == 'profile_picture' || f == 'aadhar_photo') {
                              return DataCell(val != null
                                  ? Image.network(val, width: 40, height: 40, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
                                  : Icon(Icons.image));
                            }
                            if (val is bool) {
                              return DataCell(Icon(val ? Icons.check_circle : Icons.cancel, color: val ? Colors.green : Colors.red));
                            }
                            return DataCell(Text(val?.toString() ?? ''));
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  void showViewDialog(Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Admin'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.map((f) {
              final val = admin[f];
              if (f == 'profile_picture' || f == 'aadhar_photo') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.toUpperCase()),
                    val != null
                        ? Image.network(val, width: 100, height: 100, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
                        : Text('No Image'),
                    SizedBox(height: 10),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(f.toUpperCase())),
                    Expanded(flex: 3, child: Text(val?.toString() ?? '')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
      ),
    );
  }

  void showAdminForm({Map<String, dynamic>? admin, bool isEdit = false}) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> data = Map.from(admin ?? {});
    File? profileFile;
    File? aadharFile;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Admin' : 'Add Admin'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  buildTextField('Full Name', 'full_name', data),
                  buildTextField('Email', 'email_id', data),
                  buildTextField('Mobile', 'mobile_no', data),
                  buildTextField('User Code', 'user_code', data),

                  // ✅ BP Code as string
                  TextFormField(
                    initialValue: data['bp_code']?.toString(),
                    decoration: InputDecoration(
                      labelText: 'BP Code',
                      hintText: 'Enter BP Code (e.g., BA0001-Arianth Jewellers)',
                    ),
                    onChanged: (v) => data['bp_code'] = v,
                  ),

                  buildTextField('DOB', 'dob', data),
                  buildTextField('City', 'city', data),
                  buildTextField('State', 'state', data),
                  buildTextField('Country', 'country', data),
                  buildTextField('Pincode', 'pincode', data),
                  buildTextField('Aadhar Number', 'aadhar_number', data),

                  SizedBox(height: 10),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((file) {
                          setStateDialog(() => profileFile = file);
                          data['profile_picture'] = file.path;
                        });
                      },
                      child: Text('Profile Image'),
                    ),
                    SizedBox(width: 10),
                    if (profileFile != null) Icon(Icons.check_circle, color: Colors.green),
                  ]),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((file) {
                          setStateDialog(() => aadharFile = file);
                          data['aadhar_photo'] = file.path;
                        });
                      },
                      child: Text('Aadhar Image'),
                    ),
                    SizedBox(width: 10),
                    if (aadharFile != null) Icon(Icons.check_circle, color: Colors.green),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                addOrUpdateAdminAlternative(data, isEdit: isEdit);
              }
            },
            child: Text(isEdit ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String key, Map<String, dynamic> data) {
    return TextFormField(
      initialValue: data[key]?.toString(),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => data[key] = v,
    );
  }
}


class KeyUserPage extends StatefulWidget {
  @override
  _KeyUserPageState createState() => _KeyUserPageState();
}

class _KeyUserPageState extends State<KeyUserPage> {
  List<Map<String, dynamic>> keyUsers = [];
  bool isLoading = true;
  String? token; // ✅ Dynamic token
  Set<int> selectedIndexes = {};
  List<String> buyerBpCodes = [];

  final fields = [
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
    'created_at',
    'updated_at',
  ];

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  // ✅ Load token from SharedPreferences
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
    });

    if (token != null) {
      fetchKeyUsers();
      fetchBuyerBpCodes();
    } else {
      print('⚠️ No token found. Please login again.');
    }
  }

  // ✅ Fetch Key Users
  Future<void> fetchKeyUsers() async {
    if (token == null) {
      print('⚠️ Token is null. Please login again.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('http://127.0.0.1:8000/user/keyuser/list/');
    try {
      final resp = await http.get(url, headers: {
        'Authorization': 'Token $token',
      });

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> list = [];

        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded.containsKey('results')) {
          list = List<Map<String, dynamic>>.from(decoded['results']);
        }

        setState(() {
          keyUsers = list;
          isLoading = false;
        });
      } else {
        print('Failed to fetch key users: ${resp.statusCode} | ${resp.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching key users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // ✅ Fetch Buyer BP Codes
  Future<void> fetchBuyerBpCodes() async {
    if (token == null) return;

    final url = Uri.parse(
        'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
    try {
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> buyerList = [];

        if (decoded is Map && decoded.containsKey('results')) {
          buyerList = List<Map<String, dynamic>>.from(decoded['results']);
        }

        setState(() {
          buyerBpCodes =
              buyerList.map((buyer) => buyer['bp_code'].toString()).toList();
        });
      } else {
        print('Failed to fetch buyers: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  // ✅ Add or Update Key User
  Future<void> addOrUpdateKeyUser(Map<String, dynamic> data,
      {bool isEdit = false}) async {
    if (token == null) {
      print('⚠️ Token is null. Please login again.');
      return;
    }

    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/user/KeyUser/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/user/KeyUser/registration/');

    try {
      var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
      request.headers['Authorization'] = 'Token $token';

      // ✅ Add fields except images & user_permissions
      data.forEach((key, value) {
        if (value != null &&
            key != 'profile_picture' &&
            key != 'aadhar_photo' &&
            key != 'user_permissions') {
          request.fields[key] = value.toString();
        }
      });

      // ✅ Attach profile image if new
      if (data['profile_picture'] != null &&
          data['profile_picture'].toString().isNotEmpty &&
          !data['profile_picture'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_picture', data['profile_picture']));
      }

      // ✅ Attach aadhar image if new
      if (data['aadhar_photo'] != null &&
          data['aadhar_photo'].toString().isNotEmpty &&
          !data['aadhar_photo'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath(
            'aadhar_photo', data['aadhar_photo']));
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        fetchKeyUsers();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Key User saved successfully')));
      } else {
        print('Failed to save key user: ${response.statusCode} | $respStr');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save key user: ${response.statusCode}')));
      }
    } catch (e) {
      print('Error saving key user: $e');
    }
  }

  Future<void> pickImage(Function(String) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) onSelected(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Key Users'),
        actions: [
          ElevatedButton(
            onPressed: () => showKeyUserForm(isEdit: false),
            child: Text('Add New'),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : keyUsers.isEmpty
              ? Center(child: Text('No key users found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Actions')),
                      ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
                    ],
                    rows: keyUsers.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> keyUser = entry.value;
                      bool isSelected = selectedIndexes.contains(index);

                      return DataRow(
                        selected: isSelected,
                        cells: [
                          DataCell(Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedIndexes.add(index);
                                } else {
                                  selectedIndexes.remove(index);
                                }
                              });
                            },
                          )),
                          DataCell(
                            Row(
                              children: isSelected
                                  ? [
                                      ElevatedButton(
                                          onPressed: () =>
                                              showViewDialog(keyUser),
                                          child: Text('View')),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                          onPressed: () => showKeyUserForm(
                                              keyUser: keyUser, isEdit: true),
                                          child: Text('Edit')),
                                    ]
                                  : [Text('')],
                            ),
                          ),
                          ...fields.map((f) {
                            final val = keyUser[f];
                            if (f == 'profile_picture' || f == 'aadhar_photo') {
                              return DataCell(val != null
                                  ? Image.network(val,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.image_not_supported))
                                  : Icon(Icons.image));
                            }
                            if (val is bool) {
                              return DataCell(Icon(
                                  val ? Icons.check_circle : Icons.cancel,
                                  color:
                                      val ? Colors.green : Colors.red));
                            }
                            return DataCell(Text(val?.toString() ?? ''));
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  void showViewDialog(Map<String, dynamic> keyUser) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Key User'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.map((f) {
              final val = keyUser[f];
              if (f == 'profile_picture' || f == 'aadhar_photo') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.toUpperCase()),
                    val != null
                        ? Image.network(val,
                            width: 100,
                            height: 100,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.image_not_supported))
                        : Text('No Image'),
                    SizedBox(height: 10),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(f.toUpperCase())),
                    Expanded(flex: 3, child: Text(val?.toString() ?? '')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Close'))
        ],
      ),
    );
  }

  void showKeyUserForm({Map<String, dynamic>? keyUser, bool isEdit = false}) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> data = Map.from(keyUser ?? {});
    String profilePath = data['profile_picture'] ?? '';
    String aadharPath = data['aadhar_photo'] ?? '';
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Key User' : 'Add Key User'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  buildTextField('Full Name', 'full_name', data),
                  buildTextField('Email', 'email_id', data),
                  buildTextField('Mobile', 'mobile_no', data),
                  buildTextField('User Code', 'user_code', data),

                  DropdownButtonFormField<String>(
                    value: data['bp_code'] != null &&
                            buyerBpCodes.any((bp) =>
                                bp.split('-').first.trim() == data['bp_code'])
                        ? data['bp_code']
                        : null,
                    items: buyerBpCodes.map((bp) {
                      final bpCode = bp.split('-').first.trim();
                      return DropdownMenuItem<String>(
                        value: bpCode,
                        child: Text(bp),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        data['bp_code'] = value!;
                      });
                    },
                    decoration: InputDecoration(labelText: 'BP Code'),
                  ),

                  buildTextField('DOB', 'dob', data),
                  buildTextField('City', 'city', data),
                  buildTextField('State', 'state', data),
                  buildTextField('Country', 'country', data),
                  buildTextField('Pincode', 'pincode', data),
                  buildTextField('Aadhar Number', 'aadhar_number', data),

                  if (!isEdit)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(showPassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setStateDialog(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: !showPassword,
                      validator: (value) {
                        if (!isEdit && (value == null || value.isEmpty)) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      onChanged: (v) => data['password'] = v,
                    ),

                  SizedBox(height: 10),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((path) {
                          setStateDialog(() => profilePath = path);
                          data['profile_picture'] = path;
                        });
                      },
                      child: Text('Profile Image'),
                    ),
                    SizedBox(width: 10),
                    if (profilePath.isNotEmpty)
                      Icon(Icons.check_circle, color: Colors.green),
                  ]),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((path) {
                          setStateDialog(() => aadharPath = path);
                          data['aadhar_photo'] = path;
                        });
                      },
                      child: Text('Aadhar Image'),
                    ),
                    SizedBox(width: 10),
                    if (aadharPath.isNotEmpty)
                      Icon(Icons.check_circle, color: Colors.green),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                addOrUpdateKeyUser(data, isEdit: isEdit);
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String key, Map<String, dynamic> data) {
    return TextFormField(
      initialValue: data[key]?.toString(),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => data[key] = v,
    );
  }
}

class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  List<Map<String, dynamic>> keyUsers = [];
  bool isLoading = true;
  String? token; // ✅ Dynamic token
  Set<int> selectedIndexes = {};
  List<String> buyerBpCodes = [];

  final fields = [
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
    'created_at',
    'updated_at',
  ];

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  // ✅ Load token from SharedPreferences
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
    });

    if (token != null) {
      fetchKeyUsers();
      fetchBuyerBpCodes();
    } else {
      print('⚠️ No token found. Please login again.');
    }
  }

  // ✅ Fetch Users
  Future<void> fetchKeyUsers() async {
    if (token == null) {
      print('⚠️ Token is null. Please login again.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('http://127.0.0.1:8000/user/user/list/');
    try {
      final resp = await http.get(url, headers: {
        'Authorization': 'Token $token',
      });

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> list = [];

        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded.containsKey('results')) {
          list = List<Map<String, dynamic>>.from(decoded['results']);
        }

        setState(() {
          keyUsers = list;
          isLoading = false;
        });
      } else {
        print('Failed to fetch users: ${resp.statusCode} | ${resp.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching users: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // ✅ Fetch Buyer BP Codes
  Future<void> fetchBuyerBpCodes() async {
    if (token == null) return;

    final url = Uri.parse(
        'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
    try {
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> buyerList = [];

        if (decoded is Map && decoded.containsKey('results')) {
          buyerList = List<Map<String, dynamic>>.from(decoded['results']);
        }

        setState(() {
          buyerBpCodes =
              buyerList.map((buyer) => buyer['bp_code'].toString()).toList();
        });
      } else {
        print('Failed to fetch buyers: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  // ✅ Add or Update User
  Future<void> addOrUpdateKeyUser(Map<String, dynamic> data,
      {bool isEdit = false}) async {
    if (token == null) {
      print('⚠️ Token is null. Please login again.');
      return;
    }

    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/user/User/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/user/User/registration/');

    try {
      var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
      request.headers['Authorization'] = 'Token $token';

      // ✅ Add fields except images & user_permissions
      data.forEach((key, value) {
        if (value != null &&
            key != 'profile_picture' &&
            key != 'aadhar_photo' &&
            key != 'user_permissions') {
          request.fields[key] = value.toString();
        }
      });

      // ✅ Attach profile image if new
      if (data['profile_picture'] != null &&
          data['profile_picture'].toString().isNotEmpty &&
          !data['profile_picture'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_picture', data['profile_picture']));
      }

      // ✅ Attach aadhar image if new
      if (data['aadhar_photo'] != null &&
          data['aadhar_photo'].toString().isNotEmpty &&
          !data['aadhar_photo'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath(
            'aadhar_photo', data['aadhar_photo']));
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        fetchKeyUsers();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('User saved successfully')));
      } else {
        print('Failed to save user: ${response.statusCode} | $respStr');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save user: ${response.statusCode}')));
      }
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  Future<void> pickImage(Function(String) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) onSelected(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Users'),
        actions: [
          ElevatedButton(
            onPressed: () => showKeyUserForm(isEdit: false),
            child: Text('Add New'),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : keyUsers.isEmpty
              ? Center(child: Text('No users found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Actions')),
                      ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
                    ],
                    rows: keyUsers.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> keyUser = entry.value;
                      bool isSelected = selectedIndexes.contains(index);

                      return DataRow(
                        selected: isSelected,
                        cells: [
                          DataCell(Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedIndexes.add(index);
                                } else {
                                  selectedIndexes.remove(index);
                                }
                              });
                            },
                          )),
                          DataCell(
                            Row(
                              children: isSelected
                                  ? [
                                      ElevatedButton(
                                          onPressed: () =>
                                              showViewDialog(keyUser),
                                          child: Text('View')),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                          onPressed: () => showKeyUserForm(
                                              keyUser: keyUser, isEdit: true),
                                          child: Text('Edit')),
                                    ]
                                  : [Text('')],
                            ),
                          ),
                          ...fields.map((f) {
                            final val = keyUser[f];
                            if (f == 'profile_picture' || f == 'aadhar_photo') {
                              return DataCell(val != null
                                  ? Image.network(val,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.image_not_supported))
                                  : Icon(Icons.image));
                            }
                            if (val is bool) {
                              return DataCell(Icon(
                                  val ? Icons.check_circle : Icons.cancel,
                                  color:
                                      val ? Colors.green : Colors.red));
                            }
                            return DataCell(Text(val?.toString() ?? ''));
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  void showViewDialog(Map<String, dynamic> keyUser) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Key User'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.map((f) {
              final val = keyUser[f];
              if (f == 'profile_picture' || f == 'aadhar_photo') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.toUpperCase()),
                    val != null
                        ? Image.network(val,
                            width: 100,
                            height: 100,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.image_not_supported))
                        : Text('No Image'),
                    SizedBox(height: 10),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(f.toUpperCase())),
                    Expanded(flex: 3, child: Text(val?.toString() ?? '')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Close'))
        ],
      ),
    );
  }

  void showKeyUserForm({Map<String, dynamic>? keyUser, bool isEdit = false}) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> data = Map.from(keyUser ?? {});
    String profilePath = data['profile_picture'] ?? '';
    String aadharPath = data['aadhar_photo'] ?? '';
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Key User' : 'Add Key User'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  buildTextField('Full Name', 'full_name', data),
                  buildTextField('Email', 'email_id', data),
                  buildTextField('Mobile', 'mobile_no', data),
                  buildTextField('User Code', 'user_code', data),

                  DropdownButtonFormField<String>(
                    value: data['bp_code'] != null &&
                            buyerBpCodes.any((bp) =>
                                bp.split('-').first.trim() == data['bp_code'])
                        ? data['bp_code']
                        : null,
                    items: buyerBpCodes.map((bp) {
                      final bpCode = bp.split('-').first.trim();
                      return DropdownMenuItem<String>(
                        value: bpCode,
                        child: Text(bp),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        data['bp_code'] = value!;
                      });
                    },
                    decoration: InputDecoration(labelText: 'BP Code'),
                  ),

                  buildTextField('DOB', 'dob', data),
                  buildTextField('City', 'city', data),
                  buildTextField('State', 'state', data),
                  buildTextField('Country', 'country', data),
                  buildTextField('Pincode', 'pincode', data),
                  buildTextField('Aadhar Number', 'aadhar_number', data),

                  if (!isEdit)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(showPassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setStateDialog(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: !showPassword,
                      validator: (value) {
                        if (!isEdit && (value == null || value.isEmpty)) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      onChanged: (v) => data['password'] = v,
                    ),

                  SizedBox(height: 10),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((path) {
                          setStateDialog(() => profilePath = path);
                          data['profile_picture'] = path;
                        });
                      },
                      child: Text('Profile Image'),
                    ),
                    SizedBox(width: 10),
                    if (profilePath.isNotEmpty)
                      Icon(Icons.check_circle, color: Colors.green),
                  ]),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((path) {
                          setStateDialog(() => aadharPath = path);
                          data['aadhar_photo'] = path;
                        });
                      },
                      child: Text('Aadhar Image'),
                    ),
                    SizedBox(width: 10),
                    if (aadharPath.isNotEmpty)
                      Icon(Icons.check_circle, color: Colors.green),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                addOrUpdateKeyUser(data, isEdit: isEdit);
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String key, Map<String, dynamic> data) {
    return TextFormField(
      initialValue: data[key]?.toString(),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => data[key] = v,
    );
  }
}


// class UserPage extends StatefulWidget {
//   @override
//   _UserPageState createState() => _UserPageState();
// }

// class _UserPageState extends State<UserPage> {
//   List<Map<String, dynamic>> users = [];
//   bool isLoading = true;
//   String? token;
//   Set<int> selectedIndexes = {};
//   List<String> buyerBpCodes = [];

//   final fields = [
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
//     'created_at',
//     'updated_at',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     loadToken();
//   }

//   Future<void> loadToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedToken = prefs.getString('token');

//     setState(() {
//       token = savedToken;
//     });

//     if (token != null) {
//       fetchUsers();
//       fetchBuyerBpCodes();
//     } else {
//       print('⚠️ No token found. Please login again.');
//     }
//   }

//   Future<void> fetchUsers() async {
//     if (token == null) {
//       print('⚠️ Token is null. Please login again.');
//       return;
//     }

//     setState(() => isLoading = true);

//     final url = Uri.parse('http://127.0.0.1:8000/user/user/list/');
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
//           users = list;
//           isLoading = false;
//         });
//       } else {
//         print('Failed to fetch users: ${resp.statusCode} | ${resp.body}');
//         setState(() => isLoading = false);
//       }
//     } catch (e) {
//       print('Error fetching users: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> fetchBuyerBpCodes() async {
//     if (token == null) return;

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
//           buyerBpCodes = buyerList.map((buyer) => buyer['bp_code'].toString()).toList();
//         });
//       } else {
//         print('Failed to fetch buyers: ${resp.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching buyers: $e');
//     }
//   }

//   Future<void> addOrUpdateUser(Map<String, dynamic> data, {bool isEdit = false}) async {
//     if (token == null) {
//       print('⚠️ Token is null. Please login again.');
//       return;
//     }

//     Uri url = isEdit
//         ? Uri.parse('http://127.0.0.1:8000/user/User/update/${data['id']}/')
//         : Uri.parse('http://127.0.0.1:8000/user/User/registration/');

//     try {
//       var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
//       request.headers['Authorization'] = 'Token $token';

//       // Skip images & user_permissions
//       data.forEach((key, value) {
//         if (value != null &&
//             key != 'profile_picture' &&
//             key != 'aadhar_photo' &&
//             key != 'user_permissions') {
//           request.fields[key] = value.toString();
//         }
//       });

//       if (data['profile_picture'] != null &&
//           data['profile_picture'].toString().isNotEmpty &&
//           !data['profile_picture'].toString().startsWith('http')) {
//         request.files.add(await http.MultipartFile.fromPath('profile_picture', data['profile_picture']));
//       }

//       if (data['aadhar_photo'] != null &&
//           data['aadhar_photo'].toString().isNotEmpty &&
//           !data['aadhar_photo'].toString().startsWith('http')) {
//         request.files.add(await http.MultipartFile.fromPath('aadhar_photo', data['aadhar_photo']));
//       }

//       var response = await request.send();
//       var respStr = await response.stream.bytesToString();

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         Navigator.pop(context);
//         fetchUsers();
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('User saved successfully')));
//       } else {
//         print('Failed to save user: ${response.statusCode} | $respStr');
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text('Failed to save user')));
//       }
//     } catch (e) {
//       print('Error saving user: $e');
//     }
//   }

//   Future<void> pickImage(Function(String) onSelected) async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
//     if (picked != null) onSelected(picked.path);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Users'),
//         actions: [
//           ElevatedButton(
//             onPressed: () => showUserForm(isEdit: false),
//             child: Text('Add New'),
//           ),
//         ],
//       ),
//       body: isLoading
//           ? Center(child: CircularProgressIndicator())
//           : users.isEmpty
//               ? Center(child: Text('No users found'))
//               : SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: DataTable(
//                     columns: [
//                       DataColumn(label: Text('Select')),
//                       DataColumn(label: Text('Actions')),
//                       ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
//                     ],
//                     rows: users.asMap().entries.map((entry) {
//                       int index = entry.key;
//                       Map<String, dynamic> user = entry.value;
//                       bool isSelected = selectedIndexes.contains(index);

//                       return DataRow(
//                         selected: isSelected,
//                         cells: [
//                           DataCell(Checkbox(
//                             value: isSelected,
//                             onChanged: (bool? value) {
//                               setState(() {
//                                 if (value == true) {
//                                   selectedIndexes.add(index);
//                                 } else {
//                                   selectedIndexes.remove(index);
//                                 }
//                               });
//                             },
//                           )),
//                           DataCell(
//                             Row(
//                               children: isSelected
//                                   ? [
//                                       ElevatedButton(
//                                           onPressed: () => showViewDialog(user),
//                                           child: Text('View')),
//                                       SizedBox(width: 8),
//                                       ElevatedButton(
//                                           onPressed: () => showUserForm(user: user, isEdit: true),
//                                           child: Text('Edit')),
//                                     ]
//                                   : [Text('')],
//                             ),
//                           ),
//                           ...fields.map((f) {
//                             final val = user[f];
//                             if (f == 'profile_picture' || f == 'aadhar_photo') {
//                               return DataCell(val != null
//                                   ? Image.network(val,
//                                       width: 40,
//                                       height: 40,
//                                       errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
//                                   : Icon(Icons.image));
//                             }
//                             if (val is bool) {
//                               return DataCell(Icon(val ? Icons.check_circle : Icons.cancel,
//                                   color: val ? Colors.green : Colors.red));
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

//   void showViewDialog(Map<String, dynamic> user) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text('View User'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: fields.map((f) {
//               final val = user[f];
//               if (f == 'profile_picture' || f == 'aadhar_photo') {
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(f.toUpperCase()),
//                     val != null
//                         ? Image.network(val,
//                             width: 100,
//                             height: 100,
//                             errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
//                         : Text('No Image'),
//                     SizedBox(height: 10),
//                   ],
//                 );
//               }
//               return Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 4),
//                 child: Row(
//                   children: [
//                     Expanded(flex: 2, child: Text(f.toUpperCase())),
//                     Expanded(flex: 3, child: Text(val?.toString() ?? '')),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))
//         ],
//       ),
//     );
//   }

//   void showUserForm({Map<String, dynamic>? user, bool isEdit = false}) {
//     final formKey = GlobalKey<FormState>();
//     Map<String, dynamic> data = Map.from(user ?? {});
//     String profilePath = data['profile_picture'] ?? '';
//     String aadharPath = data['aadhar_photo'] ?? '';
//     bool showPassword = false;

//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(isEdit ? 'Edit User' : 'Add User'),
//         content: StatefulBuilder(
//           builder: (context, setStateDialog) => SingleChildScrollView(
//             child: Form(
//               key: formKey,
//               child: Column(
//                 children: [
//                   buildTextField('Full Name', 'full_name', data),
//                   buildTextField('Email', 'email_id', data),
//                   buildTextField('Mobile', 'mobile_no', data),
//                   buildTextField('User Code', 'user_code', data),

//                   DropdownButtonFormField<String>(
//                     value: data['bp_code'] != null &&
//                             buyerBpCodes.any(
//                                 (bp) => bp.split('-').first.trim() == data['bp_code'])
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

//                   buildTextField('DOB', 'dob', data),
//                   buildTextField('City', 'city', data),
//                   buildTextField('State', 'state', data),
//                   buildTextField('Country', 'country', data),
//                   buildTextField('Pincode', 'pincode', data),
//                   buildTextField('Aadhar Number', 'aadhar_number', data),

//                   if (!isEdit)
//                     TextFormField(
//                       decoration: InputDecoration(
//                         labelText: 'Password',
//                         suffixIcon: IconButton(
//                           icon: Icon(
//                               showPassword ? Icons.visibility : Icons.visibility_off),
//                           onPressed: () {
//                             setStateDialog(() {
//                               showPassword = !showPassword;
//                             });
//                           },
//                         ),
//                       ),
//                       obscureText: !showPassword,
//                       validator: (value) {
//                         if (!isEdit && (value == null || value.isEmpty)) {
//                           return 'Password is required';
//                         }
//                         return null;
//                       },
//                       onChanged: (v) => data['password'] = v,
//                     ),

//                   SizedBox(height: 10),
//                   Row(children: [
//                     ElevatedButton(
//                       onPressed: () async {
//                         await pickImage((path) {
//                           setStateDialog(() => profilePath = path);
//                           data['profile_picture'] = path;
//                         });
//                       },
//                       child: Text('Profile Image'),
//                     ),
//                     SizedBox(width: 10),
//                     if (profilePath.isNotEmpty)
//                       Icon(Icons.check_circle, color: Colors.green),
//                   ]),
//                   Row(children: [
//                     ElevatedButton(
//                       onPressed: () async {
//                         await pickImage((path) {
//                           setStateDialog(() => aadharPath = path);
//                           data['aadhar_photo'] = path;
//                         });
//                       },
//                       child: Text('Aadhar Image'),
//                     ),
//                     SizedBox(width: 10),
//                     if (aadharPath.isNotEmpty)
//                       Icon(Icons.check_circle, color: Colors.green),
//                   ]),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
//           ElevatedButton(
//             onPressed: () {
//               if (formKey.currentState!.validate()) {
//                 addOrUpdateUser(data, isEdit: isEdit);
//               }
//             },
//             child: Text(isEdit ? 'Update' : 'Create'),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget buildTextField(String label, String key, Map<String, dynamic> data) {
//     return TextFormField(
//       initialValue: data[key]?.toString(),
//       decoration: InputDecoration(labelText: label),
//       onChanged: (v) => data[key] = v,
//     );
//   }
// }


class CraftmanPage extends StatefulWidget {
  @override
  _CraftmanPageState createState() => _CraftmanPageState();
}

class _CraftmanPageState extends State<CraftmanPage> {
  List<Map<String, dynamic>> keyUsers = [];
  bool isLoading = true;
  String? token; // ✅ Dynamic token
  Set<int> selectedIndexes = {};
  List<String> buyerBpCodes = [];

  final fields = [
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
    'created_at',
    'updated_at',
  ];

  @override
  void initState() {
    super.initState();
    loadToken();
  }

  // ✅ Load token from SharedPreferences
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
    });

    if (token != null) {
      fetchKeyUsers();
      fetchBuyerBpCodes();
    } else {
      print('⚠️ No token found. Please login again.');
    }
  }

  // ✅ Fetch Craftsman
  Future<void> fetchKeyUsers() async {
    if (token == null) {
      print('⚠️ Token is null. Please login again.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    final url = Uri.parse('http://127.0.0.1:8000/user/craftsman/list/');
    try {
      final resp = await http.get(url, headers: {
        'Authorization': 'Token $token',
      });

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> list = [];

        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded.containsKey('results')) {
          list = List<Map<String, dynamic>>.from(decoded['results']);
        }

        setState(() {
          keyUsers = list;
          isLoading = false;
        });
      } else {
        print('Failed to fetch Craftsman: ${resp.statusCode} | ${resp.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching Craftsman: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // ✅ Fetch Buyer BP Codes
  Future<void> fetchBuyerBpCodes() async {
    if (token == null) return;

    final url = Uri.parse(
        'http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Craftsmans/');
    try {
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> buyerList = [];

        if (decoded is Map && decoded.containsKey('results')) {
          buyerList = List<Map<String, dynamic>>.from(decoded['results']);
        }

        setState(() {
          buyerBpCodes =
              buyerList.map((buyer) => buyer['bp_code'].toString()).toList();
        });
      } else {
        print('Failed to fetch buyers: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  // ✅ Add or Update Craftsman
  Future<void> addOrUpdateKeyUser(Map<String, dynamic> data,
      {bool isEdit = false}) async {
    if (token == null) {
      print('⚠️ Token is null. Please login again.');
      return;
    }

    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/user/Craftsman/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/user/Craftsman/registration/');

    try {
      var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
      request.headers['Authorization'] = 'Token $token';

      // ✅ Add fields except images & user_permissions
      data.forEach((key, value) {
        if (value != null &&
            key != 'profile_picture' &&
            key != 'aadhar_photo' &&
            key != 'user_permissions') {
          request.fields[key] = value.toString();
        }
      });

      // ✅ Attach profile image if new
      if (data['profile_picture'] != null &&
          data['profile_picture'].toString().isNotEmpty &&
          !data['profile_picture'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_picture', data['profile_picture']));
      }

      // ✅ Attach aadhar image if new
      if (data['aadhar_photo'] != null &&
          data['aadhar_photo'].toString().isNotEmpty &&
          !data['aadhar_photo'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath(
            'aadhar_photo', data['aadhar_photo']));
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        fetchKeyUsers();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Craftsman saved successfully')));
      } else {
        print('Failed to save Craftsman: ${response.statusCode} | $respStr');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save Craftsman: ${response.statusCode}')));
      }
    } catch (e) {
      print('Error saving Craftsman: $e');
    }
  }

  Future<void> pickImage(Function(String) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) onSelected(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Craftsman'),
        actions: [
          ElevatedButton(
            onPressed: () => showKeyUserForm(isEdit: false),
            child: Text('Add New'),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : keyUsers.isEmpty
              ? Center(child: Text('No Craftsman found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Actions')),
                      ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
                    ],
                    rows: keyUsers.asMap().entries.map((entry) {
                      int index = entry.key;
                      Map<String, dynamic> keyUser = entry.value;
                      bool isSelected = selectedIndexes.contains(index);

                      return DataRow(
                        selected: isSelected,
                        cells: [
                          DataCell(Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedIndexes.add(index);
                                } else {
                                  selectedIndexes.remove(index);
                                }
                              });
                            },
                          )),
                          DataCell(
                            Row(
                              children: isSelected
                                  ? [
                                      ElevatedButton(
                                          onPressed: () =>
                                              showViewDialog(keyUser),
                                          child: Text('View')),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                          onPressed: () => showKeyUserForm(
                                              keyUser: keyUser, isEdit: true),
                                          child: Text('Edit')),
                                    ]
                                  : [Text('')],
                            ),
                          ),
                          ...fields.map((f) {
                            final val = keyUser[f];
                            if (f == 'profile_picture' || f == 'aadhar_photo') {
                              return DataCell(val != null
                                  ? Image.network(val,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (_, __, ___) =>
                                          Icon(Icons.image_not_supported))
                                  : Icon(Icons.image));
                            }
                            if (val is bool) {
                              return DataCell(Icon(
                                  val ? Icons.check_circle : Icons.cancel,
                                  color:
                                      val ? Colors.green : Colors.red));
                            }
                            return DataCell(Text(val?.toString() ?? ''));
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  void showViewDialog(Map<String, dynamic> keyUser) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Craftsman'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: fields.map((f) {
              final val = keyUser[f];
              if (f == 'profile_picture' || f == 'aadhar_photo') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.toUpperCase()),
                    val != null
                        ? Image.network(val,
                            width: 100,
                            height: 100,
                            errorBuilder: (_, __, ___) =>
                                Icon(Icons.image_not_supported))
                        : Text('No Image'),
                    SizedBox(height: 10),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(f.toUpperCase())),
                    Expanded(flex: 3, child: Text(val?.toString() ?? '')),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Close'))
        ],
      ),
    );
  }

  void showKeyUserForm({Map<String, dynamic>? keyUser, bool isEdit = false}) {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic> data = Map.from(keyUser ?? {});
    String profilePath = data['profile_picture'] ?? '';
    String aadharPath = data['aadhar_photo'] ?? '';
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Craftsman' : 'Add Craftsman'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  buildTextField('Full Name', 'full_name', data),
                  buildTextField('Email', 'email_id', data),
                  buildTextField('Mobile', 'mobile_no', data),
                  buildTextField('User Code', 'user_code', data),

                  DropdownButtonFormField<String>(
                    value: data['bp_code'] != null &&
                            buyerBpCodes.any((bp) =>
                                bp.split('-').first.trim() == data['bp_code'])
                        ? data['bp_code']
                        : null,
                    items: buyerBpCodes.map((bp) {
                      final bpCode = bp.split('-').first.trim();
                      return DropdownMenuItem<String>(
                        value: bpCode,
                        child: Text(bp),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        data['bp_code'] = value!;
                      });
                    },
                    decoration: InputDecoration(labelText: 'BP Code'),
                  ),

                  buildTextField('DOB', 'dob', data),
                  buildTextField('City', 'city', data),
                  buildTextField('State', 'state', data),
                  buildTextField('Country', 'country', data),
                  buildTextField('Pincode', 'pincode', data),
                  buildTextField('Aadhar Number', 'aadhar_number', data),

                  if (!isEdit)
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(showPassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setStateDialog(() {
                              showPassword = !showPassword;
                            });
                          },
                        ),
                      ),
                      obscureText: !showPassword,
                      validator: (value) {
                        if (!isEdit && (value == null || value.isEmpty)) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      onChanged: (v) => data['password'] = v,
                    ),

                  SizedBox(height: 10),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((path) {
                          setStateDialog(() => profilePath = path);
                          data['profile_picture'] = path;
                        });
                      },
                      child: Text('Profile Image'),
                    ),
                    SizedBox(width: 10),
                    if (profilePath.isNotEmpty)
                      Icon(Icons.check_circle, color: Colors.green),
                  ]),
                  Row(children: [
                    ElevatedButton(
                      onPressed: () async {
                        await pickImage((path) {
                          setStateDialog(() => aadharPath = path);
                          data['aadhar_photo'] = path;
                        });
                      },
                      child: Text('Aadhar Image'),
                    ),
                    SizedBox(width: 10),
                    if (aadharPath.isNotEmpty)
                      Icon(Icons.check_circle, color: Colors.green),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                addOrUpdateKeyUser(data, isEdit: isEdit);
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String key, Map<String, dynamic> data) {
    return TextFormField(
      initialValue: data[key]?.toString(),
      decoration: InputDecoration(labelText: label),
      onChanged: (v) => data[key] = v,
    );
  }
}

class WorkOrderPage extends StatefulWidget {
  @override
  _WorkOrderPageState createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends State<WorkOrderPage> {
  List<Map<String, dynamic>> workOrders = [];
  List<Map<String, dynamic>> allWorkOrders = [];
  bool isLoading = true;
  String token = "c4d39cfb658de543df3719a86ff8bee85ea8da85";
  Set<int> selectedIds = {};
  List<String> buyerBpCodes = [];

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
    fetchWorkOrders();
    fetchBuyerBpCodes();
  }

  Future<void> fetchWorkOrders() async {
    setState(() => isLoading = true);
    final url = Uri.parse('http://127.0.0.1:8000/order/orders/list/');
    try {
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> list = [];
        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded.containsKey('results')) {
          list = List<Map<String, dynamic>>.from(decoded['results']);
        }
        setState(() {
          allWorkOrders = list;
          workOrders = list;
          isLoading = false;
        });
      } else {
        print('Failed to fetch work orders: ${resp.statusCode} | ${resp.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching work orders: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchBuyerBpCodes() async {
    final url = Uri.parse('http://127.0.0.1:8000/BusinessPartner/BusinessPartner/Buyers/');
    try {
      final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        List<Map<String, dynamic>> buyerList = [];
        if (decoded is Map && decoded.containsKey('results')) {
          buyerList = List<Map<String, dynamic>>.from(decoded['results']);
        }
        setState(() {
          buyerBpCodes = buyerList.map((buyer) => "${buyer['bp_code']}").toList();
        });
      } else {
        print('Failed to fetch buyers: ${resp.statusCode}');
      }
    } catch (e) {
      print('Error fetching buyers: $e');
    }
  }

  Future<void> addOrUpdateWorkOrder(Map<String, dynamic> data, {bool isEdit = false}) async {
    Uri url = isEdit
        ? Uri.parse('http://127.0.0.1:8000/order/orders/update/${data['id']}/')
        : Uri.parse('http://127.0.0.1:8000/order/orders/create/');
    try {
      var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', url);
      request.headers['Authorization'] = 'Token $token';

      data.forEach((key, value) async {
        if (value != null && key != 'product_image') {
          String valStr = value.toString();
          if ((key == 'due_date' || key == 'craftsman_due_date') &&
              RegExp(r'\d{2}-\d{2}-\d{4}').hasMatch(valStr)) {
            List<String> parts = valStr.split('-');
            valStr = "${parts[2]}-${parts[1]}-${parts[0]}";
          }
          request.fields[key] = valStr;
        }
      });

      if (data['product_image'] != null &&
          data['product_image'].toString().isNotEmpty &&
          !data['product_image'].toString().startsWith('http')) {
        request.files.add(await http.MultipartFile.fromPath('product_image', data['product_image']));
      }

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.pop(context);
        fetchWorkOrders();
      } else {
        print('Failed to save work order: ${response.statusCode} | $respStr');
      }
    } catch (e) {
      print('Error saving work order: $e');
    }
  }

  Future<void> pickImage(Function(String) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) onSelected(picked.path);
  }

  // ✅ Status Filter with API integration for New orders
  void filterWorkOrdersByStatus(String status) async {
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
        final resp = await http.get(url, headers: {'Authorization': 'Token $token'});
        if (resp.statusCode == 200) {
          final decoded = json.decode(resp.body);
          List<Map<String, dynamic>> list = [];
          if (decoded is List) {
            list = List<Map<String, dynamic>>.from(decoded);
          } else if (decoded is Map && decoded.containsKey('results')) {
            list = List<Map<String, dynamic>>.from(decoded['results']);
          }
          setState(() {
            workOrders = list;
            isLoading = false;
          });
        } else {
          print('Failed to fetch new orders: ${resp.statusCode} | ${resp.body}');
          setState(() => isLoading = false);
        }
      } catch (e) {
        print('Error fetching new orders: $e');
        setState(() => isLoading = false);
      }
    } else {
      // Local filter for other statuses
      setState(() {
        workOrders = allWorkOrders.where((order) {
          return (order['status']?.toString().toLowerCase() == status.toLowerCase());
        }).toList();
      });
    }
  }

  // ✅ Navigate to AllocatedToPage
  void _navigateToAllocatedToPage() {
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one order to allocate'))
      );
      return;
    }

    // Get the first selected order (you might want to handle multiple selections differently)
    final selectedOrder = workOrders.firstWhere((order) => selectedIds.contains(order['id']));
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AllocatedToPage(
          order: selectedOrder,
          token: token,
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
      onPressed: () {
        filterWorkOrdersByStatus(status);
      },
      child: Text(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work Orders'),
        actions: [
          ElevatedButton(
            onPressed: () => showWorkOrderForm(isEdit: false),
            child: Text('Add New'),
          ),
          SizedBox(width: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildStatusButton('All'),
              _buildStatusButton('New'),
              _buildStatusButton('Allocated'),
              _buildStatusButton('In Process'),
              _buildStatusButton('Approval'),
              _buildStatusButton('Completed'),
              _buildStatusButton('Rejected'),
              ElevatedButton(
                onPressed: _navigateToAllocatedToPage,
                child: Text('Allocated To'),
              ),
            ],
          ),
          SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : workOrders.isEmpty
              ? Center(child: Text('No work orders found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text('Select')),
                      DataColumn(label: Text('Actions')),
                      ...fields.map((f) => DataColumn(label: Text(f.toUpperCase()))),
                    ],
                    rows: workOrders.map((workOrder) {
                      int id = workOrder['id'];
                      bool isSelected = selectedIds.contains(id);

                      return DataRow(
                        selected: isSelected,
                        cells: [
                          DataCell(Checkbox(
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
                          )),
                          DataCell(
                            Row(
                              children: isSelected
                                  ? [
                                      ElevatedButton(onPressed: () => showViewDialog(workOrder), child: Text('View')),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                          onPressed: () => showWorkOrderForm(workOrder: workOrder, isEdit: true),
                                          child: Text('Edit')),
                                    ]
                                  : [Text('')],
                            ),
                          ),
                          ...fields.map((f) {
                            final val = workOrder[f];
                            if (f == 'product_image') {
                              return DataCell(val != null
                                  ? Image.network(val, width: 40, height: 40, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
                                  : Icon(Icons.image));
                            }
                            return DataCell(Text(val?.toString() ?? ''));
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
  void showViewDialog(Map<String, dynamic> workOrder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('View Work Order'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: fields.map((f) {
              final val = workOrder[f];
              if (f == 'product_image') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.toUpperCase()),
                    val != null
                        ? Image.network(val, width: 100, height: 100, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported))
                        : Text('No Image'),
                    SizedBox(height: 10),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [Expanded(flex: 2, child: Text(f.toUpperCase())), Expanded(flex: 3, child: Text(val?.toString() ?? ''))],
                ),
              );
            }).toList(),
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
          builder: (context, setStateDialog) => SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: data['bp_code'] != null &&
                            buyerBpCodes.any((bp) => bp.split('-').first.trim() == data['bp_code'])
                        ? data['bp_code']
                        : null,
                    items: buyerBpCodes.map((bp) {
                      final bpCode = bp.split('-').first.trim();
                      return DropdownMenuItem<String>(
                        value: bpCode,
                        child: Text(bp),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        data['bp_code'] = value!;
                      });
                    },
                    decoration: InputDecoration(labelText: 'BP Code'),
                  ),
                  SizedBox(height: 10),
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
                    if (profilePath.isNotEmpty) Icon(Icons.check_circle, color: Colors.green),
                  ]),
                  SizedBox(height: 10),
                  ...fields.where((f) {
                    if (!isEdit && readOnlyFields.contains(f)) return false;
                    return f != 'product_image' && f != 'bp_code';
                  }).map((f) {
                    if (f == 'product_category') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: data[f] != null && productCategories.contains(data[f]) ? data[f] : null,
                          items: productCategories
                              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                              .toList(),
                          onChanged: (val) => data[f] = val,
                          decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder()),
                        ),
                      );
                    } else if (f == 'type') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: data[f] != null && typeOptions.contains(data[f]) ? data[f] : null,
                          items: typeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                          onChanged: (val) => data[f] = val,
                          decoration: InputDecoration(labelText: 'TYPE', border: OutlineInputBorder()),
                        ),
                      );
                    } else if (f == 'order_type') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: data[f] != null && orderTypeOptions.contains(data[f]) ? data[f] : null,
                          items: orderTypeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                          onChanged: (val) => data[f] = val,
                          decoration: InputDecoration(labelText: 'ORDER TYPE', border: OutlineInputBorder()),
                        ),
                      );
                    } else if (f == 'open_close') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: data[f] != null && openCloseOptions.contains(data[f]) ? data[f] : null,
                          items: openCloseOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                          onChanged: (val) => data[f] = val,
                          decoration: InputDecoration(labelText: 'OPEN/CLOSE', border: OutlineInputBorder()),
                        ),
                      );
                    } else if (['hallmark', 'rodium', 'hook', 'stone'].contains(f)) {
                      final yesNoOptions = ['Yes', 'No'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: data[f] != null && yesNoOptions.contains(data[f]) ? data[f] : null,
                          items: yesNoOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                          onChanged: (val) => data[f] = val,
                          decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder()),
                        ),
                      );
                    } else if (f == 'size') {
                      final sizeOptions = ['Large', 'Medium', 'Small'];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DropdownButtonFormField<String>(
                          value: data[f] != null && sizeOptions.contains(data[f]) ? data[f] : null,
                          items: sizeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                          onChanged: (val) => data[f] = val,
                          decoration: InputDecoration(labelText: 'SIZE', border: OutlineInputBorder()),
                        ),
                      );
                    } else if (f == 'due_date' || f == 'craftsman_due_date') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () async {
                            DateTime initialDate = DateTime.now();
                            if (data[f] != null && data[f].toString().isNotEmpty) {
                              try {
                                List<String> parts = data[f].toString().split('-');
                                if (parts.length == 3) initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                              } catch (_) {}
                            }
                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setStateDialog(() => data[f] = "${picked.day.toString().padLeft(2,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.year}");
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(text: data[f]?.toString() ?? ''),
                              decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextFormField(
                          initialValue: data[f]?.toString() ?? '',
                          readOnly: readOnlyFields.contains(f),
                          decoration: InputDecoration(labelText: f.toUpperCase(), border: OutlineInputBorder()),
                          onChanged: (val) => data[f] = val,
                        ),
                      );
                    }
                  }).toList(),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              addOrUpdateWorkOrder(data, isEdit: isEdit);
            },
            child: Text(isEdit ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
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
    final url = Uri.parse(
        'https://veto.co.in/BusinessPartner/BusinessPartner/Craftsmans/');
    try {
      final response =
          await http.get(url, headers: {'Authorization': 'Token ${widget.token}'});

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<dynamic> craftsmenListRaw = [];

        if (jsonData is List) {
          craftsmenListRaw = jsonData;
        } else if (jsonData is Map && jsonData.containsKey('results')) {
          craftsmenListRaw = jsonData['results'];
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
      } else {
        throw Exception('Failed to load craftsmen');
      }
    } catch (e) {
      print('Error fetching craftsmen: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> allocateOrder() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final url = Uri.parse('https://veto.co.in/order/orders/assign-orders/');
    try {
      Map<String, dynamic> body = {
        "order_id": widget.order['id'],
        "bp_code": selectedBpCode!,
      };

      if (dueDate != null) {
        List<String> parts = dueDate!.split('-');
        body['due_date'] = "${parts[2]}-${parts[1]}-${parts[0]}";
      }

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Token ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order allocated successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}')),
        );
      }
    } catch (e) {
      print('Error allocating order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error allocating order')),
      );
    }
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
                    Text('Order No: ${widget.order['order_no']}',
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select BP Code',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedBpCode,
                      items: craftsmanList.map((item) {
                        return DropdownMenuItem(
                          value: item['bp_code'],
                          child: Text("${item['bp_code']}"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => selectedBpCode = val),
                      validator: (val) =>
                          val == null ? 'Please select BP Code' : null,
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
                            labelText: 'Due Date',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: dueDate ?? ''),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(onPressed: allocateOrder, child: Text('Allocate')),
                  ],
                ),
              ),
            ),
    );
  }
}
void main() {
  runApp(MaterialApp(
    home: PurchaseOrderPage(),
    theme: ThemeData(
      primaryColor: Colors.blueGrey[900],
      colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.blue),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
    ),
  ));
}

class PurchaseOrderPage extends StatefulWidget {
  @override
  _PurchaseOrderPageState createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  String selectedFilter = 'Specific';
  TextEditingController searchController = TextEditingController();

  final List<String> filters = ['Specific', 'All', 'Pending'];
  final List<String> tabs = ['Created', 'In Process', 'Presented', 'Rejected'];
  int selectedTabIndex = 0;

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
      ),
      body: Padding(
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
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CreatePurchaseOrderPage()),
                      );
                    },
                    icon: Icon(Icons.add, size: 18),
                    label: Text('Add New'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Edit'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('View'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Sort'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Filter'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Print'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Allocate'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      backgroundColor: Colors.green,
                    ),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Share'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(tabs.length, (index) {
                  return Container(
                    margin: EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tabs[index]),
                      selected: selectedTabIndex == index,
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: selectedTabIndex == index ? Colors.white : Colors.black,
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          selectedTabIndex = selected ? index : 0;
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
              ),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Created Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Items', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Total Weight', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            // Table Data (Empty for now)
            Expanded(
              child: Center(
                child: Text(
                  'No Purchase Orders Available',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class CreatePurchaseOrderPage extends StatefulWidget {
  @override
  _CreatePurchaseOrderPageState createState() =>
      _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  DateTime? selectedDate;
  TextEditingController dueDateController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  List<Map<String, dynamic>> items = [];
  final List<String> categories = ["Bangles", "Chains", "Rings", "Earrings"];
  final List<String> designs = ["Knot Rope", "Plain", "Fancy", "Custom"];

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
            // ✅ Due Date + Note Section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dueDateController,
                    decoration: InputDecoration(
                      labelText: "Due Date",
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
                                  "${picked.month}/${picked.day}/${picked.year}";
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

            // ✅ Table Header
            Container(
              color: Colors.grey[200],
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                children: [
                  Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Category", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Design", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Grams & Qty", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Total Weight", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("Notes", style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text("Action", style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // ✅ Dynamic Rows
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  var item = items[index];
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey)),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text("${index + 1}")), // ✅ S.No

                        // ✅ Category Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButton<String>(
                            value: categories.contains(item["category"])
                                ? item["category"]
                                : null,
                            hint: Text("Select"),
                            isExpanded: true,
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item["category"] = val!;
                              });
                            },
                          ),
                        ),

                        // ✅ Design Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButton<String>(
                            value: designs.contains(item["design"])
                                ? item["design"]
                                : null,
                            hint: Text("Select"),
                            isExpanded: true,
                            items: designs.map((des) {
                              return DropdownMenuItem(
                                value: des,
                                child: Text(des),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                item["design"] = val!;
                              });
                            },
                          ),
                        ),

                        // ✅ Grams & Quantity
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(hintText: "Gram"),
                                  onChanged: (val) {
                                    setState(() {
                                      item["grams"] = int.tryParse(val) ?? 0;
                                      item["total"] =
                                          item["grams"] * item["qty"];
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(hintText: "Qty"),
                                  onChanged: (val) {
                                    setState(() {
                                      item["qty"] = int.tryParse(val) ?? 0;
                                      item["total"] =
                                          item["grams"] * item["qty"];
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ✅ Total Weight
                        Expanded(
                          flex: 2,
                          child: Text("${item["total"]}"),
                        ),

                        // ✅ Notes
                        Expanded(
                          flex: 2,
                          child: TextField(
                            decoration: InputDecoration(hintText: "Notes"),
                            onChanged: (val) {
                              item["note"] = val;
                            },
                          ),
                        ),
                        // ✅ Remove Action
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      items.add({
                        "category": categories.isNotEmpty ? categories[0] : null,
                        "design": designs.isNotEmpty ? designs[0] : null,
                        "grams": 0,
                        "qty": 0,
                        "total": 0,
                        "note": ""
                      });
                    });
                  },
                  child: Text("Add Item"),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () {
                    print("Final Items: $items");
                  },
                  child: Text("Create Order"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
