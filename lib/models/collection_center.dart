class CollectionCenter {
  final String id;
  final String centerName;
  final String wardName;
  final String address;
  final List<String> acceptedTypes;
  final double lat;
  final double lng;
  final bool isDemo;

  const CollectionCenter({
    required this.id,
    required this.centerName,
    required this.wardName,
    required this.address,
    required this.acceptedTypes,
    required this.lat,
    required this.lng,
    this.isDemo = true,
  });

  factory CollectionCenter.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['accepted_types'];
    final List<String> types = rawTypes is List
        ? rawTypes.map((e) => e.toString()).toList()
        : ['Dry', 'Wet'];

    return CollectionCenter(
      id: json['id']?.toString() ?? '',
      centerName: json['center_name']?.toString() ?? 'Dry Waste Centre',
      wardName: json['ward_name']?.toString() ?? 'Bengaluru',
      address: json['address']?.toString() ?? '',
      acceptedTypes: types,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      isDemo: json['is_demo'] as bool? ?? true,
    );
  }
}
