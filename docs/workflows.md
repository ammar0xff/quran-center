# Core Workflows

## Journey A — Director creates a student
1. Director opens Students list.
2. Taps Add Student.
3. Enters required profile info (full name required; DOB/contact optional).
4. Chooses account mode: no login (default) or create login.
5. Assigns teacher and circle.
6. Reviews summary.
7. Saves (transaction: student + enrollment + optional provisioning function).
8. Shows new profile.
9. Offers: open profile, create learning plan, add another student.

## Journey B — Teacher runs a teaching session
1. Teacher opens dashboard.
2. Selects today's circle.
3. Opens/creates scheduled session (status: in_progress).
4. Reviews roster.
5. Marks attendance (present/absent/late/excused).
6. Records memorization/revision assessment per student.
7. Assigns next tasks (learning plan).
8. Reviews missing records.
9. Submits/closes session (status: completed).
10. Session summary shown (attendance + assessment counts).

## Journey C — Student practices independently
1. Student opens dashboard.
2. Sees today's primary task.
3. Opens task details (surah/ayah range).
4. Practices outside the app.
5. Marks practice completed (self-reported) or submits for review.
6. Reviews remaining tasks.
7. Sees actual status: self-reported vs teacher-verified (distinct).

## Journey D — Director supervises progress
1. Director opens dashboard.
2. Identifies student needing follow-up.
3. Opens student profile.
4. Reviews attendance, memorization history, learning plan.
5. Reviews teacher notes within permissions.
6. Records administrative follow-up or assigns review task (audit logged).
7. Action preserved in audit history.

## Journey E — Accountless student becomes a digital user
1. Director opens existing student profile.
2. Selects Enable Student Access.
3. Reviews linking requirements.
4. Secure backend provisions auth account + links to existing studentId (authUserId).
5. Verifies identity, prevents duplicate links / cross-student takeover.
6. Sends secure activation instructions.
7. Student signs in; existing history available under authorized access.
8. No duplicate student profile created.

## Account switching (sign-out)
- Clear role state, cancel listeners, clear sensitive cache, remove notification subscriptions, reset nav stack, return to auth flow. Next sign-in never exposes previous user's data.

## Offline session flow
- Read cached students/schedule. Record attendance/assessment locally (outbox, idempotency key). Show "saved locally / waiting to sync". On reconnect: sync, retry, surface conflicts (never silently overwrite). Session may be locally complete while server-confirmed status remains distinct.

## Enrollment policy (implemented)
* A student has at most one **active** enrollment. Assigning to another circle
  is a **transfer**: the old enrollment becomes `transferred` (with end date and
  reason) and is kept as history; nothing is deleted.
* Only `active` students go into `active` circles, never beyond `maxCapacity`.
* Assignment is one atomic batch: new enrollment, closed old enrollment,
  student `assignedTeacherIds` (set from the circle's teacher; security rules
  use it to let that teacher read the student), and the audit entry.
* The same enrollment/circle/day re-submitted is rejected as a duplicate, not
  written twice.
