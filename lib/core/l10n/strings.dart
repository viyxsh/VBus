import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/locale_provider.dart';

// ─── Translation map ──────────────────────────────────────────────────────────

const _hi = {
  // Navigation
  'Home': 'होम',
  'Inbox': 'इनबॉक्स',
  'Seat': 'सीट',
  'Attendance': 'उपस्थिति',
  'Profile': 'प्रोफ़ाइल',

  // Auth
  'VBUS': 'VBUS',
  'VIT Bhopal Transport': 'VIT भोपाल परिवहन',
  'VIT Bhopal University Transport': 'VIT भोपाल विश्वविद्यालय परिवहन',
  'Choose Account Type': 'खाता प्रकार चुनें',
  'Conductor': 'कंडक्टर',
  'Student / Faculty': 'छात्र / शिक्षक',
  'Sign In': 'साइन इन',
  'Username': 'उपयोगकर्ता नाम',
  'Password': 'पासवर्ड',
  'Sign in with Google': 'Google से साइन इन करें',
  'Use your @vitbhopal.ac.in account': 'अपने @vitbhopal.ac.in खाते का उपयोग करें',

  // Settings / Profile
  'Settings': 'सेटिंग्स',
  'Edit Profile': 'प्रोफ़ाइल संपादित करें',
  'Account': 'खाता',
  'Bus Management': 'बस प्रबंधन',
  'Notifications': 'सूचनाएं',
  'General': 'सामान्य',
  'Support': 'सहायता',
  'Log Out': 'लॉग आउट',
  'Seat Booking History': 'सीट बुकिंग इतिहास',
  'Custom Stop Pins': 'कस्टम स्टॉप पिन',
  'Manage your saved map pins': 'अपने सहेजे गए मानचित्र पिन प्रबंधित करें',
  'Seat Booking Reminder': 'सीट बुकिंग अनुस्मारक',
  'Remind me before the 8 PM booking window opens': 'रात 8 बजे की बुकिंग विंडो खुलने से पहले याद दिलाएं',
  'Custom Pin Alerts': 'कस्टम पिन अलर्ट',
  'Alert me when the bus nears my saved map pins': 'बस मेरे सहेजे गए पिन के पास आने पर सूचित करें',
  'Appearance': 'स्वरूप',
  'Dark': 'डार्क',
  'Light': 'लाइट',
  'Language': 'भाषा',
  'English': 'अंग्रेज़ी',
  'Hindi': 'हिंदी',
  'Bus Controls': 'बस नियंत्रण',
  'Faculty rows, seat layout': 'फैकल्टी पंक्तियां, सीट लेआउट',
  'Manage Passengers': 'यात्री प्रबंधन',
  'Add or remove passengers from bus': 'बस से यात्री जोड़ें या हटाएं',
  'Trip and attendance reminders': 'यात्रा और उपस्थिति अनुस्मारक',
  'Trip start reminders and attendance alerts': 'यात्रा प्रारंभ और उपस्थिति अलर्ट',
  'Manage your saved pins': 'अपने सहेजे गए पिन प्रबंधित करें',
  'Dark Mode': 'डार्क मोड',
  'Currently using dark theme': 'वर्तमान में डार्क थीम उपयोग में है',
  'Currently using light theme': 'वर्तमान में लाइट थीम उपयोग में है',

  // Attendance
  'No Active Trip': 'कोई एक्टिव ट्रिप नहीं',
  'Start a trip to begin taking attendance': 'अटेंडेंस लेने के लिए ट्रिप शुरू करें',
  'Start Trip': 'ट्रिप शुरू करें',
  'End Trip': 'ट्रिप खत्म करें',
  'Trip Ended': 'ट्रिप खत्म',
  'Trip Complete': 'ट्रिप कम्पलीट',
  'New Trip': 'नई ट्रिप',
  'Scan ID': 'ID स्कैन करें',
  'Present': 'प्रेज़ेंट',
  'Missing': 'मिसिंग',
  'Missed': 'मिस्ड',
  'Absent': 'एब्सेंट',
  'Waiting': 'वेटिंग',
  'Total': 'टोटल',
  'Search': 'खोजें',
  'Current': 'करंट',
  'Current Location:': 'करंट लोकेशन:',
  'Final Stop': 'फाइनल स्टॉप',
  'No results': 'कोई रिजल्ट नहीं',
  'Name': 'नाम',
  'Stop': 'स्टॉप',
  'GPS signal lost — auto-advance paused.': 'GPS सिग्नल खो गया — ऑटो-एडवांस रुका।',
  'GPS lost — auto-advance paused.': 'GPS खो गया — ऑटो-एडवांस रुका।',
  'Next Stop →': 'अगला स्टॉप →',

  // Inbox
  'Broadcast': 'ब्रॉडकास्ट',
  'Private': 'प्राइवेट',
  'No messages yet': 'अभी कोई मैसेज नहीं',
  'Tap to start private chat': 'प्राइवेट चैट शुरू करने के लिए टैप करें',
  'New Message': 'नया मैसेज',
  'All': 'सभी',
  'Unread': 'अनरीड',
  'Students': 'स्टूडेंट्स',
  'Faculty': 'फैकल्टी',
  'Failed to load inbox': 'इनबॉक्स लोड नहीं हुआ',
  'No conversations yet': 'अभी कोई बातचीत नहीं',
  'All caught up!': 'सब पढ़ लिया!',
  'No unread messages': 'कोई अनरीड मैसेज नहीं',
  'Not set up yet': 'अभी सेट अप नहीं हुआ',
  'No passengers': 'कोई पैसेंजर नहीं',
  'Open': 'खोलें',
  'Done': 'डन',
  'Clear': 'क्लियर',
  'Search conversations...': 'बातचीत खोजें...',
  'Search passengers...': 'पैसेंजर खोजें...',
  'You': 'आप',
  'Yesterday': 'कल',

  // Seat
  'My Seat': 'मेरी सीट',
  'Confirm': 'पुष्टि करें',
  'Cancel Booking': 'बुकिंग रद्द करें',
  'Open — closes in': 'खुला — बंद होगा',
  'Seat selection starts in': 'सीट चयन शुरू होगा',

  // Common
  'Retry': 'पुनः प्रयास करें',
  'Cancel': 'रद्द करें',
  'Save Changes': 'परिवर्तन सहेजें',
  'Full Name': 'पूरा नाम',
  'Phone Number': 'फोन नंबर',
  'Student': 'छात्र',
  'Bus': 'बस',
  'Your stop': 'आपका स्टॉप',
  'Bus here': 'बस यहाँ है',
};

// ─── Helper class ─────────────────────────────────────────────────────────────

class S {
  /// Translate [key] based on the current app locale.
  static String of(WidgetRef ref, String key) {
    final isHindi = ref.watch(localeProvider).languageCode == 'hi';
    if (!isHindi) return key;
    return _hi[key] ?? key;
  }

  /// Use inside a Widget where you already have a BuildContext.
  static String t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode != 'hi') return key;
    return _hi[key] ?? key;
  }
}
