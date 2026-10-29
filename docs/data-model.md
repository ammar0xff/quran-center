# Firestore Data Model

All documents include: stable ID, `centerId` where applicable, `createdAt`, `updatedAt` (server timestamps), `createdBy`/`updatedBy` where appropriate, and a validated `status` enum. Audit fields use `FieldValue.serverTimestamp()`.

## Collections

### centers/{centerId}
- name: string
- logoUrl: string?
- contact: { phone?, email?, address? }
- timezone: string (IANA)
- locale: string (default 'ar')
- dateFormat, numberFormat: string
- operatingHours: { start, end, workingDays }?
- branding: { primaryColor?, darkModeDefault? }
- status: active | suspended
- createdAt, updatedAt

### users/{uid} (Firebase Auth uid -> profile)
- centerId: string
- fullName: string
- role: director | teacher | student | guardian(reserved)
- status: active | suspended | pending | incomplete
- authProvider: string
- phone?: string
- profileImageUrl?: string
- assignedCenterIds: [string] (future multi-branch)
- lastSignInAt?: timestamp
- createdAt, updatedAt
- Security: role is written only by trusted provisioning functions; clients cannot write role.

### students/{studentId}
- centerId: string
- fullName: string (required)
- preferredName?: string
- dateOfBirth?: timestamp
- contactInfo?: { phone?, guardianPhone? }
- profileImageUrl?: string
- enrollmentStatus: active | pending | archived | withdrawn
- accountMode: none | login_enabled | suspended
- authUserId?: string (nullable, links to users/{uid})
- educationalLevel: string
- accessibilityPreferences?: string
- adminNotes?: string (staff only)
- createdAt, updatedAt, createdBy, updatedBy
- Note: authUserId optional. No auth account required.

### enrollments/{enrollmentId}
- centerId: string
- studentId: string
- circleId: string
- teacherId?: string
- startDate: timestamp
- endDate?: timestamp
- status: active | completed | transferred | withdrawn | archived
- changeReason?: string
- changedBy?: string
- changedAt?: timestamp
- createdAt, updatedAt
- Policy: one active enrollment per student per circle at a time (simultaneous enrollments in multiple circles NOT permitted by default; configurable). History preserved.

### teachers/{teacherId}
- centerId: string
- userId?: string (links to users/{uid} when account provisioned)
- fullName: string
- contactInfo?: { phone?, email? }
- profileImageUrl?: string
- professionalNotes?: string
- status: active | suspended | archived
- assignedCircleIds: [string]
- createdAt, updatedAt, createdBy, updatedBy

### circles/{circleId}
- centerId: string
- name: string (required)
- description?: string
- educationalLevel: string
- assignedTeacherId?: string
- maxCapacity: number
- locationOrMode: string (onsite/online/hybrid)
- weeklySchedule: [{ dayOfWeek, startTime, endTime }]
- sessionDurationMinutes: number
- status: active | archived
- adminNotes?: string
- createdAt, updatedAt, createdBy, updatedBy

### schedules/{scheduleId} (session template / scheduled session)
- centerId: string
- circleId: string
- teacherId: string
- date: timestamp (date only)
- startTime: string (HH:mm)
- endTime: string (HH:mm)
- locationOrMode: string
- status: scheduled | in_progress | completed | cancelled
- cancellationReason?: string
- cancelledBy?: string
- cancelledAt?: timestamp
- createdAt, updatedAt

### sessions/{sessionId} (teaching session instance)
- centerId: string
- circleId: string
- scheduleId?: string
- teacherId: string
- date: timestamp
- startTime, endTime: string
- status: scheduled | in_progress | completed | cancelled
- studentCount: number
- attendanceCompletedCount: number
- assessmentCompletedCount: number
- isLocallyComplete: boolean (offline)
- serverConfirmedAt?: timestamp
- createdAt, updatedAt

### attendance/{attendanceId}
- centerId: string
- sessionId: string
- studentId: string
- status: present | absent | late | excused
- recordedBy: string (teacherId)
- note?: string
- createdAt: server timestamp
- updatedAt: server timestamp
- correctionMetadata?: { originalStatus, correctedBy, correctedAt, reason }
- Unique constraint: (centerId, sessionId, studentId) — one record per student per session.

