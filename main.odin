package main

import clay "./clay-odin"
import "core:c"
import "vendor:raylib"

windowWidth: i32 = 1024
windowHeight: i32 = 768

syntaxImage: raylib.Texture2D = {}
checkImage1: raylib.Texture2D = {}

FONT_ID_BODY_16 :: 0
FONT_ID_TITLE_56 :: 9
FONT_ID_TITLE_52 :: 1
FONT_ID_TITLE_48 :: 2
FONT_ID_TITLE_36 :: 3
FONT_ID_TITLE_32 :: 4
FONT_ID_BODY_36 :: 5
FONT_ID_BODY_30 :: 6
FONT_ID_BODY_28 :: 7
FONT_ID_BODY_24 :: 8

COLOR_LIGHT :: clay.Color{244, 235, 230, 255}
COLOR_LIGHT_HOVER :: clay.Color{224, 215, 210, 255}
COLOR_BUTTON_HOVER :: clay.Color{238, 227, 225, 255}
COLOR_BROWN :: clay.Color{61, 26, 5, 255}
//COLOR_RED :: clay.Color {252, 67, 27, 255}
COLOR_RED :: clay.Color{168, 66, 28, 255}
COLOR_RED_HOVER :: clay.Color{148, 46, 8, 255}
COLOR_ORANGE :: clay.Color{225, 138, 50, 255}
COLOR_BLUE :: clay.Color{111, 173, 162, 255}
COLOR_TEAL :: clay.Color{111, 173, 162, 255}
COLOR_BLUE_DARK :: clay.Color{2, 32, 82, 255}
COLOR_WHITE :: clay.Color{255, 255, 255, 255}

// Colors for top stripe
COLOR_TOP_BORDER_1 :: clay.Color{168, 66, 28, 255}
COLOR_TOP_BORDER_2 :: clay.Color{223, 110, 44, 255}
COLOR_TOP_BORDER_3 :: clay.Color{225, 138, 50, 255}
COLOR_TOP_BORDER_4 :: clay.Color{236, 189, 80, 255}
COLOR_TOP_BORDER_5 :: clay.Color{240, 213, 137, 255}

COLOR_BLOB_BORDER_1 :: clay.Color{168, 66, 28, 255}
COLOR_BLOB_BORDER_2 :: clay.Color{203, 100, 44, 255}
COLOR_BLOB_BORDER_3 :: clay.Color{225, 138, 50, 255}
COLOR_BLOB_BORDER_4 :: clay.Color{236, 159, 70, 255}
COLOR_BLOB_BORDER_5 :: clay.Color{240, 189, 100, 255}


HEADER_SIZE :: 40

headerTextConfig := clay.TextElementConfig {
	fontId    = FONT_ID_BODY_24,
	fontSize  = 24,
	textColor = {61, 26, 5, 255},
}

border2pxRed := clay.BorderElementConfig {
	width = {2, 2, 2, 2, 0},
	color = COLOR_RED,
}

RaylibFont :: struct {
	fontId: u16,
	font:   raylib.Font,
}

raylibFonts := [dynamic]RaylibFont{}

Screens :: enum {
	Timer = 1,
	List,
	Labels,
}
selectedScreen := Screens.Timer

handleHeaderButtonInteraction :: proc "c" (
	id: clay.ElementId,
	pointerData: clay.PointerData,
	userData: rawptr,
) {
	if pointerData.state == .PressedThisFrame {
		if int(uintptr(userData)) >= 0 && int(uintptr(userData)) <= int(Screens.Labels) {
			selectedScreen = Screens(int(uintptr(userData)))
		}
	}
}

HeaderButton :: proc(text: string, onHoverData: rawptr) {
	focusColor := clay.Color{100, 100, 100, 255}
	defaultColor := clay.Color{140, 140, 140, 255}
	if clay.UI()(
	{
		layout = {padding = {left = 16, right = 16, top = 8, bottom = 8}},
		backgroundColor = clay.Hovered() ? focusColor : defaultColor,
		cornerRadius = {5, 5, 5, 5},
		border = clay.Hovered() ? {color = defaultColor, width = {1, 1, 1, 1, 0}} : {},
	},
	) {
		clay.Text(
			text,
			clay.TextElementConfig {
				fontId = FONT_ID_BODY_16,
				fontSize = 16,
				textColor = COLOR_WHITE,
			},
		)
		clay.OnHover(handleHeaderButtonInteraction, onHoverData)
	}
}

