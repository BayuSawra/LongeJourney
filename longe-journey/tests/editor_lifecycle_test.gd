extends GdUnitTestSuite

func test_report_writer_releases_owned_formatter() -> void:
	var output := RichTextLabel.new()
	var writer := GdUnitRichTextMessageWriter.new(output)
	var formatter_id := writer._report_formatter.get_instance_id()
	assert_bool(is_instance_id_valid(formatter_id)).is_true()
	writer = null
	assert_bool(is_instance_id_valid(formatter_id)).is_false()
	# The output belongs to the caller, not the writer.
	assert_bool(is_instance_valid(output)).is_true()
	output.free()

func test_rpc_dispatch_keeps_message_and_event_payloads() -> void:
	var server := preload("res://addons/gdUnit4/src/network/GdUnitServer.gd").new()
	var original := GdUnitSignals.instance()
	var isolated := GdUnitSignals.new()
	var messages: Array[String] = []
	var events: Array[GdUnitEvent] = []
	isolated.gdunit_message.connect(func(message: String) -> void: messages.append(message))
	isolated.gdunit_event.connect(func(event: GdUnitEvent) -> void: events.append(event))
	Engine.set_meta(GdUnitSignals.META_KEY, isolated)
	server._receive_rpc_data(RPCMessage.of("editor lifecycle regression"))
	var source := GdUnitEvent.new().suite_before("res://tests/editor_lifecycle_test.gd", "isolated", 2)
	server._receive_rpc_data(RPCGdUnitEvent.of(source))
	Engine.set_meta(GdUnitSignals.META_KEY, original)
	server.free()
	assert_array(messages).contains_exactly(["editor lifecycle regression"])
	assert_int(events.size()).is_equal(1)
	assert_int(events[0].type()).is_equal(GdUnitEvent.TESTSUITE_BEFORE)
	assert_str(events[0].suite_name()).is_equal("isolated")
	assert_int(events[0].total_count()).is_equal(2)
