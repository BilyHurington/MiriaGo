{{flutter_js}}
{{flutter_build_config}}

const isTauriDesktop = typeof window.__TAURI__ !== 'undefined';
const monitor = window.__miriagoStartupMonitor;
const loaderOptions = isTauriDesktop
  ? {}
  : {
      serviceWorkerSettings: {
        serviceWorkerVersion: {{flutter_service_worker_version}},
      },
    };

loaderOptions.onEntrypointLoaded = async function (engineInitializer) {
  try {
    monitor?.stage('正在初始化 Flutter...');
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        monitor?.ready();
      });
    });
  } catch (error) {
    monitor?.report('Flutter 初始化失败', error);
    throw error;
  }
};

monitor?.stage('正在载入应用程序...');
_flutter.loader.load(loaderOptions).catch(function (error) {
  monitor?.report('Flutter 入口载入失败', error);
});
