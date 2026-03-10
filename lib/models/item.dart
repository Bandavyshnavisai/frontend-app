class Item {
  final String id;
  final String title;
  final String type; // 'lost' or 'found'
  final String location;
  final String description;
  final String status;
  final String? imageUrl;
  final String reportedBy;
  final dynamic createdAt;
  final bool saleEligible;
  final String? saleStatus;
  final dynamic price;

  Item({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.description,
    required this.status,
    this.imageUrl,
    required this.reportedBy,
    required this.createdAt,
    this.saleEligible = false,
    this.saleStatus,
    this.price,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? 'lost',
      location: json['location'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      imageUrl: json['imageUrl'],
      reportedBy: json['reportedBy'] ?? '',
      createdAt: json['createdAt'],
      saleEligible: json['saleEligible'] == true,
      saleStatus: json['saleStatus'],
      price: json['price'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'location': location,
      'description': description,
      'status': status,
      'imageUrl': imageUrl,
      'reportedBy': reportedBy,
      'createdAt': createdAt,
      'saleEligible': saleEligible,
      'saleStatus': saleStatus,
      'price': price,
    };
  }
}
