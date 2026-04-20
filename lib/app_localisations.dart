

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _currentCode = 'en';

class AppLocalizations {
  AppLocalizations._();

  /// Listen to this to rebuild when language changes
  static final ValueNotifier<String> notifier = ValueNotifier<String>('en');

  /// Call once in main() before runApp
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'en';
    _currentCode = _translations.containsKey(saved) ? saved : 'en';
    notifier.value = _currentCode;
  }

  /// Save new language + notifies all listeners → triggers rebuilds
  static Future<void> setLanguage(String code) async {
    if (!_translations.containsKey(code)) return;
    _currentCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    notifier.value = code; // ← this triggers ValueListenableBuilder rebuilds
  }

  static String get currentCode => _currentCode;

  static AppLocalizations get instance => AppLocalizations._();

  String _t(String key) =>
      _translations[_currentCode]?[key] ?? _translations['en']?[key] ?? key;

  // ── Language Selection ──────────────────────────────────────────────────
  String get chooseLanguage         => _t('chooseLanguage');
  String get chooseLanguageSubtitle => _t('chooseLanguageSubtitle');
  String get selectALanguage        => _t('selectALanguage');
  String get skipForNow             => _t('skipForNow');
  String get pleaseSelectLanguage   => _t('pleaseSelectLanguage');
  String get failedToSaveLanguage   => _t('failedToSaveLanguage');
  String continueWithLang(String name) => '${_t('continueWith')} $name';
  String languageSelectedMsg(String name) => '$name ${_t('languageSelected')}';

  // ── Login ───────────────────────────────────────────────────────────────
  String get welcomeBack          => _t('welcomeBack');
  String get signInToYourAccount  => _t('signInToYourAccount');
  String get mobileNumber         => _t('mobileNumber');
  String get enterNumber          => _t('enterNumber');
  String get password             => _t('password');
  String get enterPassword        => _t('enterPassword');
  String get forgotPassword       => _t('forgotPassword');
  String get login                => _t('login');
  String get sendOtp              => _t('sendOtp');
  String get or                   => _t('or');
  String get continueWithGoogle   => _t('continueWithGoogle');
  String get dontHaveAccount      => _t('dontHaveAccount');
  String get signUp               => _t('signUp');
  String get changeLanguage       => _t('changeLanguage');
  String get passwordTab          => _t('passwordTab');
  String get otpTab               => _t('otpTab');
  String get numberTooShort       => _t('numberTooShort');
  String get numberTooLong        => _t('numberTooLong');
  String get enterMobileNumber    => _t('enterMobileNumber');
  String get enterYourPassword    => _t('enterYourPassword');
  String get googleSignInFailed   => _t('googleSignInFailed');
  String get signingYouIn         => _t('signingYouIn');
  String get verifyingGoogle      => _t('verifyingGoogle');
  String get securingSession      => _t('securingSession');
  String otpSentToMsg(String mobile) => '${_t('otpSentTo')} $mobile';
}

