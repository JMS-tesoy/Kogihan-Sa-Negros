class AgentListingFormModel {
  const AgentListingFormModel({
    required this.title,
    required this.price,
    this.description = '',
    this.address = '',
  });

  final String title;
  final double price;
  final String description;
  final String address;
}
