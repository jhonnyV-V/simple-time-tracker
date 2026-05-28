package main
import clay "./clay-odin"
import "base:runtime"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import "vendor:raylib"


ClayColorToRlColor :: proc(color: clay.Color) -> raylib.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

@(private = "file")
DrawArc :: proc(
	x, y: f32,
	inner_rad, outer_rad: f32,
	start_angle, end_angle: f32,
	color: clay.Color,
) {
	raylib.DrawRing(
		{math.round(x), math.round(y)},
		math.round(inner_rad),
		outer_rad,
		start_angle,
		end_angle,
		10,
		ClayColorToRlColor(color),
	)
}

@(private = "file")
DrawRect :: proc(x, y, w, h: f32, color: clay.Color) {
	raylib.DrawRectangle(
		i32(math.round(x)),
		i32(math.round(y)),
		i32(math.round(w)),
		i32(math.round(h)),
		ClayColorToRlColor(color),
	)
}

@(private = "file")
DrawRectRounded :: proc(x, y, w, h: f32, radius: f32, color: clay.Color) {
	raylib.DrawRectangleRounded({x, y, w, h}, radius, 8, ClayColorToRlColor(color))
}


// Alias for compatibility, default to ascii support
MeasureText :: RaylibMeasureText

MeasureTextUnicode :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	// Needed for grapheme_count
	context = runtime.default_context()

	line_width: f32 = 0

	font := raylibFonts[config.fontId].font
	text_str := string(text.chars[:text.length])

	// This function seems somewhat expensive, if you notice performance issues, you could assume
	// - 1 codepoint per visual character (no grapheme clusters), where you can get the length from the loop
	// - 1 byte per visual character (ascii), where you can get the length with `text.length`
	// see `measure_text_ascii`

	grapheme_count, _, _ := utf8.grapheme_count(text_str)

	for letter, byte_idx in text_str {
		glyph_index := raylib.GetGlyphIndex(font, letter)

		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
		}
	}

	scaleFactor := f32(config.fontSize) / f32(font.baseSize)

	// Note:
	//   I'd expect this to be `grapheme_count - 1`,
	//   but that seems to be one letterSpacing too small
	//   maybe that's a raylib bug, maybe that's Clay?

	total_spacing := f32(grapheme_count) * f32(config.letterSpacing)
	return {width = line_width * scaleFactor + total_spacing, height = f32(config.fontSize)}
}

MeasureTextAscii :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	line_width: f32 = 0

	font := raylibFonts[config.fontId].font

	text_str := string(text.chars[:text.length])

	for i in 0 ..< len(text_str) {
		glyph_index := text_str[i] - 32

		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
		}
	}

	scaleFactor := f32(config.fontSize) / f32(font.baseSize)

	// Note:
	//   I'd expect this to be `len(text_str) - 1`,
	//   but that seems to be one letterSpacing too small
	//   maybe that's a raylib bug, maybe that's Clay?

	total_spacing := f32(len(text_str)) * f32(config.letterSpacing)
	return {width = line_width * scaleFactor + total_spacing, height = f32(config.fontSize)}
}

RaylibMeasureText :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	// Measure string size for Font
	textSize := clay.Dimensions{}

	maxTextWidth: f32 = 0
	lineTextWidth: f32 = 0
	maxLineCharCount := 0
	lineCharCount := 0

	textHeight := config.fontSize
	fontToUse := raylibFonts[config.fontId].font
	// Font failed to load, likely the fonts are in the wrong place relative to the execution dir.
	// RayLib ships with a default font, so we can continue with that built in one.
	if fontToUse.glyphs == nil {
		fontToUse = raylib.GetFontDefault()
	}

	scaleFactor := f32(config.fontSize) / f32(fontToUse.baseSize)


	for i in 0 ..< text.length {
		lineCharCount += 1
		if text.chars[i] == '\n' {
			maxTextWidth = math.max(maxTextWidth, lineTextWidth)
			maxLineCharCount = math.max(maxLineCharCount, lineCharCount)
			lineTextWidth = 0
			lineCharCount = 0
			continue
		}
		index := text.chars[i] - 32
		if (fontToUse.glyphs[index].advanceX != 0) {
			lineTextWidth += f32(fontToUse.glyphs[index].advanceX)
		} else {
			lineTextWidth += (fontToUse.recs[index].width + f32(fontToUse.glyphs[index].offsetX))
		}
	}

	maxTextWidth = math.max(maxTextWidth, lineTextWidth)
	maxLineCharCount = math.max(maxLineCharCount, lineCharCount)

	textSize.width = maxTextWidth * scaleFactor + f32(lineCharCount * int(config.letterSpacing))
	textSize.height = f32(textHeight)

	return textSize
}

