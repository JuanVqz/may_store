# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@rails/actioncable", to: "actioncable.esm.js"

# Stimulus controllers are pulled in at runtime by eagerLoadControllersFrom, so a
# <link rel="modulepreload"> for each one only adds ~20 head tags the browser then
# reports as "preloaded but not used". Repin the engine's controllers too: the
# maquina-components importmap pins them with the default preload: true.
pin_all_from "app/javascript/controllers", under: "controllers", preload: false
pin_all_from MaquinaComponents::Engine.root.join("app/javascript/controllers"),
  under: "controllers", preload: false

pin_all_from "app/javascript/channels", under: "channels"
