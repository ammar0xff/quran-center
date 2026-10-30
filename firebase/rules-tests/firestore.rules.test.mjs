import { readFileSync } from "node:fs";
import { before, after, beforeEach, describe, it } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { collection, deleteDoc, doc, getDoc, getDocs, query, setDoc, updateDoc, where, writeBatch } from "firebase/firestore";

let env;

const C1 = "c1";
const C2 = "c2";

// uid -> users/{uid} profile
const users = {
  dir1: { role: "director", centerId: C1, status: "active" },
  dir2: { role: "director", centerId: C2, status: "active" },
  dirSusp: { role: "director", centerId: C1, status: "suspended" },
  tA: { role: "teacher", centerId: C1, status: "active" },
  tB: { role: "teacher", centerId: C1, status: "active" },
  tSusp: { role: "teacher", centerId: C1, status: "suspended" },
  uS1: { role: "student", centerId: C1, status: "active", studentId: "s1" },
  uS2: { role: "student", centerId: C1, status: "active", studentId: "s2" },
};

const student = (over = {}) => ({
  centerId: C1,
  fullName: "طالب",
  enrollmentStatus: "active",
  accountMode: "none",
  authUserId: null,
  educationalLevel: "مبتدئ",
  assignedTeacherIds: [],
  ...over,
});

const att = (over = {}) => ({
  centerId: C1,
  sessionId: "sess1",
  studentId: "s1",
  status: "present",
  recordedBy: "tA",
  ...over,
});

const task = (over = {}) => ({
  centerId: C1, planId: "plan_s1_tA", studentId: "s1", teacherId: "tA",
  taskType: "newMemorization", surah: 2, startAyah: 1, endAyah: 5,
  assignedDate: new Date("2026-01-05"), dueDate: new Date("2026-01-12"),
  teacherInstructions: "راجع", status: "upcoming", ...over,
});

const rec = (over = {}) => ({
  centerId: C1, studentId: "s1", teacherId: "tA", sessionId: "sess9", circleId: "circle1",
  assessmentType: "newMemorization", surah: 2, startAyah: 1, endAyah: 5,
  criteriaScores: { accuracy: 4 }, mistakesCount: 0, requiresFollowUp: false, ...over,
});

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, p] of Object.entries(users)) await setDoc(doc(db, "users", uid), p);
    // s1 / s2 have logins; s3 is accountless; sx is in another center.
    await setDoc(doc(db, "students/s1"), student({ accountMode: "loginEnabled", authUserId: "uS1", assignedTeacherIds: ["tA"] }));
    await setDoc(doc(db, "students/s2"), student({ accountMode: "loginEnabled", authUserId: "uS2", assignedTeacherIds: ["tB"] }));
    await setDoc(doc(db, "students/s3"), student({ assignedTeacherIds: ["tA"] }));
    await setDoc(doc(db, "students/sx"), student({ centerId: C2, assignedTeacherIds: ["tA"] }));
    await setDoc(doc(db, "attendance/sess1_s1"), att());
    await setDoc(doc(db, "attendance/sess1_s2"), att({ studentId: "s2", recordedBy: "tB" }));
    const sess = (over) => ({ centerId: C1, circleId: "circle1", teacherId: "tA", date: new Date("2026-01-05"), status: "inProgress", ...over });
    await setDoc(doc(db, "schedules/sess1"), sess({ status: "completed" }));
    await setDoc(doc(db, "schedules/sess9"), sess());
    await setDoc(doc(db, "schedules/sessB"), sess({ teacherId: "tB" }));
    await setDoc(doc(db, "schedules/sessSched"), sess({ status: "scheduled" }));
    await setDoc(doc(db, "schedules/sessFuture"), sess({ status: "scheduled", date: new Date("2999-01-01") }));
    await setDoc(doc(db, "circles/circle1"), { centerId: C1, name: "A", assignedTeacherId: "tA" });
    await setDoc(doc(db, "circles/circle2"), { centerId: C1, name: "B", assignedTeacherId: "tB" });
    await setDoc(doc(db, "memorization_records/m1"), rec({ sessionId: "sess9" }));
    await setDoc(doc(db, "learning_plans/plan_s1_tA"), { centerId: C1, studentId: "s1", responsibleTeacherId: "tA", status: "active" });
    await setDoc(doc(db, "learning_tasks/t1"), task());
    await setDoc(doc(db, "learning_tasks/tReported"), task({ status: "practiceReported", selfReportedPractice: { reportedAt: new Date() } }));
    await setDoc(doc(db, "learning_tasks/tDone"), task({ status: "completed" }));
    await setDoc(doc(db, "private_teacher_notes/m1"), { centerId: C1, studentId: "s1", teacherId: "tA", note: "secret" });
  });
}

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-quran-center",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
  });
});
after(async () => env.cleanup());
beforeEach(seed);

