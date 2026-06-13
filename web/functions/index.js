const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

async function getGroup(groupId) {
  const snapshot = await db.doc(`groups/${groupId}`).get();
  return snapshot.data() || {};
}

async function getMemberName(groupId, uid) {
  if (!uid) return "A member";
  const snapshot = await db.doc(`groups/${groupId}/members/${uid}`).get();
  return snapshot.data()?.name || "A member";
}

async function getTokensForUsers(uids) {
  const tokens = [];
  await Promise.all(
    uids.map(async (uid) => {
      const snapshot = await db.collection(`users/${uid}/fcmTokens`).get();
      snapshot.forEach((doc) => {
        const token = doc.data().token || doc.id;
        if (token) tokens.push(token);
      });
    }),
  );
  return [...new Set(tokens)];
}

async function createInboxRecords(uids, eventId, payload) {
  const batch = db.batch();
  for (const uid of uids) {
    const ref = db.doc(`users/${uid}/notifications/${eventId}`);
    batch.set(ref, {
      ...payload,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

async function sendPush(uids, payload) {
  const tokens = await getTokensForUsers(uids);
  if (!tokens.length) return;

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: payload.title,
      body: payload.pushBody,
    },
    data: {
      groupId: String(payload.groupId),
      txId: String(payload.txId),
      type: String(payload.type),
      path: `/group/${payload.groupId}/notifications`,
    },
    android: {
      priority: "high",
    },
  });

  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (!result.success &&
        ["messaging/invalid-registration-token", "messaging/registration-token-not-registered"]
          .includes(result.error?.code)) {
      invalidTokens.push(tokens[index]);
    }
  });
  await Promise.all(invalidTokens.map(async (token) => {
    const snapshots = await db.collectionGroup("fcmTokens")
      .where("token", "==", token).get();
    await Promise.all(snapshots.docs.map((doc) => doc.ref.delete()));
  }));
}

async function notifyGroup(groupId, txId, eventId, details) {
  const group = await getGroup(groupId);
  const members = group.memberUids || [];
  if (!members.length) return;

  const category = details.tx.category || "Expense";
  const note = details.tx.description || "No note";
  const amount = Number(details.tx.amount || 0);
  const payload = {
    groupId,
    groupName: group.name || "Group",
    txId,
    type: details.type,
    title: details.title,
    message: details.message,
    category,
    note: details.tx.description || "",
    amount,
    requiresAction: Boolean(details.requiresAction),
    pushBody: `${category} | ${note} | PKR ${amount.toFixed(2)}`,
  };

  await Promise.all([
    createInboxRecords(members, eventId, payload),
    sendPush(members, payload),
  ]);
}

exports.onTxCreate = functions.firestore
  .document("groups/{groupId}/tx/{txId}")
  .onCreate(async (snapshot, context) => {
    const { groupId, txId } = context.params;
    const tx = snapshot.data() || {};
    if (tx.type !== "expense") return;

    const pending = tx.status === "pending";
    await notifyGroup(groupId, txId, `${txId}_created`, {
      tx,
      type: "expense_added",
      title: pending ? "New expense needs approval" : "New expense added",
      message: pending
        ? "Review this expense and choose Okay or Reject."
        : "This expense has been added to the group.",
      requiresAction: pending,
    });
  });

exports.onTxUpdate = functions.firestore
  .document("groups/{groupId}/tx/{txId}")
  .onUpdate(async (change, context) => {
    const { groupId, txId } = context.params;
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (after.type !== "expense") return;

    if (before.status !== after.status) {
      if (after.status === "approved") {
        await notifyGroup(groupId, txId, `${txId}_approved`, {
          tx: after,
          type: "expense_approved",
          title: "Expense approved",
          message: "The expense is approved and included in group totals.",
          requiresAction: false,
        });
      } else if (["disputed", "rejected"].includes(after.status)) {
        const rejectedBy = await getMemberName(groupId, after.rejectedBy);
        await notifyGroup(groupId, txId, `${txId}_disputed`, {
          tx: after,
          type: "expense_disputed",
          title: "Expense disputed",
          message: `${rejectedBy} rejected this expense. It is excluded from totals.`,
          requiresAction: false,
        });
      }
      return;
    }

    const beforeUpdatedAt = before.updatedAt?.toMillis?.() || 0;
    const afterUpdatedAt = after.updatedAt?.toMillis?.() || 0;
    if (afterUpdatedAt > beforeUpdatedAt) {
      const editorName = await getMemberName(groupId, after.updatedBy);
      await notifyGroup(groupId, txId, `${txId}_edited_${change.after.updateTime.toMillis()}`, {
        tx: after,
        type: "expense_edited",
        title: "Expense edited",
        message: `${editorName} edited this expense.`,
        requiresAction: after.status === "pending",
      });
    }
  });
