package main
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"
import mu "vendor:microui"
import sdl "vendor:sdl3"

time_blocks :: struct {
	start: i64,
	end:   i64,
}

state := struct {
	mu_ctx:        mu.Context,
	atlas_texture: ^sdl.Texture,
	is_tracking:   bool,
	time_blocks:   [10000]time_blocks,
	n_time_blocks: int,
}{}

defaultContext: runtime.Context

main :: proc() {
	context.logger = log.create_console_logger()
	defaultContext = context
	sdl.SetLogPriorities(.VERBOSE)
	sdl.SetLogOutputFunction(
		proc "c" (
			userdata: rawptr,
			category: sdl.LogCategory,
			priority: sdl.LogPriority,
			message: cstring,
		) {
			context = defaultContext
			log.debugf("sdl {} [{}]: {}", category, priority, message)
		},
		nil,
	)

	ok := sdl.Init({.VIDEO})
	assert(ok)
	defer sdl.Quit()

	window := sdl.CreateWindow("simple time tracker", 960, 540, {.RESIZABLE})
	if window == nil {
		fmt.eprintln(sdl.GetError())
		return
	}
	defer sdl.DestroyWindow(window)
	assert(window != nil)

	renderer := sdl.CreateRenderer(window, nil)
	assert(renderer != nil)

	state.atlas_texture = sdl.CreateTexture(
		renderer,
		.RGBA32,
		.TARGET,
		mu.DEFAULT_ATLAS_WIDTH,
		mu.DEFAULT_ATLAS_HEIGHT,
	)
	assert(state.atlas_texture != nil, "no atlas texture")

	ok = sdl.SetTextureBlendMode(state.atlas_texture, sdl.BLENDMODE_BLEND)
	assert(ok)

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i].rgb = 0xff
		pixels[i].a = alpha
	}

	ok = sdl.UpdateTexture(state.atlas_texture, nil, raw_data(pixels), 4 * mu.DEFAULT_ATLAS_WIDTH)
	assert(ok)

	ctx := &state.mu_ctx
	mu.init(ctx, set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) {
			cstr := strings.clone_to_cstring(text)
			sdl.SetClipboardText(cstr)
			delete(cstr)
			return true
		}, get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) {
			if sdl.HasClipboardText() {
				text = string(cstring(sdl.GetClipboardText()))
				ok = true
			}
			return
		})

	ctx.text_width = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height


	// NOTE: This allows for continuous rendering as the window resizes rather than waiting for the resize to finish
	Resize_Data :: struct {
		ctx:      ^mu.Context,
		renderer: ^sdl.Renderer,
	}
	ok = sdl.AddEventWatch(proc "c" (data: rawptr, event: ^sdl.Event) -> bool {
			if event.type == .WINDOW_RESIZED {
				resize_data := (^Resize_Data)(data)
				render(resize_data.ctx, resize_data.renderer)
			}
			return true
		}, &Resize_Data{ctx = ctx, renderer = renderer})
	assert(ok)

	main_loop: for {
		free_all(context.temp_allocator)

		for e: sdl.Event; sdl.PollEvent(&e);  /**/{
			#partial switch e.type {
			case .QUIT:
				break main_loop
			case .MOUSE_MOTION:
				mu.input_mouse_move(ctx, i32(e.motion.x), i32(e.motion.y))
			case .MOUSE_WHEEL:
				mu.input_scroll(ctx, i32(e.wheel.x) * 30, i32(e.wheel.y) * -30)
			case .TEXT_INPUT:
				mu.input_text(ctx, string(e.text.text))

			case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
				fn := mu.input_mouse_down if e.type == .MOUSE_BUTTON_DOWN else mu.input_mouse_up
				switch e.button.button {
				case sdl.BUTTON_LEFT:
					fn(ctx, i32(e.button.x), i32(e.button.y), .LEFT)
				case sdl.BUTTON_MIDDLE:
					fn(ctx, i32(e.button.x), i32(e.button.y), .MIDDLE)
				case sdl.BUTTON_RIGHT:
					fn(ctx, i32(e.button.x), i32(e.button.y), .RIGHT)
				}

			case .KEY_DOWN, .KEY_UP:
				if e.type == .KEY_UP && e.key.scancode == .ESCAPE {
					ok = sdl.PushEvent(&sdl.Event{type = .QUIT})
				}

				fn := mu.input_key_down if e.type == .KEY_DOWN else mu.input_key_up

				#partial switch e.key.scancode {
				case .LSHIFT:
					fn(ctx, .SHIFT)
				case .RSHIFT:
					fn(ctx, .SHIFT)
				case .LCTRL:
					fn(ctx, .CTRL)
				case .RCTRL:
					fn(ctx, .CTRL)
				case .LALT:
					fn(ctx, .ALT)
				case .RALT:
					fn(ctx, .ALT)
				case .RETURN:
					fn(ctx, .RETURN)
				case .KP_ENTER:
					fn(ctx, .RETURN)
				case .BACKSPACE:
					fn(ctx, .BACKSPACE)

				case .LEFT:
					fn(ctx, .LEFT)
				case .RIGHT:
					fn(ctx, .RIGHT)
				case .HOME:
					fn(ctx, .HOME)
				case .END:
					fn(ctx, .END)
				case .A:
					fn(ctx, .A)
				case .X:
					fn(ctx, .X)
				case .C:
					fn(ctx, .C)
				case .V:
					fn(ctx, .V)
				}
			}
		}

		mu.begin(ctx)
		all_windows(ctx)
		mu.end(ctx)

		render(ctx, renderer)
	}
}