describe("users: role escalation and profile access", () => {
  it("a user can read their own profile", async () => {
    await assertSucceeds(getDoc(doc(as("tA"), "users/tA")));
  });
  it("a suspended user can still read their own profile (to show the status screen)", async () => {
    await assertSucceeds(getDoc(doc(as("tSusp"), "users/tSusp")));
  });
  it("a teacher cannot read another user's profile", async () => {
    await assertFails(getDoc(doc(as("tA"), "users/dir1")));
  });
  it("a director can read profiles in their own center only", async () => {
    await assertSucceeds(getDoc(doc(as("dir1"), "users/tA")));
    await assertFails(getDoc(doc(as("dir2"), "users/tA")));
  });
  it("a teacher cannot grant themselves the director role", async () => {
    await assertFails(updateDoc(doc(as("tA"), "users/tA"), { role: "director" }));
  });
  it("a suspended user cannot re-activate themselves", async () => {
    await assertFails(updateDoc(doc(as("tSusp"), "users/tSusp"), { status: "active" }));
  });
  it("nobody can create a users document from a client, even a director", async () => {
    await assertFails(setDoc(doc(as("dir1"), "users/newUser"), { role: "director", centerId: C1, status: "active" }));
  });
  it("unauthenticated clients read nothing", async () => {
    await assertFails(getDoc(doc(anon(), "users/tA")));
  });
});

describe("students: access boundaries", () => {
  it("a student reads their own profile but not another student's", async () => {
    await assertSucceeds(getDoc(doc(as("uS1"), "students/s1")));
    await assertFails(getDoc(doc(as("uS1"), "students/s2")));
  });
  it("a teacher reads assigned students only", async () => {
    await assertSucceeds(getDoc(doc(as("tA"), "students/s1")));
    await assertFails(getDoc(doc(as("tA"), "students/s2")));
  });
  it("accountless student records stay protected", async () => {
    await assertFails(getDoc(doc(anon(), "students/s3"))); // guessing the id is not enough
    await assertFails(getDoc(doc(as("tB"), "students/s3"))); // unassigned teacher
    await assertFails(getDoc(doc(as("uS1"), "students/s3"))); // another student
    await assertSucceeds(getDoc(doc(as("tA"), "students/s3"))); // assigned teacher
    await assertSucceeds(getDoc(doc(as("dir1"), "students/s3"))); // director
  });
  it("cross-center access is denied", async () => {
    await assertFails(getDoc(doc(as("dir2"), "students/s3")));
    await assertFails(getDoc(doc(as("dir1"), "students/sx")));
    // even a teacher listed on the other-center student cannot read across centers
    await assertFails(getDoc(doc(as("tA"), "students/sx")));
  });
  it("suspended users cannot read protected data", async () => {
    await assertFails(getDoc(doc(as("tSusp"), "students/s3")));
    await assertFails(getDoc(doc(as("dirSusp"), "students/s3")));
  });
});

describe("director queries must be scoped to the center", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "enrollments/q1"), { centerId: C1, studentId: "s1", circleId: "cA", status: "active" });
      await setDoc(doc(db, "attendance/sq_s1"), { centerId: C1, sessionId: "sq", studentId: "s1", status: "present", recordedBy: "tA" });
      await setDoc(doc(db, "audit_logs/qa1"), { centerId: C1, entityType: "student", entityId: "s1", action: "x" });
    });
  });
  const cases = [
    ["enrollments", "studentId", "s1"],
    ["attendance", "studentId", "s1"],
    ["audit_logs", "entityId", "s1"],
  ];
  for (const [col, field, value] of cases) {
    it(`${col}: a query without centerId is refused, with centerId it works`, async () => {
      const db = as("dir1");
      await assertFails(getDocs(query(collection(db, col), where(field, "==", value))));
      await assertSucceeds(getDocs(query(collection(db, col), where("centerId", "==", C1), where(field, "==", value))));
    });
    it(`${col}: another center's director cannot query this center`, async () => {
      const db = as("dir2");
      await assertFails(getDocs(query(collection(db, col), where("centerId", "==", C1), where(field, "==", value))));
    });
  }
});

