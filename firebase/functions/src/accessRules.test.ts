import { test } from "node:test";
import assert from "node:assert/strict";
import { checkAccessAction, isPlausibleEmail, StudentAccessState } from "./accessRules";

const base: StudentAccessState = {
  accountMode: "none",
  authUserId: null,
  enrollmentStatus: "active",
};

test("enable: allowed only for accountless active students", () => {
  assert.equal(checkAccessAction(base, "enable"), null);
  assert.equal(
    checkAccessAction({ ...base, accountMode: "loginEnabled", authUserId: "u" }, "enable"),
    "alreadyHasLogin"
  );
  assert.equal(
    checkAccessAction({ ...base, accountMode: "suspended", authUserId: "u" }, "enable"),
    "alreadyHasLogin"
  );
  // A dangling link blocks enabling even if the mode says none.
  assert.equal(checkAccessAction({ ...base, authUserId: "u" }, "enable"), "alreadyHasLogin");
  assert.equal(
    checkAccessAction({ ...base, enrollmentStatus: "archived" }, "enable"),
    "archivedStudent"
  );
});

test("suspend: needs an enabled, linked account", () => {
  const enabled: StudentAccessState = { ...base, accountMode: "loginEnabled", authUserId: "u" };
  assert.equal(checkAccessAction(enabled, "suspend"), null);
  assert.equal(checkAccessAction(base, "suspend"), "noLoginToChange");
  assert.equal(
    checkAccessAction({ ...enabled, accountMode: "suspended" }, "suspend"),
    "alreadySuspended"
  );
  assert.equal(checkAccessAction({ ...enabled, authUserId: null }, "suspend"), "missingLink");
});

test("reactivate: only from suspended with a link", () => {
  const suspended: StudentAccessState = { ...base, accountMode: "suspended", authUserId: "u" };
  assert.equal(checkAccessAction(suspended, "reactivate"), null);
  assert.equal(checkAccessAction(base, "reactivate"), "notSuspended");
  assert.equal(
    checkAccessAction({ ...suspended, accountMode: "loginEnabled" }, "reactivate"),
    "notSuspended"
  );
  assert.equal(checkAccessAction({ ...suspended, authUserId: null }, "reactivate"), "missingLink");
});

test("isPlausibleEmail", () => {
  assert.ok(isPlausibleEmail("a@b.com"));
  assert.ok(isPlausibleEmail("  x.y@mail.example.org "));
  for (const bad of ["", "a", "a@", "@b.com", "a@b", "a b@c.com"]) {
    assert.equal(isPlausibleEmail(bad), false, bad);
  }
});

import { checkTeacherAction, cleanName } from "./accessRules";

test("teacher state machine", () => {
  assert.equal(checkTeacherAction("active", "suspend"), null);
  assert.equal(checkTeacherAction("suspended", "suspend"), "alreadySuspended");
  assert.equal(checkTeacherAction("suspended", "reactivate"), null);
  assert.equal(checkTeacherAction("active", "reactivate"), "notSuspended");
  assert.equal(checkTeacherAction("archived", "suspend"), "archived");
  assert.equal(checkTeacherAction("archived", "reactivate"), "archived");
});

test("cleanName trims, collapses spaces and bounds length", () => {
  assert.equal(cleanName("  فاطمة   علي "), "فاطمة علي");
  assert.equal(cleanName(""), null);
  assert.equal(cleanName("   "), null);
  assert.equal(cleanName("ا"), null);
  assert.equal(cleanName(123), null);
  assert.equal(cleanName(undefined), null);
  assert.equal(cleanName("x".repeat(121)), null);
  assert.equal(cleanName("x".repeat(120)), "x".repeat(120));
});
