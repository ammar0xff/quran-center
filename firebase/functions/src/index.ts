import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import {
  AccessAction,
  AccessBlock,
  checkAccessAction,
  checkTeacherAction,
  cleanName,
  isPlausibleEmail,
  StudentAccessState,
  TeacherAction,
  TeacherBlock,
  TeacherStatus,
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

async function createAuthUser(
  email: string,
  displayName: string,
  password?: string
): Promise<string> {
  try {
    const user = await auth.createUser({
      email,
      password: password && password.length >= 6 ? password : undefined,
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
  const temporaryPassword = readString(input["temporaryPassword"]);
  if (studentId === "") throw new HttpsError("invalid-argument", "studentId is required.");
  if (!isPlausibleEmail(email)) throw new HttpsError("invalid-argument", "A valid email is required.");
  if (temporaryPassword !== "" && temporaryPassword.length < 6) {
    throw new HttpsError("invalid-argument", "كلمة المرور المؤقتة يجب أن تكون 6 أحرف على الأقل.");
  }

  const { ref, data } = await loadStudent(studentId, caller.centerId);
  assertAllowed(toState(data), "enable");

  const uid = await createAuthUser(
    email,
    readString(data["fullName"]),
    temporaryPassword || undefined
  );
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
        mustChangePassword: temporaryPassword !== "",
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

const teacherBlockMessages: Record<TeacherBlock, string> = {
  alreadySuspended: "This teacher is already suspended.",
  notSuspended: "This teacher is not suspended.",
  archived: "Archived teachers cannot be changed.",
};

/**
 * Creates a teacher: the Auth account, its role claims, the authoritative
 * users/{uid} profile and the teachers/{uid} record (document id == uid, which
 * the Security Rules rely on) are created together. An email that already has
 * an account is refused, and a failure part-way removes the new account.
 * The client then calls sendPasswordResetEmail(email) to deliver activation.
 */
export const createTeacher = onCall(async (request) => {
  const caller = await requireDirector(request);
  const input = (request.data ?? {}) as Record<string, unknown>;
  const fullName = cleanName(input["fullName"]);
  const email = readString(input["email"]).trim().toLowerCase();
  const phone = readString(input["phone"]).trim();
  const notes = readString(input["professionalNotes"]).trim();
  const temporaryPassword = readString(input["temporaryPassword"]);
  if (fullName === null) throw new HttpsError("invalid-argument", "A valid name is required.");
  if (!isPlausibleEmail(email)) throw new HttpsError("invalid-argument", "A valid email is required.");
  if (temporaryPassword !== "" && temporaryPassword.length < 6) {
    throw new HttpsError("invalid-argument", "كلمة المرور المؤقتة يجب أن تكون 6 أحرف على الأقل.");
  }

  const uid = await createAuthUser(email, fullName, temporaryPassword || undefined);
  try {
    await auth.setCustomUserClaims(uid, { role: "teacher", centerId: caller.centerId });
    const batch = db.batch();
    batch.set(db.doc(`users/${uid}`), {
      centerId: caller.centerId,
      fullName,
      role: "teacher",
      status: "active",
      authProvider: "password",
      assignedCenterIds: [caller.centerId],
      mustChangePassword: temporaryPassword !== "",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.doc(`teachers/${uid}`), {
      centerId: caller.centerId,
      userId: uid,
      fullName,
      contactInfo: phone === "" ? { email } : { email, phone },
      ...(notes === "" ? {} : { professionalNotes: notes }),
      status: "active",
      assignedCircleIds: [],
      createdBy: caller.uid,
      updatedBy: caller.uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    batch.set(db.collection("audit_logs").doc(), {
      centerId: caller.centerId,
      actorUserId: caller.uid,
      actorRole: "director",
      action: "create_teacher",
      entityType: "teacher",
      entityId: uid,
      newValue: { status: "active" },
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } catch (e) {
    await auth.deleteUser(uid).catch(() => undefined);
    throw e instanceof HttpsError ? e : new HttpsError("internal", "Could not create the teacher.");
  }
  return { uid };
});

/**
 * Suspends or reactivates a teacher's login. The Auth change is applied first
 * (suspension takes effect immediately and sessions are revoked); if the
 * bookkeeping transaction then fails, the Auth change is reverted. Educational
 * records the teacher created are untouched.
 */
export const setTeacherSuspended = onCall(async (request) => {
  const caller = await requireDirector(request);
  const input = (request.data ?? {}) as Record<string, unknown>;
  const teacherId = readString(input["teacherId"]);
  const suspend = input["suspend"];
  if (teacherId === "") throw new HttpsError("invalid-argument", "teacherId is required.");
  if (typeof suspend !== "boolean") throw new HttpsError("invalid-argument", "suspend must be a boolean.");

  const action: TeacherAction = suspend ? "suspend" : "reactivate";
  const ref = db.doc(`teachers/${teacherId}`);
  const snap = await ref.get();
  const data = snap.data();
  // Unknown and other-center teachers are indistinguishable.
  if (!data || data["centerId"] !== caller.centerId) {
    throw new HttpsError("not-found", "Teacher not found.");
  }
  const assertTeacher = (status: unknown): void => {
    const block = checkTeacherAction((status ?? "active") as TeacherStatus, action);
    if (block) throw new HttpsError("failed-precondition", teacherBlockMessages[block]);
  };
  assertTeacher(data["status"]);

  await auth.updateUser(teacherId, { disabled: suspend });
  if (suspend) await auth.revokeRefreshTokens(teacherId);

  const newStatus = suspend ? "suspended" : "active";
  try {
    await db.runTransaction(async (tx) => {
      const fresh = (await tx.get(ref)).data();
      if (!fresh || fresh["centerId"] !== caller.centerId) {
        throw new HttpsError("not-found", "Teacher not found.");
      }
      assertTeacher(fresh["status"]);
      tx.update(ref, {
        status: newStatus,
        updatedBy: caller.uid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.update(db.doc(`users/${teacherId}`), {
        status: newStatus,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(db.collection("audit_logs").doc(), {
        centerId: caller.centerId,
        actorUserId: caller.uid,
        actorRole: "director",
        action: suspend ? "suspend_teacher" : "reactivate_teacher",
        entityType: "teacher",
        entityId: teacherId,
        previousValue: { status: suspend ? "active" : "suspended" },
        newValue: { status: newStatus },
        createdAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    await auth.updateUser(teacherId, { disabled: !suspend }).catch(() => undefined);
    throw e instanceof HttpsError ? e : new HttpsError("internal", "Could not update the teacher.");
  }
  return { status: newStatus };
});

/**
 * Self-service registration for a new Quran Center & Director.
 * Creates the Auth account, assigns director custom claims with 'unpaid' subscription,
 * provisions the center document with subscription status, creates director profile in users/{uid},
 * and logs to audit_logs.
 */
export const registerDirectorAndCenter = onCall(async (request) => {
  const input = (request.data ?? {}) as Record<string, unknown>;
  const email = readString(input["email"]).trim().toLowerCase();
  const password = readString(input["password"]);
  const fullName = cleanName(input["fullName"]);
  const centerName = cleanName(input["centerName"]);
  const centerSlug = readString(input["centerSlug"]).trim().toLowerCase();
  const phone = readString(input["phone"]).trim();

  if (!isPlausibleEmail(email)) throw new HttpsError("invalid-argument", "البريد الإلكتروني غير صالح.");
  if (password.length < 6) throw new HttpsError("invalid-argument", "كلمة المرور يجب أن تكون 6 أحرف على الأقل.");
  if (fullName === null) throw new HttpsError("invalid-argument", "اسم المدير غير صالح.");
  if (centerName === null) throw new HttpsError("invalid-argument", "اسم دار التحفيظ غير صالح.");
  if (!/^[a-z0-9][a-z0-9-]{1,30}$/.test(centerSlug)) {
    throw new HttpsError("invalid-argument", "معرف الدار يجب أن يتكون من 2 إلى 30 حرف إنجليزي أو رقم أو شرطة.");
  }

  // Ensure center slug is unique
  const centerSnap = await db.doc(`centers/${centerSlug}`).get();
  if (centerSnap.exists) {
    throw new HttpsError("already-exists", "رمز الدار محجوز بالفعل. الرجاء اختيار رمز آخر.");
  }

  // Ensure email is unique
  try {
    await auth.getUserByEmail(email);
    throw new HttpsError("already-exists", "هذا البريد الإلكتروني مسجل بالفعل.");
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found" && !(e instanceof HttpsError)) {
      throw e;
    }
    if (e instanceof HttpsError) throw e;
  }

  let uid: string;
  try {
    const user = await auth.createUser({
      email,
      password,
      displayName: fullName,
      emailVerified: false,
    });
    uid = user.uid;
  } catch (e) {
    throw new HttpsError("internal", "تعذر إنشاء حساب المستخدم.");
  }

  try {
    await auth.setCustomUserClaims(uid, {
      role: "director",
      centerId: centerSlug,
      subscriptionStatus: "unpaid",
    });

    const batch = db.batch();
    batch.set(db.doc(`centers/${centerSlug}`), {
      name: centerName,
      slug: centerSlug,
      status: "active",
      subscription: {
        status: "unpaid",
        tier: "none",
        billingCycle: "none",
        currency: "none",
        expiresAt: null,
      },
      phone: phone || null,
      createdBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    batch.set(db.doc(`users/${uid}`), {
      centerId: centerSlug,
      fullName,
      role: "director",
      status: "active",
      authProvider: "password",
      phone: phone || null,
      assignedCenterIds: [centerSlug],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    batch.set(db.collection("audit_logs").doc(), {
      centerId: centerSlug,
      actorUserId: uid,
      actorRole: "director",
      action: "register_center_and_director",
      entityType: "center",
      entityId: centerSlug,
      newValue: { centerName, role: "director" },
      createdAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return { uid, centerId: centerSlug, success: true };
  } catch (e) {
    await auth.deleteUser(uid).catch(() => undefined);
    throw e instanceof HttpsError ? e : new HttpsError("internal", "تعذر تسجيل الدار.");
  }
});

/**
 * Paymob transaction callback / webhook handler.
 * Verifies transaction notification, extracts center and plan info,
 * updates center subscription in Firestore, and updates director claims.
 */
export const paymobWebhook = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const body = req.body ?? {};
    const obj = (body.obj ?? body) as Record<string, unknown>;

    const isSuccess = obj["success"] === true || obj["success"] === "true";
    const transactionId = String(obj["id"] ?? "");
    const amountCents = Number(obj["amount_cents"] ?? 0);
    const currency = String(obj["currency"] ?? "EGP").toUpperCase();

    // The merchant_order_id or special_reference format: meshkah:<centerId>:<tier>:<cycle>:<currency>
    const orderObj = (obj["order"] ?? {}) as Record<string, unknown>;
    const orderRef = String(
      orderObj["merchant_order_id"] ??
      obj["merchant_order_id"] ??
      obj["special_reference"] ??
      ""
    );

    console.log(`[Paymob Webhook] Tx: ${transactionId}, Success: ${isSuccess}, Ref: ${orderRef}`);

    if (!orderRef.startsWith("meshkah:")) {
      res.status(200).json({ received: true, ignored: "non-meshkah order" });
      return;
    }

    const parts = orderRef.split(":");
    // parts: ['meshkah', centerId, tier, cycle, currency]
    const centerId = parts[1];
    const planTier = parts[2] ?? "starter";
    const billingCycle = parts[3] ?? "monthly";

    if (!centerId) {
      res.status(400).json({ error: "Missing centerId in reference" });
      return;
    }

    if (isSuccess) {
      // Calculate expiration: 30 days for monthly, 365 + 60 (2 months free) = 425 days for yearly
      const days = billingCycle === "yearly" ? 425 : 30;
      const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

      const centerRef = db.doc(`centers/${centerId}`);
      await db.runTransaction(async (tx) => {
        const centerSnap = await tx.get(centerRef);
        if (!centerSnap.exists) {
          throw new Error(`Center ${centerId} not found`);
        }

        tx.update(centerRef, {
          "subscription.status": "active",
          "subscription.tier": planTier,
          "subscription.billingCycle": billingCycle,
          "subscription.currency": currency,
          "subscription.amountCents": amountCents,
          "subscription.lastTransactionId": transactionId,
          "subscription.paidAt": FieldValue.serverTimestamp(),
          "subscription.expiresAt": expiresAt,
          updatedAt: FieldValue.serverTimestamp(),
        });

        tx.set(db.collection("audit_logs").doc(), {
          centerId,
          actorUserId: "paymob_gateway",
          actorRole: "system",
          action: "subscription_activated",
          entityType: "center",
          entityId: centerId,
          newValue: {
            tier: planTier,
            billingCycle,
            currency,
            amountCents,
            transactionId,
            expiresAt,
          },
          createdAt: FieldValue.serverTimestamp(),
        });
      });

      // Update director custom claims to active
      const usersSnap = await db.collection("users")
        .where("centerId", "==", centerId)
        .where("role", "==", "director")
        .get();

      for (const doc of usersSnap.docs) {
        await auth.setCustomUserClaims(doc.id, {
          role: "director",
          centerId,
          subscriptionStatus: "active",
        }).catch((err) => console.error("Error setting director claim:", err));
      }

      console.log(`[Paymob Webhook] Successfully activated subscription for center ${centerId}`);
    }

    res.status(200).json({ received: true, success: isSuccess });
  } catch (error) {
    console.error("[Paymob Webhook Error]", error);
    res.status(500).json({ error: (error as Error).message });
  }
});