describe("enrollment assignment batch", () => {
  const enrollment = (o = {}) => ({
    centerId: C1, studentId: "s3", circleId: "cA", teacherId: "tB", status: "active", ...o,
  });
  it("a director can assign: new enrolment + student teacher + audit, then that teacher can read the student", async () => {
    await assertFails(getDoc(doc(as("tB"), "students/s3")));
    const db = as("dir1");
    const batch = writeBatch(db);
    batch.set(doc(db, "enrollments/enr1"), enrollment());
    batch.update(doc(db, "students/s3"), { assignedTeacherIds: ["tB"], updatedBy: "dir1" });
    batch.set(doc(db, "audit_logs/aud-assign-1"), {
      centerId: C1, actorUserId: "dir1", actorRole: "director",
      action: "assign_student", entityType: "student", entityId: "s3",
    });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(as("tB"), "students/s3")));
  });
  it("a director can close an old enrolment as transferred", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "enrollments/enrOld"), enrollment({ circleId: "cOld" }));
    });
    await assertSucceeds(updateDoc(doc(as("dir1"), "enrollments/enrOld"), { status: "transferred", changeReason: "نقل" }));
  });
  it("nobody can re-point an enrolment at another student or center", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "enrollments/enrOld"), enrollment());
    });
    await assertFails(updateDoc(doc(as("dir1"), "enrollments/enrOld"), { studentId: "s1" }));
    await assertFails(updateDoc(doc(as("dir1"), "enrollments/enrOld"), { centerId: C2 }));
  });
  it("teachers, students and other-center directors cannot assign", async () => {
    await assertFails(setDoc(doc(as("tA"), "enrollments/e2"), enrollment()));
    await assertFails(setDoc(doc(as("uS1"), "enrollments/e3"), enrollment({ studentId: "s1" })));
    await assertFails(setDoc(doc(as("dir2"), "enrollments/e4"), enrollment()));
    await assertFails(updateDoc(doc(as("tA"), "students/s3"), { assignedTeacherIds: ["tA"] }));
    await assertFails(updateDoc(doc(as("uS1"), "students/s1"), { assignedTeacherIds: ["tB"] }));
  });
  it("enrolments are never deleted", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "enrollments/enrOld"), enrollment());
    });
    await assertFails(deleteDoc(doc(as("dir1"), "enrollments/enrOld")));
  });
});

describe("students: writes", () => {
  it("a director can create an accountless student", async () => {
    await assertSucceeds(setDoc(doc(as("dir1"), "students/new1"), student()));
  });
  it("a student cannot be created with a login already attached", async () => {
    await assertFails(setDoc(doc(as("dir1"), "students/new2"), student({ accountMode: "loginEnabled" })));
    await assertFails(setDoc(doc(as("dir1"), "students/new3"), student({ authUserId: "someoneElse" })));
  });
  it("a director cannot create a student in another center", async () => {
    await assertFails(setDoc(doc(as("dir1"), "students/new4"), student({ centerId: C2 })));
  });
  it("teachers and students cannot create or edit students", async () => {
    await assertFails(setDoc(doc(as("tA"), "students/new5"), student()));
    await assertFails(updateDoc(doc(as("tA"), "students/s1"), { fullName: "x" }));
    await assertFails(updateDoc(doc(as("uS1"), "students/s1"), { fullName: "x" }));
  });
  it("a director can edit profile fields", async () => {
    await assertSucceeds(updateDoc(doc(as("dir1"), "students/s3"), { educationalLevel: "متقدم" }));
  });
  it("account linking cannot be done from the client (no takeover of another identity)", async () => {
    // attach a different login to a student
    await assertFails(updateDoc(doc(as("dir1"), "students/s3"), { authUserId: "uS1", accountMode: "loginEnabled" }));
    // re-point an existing link
    await assertFails(updateDoc(doc(as("dir1"), "students/s1"), { authUserId: "attacker" }));
    // flip the access mode directly
    await assertFails(updateDoc(doc(as("dir1"), "students/s1"), { accountMode: "none" }));
  });
  it("a student cannot be moved to another center", async () => {
    await assertFails(updateDoc(doc(as("dir1"), "students/s3"), { centerId: C2 }));
  });
  it("a director can archive a student together with its audit entry (one batch)", async () => {
    const db = as("dir1");
    const batch = writeBatch(db);
    batch.update(doc(db, "students/s3"), { enrollmentStatus: "archived", updatedBy: "dir1" });
    batch.set(doc(db, "audit_logs/aud-archive-1"), {
      centerId: C1, actorUserId: "dir1", actorRole: "director",
      action: "archive_student", entityType: "student", entityId: "s3",
    });
    await assertSucceeds(batch.commit());
  });
  it("teachers and students cannot archive, and a director cannot forge another actor in the audit entry", async () => {
    await assertFails(updateDoc(doc(as("tA"), "students/s3"), { enrollmentStatus: "archived" }));
    await assertFails(updateDoc(doc(as("uS1"), "students/s1"), { enrollmentStatus: "archived" }));
    const db = as("dir1");
    const batch = writeBatch(db);
    batch.update(doc(db, "students/s3"), { enrollmentStatus: "archived" });
    batch.set(doc(db, "audit_logs/aud-forged"), {
      centerId: C1, actorUserId: "dir2", action: "archive_student", entityType: "student", entityId: "s3",
    });
    await assertFails(batch.commit());
  });
  it("a director from another center cannot archive this center's student", async () => {
    await assertFails(updateDoc(doc(as("dir2"), "students/s3"), { enrollmentStatus: "archived" }));
  });
  it("students are never deleted", async () => {
    await assertFails(deleteDoc(doc(as("dir1"), "students/s3")));
  });
});

