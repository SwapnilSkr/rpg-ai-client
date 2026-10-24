/// What the envelope says about this install: app version and device.
///
/// Read once at launch. Everything here is a coarse label (OS version, model
/// name, phone-or-tablet, language); nothing that identifies the person.
library;

import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class TelemetryEnvironment {
  const TelemetryEnvironment({
    required this.appVersion,
    required this.appBuild,
    required this.device,
  });

  final String appVersion;
  final int appBuild;
  final Map<String, Object> device;
}

typedef EnvironmentLoader = Future<TelemetryEnvironment> Function();

final RegExp _modelChars = RegExp(r'[^\w .-]');
final RegExp _localeShape = RegExp(r'^[a-z]{2,3}(-[A-Z]{2})?$');

/// `en` / `en-IN`, or `en` when the platform locale is not in that shape.
String localeLabel(ui.Locale locale) {
  final country = locale.countryCode;
  final label = country == null || country.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}-$country';
  return _localeShape.hasMatch(label) ? label : 'en';
}

/// Phone or tablet by the shortest side in dp (>= 600 is a tablet).
String formFactor(ui.Size physicalSize, double devicePixelRatio) {
  if (devicePixelRatio <= 0) return 'phone';
  final shortest = physicalSize.shortestSide / devicePixelRatio;
  return shortest >= 600 ? 'tablet' : 'phone';
}

Future<TelemetryEnvironment> loadEnvironment() async {
  var version = '0.0.0';
  var build = 0;
  try {
    final info = await PackageInfo.fromPlatform();
    if (RegExp(r'^\d+\.\d+\.\d+$').hasMatch(info.version)) {
      version = info.version;
    }
    build = int.tryParse(info.buildNumber) ?? 0;
  } catch (_) {}

  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  var osVersion = '0';
  var model = 'unknown';
  try {
    final plugin = DeviceInfoPlugin();
    if (ios) {
      final info = await plugin.iosInfo;
      osVersion = info.systemVersion;
      model = info.utsname.machine;
    } else {
      final info = await plugin.androidInfo;
      osVersion = '${info.version.sdkInt}';
      model = info.model;
    }
  } catch (_) {}
  osVersion = osVersion.length > 8 ? osVersion.substring(0, 8) : osVersion;
  model = model.replaceAll(_modelChars, '').trim();
  if (model.isEmpty) model = 'unknown';
  if (model.length > 40) model = model.substring(0, 40);

  final dispatcher = ui.PlatformDispatcher.instance;
  final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
  return TelemetryEnvironment(
    appVersion: version,
    appBuild: build,
    device: {
      'os': ios ? 'ios' : 'android',
      'os_version': osVersion,
      'model': model,
      'form': view == null
          ? 'phone'
          : formFactor(view.physicalSize, view.devicePixelRatio),
      'locale': localeLabel(dispatcher.locale),
    },
  );
}
