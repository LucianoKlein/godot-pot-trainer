const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const PRODUCT_TIER_MAP = {
  "pot_trainer_monthly": "pot_trainer",
};

const WEBHOOK_AUTH_KEY = process.env.RC_WEBHOOK_SECRET || "";

exports.revenuecatWebhook = onRequest(
  { region: "us-central1", cors: false },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    if (WEBHOOK_AUTH_KEY) {
      const authHeader = req.headers.authorization || "";
      if (authHeader !== `Bearer ${WEBHOOK_AUTH_KEY}`) {
        console.warn("Unauthorized webhook request");
        res.status(401).send("Unauthorized");
        return;
      }
    }

    const event = req.body;
    if (!event || !event.event) {
      res.status(400).send("Invalid payload");
      return;
    }

    const eventType = event.event.type;
    const appUserId = event.event.app_user_id;
    const productId = event.event.product_id;
    const expirationAtMs = event.event.expiration_at_ms;

    console.log(`RevenueCat event: ${eventType}, user: ${appUserId}, product: ${productId}`);

    if (!appUserId) {
      res.status(400).send("Missing app_user_id");
      return;
    }

    const tier = PRODUCT_TIER_MAP[productId] || null;

    try {
      const docRef = db.collection("users").doc(appUserId);

      switch (eventType) {
        case "INITIAL_PURCHASE":
        case "RENEWAL":
        case "PRODUCT_CHANGE":
        case "UNCANCELLATION": {
          if (!tier) {
            console.warn(`Unknown product_id: ${productId}`);
            res.status(200).send("OK (unknown product)");
            return;
          }
          const expiresAt = expirationAtMs
            ? new Date(expirationAtMs)
            : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

          await docRef.set(
            {
              subscription: {
                tier: tier,
                expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
              },
            },
            { merge: true }
          );
          console.log(`Updated ${appUserId}: tier=${tier}, expires=${expiresAt.toISOString()}`);
          break;
        }

        case "CANCELLATION":
        case "EXPIRATION": {
          console.log(`Subscription ${eventType} for ${appUserId}`);
          break;
        }

        case "BILLING_ISSUE": {
          console.warn(`Billing issue for ${appUserId}, product: ${productId}`);
          break;
        }

        default:
          console.log(`Unhandled event type: ${eventType}`);
      }

      res.status(200).send("OK");
    } catch (err) {
      console.error("Error processing webhook:", err);
      res.status(500).send("Internal error");
    }
  }
);