### memorization_records/{recordId}
- centerId: string
- studentId: string
- teacherId: string
- sessionId?: string
- circleId?: string
- assessmentType: new_memorization | recent_revision | long_term_revision | general_recitation
- schemaVersion: number (e.g., 1)
- surah: number (1-114)
- startAyah: number
- endAyah: number
- criteriaScores: { criterionId: score } (configurable)
- overallAssessment?: string
- mistakesCount: number
- mistakeCategory?: string
- mistakeReference?: string
- teacherCorrection?: string
- requiresFollowUp: boolean
- strengths?: string
- areasForImprovement?: string
- privateTeacherNote?: string (staff only)
- studentVisibleFeedback?: string
- recommendedNextAssignment?: string
- suggestedNextReviewDate?: timestamp
- assessedAt: server timestamp
- createdAt, updatedAt

### learning_plans/{planId}
- centerId: string
- studentId: string
- responsibleTeacherId: string
- circleId?: string
- educationalObjective: string
- startDate: timestamp
- targetDate: timestamp
- status: active | completed | cancelled | archived
- createdAt, updatedAt, createdBy, updatedBy

### learning_tasks/{taskId}
- centerId: string
- planId: string
- studentId: string
- teacherId: string
- taskType: new_memorization | recent_revision | long_term_revision | general_recitation
- surah: number
- startAyah: number
- endAyah: number
- assignedDate: timestamp
- dueDate: timestamp
- priority?: low | medium | high
- teacherInstructions: string
- status: upcoming | in_progress | practice_reported | submitted_for_review | completed | needs_review | overdue | cancelled
- selfReportedPractice?: { reportedAt, note, reflection? }
- teacherVerification?: { verifiedAt, verifiedBy, result, feedback }
- completionMetadata?: { completedAt, verifiedAt }
- createdAt, updatedAt

### announcements/{announcementId}
- centerId: string
- title: string
- message: string
- targetAudience: all | teachers | students_with_account | selected_circles | selected_users
- targetEntityIds: [string]
- authorId: string
- status: draft | scheduled | published | archived
- publishAt?: timestamp
- expiresAt?: timestamp
- createdAt, updatedAt

### notifications/{notificationId}
- recipientUserId: string
- centerId: string
- type: session_reminder | schedule_change | new_assignment | review_reminder | teacher_feedback | center_announcement | admin_alert
- title: string
- message: string (safe, no sensitive student data)
- relatedEntityType?: string
- relatedEntityId?: string
- createdAt: server timestamp
- read: boolean
- readAt?: timestamp
- deliveryMetadata?: { sentVia: fcm, messageId?, status? }

### audit_logs/{auditId}
- centerId: string
- actorUserId?: string
- actorRole?: string
- action: string (e.g., create_student, correct_attendance, link_account)
- entityType: string
- entityId: string
- previousValue?: map
- newValue?: map
- reason?: string
- createdAt: server timestamp

### center_settings/{centerId} (or settings doc inside centers)
- assessmentCriteria: [criterionId]
- scoringScale: map
- attendanceStatuses: [present, absent, late, excused]
- defaultSessionDurationMinutes: number
- learningTaskDefaults: map
- reminderRules: map
- permissions: { whoCanCorrectAttendance, whoCanEditAssessments, whoCanViewPrivateNotes, whoCanExportReports }
- updatedAt, updatedBy

## Indexes (composite, by query)
- students: centerId + enrollmentStatus
- enrollments: centerId + studentId + status
- enrollments: centerId + circleId + status
- circles: centerId + status
- circles: centerId + assignedTeacherId
- schedules: centerId + circleId + date
- schedules: centerId + teacherId + date
- sessions: centerId + circleId + date
- sessions: centerId + teacherId + date
- attendance: centerId + sessionId + studentId (unique)
- attendance: centerId + studentId + date
- memorization_records: centerId + studentId + assessedAt
- memorization_records: centerId + circleId + assessedAt
- learning_tasks: centerId + studentId + status
- learning_tasks: centerId + dueDate + status
- notifications: recipientUserId + createdAt
- notifications: recipientUserId + read
- audit_logs: centerId + createdAt