import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationButton extends StatefulWidget {
  const CurrentLocationButton({
    required this.label,
    required this.loadingLabel,
    required this.onLocation,
    super.key,
  });

  final String label;
  final String loadingLabel;
  final ValueChanged<Position> onLocation;

  @override
  State<CurrentLocationButton> createState() => _CurrentLocationButtonState();
}

class _CurrentLocationButtonState extends State<CurrentLocationButton> {
  bool _locating = false;

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationFailure(
          'common.farmerApplication.locationDisabled',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationFailure(
          'common.farmerApplication.locationPermission',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );
      if (mounted) widget.onLocation(position);
    } on _LocationFailure catch (error) {
      _showError(error.translationKey.tr());
    } catch (error, stackTrace) {
      debugPrint('Could not read customer location: $error\n$stackTrace');
      _showError('common.farmerApplication.locationFailed'.tr());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _locating ? null : _getLocation,
        icon: _locating
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
        label: Text(_locating ? widget.loadingLabel : widget.label),
      );
}

class _LocationFailure implements Exception {
  const _LocationFailure(this.translationKey);

  final String translationKey;
}

String addressWithGpsCoordinates(
    String address, double latitude, double longitude) {
  final withoutOldCoordinates = address
      .trim()
      .replaceFirst(
        RegExp(r'(?:\r?\n)?GPS: -?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?\s*$'),
        '',
      )
      .trim();
  final coordinates =
      'GPS: ${latitude.toStringAsFixed(7)}, ${longitude.toStringAsFixed(7)}';
  return withoutOldCoordinates.isEmpty
      ? coordinates
      : '$withoutOldCoordinates\n$coordinates';
}
