const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

function groupTxPath(groupId, txId) {
  return `groups/${groupId}/tx/${txId}`;
}

async function getGroupMemberUids(groupId) {
  const g = await admin.firestore().doc(`groups/${groupId}`).get();
  const data = g.data() || {};
  return data.memberUids || [];
}

async function getTokensForUsers(uids) {
  const tokens = [];
  await Promise.all(
    uids.map(async (uid) => {
      const snap = await admin.firestore().collection(`users/${uid}/fcmTokens`).get();
      snap.forEach((d) => {
        const t = d.id;
        if (t) tokens.push(t);
      });
    })
  );
  return tokens;
}

async function sendToUsers(uids, title, body, data = {}) {
  const tokens = await getTokensForUsers(uids);
  if (!tokens.length) return;

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
  });
}

exports.onTxCreate = functions.firestore
  .document("groups/{groupId}/tx/{txId}")
  .onCreate(async (snap, ctx) => {
    const { groupId, txId } = ctx.params;
    const tx = snap.data() || {};
    if (tx.type !== "expense") return;
    if (tx.status !== "pending") return;

    const members = await getGroupMemberUids(groupId);
    const category = tx.category || "expense";
    const amount = tx.amount || 0;

    await sendToUsers(
      members,
      "SplitNest: Approval needed",
      `New pending ${category} • ${amount}`,
      { groupId, txId, path: groupTxPath(groupId, txId) }
    );
  });

exports.onTxUpdate = functions.firestore
  .document("groups/{groupId}/tx/{txId}")
  .onUpdate(async (change, ctx) => {
    const { groupId, txId } = ctx.params;
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    if (before.status === after.status) return;
    if (after.type !== "expense") return;

    const members = await getGroupMemberUids(groupId);
    const category = after.category || "expense";
    const amount = after.amount || 0;

    if (after.status === "approved") {
      await sendToUsers(
        members,
        "SplitNest: Approved",
        `${category} • ${amount} approved`,
        { groupId, txId, status: "approved" }
      );
    } else if (after.status === "rejected") {
      await sendToUsers(
        members,
        "SplitNest: Rejected",
        `${category} • ${amount} rejected`,
        { groupId, txId, status: "rejected" }
      );
    }
  });
