extends RefCounted


static func is_available() -> bool:
	if not OS.has_feature("web"):
		return false
	var result: Variant = JavaScriptBridge.eval("""
		(function() {
			var element = document.getElementById("canvas") || document.querySelector("canvas") || document.documentElement;
			var enabled = true;
			if ("fullscreenEnabled" in document) {
				enabled = document.fullscreenEnabled;
			} else if ("webkitFullscreenEnabled" in document) {
				enabled = document.webkitFullscreenEnabled;
			}
			return enabled && !!(element.requestFullscreen || element.webkitRequestFullscreen);
		})()
	""", true)
	return bool(result)


static func is_fullscreen() -> bool:
	if not OS.has_feature("web"):
		return false
	var result: Variant = JavaScriptBridge.eval("""
		(function() {
			return !!(document.fullscreenElement || document.webkitFullscreenElement);
		})()
	""", true)
	return bool(result)


static func toggle() -> void:
	if not is_available():
		return
	JavaScriptBridge.eval("""
		(function() {
			var promise = null;
			if (document.fullscreenElement || document.webkitFullscreenElement) {
				if (document.exitFullscreen) {
					promise = document.exitFullscreen();
				} else if (document.webkitExitFullscreen) {
					document.webkitExitFullscreen();
				}
				if (promise && promise.catch) {
					promise.catch(function() {});
				}
				return;
			}

			var element = document.getElementById("canvas") || document.querySelector("canvas") || document.documentElement;
			if (element.requestFullscreen) {
				promise = element.requestFullscreen();
			} else if (element.webkitRequestFullscreen) {
				element.webkitRequestFullscreen();
			}
			if (promise && promise.catch) {
				promise.catch(function() {});
			}
		})()
	""", true)
