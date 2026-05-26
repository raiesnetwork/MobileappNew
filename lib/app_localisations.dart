

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
  // ── OTP Screen ──────────────────────────────────────────────────────────
  String get verifyYourNumber  => _t('verifyYourNumber');
  String get codeSentTo        => _t('codeSentTo');
  String get enter6DigitCode   => _t('enter6DigitCode');
  String get verifyAndSignIn   => _t('verifyAndSignIn');
  String get resendCode        => _t('resendCode');
  String get didntGetCode      => _t('didntGetCode');
  String get invalidOtp        => _t('invalidOtp');
  String get otpResentSuccess  => _t('otpResentSuccess');
  // ── Signup Screen ────────────────────────────────────────────────────────
  String get createAccount          => _t('createAccount');
  String get joinIxes               => _t('joinIxes');
  String get mobileNumberLabel      => _t('mobileNumberLabel');
  String get usernameLabel          => _t('usernameLabel');
  String get usernamePlaceholder    => _t('usernamePlaceholder');
  String get enterUsernameError     => _t('enterUsernameError');
  String get usernameMinLength      => _t('usernameMinLength');
  String get passwordLabel          => _t('passwordLabel');
  String get passwordMinChars       => _t('passwordMinChars');
  String get enterPasswordError     => _t('enterPasswordError');
  String get passwordMinLength      => _t('passwordMinLength');
  String get confirmPasswordLabel   => _t('confirmPasswordLabel');
  String get reenterPassword        => _t('reenterPassword');
  String get confirmPasswordError   => _t('confirmPasswordError');
  String get passwordsNotMatch      => _t('passwordsNotMatch');
  String get termsTitle             => _t('termsTitle');
  String get termsSubtitle          => _t('termsSubtitle');
  String get agreeToTermsError      => _t('agreeToTermsError');
  String get createAccountBtn       => _t('createAccountBtn');
  String get alreadyHaveAccount     => _t('alreadyHaveAccount');
  String get signIn                 => _t('signIn');
  String get enterMobileNumberHint  => _t('enterMobileNumberHint');
  String get enterValidNumber       => _t('enterValidNumber');
  String get signUpFailed           => _t('signUpFailed');
  // ── Announcements ────────────────────────────────────────────────────────────
  String get announcements          => _t('announcements');
  String get newAnnouncement        => _t('newAnnouncement');
  String get searchAnnouncements    => _t('searchAnnouncements');
  String get deleteAnnouncement     => _t('deleteAnnouncement');
  String get deleteAnnouncementMsg  => _t('deleteAnnouncementMsg');
  String get cancel                 => _t('cancel');
  String get delete                 => _t('delete');
  String get couldntLoad            => _t('couldntLoad');
  String get retry                  => _t('retry');
  String get noAnnouncementsYet     => _t('noAnnouncementsYet');
  String get checkBackLater         => _t('checkBackLater');
  String get clearSearch            => _t('clearSearch');
  String get posted                 => _t('posted');
  String get editAnnouncement       => _t('editAnnouncement');
  String get createAnnouncement     => _t('createAnnouncement');
  String get updateAnnouncement     => _t('updateAnnouncement');
  String get fillAllFields          => _t('fillAllFields');
  String get endDateBeforeStart     => _t('endDateBeforeStart');
  String get endTimeBeforeStart     => _t('endTimeBeforeStart');
  String get basicInfo              => _t('basicInfo');
  String get schedule               => _t('schedule');
  String get details                => _t('details');
  String get titleLabel             => _t('titleLabel');
  String get descriptionLabel       => _t('descriptionLabel');
  String get categoryLabel          => _t('categoryLabel');
  String get startDate              => _t('startDate');
  String get endDate                => _t('endDate');
  String get startTime              => _t('startTime');
  String get endTime                => _t('endTime');
  String get locationLabel          => _t('locationLabel');
  String get contactInfo            => _t('contactInfo');
  String get titleRequired          => _t('titleRequired');
  String get descriptionRequired    => _t('descriptionRequired');
  String get categoryRequired       => _t('categoryRequired');
  String get invalidDate            => _t('invalidDate');
  String get invalidTime            => _t('invalidTime');
  String get titlePlaceholder       => _t('titlePlaceholder');
  String get descriptionPlaceholder => _t('descriptionPlaceholder');
  String get locationPlaceholder    => _t('locationPlaceholder');
  String get contactPlaceholder     => _t('contactPlaceholder');
  String noResultsFor(String q)     => '${_t('noResultsFor')} "$q"';
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
    'verifyYourNumber': 'Verify your number',
    'codeSentTo':       'Code sent to',
    'enter6DigitCode':  'Enter 6-digit code',
    'verifyAndSignIn':  'Verify & Sign In',
    'resendCode':       'Resend code',
    'didntGetCode':     'Didn\'t get the code? Check your spam or try resend.',
    'invalidOtp':       'Please enter a valid 6-digit OTP',
    'otpResentSuccess': 'OTP resent successfully',
    'createAccount':        'Create account',
    'joinIxes':             'Join iXES and connect with your community',
    'mobileNumberLabel':    'Mobile Number',
    'usernameLabel':        'Username',
    'usernamePlaceholder':  'e.g. john_doe',
    'enterUsernameError':   'Enter a username',
    'usernameMinLength':    'At least 3 characters',
    'passwordLabel':        'Password',
    'passwordMinChars':     'Min. 6 characters',
    'enterPasswordError':   'Enter a password',
    'passwordMinLength':    'At least 6 characters',
    'confirmPasswordLabel': 'Confirm Password',
    'reenterPassword':      'Re-enter your password',
    'confirmPasswordError': 'Confirm your password',
    'passwordsNotMatch':    'Passwords do not match',
    'termsTitle':           'Terms & Conditions',
    'termsSubtitle':        'I agree to the terms and conditions',
    'agreeToTermsError':    'Please agree to the terms and conditions',
    'createAccountBtn':     'Create Account',
    'alreadyHaveAccount':   'Already have an account?  ',
    'signIn':               'Sign In',
    'enterMobileNumberHint':'Enter mobile number',
    'enterValidNumber':     'Enter a valid 10-digit number',
    'signUpFailed':         'Sign up failed. Try again.',
    'announcements':          'Announcements',
    'newAnnouncement':        'New',
    'searchAnnouncements':    'Search announcements…',
    'deleteAnnouncement':     'Delete Announcement',
    'deleteAnnouncementMsg':  'This will permanently remove this announcement.',
    'cancel':                 'Cancel',
    'delete':                 'Delete',
    'couldntLoad':            'Couldn\'t load',
    'retry':                  'Retry',
    'noAnnouncementsYet':     'No announcements yet',
    'checkBackLater':         'Check back later or create one',
    'clearSearch':            'Clear search',
    'posted':                 'Posted',
    'noResultsFor':           'No results for',
    'editAnnouncement':       'Edit Announcement',
    'createAnnouncement':     'Create Announcement',
    'updateAnnouncement':     'Update Announcement',
    'fillAllFields':          'Please fill all required fields',
    'endDateBeforeStart':     'End date cannot be before start date',
    'endTimeBeforeStart':     'End time cannot be before start time on the same date',
    'basicInfo':              'Basic Info',
    'schedule':               'Schedule',
    'details':                'Details',
    'titleLabel':             'Title',
    'descriptionLabel':       'Description',
    'categoryLabel':          'Category',
    'startDate':              'Start Date',
    'endDate':                'End Date',
    'startTime':              'Start Time',
    'endTime':                'End Time',
    'locationLabel':          'Location',
    'contactInfo':            'Contact Info',
    'titleRequired':          'Title is required',
    'descriptionRequired':    'Description is required',
    'categoryRequired':       'Category is required',
    'invalidDate':            'Invalid date',
    'invalidTime':            'Invalid time',
    'titlePlaceholder':       'e.g. Community Meetup',
    'descriptionPlaceholder': 'Describe your announcement…',
    'locationPlaceholder':    'e.g. Community Hall',
    'contactPlaceholder':     'e.g. email or phone number',
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
    'verifyYourNumber': 'మీ నంబర్‌ను ధృవీకరించండి',
    'codeSentTo':       'కోడ్ పంపబడింది',
    'enter6DigitCode':  '6-అంకెల కోడ్ నమోదు చేయండి',
    'verifyAndSignIn':  'ధృవీకరించి సైన్ ఇన్ చేయండి',
    'resendCode':       'కోడ్ మళ్ళీ పంపండి',
    'didntGetCode':     'కోడ్ రాలేదా? స్పామ్ చెక్ చేయండి.',
    'invalidOtp':       'చెల్లుబాటు అయ్యే 6-అంకెల OTP నమోదు చేయండి',
    'otpResentSuccess': 'OTP మళ్ళీ పంపబడింది',
    'createAccount':        'ఖాతా సృష్టించండి',
    'joinIxes':             'iXES లో చేరండి మరియు మీ కమ్యూనిటీతో కనెక్ట్ అవ్వండి',
    'mobileNumberLabel':    'మొబైల్ నంబర్',
    'usernameLabel':        'వినియోగదారు పేరు',
    'usernamePlaceholder':  'ఉదా. john_doe',
    'enterUsernameError':   'వినియోగదారు పేరు నమోదు చేయండి',
    'usernameMinLength':    'కనీసం 3 అక్షరాలు',
    'passwordLabel':        'పాస్‌వర్డ్',
    'passwordMinChars':     'కనీసం 6 అక్షరాలు',
    'enterPasswordError':   'పాస్‌వర్డ్ నమోదు చేయండి',
    'passwordMinLength':    'కనీసం 6 అక్షరాలు',
    'confirmPasswordLabel': 'పాస్‌వర్డ్ నిర్ధారించండి',
    'reenterPassword':      'మీ పాస్‌వర్డ్ మళ్ళీ నమోదు చేయండి',
    'confirmPasswordError': 'మీ పాస్‌వర్డ్ నిర్ధారించండి',
    'passwordsNotMatch':    'పాస్‌వర్డ్‌లు సరిపోలడం లేదు',
    'termsTitle':           'నిబంధనలు & షరతులు',
    'termsSubtitle':        'నేను నిబంధనలు మరియు షరతులకు అంగీకరిస్తున్నాను',
    'agreeToTermsError':    'దయచేసి నిబంధనలకు అంగీకరించండి',
    'createAccountBtn':     'ఖాతా సృష్టించండి',
    'alreadyHaveAccount':   'ఇప్పటికే ఖాతా ఉందా?  ',
    'signIn':               'సైన్ ఇన్',
    'enterMobileNumberHint':'మొబైల్ నంబర్ నమోదు చేయండి',
    'enterValidNumber':     'చెల్లుబాటు అయ్యే 10-అంకెల నంబర్ నమోదు చేయండి',
    'signUpFailed':         'సైన్ అప్ విఫలమైంది. మళ్ళీ ప్రయత్నించండి.',
    'announcements':          'ప్రకటనలు',
    'newAnnouncement':        'కొత్తది',
    'searchAnnouncements':    'ప్రకటనలు వెతకండి…',
    'deleteAnnouncement':     'ప్రకటన తొలగించు',
    'deleteAnnouncementMsg':  'ఇది ఈ ప్రకటనను శాశ్వతంగా తొలగిస్తుంది.',
    'cancel':                 'రద్దు చేయి',
    'delete':                 'తొలగించు',
    'couldntLoad':            'లోడ్ చేయడం సాధ్యం కాలేదు',
    'retry':                  'మళ్ళీ ప్రయత్నించు',
    'noAnnouncementsYet':     'ఇంకా ప్రకటనలు లేవు',
    'checkBackLater':         'తర్వాత చెక్ చేయండి లేదా ఒకటి సృష్టించండి',
    'clearSearch':            'శోధన క్లియర్ చేయి',
    'posted':                 'పోస్ట్ చేయబడింది',
    'noResultsFor':           'కోసం ఫలితాలు లేవు',
    'editAnnouncement':       'ప్రకటన సవరించు',
    'createAnnouncement':     'ప్రకటన సృష్టించు',
    'updateAnnouncement':     'ప్రకటన నవీకరించు',
    'fillAllFields':          'దయచేసి అన్ని అవసరమైన ఫీల్డ్‌లు పూరించండి',
    'endDateBeforeStart':     'ముగింపు తేదీ ప్రారంభ తేదీ కంటే ముందు ఉండకూడదు',
    'endTimeBeforeStart':     'ఒకే తేదీలో ముగింపు సమయం ప్రారంభ సమయం కంటే ముందు ఉండకూడదు',
    'basicInfo':              'ప్రాథమిక సమాచారం',
    'schedule':               'షెడ్యూల్',
    'details':                'వివరాలు',
    'titleLabel':             'శీర్షిక',
    'descriptionLabel':       'వివరణ',
    'categoryLabel':          'వర్గం',
    'startDate':              'ప్రారంభ తేదీ',
    'endDate':                'ముగింపు తేదీ',
    'startTime':              'ప్రారంభ సమయం',
    'endTime':                'ముగింపు సమయం',
    'locationLabel':          'స్థానం',
    'contactInfo':            'సంప్రదింపు సమాచారం',
    'titleRequired':          'శీర్షిక అవసరం',
    'descriptionRequired':    'వివరణ అవసరం',
    'categoryRequired':       'వర్గం అవసరం',
    'invalidDate':            'చెల్లుబాటు కాని తేదీ',
    'invalidTime':            'చెల్లుబాటు కాని సమయం',
    'titlePlaceholder':       'ఉదా. కమ్యూనిటీ సమావేశం',
    'descriptionPlaceholder': 'మీ ప్రకటనను వివరించండి…',
    'locationPlaceholder':    'ఉదా. కమ్యూనిటీ హాల్',
    'contactPlaceholder':     'ఉదా. ఇమెయిల్ లేదా ఫోన్ నంబర్',
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
    'verifyYourNumber': 'अपना नंबर सत्यापित करें',
    'codeSentTo':       'कोड भेजा गया',
    'enter6DigitCode':  '6-अंकीय कोड दर्ज करें',
    'verifyAndSignIn':  'सत्यापित करें और साइन इन करें',
    'resendCode':       'कोड फिर से भेजें',
    'didntGetCode':     'कोड नहीं मिला? स्पैम जांचें।',
    'invalidOtp':       'कृपया वैध 6-अंकीय OTP दर्ज करें',
    'otpResentSuccess': 'OTP फिर से भेजा गया',
    'createAccount':        'खाता बनाएं',
    'joinIxes':             'iXES से जुड़ें और अपने समुदाय से जुड़ें',
    'mobileNumberLabel':    'मोबाइल नंबर',
    'usernameLabel':        'उपयोगकर्ता नाम',
    'usernamePlaceholder':  'जैसे john_doe',
    'enterUsernameError':   'उपयोगकर्ता नाम दर्ज करें',
    'usernameMinLength':    'कम से कम 3 अक्षर',
    'passwordLabel':        'पासवर्ड',
    'passwordMinChars':     'कम से कम 6 अक्षर',
    'enterPasswordError':   'पासवर्ड दर्ज करें',
    'passwordMinLength':    'कम से कम 6 अक्षर',
    'confirmPasswordLabel': 'पासवर्ड की पुष्टि करें',
    'reenterPassword':      'पासवर्ड दोबारा दर्ज करें',
    'confirmPasswordError': 'अपना पासवर्ड कन्फर्म करें',
    'passwordsNotMatch':    'पासवर्ड मेल नहीं खाते',
    'termsTitle':           'नियम और शर्तें',
    'termsSubtitle':        'मैं नियम और शर्तों से सहमत हूं',
    'agreeToTermsError':    'कृपया नियम और शर्तों से सहमत हों',
    'createAccountBtn':     'खाता बनाएं',
    'alreadyHaveAccount':   'पहले से खाता है?  ',
    'signIn':               'साइन इन',
    'enterMobileNumberHint':'मोबाइल नंबर दर्ज करें',
    'enterValidNumber':     'एक वैध 10-अंकीय नंबर दर्ज करें',
    'signUpFailed':         'साइन अप विफल रहा। पुनः प्रयास करें।',
    'announcements':          'घोषणाएं',
    'newAnnouncement':        'नई',
    'searchAnnouncements':    'घोषणाएं खोजें…',
    'deleteAnnouncement':     'घोषणा हटाएं',
    'deleteAnnouncementMsg':  'यह इस घोषणा को स्थायी रूप से हटा देगा।',
    'cancel':                 'रद्द करें',
    'delete':                 'हटाएं',
    'couldntLoad':            'लोड नहीं हो सका',
    'retry':                  'पुनः प्रयास करें',
    'noAnnouncementsYet':     'अभी तक कोई घोषणा नहीं',
    'checkBackLater':         'बाद में जांचें या एक बनाएं',
    'clearSearch':            'खोज साफ करें',
    'posted':                 'पोस्ट किया गया',
    'noResultsFor':           'के लिए कोई परिणाम नहीं',
    'editAnnouncement':       'घोषणा संपादित करें',
    'createAnnouncement':     'घोषणा बनाएं',
    'updateAnnouncement':     'घोषणा अपडेट करें',
    'fillAllFields':          'कृपया सभी आवश्यक फ़ील्ड भरें',
    'endDateBeforeStart':     'समाप्ति तिथि प्रारंभ तिथि से पहले नहीं हो सकती',
    'endTimeBeforeStart':     'उसी दिन समाप्ति समय प्रारंभ समय से पहले नहीं हो सकता',
    'basicInfo':              'बुनियादी जानकारी',
    'schedule':               'शेड्यूल',
    'details':                'विवरण',
    'titleLabel':             'शीर्षक',
    'descriptionLabel':       'विवरण',
    'categoryLabel':          'श्रेणी',
    'startDate':              'प्रारंभ तिथि',
    'endDate':                'समाप्ति तिथि',
    'startTime':              'प्रारंभ समय',
    'endTime':                'समाप्ति समय',
    'locationLabel':          'स्थान',
    'contactInfo':            'संपर्क जानकारी',
    'titleRequired':          'शीर्षक आवश्यक है',
    'descriptionRequired':    'विवरण आवश्यक है',
    'categoryRequired':       'श्रेणी आवश्यक है',
    'invalidDate':            'अमान्य तिथि',
    'invalidTime':            'अमान्य समय',
    'titlePlaceholder':       'जैसे. सामुदायिक बैठक',
    'descriptionPlaceholder': 'अपनी घोषणा का वर्णन करें…',
    'locationPlaceholder':    'जैसे. सामुदायिक हॉल',
    'contactPlaceholder':     'जैसे. ईमेल या फोन नंबर',

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
    'verifyYourNumber': 'உங்கள் எண்ணை சரிபார்க்கவும்',
    'codeSentTo':       'குறியீடு அனுப்பப்பட்டது',
    'enter6DigitCode':  '6-இலக்க குறியீட்டை உள்ளிடவும்',
    'verifyAndSignIn':  'சரிபார்த்து உள்நுழையவும்',
    'resendCode':       'குறியீட்டை மீண்டும் அனுப்பு',
    'didntGetCode':     'குறியீடு கிடைக்கவில்லையா? ஸ்பேம் சரிபார்க்கவும்.',
    'invalidOtp':       'சரியான 6-இலக்க OTP உள்ளிடவும்',
    'otpResentSuccess': 'OTP மீண்டும் அனுப்பப்பட்டது',
    'createAccount':        'கணக்கை உருவாக்கு',
    'joinIxes':             'iXES இல் சேர்ந்து உங்கள் சமூகத்துடன் இணையுங்கள்',
    'mobileNumberLabel':    'மொபைல் எண்',
    'usernameLabel':        'பயனர் பெயர்',
    'usernamePlaceholder':  'எ.கா. john_doe',
    'enterUsernameError':   'பயனர் பெயரை உள்ளிடவும்',
    'usernameMinLength':    'குறைந்தது 3 எழுத்துக்கள்',
    'passwordLabel':        'கடவுச்சொல்',
    'passwordMinChars':     'குறைந்தது 6 எழுத்துக்கள்',
    'enterPasswordError':   'கடவுச்சொல்லை உள்ளிடவும்',
    'passwordMinLength':    'குறைந்தது 6 எழுத்துக்கள்',
    'confirmPasswordLabel': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
    'reenterPassword':      'கடவுச்சொல்லை மீண்டும் உள்ளிடவும்',
    'confirmPasswordError': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
    'passwordsNotMatch':    'கடவுச்சொற்கள் பொருந்தவில்லை',
    'termsTitle':           'விதிமுறைகள் & நிபந்தனைகள்',
    'termsSubtitle':        'விதிமுறைகளுக்கு சம்மதிக்கிறேன்',
    'agreeToTermsError':    'விதிமுறைகளுக்கு சம்மதிக்கவும்',
    'createAccountBtn':     'கணக்கை உருவாக்கு',
    'alreadyHaveAccount':   'ஏற்கனவே கணக்கு உள்ளதா?  ',
    'signIn':               'உள்நுழைய',
    'enterMobileNumberHint':'மொபைல் எண்ணை உள்ளிடவும்',
    'enterValidNumber':     'சரியான 10-இலக்க எண்ணை உள்ளிடவும்',
    'signUpFailed':         'பதிவு தோல்வியடைந்தது. மீண்டும் முயலவும்.',
    'announcements':          'அறிவிப்புகள்',
    'newAnnouncement':        'புதியது',
    'searchAnnouncements':    'அறிவிப்புகளை தேடுங்கள்…',
    'deleteAnnouncement':     'அறிவிப்பை நீக்கு',
    'deleteAnnouncementMsg':  'இது இந்த அறிவிப்பை நிரந்தரமாக அகற்றும்.',
    'cancel':                 'ரத்து செய்',
    'delete':                 'நீக்கு',
    'couldntLoad':            'ஏற்ற முடியவில்லை',
    'retry':                  'மீண்டும் முயற்சி',
    'noAnnouncementsYet':     'இன்னும் அறிவிப்புகள் இல்லை',
    'checkBackLater':         'பின்னர் சரிபார்க்கவும் அல்லது ஒன்று உருவாக்கவும்',
    'clearSearch':            'தேடலை அழி',
    'posted':                 'இடுகையிடப்பட்டது',
    'noResultsFor':           'க்கான முடிவுகள் இல்லை',
    'editAnnouncement':       'அறிவிப்பை திருத்து',
    'createAnnouncement':     'அறிவிப்பை உருவாக்கு',
    'updateAnnouncement':     'அறிவிப்பை புதுப்பி',
    'fillAllFields':          'தேவையான அனைத்து புலங்களையும் நிரப்பவும்',
    'endDateBeforeStart':     'முடிவு தேதி தொடக்க தேதிக்கு முன்பு இருக்க முடியாது',
    'endTimeBeforeStart':     'அதே தேதியில் முடிவு நேரம் தொடக்க நேரத்திற்கு முன்பு இருக்க முடியாது',
    'basicInfo':              'அடிப்படை தகவல்',
    'schedule':               'அட்டவணை',
    'details':                'விவரங்கள்',
    'titleLabel':             'தலைப்பு',
    'descriptionLabel':       'விளக்கம்',
    'categoryLabel':          'வகை',
    'startDate':              'தொடக்க தேதி',
    'endDate':                'முடிவு தேதி',
    'startTime':              'தொடக்க நேரம்',
    'endTime':                'முடிவு நேரம்',
    'locationLabel':          'இடம்',
    'contactInfo':            'தொடர்பு தகவல்',
    'titleRequired':          'தலைப்பு அவசியம்',
    'descriptionRequired':    'விளக்கம் அவசியம்',
    'categoryRequired':       'வகை அவசியம்',
    'invalidDate':            'தவறான தேதி',
    'invalidTime':            'தவறான நேரம்',
    'titlePlaceholder':       'எ.கா. சமூக கூட்டம்',
    'descriptionPlaceholder': 'உங்கள் அறிவிப்பை விவரிக்கவும்…',
    'locationPlaceholder':    'எ.கா. சமூக அரங்கம்',
    'contactPlaceholder':     'எ.கா. மின்னஞ்சல் அல்லது தொலைபேசி எண்',
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
    'verifyYourNumber': 'ನಿಮ್ಮ ಸಂಖ್ಯೆಯನ್ನು ಪರಿಶೀಲಿಸಿ',
    'codeSentTo':       'ಕೋಡ್ ಕಳುಹಿಸಲಾಗಿದೆ',
    'enter6DigitCode':  '6-ಅಂಕಿ ಕೋಡ್ ನಮೂದಿಸಿ',
    'verifyAndSignIn':  'ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಸೈನ್ ಇನ್ ಮಾಡಿ',
    'resendCode':       'ಕೋಡ್ ಮತ್ತೆ ಕಳುಹಿಸಿ',
    'didntGetCode':     'ಕೋಡ್ ಸಿಗಲಿಲ್ಲವೇ? ಸ್ಪ್ಯಾಮ್ ಪರಿಶೀಲಿಸಿ.',
    'invalidOtp':       'ಮಾನ್ಯ 6-ಅಂಕಿ OTP ನಮೂದಿಸಿ',
    'otpResentSuccess': 'OTP ಮತ್ತೆ ಕಳುಹಿಸಲಾಗಿದೆ',
    'createAccount':        'ಖಾತೆ ರಚಿಸಿ',
    'joinIxes':             'iXES ಗೆ ಸೇರಿ ಮತ್ತು ನಿಮ್ಮ ಸಮುದಾಯದೊಂದಿಗೆ ಸಂಪರ್ಕ ಸಾಧಿಸಿ',
    'mobileNumberLabel':    'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ',
    'usernameLabel':        'ಬಳಕೆದಾರ ಹೆಸರು',
    'usernamePlaceholder':  'ಉದಾ. john_doe',
    'enterUsernameError':   'ಬಳಕೆದಾರ ಹೆಸರು ನಮೂದಿಸಿ',
    'usernameMinLength':    'ಕನಿಷ್ಠ 3 ಅಕ್ಷರಗಳು',
    'passwordLabel':        'ಪಾಸ್‌ವರ್ಡ್',
    'passwordMinChars':     'ಕನಿಷ್ಠ 6 ಅಕ್ಷರಗಳು',
    'enterPasswordError':   'ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ',
    'passwordMinLength':    'ಕನಿಷ್ಠ 6 ಅಕ್ಷರಗಳು',
    'confirmPasswordLabel': 'ಪಾಸ್‌ವರ್ಡ್ ದೃಢೀಕರಿಸಿ',
    'reenterPassword':      'ಪಾಸ್‌ವರ್ಡ್ ಮತ್ತೆ ನಮೂದಿಸಿ',
    'confirmPasswordError': 'ನಿಮ್ಮ ಪಾಸ್‌ವರ್ಡ್ ದೃಢೀಕರಿಸಿ',
    'passwordsNotMatch':    'ಪಾಸ್‌ವರ್ಡ್‌ಗಳು ಹೊಂದಿಕೆಯಾಗುತ್ತಿಲ್ಲ',
    'termsTitle':           'ನಿಯಮಗಳು & ಷರತ್ತುಗಳು',
    'termsSubtitle':        'ನಿಯಮಗಳಿಗೆ ಒಪ್ಪಿಗೆ ನೀಡುತ್ತೇನೆ',
    'agreeToTermsError':    'ದಯವಿಟ್ಟು ನಿಯಮಗಳಿಗೆ ಒಪ್ಪಿಗೆ ನೀಡಿ',
    'createAccountBtn':     'ಖಾತೆ ರಚಿಸಿ',
    'alreadyHaveAccount':   'ಈಗಾಗಲೇ ಖಾತೆ ಇದೆಯೇ?  ',
    'signIn':               'ಸೈನ್ ಇನ್',
    'enterMobileNumberHint':'ಮೊಬೈಲ್ ಸಂಖ್ಯೆ ನಮೂದಿಸಿ',
    'enterValidNumber':     'ಮಾನ್ಯ 10-ಅಂಕಿ ಸಂಖ್ಯೆ ನಮೂದಿಸಿ',
    'signUpFailed':         'ಸೈನ್ ಅಪ್ ವಿಫಲವಾಗಿದೆ. ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
    'announcements':          'ಪ್ರಕಟಣೆಗಳು',
    'newAnnouncement':        'ಹೊಸದು',
    'searchAnnouncements':    'ಪ್ರಕಟಣೆಗಳನ್ನು ಹುಡುಕಿ…',
    'deleteAnnouncement':     'ಪ್ರಕಟಣೆ ಅಳಿಸಿ',
    'deleteAnnouncementMsg':  'ಇದು ಈ ಪ್ರಕಟಣೆಯನ್ನು ಶಾಶ್ವತವಾಗಿ ತೆಗೆದುಹಾಕುತ್ತದೆ.',
    'cancel':                 'ರದ್ದು ಮಾಡಿ',
    'delete':                 'ಅಳಿಸಿ',
    'couldntLoad':            'ಲೋಡ್ ಆಗಲಿಲ್ಲ',
    'retry':                  'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    'noAnnouncementsYet':     'ಇನ್ನೂ ಪ್ರಕಟಣೆಗಳಿಲ್ಲ',
    'checkBackLater':         'ನಂತರ ಪರಿಶೀಲಿಸಿ ಅಥವಾ ಒಂದನ್ನು ರಚಿಸಿ',
    'clearSearch':            'ಹುಡುಕಾಟ ತೆರವುಗೊಳಿಸಿ',
    'posted':                 'ಪೋಸ್ಟ್ ಮಾಡಲಾಗಿದೆ',
    'noResultsFor':           'ಗಾಗಿ ಯಾವುದೇ ಫಲಿತಾಂಶಗಳಿಲ್ಲ',
    'editAnnouncement':       'ಪ್ರಕಟಣೆ ಸಂಪಾದಿಸಿ',
    'createAnnouncement':     'ಪ್ರಕಟಣೆ ರಚಿಸಿ',
    'updateAnnouncement':     'ಪ್ರಕಟಣೆ ನವೀಕರಿಸಿ',
    'fillAllFields':          'ದಯವಿಟ್ಟು ಎಲ್ಲಾ ಅಗತ್ಯ ಕ್ಷೇತ್ರಗಳನ್ನು ತುಂಬಿಸಿ',
    'endDateBeforeStart':     'ಅಂತಿಮ ದಿನಾಂಕ ಆರಂಭ ದಿನಾಂಕಕ್ಕಿಂತ ಮೊದಲು ಇರಬಾರದು',
    'endTimeBeforeStart':     'ಅದೇ ದಿನದಂದು ಅಂತಿಮ ಸಮಯ ಆರಂಭ ಸಮಯಕ್ಕಿಂತ ಮೊದಲು ಇರಬಾರದು',
    'basicInfo':              'ಮೂಲ ಮಾಹಿತಿ',
    'schedule':               'ವೇಳಾಪಟ್ಟಿ',
    'details':                'ವಿವರಗಳು',
    'titleLabel':             'ಶೀರ್ಷಿಕೆ',
    'descriptionLabel':       'ವಿವರಣೆ',
    'categoryLabel':          'ವರ್ಗ',
    'startDate':              'ಆರಂಭ ದಿನಾಂಕ',
    'endDate':                'ಅಂತಿಮ ದಿನಾಂಕ',
    'startTime':              'ಆರಂಭ ಸಮಯ',
    'endTime':                'ಅಂತಿಮ ಸಮಯ',
    'locationLabel':          'ಸ್ಥಳ',
    'contactInfo':            'ಸಂಪರ್ಕ ಮಾಹಿತಿ',
    'titleRequired':          'ಶೀರ್ಷಿಕೆ ಅಗತ್ಯ',
    'descriptionRequired':    'ವಿವರಣೆ ಅಗತ್ಯ',
    'categoryRequired':       'ವರ್ಗ ಅಗತ್ಯ',
    'invalidDate':            'ಅಮಾನ್ಯ ದಿನಾಂಕ',
    'invalidTime':            'ಅಮಾನ್ಯ ಸಮಯ',
    'titlePlaceholder':       'ಉದಾ. ಸಮುದಾಯ ಸಭೆ',
    'descriptionPlaceholder': 'ನಿಮ್ಮ ಪ್ರಕಟಣೆಯನ್ನು ವಿವರಿಸಿ…',
    'locationPlaceholder':    'ಉದಾ. ಸಮುದಾಯ ಭವನ',
    'contactPlaceholder':     'ಉದಾ. ಇಮೇಲ್ ಅಥವಾ ಫೋನ್ ಸಂಖ್ಯೆ'
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
    'verifyYourNumber': 'നിങ്ങളുടെ നമ്പർ സ്ഥിരീകരിക്കുക',
    'codeSentTo':       'കോഡ് അയച്ചു',
    'enter6DigitCode':  '6-അക്ക കോഡ് നൽകുക',
    'verifyAndSignIn':  'സ്ഥിരീകരിച്ച് സൈൻ ഇൻ ചെയ്യുക',
    'resendCode':       'കോഡ് വീണ്ടും അയക്കുക',
    'didntGetCode':     'കോഡ് ലഭിച്ചില്ലേ? സ്പാം പരിശോധിക്കുക.',
    'invalidOtp':       'സാധുവായ 6-അക്ക OTP നൽകുക',
    'otpResentSuccess': 'OTP വീണ്ടും അയച്ചു',
    'createAccount':        'അക്കൗണ്ട് ഉണ്ടാക്കുക',
    'joinIxes':             'iXES ൽ ചേർന്ന് നിങ്ങളുടെ കമ്മ്യൂണിറ്റിയുമായി ബന്ധപ്പെടുക',
    'mobileNumberLabel':    'മൊബൈൽ നമ്പർ',
    'usernameLabel':        'ഉപയോക്തൃ നാമം',
    'usernamePlaceholder':  'ഉദാ. john_doe',
    'enterUsernameError':   'ഉപയോക്തൃ നാമം നൽകുക',
    'usernameMinLength':    'കുറഞ്ഞത് 3 അക്ഷരങ്ങൾ',
    'passwordLabel':        'പാസ്‌വേഡ്',
    'passwordMinChars':     'കുറഞ്ഞത് 6 അക്ഷരങ്ങൾ',
    'enterPasswordError':   'പാസ്‌വേഡ് നൽകുക',
    'passwordMinLength':    'കുറഞ്ഞത് 6 അക്ഷരങ്ങൾ',
    'confirmPasswordLabel': 'പാസ്‌വേഡ് സ്ഥിരീകരിക്കുക',
    'reenterPassword':      'പാസ്‌വേഡ് വീണ്ടും നൽകുക',
    'confirmPasswordError': 'പാസ്‌വേഡ് സ്ഥിരീകരിക്കുക',
    'passwordsNotMatch':    'പാസ്‌വേഡുകൾ പൊരുത്തപ്പെടുന്നില്ല',
    'termsTitle':           'നിബന്ധനകളും വ്യവസ്ഥകളും',
    'termsSubtitle':        'നിബന്ധനകൾക്ക് ഞാൻ സമ്മതിക്കുന്നു',
    'agreeToTermsError':    'ദയവായി നിബന്ധനകൾക്ക് സമ്മതിക്കുക',
    'createAccountBtn':     'അക്കൗണ്ട് ഉണ്ടാക്കുക',
    'alreadyHaveAccount':   'ഇതിനകം അക്കൗണ്ട് ഉണ്ടോ?  ',
    'signIn':               'സൈൻ ഇൻ',
    'enterMobileNumberHint':'മൊബൈൽ നമ്പർ നൽകുക',
    'enterValidNumber':     'സാധുവായ 10-അക്ക നമ്പർ നൽകുക',
    'signUpFailed':         'സൈൻ അപ്പ് പരാജയപ്പെട്ടു. വീണ്ടും ശ്രമിക്കുക.',
    'announcements':          'അറിയിപ്പുകൾ',
    'newAnnouncement':        'പുതിയത്',
    'searchAnnouncements':    'അറിയിപ്പുകൾ തിരയുക…',
    'deleteAnnouncement':     'അറിയിപ്പ് ഇല്ലാതാക്കുക',
    'deleteAnnouncementMsg':  'ഇത് ഈ അറിയിപ്പ് സ്ഥിരമായി നീക്കം ചെയ്യും.',
    'cancel':                 'റദ്ദാക്കുക',
    'delete':                 'ഇല്ലാതാക്കുക',
    'couldntLoad':            'ലോഡ് ചെയ്യാനായില്ല',
    'retry':                  'വീണ്ടും ശ്രമിക്കുക',
    'noAnnouncementsYet':     'ഇതുവരെ അറിയിപ്പുകളില്ല',
    'checkBackLater':         'പിന്നീട് പരിശോധിക്കുക അല്ലെങ്കിൽ ഒന്ന് സൃഷ്ടിക്കുക',
    'clearSearch':            'തിരയൽ മായ്ക്കുക',
    'posted':                 'പോസ്റ്റ് ചെയ്തു',
    'noResultsFor':           'ന് ഫലങ്ങളൊന്നുമില്ല',
    'editAnnouncement':       'അറിയിപ്പ് തിരുത്തുക',
    'createAnnouncement':     'അറിയിപ്പ് സൃഷ്ടിക്കുക',
    'updateAnnouncement':     'അറിയിപ്പ് അപ്ഡേറ്റ് ചെയ്യുക',
    'fillAllFields':          'എല്ലാ ആവശ്യമായ ഫീൽഡുകളും പൂരിപ്പിക്കുക',
    'endDateBeforeStart':     'അവസാന തീയതി ആരംഭ തീയതിക്ക് മുമ്പ് ആകരുത്',
    'endTimeBeforeStart':     'അതേ ദിവസം അവസാന സമയം ആരംഭ സമയത്തിന് മുമ്പ് ആകരുത്',
    'basicInfo':              'അടിസ്ഥാന വിവരങ്ങൾ',
    'schedule':               'ഷെഡ്യൂൾ',
    'details':                'വിവരങ്ങൾ',
    'titleLabel':             'തലക്കെട്ട്',
    'descriptionLabel':       'വിവരണം',
    'categoryLabel':          'വിഭാഗം',
    'startDate':              'ആരംഭ തീയതി',
    'endDate':                'അവസാന തീയതി',
    'startTime':              'ആരംഭ സമയം',
    'endTime':                'അവസാന സമയം',
    'locationLabel':          'സ്ഥലം',
    'contactInfo':            'ബന്ധപ്പെടാനുള്ള വിവരങ്ങൾ',
    'titleRequired':          'തലക്കെട്ട് ആവശ്യമാണ്',
    'descriptionRequired':    'വിവരണം ആവശ്യമാണ്',
    'categoryRequired':       'വിഭാഗം ആവശ്യമാണ്',
    'invalidDate':            'അസാധുവായ തീയതി',
    'invalidTime':            'അസാധുവായ സമയം',
    'titlePlaceholder':       'ഉദാ. കമ്മ്യൂണിറ്റി യോഗം',
    'descriptionPlaceholder': 'നിങ്ങളുടെ അറിയിപ്പ് വിവരിക്കുക…',
    'locationPlaceholder':    'ഉദാ. കമ്മ്യൂണിറ്റി ഹാൾ',
    'contactPlaceholder':     'ഉദാ. ഇമെയിൽ അല്ലെങ്കിൽ ഫോൺ നമ്പർ',

  },

};
