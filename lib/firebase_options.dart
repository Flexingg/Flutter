import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkw1YsbkYBw0GAOICILSZIfnSi20k3MZY',
    appId: '1:992531114744:web:77796f57af87c23795e90d',
    messagingSenderId: '992531114744',
    projectId: 'flexinggapp',
    authDomain: 'flexinggapp.firebaseapp.com',
    storageBucket: 'flexinggapp.firebasestorage.app',
    measurementId: 'G-7NP2QL1JWH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6DZX_EgFTdqMf6YtPQLaMUsvgn3ragfw',
    appId: '1:992531114744:android:93da2367bed42ae695e90d',
    messagingSenderId: '992531114744',
    projectId: 'flexinggapp',
    storageBucket: 'flexinggapp.firebasestorage.app',
  );
} 