describe("attendance", () => {
  it("a student reads only their own attendance", async () => {
    await assertSucceeds(getDoc(doc(as("uS1"), "attendance/sess1_s1")));
    await assertFails(getDoc(doc(as("uS1"), "attendance/sess1_s2")));
  });
  it("a teacher records attendance for an assigned student", async () => {
    await assertSucceeds(setDoc(doc(as("tA"), "attendance/sess9_s3"), att({ sessionId: "sess9", studentId: "s3" })));
  });
  it("the deterministic id blocks duplicate / mismatched records", async () => {
    await assertFails(setDoc(doc(as("tA"), "attendance/random-id"), att({ sessionId: "sess9", studentId: "s3" })));
  });
  it("a teacher cannot record for an unassigned student or as someone else", async () => {
    await assertFails(setDoc(doc(as("tA"), "attendance/sess9_s2"), att({ sessionId: "sess9", studentId: "s2" })));
    await assertFails(setDoc(doc(as("tA"), "attendance/sess9_s3"), att({ sessionId: "sess9", studentId: "s3", recordedBy: "tB" })));
  });
  it("a teacher cannot forge correction metadata on create", async () => {
    await assertFails(setDoc(doc(as("tA"), "attendance/sess9_s3"),
      att({ sessionId: "sess9", studentId: "s3", correctionMetadata: { correctedBy: "tA" } })));
  });
  it("a student cannot create attendance", async () => {
    await assertFails(setDoc(doc(as("uS1"), "attendance/sess9_s1"), att({ sessionId: "sess9", recordedBy: "uS1" })));
  });
  it("once the session is completed, neither teacher nor student can change a record", async () => {
    await assertFails(updateDoc(doc(as("tA"), "attendance/sess1_s1"), { status: "absent" }));
    await assertFails(updateDoc(doc(as("uS1"), "attendance/sess1_s1"), { status: "present" }));
  });
  it("attendance can only be recorded for the teacher's own session that is in progress", async () => {
    const rec = (session) => att({ sessionId: session, studentId: "s3" });
    await assertFails(setDoc(doc(as("tA"), "attendance/sessB_s3"), rec("sessB")));        // someone else's session
    await assertFails(setDoc(doc(as("tA"), "attendance/sess1_s3"), rec("sess1")));        // completed
    await assertFails(setDoc(doc(as("tA"), "attendance/sessSched_s3"), rec("sessSched"))); // not started
    await assertFails(setDoc(doc(as("tA"), "attendance/ghost_s3"), rec("ghost")));        // no such session
    await assertSucceeds(setDoc(doc(as("tA"), "attendance/sess9_s3"), rec("sess9")));
  });
  it("a teacher may fix their own entry only while the session is in progress, and only status/note", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "attendance/sess9_s3"), att({ sessionId: "sess9", studentId: "s3" }));
    });
    await assertSucceeds(updateDoc(doc(as("tA"), "attendance/sess9_s3"), { status: "late", note: "تأخر" }));
    await assertFails(updateDoc(doc(as("tA"), "attendance/sess9_s3"), { status: "bogus" }));
    await assertFails(updateDoc(doc(as("tA"), "attendance/sess9_s3"), { studentId: "s1" }));
    await assertFails(updateDoc(doc(as("tA"), "attendance/sess9_s3"), { status: "absent", correctionMetadata: { correctedBy: "tA" } }));
    await assertFails(updateDoc(doc(as("tB"), "attendance/sess9_s3"), { status: "absent" })); // not the recorder
  });
  it("a director can correct, attributed to themselves", async () => {
    await assertSucceeds(updateDoc(doc(as("dir1"), "attendance/sess1_s1"), {
      status: "excused",
      correctionMetadata: { originalStatus: "present", correctedBy: "dir1", reason: "note" },
    }));
  });
  it("a correction must be attributed to the acting director and carry metadata", async () => {
    await assertFails(updateDoc(doc(as("dir1"), "attendance/sess1_s1"), { status: "excused" }));
    await assertFails(updateDoc(doc(as("dir1"), "attendance/sess1_s1"), {
      status: "excused",
      correctionMetadata: { originalStatus: "present", correctedBy: "someoneElse", reason: "x" },
    }));
  });
  it("a correction cannot retarget the record", async () => {
    await assertFails(updateDoc(doc(as("dir1"), "attendance/sess1_s1"), {
      studentId: "s2",
      correctionMetadata: { originalStatus: "present", correctedBy: "dir1", reason: "x" },
    }));
  });
  it("other-center directors and suspended users are denied", async () => {
    await assertFails(getDoc(doc(as("dir2"), "attendance/sess1_s1")));
    await assertFails(getDoc(doc(as("tSusp"), "attendance/sess1_s1")));
  });
  it("attendance is never deleted", async () => {
    await assertFails(deleteDoc(doc(as("dir1"), "attendance/sess1_s1")));
  });
});