const Map<String, Map<String, String>> _translations = {
  'en': {
    'chooseLanguage':         'Choose your language',
    'chooseLanguageSubtitle': 'Select the language you\'re most comfortable with',
    'continueWith':           'Continue with',
    'selectALanguage':        'Select a language',
    'skipForNow':             'Skip for now',
    'languageSelected':       'selected ✓',
    'pleaseSelectLanguage':   'Please select a language to continue',
    'failedToSaveLanguage':   'Failed to save language',
    'welcomeBack':            'Welcome back',
    'signInToYourAccount':    'Sign in to your account',
    'mobileNumber':           'Mobile Number',
    'enterNumber':            'Enter number',
    'password':               'Password',
    'enterPassword':          'Enter password',
    'forgotPassword':         'Forgot password?',
    'login':                  'Login',
    'sendOtp':                'Send OTP',
    'or':                     'or',
    'continueWithGoogle':     'Continue with Google',
    'dontHaveAccount':        'Don\'t have an account? ',
    'signUp':                 'Sign Up',
    'changeLanguage':         'Change Language',
    'passwordTab':            'Password',
    'otpTab':                 'OTP',
    'numberTooShort':         'Number too short',
    'numberTooLong':          'Number too long',
    'enterMobileNumber':      'Enter mobile number',
    'enterYourPassword':      'Enter your password',
    'otpSentTo':              'OTP sent to',
    'googleSignInFailed':     'Google Sign-In failed.',
    'signingYouIn':           'Signing you in',
    'verifyingGoogle':        'Verifying your Google account,\nplease wait...',
    'securingSession':        'Securing your session...',
  },
  'te': {
    'chooseLanguage':         'మీ భాష ఎంచుకోండి',
    'chooseLanguageSubtitle': 'మీకు అత్యంత సౌకర్యవంతమైన భాషను ఎంచుకోండి',
    'continueWith':           'కొనసాగించు',
    'selectALanguage':        'భాషను ఎంచుకోండి',
    'skipForNow':             'ఇప్పటికి దాటవేయి',
    'languageSelected':       'ఎంచుకోబడింది ✓',
    'pleaseSelectLanguage':   'కొనసాగించడానికి భాషను ఎంచుకోండి',
    'failedToSaveLanguage':   'భాషను సేవ్ చేయడం విఫలమైంది',
    'welcomeBack':            'తిరిగి స్వాగతం',
    'signInToYourAccount':    'మీ ఖాతాలోకి సైన్ ఇన్ చేయండి',
    'mobileNumber':           'మొబైల్ నంబర్',
    'enterNumber':            'నంబర్ నమోదు చేయండి',
    'password':               'పాస్‌వర్డ్',
    'enterPassword':          'పాస్‌వర్డ్ నమోదు చేయండి',
    'forgotPassword':         'పాస్‌వర్డ్ మర్చిపోయారా?',
    'login':                  'లాగిన్',
    'sendOtp':                'OTP పంపండి',
    'or':                     'లేదా',
    'continueWithGoogle':     'Google తో కొనసాగించు',
    'dontHaveAccount':        'ఖాతా లేదా? ',
    'signUp':                 'సైన్ అప్',
    'changeLanguage':         'భాష మార్చండి',
    'passwordTab':            'పాస్‌వర్డ్',
    'otpTab':                 'OTP',
    'numberTooShort':         'నంబర్ చాలా చిన్నది',
    'numberTooLong':          'నంబర్ చాలా పొడవుగా ఉంది',
    'enterMobileNumber':      'మొబైల్ నంబర్ నమోదు చేయండి',
    'enterYourPassword':      'మీ పాస్‌వర్డ్ నమోదు చేయండి',
    'otpSentTo':              'కు OTP పంపబడింది',
    'googleSignInFailed':     'Google సైన్-ఇన్ విఫలమైంది.',
    'signingYouIn':           'లాగిన్ అవుతున్నారు',
    'verifyingGoogle':        'మీ Google ఖాతాను ధృవీకరిస్తున్నాం,\nదయచేసి వేచి ఉండండి...',
    'securingSession':        'సెషన్ సురక్షితం చేస్తున్నాం...',
  },
  'hi': {
    'chooseLanguage':         'अपनी भाषा चुनें',
    'chooseLanguageSubtitle': 'वह भाषा चुनें जिसमें आप सबसे ज़्यादा सहज हों',
    'continueWith':           'के साथ जारी रखें',
    'selectALanguage':        'एक भाषा चुनें',
    'skipForNow':             'अभी के लिए छोड़ें',
    'languageSelected':       'चुना गया ✓',
    'pleaseSelectLanguage':   'जारी रखने के लिए भाषा चुनें',
    'failedToSaveLanguage':   'भाषा सहेजने में विफल रहा',
    'welcomeBack':            'वापस स्वागत है',
    'signInToYourAccount':    'अपने खाते में साइन इन करें',
    'mobileNumber':           'मोबाइल नंबर',
    'enterNumber':            'नंबर दर्ज करें',
    'password':               'पासवर्ड',
    'enterPassword':          'पासवर्ड दर्ज करें',
    'forgotPassword':         'पासवर्ड भूल गए?',
    'login':                  'लॉगिन',
    'sendOtp':                'OTP भेजें',
    'or':                     'या',
    'continueWithGoogle':     'Google के साथ जारी रखें',
    'dontHaveAccount':        'खाता नहीं है? ',
    'signUp':                 'साइन अप',
    'changeLanguage':         'भाषा बदलें',
    'passwordTab':            'पासवर्ड',
    'otpTab':                 'OTP',
    'numberTooShort':         'नंबर बहुत छोटा है',
    'numberTooLong':          'नंबर बहुत लंबा है',
    'enterMobileNumber':      'मोबाइल नंबर दर्ज करें',
    'enterYourPassword':      'अपना पासवर्ड दर्ज करें',
    'otpSentTo':              'को OTP भेजा गया',
    'googleSignInFailed':     'Google साइन-इन विफल रहा।',
    'signingYouIn':           'साइन इन हो रहे हैं',
    'verifyingGoogle':        'आपका Google खाता सत्यापित हो रहा है,\nकृपया प्रतीक्षा करें...',
    'securingSession':        'सत्र सुरक्षित किया जा रहा है...',
  },
  'ta': {
    'chooseLanguage':         'உங்கள் மொழியை தேர்ந்தெடுக்கவும்',
    'chooseLanguageSubtitle': 'நீங்கள் மிகவும் வசதியான மொழியை தேர்ந்தெடுக்கவும்',
    'continueWith':           'தொடர',
    'selectALanguage':        'ஒரு மொழியை தேர்ந்தெடுக்கவும்',
    'skipForNow':             'இப்போது தவிர்',
    'languageSelected':       'தேர்ந்தெடுக்கப்பட்டது ✓',
    'pleaseSelectLanguage':   'தொடர மொழியை தேர்ந்தெடுக்கவும்',
    'failedToSaveLanguage':   'மொழியை சேமிக்க முடியவில்லை',
    'welcomeBack':            'மீண்டும் வரவேற்கிறோம்',
    'signInToYourAccount':    'உங்கள் கணக்கில் உள்நுழையவும்',
    'mobileNumber':           'மொபைல் எண்',
    'enterNumber':            'எண்ணை உள்ளிடவும்',
    'password':               'கடவுச்சொல்',
    'enterPassword':          'கடவுச்சொல்லை உள்ளிடவும்',
    'forgotPassword':         'கடவுச்சொல் மறந்தீர்களா?',
    'login':                  'உள்நுழைய',
    'sendOtp':                'OTP அனுப்பு',
    'or':                     'அல்லது',
    'continueWithGoogle':     'Google உடன் தொடர',
    'dontHaveAccount':        'கணக்கு இல்லையா? ',
    'signUp':                 'பதிவு செய்',
    'changeLanguage':         'மொழியை மாற்று',
    'passwordTab':            'கடவுச்சொல்',
    'otpTab':                 'OTP',
    'numberTooShort':         'எண் மிகவும் குறுகியது',
    'numberTooLong':          'எண் மிகவும் நீளமானது',
    'enterMobileNumber':      'மொபைல் எண்ணை உள்ளிடவும்',
    'enterYourPassword':      'உங்கள் கடவுச்சொல்லை உள்ளிடவும்',
    'otpSentTo':              'க்கு OTP அனுப்பப்பட்டது',
    'googleSignInFailed':     'Google உள்நுழைவு தோல்வியடைந்தது.',
    'signingYouIn':           'உள்நுழைகிறோம்',
    'verifyingGoogle':        'உங்கள் Google கணக்கை சரிபார்க்கிறோம்,\nதயவுசெய்து காத்திருக்கவும்...',
    'securingSession':        'அமர்வை பாதுகாக்கிறோம்...',
  },
  'kn': {
    'chooseLanguage':         'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆರಿಸಿ',
    'chooseLanguageSubtitle': 'ನಿಮಗೆ ಅತ್ಯಂತ ಆರಾಮದಾಯಕ ಭಾಷೆಯನ್ನು ಆರಿಸಿ',
    'continueWith':           'ಮುಂದುವರಿಯಿರಿ',
    'selectALanguage':        'ಭಾಷೆಯನ್ನು ಆರಿಸಿ',
    'skipForNow':             'ಈಗ ಬಿಟ್ಟುಬಿಡಿ',
    'languageSelected':       'ಆಯ್ಕೆಯಾಗಿದೆ ✓',
    'pleaseSelectLanguage':   'ಮುಂದುವರಿಯಲು ಭಾಷೆ ಆರಿಸಿ',
    'failedToSaveLanguage':   'ಭಾಷೆಯನ್ನು ಉಳಿಸಲು ವಿಫಲವಾಗಿದೆ',
    'welcomeBack':            'ಮರಳಿ ಸ್ವಾಗತ',
    'signInToYourAccount':    'ನಿಮ್ಮ ಖಾತೆಗೆ ಸೈನ್ ಇನ್ ಮಾಡಿ',
    'mobileNumber':           'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
    'enterNumber':            'ಸಂಖ್ಯೆ ನಮೂದಿಸಿ',
    'password':               'ಪಾಸ್‌ವರ್ಡ್',
    'enterPassword':          'ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ',
    'forgotPassword':         'ಪಾಸ್‌ವರ್ಡ್ ಮರೆತಿದ್ದೀರಾ?',
    'login':                  'ಲಾಗಿನ್',
    'sendOtp':                'OTP ಕಳುಹಿಸಿ',
    'or':                     'ಅಥವಾ',
    'continueWithGoogle':     'Google ನೊಂದಿಗೆ ಮುಂದುವರಿಯಿರಿ',
    'dontHaveAccount':        'ಖಾತೆ ಇಲ್ಲವೇ? ',
    'signUp':                 'ಸೈನ್ ಅಪ್',
    'changeLanguage':         'ಭಾಷೆ ಬದಲಿಸಿ',
    'passwordTab':            'ಪಾಸ್‌ವರ್ಡ್',
    'otpTab':                 'OTP',
    'numberTooShort':         'ಸಂಖ್ಯೆ ತುಂಬಾ ಚಿಕ್ಕದು',
    'numberTooLong':          'ಸಂಖ್ಯೆ ತುಂಬಾ ಉದ್ದವಾಗಿದೆ',
    'enterMobileNumber':      'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ನಮೂದಿಸಿ',
    'enterYourPassword':      'ನಿಮ್ಮ ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ',
    'otpSentTo':              'ಗೆ OTP ಕಳುಹಿಸಲಾಗಿದೆ',
    'googleSignInFailed':     'Google ಸೈನ್-ಇನ್ ವಿಫಲವಾಗಿದೆ.',
    'signingYouIn':           'ಸೈನ್ ಇನ್ ಆಗುತ್ತಿದ್ದೇವೆ',
    'verifyingGoogle':        'ನಿಮ್ಮ Google ಖಾತೆಯನ್ನು ಪರಿಶೀಲಿಸುತ್ತಿದ್ದೇವೆ,\nದಯವಿಟ್ಟು ನಿರೀಕ್ಷಿಸಿ...',
    'securingSession':        'ಸೆಶನ್ ಸುರಕ್ಷಿತಗೊಳಿಸುತ್ತಿದ್ದೇವೆ...',
  },
  'ml': {
    'chooseLanguage':         'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക',
    'chooseLanguageSubtitle': 'നിങ്ങൾക്ക് ഏറ്റവും സൗകര്യമുള്ള ഭാഷ തിരഞ്ഞെടുക്കുക',
    'continueWith':           'തുടരുക',
    'selectALanguage':        'ഒരു ഭാഷ തിരഞ്ഞെടുക്കുക',
    'skipForNow':             'ഇപ്പോൾ ഒഴിവാക്കുക',
    'languageSelected':       'തിരഞ്ഞെടുത്തു ✓',
    'pleaseSelectLanguage':   'തുടരാൻ ഭാഷ തിരഞ്ഞെടുക്കുക',
    'failedToSaveLanguage':   'ഭാഷ സേവ് ചെയ്യുന്നതിൽ പരാജയപ്പെട്ടു',
    'welcomeBack':            'തിരിച്ചു സ്വാഗതം',
    'signInToYourAccount':    'നിങ്ങളുടെ അക്കൗണ്ടിൽ സൈൻ ഇൻ ചെയ്യുക',
    'mobileNumber':           'മൊബൈൽ നമ്പർ',
    'enterNumber':            'നമ്പർ നൽകുക',
    'password':               'പാസ്‌വേഡ്',
    'enterPassword':          'പാസ്‌വേഡ് നൽകുക',
    'forgotPassword':         'പാസ്‌വേഡ് മറന്നോ?',
    'login':                  'ലോഗിൻ',
    'sendOtp':                'OTP അയക്കുക',
    'or':                     'അല്ലെങ്കിൽ',
    'continueWithGoogle':     'Google ഉപയോഗിച്ച് തുടരുക',
    'dontHaveAccount':        'അക്കൗണ്ട് ഇല്ലേ? ',
    'signUp':                 'സൈൻ അപ്',
    'changeLanguage':         'ഭാഷ മാറ്റുക',
    'passwordTab':            'പാസ്‌വേഡ്',
    'otpTab':                 'OTP',
    'numberTooShort':         'നമ്പർ വളരെ കുറഞ്ഞതാണ്',
    'numberTooLong':          'നമ്പർ വളരെ നീളമുള്ളതാണ്',
    'enterMobileNumber':      'മൊബൈൽ നമ്പർ നൽകുക',
    'enterYourPassword':      'നിങ്ങളുടെ പാസ്‌വേഡ് നൽകുക',
    'otpSentTo':              'ലേക്ക് OTP അയച്ചു',
    'googleSignInFailed':     'Google സൈൻ-ഇൻ പരാജയപ്പെട്ടു.',
    'signingYouIn':           'സൈൻ ഇൻ ചെയ്യുന്നു',
    'verifyingGoogle':        'നിങ്ങളുടെ Google അക്കൗണ്ട് പരിശോധിക്കുന്നു,\nദയവായി കാത്തിരിക്കുക...',
    'securingSession':        'സെഷൻ സുരക്ഷിതമാക്കുന്നു...',
  },
};