TimerView :: proc() {
	clay.Text(
		"TIMER VIEW",
		clay.TextElementConfig{fontId = FONT_ID_TITLE_56, fontSize = 56, textColor = COLOR_WHITE},
	)
}

CreateLayout :: proc(frametime: f32) -> clay.ClayArray(clay.RenderCommand) {
	sizingExpand := clay.Sizing {
		width  = clay.SizingGrow(),
		height = clay.SizingGrow(),
	}

	segmentColor := clay.Color{90, 90, 90, 255}
	radius := clay.CornerRadius{8, 8, 8, 8}

	clay.BeginLayout()
	if clay.UI(clay.ID("OuterContainer"))(
	{
		backgroundColor = {43, 42, 51, 255},
		layout = {
			sizing = sizingExpand,
			layoutDirection = .TopToBottom,
			padding = {left = 16, right = 16, top = 16, bottom = 16},
			childGap = 16,
		},
	},
	) {

		if clay.UI(clay.ID("HeaderBar"))(
		{
			layout = {
				sizing = {height = clay.SizingFixed(60), width = clay.SizingGrow()},
				layoutDirection = .LeftToRight,
				childGap = 16,
				childAlignment = {y = .Center},
				padding = {left = 16, right = 16},
			},
			backgroundColor = segmentColor,
			cornerRadius = radius,
		},
		) {
			if selectedScreen != .Timer {
				HeaderButton("Timer", rawptr(uintptr(int(Screens.Timer))))
			}
			if selectedScreen != .List {
				HeaderButton("List", rawptr(uintptr(int(Screens.List))))
			}
			if selectedScreen != .Labels {
				HeaderButton("Labels", rawptr(uintptr(int(Screens.Labels))))
			}
			if clay.UI()({layout = {sizing = {width = clay.SizingGrow()}}}) {
			}
			//any other header stuff goes here
		}
		if clay.UI(clay.ID("LowerContent"))(
		{layout = {sizing = sizingExpand, layoutDirection = .LeftToRight, childGap = 16}},
		) {
			if clay.UI(clay.ID("MainContent"))(
			{
				layout = {
					sizing = sizingExpand,
					layoutDirection = .TopToBottom,
					childGap = 16,
					padding = {16, 16, 16, 16},
				},
				backgroundColor = segmentColor,
				cornerRadius = radius,
				clip = {vertical = true, horizontal = true, childOffset = clay.GetScrollOffset()},
			},
			) {
				#partial switch (selectedScreen) {
				case .Timer:
					TimerView()
					break

				}
			}
		}
	}
	return clay.EndLayout(frametime)
}

loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
		&raylibFonts,
		fontId,
		RaylibFont {
			font = raylib.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
			fontId = cast(u16)fontId,
		},
	)
	raylib.SetTextureFilter(raylibFonts[fontId].font.texture, raylib.TextureFilter.TRILINEAR)
}

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

main :: proc() {
	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(MeasureText, nil)

	raylib.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	raylib.InitWindow(windowWidth, windowHeight, "Raylib Odin Example")
	raylib.SetTargetFPS(raylib.GetMonitorRefreshRate(0))
	loadFont(FONT_ID_TITLE_56, 56, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_52, 52, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_48, 48, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_36, 36, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_32, 32, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_BODY_36, 36, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_30, 30, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_28, 28, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_24, 24, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_16, 16, "resources/Quicksand-Semibold.ttf")

	debugModeEnabled: bool = false

	for !raylib.WindowShouldClose() {
		defer free_all(context.temp_allocator)
		windowWidth = raylib.GetScreenWidth()
		windowHeight = raylib.GetScreenHeight()
		if (raylib.IsKeyPressed(.D)) {
			debugModeEnabled = !debugModeEnabled
			clay.SetDebugModeEnabled(debugModeEnabled)
		}
		clay.SetPointerState(
			transmute(clay.Vector2)raylib.GetMousePosition(),
			raylib.IsMouseButtonDown(raylib.MouseButton.LEFT),
		)
		clay.UpdateScrollContainers(
			false,
			transmute(clay.Vector2)raylib.GetMouseWheelMoveV() * 10,
			raylib.GetFrameTime(),
		)
		clay.SetLayoutDimensions(
			{cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()},
		)
		renderCommands := CreateLayout(raylib.GetFrameTime())
		raylib.BeginDrawing()
		ClayRaylibRender(&renderCommands)
		raylib.EndDrawing()
	}
}
