const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

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

async function sendDirectPush(uids, title, body, data) {
  const tokens = await getTokensForUsers(uids);
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)]),
    ),
    android: { priority: "high" },
  });
}

async function ensurePublicId(uid) {
  const userRef = db.doc(`users/${uid}`);
  for (let attempt = 0; attempt < 30; attempt += 1) {
    let normalizedId = String(crypto.randomInt(1, 10));
    for (let digit = 1; digit < 10; digit += 1) {
      normalizedId += String(crypto.randomInt(0, 10));
    }
    const idRef = db.doc(`publicIds/${normalizedId}`);
    const result = await db.runTransaction(async (transaction) => {
      const [userSnapshot, idSnapshot] = await Promise.all([
        transaction.get(userRef),
        transaction.get(idRef),
      ]);
      if (userSnapshot.data()?.publicId) return userSnapshot.data().publicId;
      if (idSnapshot.exists) return null;
      transaction.set(idRef, { uid });
      transaction.set(userRef, { publicId: normalizedId }, { merge: true });
      return normalizedId;
    });
    if (result) return result;
  }
  throw new Error(`Unable to allocate public ID for ${uid}`);
}

exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
  await ensurePublicId(user.uid);
});

exports.onFriendRequestCreate = functions.firestore
  .document("friendRequests/{requestId}")
  .onCreate(async (snapshot) => {
    const request = snapshot.data() || {};
    if (!request.toUid) return;
    await sendDirectPush(
      [request.toUid],
      "New friend request",
      `${request.fromName || "A user"} wants to connect with you.`,
      { type: "friend_request", path: "/app/chat" },
    );
  });

exports.onFriendRequestUpdate = functions.firestore
  .document("friendRequests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === after.status || after.status !== "accepted") return;
    const receiver = await db.doc(`users/${after.toUid}`).get();
    await sendDirectPush(
      [after.fromUid],
      "Friend request accepted",
      `${receiver.data()?.name || "Your friend"} accepted your request.`,
      { type: "friend_accepted", path: `/chat/${after.toUid}` },
    );
  });

exports.onChatMessageCreate = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() || {};
    const chat = await db.doc(`chats/${context.params.chatId}`).get();
    const members = chat.data()?.memberUids || [];
    const recipients = members.filter((uid) => uid !== message.senderUid);
    if (!recipients.length) return;
    const sender = await db.doc(`users/${message.senderUid}`).get();
    await sendDirectPush(
      recipients,
      sender.data()?.name || "New message",
      message.text || "Sent you a message",
      {
        type: "chat_message",
        chatId: context.params.chatId,
        senderUid: message.senderUid,
        path: `/chat/${message.senderUid}`,
      },
    );
  });

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

exports.onTxDelete = functions.firestore
  .document("groups/{groupId}/tx/{txId}")
  .onDelete(async (snapshot, context) => {
    const { groupId, txId } = context.params;
    const tx = snapshot.data() || {};
    if (tx.type !== "expense") return;

    await notifyGroup(groupId, txId, `${txId}_deleted`, {
      tx,
      type: "expense_deleted",
      title: "Expense deleted",
      message: "A group admin deleted this expense. It has been removed from group totals.",
      requiresAction: false,
    });
  });
