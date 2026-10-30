// Runs the REAL Cloud Functions (built into ../functions/lib) against the Auth,
// Firestore and Functions emulators, plus the real firestore.rules for the
// client-side checks. Run with: npm run test:functions
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { before, describe, it } from "node:test";
import assert from "node:assert/strict";
import { initializeApp as initClient } from "firebase/app";
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword, signOut } from "firebase/auth";
import { connectFirestoreEmulator, doc, getDoc, getFirestore, updateDoc } from "firebase/firestore";
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions";

// Use the very same firebase-admin copy the functions use (two copies would
// disagree about FieldValue and friends).
const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { provisionDirector } = require("./lib/provision.js");
const { initializeApp: initAdmin } = require("firebase-admin/app");
const { getAuth: adminAuth } = require("firebase-admin/auth");
const { getFirestore: adminDb } = require("firebase-admin/firestore");

const PROJECT = "demo-quran-center";
const admin = initAdmin({ projectId: PROJECT });
const aauth = adminAuth(admin);
const adb = adminDb(admin);

const client = initClient({ projectId: PROJECT, apiKey: "demo-key" });
const cauth = getAuth(client);
connectAuthEmulator(cauth, "http://127.0.0.1:9099", { disableWarnings: true });
const cdb = getFirestore(client);
const [fsHost, fsPort] = process.env.FIRESTORE_EMULATOR_HOST.split(":");
connectFirestoreEmulator(cdb, fsHost, Number(fsPort));
const fns = getFunctions(client);
connectFunctionsEmulator(fns, "127.0.0.1", 5001);

const call = (name, data) => httpsCallable(fns, name)(data).then((r) => r.data);
const code = (e) => e?.code ?? "";

async function signInAs(email, password) {
  await signOut(cauth).catch(() => {});
  await signInWithEmailAndPassword(cauth, email, password);
  // Force a fresh token so newly set claims are present.
  await cauth.currentUser.getIdToken(true);
}

let directorUid;
const DIR_EMAIL = "director@example.com";
const PASSWORD = "test-only-pass-123";

before(async () => {
  const r = await provisionDirector(aauth, adb, {
    email: DIR_EMAIL, fullName: "مديرة الدار", centerId: "center-a", centerName: "دار النور",
  });
  directorUid = r.uid;
  assert.match(r.passwordSetupLink, /^http/);
  // The test sets its own password; provisioning itself never invents one.
  await aauth.updateUser(directorUid, { password: PASSWORD });
});

describe("director provisioning", () => {
  it("creates the account, claims, profile, center and audit entry", async () => {
    const user = await aauth.getUser(directorUid);
    assert.deepEqual(user.customClaims, { role: "director", centerId: "center-a" });
    const profile = (await adb.doc(`users/${directorUid}`).get()).data();
    assert.equal(profile.role, "director");
    assert.equal(profile.status, "active");
    assert.equal(profile.centerId, "center-a");
    assert.equal((await adb.doc("centers/center-a").get()).data().name, "دار النور");
    const audits = await adb.collection("audit_logs").where("action", "==", "provision_director").get();
    assert.equal(audits.size, 1);
  });
  it("refuses an existing email or an existing center, leaving nothing behind", async () => {
    await assert.rejects(provisionDirector(aauth, adb, { email: DIR_EMAIL, fullName: "x y", centerId: "center-b", centerName: "دار ب" }), /already has an account/);
    await assert.rejects(provisionDirector(aauth, adb, { email: "other@example.com", fullName: "x y", centerId: "center-a", centerName: "دار ب" }), /already exists/);
    await assert.rejects(aauth.getUserByEmail("other@example.com"), (e) => e.code === "auth/user-not-found");
  });
  it("validates its input", async () => {
    for (const bad of [
      { email: "nope", fullName: "اسم كامل", centerId: "c-ok", centerName: "دار" },
      { email: "a@b.co", fullName: "x", centerId: "c-ok", centerName: "دار ما" },
      { email: "a@b.co", fullName: "اسم كامل", centerId: "Bad Id!", centerName: "دار ما" },
    ]) {
      await assert.rejects(provisionDirector(aauth, adb, bad));
    }
  });
});

