export type AccountMode = "none" | "loginEnabled" | "suspended";

export interface StudentAccessState {
  accountMode: AccountMode;
  authUserId?: string | null;
  enrollmentStatus: string;
}

export type AccessAction = "enable" | "suspend" | "reactivate";

export type AccessBlock =
  | "alreadyHasLogin"
  | "noLoginToChange"
  | "notSuspended"
  | "alreadySuspended"
  | "archivedStudent"
  | "missingLink";

/**
 * Authoritative state machine for student digital access. The Dart client
 * mirrors this (lib/core/utils/account_access_rules.dart) only to enable or
 * disable buttons; this function is what actually gates the operation.
 *
 *   none --enable--> loginEnabled --suspend--> suspended
 *                         ^                        |
 *                         +-------reactivate-------+
 */
export function checkAccessAction(
  s: StudentAccessState,
  action: AccessAction
): AccessBlock | null {
  switch (action) {
    case "enable":
      if (s.enrollmentStatus === "archived") return "archivedStudent";
      if (s.accountMode !== "none" || s.authUserId) return "alreadyHasLogin";
      return null;
    case "suspend":
      if (s.accountMode === "suspended") return "alreadySuspended";
      if (s.accountMode !== "loginEnabled") return "noLoginToChange";
      if (!s.authUserId) return "missingLink";
      return null;
    case "reactivate":
      if (s.accountMode !== "suspended") return "notSuspended";
      if (!s.authUserId) return "missingLink";
      return null;
  }
}

export function isPlausibleEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value.trim());
}