ClayRaylibRender :: proc(
	commandArray: ^clay.ClayArray(clay.RenderCommand),
	allocator := context.temp_allocator,
) {
	for i in 0 ..< commandArray.length {
		renderCommand := clay.RenderCommandArray_Get(commandArray, i)
		boundingBox: clay.BoundingBox = {
			x      = renderCommand.boundingBox.x,
			y      = renderCommand.boundingBox.y,
			width  = renderCommand.boundingBox.width,
			height = renderCommand.boundingBox.height,
		}

		#partial switch (renderCommand.commandType) {
		case .Text:
			textData: clay.TextRenderData = renderCommand.renderData.text
			fontToUse := raylibFonts[textData.fontId].font

			text := string(textData.stringContents.chars[:textData.stringContents.length])

			// Raylib uses C strings instead of Odin strings, so we need to clone
			// Assume this will be freed elsewhere since we default to the temp allocator
			cstrText := strings.clone_to_cstring(text, allocator)

			raylib.DrawTextEx(
				fontToUse,
				cstrText,
				{boundingBox.x, boundingBox.y},
				f32(textData.fontSize),
				f32(textData.letterSpacing),
				ClayColorToRlColor(textData.textColor),
			)

			break

		case .Image:
			imageTexture: ^raylib.Texture2D = cast(^raylib.Texture2D)renderCommand.renderData.image.imageData
			tintColor: clay.Color = renderCommand.renderData.image.backgroundColor
			if (tintColor.r == 0 && tintColor.g == 0 && tintColor.b == 0 && tintColor.a == 0) {
				tintColor = {255, 255, 255, 255}
			}

			raylib.DrawTexturePro(
				imageTexture^,
				{x = 0, y = 0, width = f32(imageTexture.width), height = f32(imageTexture.height)},
				{
					x = boundingBox.x,
					y = boundingBox.y,
					width = f32(imageTexture.width),
					height = f32(imageTexture.height),
				},
				{},
				0,
				ClayColorToRlColor(tintColor),
			)
			break

		case .ScissorStart:
			raylib.BeginScissorMode(
				i32(math.round(boundingBox.x)),
				i32(math.round(boundingBox.y)),
				i32(math.round(boundingBox.width)),
				i32(math.round(boundingBox.height)),
			)
			break

		case .ScissorEnd:
			raylib.EndScissorMode()
			break

		case .Rectangle:
			{
				config := renderCommand.renderData.rectangle
				if config.cornerRadius.topLeft > 0 {
					radius: f32 =
						(config.cornerRadius.topLeft * 2) /
						min(boundingBox.width, boundingBox.height)
					DrawRectRounded(
						boundingBox.x,
						boundingBox.y,
						boundingBox.width,
						boundingBox.height,
						radius,
						config.backgroundColor,
					)
				} else {
					DrawRect(
						boundingBox.x,
						boundingBox.y,
						boundingBox.width,
						boundingBox.height,
						config.backgroundColor,
					)
				}
				break
			}
		case .Border:
			{
				config := renderCommand.renderData.border
				// Left border
				if config.width.left > 0 {
					DrawRect(
						boundingBox.x,
						boundingBox.y + config.cornerRadius.topLeft,
						f32(config.width.left),
						boundingBox.height -
						config.cornerRadius.topLeft -
						config.cornerRadius.bottomLeft,
						config.color,
					)
				}
				// Right border
				if config.width.right > 0 {
					DrawRect(
						boundingBox.x + boundingBox.width - f32(config.width.right),
						boundingBox.y + config.cornerRadius.topRight,
						f32(config.width.right),
						boundingBox.height -
						config.cornerRadius.topRight -
						config.cornerRadius.bottomRight,
						config.color,
					)
				}
				// Top border
				if config.width.top > 0 {
					DrawRect(
						boundingBox.x + config.cornerRadius.topLeft,
						boundingBox.y,
						boundingBox.width -
						config.cornerRadius.topLeft -
						config.cornerRadius.topRight,
						f32(config.width.top),
						config.color,
					)
				}
				// Bottom border
				if config.width.bottom > 0 {
					DrawRect(
						boundingBox.x + config.cornerRadius.bottomLeft,
						boundingBox.y + boundingBox.height - f32(config.width.bottom),
						boundingBox.width -
						config.cornerRadius.bottomLeft -
						config.cornerRadius.bottomRight,
						f32(config.width.bottom),
						config.color,
					)
				}

				// Rounded Borders
				if config.cornerRadius.topLeft > 0 {
					DrawArc(
						boundingBox.x + config.cornerRadius.topLeft,
						boundingBox.y + config.cornerRadius.topLeft,
						config.cornerRadius.topLeft - f32(config.width.top),
						config.cornerRadius.topLeft,
						180,
						270,
						config.color,
					)
				}
				if config.cornerRadius.topRight > 0 {
					DrawArc(
						boundingBox.x + boundingBox.width - config.cornerRadius.topRight,
						boundingBox.y + config.cornerRadius.topRight,
						config.cornerRadius.topRight - f32(config.width.top),
						config.cornerRadius.topRight,
						270,
						360,
						config.color,
					)
				}
				if config.cornerRadius.bottomLeft > 0 {
					DrawArc(
						boundingBox.x + config.cornerRadius.bottomLeft,
						boundingBox.y + boundingBox.height - config.cornerRadius.bottomLeft,
						config.cornerRadius.bottomLeft - f32(config.width.top),
						config.cornerRadius.bottomLeft,
						90,
						180,
						config.color,
					)
				}
				if config.cornerRadius.bottomRight > 0 {
					DrawArc(
						boundingBox.x + boundingBox.width - config.cornerRadius.bottomRight,
						boundingBox.y + boundingBox.height - config.cornerRadius.bottomRight,
						config.cornerRadius.bottomRight - f32(config.width.bottom),
						config.cornerRadius.bottomRight,
						0.1,
						90,
						config.color,
					)
				}
				break
			}
		case .Custom:
			break

		case .None:
			break

		}
	}
}
