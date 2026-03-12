class_name TestUtils
extends RefCounted


static func expect_true(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


static func expect_eq(failures: Array[String], actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s | actual=%s expected=%s" % [message, str(actual), str(expected)])
