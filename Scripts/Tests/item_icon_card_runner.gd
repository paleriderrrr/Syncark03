extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var scene: PackedScene = load("res://Scenes/Components/item_icon_card.tscn")
	var card: ItemIconCard = scene.instantiate() as ItemIconCard
	root.add_child(card)
	await process_frame

	card.configure({
		"display_name": "Lettuce Leaf",
		"count": 3,
		"display_price": 4,
		"discount_percent": 20,
		"kind": &"food",
		"category": &"fruit",
		"rarity": &"rare",
	}, null, {})
	await process_frame

	var name_label: Label = card.get_node("%NameLabel")
	var count_label: Label = card.get_node("%CountLabel")
	var price_label: Label = card.get_node("%PriceLabel")
	var discount_label: Label = card.get_node("%DiscountLabel")
	var discount_badge: Control = card.get_node("%DiscountBadge")
	var rarity_badge: Control = card.get_node("%RarityBadge")
	var category_badge: Control = card.get_node("%CategoryBadge")
	var category_label: Label = card.get_node("%CategoryLabel")
	var rarity_bar: ColorRect = card.get_node("%RarityBar")

	_assert(name_label.text == "Lettuce Leaf", "Card name should render as a single explicit title")
	_assert(int(name_label.autowrap_mode) == 0, "Card name should stay on one line")
	_assert(name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Card name should stay bottom centered")
	_assert(name_label.offset_top >= 132.0, "Card name should sit in the bottom band of the card")
	_assert(card.custom_minimum_size.y >= name_label.offset_bottom, "Card scene minimum height should be large enough for the template label layout")
	_assert(count_label.text == "x3", "Count badge should render quantity")
	_assert(price_label.text == "4 G", "Price badge should render package price")
	_assert(discount_badge.visible, "Discount badge should be visible when a discount exists")
	_assert(discount_label.text == "-20%", "Discount badge should render percent off")
	_assert(rarity_badge.visible, "Rarity badge should be visible for market cards")
	_assert(category_badge.visible, "Category badge should be visible for food cards")
	_assert(category_label.text == "蔬果", "Category badge should show the Chinese food category")
	_assert(rarity_bar.color.a > 0.0, "Rarity bar should use a visible color")
	_assert(rarity_bar.offset_bottom <= 12.0, "Card should not use a full solid rarity background")

	card.configure({
		"display_name": "Stored Berry",
		"count": 7,
		"entry_kind": &"expansion",
		"rarity": &"common",
	}, null, {})
	await process_frame

	_assert(not discount_badge.visible, "Discount badge should hide when no discount exists")
	_assert(price_label.text == "", "Price badge should hide text when no price exists")
	_assert(count_label.text == "x7", "Inventory card should still show count badge")
	_assert(not category_badge.visible, "Category badge should hide for non-food cards")

	card.queue_free()
	if _failures.is_empty():
		print("ITEM_ICON_CARD_TEST_PASS")
		quit(0)
	else:
		printerr("ITEM_ICON_CARD_TEST_FAIL")
		for failure in _failures:
			printerr("- %s" % failure)
		quit(1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
