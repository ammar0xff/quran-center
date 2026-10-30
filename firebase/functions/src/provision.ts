import { Auth } from "firebase-admin/auth";
import { FieldValue, Firestore } from "firebase-admin/firestore";
import { cleanName, isPlausibleEmail } from "./accessRules";

export interface ProvisionInput {
  email: string;
  fullName: string;
  centerId: string;
  centerName: string;
}

export interface ProvisionResult {
  uid: string;
  /** One-time link the operator sends to the director to choose a password. */
  passwordSetupLink: string;
}

const centerIdPattern = /^[a-z0-9][a-z0-9_-]{1,62}$/;

/**
 * Creates (or completes) the FIRST director of a center: the Auth account, the
 * `role` / `centerId` custom claims the Cloud Functions authorize from, the
 * authoritative `users/{uid}` profile the Security Rules read, and the center
 * document.
 *
 * No password is invented or stored: the account is created without one and
 * the returned link lets the director set their own.
 *
 * Refuses an email that already has an account, so it can never take over or
 * re-role an existing user, and refuses a center that already exists, so it
 * cannot add a director to someone else's center by accident. A failure part
 * way removes the account it created.
 */
export async function provisionDirector(
  auth: Auth,
  db: Firestore,
  input: ProvisionInput
): Promise<ProvisionResult> {
  const email = input.email.trim().toLowerCase();
  const fullName = cleanName(input.fullName);
  const centerId = input.centerId.trim();
  const centerName = cleanName(input.centerName);
  if (!isPlausibleEmail(email)) throw new Error("A valid email is required.");
  if (fullName === null) throw new Error("A valid director name is required.");
  if (centerName === null) throw new Error("A valid center name is required.");
  if (!centerIdPattern.test(centerId)) {
    throw new Error("centerId must be 2-63 chars of a-z, 0-9, '-' or '_'.");
  }

  if ((await db.doc(`centers/${centerId}`).get()).exists) {
    throw new Error(`Center "${centerId}" already exists.`);
  }
  try {
    await auth.getUserByEmail(email);
    throw new Error("That email already has an account.");
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
  }

  const user = await auth.createUser({ email, displayName: fullName, emailVerified: false });
  try {
    await auth.setCustomUserClaims(user.uid, { role: "director", centerId });
    const batch = db.batch();
    batch.set(db.doc(`centers/${centerId}`), {
      name: centerName,
      status: "active",
      createdBy: user.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.doc(`users/${user.uid}`), {
      centerId,
      fullName,
      role: "director",
      status: "active",
      authProvider: "password",
      assignedCenterIds: [centerId],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("audit_logs").doc(), {
      centerId,
      actorUserId: user.uid,
      actorRole: "provisioning",
      action: "provision_director",
      entityType: "user",
      entityId: user.uid,
      newValue: { role: "director" },
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    const passwordSetupLink = await auth.generatePasswordResetLink(email);
    return { uid: user.uid, passwordSetupLink };
  } catch (e) {
    await auth.deleteUser(user.uid).catch(() => undefined);
    throw e;
  }
}
