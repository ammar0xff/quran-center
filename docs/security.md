# Security Model

## Principle
Authorization enforced by the backend (Firestore Security Rules + Cloud Functions). Frontend role checks are UI convenience only and never sufficient.

## Roles
- `director`: manages authorized center data and admin functions.
- `teacher`: assigned circles + authorized student records only.
- `student`: own permitted data only.
- `guardian`: reserved for future (narrowly scoped, verified relationship).
- Accountless students: no auth identity; records protected by center/role boundaries.

## Rules (enforced)
1. Never trust a client-supplied `centerId`, role, teacher assignment, or permission claim.
2. Never treat possession of a document ID as authorization.
3. Never expose private teacher notes to students.
4. Never allow a user to grant themselves a role (role written only by trusted provisioning functions/custom claims).
5. Admin SDK bypasses Security Rules — every privileged Cloud Function performs its own authorization.
6. No service account credentials or secrets in client; nothing committed.
7. Cross-center access denied; accountless student records protected; account linking cannot take over another student's identity.

## Security tests to verify
1. Student cannot read another student's private records.
2. Teacher cannot access an unauthorized circle.
3. Teacher cannot grant self director permissions.
4. Student cannot modify official assessment scores.
5. Student cannot modify official attendance.
6. Suspended user cannot access protected data.
7. Cross-center access denied.
8. Accountless student records protected.
9. Account linking cannot take over another student identity.
10. Unauthorized users cannot read by guessing document IDs.
11. Private teacher notes remain private.
12. Financial records inaccessible (module out of scope; reserved).

## Additional controls
- Firebase App Check enabled.
- Rate limiting on auth and callable functions.
- Audit log collection for sensitive operations.
- Secure account provisioning via callable functions (not client-side create).
- Firestore + Storage rules; Emulator Suite for local testing.
- Security Rules tested with firebase emulator unit tests.