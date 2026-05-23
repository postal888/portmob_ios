#!/usr/bin/env node
/**
 * Ensures iOS Info.plist has required usage descriptions after `cap sync ios`.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const infoPlistPath = path.join(__dirname, "..", "App", "App", "Info.plist");

const REQUIRED_KEYS = {
  NSMicrophoneUsageDescription:
    "PortuPrep Cards записывает произношение слов и аудио для наборов.",
  NSPhotoLibraryUsageDescription:
    "PortuPrep Cards использует фото для картинок к словам в наборах.",
};

if (!fs.existsSync(infoPlistPath)) {
  console.error("[ios-prepare] Info.plist not found at", infoPlistPath);
  process.exit(1);
}

let plist = fs.readFileSync(infoPlistPath, "utf8");
let changed = false;

for (const [key, value] of Object.entries(REQUIRED_KEYS)) {
  if (plist.includes(`<key>${key}</key>`)) continue;
  const block = `\t<key>${key}</key>\n\t<string>${value}</string>\n`;
  plist = plist.replace("</dict>\n</plist>", `${block}</dict>\n</plist>`);
  changed = true;
  console.log(`[ios-prepare] added ${key}`);
}

if (changed) {
  fs.writeFileSync(infoPlistPath, plist, "utf8");
} else {
  console.log("[ios-prepare] Info.plist permissions OK");
}
