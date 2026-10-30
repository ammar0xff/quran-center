// Fills the LOCAL emulators with a small demo center so the app can be tried.
// Usage (emulators must be running):  node seed-demo.mjs
// Demo logins (emulator only, throwaway):  director@demo.test / teacher@demo.test / student@demo.test
// all with the password below.
import { createRequire } from "node:module";
import { initializeApp as initClient } from "firebase/app";
import { connectAuthEmulator, getAuth, signInWithEmailAndPassword } from "firebase/auth";
import { connectFunctionsEmulator, getFunctions, httpsCallable } from "firebase/functions";

process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8189";
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";

const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { provisionDirector } = require("./lib/provision.js");
const { initializeApp: initAdmin } = require("firebase-admin/app");
const { getAuth: adminAuth } = require("firebase-admin/auth");
const { getFirestore: adminDb, Timestamp } = require("firebase-admin/firestore");

const PASSWORD = "demo-pass-123";
const admin = initAdmin({ projectId: "demo-quran-center" });
const auth = adminAuth(admin);
const db = adminDb(admin);
const ts = (d) => Timestamp.fromDate(d);
const day = (offset) => { const n = new Date(); return new Date(n.getFullYear(), n.getMonth(), n.getDate() + offset); };

const client = initClient({ projectId: "demo-quran-center", apiKey: "demo-key" }, "seed");
const cauth = getAuth(client);
connectAuthEmulator(cauth, "http://127.0.0.1:9099", { disableWarnings: true });
const fns = getFunctions(client);
connectFunctionsEmulator(fns, "127.0.0.1", 5001);
const call = (n, d) => httpsCallable(fns, n)(d).then((r) => r.data);

const C = "demo-center";
const d = await provisionDirector(auth, db, { email: "director@demo.test", fullName: "أم عبدالله", centerId: C, centerName: "دار النور لتحفيظ القرآن" });
await auth.updateUser(d.uid, { password: PASSWORD });
await signInWithEmailAndPassword(cauth, "director@demo.test", PASSWORD);
await cauth.currentUser.getIdToken(true);

// Created through the real Cloud Functions, like the app does.
const t = await call("createTeacher", { fullName: "المعلمة فاطمة الزهراء", email: "teacher@demo.test", phone: "0500000001" });
await auth.updateUser(t.uid, { password: PASSWORD });

const now = ts(new Date());
const circleBase = { centerId: C, educationalLevel: "متوسط", locationOrMode: "onsite", sessionDurationMinutes: 60, status: "active", createdAt: now, updatedAt: now };
await db.doc("circles/circle-fajr").set({
  ...circleBase, name: "حلقة الفجر", assignedTeacherId: t.uid, maxCapacity: 8, activeCount: 3,
  weeklySchedule: [{ dayOfWeek: 6, startTime: "05:30", endTime: "06:30" }, { dayOfWeek: 1, startTime: "05:30", endTime: "06:30" }],
});
await db.doc("circles/circle-maghrib").set({
  ...circleBase, name: "حلقة المغرب", educationalLevel: "مبتدئ", assignedTeacherId: null, maxCapacity: 10, activeCount: 0, weeklySchedule: [],
});

const students = [
  ["stu-1", "بسمة خالد", "متوسط"], ["stu-2", "أحمد علي", "متوسط"], ["stu-3", "مريم سعيد", "مبتدئ"],
];
for (const [id, name, level] of students) {
  await db.doc(`students/${id}`).set({
    centerId: C, fullName: name, enrollmentStatus: "active", accountMode: "none", authUserId: null,
    assignedTeacherIds: [t.uid], currentCircleId: "circle-fajr", educationalLevel: level,
    createdAt: now, updatedAt: now,
  });
  await db.doc(`enrollments/enr_${id}_circle-fajr_seed`).set({
    centerId: C, studentId: id, circleId: "circle-fajr", teacherId: t.uid, startDate: ts(day(-30)),
    status: "active", createdAt: now, updatedAt: now,
  });
}
const s = await call("enableStudentAccess", { studentId: "stu-1", email: "student@demo.test" });
await auth.updateUser(s.uid, { password: PASSWORD });

const session = (id, offset, status, start = "05:30", end = "06:30") =>
  db.doc(`schedules/${id}`).set({
    centerId: C, circleId: "circle-fajr", teacherId: t.uid, date: ts(day(offset)), startTime: start, endTime: end,
    locationOrMode: "onsite", status, createdAt: now, updatedAt: now,
  });
await session("sess-today", 0, "scheduled");
await session("sess-yesterday", -2, "completed");
await session("sess-next", 2, "scheduled");
for (const [sid, st] of [["stu-1", "present"], ["stu-2", "late"], ["stu-3", "absent"]]) {
  await db.doc(`attendance/sess-yesterday_${sid}`).set({
    centerId: C, sessionId: "sess-yesterday", studentId: sid, status: st, recordedBy: t.uid, createdAt: ts(day(-2)), updatedAt: ts(day(-2)),
  });
}
const task = (id, studentId, status, dueOffset, surah, from, to, extra = {}) =>
  db.doc(`learning_tasks/${id}`).set({
    centerId: C, planId: `plan_${studentId}_${t.uid}`, studentId, teacherId: t.uid, taskType: "recentRevision",
    surah, startAyah: from, endAyah: to, assignedDate: ts(day(-5)), dueDate: ts(day(dueOffset)),
    teacherInstructions: "كرّر الآيات عشر مرات قبل الحصة", status, createdAt: now, updatedAt: now, ...extra,
  });
await db.doc(`learning_plans/plan_stu-1_${t.uid}`).set({
  centerId: C, studentId: "stu-1", responsibleTeacherId: t.uid, educationalObjective: "متابعة الحفظ والمراجعة",
  startDate: ts(day(-30)), targetDate: ts(day(335)), status: "active", createdAt: now, updatedAt: now,
});
await task("task-1", "stu-1", "upcoming", 4, 112, 1, 4);
await task("task-2", "stu-1", "inProgress", -1, 113, 1, 5);
await task("task-3", "stu-2", "practiceReported", 3, 114, 1, 6, { selfReportedPractice: { reportedAt: ts(day(-1)) } });
await db.doc("memorization_records/m-1").set({
  centerId: C, studentId: "stu-1", teacherId: t.uid, sessionId: "sess-yesterday", circleId: "circle-fajr",
  assessmentType: "newMemorization", schemaVersion: 1, surah: 1, startAyah: 1, endAyah: 7,
  criteriaScores: { accuracy: 4, tajweed: 4 }, mistakesCount: 1, requiresFollowUp: false,
  studentVisibleFeedback: "أحسنتِ، واصلي بنفس الهمة", strengths: "إتقان وطلاقة",
  assessedAt: ts(day(-2)), createdAt: ts(day(-2)), updatedAt: ts(day(-2)),
});
console.log("Seeded. Logins (password " + PASSWORD + "): director@demo.test, teacher@demo.test, student@demo.test");
process.exit(0);
