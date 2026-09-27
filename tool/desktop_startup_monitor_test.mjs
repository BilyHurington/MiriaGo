import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const script = readFileSync(new URL('../web/desktop_startup_monitor.js', import.meta.url), 'utf8');

test('WebKit errors preserve message and stack frames', () => {
  const messages = [];
  const context = vm.createContext({
    window: { addEventListener() {}, setTimeout() {} },
    document: { getElementById() { return null; }, addEventListener() {} },
    console: { error(message) { messages.push(message); } },
  });
  vm.runInContext(script, context);
  vm.runInContext(`
    const error = new Error('GPU context unavailable');
    error.stack = 'initialize@tauri://localhost/main.dart.js:1:2';
    window.__miriagoStartupMonitor.report('initialization', error);
  `, context);
  assert.equal(messages.length, 1);
  assert.match(messages[0], /Error: GPU context unavailable/);
  assert.match(messages[0], /initialize@tauri:/);
});
