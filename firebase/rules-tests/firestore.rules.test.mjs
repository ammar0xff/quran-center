import { readFileSync } from "node:fs";
import { before, after, beforeEach, describe, it } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

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
    await setDoc(doc(db, "circles/circle1"), { centerId: C1, name: "A", assignedTeacherId: "tA" });
    await setDoc(doc(db, "circles/circle2"), { centerId: C1, name: "B", assignedTeacherId: "tB" });
    await setDoc(doc(db, "memorization_records/m1"), { centerId: C1, studentId: "s1", teacherId: "tA", privateTeacherNote: "secret" });
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
  it("neither teacher nor student can change an existing record", async () => {
    await assertFails(updateDoc(doc(as("tA"), "attendance/sess1_s1"), { status: "absent" }));
    await assertFails(updateDoc(doc(as("uS1"), "attendance/sess1_s1"), { status: "present" }));
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

describe("default deny for features not built yet", () => {
  it("private teacher notes are unreachable for students (and everyone, until the split)", async () => {
    await assertFails(getDoc(doc(as("uS1"), "memorization_records/m1")));
    await assertFails(getDoc(doc(as("tA"), "memorization_records/m1")));
    await assertFails(getDoc(doc(as("dir1"), "memorization_records/m1")));
  });
});
