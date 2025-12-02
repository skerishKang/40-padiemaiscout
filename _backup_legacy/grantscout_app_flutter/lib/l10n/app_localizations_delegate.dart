import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_localizations.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => 
        supportedLocale.languageCode == locale.languageCode &&
        supportedLocale.countryCode == locale.countryCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(_getLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;

  AppLocalizations _getLocalizations(Locale locale) {
    switch (locale.languageCode) {
      case 'ko':
        return AppLocalizationsKo();
      case 'en':
      default:
        return AppLocalizationsEn();
    }
  }
}

// 편의 메서드를 위한 확장
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}