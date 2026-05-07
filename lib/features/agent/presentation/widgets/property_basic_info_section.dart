import 'package:flutter/material.dart';

class PropertyBasicInfoSection extends StatelessWidget {
  const PropertyBasicInfoSection({
    super.key,
    required this.referenceCodeController,
    required this.titleController,
    required this.locationController,
    required this.priceController,
    required this.sizeController,
    required this.statusController,
    required this.selectedTitleStatus,
    required this.titleStatusOptions,
    required this.onFieldChanged,
    required this.onPickNegrosPlace,
    required this.onTitleStatusChanged,
    required this.referenceCodeValidator,
    required this.titleValidator,
    required this.locationValidator,
    required this.priceValidator,
    required this.sizeValidator,
    required this.statusValidator,
    required this.titleStatusValidator,
  });

  final TextEditingController referenceCodeController;
  final TextEditingController titleController;
  final TextEditingController locationController;
  final TextEditingController priceController;
  final TextEditingController sizeController;
  final TextEditingController statusController;
  final String selectedTitleStatus;
  final List<String> titleStatusOptions;
  final VoidCallback onFieldChanged;
  final VoidCallback onPickNegrosPlace;
  final ValueChanged<String?> onTitleStatusChanged;
  final FormFieldValidator<String> referenceCodeValidator;
  final FormFieldValidator<String> titleValidator;
  final FormFieldValidator<String> locationValidator;
  final FormFieldValidator<String> priceValidator;
  final FormFieldValidator<String> sizeValidator;
  final FormFieldValidator<String> statusValidator;
  final FormFieldValidator<String> titleStatusValidator;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Listing Identity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add the core listing details the agent should track and publish.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildCompactFieldRow(
            left: _buildFormField(
              controller: referenceCodeController,
              label: 'Listing code',
              hintText: 'LF-000120008',
              icon: Icons.pin_outlined,
              validator: referenceCodeValidator,
            ),
            right: _buildFormField(
              controller: titleController,
              label: 'Clean title',
              hintText: 'Prime Residential Lot',
              icon: Icons.title_rounded,
              validator: titleValidator,
            ),
          ),
          const SizedBox(height: 12),
          _buildFormField(
            controller: locationController,
            label: 'Location / area',
            hintText: 'Example: Dumaguete City or 9.3077, 123.3054',
            icon: Icons.location_on_outlined,
            validator: locationValidator,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onPickNegrosPlace,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Pick from Negros places'),
            ),
          ),
          const SizedBox(height: 12),
          _buildCompactFieldRow(
            left: _buildFormField(
              controller: priceController,
              label: 'Price',
              hintText: '₱1,200,000',
              icon: Icons.payments_outlined,
              validator: priceValidator,
            ),
            right: _buildFormField(
              controller: sizeController,
              label: 'Lot size',
              hintText: '500 sqm',
              icon: Icons.straighten_rounded,
              validator: sizeValidator,
            ),
          ),
          const SizedBox(height: 12),
          _buildCompactFieldRow(
            left: _buildFormField(
              controller: statusController,
              label: 'Card tag',
              hintText: 'Featured',
              icon: Icons.sell_outlined,
              validator: statusValidator,
            ),
            right: _buildSelectionField(
              label: 'Title status',
              icon: Icons.verified_outlined,
              value: selectedTitleStatus,
              items: titleStatusOptions,
              onChanged: onTitleStatusChanged,
              validator: titleStatusValidator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFieldRow({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
    String? helperText,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => onFieldChanged(),
      minLines: maxLines != null && maxLines > 1 ? maxLines : 1,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      validator: validator,
    );
  }

  Widget _buildSelectionField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required FormFieldValidator<String> validator,
    String? helperText,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      validator: validator,
    );
  }
}
