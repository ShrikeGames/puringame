extends SceneTree

class_name TestBase

var test_count := 0
var pass_count := 0
var fail_count := 0
var test_node: Node

func _init():
	# Create a node to handle async operations
	test_node = Node.new()
	test_node.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	get_root().add_child(test_node)
	
	print("\nRunning tests...")
	await setup()
	await run_tests()
	print_results()
	quit()

func run_tests():
	# Override in child class
	pass

func setup():
	# Override in child class
	pass

func before_test():
	# Override in child class
	pass

func after_test():
	# Override in child class
	pass

func print_results():
	print("\nTest Results:")
	print("Total: ", test_count)
	print("Passed: ", pass_count)
	print("Failed: ", fail_count)

func assert_true(condition: bool, message := ""):
	test_count += 1
	if condition:
		pass_count += 1
		print("✓ Pass: ", message if message else "assertion true")
	else:
		fail_count += 1
		print("✗ Fail: ", message if message else "assertion false")

func assert_false(condition: bool, message := ""):
	assert_true(not condition, message)

func assert_equal(a, b, message := ""):
	test_count += 1
	if a == b:
		pass_count += 1
		print("✓ Pass: ", message if message else str(a) + " equals " + str(b))
	else:
		fail_count += 1
		print("✗ Fail: ", message if message else str(a) + " does not equal " + str(b))

func assert_almost_equal(a: float, b: float, tolerance: float, message := ""):
	test_count += 1
	if abs(a - b) <= tolerance:
		pass_count += 1
		print("✓ Pass: ", message if message else str(a) + " ≈ " + str(b))
	else:
		fail_count += 1
		print("✗ Fail: ", message if message else str(a) + " !≈ " + str(b))

func fail(message: String):
	fail_count += 1
	print("✗ Fail: ", message)