describe("teachers", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "teachers/tA"), { centerId: C1, userId: "tA", fullName: "المعلم أ", status: "active", assignedCircleIds: [] });
      await setDoc(doc(db, "teachers/tB"), { centerId: C1, userId: "tB", fullName: "المعلم ب", status: "active", assignedCircleIds: [] });
    });
  });
  it("a teacher reads their own record but not a colleague's", async () => {
    await assertSucceeds(getDoc(doc(as("tA"), "teachers/tA")));
    await assertFails(getDoc(doc(as("tA"), "teachers/tB")));
  });
  it("students and other centers cannot read teachers", async () => {
    await assertFails(getDoc(doc(as("uS1"), "teachers/tA")));
    await assertFails(getDoc(doc(as("dir2"), "teachers/tA")));
    await assertSucceeds(getDoc(doc(as("dir1"), "teachers/tA")));
  });
  it("no client can create a teacher document, even a director", async () => {
    await assertFails(setDoc(doc(as("dir1"), "teachers/forged"), { centerId: C1, userId: "forged", fullName: "x", status: "active" }));
  });
  it("a director can edit notes but not status, link or center", async () => {
    await assertSucceeds(updateDoc(doc(as("dir1"), "teachers/tA"), { professionalNotes: "ملاحظات" }));
    await assertFails(updateDoc(doc(as("dir1"), "teachers/tA"), { status: "suspended" }));
    await assertFails(updateDoc(doc(as("dir1"), "teachers/tA"), { userId: "other" }));
    await assertFails(updateDoc(doc(as("dir1"), "teachers/tA"), { centerId: C2 }));
  });
  it("a teacher cannot edit their own record", async () => {
    await assertFails(updateDoc(doc(as("tA"), "teachers/tA"), { fullName: "x" }));
    await assertFails(updateDoc(doc(as("tA"), "teachers/tA"), { status: "active" }));
  });
  it("teachers are never deleted", async () => {
    await assertFails(deleteDoc(doc(as("dir1"), "teachers/tA")));
  });
});

describe("circles", () => {
  it("a teacher reads only their own circle", async () => {
    await assertSucceeds(getDoc(doc(as("tA"), "circles/circle1")));
    await assertFails(getDoc(doc(as("tA"), "circles/circle2")));
  });
  it("students cannot read circles; directors can create them", async () => {
    await assertFails(getDoc(doc(as("uS1"), "circles/circle1")));
    await assertSucceeds(setDoc(doc(as("dir1"), "circles/new"), { centerId: C1, name: "N" }));
    await assertFails(setDoc(doc(as("tA"), "circles/new2"), { centerId: C1, name: "N" }));
  });
});

describe("session lifecycle (teacher)", () => {
  it("the session's teacher can start it, and later complete it", async () => {
    await assertSucceeds(updateDoc(doc(as("tA"), "schedules/sessSched"), { status: "inProgress", startedAt: new Date() }));
    await assertSucceeds(updateDoc(doc(as("tA"), "schedules/sessSched"), { status: "completed", completedAt: new Date() }));
  });
  it("a session cannot be started before its date", async () => {
    await assertFails(updateDoc(doc(as("tA"), "schedules/sessFuture"), { status: "inProgress" }));
  });
  it("only valid transitions: no skipping, reopening, cancelling or reassigning", async () => {
    await assertFails(updateDoc(doc(as("tA"), "schedules/sessSched"), { status: "completed" }));   // skip
    await assertFails(updateDoc(doc(as("tA"), "schedules/sess1"), { status: "inProgress" }));       // reopen
    await assertFails(updateDoc(doc(as("tA"), "schedules/sessSched"), { status: "cancelled" }));
    await assertFails(updateDoc(doc(as("tA"), "schedules/sessSched"), { status: "inProgress", teacherId: "tA", circleId: "circle2" }));
    await assertFails(updateDoc(doc(as("tA"), "schedules/sessSched"), { status: "inProgress", date: new Date("2026-02-01") }));
  });
  it("another teacher, a student or a suspended teacher cannot change it", async () => {
    await assertFails(updateDoc(doc(as("tB"), "schedules/sessSched"), { status: "inProgress" }));
    await assertFails(updateDoc(doc(as("uS1"), "schedules/sessSched"), { status: "inProgress" }));
    await assertFails(updateDoc(doc(as("tSusp"), "schedules/sessSched"), { status: "inProgress" }));
  });
  it("a teacher reads only their own sessions", async () => {
    await assertSucceeds(getDoc(doc(as("tA"), "schedules/sess9")));
    await assertFails(getDoc(doc(as("tA"), "schedules/sessB")));
  });
});

