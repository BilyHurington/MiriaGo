(function installMiriaGoStartupMonitor() {
  let pendingStatus = '正在启动 MiriaGo...';

  function statusElement() {
    return document.getElementById('miriago-startup-status');
  }

  function stage(message) {
    if (pendingStatus !== message) {
      void writeLog(`web stage: ${message}`);
    }
    pendingStatus = message;
    const element = statusElement();
    if (element) {
      element.textContent = message;
    }
  }

  function formatError(error) {
    if (error instanceof Error) {
      return error.stack || error.message;
    }
    return String(error ?? '未知错误');
  }

  async function writeLog(message) {
    try {
      const invoke = window.__TAURI__?.core?.invoke;
      if (typeof invoke === 'function') {
        await invoke('append_desktop_log', { request: { message } });
      }
    } catch (_) {}
  }

  function report(label, error) {
    const details = `${label}: ${formatError(error)}`;
    console.error(details);
    stage(`MiriaGo 启动失败\n${details}`);
    void writeLog(`web bootstrap: ${details}`);
  }

  function ready() {
    void writeLog('web stage: Flutter first page displayed');
    statusElement()?.remove();
  }

  window.__miriagoStartupMonitor = { stage, report, ready };
  window.addEventListener('error', function (event) {
    report(
      'JavaScript 载入失败',
      event.error || `${event.message} (${event.filename}:${event.lineno})`,
    );
  });
  window.addEventListener('unhandledrejection', function (event) {
    report('启动任务执行失败', event.reason);
  });
  document.addEventListener('DOMContentLoaded', function () {
    stage(pendingStatus);
  });
  window.setTimeout(function () {
    if (statusElement()) {
      report('启动超时', 'Flutter 在 20 秒内没有显示首个页面');
    }
  }, 20000);
})();
