import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'model/datamodel.dart';

Future<FoodItem?> getNextExpiringFood() async {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  /// 1. récupérer les frigos
  final fridgeSnapshot = await FirebaseFirestore.instance
      .collection('fridge_users')
      .where('userId', isEqualTo: userId)
      .get();

  final fridgeIds = fridgeSnapshot.docs
      .map((d) => d['fridgeId'] as String)
      .toList();

  if (fridgeIds.isEmpty) return null;

  /// 2. récupérer les food_items
  final foodSnapshot = await FirebaseFirestore.instance
      .collection('food_items')
      .where('fridgeId', whereIn: fridgeIds)
      .get();

  FoodItem? closest;

  for (var doc in foodSnapshot.docs) {
    final data = doc.data();

    final item = FoodItem.fromMap(data);

    if (item.expirationDate == null) continue;

    if (closest == null ||
        item.expirationDate!.isBefore(closest.expirationDate!)) {
      closest = item;
    }
  }

  return closest;
}

Future<void> showNotification(String title, String body) async {
  const android = AndroidNotificationDetails(
    'fridge_channel',
    'Fridge Notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: android);

  await NotificationService._notifications.show(0, title, body, details);
}

Future<void> scheduleDailyReminder() async {
  const android = AndroidNotificationDetails(
    'daily_channel',
    'Daily Reminder',
    importance: Importance.max,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: android);

  await NotificationService._notifications.periodicallyShow(
    1,
    "Vérifie ton frigo 🧊",
    "Certains aliments vont bientôt expirer",
    RepeatInterval.daily,
    details,
  );
}

Future<void> checkAndNotify() async {
  final food = await getNextExpiringFood();

  if (food == null) return;

  final daysLeft = food.expirationDate!.difference(DateTime.now()).inDays;

  if (daysLeft <= 2) {
    await showNotification(
      "⚠️ ${food.name}",
      daysLeft < 0 ? "Est périmé !" : "Expire dans $daysLeft jour(s)",
    );
  }
}

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);

    // await _notifications.initialize(settings);
  }
}

Future<void> saveToken() async {
  final token = await FirebaseMessaging.instance.getToken();

  final userId = FirebaseAuth.instance.currentUser!.uid;

  await FirebaseFirestore.instance.collection('users').doc(userId).set({
    'fcmToken': token,
  }, SetOptions(merge: true));
}