describe("createTeacher / setTeacherSuspended", () => {
  const T_EMAIL = "teacher1@example.com";
  let teacherUid;

  it("rejects unauthenticated callers", async () => {
    await signOut(cauth);
    await assert.rejects(call("createTeacher", { fullName: "معلمة جديدة", email: T_EMAIL }), (e) => code(e) === "functions/unauthenticated");
  });

  it("a director creates a teacher: account, claims, profile, record, audit", async () => {
    await signInAs(DIR_EMAIL, PASSWORD);
    const r = await call("createTeacher", { fullName: "  معلمة   جديدة ", email: "Teacher1@Example.com", phone: "0500000000" });
    teacherUid = r.uid;
    const user = await aauth.getUser(teacherUid);
    assert.equal(user.email, T_EMAIL);
    assert.deepEqual(user.customClaims, { role: "teacher", centerId: "center-a" });
    const profile = (await adb.doc(`users/${teacherUid}`).get()).data();
    assert.equal(profile.role, "teacher");
    assert.equal(profile.centerId, "center-a");
    const teacher = (await adb.doc(`teachers/${teacherUid}`).get()).data();
    assert.equal(teacher.fullName, "معلمة جديدة");
    assert.equal(teacher.userId, teacherUid);
    assert.equal(teacher.contactInfo.phone, "0500000000");
    const audits = await adb.collection("audit_logs").where("action", "==", "create_teacher").get();
    assert.equal(audits.docs[0].data().actorUserId, directorUid);
  });

  it("refuses an email that already has an account (no takeover)", async () => {
    await assert.rejects(call("createTeacher", { fullName: "معلمة ثانية", email: T_EMAIL }), (e) => code(e) === "functions/already-exists" || /already/i.test(e.message));
    await assert.rejects(call("createTeacher", { fullName: "مديرة", email: DIR_EMAIL }), (e) => /already/i.test(e.message) || code(e) === "functions/already-exists");
    const profile = (await adb.doc(`users/${directorUid}`).get()).data();
    assert.equal(profile.role, "director"); // untouched
  });

  it("validates input", async () => {
    await assert.rejects(call("createTeacher", { fullName: "x", email: "teacher2@example.com" }), (e) => code(e) === "functions/invalid-argument");
    await assert.rejects(call("createTeacher", { fullName: "معلمة ثالثة", email: "not-an-email" }), (e) => code(e) === "functions/invalid-argument");
  });

  it("the new teacher can sign in once they have a password and is NOT a director", async () => {
    await aauth.updateUser(teacherUid, { password: PASSWORD });
    await signInAs(T_EMAIL, PASSWORD);
    // Rules: a teacher reads their own profile...
    const own = await getDoc(doc(cdb, `users/${teacherUid}`));
    assert.equal(own.data().role, "teacher");
    // ...cannot read a director's profile, and cannot promote themselves.
    await assert.rejects(getDoc(doc(cdb, `users/${directorUid}`)));
    await assert.rejects(updateDoc(doc(cdb, `users/${teacherUid}`), { role: "director" }));
    // ...and the functions refuse them.
    await assert.rejects(call("createTeacher", { fullName: "معلمة رابعة", email: "t4@example.com" }), (e) => code(e) === "functions/permission-denied");
    await assert.rejects(call("setTeacherSuspended", { teacherId: teacherUid, suspend: true }), (e) => code(e) === "functions/permission-denied");
  });

  it("suspending disables the login, updates both records, and is audited; repeating is refused", async () => {
    await signInAs(DIR_EMAIL, PASSWORD);
    await call("setTeacherSuspended", { teacherId: teacherUid, suspend: true });
    assert.equal((await aauth.getUser(teacherUid)).disabled, true);
    assert.equal((await adb.doc(`teachers/${teacherUid}`).get()).data().status, "suspended");
    assert.equal((await adb.doc(`users/${teacherUid}`).get()).data().status, "suspended");
    await assert.rejects(call("setTeacherSuspended", { teacherId: teacherUid, suspend: true }), (e) => code(e) === "functions/failed-precondition");
    // A suspended teacher cannot sign in.
    await assert.rejects(signInAs(T_EMAIL, PASSWORD));
    await signInAs(DIR_EMAIL, PASSWORD);
    await call("setTeacherSuspended", { teacherId: teacherUid, suspend: false });
    assert.equal((await aauth.getUser(teacherUid)).disabled, false);
    assert.equal((await adb.doc(`users/${teacherUid}`).get()).data().status, "active");
  });

  it("unknown ids and other centers' teachers are both 'not found'", async () => {
    await assert.rejects(call("setTeacherSuspended", { teacherId: "ghost", suspend: true }), (e) => code(e) === "functions/not-found");
    // A second center with its own director.
    const other = await provisionDirector(aauth, adb, { email: "dir-b@example.com", fullName: "مدير آخر", centerId: "center-b", centerName: "دار ب" });
    await aauth.updateUser(other.uid, { password: PASSWORD });
    await signInAs("dir-b@example.com", PASSWORD);
    await assert.rejects(call("setTeacherSuspended", { teacherId: teacherUid, suspend: true }), (e) => code(e) === "functions/not-found");
    assert.equal((await adb.doc(`teachers/${teacherUid}`).get()).data().status, "active");
  });
});

