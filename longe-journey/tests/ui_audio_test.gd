extends GdUnitTestSuite


func test_business_buttons_use_one_ui_bus_player_without_duplicate_connections() -> void:
	var host := Control.new()
	add_child(host)
	var first := Button.new()
	first.name = "FirstBusinessButton"
	host.add_child(first)
	await get_tree().process_frame

	UIAudio.scan_buttons()
	assert_bool(UIAudio.is_button_bound(first)).is_true()
	assert_int(first.pressed.get_connections().size()).is_equal(1)
	UIAudio.scan_buttons()
	assert_int(first.pressed.get_connections().size()).is_equal(1)

	var player: AudioStreamPlayer = UIAudio.get_click_player()
	assert_object(player).is_not_null()
	assert_str(str(player.bus)).is_equal("UI")
	assert_object(player.stream).is_not_null()
	first.emit_signal("pressed")
	assert_bool(player.playing).is_true()

	var dynamic := CheckButton.new()
	dynamic.name = "DynamicBusinessButton"
	host.add_child(dynamic)
	await get_tree().process_frame
	UIAudio.scan_buttons()
	assert_bool(UIAudio.is_button_bound(dynamic)).is_true()
	assert_int(dynamic.pressed.get_connections().size()).is_equal(1)

	host.queue_free()
	await get_tree().process_frame
	UIAudio.scan_buttons()


func test_dialogic_choice_buttons_keep_their_own_press_sound() -> void:
	var host := Control.new()
	add_child(host)
	var choice := DialogicNode_ChoiceButton.new()
	host.add_child(choice)
	await get_tree().process_frame

	UIAudio.scan_buttons()
	assert_bool(UIAudio.is_button_bound(choice)).is_false()

	host.queue_free()
	await get_tree().process_frame

func test_transient_button_freed_before_deferred_registration_is_ignored() -> void:
	var host := Control.new()
	add_child(host)
	var transient := Button.new()
	host.add_child(transient)
	transient.free()
	await get_tree().process_frame

	var stable := Button.new()
	host.add_child(stable)
	await get_tree().process_frame
	assert_bool(UIAudio.is_button_bound(stable)).is_true()
	assert_int(stable.pressed.get_connections().size()).is_equal(1)

	host.queue_free()
	await get_tree().process_frame
