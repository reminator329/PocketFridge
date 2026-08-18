import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'model/datamodel.dart';

/// Top-level background handler for FCM messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pocket_fridge_channel',
    'Alertes Péremption',
    description: 'Notifications pour les aliments qui vont expirer',
    importance: Importance.high,
    playSound: true,
  );

  static Future<void> init() async {
    // 1. Initialiser le canal de notification Android
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }

    // 2. Initialiser les settings locaux (Android & iOS)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    // 3. Demander les permissions système
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 4. Configurer la gestion en arrière-plan
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 5. Afficher la notification quand l'application est au premier plan (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        showNotification(
          notification.title ?? 'Pocket Fridge 🧊',
          notification.body ?? '',
        );
      }
    });

    // 6. Écouter le renouvellement du token FCM
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      saveDeviceToken(token: newToken);
    });

    // 7. Sauvegarder le token actuel si l'utilisateur est déjà connecté
    await saveDeviceToken();
  }

  /// Sauvegarde ou met à jour le token FCM dans Firestore pour l'utilisateur connecté
  static Future<void> saveDeviceToken({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('FCM Token enregistré avec succès pour ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de l\'enregistrement du FCM token: $e');
      }
    }
  }

  /// Affiche une notification locale immédiate
  static Future<void> showNotification(String title, String body) async {
    final android = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(
      android: android,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

/// Recherche locale des aliments les plus proches de l'expiration
Future<FoodItem?> getNextExpiringFood() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final fridgeSnapshot = await FirebaseFirestore.instance
      .collection('fridge_users')
      .where('userId', isEqualTo: user.uid)
      .get();

  final fridgeIds =
      fridgeSnapshot.docs.map((d) => d['fridgeId'] as String).toList();

  if (fridgeIds.isEmpty) return null;

  final foodSnapshot = await FirebaseFirestore.instance
      .collection('food_items')
      .where('fridgeId', whereIn: fridgeIds)
      .get();

  FoodItem? closest;

  for (var doc in foodSnapshot.docs) {
    final item = FoodItem.fromMap(doc.data());
    if (item.expirationDate == null) continue;

    if (closest == null ||
        item.expirationDate!.isBefore(closest.expirationDate!)) {
      closest = item;
    }
  }

  return closest;
}