describe("circle teacher change (one batch)", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "enrollments/ct1"), { centerId: C1, studentId: "s3", circleId: "circle1", teacherId: "tA", status: "active" });
      await setDoc(doc(db, "schedules/ctS"), { centerId: C1, circleId: "circle1", teacherId: "tA", status: "scheduled" });
    });
  });
  it("a director can move circle, enrolment, student, session and audit together", async () => {
    const db = as("dir1");
    const batch = writeBatch(db);
    batch.update(doc(db, "circles/circle1"), { assignedTeacherId: "tB", updatedBy: "dir1" });
    batch.update(doc(db, "enrollments/ct1"), { teacherId: "tB" });
    batch.update(doc(db, "students/s3"), { assignedTeacherIds: ["tB"] });
    batch.update(doc(db, "schedules/ctS"), { teacherId: "tB" });
    batch.set(doc(db, "audit_logs/aud-ct-1"), {
      centerId: C1, actorUserId: "dir1", actorRole: "director",
      action: "change_circle_teacher", entityType: "circle", entityId: "circle1",
    });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(as("tB"), "circles/circle1")));
    await assertFails(getDoc(doc(as("tA"), "circles/circle1")));
  });
  it("a teacher cannot reassign a circle to themselves, and another center's director cannot touch it", async () => {
    await assertFails(updateDoc(doc(as("tB"), "circles/circle1"), { assignedTeacherId: "tB" }));
    await assertFails(updateDoc(doc(as("dir2"), "circles/circle1"), { assignedTeacherId: "tB" }));
    await assertFails(updateDoc(doc(as("dir1"), "circles/circle1"), { centerId: C2 }));
  });
});

describe("audit_logs", () => {
  const entry = (over = {}) => ({ centerId: C1, actorUserId: "dir1", action: "x", ...over });
  it("a director can append an entry attributed to themselves", async () => {
    await assertSucceeds(setDoc(doc(as("dir1"), "audit_logs/a1"), entry()));
  });
  it("entries cannot be attributed to someone else", async () => {
    await assertFails(setDoc(doc(as("dir1"), "audit_logs/a2"), entry({ actorUserId: "dir2" })));
  });
  it("entries are immutable and unreadable to non-directors", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => setDoc(doc(ctx.firestore(), "audit_logs/a3"), entry()));
    await assertFails(updateDoc(doc(as("dir1"), "audit_logs/a3"), { action: "tampered" }));
    await assertFails(deleteDoc(doc(as("dir1"), "audit_logs/a3")));
    await assertFails(getDoc(doc(as("tA"), "audit_logs/a3")));
    await assertSucceeds(getDoc(doc(as("dir1"), "audit_logs/a3")));
  });
});