describe("student access", () => {
  const S_EMAIL = "student1@example.com";
  let studentLoginUid;

  before(async () => {
    await adb.doc("students/stu-1").set({
      centerId: "center-a", fullName: "طالب تجريبي", accountMode: "none",
      enrollmentStatus: "active", assignedTeacherIds: [], educationalLevel: "مبتدئ",
    });
    await adb.doc("students/stu-b").set({
      centerId: "center-b", fullName: "طالب مركز آخر", accountMode: "none",
      enrollmentStatus: "active", assignedTeacherIds: [], educationalLevel: "مبتدئ",
    });
  });

  it("enabling access links a login, sets the student claim and profile link", async () => {
    await signInAs(DIR_EMAIL, PASSWORD);
    const r = await call("enableStudentAccess", { studentId: "stu-1", email: S_EMAIL });
    studentLoginUid = r.uid;
    const user = await aauth.getUser(studentLoginUid);
    assert.deepEqual(user.customClaims, { role: "student", centerId: "center-a", studentId: "stu-1" });
    const student = (await adb.doc("students/stu-1").get()).data();
    assert.equal(student.accountMode, "loginEnabled");
    assert.equal(student.authUserId, studentLoginUid);
    const profile = (await adb.doc(`users/${studentLoginUid}`).get()).data();
    assert.equal(profile.role, "student");
    assert.equal(profile.studentId, "stu-1");
  });

  it("a second enable is refused and creates no extra account", async () => {
    await assert.rejects(call("enableStudentAccess", { studentId: "stu-1", email: "student-dup@example.com" }), (e) => code(e) === "functions/failed-precondition");
    await assert.rejects(aauth.getUserByEmail("student-dup@example.com"), (e) => e.code === "auth/user-not-found");
  });

  it("another center's student cannot be reached", async () => {
    await assert.rejects(call("enableStudentAccess", { studentId: "stu-b", email: "x-b@example.com" }), (e) => code(e) === "functions/not-found");
  });

  it("the student can read their own profile but not the director's, and cannot edit their link", async () => {
    await aauth.updateUser(studentLoginUid, { password: PASSWORD });
    await signInAs(S_EMAIL, PASSWORD);
    const own = await getDoc(doc(cdb, "students/stu-1"));
    assert.equal(own.data().fullName, "طالب تجريبي");
    await assert.rejects(getDoc(doc(cdb, "students/stu-b")));
    await assert.rejects(updateDoc(doc(cdb, "students/stu-1"), { authUserId: "someone" }));
    await assert.rejects(call("enableStudentAccess", { studentId: "stu-1", email: "z@example.com" }), (e) => code(e) === "functions/permission-denied");
  });

  it("suspending blocks sign-in; reactivating restores it", async () => {
    await signInAs(DIR_EMAIL, PASSWORD);
    await call("setStudentAccessSuspended", { studentId: "stu-1", suspend: true });
    assert.equal((await aauth.getUser(studentLoginUid)).disabled, true);
    assert.equal((await adb.doc("students/stu-1").get()).data().accountMode, "suspended");
    await assert.rejects(signInAs(S_EMAIL, PASSWORD));
    await signInAs(DIR_EMAIL, PASSWORD);
    await call("setStudentAccessSuspended", { studentId: "stu-1", suspend: false });
    assert.equal((await adb.doc("students/stu-1").get()).data().accountMode, "loginEnabled");
    await signInAs(S_EMAIL, PASSWORD); // works again
  });
});
