const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Tâche Cron exécutée tous les jours à 08:00 (Europe/Paris)
 * Vérifie les aliments qui arrivent à date d'expiration (J-2, J-1, Jour J)
 * et envoie une notification push FCM aux utilisateurs des frigos correspondants.
 */
exports.checkExpiringFood = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "Europe/Paris",
    memory: "256MiB",
  },
  async (event) => {
    const db = admin.firestore();
    const now = new Date();
    // Plage de dates : aliments expirés récemment (jusqu'à il y a 7 jours) + aliments expirant d'ici 2 jours
    const startWindow = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7, 0, 0, 0);
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const endInTwoDays = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2, 23, 59, 59, 999);

    logger.info(`Vérification des aliments expirant entre ${startWindow.toISOString()} et ${endInTwoDays.toISOString()}`);

    try {
      // 1. Récupérer les aliments dans la plage
      const foodSnapshot = await db
        .collection("food_items")
        .where("expirationDate", ">=", admin.firestore.Timestamp.fromDate(startWindow))
        .where("expirationDate", "<=", admin.firestore.Timestamp.fromDate(endInTwoDays))
        .get();

      if (foodSnapshot.empty) {
        logger.info("Aucun aliment périmé ou arrivant à expiration.");
        return;
      }

      logger.info(`${foodSnapshot.size} aliment(s) trouvé(s).`);

      // 2. Regrouper les aliments par frigo
      const foodsByFridge = new Map();
      for (const doc of foodSnapshot.docs) {
        const food = { id: doc.id, ...doc.data() };
        if (!food.fridgeId) continue;

        if (!foodsByFridge.has(food.fridgeId)) {
          foodsByFridge.set(food.fridgeId, []);
        }
        foodsByFridge.get(food.fridgeId).push(food);
      }

      // 3. Pour chaque frigo, retrouver les membres et préparer les notifications
      const userNotifications = new Map(); // userId -> Array<{ name, daysLeft }>

      for (const [fridgeId, foods] of foodsByFridge.entries()) {
        const fridgeUsersSnapshot = await db
          .collection("fridge_users")
          .where("fridgeId", "==", fridgeId)
          .get();

        const userIds = fridgeUsersSnapshot.docs.map((d) => d.data().userId).filter(Boolean);

        for (const userId of userIds) {
          if (!userNotifications.has(userId)) {
            userNotifications.set(userId, []);
          }

          for (const food of foods) {
            const expDate = food.expirationDate.toDate();
            // Comparer par rapport au début de la journée d'aujourd'hui
            const diffTime = expDate.getTime() - startOfToday.getTime();
            const daysLeft = Math.floor(diffTime / (1000 * 60 * 60 * 24));

            userNotifications.get(userId).push({
              name: food.name || "Aliment",
              daysLeft: daysLeft,
            });
          }
        }
      }

      // 4. Envoyer les notifications push aux utilisateurs ciblés
      for (const [userId, items] of userNotifications.entries()) {
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) continue;

        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;

        if (!fcmToken) {
          logger.warn(`Aucun token FCM trouvé pour l'utilisateur ${userId}`);
          continue;
        }

        // Construire le message de notification adapté
        let title = "Pocket Fridge 🧊";
        let body = "";

        if (items.length === 1) {
          const item = items[0];
          if (item.daysLeft < 0) {
            const absDays = Math.abs(item.daysLeft);
            title = "🚨 Aliment déjà périmé !";
            body = absDays === 1
              ? `L'article "${item.name}" est périmé depuis hier.`
              : `L'article "${item.name}" est périmé depuis ${absDays} jours.`;
          } else if (item.daysLeft === 0) {
            title = "🚨 Attention : À consommer aujourd'hui !";
            body = `L'article "${item.name}" expire aujourd'hui.`;
          } else {
            title = "⚠️ Alerte Péremption";
            body = `L'article "${item.name}" expire dans ${item.daysLeft} jour(s).`;
          }
        } else {
          const expiredCount = items.filter((i) => i.daysLeft < 0).length;
          const expiringCount = items.filter((i) => i.daysLeft >= 0).length;

          if (expiredCount > 0 && expiringCount > 0) {
            title = `🚨 ${items.length} articles à vérifier dans votre frigo !`;
            body = `${expiredCount} article(s) périmé(s) et ${expiringCount} expirant bientôt (${items.slice(0, 2).map((i) => i.name).join(", ")}...).`;
          } else if (expiredCount > 0) {
            title = `🚨 ${expiredCount} article(s) sont déjà périmés !`;
            body = `Pensez à vérifier : ${items.slice(0, 3).map((i) => i.name).join(", ")}${items.length > 3 ? "..." : "."}`;
          } else {
            title = `⚠️ ${expiringCount} aliments vont bientôt expirer !`;
            body = `Pensez à consommer : ${items.slice(0, 3).map((i) => i.name).join(", ")}${items.length > 3 ? "..." : "."}`;
          }
        }

        const message = {
          token: fcmToken,
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: "EXPIRING_FOOD_ALERT",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            ttl: 24 * 60 * 60 * 1000, // 24 heures en millisecondes
            collapseKey: "pocket_fridge_daily_alert", // Écrase les anciennes alertes non délivrées
            notification: {
              channelId: "pocket_fridge_channel",
              sound: "default",
            },
          },
          apns: {
            headers: {
              "apns-expiration": String(Math.floor(Date.now() / 1000) + 86400), // Expire après 24h
              "apns-collapse-id": "pocket_fridge_daily_alert",
            },
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        try {
          const response = await admin.messaging().send(message);
          logger.info(`Notification envoyée avec succès à ${userId}: ${response}`);
        } catch (err) {
          logger.error(`Erreur d'envoi FCM pour l'utilisateur ${userId}:`, err);
        }
      }
    } catch (error) {
      logger.error("Erreur globale lors de la vérification des aliments expirants:", error);
    }
  }
);
