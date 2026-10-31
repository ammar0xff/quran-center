{{flutter_js}}
{{flutter_build_config}}

const urlParams = new URLSearchParams(window.location.search);
const forceCpu = urlParams.get('gpu') !== 'true';

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const config = {};
    if (forceCpu) {
      config.canvasKitForceCpuOnly = true;
    }
    const appRunner = await engineInitializer.initializeEngine(config);
    await appRunner.runApp();
  }
});
