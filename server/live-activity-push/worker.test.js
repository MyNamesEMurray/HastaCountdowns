import test from "node:test";
import assert from "node:assert/strict";
import { classifyApns, parseSchedule } from "./worker.js";

const id = "7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F";
const token = "ab".repeat(32);

test("only a bad token or 410 forgets the device", () => {
  assert.equal(classifyApns(410), "badToken");
  assert.equal(classifyApns(400, "BadDeviceToken"), "badToken");
  assert.equal(classifyApns(400, "BadTopic"), "drop");
  assert.equal(classifyApns(400, "PayloadEmpty"), "drop");
});

test("transient errors are retried and success is final", () => {
  for (const status of [0, 403, 429, 500, 503]) assert.equal(classifyApns(status), "retry");
  assert.equal(classifyApns(200), "ok");
});

test("schedule is validated and capped", () => {
  assert.equal(parseSchedule(null), null);
  assert.equal(parseSchedule({ token: "nothex!", countdowns: [] }), null);
  assert.equal(parseSchedule({ token, countdowns: "x" }), null);
  const parsed = parseSchedule({
    token,
    sandbox: 1,
    countdowns: [
      { id, fireAt: 100.7, target: 200 },
      { id: "bad", fireAt: 1, target: 2 },
      { id, fireAt: "x", target: 2 },
      null,
    ],
  });
  assert.deepEqual(parsed.items, [{ id, fireAt: 100, target: 200 }]);
  assert.equal(parsed.sandbox, true);
  const many = Array.from({ length: 80 }, () => ({ id, fireAt: 1, target: 2 }));
  assert.equal(parseSchedule({ token, countdowns: many }).items.length, 50);
});
