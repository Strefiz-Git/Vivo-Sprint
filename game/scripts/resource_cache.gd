extends Node

var _cache: Dictionary = {}

func get_resource(path: String, type_hint: String = "") -> Resource:
	if _cache.has(path):
		return _cache[path]
	var res = load(path)
	if res:
		_cache[path] = res
	return res

func preload_resources(paths: Array[String]) -> Dictionary:
	var results: Dictionary = {}
	for p in paths:
		results[p] = get_resource(p)
	return results

func get_cached(path: String):
	return _cache.get(path)

func is_cached(path: String) -> bool:
	return _cache.has(path)

func clear_cache():
	_cache.clear()

func remove_from_cache(path: String):
	_cache.erase(path)
