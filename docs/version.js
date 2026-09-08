fetch("https://api.github.com/repos/piitaya/hue-camera-viewer/releases/latest")
  .then(function (response) { return response.ok ? response.json() : null; })
  .then(function (release) {
    if (!release || !release.tag_name) return;
    var label = document.getElementById("version");
    label.textContent = label.dataset.prefix + release.tag_name.replace(/^v/, "");
    label.hidden = false;
  })
  .catch(function () {});
