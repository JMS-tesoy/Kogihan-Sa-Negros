import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/config/env_config.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/models/plan_model.dart';
import '../../domain/entities/payment_method.dart';
import '../../data/services/purchase_handler.dart';
import '../../data/services/paymongo_billing_provider.dart';
import 'purchase_success_screen.dart';

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
  late final PayMongoBillingProvider _payMongo;
  StreamSubscription<PurchaseResult>? _purchaseSubscription;
  PurchaseState _purchaseState = PurchaseState.idle;
  String? _errorMessage;
  List<PaymentMethodEntity> _paymentMethods = const [];
  PaymentMethodId _selectedMethod = PaymentMethodId.store;

  @override
  void initState() {
    super.initState();
    _purchaseHandler = PurchaseHandler();
    _payMongo = PayMongoBillingProvider();
    _listenToPurchaseUpdates();
    unawaited(_loadPaymentMethods());
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final methods = await _payMongo.getAvailableMethods();
      if (!mounted) return;
      setState(() => _paymentMethods = methods);
    } catch (_) {
      if (!mounted) return;
      setState(() => _paymentMethods = const []);
    }
  }

  void _listenToPurchaseUpdates() {
    _purchaseSubscription = _purchaseHandler.purchaseUpdates.listen((result) {
      if (!mounted) return;

      setState(() {
        _purchaseState = result.state;
        _errorMessage = result.userMessage;
      });

      if (result.state == PurchaseState.success) {
        if (result.subscription != null) {
          _showSuccessAndClose(result.subscription!.expiresAt);
        }
      } else if (result.state == PurchaseState.error) {
        AppSnackBar.error(context, result.userMessage ?? 'Purchase failed');
      }
    });
  }

  void _showSuccessAndClose(DateTime? expiryDate) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PurchaseSuccessScreen(
          plan: widget.plan,
          expiryDate: expiryDate,
          onDone: () {
            widget.onSuccess();
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _startPurchase() async {
    if (_selectedMethod != PaymentMethodId.store) {
      await _startPayMongoCheckout();
      return;
    }
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
      final result = await _purchaseHandler.purchaseProduct(product: product);

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

  Future<void> _startPayMongoCheckout() async {
    final PaymentMethodEntity? method = _paymentMethods
        .where((candidate) => candidate.id == _selectedMethod)
        .firstOrNull;
    if (method == null) return;
    setState(() {
      _errorMessage = null;
      _purchaseState = PurchaseState.processing;
    });
    try {
      final session = await _payMongo.createCheckout(
        planId: widget.plan.id,
        method: method,
      );
      final Uri checkout = Uri.parse(session.checkoutUrl);
      final bool launched = await launchUrl(
        checkout,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('Unable to open checkout');
      await _pollOrder(session.orderId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _purchaseState = PurchaseState.error;
        _errorMessage = 'Checkout could not be completed: $error';
      });
    }
  }

  Future<void> _pollOrder(String orderId) async {
    for (int attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final order = await _payMongo.getOrder(orderId);
      if (order.status == 'paid') {
        _showSuccessAndClose(order.entitlementUntil);
        return;
      }
      if (order.isTerminal) {
        setState(() {
          _purchaseState = PurchaseState.error;
          _errorMessage = switch (order.status) {
            'cancelled' => 'Payment was cancelled.',
            'refunded' => 'This payment was refunded.',
            'expired' => 'The checkout expired. Please try again.',
            _ => 'Payment was not completed.',
          };
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _purchaseState = PurchaseState.pending;
        _errorMessage =
            'Payment is still being confirmed. Reopen the app to refresh it.';
      });
    }
  }

  String _getProductIdForPlan() {
    // Map to actual store product IDs
    // These should match your Google Play Console and App Store Connect setup
    if (widget.plan.id == 'monthly_plan') {
      return defaultTargetPlatform == TargetPlatform.android
          ? EnvConfig.googlePlayMonthlySku
          : EnvConfig.appStoreMonthlySku;
    } else if (widget.plan.id == 'yearly_plan') {
      return defaultTargetPlatform == TargetPlatform.android
          ? EnvConfig.googlePlayYearlySku
          : EnvConfig.appStoreYearlySku;
    }
    throw ArgumentError('Invalid plan ID: ${widget.plan.id}');
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    _purchaseHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete Purchase'), centerTitle: true),
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
          Text(
            'Payment method',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          RadioGroup<PaymentMethodId>(
            groupValue: _selectedMethod,
            onChanged: (value) => setState(
              () => _selectedMethod = value ?? PaymentMethodId.store,
            ),
            child: Column(
              children: [
                RadioListTile<PaymentMethodId>(
                  value: PaymentMethodId.store,
                  title: Text(
                    defaultTargetPlatform == TargetPlatform.android
                        ? 'Google Play'
                        : 'App Store',
                  ),
                  subtitle: const Text(
                    'Store-managed subscription and renewal.',
                  ),
                ),
                ..._paymentMethods.map(
                  (method) => RadioListTile<PaymentMethodId>(
                    value: method.id,
                    title: Text(method.label),
                    subtitle: Text(method.description),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                        _selectedMethod == PaymentMethodId.store
                            ? 'About ${defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store'} Purchases'
                            : 'About PayMongo Checkout',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedMethod == PaymentMethodId.store
                        ? 'Your purchase is charged and managed by ${defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store'}.'
                        : 'Payment is completed with PayMongo. GCash and QR Ph purchases grant a fixed term and must be renewed manually; eligible card subscriptions may auto-renew.',
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
