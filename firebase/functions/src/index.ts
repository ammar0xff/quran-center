import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import {
  AccessAction,
  AccessBlock,
  checkAccessAction,
  isPlausibleEmail,
  StudentAccessState,
} from "./accessRules";

initializeApp();
const db = getFirestore();
const auth = getAuth();

interface Caller {
  uid: string;
  centerId: string;
}

/**
 * Authorizes a director. Role and centerId come ONLY from the verified ID
 * token custom claims (set by trusted provisioning), never from request data.
 * The director's own profile must also still be active, so a suspended
 * director holding an unexpired token is rejected.
 */
async function requireDirector(request: CallableRequest<unknown>): Promise<Caller> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const token = request.auth.token;
  const centerId = token["centerId"];
  if (token["role"] !== "director" || typeof centerId !== "string" || centerId === "") {
    throw new HttpsError("permission-denied", "Directors only.");
  }
  const profile = await db.doc(`users/${request.auth.uid}`).get();
  const data = profile.data();
  if (!data || data["status"] !== "active" || data["centerId"] !== centerId) {
    throw new HttpsError("permission-denied", "Account is not active.");
  }
  return { uid: request.auth.uid, centerId };
}

const blockMessages: Record<AccessBlock, string> = {
  alreadyHasLogin: "This student already has a login.",
  noLoginToChange: "This student has no login to change.",
  notSuspended: "This student's access is not suspended.",
  alreadySuspended: "This student's access is already suspended.",
  archivedStudent: "Archived students cannot be given access.",
  missingLink: "The student is marked as having a login but no account is linked.",
};

function assertAllowed(state: StudentAccessState, action: AccessAction): void {
  const block = checkAccessAction(state, action);
  if (block) throw new HttpsError("failed-precondition", blockMessages[block]);
}

function toState(data: FirebaseFirestore.DocumentData): StudentAccessState {
  return {
    accountMode: data["accountMode"] ?? "none",
    authUserId: data["authUserId"] ?? null,
    enrollmentStatus: data["enrollmentStatus"] ?? "active",
  };
}

/**
 * Loads a student that belongs to the caller's center. Unknown ids and
 * other-center ids are indistinguishable (both "not-found") so ids cannot be
 * probed across centers.
 */
async function loadStudent(
  studentId: string,
  centerId: string
): Promise<{ ref: FirebaseFirestore.DocumentReference; data: FirebaseFirestore.DocumentData }> {
  const ref = db.doc(`students/${studentId}`);
  const snap = await ref.get();
  const data = snap.data();
  if (!data || data["centerId"] !== centerId) {
    throw new HttpsError("not-found", "Student not found.");
  }
  return { ref, data };
}

function readString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

async function createAuthUser(email: string, displayName: string): Promise<string> {
  try {
    const user = await auth.createUser({
      email,
      emailVerified: false,
      disabled: false,
      displayName,
    });
    return user.uid;
  } catch (e) {
    // Never attach a student to a pre-existing account: that would let
    // someone take over another person's identity.
    if ((e as { code?: string }).code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "This email is already in use.");
    }
    throw new HttpsError("internal", "Could not create the account.");
  }
}

/**
 * Creates a login for an EXISTING accountless student and links it to the
 * student's profile. No duplicate student is created. The client then calls
 * sendPasswordResetEmail(email) so Firebase emails the activation link; no
 * credentials or links are returned from here.
 */
export const enableStudentAccess = onCall(async (request) => {
  const caller = await requireDirector(request);
  const input = (request.data ?? {}) as Record<string, unknown>;
  const studentId = readString(input["studentId"]);
  const email = readString(input["email"]).trim().toLowerCase();
  if (studentId === "") throw new HttpsError("invalid-argument", "studentId is required.");
  if (!isPlausibleEmail(email)) throw new HttpsError("invalid-argument", "A valid email is required.");

  const { ref, data } = await loadStudent(studentId, caller.centerId);
  assertAllowed(toState(data), "enable");

  const uid = await createAuthUser(email, readString(data["fullName"]));
  try {
    await auth.setCustomUserClaims(uid, {
      role: "student",
      centerId: caller.centerId,
      studentId,
    });
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const current = fresh.data();
      if (!current || current["centerId"] !== caller.centerId) {
        throw new HttpsError("not-found", "Student not found.");
      }
      // Re-check inside the transaction: another request may have linked
      // an account since we first read.
      assertAllowed(toState(current), "enable");

      tx.update(ref, {
        authUserId: uid,
        accountMode: "loginEnabled",
        updatedBy: caller.uid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.doc(`users/${uid}`), {
        centerId: caller.centerId,
        fullName: readString(current["fullName"]),
        role: "student",
        status: "active",
        authProvider: "password",
        studentId,
        assignedCenterIds: [caller.centerId],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.collection("audit_logs").doc(), {
        centerId: caller.centerId,
        actorUserId: caller.uid,
        actorRole: "director",
        action: "enable_student_access",
        entityType: "student",
        entityId: studentId,
        previousValue: { accountMode: "none" },
        newValue: { accountMode: "loginEnabled", authUserId: uid },
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    // Roll back so a failed link does not leave an orphan login behind.
    await auth.deleteUser(uid).catch(() => undefined);
    throw e instanceof HttpsError ? e : new HttpsError("internal", "Could not link the account.");
  }
  return { uid };
});

/**
 * Suspends or reactivates a student's login. Educational history is
 * untouched. The Auth change happens first (so suspension takes effect
 * immediately); if the bookkeeping transaction then fails, the Auth change
 * is reverted. Firestore rules additionally require users/{uid}.status to be
 * "active", so data access stays blocked even if an Auth state ever lagged.
 */
export const setStudentAccessSuspended = onCall(async (request) => {
  const caller = await requireDirector(request);
  const input = (request.data ?? {}) as Record<string, unknown>;
  const studentId = readString(input["studentId"]);
  const suspend = input["suspend"];
  if (studentId === "") throw new HttpsError("invalid-argument", "studentId is required.");
  if (typeof suspend !== "boolean") throw new HttpsError("invalid-argument", "suspend must be a boolean.");

  const action: AccessAction = suspend ? "suspend" : "reactivate";
  const { ref, data } = await loadStudent(studentId, caller.centerId);
  assertAllowed(toState(data), action);

  const uid = readString(data["authUserId"]);
  const newMode = suspend ? "suspended" : "loginEnabled";
  const previousMode = suspend ? "loginEnabled" : "suspended";

  await auth.updateUser(uid, { disabled: suspend });
  if (suspend) await auth.revokeRefreshTokens(uid);

  try {
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(ref);
      const current = fresh.data();
      if (!current || current["centerId"] !== caller.centerId) {
        throw new HttpsError("not-found", "Student not found.");
      }
      assertAllowed(toState(current), action);

      tx.update(ref, {
        accountMode: newMode,
        updatedBy: caller.uid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(db.doc(`users/${uid}`), {
        status: suspend ? "suspended" : "active",
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.collection("audit_logs").doc(), {
        centerId: caller.centerId,
        actorUserId: caller.uid,
        actorRole: "director",
        action: suspend ? "suspend_student_access" : "reactivate_student_access",
        entityType: "student",
        entityId: studentId,
        previousValue: { accountMode: previousMode },
        newValue: { accountMode: newMode },
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    await auth.updateUser(uid, { disabled: !suspend }).catch(() => undefined);
    throw e instanceof HttpsError ? e : new HttpsError("internal", "Could not update access.");
  }
  return { accountMode: newMode };
});
