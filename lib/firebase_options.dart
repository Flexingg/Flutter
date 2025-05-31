import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'firebase_config.dart';

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
      case TargetPlatform.macOS:
        return macos;
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
    apiKey: 'AIzaSyB6DZX_EgFTdqMf6YtPQLaMUsvgn3ragfw',
    appId: '1:992531114744:web:93da2367bed42ae695e90d',
    messagingSenderId: '992531114744',
    projectId: 'flexinggapp',
    authDomain: 'flexinggapp.firebaseapp.com',
    storageBucket: 'flexinggapp.firebasestorage.app',
  );

  static final FirebaseOptions android = FirebaseOptions(
    apiKey: FirebaseConfig.apiKey,
    appId: FirebaseConfig.appId,
    messagingSenderId: FirebaseConfig.messagingSenderId,
    projectId: FirebaseConfig.projectId,
    storageBucket: FirebaseConfig.storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB6DZX_EgFTdqMf6YtPQLaMUsvgn3ragfw',
    appId: '1:992531114744:ios:93da2367bed42ae695e90d',
    messagingSenderId: '992531114744',
    projectId: 'flexinggapp',
    storageBucket: 'flexinggapp.firebasestorage.app',
    iosClientId: '992531114744-ios-client-id',
    iosBundleId: 'com.example.flexingg',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB6DZX_EgFTdqMf6YtPQLaMUsvgn3ragfw',
    appId: '1:992531114744:macos:93da2367bed42ae695e90d',
    messagingSenderId: '992531114744',
    projectId: 'flexinggapp',
    storageBucket: 'flexinggapp.firebasestorage.app',
    iosClientId: '992531114744-macos-client-id',
    iosBundleId: 'com.example.flexingg',
  );
} 