describe("memorization assessments and private notes", () => {
  it("the student, the author and the director can read the assessment; others cannot", async () => {
    await assertSucceeds(getDoc(doc(as("uS1"), "memorization_records/m1")));
    await assertSucceeds(getDoc(doc(as("tA"), "memorization_records/m1")));
    await assertSucceeds(getDoc(doc(as("dir1"), "memorization_records/m1")));
    await assertFails(getDoc(doc(as("uS2"), "memorization_records/m1")));   // another student
    await assertFails(getDoc(doc(as("tB"), "memorization_records/m1")));    // another teacher
    await assertFails(getDoc(doc(as("dir2"), "memorization_records/m1")));  // another center
    await assertFails(getDoc(doc(anon(), "memorization_records/m1")));
  });
  it("the private note is never readable by the student, nor by other teachers or centers", async () => {
    await assertFails(getDoc(doc(as("uS1"), "private_teacher_notes/m1")));
    await assertFails(getDoc(doc(as("tB"), "private_teacher_notes/m1")));
    await assertFails(getDoc(doc(as("dir2"), "private_teacher_notes/m1")));
    await assertSucceeds(getDoc(doc(as("tA"), "private_teacher_notes/m1")));
    await assertSucceeds(getDoc(doc(as("dir1"), "private_teacher_notes/m1")));
  });
  it("the student's own query for their assessments works and never returns a private note", async () => {
    const db = as("uS1");
    await assertSucceeds(getDocs(query(collection(db, "memorization_records"), where("centerId", "==", C1), where("studentId", "==", "s1"))));
    await assertFails(getDocs(query(collection(db, "private_teacher_notes"), where("centerId", "==", C1), where("studentId", "==", "s1"))));
  });
  it("a teacher records an assessment for their student in their in-progress session", async () => {
    await assertSucceeds(setDoc(doc(as("tA"), "memorization_records/new1"), rec({ studentId: "s3" })));
  });
  it("assessment + private note can be written together in one batch", async () => {
    const db = as("tA");
    const batch = writeBatch(db);
    batch.set(doc(db, "memorization_records/new2"), rec({ studentId: "s3" }));
    batch.set(doc(db, "private_teacher_notes/new2"), { centerId: C1, studentId: "s3", teacherId: "tA", note: "ملاحظة" });
    await assertSucceeds(batch.commit());
  });
  it("a private note cannot be created without its assessment, or for someone else's", async () => {
    await assertFails(setDoc(doc(as("tA"), "private_teacher_notes/orphan"), { centerId: C1, studentId: "s3", teacherId: "tA", note: "x" }));
    await assertFails(setDoc(doc(as("tB"), "private_teacher_notes/m1x"), { centerId: C1, studentId: "s1", teacherId: "tB", note: "x" }));
  });
  it("the private note cannot be smuggled into the readable record", async () => {
    await assertFails(setDoc(doc(as("tA"), "memorization_records/new3"), rec({ studentId: "s3", privateTeacherNote: "secret" })));
  });
  it("refused: not your student, not your session, not in progress, or as someone else", async () => {
    await assertFails(setDoc(doc(as("tA"), "memorization_records/n4"), rec({ studentId: "s2" })));          // s2 is tB's
    await assertFails(setDoc(doc(as("tA"), "memorization_records/n5"), rec({ studentId: "s3", sessionId: "sessB" })));
    await assertFails(setDoc(doc(as("tA"), "memorization_records/n6"), rec({ studentId: "s3", sessionId: "sess1" })));      // completed
    await assertFails(setDoc(doc(as("tA"), "memorization_records/n7"), rec({ studentId: "s3", sessionId: "sessSched" })));   // not started
    await assertFails(setDoc(doc(as("tA"), "memorization_records/n8"), rec({ studentId: "s3", teacherId: "tB" })));
    const noSession = rec({ studentId: "s3" });
    delete noSession.sessionId;
    await assertFails(setDoc(doc(as("tA"), "memorization_records/n9"), noSession));
    await assertFails(setDoc(doc(as("uS1"), "memorization_records/n10"), rec({ teacherId: "uS1" })));
  });
  it("invalid surah and ayah ranges are refused by the backend too", async () => {
    for (const bad of [{ surah: 0 }, { surah: 115 }, { startAyah: 0 }, { startAyah: 6, endAyah: 5 }, { surah: "2" }]) {
      await assertFails(setDoc(doc(as("tA"), "memorization_records/bad"), rec({ studentId: "s3", ...bad })));
    }
  });
  it("the author may amend while the session runs, but cannot retarget the record", async () => {
    await assertSucceeds(updateDoc(doc(as("tA"), "memorization_records/m1"), { mistakesCount: 2, endAyah: 6 }));
    await assertFails(updateDoc(doc(as("tA"), "memorization_records/m1"), { studentId: "s3" }));
    await assertFails(updateDoc(doc(as("tA"), "memorization_records/m1"), { teacherId: "tB" }));
    await assertFails(updateDoc(doc(as("tA"), "memorization_records/m1"), { endAyah: 0 }));
    await assertFails(updateDoc(doc(as("tA"), "memorization_records/m1"), { privateTeacherNote: "x" }));
    await assertFails(updateDoc(doc(as("tB"), "memorization_records/m1"), { mistakesCount: 9 }));
    await assertFails(updateDoc(doc(as("uS1"), "memorization_records/m1"), { mistakesCount: 9 }));
  });
  it("after the session completes the assessment is frozen, and nothing is ever deleted", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "memorization_records/old"), rec({ sessionId: "sess1" }));
    });
    await assertFails(updateDoc(doc(as("tA"), "memorization_records/old"), { mistakesCount: 1 }));
    await assertFails(deleteDoc(doc(as("tA"), "memorization_records/m1")));
    await assertFails(deleteDoc(doc(as("dir1"), "memorization_records/m1")));
    await assertFails(deleteDoc(doc(as("tA"), "private_teacher_notes/m1")));
  });
  it("the teacher can edit their own private note", async () => {
    await assertSucceeds(updateDoc(doc(as("tA"), "private_teacher_notes/m1"), { note: "محدّثة" }));
    await assertFails(updateDoc(doc(as("tA"), "private_teacher_notes/m1"), { studentId: "s3" }));
    await assertFails(updateDoc(doc(as("tB"), "private_teacher_notes/m1"), { note: "x" }));
  });
});

