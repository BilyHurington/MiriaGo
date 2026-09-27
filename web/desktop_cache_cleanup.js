(async function cleanLegacyDesktopWebCache() {
  if (typeof window.__TAURI__ === 'undefined') {
    return;
  }

  const monitor = window.__miriagoStartupMonitor;
  monitor?.stage('正在检查桌面缓存...');

  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map(function (registration) {
        return registration.unregister();
      }));

      if (navigator.serviceWorker.controller) {
        const reloadKey = 'miriago-service-worker-cleanup-reloaded';
        if (sessionStorage.getItem(reloadKey) !== '1') {
          sessionStorage.setItem(reloadKey, '1');
          monitor?.stage('正在更新桌面缓存...');
          window.location.reload();
          return;
        }
      }
    }

    sessionStorage.removeItem('miriago-service-worker-cleanup-reloaded');
    if ('caches' in window) {
      const names = await caches.keys();
      await Promise.all(names.map(function (name) {
        return caches.delete(name);
      }));
    }
  } catch (error) {
    monitor?.report('清理旧版桌面缓存失败', error);
  }
})();
