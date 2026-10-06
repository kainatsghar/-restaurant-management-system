import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Generated from google-services.json for project fooddeliveryapp-fb8c1.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB-WXZ9QNrNsF7Y5uOvuqqOuU5hqTnko5s',
    appId: '1:570159539248:android:9c8ab00d671f9de7ba79f5',
    messagingSenderId: '570159539248',
    projectId: 'fooddeliveryapp-fb8c1',
    storageBucket: 'fooddeliveryapp-fb8c1.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB-WXZ9QNrNsF7Y5uOvuqqOuU5hqTnko5s',
    appId: '1:570159539248:android:9c8ab00d671f9de7ba79f5',
    messagingSenderId: '570159539248',
    projectId: 'fooddeliveryapp-fb8c1',
    storageBucket: 'fooddeliveryapp-fb8c1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB-WXZ9QNrNsF7Y5uOvuqqOuU5hqTnko5s',
    appId: '1:570159539248:android:9c8ab00d671f9de7ba79f5',
    messagingSenderId: '570159539248',
    projectId: 'fooddeliveryapp-fb8c1',
    storageBucket: 'fooddeliveryapp-fb8c1.firebasestorage.app',
  );
}
