import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { provisionDirector } from "./provision";

/**
 * Operator tool, run once per new center:
 *   GOOGLE_APPLICATION_CREDENTIALS=key.json node lib/provisionCli.js \
 *     --email director@example.com --name "اسم المديرة" \
 *     --center-id my-center --center-name "دار ..."
 * Prints the password-setup link to send to the director. Nothing secret is
 * stored or logged beyond that one-time link.
 */
function arg(name: string): string {
  const i = process.argv.indexOf(`--${name}`);
  const v = i >= 0 ? process.argv[i + 1] : undefined;
  if (!v) {
    console.error(`Missing --${name}`);
    process.exit(2);
  }
  return v;
}

async function main(): Promise<void> {
  initializeApp();
  const result = await provisionDirector(getAuth(), getFirestore(), {
    email: arg("email"),
    fullName: arg("name"),
    centerId: arg("center-id"),
    centerName: arg("center-name"),
  });
  console.log(`Created director ${result.uid}.`);
  console.log(`Send this one-time link so they can set a password:\n${result.passwordSetupLink}`);
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
