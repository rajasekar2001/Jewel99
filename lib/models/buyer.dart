class Buyer {
  final int id;
  final String role;
  final String bpCode;
  final String businessName;
  final String name;
  final String mobile;
  final String email;
  final String pincode;

  Buyer({
    required this.id,
    required this.role,
    required this.bpCode,
    required this.businessName,
    required this.name,
    required this.mobile,
    required this.email,
    required this.pincode,
  });

  factory Buyer.fromJson(Map<String, dynamic> json) {
    return Buyer(
      id: json['id'],
      role: json['role'],
      bpCode: json['bp_code'],
      businessName: json['business_name'],
      name: json['name'],
      mobile: json['mobile'],
      email: json['email'],
      pincode: json['pincode'],
    );
  }
}