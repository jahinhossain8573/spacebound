extends RefCounted

const PATH := "user://settings.cfg"

static func guidance_enabled(path := PATH) -> bool:
	var settings := ConfigFile.new()
	settings.load(path)
	return bool(settings.get_value("flight", "guidance", true))

static func save_guidance(enabled: bool, path := PATH) -> Error:
	var settings := ConfigFile.new()
	settings.load(path)
	settings.set_value("flight", "guidance", enabled)
	return settings.save(path)