describe("learning plans and tasks", () => {
  const verification = (over = {}) => ({ verifiedAt: new Date(), verifiedBy: "tA", result: "passed", ...over });

  it("readable by the student, the owning teacher and the director only", async () => {
    await assertSucceeds(getDoc(doc(as("uS1"), "learning_tasks/t1")));
    await assertSucceeds(getDoc(doc(as("tA"), "learning_tasks/t1")));
    await assertSucceeds(getDoc(doc(as("dir1"), "learning_tasks/t1")));
    await assertFails(getDoc(doc(as("uS2"), "learning_tasks/t1")));
    await assertFails(getDoc(doc(as("tB"), "learning_tasks/t1")));
    await assertFails(getDoc(doc(as("dir2"), "learning_tasks/t1")));
    await assertSucceeds(getDoc(doc(as("uS1"), "learning_plans/plan_s1_tA")));
    await assertFails(getDoc(doc(as("uS2"), "learning_plans/plan_s1_tA")));
  });
  it("a student's own task query works when scoped", async () => {
    const db = as("uS1");
    await assertSucceeds(getDocs(query(collection(db, "learning_tasks"), where("centerId", "==", C1), where("studentId", "==", "s1"))));
    await assertFails(getDocs(query(collection(db, "learning_tasks"), where("centerId", "==", C1))));
  });
  it("a teacher assigns a task to their own student", async () => {
    await assertSucceeds(setDoc(doc(as("tA"), "learning_tasks/new1"), task({ studentId: "s3", planId: "plan_s3_tA" })));
  });
  it("refused: others' students, wrong plan, non-upcoming start, pre-filled claims, bad range or dates", async () => {
    const t = (over) => setDoc(doc(as("tA"), "learning_tasks/bad"), task({ studentId: "s3", planId: "plan_s3_tA", ...over }));
    await assertFails(setDoc(doc(as("tA"), "learning_tasks/bad"), task({ studentId: "s2", planId: "plan_s2_tB" }))); // tB's student
    await assertFails(t({ planId: "plan_s3" }));            // not the (student, teacher) plan id
    await assertFails(t({ planId: "plan_s3_tB" }));
    await assertFails(t({ status: "completed" }));
    await assertFails(t({ selfReportedPractice: { reportedAt: new Date() } }));
    await assertFails(t({ teacherVerification: verification() }));
    await assertFails(t({ teacherId: "tB" }));
    await assertFails(t({ surah: 115 }));
    await assertFails(t({ startAyah: 6, endAyah: 5 }));
    await assertFails(t({ dueDate: new Date("2026-01-01") })); // before assignment
    await assertFails(setDoc(doc(as("uS1"), "learning_tasks/self"), task({ teacherId: "uS1" })));
  });
  it("the teacher can edit instructions and due date only before work starts", async () => {
    await assertSucceeds(updateDoc(doc(as("tA"), "learning_tasks/t1"), { teacherInstructions: "جديد", dueDate: new Date("2026-02-01") }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { surah: 3 }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { studentId: "s3" }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/tReported"), { teacherInstructions: "x" })); // already reported
  });
  it("only a teacher verification completes a task, and it must say so truthfully", async () => {
    await assertSucceeds(updateDoc(doc(as("tA"), "learning_tasks/tReported"), { status: "completed", teacherVerification: verification() }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "completed" }));                                    // no verification
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "completed", teacherVerification: verification({ verifiedBy: "tB" }) }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "completed", teacherVerification: verification({ result: "needs_improvement" }) }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "needsReview", teacherVerification: verification({ result: "passed" }) }));
    await assertSucceeds(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "needsReview", teacherVerification: verification({ result: "needs_improvement" }) }));
  });
  it("a completed task is final; students and other teachers cannot change anything", async () => {
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/tDone"), { status: "needsReview", teacherVerification: verification({ result: "needs_improvement" }) }));
    await assertFails(updateDoc(doc(as("uS1"), "learning_tasks/t1"), { status: "completed" }));
    await assertFails(updateDoc(doc(as("uS1"), "learning_tasks/t1"), { status: "practiceReported" })); // student path arrives with Phase 6
    await assertFails(updateDoc(doc(as("tB"), "learning_tasks/t1"), { teacherInstructions: "x" }));
    await assertFails(updateDoc(doc(as("dir1"), "learning_tasks/t1"), { status: "completed" }));
  });
  it("cancelling needs a reason; closed tasks cannot be cancelled; nothing is deleted", async () => {
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "cancelled" }));
    await assertSucceeds(updateDoc(doc(as("tA"), "learning_tasks/t1"), { status: "cancelled", completionMetadata: { reason: "تغيير الخطة", cancelledBy: "tA" } }));
    await assertFails(updateDoc(doc(as("tA"), "learning_tasks/tDone"), { status: "cancelled", completionMetadata: { reason: "x" } }));
    await assertFails(deleteDoc(doc(as("tA"), "learning_tasks/t1")));
    await assertFails(deleteDoc(doc(as("dir1"), "learning_tasks/t1")));
  });
  it("the plan is created once per student by an assigned teacher", async () => {
    const plan = (over = {}) => ({ centerId: C1, studentId: "s3", responsibleTeacherId: "tA", status: "active", ...over });
    await assertSucceeds(setDoc(doc(as("tA"), "learning_plans/plan_s3_tA"), plan()));
    await assertFails(setDoc(doc(as("tA"), "learning_plans/other"), plan()));                       // id convention
    await assertFails(setDoc(doc(as("tB"), "learning_plans/plan_s3_tB"), plan({ responsibleTeacherId: "tB" }))); // not assigned
    await assertFails(setDoc(doc(as("uS1"), "learning_plans/plan_s1x_uS1"), plan({ studentId: "s1x" })));
    await assertFails(deleteDoc(doc(as("tA"), "learning_plans/plan_s1_tA")));
  });
});

describe("default deny for features not built yet", () => {
  it("notifications and announcements stay closed", async () => {
    await assertFails(setDoc(doc(as("dir1"), "notifications/n1"), { centerId: C1 }));
    await assertFails(setDoc(doc(as("dir1"), "announcements/a1"), { centerId: C1 }));
  });
});
