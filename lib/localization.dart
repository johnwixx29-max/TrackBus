import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight app-wide localization (English, Kannada, Marathi).
class AppLang extends ChangeNotifier {
  AppLang._();
  static final AppLang instance = AppLang._();

  static const prefKey = 'trackbus_language';
  String _code = 'en';

  String get code => _code;
  static String get currentCode => instance._code;
  bool get isInitialized => _initialized;
  bool _initialized = false;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    instance._code = prefs.getString(prefKey) ?? 'en';
    instance._initialized = true;
  }

  static bool get hasSelectedLanguage {
    // Sync check — call after init or read prefs in splash.
    return instance._initialized && instance._code.isNotEmpty;
  }

  Future<void> setLocale(String code) async {
    if (_code == code) return;
    _code = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, code);
    notifyListeners();
  }

  static String t(String key) =>
      _strings[instance._code]?[key] ?? _strings['en']?[key] ?? key;

  static const _strings = <String, Map<String, String>>{
    'en': {
      'home': 'Home',
      'profile': 'Profile',
      'cbt': 'CBT',
      'your_location': 'Your Location',
      'cbt_belagavi': 'CBT, Belagavi, Karnataka',
      'where_go': 'Where do you want to go?',
      'popular_places': 'Popular Places',
      'saved_routes': 'Saved Routes',
      'view_all': 'View All',
      'from': 'From',
      'to': 'To',
      'from_hint': 'From — where are you?',
      'to_hint': 'To — where do you want to go?',
      'no_buses_found': 'No buses found',
      'try_different': 'Try different stops',
      'choose_language': 'Choose your language',
      'select_language': 'Continue',
      'lang_en': 'English',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_mr': 'मराठी (Marathi)',
      'cbt_terminal': 'CBT Belagavi',
      'central_terminal': 'Central Bus Terminal',
      'buses': 'Buses',
      'track': 'Track',
      'arriving': 'Arriving',
      'soon': 'Soon',
      'min': 'min',
      'cbt_bus_stand': 'CBT Bus Stand',
      'cbt_subtitle': 'Central Bus Terminal, Belagavi',
      'no_saved_routes': 'No saved routes yet',
      'save_routes_hint': 'Travel on a bus to save routes here',
      'select_destination': 'Select destination',
      'buses_to': 'Buses to',
      'via_route': 'Via route',
      'good_morning': 'Good Morning',
      'good_afternoon': 'Good Afternoon',
      'good_evening': 'Good Evening',
      'splash_subtitle': 'Belagavi Rural Bus Tracker',
      'find_my_bus': 'Find My Bus',
      'suggested_places': 'Suggested places',
      'no_buses_to_place': 'No buses found for this place',
      'see_buses': 'See buses',
      'language': 'Language',
      'language_sub': 'English, Kannada, or Marathi',
    },
    'kn': {
      'home': 'ಮುಖಪುಟ',
      'profile': 'ಪ್ರೊಫೈಲ್',
      'cbt': 'CBT',
      'your_location': 'ನಿಮ್ಮ ಸ್ಥಳ',
      'cbt_belagavi': 'CBT, ಬೆಳಗಾವಿ, ಕರ್ನಾಟಕ',
      'where_go': 'ನೀವು ಎಲ್ಲಿಗೆ ಹೋಗಬೇಕು?',
      'popular_places': 'ಜನಪ್ರಿಯ ಸ್ಥಳಗಳು',
      'saved_routes': 'ಉಳಿಸಿದ ಮಾರ್ಗಗಳು',
      'view_all': 'ಎಲ್ಲಾ ನೋಡಿ',
      'from': 'ಇಂದ',
      'to': 'ಗೆ',
      'from_hint': 'ಇಂದ — ನೀವು ಎಲ್ಲಿದ್ದೀರಿ?',
      'to_hint': 'ಗೆ — ಎಲ್ಲಿಗೆ ಹೋಗಬೇಕು?',
      'no_buses_found': 'ಯಾವುದೇ ಬಸ್ಸುಗಳು ಕಂಡುಬಂದಿಲ್ಲ',
      'try_different': 'ಬೇರೆ ನಿಲ್ದಾಣಗಳನ್ನು ಪ್ರಯತ್ನಿಸಿ',
      'choose_language': 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ',
      'select_language': 'ಮುಂದುವರಿಸಿ',
      'lang_en': 'English',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_mr': 'मराठी (Marathi)',
      'cbt_terminal': 'CBT ಬೆಳಗಾವಿ',
      'central_terminal': 'ಕೇಂದ್ರ ಬಸ್ ನಿಲ್ದಾಣ',
      'buses': 'ಬಸ್ಸುಗಳು',
      'track': 'ಟ್ರ್ಯಾಕ್',
      'arriving': 'ಬರುತ್ತಿದೆ',
      'soon': 'ಶೀಘ್ರ',
      'min': 'ನಿಮಿಷ',
      'cbt_bus_stand': 'CBT ಬಸ್ ನಿಲ್ದಾಣ',
      'cbt_subtitle': 'ಕೇಂದ್ರ ಬಸ್ ನಿಲ್ದಾಣ, ಬೆಳಗಾವಿ',
      'no_saved_routes': 'ಇನ್ನೂ ಉಳಿಸಿದ ಮಾರ್ಗಗಳಿಲ್ಲ',
      'save_routes_hint': 'ಮಾರ್ಗಗಳನ್ನು ಉಳಿಸಲು ಬಸ್ಸಿನಲ್ಲಿ ಪ್ರಯಾಣಿಸಿ',
      'select_destination': 'ಗಮ್ಯಸ್ಥಾನ ಆಯ್ಕೆಮಾಡಿ',
      'buses_to': 'ಬಸ್ಸುಗಳು',
      'via_route': 'ಮಾರ್ಗದ ಮೂಲಕ',
      'good_morning': 'ಶುಭೋದಯ',
      'good_afternoon': 'ಶುಭ ಮಧ್ಯಾಹ್ನ',
      'good_evening': 'ಶುಭ ಸಂಜೆ',
      'splash_subtitle': 'ಬೆಳಗಾವಿ ಗ್ರಾಮೀಣ ಬಸ್ ಟ್ರ್ಯಾಕರ್',
      'find_my_bus': 'ನನ್ನ ಬಸ್ ಹುಡುಕಿ',
      'suggested_places': 'ಸೂಚಿಸಿದ ಸ್ಥಳಗಳು',
      'no_buses_to_place': 'ಈ ಸ್ಥಳಕ್ಕೆ ಬಸ್ಸುಗಳು ಕಂಡುಬಂದಿಲ್ಲ',
      'see_buses': 'ಬಸ್ಸುಗಳನ್ನು ನೋಡಿ',
      'language': 'ಭಾಷೆ',
      'language_sub': 'ಇಂಗ್ಲಿಷ್, ಕನ್ನಡ ಅಥವಾ ಮರಾಠಿ',
    },
    'mr': {
      'home': 'मुख्यपृष्ठ',
      'profile': 'प्रोफाइल',
      'cbt': 'CBT',
      'your_location': 'तुमचे स्थान',
      'cbt_belagavi': 'CBT, बेळगाव, कर्नाटक',
      'where_go': 'तुम्हाला कुठे जायचे आहे?',
      'popular_places': 'लोकप्रिय ठिकाणे',
      'saved_routes': 'जतन केलेले मार्ग',
      'view_all': 'सर्व पहा',
      'from': 'पासून',
      'to': 'पर्यंत',
      'from_hint': 'पासून — तुम्ही कुठे आहात?',
      'to_hint': 'पर्यंत — कुठे जायचे आहे?',
      'no_buses_found': 'कोणतीही बस सापडली नाही',
      'try_different': 'वेगळे थांबे वापरून पहा',
      'choose_language': 'तुमची भाषा निवडा',
      'select_language': 'पुढे जा',
      'lang_en': 'English',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_mr': 'मराठी (Marathi)',
      'cbt_terminal': 'CBT बेळगाव',
      'central_terminal': 'केंद्रीय बस टर्मिनल',
      'buses': 'बसेस',
      'track': 'ट्रॅक',
      'arriving': 'येत आहे',
      'soon': 'लवकरच',
      'min': 'मिनि',
      'cbt_bus_stand': 'CBT बस स्टँड',
      'cbt_subtitle': 'केंद्रीय बस टर्मिनल, बेळगाव',
      'no_saved_routes': 'अजून जतन केलेले मार्ग नाहीत',
      'save_routes_hint': 'मार्ग जतन करण्यासाठी बसमध्ये प्रवास करा',
      'select_destination': 'गंतव्य निवडा',
      'buses_to': 'बसेस',
      'via_route': 'मार्गाने',
      'good_morning': 'शुभ प्रभात',
      'good_afternoon': 'शुभ दुपार',
      'good_evening': 'शुभ संध्याकाळ',
      'splash_subtitle': 'बेळगाव ग्रामीण बस ट्रॅकर',
      'find_my_bus': 'माझी बस शोधा',
      'suggested_places': 'सुचवलेली ठिकाणे',
      'no_buses_to_place': 'या ठिकाणासाठी बस सापडली नाही',
      'see_buses': 'बसेस पहा',
      'language': 'भाषा',
      'language_sub': 'इंग्रजी, कन्नड किंवा मराठी',
    },
  };
}
