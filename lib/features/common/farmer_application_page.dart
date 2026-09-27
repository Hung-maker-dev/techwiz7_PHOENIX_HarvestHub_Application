import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/user_role_provider.dart';
import '../../models/farmer_application.dart';
import '../../providers/farmer_application_provider.dart';
import '../../shared_widgets/app_button.dart';

class FarmerApplicationPage extends ConsumerStatefulWidget {
  const FarmerApplicationPage({super.key});

  @override
  ConsumerState<FarmerApplicationPage> createState() =>
      _FarmerApplicationPageState();
}

class _FarmerApplicationPageState extends ConsumerState<FarmerApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _farmName = TextEditingController();
  final _address = TextEditingController();
  final _contactPhone = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  String? _marketId;
  bool _submitting = false;
  bool _locating = false;
  bool _gpsCapturedThisSession = false;
  String? _loadedUid;

  @override
  void dispose() {
    _farmName.dispose();
    _address.dispose();
    _contactPhone.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _loadApplication(FarmerApplication? application) {
    if (application == null || _loadedUid == application.farmName) return;
    _loadedUid = application.farmName;
    _farmName.text = application.farmName;
    _marketId = application.marketId;
    _address.text = application.address ?? '';
    _contactPhone.text = application.contactPhone ?? '';
    _description.text = application.description ?? '';
    _latitude.clear();
    _longitude.clear();
    _gpsCapturedThisSession = false;
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _gpsCapturedThisSession = false;
      _latitude.clear();
      _longitude.clear();
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationFailure(
            'common.farmerApplication.locationDisabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationFailure(
            'common.farmerApplication.locationPermission');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(7);
        _longitude.text = position.longitude.toStringAsFixed(7);
        _gpsCapturedThisSession = true;
      });
    } on _LocationFailure catch (error) {
      _showMessage(error.message.tr());
    } catch (error, stackTrace) {
      debugPrint('Could not read farmer location: $error\n$stackTrace');
      _showMessage('common.farmerApplication.locationFailed'.tr());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_marketId == null) {
      _showMessage('common.farmerApplication.selectMarket'.tr());
      return;
    }

    final phone = _contactPhone.text.trim();
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\+?[0-9().\-\s]{7,30}$').hasMatch(phone) ||
        phoneDigits.length < 7 ||
        phoneDigits.length > 15) {
      _showMessage('common.farmerApplication.invalidPhone'.tr());
      return;
    }

    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (!_gpsCapturedThisSession || latitude == null || longitude == null) {
      _showMessage('common.farmerApplication.gpsRequiredError'.tr());
      return;
    }
    if (latitude < -90 || latitude > 90) {
      _showMessage('common.farmerApplication.invalidLatitude'.tr());
      return;
    }
    if (longitude < -180 || longitude > 180) {
      _showMessage('common.farmerApplication.invalidLongitude'.tr());
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(farmerApplicationApiProvider).submitApplication(
            farmName: _farmName.text.trim(),
            marketId: _marketId!,
            address: _address.text.trim(),
            contactPhone: phone,
            description: _description.text.trim(),
            latitude: latitude,
            longitude: longitude,
          );
      ref.invalidate(myFarmerApplicationProvider);
    } catch (error, stackTrace) {
      debugPrint('Farmer application submission failed: $error\n$stackTrace');
      _showMessage('common.farmerApplication.submitFailed'.tr());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final application = ref.watch(myFarmerApplicationProvider);
    final markets = ref.watch(farmerMarketsProvider);

    return role.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _errorScaffold(context),
      data: (value) {
        if (value == 'admin') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/admin');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: Text('common.farmerApplication.title'.tr())),
          body: application.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _retryState(
              context,
              'common.farmerApplication.statusFailed'.tr(),
              () => ref.invalidate(myFarmerApplicationProvider),
            ),
            data: (current) {
              _loadApplication(current);
              if (current?.status == 'approved' || value == 'farmer') {
                return _statusPage(
                  context,
                  application: current,
                  approved: true,
                );
              }
              if (current?.status == 'pending') {
                return _statusPage(
                  context,
                  application: current,
                  approved: false,
                );
              }
              return markets.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _retryState(
                  context,
                  'common.farmerApplication.marketsFailed'.tr(),
                  () => ref.invalidate(farmerMarketsProvider),
                ),
                data: (items) => _applicationForm(context, items, current),
              );
            },
          ),
        );
      },
    );
  }

  Widget _applicationForm(
    BuildContext context,
    List<FarmerMarketOption> markets,
    FarmerApplication? previous,
  ) {
    final selectedMarketExists =
        markets.any((market) => market.id == _marketId);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('common.farmerApplication.intro'.tr()),
          const SizedBox(height: 20),
          TextFormField(
            controller: _farmName,
            maxLength: 200,
            decoration: InputDecoration(
                labelText: 'common.farmerApplication.farmName'.tr()),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'common.farmerApplication.required'.tr()
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedMarketExists ? _marketId : null,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: 'common.farmerApplication.market'.tr()),
            items: [
              for (final market in markets)
                DropdownMenuItem(
                  value: market.id,
                  child: Text(
                    market.address?.isNotEmpty == true
                        ? '${market.name} — ${market.address}'
                        : market.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _marketId = value),
            validator: (value) => value == null
                ? 'common.farmerApplication.selectMarket'.tr()
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'common.farmerApplication.address'.tr(),
              helperText: 'common.farmerApplication.addressHint'.tr(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'common.farmerApplication.required'.tr()
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactPhone,
            keyboardType: TextInputType.phone,
            maxLength: 30,
            decoration: InputDecoration(
              labelText: 'common.farmerApplication.contactPhone'.tr(),
              helperText: 'common.farmerApplication.phoneHint'.tr(),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final phone = value?.trim() ?? '';
              final digits = phone.replaceAll(RegExp(r'\D'), '');
              if (phone.isEmpty) {
                return 'common.farmerApplication.required'.tr();
              }
              return RegExp(r'^\+?[0-9().\-\s]{7,30}$').hasMatch(phone) &&
                      digits.length >= 7 &&
                      digits.length <= 15
                  ? null
                  : 'common.farmerApplication.invalidPhone'.tr();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: 'common.farmerApplication.description'.tr(),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'common.farmerApplication.gpsRequired'.tr(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('common.farmerApplication.gpsInstruction'.tr()),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: _locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      _latitude.text.isNotEmpty
                          ? 'common.farmerApplication.refreshLocation'.tr()
                          : 'common.farmerApplication.useLocation'.tr(),
                    ),
                  ),
                  if (_latitude.text.isNotEmpty &&
                      _longitude.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'common.farmerApplication.coordinates'.tr(args: [
                              _latitude.text,
                              _longitude.text,
                            ]),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: previous?.status == 'rejected'
                ? 'common.farmerApplication.resubmit'.tr()
                : 'common.farmerApplication.submit'.tr(),
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _statusPage(
    BuildContext context, {
    required FarmerApplication? application,
    required bool approved,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          color: approved ? colors.primaryContainer : colors.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  approved ? Icons.verified_outlined : Icons.hourglass_top,
                  size: 48,
                  color: approved
                      ? colors.onPrimaryContainer
                      : colors.onTertiaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  approved
                      ? 'common.farmerApplication.approvedTitle'.tr()
                      : 'common.farmerApplication.pendingTitle'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  approved
                      ? 'common.farmerApplication.approvedBody'.tr()
                      : 'common.farmerApplication.pendingBody'.tr(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (application != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'common.farmerApplication.submittedDetails'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _detailRow(Icons.storefront_outlined, application.farmName),
                  _detailRow(
                    Icons.store_mall_directory_outlined,
                    application.marketName ??
                        'common.farmerApplication.market'.tr(),
                  ),
                  if (application.marketAddress?.isNotEmpty == true)
                    _detailRow(
                      Icons.place_outlined,
                      application.marketAddress!,
                    ),
                  _detailRow(
                    Icons.place_outlined,
                    application.address?.isNotEmpty == true
                        ? application.address!
                        : 'common.farmerApplication.gpsNotProvided'.tr(),
                  ),
                  if (application.contactPhone?.isNotEmpty == true)
                    _detailRow(Icons.phone_outlined, application.contactPhone!),
                  if (application.latitude != null &&
                      application.longitude != null)
                    _detailRow(
                      Icons.my_location,
                      'common.farmerApplication.coordinates'.tr(args: [
                        application.latitude!.toStringAsFixed(6),
                        application.longitude!.toStringAsFixed(6),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (!approved) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'common.farmerApplication.whatNextTitle'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('common.farmerApplication.whatNextBody'.tr()),
                  const SizedBox(height: 8),
                  _progressStep(
                    context,
                    Icons.check_circle,
                    'common.farmerApplication.pendingStepSubmitted'.tr(),
                    complete: true,
                  ),
                  _progressStep(
                    context,
                    Icons.hourglass_top,
                    'common.farmerApplication.pendingStepReview'.tr(),
                    complete: false,
                  ),
                  _progressStep(
                    context,
                    Icons.lock_open_outlined,
                    'common.farmerApplication.pendingStepDecision'.tr(),
                    complete: false,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/home'),
          child: Text('common.farmerApplication.backHome'.tr()),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String value) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Widget _progressStep(
    BuildContext context,
    IconData icon,
    String label, {
    required bool complete,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: complete
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      );

  Widget _retryState(
      BuildContext context, String message, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text('common.farmerApplication.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _errorScaffold(BuildContext context) => Scaffold(
        body: _retryState(
          context,
          'common.farmerApplication.statusFailed'.tr(),
          () => ref.invalidate(myFarmerApplicationProvider),
        ),
      );
}

class _LocationFailure implements Exception {
  const _LocationFailure(this.message);
  final String message;
}
