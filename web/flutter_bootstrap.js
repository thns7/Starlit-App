{{flutter_js}}
{{flutter_build_config}}

// Cada publicação tem um id novo (o commit, preenchido pelo workflow Deploy Web):
// o app sempre baixa o main.dart.js da versão publicada, em vez de reaproveitar
// a cópia antiga guardada pelo navegador.
(function () {
  const build = "__BUILD_ID__";
  if (!build.startsWith("__")) {
    for (const b of _flutter.buildConfig.builds) {
      if (b.mainJsPath) b.mainJsPath += "?v=" + build;
    }
  }
  _flutter.loader.load();
})();