// NOTE: This is marked as "contextless" so that the 'context' does need to be set up in the `sdl.AddEventWatch` callback
render :: proc "contextless" (ctx: ^mu.Context, renderer: ^sdl.Renderer) {
	render_texture :: proc "contextless" (
		renderer: ^sdl.Renderer,
		dst: ^sdl.FRect,
		src: mu.Rect,
		color: mu.Color,
	) {
		dst.w = f32(src.w)
		dst.h = f32(src.h)

		sdl.SetTextureAlphaMod(state.atlas_texture, color.a)
		sdl.SetTextureColorMod(state.atlas_texture, color.r, color.g, color.b)
		sdl.RenderTexture(
			renderer,
			state.atlas_texture,
			&sdl.FRect{f32(src.x), f32(src.y), f32(src.w), f32(src.h)},
			dst,
		)
	}

	viewport_rect := &sdl.Rect{}
	sdl.GetCurrentRenderOutputSize(renderer, &viewport_rect.w, &viewport_rect.h)
	sdl.SetRenderViewport(renderer, viewport_rect)
	sdl.SetRenderClipRect(renderer, viewport_rect)
	sdl.RenderClear(renderer)

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text:
			dst := sdl.FRect{f32(cmd.pos.x), f32(cmd.pos.y), 0, 0}
			for ch in cmd.str {
				if ch & 0xc0 != 0x80 {
					r := min(int(ch), 127)
					src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
					render_texture(renderer, &dst, src, cmd.color)
					dst.x += dst.w
				}
			}
		case ^mu.Command_Rect:
			sdl.SetRenderDrawColor(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
			sdl.RenderFillRect(
				renderer,
				&sdl.FRect{f32(cmd.rect.x), f32(cmd.rect.y), f32(cmd.rect.w), f32(cmd.rect.h)},
			)
		case ^mu.Command_Icon:
			src := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - src.w) / 2
			y := cmd.rect.y + (cmd.rect.h - src.h) / 2
			render_texture(renderer, &sdl.FRect{f32(x), f32(y), 0, 0}, src, cmd.color)
		case ^mu.Command_Clip:
			sdl.SetRenderClipRect(
				renderer,
				&sdl.Rect{cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h},
			)
		case ^mu.Command_Jump:
			unreachable()
		}
	}

	sdl.RenderPresent(renderer)
}

all_windows :: proc(ctx: ^mu.Context) {
	@(static) opts := mu.Options{.NO_CLOSE}

	if mu.window(ctx, "timer", mu.Rect{0, 0, 960, 540}, {.NO_TITLE, .NO_CLOSE}) {
		mu.layout_row(ctx, {1}, 200)
		mu.label(ctx, "")
		mu.layout_row(ctx, {300, 100, 140}, 40)
		mu.label(ctx, "")
		mu.label(ctx, "start tracking")
		if .SUBMIT in mu.button(ctx, "", state.is_tracking ? .CLOSE : .CHECK) {
			state.is_tracking = !state.is_tracking
			if state.is_tracking {
				now := time.to_unix_seconds(time.now())
				state.time_blocks[state.n_time_blocks] = time_blocks {
					start = now,
					end   = 0,
				}
				state.n_time_blocks += 1
			} else {
				now := time.to_unix_seconds(time.now())
				state.time_blocks[state.n_time_blocks - 1] = time_blocks {
					start = state.time_blocks[state.n_time_blocks - 1].start,
					end   = now,
				}
			}
		}
		if state.n_time_blocks > 0 {
			block := time_blocks {
				start = state.time_blocks[state.n_time_blocks - 1].start,
				end   = state.time_blocks[state.n_time_blocks - 1].end,
			}
			if block.end == 0 {
				block.end = time.to_unix_seconds(time.now())
			}
			mu.label(ctx, "")
		}
	}

	// if mu.window(ctx, "Demo Window", {40, 40, 300, 450}, opts) {
	//
	// 	if .ACTIVE in mu.header(ctx, "Test Buttons", {.EXPANDED}) {
	// 		mu.layout_row(ctx, {86, -110, -1})
	// 		mu.label(ctx, "Test buttons 1:")
	// 		if .SUBMIT in mu.button(ctx, "Button 1") {}
	// 		if .SUBMIT in mu.button(ctx, "Button 2") {}
	// 		mu.label(ctx, "Test buttons 2:")
	// 		if .SUBMIT in mu.button(ctx, "Button 3") {}
	// 		if .SUBMIT in mu.button(ctx, "Button 4") {}
	// 	}
	// }

}
