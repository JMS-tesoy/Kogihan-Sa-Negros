import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/plan_model.dart';
import '../../data/services/purchase_handler.dart';

class PurchaseFlowScreen extends StatefulWidget {
  final PlanModel plan;
  final VoidCallback onSuccess;

  const PurchaseFlowScreen({
    required this.plan,
    required this.onSuccess,
    super.key,
  });

  @override
  State<PurchaseFlowScreen> createState() => _PurchaseFlowScreenState();
}

class _PurchaseFlowScreenState extends State<PurchaseFlowScreen> {
  late final PurchaseHandler _purchaseHandler;
  PurchaseState _purchaseState = PurchaseState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _purchaseHandler = PurchaseHandler();
    _listenToPurchaseUpdates();
  }

  void _listenToPurchaseUpdates() {
    _purchaseHandler.purchaseUpdates.listen(
      (result) {
        if (!mounted) return;

        setState(() {
          _purchaseState = result.state;
          _errorMessage = result.userMessage;
        });

        if (result.state == PurchaseState.success) {
          _showSuccessAndClose();
        } else if (result.state == PurchaseState.error) {
          AppSnackBar.error(
            context,
            result.userMessage ?? 'Purchase failed',
          );
        }
      },
    );
  }

  void _showSuccessAndClose() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Purchase Complete'),
        content: const Text('Your subscription has been activated.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onSuccess();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _startPurchase() async {
    // Map plan to store product IDs
    final String productId = _getProductIdForPlan();
    setState(() {
      _errorMessage = null;
      _purchaseState = PurchaseState.loading;
    });

    try {
      // Load products from store
      final products = await _purchaseHandler.loadProducts();
      
      // Find the matching product
      final product = products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found: $productId'),
      );

      // Start purchase
      final result = await _purchaseHandler.purchaseProduct(
        product: product,
        userId: '', // TODO: Get actual user ID from auth
      );

      if (!mounted) return;
      setState(() {
        _purchaseState = result.state;
        _errorMessage = result.errorMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchaseState = PurchaseState.error;
        _errorMessage = 'Failed to load products: $e';
      });
    }
  }

  String _getProductIdForPlan() {
    // Map to actual store product IDs
    // These should match your Google Play Console and App Store Connect setup
    if (widget.plan.id == 'monthly_plan') {
      return Platform.isAndroid
          ? 'com.landfinder.app.monthly'
          : 'landfinder_monthly';
    } else if (widget.plan.id == 'yearly_plan') {
      return Platform.isAndroid
          ? 'com.landfinder.app.yearly'
          : 'landfinder_yearly';
    }
    throw ArgumentError('Invalid plan ID: ${widget.plan.id}');
  }

  @override
  void dispose() {
    _purchaseHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Complete Purchase'),
      centerTitle: true,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.plan.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.plan.priceLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.plan.billingLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ...widget.plan.features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(feature)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Purchase flow status
          if (_purchaseState != PurchaseState.idle) ...[
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_purchaseState == PurchaseState.processing) ...[
                      const SizedBox(
                        height: 40,
                        width: 40,
                        child: CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Processing your purchase...',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while we verify your payment',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else if (_purchaseState == PurchaseState.error) ...[
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Purchase Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ] else if (_purchaseState == PurchaseState.success) ...[
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Purchase Successful',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Info section
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About ${Platform.isAndroid ? 'Google Play' : 'App Store'} Purchases',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'Your purchase will be charged to your Google Play account. Your subscription will auto-renew unless cancelled in Google Play settings.'
                        : 'Your purchase will be charged to your App Store account. Your subscription will auto-renew unless cancelled in App Store settings.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Terms text
          Text(
            'By proceeding, you agree to our Terms of Service and acknowledge the subscription terms listed above.',
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _purchaseState == PurchaseState.processing
                  ? null
                  : _startPurchase,
              child: _purchaseState == PurchaseState.processing
                  ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Text('Subscribe for ${widget.plan.priceLabel}'),
            ),
            const SizedBox(height: 8),
            if (_purchaseState == PurchaseState.error)
              TextButton(
                onPressed: _startPurchase,
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    ),
  );
}
