extends Node

## Fireplace 2 — UI Theme Builder
## Creates a warm pixel-art themed UI at runtime.
## Call ThemeBuilder.build() to get the Theme resource.

const COL_DARK_BROWN  := Color("#3b1f0b")
const COL_BROWN       := Color("#6b3a1f")
const COL_WARM_ORANGE := Color("#d4712a")
const COL_EMBER       := Color("#ff6633")
const COL_GOLD        := Color("#ffcc33")
const COL_CREAM       := Color("#f5e6c8")
const COL_ASH         := Color("#2a1a0e")
const COL_SMOKE       := Color("#8c7a6b")
const COL_RED         := Color("#cc2222")
const COL_GREEN       := Color("#44aa33")
const COL_DISABLED    := Color("#5a4a3a")

static func build() -> Theme:
	var theme := Theme.new()

	# ── Fonts ──
	theme.set_default_font_size(16)

	# ── Button ──
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COL_BROWN
	btn_normal.border_color = COL_WARM_ORANGE
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(4)
	btn_normal.set_content_margin_all(12)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = COL_WARM_ORANGE
	btn_hover.border_color = COL_GOLD
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(12)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = COL_EMBER
	btn_pressed.border_color = COL_GOLD
	btn_pressed.set_border_width_all(3)
	btn_pressed.set_corner_radius_all(4)
	btn_pressed.set_content_margin_all(12)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = COL_DISABLED
	btn_disabled.border_color = COL_SMOKE
	btn_disabled.set_border_width_all(2)
	btn_disabled.set_corner_radius_all(4)
	btn_disabled.set_content_margin_all(12)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", COL_CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", COL_GOLD)
	theme.set_color("font_disabled_color", "Button", COL_SMOKE)
	theme.set_font_size("font_size", "Button", 16)

	# ── Label ──
	theme.set_color("font_color", "Label", COL_CREAM)
	theme.set_font_size("font_size", "Label", 16)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))

	# ── Panel ──
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(COL_ASH, 0.92)
	panel_style.border_color = COL_WARM_ORANGE
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# ── ProgressBar ──
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = COL_ASH
	bar_bg.border_color = COL_BROWN
	bar_bg.set_border_width_all(2)
	bar_bg.set_corner_radius_all(3)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COL_EMBER
	bar_fill.set_corner_radius_all(2)

	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	# ── HSlider ──
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = COL_ASH
	slider_bg.set_border_width_all(1)
	slider_bg.border_color = COL_BROWN
	slider_bg.set_corner_radius_all(3)
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = COL_WARM_ORANGE
	slider_fill.set_corner_radius_all(3)
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)

	# ── CheckButton ──
	theme.set_color("font_color", "CheckButton", COL_CREAM)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)

	return theme

## Creates a styled button with optional icon-like prefix
static func make_button(text: String, width: float = 200.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(width, 40)
	return btn

## Creates a shop-item button showing name, cost, and owned status
static func make_shop_button(item_name: String, cost: int, owned: bool, can_afford: bool) -> Button:
	var btn := Button.new()
	if owned:
		btn.text = "%s  [OWNED]" % item_name
		btn.disabled = true
	elif not can_afford:
		btn.text = "%s  (%d)" % [item_name, cost]
		btn.disabled = true
	else:
		btn.text = "%s  (%d)" % [item_name, cost]
	btn.custom_minimum_size = Vector2(340, 36)
	return btn
