class_name ApiClient
extends Node

var base_url: String = ""


func request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var url     := base_url + path
	var headers := PackedStringArray(["Content-Type: application/json"])
	var http_method := _resolve_method(method)
	var json_body   := JSON.stringify(body) if not body.is_empty() else ""

	var err := http.request(url, headers, http_method, json_body)
	if err != OK:
		http.queue_free()
		return {
			"code": -1,
			"body": {
				"error": {
					"code": "REQUEST_FAILED",
					"message": "Failed to send request."
				}
			}
		}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var raw_body: PackedByteArray = result[3]

	var parsed = JSON.parse_string(raw_body.get_string_from_utf8())
	return {
		"code": response_code,
		"body": parsed if parsed != null else {}
	}


func _resolve_method(method: String) -> HTTPClient.Method:
	match method.to_upper():
		"GET":    return HTTPClient.METHOD_GET
		"POST":   return HTTPClient.METHOD_POST
		"PUT":    return HTTPClient.METHOD_PUT
		"PATCH":  return HTTPClient.METHOD_PATCH
		"DELETE": return HTTPClient.METHOD_DELETE
	return HTTPClient.METHOD_GET
