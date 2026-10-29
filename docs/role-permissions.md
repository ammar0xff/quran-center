# Role-Permission Matrix

Roles: `director`, `teacher`, `student`. (`guardian` reserved for future release.)
Authorization is enforced by Firestore Security Rules + Cloud Functions, never by the frontend alone.
`authUserId` on a student record is optional and nullable — students may exist without login accounts.

| Capability | Director | Teacher | Student |
|---|---:|---:|---:|
| View own profile | ✅ | ✅ | ✅ (own only) |
| Edit own permitted profile fields | ✅ | ✅ | ✅ (limited fields) |
| Sign out | ✅ | ✅ | ✅ |
| Change own role / grant privileges | ❌ | ❌ | ❌ |
| View assigned center | ✅ | ✅ | ✅ |
| View all students in center | ✅ | ✅ (assigned only) | ❌ (own only) |
| Create student profile | ✅ | ❌ | ❌ |
| Edit student profile (admin) | ✅ | ❌ | ❌ |
| Archive/reinstate student | ✅ | ❌ | ❌ |
| Assign student to circle/teacher | ✅ | ❌ | ❌ |
| Enable/suspend student login access | ✅ | ❌ | ❌ |
| Provision student auth account | ✅ (via secure backend) | ❌ | ❌ |
| View all teachers in center | ✅ | ❌ | ❌ |
| Create/edit teacher | ✅ | ❌ | ❌ |
| Suspend/reactivate teacher | ✅ | ❌ | ❌ |
| Assign circles to teacher | ✅ | ❌ | ❌ |
| View all circles | ✅ | ✅ (assigned only) | ❌ |
| Create/edit circle | ✅ | ❌ | ❌ |
| Archive circle (preserve history) | ✅ | ❌ | ❌ |
| View weekly schedule | ✅ | ✅ (assigned) | ✅ (own circles) |
| Create/edit session schedule | ✅ | ❌ | ❌ |
| Open/create teaching session | ❌ | ✅ (assigned) | ❌ |
| Mark attendance | ❌ | ✅ (assigned students) | ❌ (read own only) |
| Correct attendance (with reason + audit) | ✅ | ❌ (limited, if configured) | ❌ |
| Record memorization assessment | ❌ | ✅ (assigned students) | ❌ |
| Edit official assessment scores | ❌ | ❌ (create only; corrections via director) | ❌ |
| View private teacher notes | ✅ | ✅ (own) | ❌ |
| View student-visible feedback | ✅ | ✅ | ✅ (own) |
| Create/edit learning plan | ❌ | ✅ (assigned) | ❌ |
| Create/edit learning task | ❌ | ✅ (assigned) | ❌ |
| Mark practice completed (self-reported) | ❌ | ❌ | ✅ (own) |
| Submit task for review | ❌ | ❌ | ✅ (own, if enabled) |
| Teacher-verify task completion | ❌ | ✅ | ❌ |
| View own assessments/tasks/progress | ✅ (any student) | ✅ (assigned) | ✅ (own) |
| Follow-up list | ❌ | ✅ (assigned) | ❌ |
| Director dashboard KPIs | ✅ | ❌ | ❌ |
| Educational supervision view | ✅ | ❌ | ❌ |
| Generate reports | ✅ | ❌ | ❌ |
| CSV export (authorized datasets) | ✅ | ❌ | ❌ |
| Publish announcements | ✅ | ❌ | ❌ |
| View announcements | ✅ | ✅ | ✅ |
| Manage center settings | ✅ | ❌ | ❌ |
| Account administration (users/roles) | ✅ | ❌ | ❌ |
| Read another student's private records | ❌ | ❌ | ❌ |
| Access unauthorized circle | ❌ | ❌ | ❌ |
| Cross-center access | ❌ | ❌ | ❌ |

### Notes
- A teacher can only act on students enrolled in their assigned circles.
- A student can only read their own records; never private teacher notes or other students' data.
- Director actions on security-sensitive operations (role change, suspension) require elevated authorization and reauthentication via backend.
- Accountless students have no auth identity but their records are protected by center/role boundaries.