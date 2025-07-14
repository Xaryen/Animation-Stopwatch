#+feature dynamic-literals

package program

import rl "vendor:raylib"
import "core:log"
import "core:fmt"
import "core:c"

_ :: log

BG_COL :: rl.Color{30, 30, 30, 255}

WIDTH  :: 600
HEIGHT :: 750

DEFAULT_RES :: [2]i32{WIDTH, HEIGHT}

BUTTON_SIZE :: [2]f32{350, 35}

g_debug_mode: bool

g_font: rl.Font
g_run: bool
g_paused: bool = true

g_time_rate := 1

g_current_time_frames: int
g_time_since_last:     int
g_accumulated_time:    int


g_time          := f64(0)
g_24fps_time    := f64(0)
FRAMETIME_24FPS :: f64(1.0/24)

g_lang := Language(.ENG)

// design:
/*
	elements:
		main timer - resetable
		left  - time since last stop
		right - times add in current run (gets value from main timer after pause)
	input:
		start - stop - reset button
		get current time button
		TODO:
		(new) custom start time textbox
*/

Language :: enum {
	ENG,
	JP,
}

TITLE_STR := [Language]cstring{
	.ENG = "STOPWATCH",
	.JP  = "<missing>",
}

START_STR := [Language]cstring{
	.ENG = "START",
	.JP  = "<missing>",
}

STOP_STR := [Language]cstring{
	.ENG = "STOP",
	.JP  = "<missing>",
}

RESET_STR := [Language]cstring{
	.ENG = "RESET",
	.JP  = "リセット",
}

GETTIME_STR := [Language]cstring{
	.ENG = "GET TIME",
	.JP  = "<missing>",
}

format_anim_time :: proc(time_frames: int) -> cstring {
	// context.allocator = context.temp_allocator

	minutes := time_frames/24/60
	seconds := time_frames/24 - (minutes * 60)
	frames  := time_frames - (time_frames/24 * 24)
	
	return fmt.ctprintf("%v : %v + %v k", minutes, seconds, frames)
}

get_curr_time :: proc() {
	g_time_since_last = g_current_time_frames - g_accumulated_time
	g_accumulated_time = g_current_time_frames
}


// web-safe keyboard handling since rl.IsKeyPressed doesn't work
Keyboard_Key :: enum {
	SPACE,
	ENTER,
	R,
	P,
	A,S,D,W,
}
Keyboard_Keys :: bit_set[Keyboard_Key; u32]
g_keys_down: Keyboard_Keys
key_pressed_safe :: proc(key: Keyboard_Key) -> bool {

	context.allocator = context.temp_allocator

	was_pressed := false

	rl_key_map := map[Keyboard_Key]rl.KeyboardKey{
		.SPACE = .SPACE,
		.ENTER = .ENTER,
		.R = .R,
		.P = .P,
		.A = .A,
		.S = .S,
		.D = .D,
		.W = .W,
	}

	rl_key := rl_key_map[key]

	if key not_in g_keys_down {
		if rl.IsKeyDown(rl_key) {
			g_keys_down += Keyboard_Keys{key}
			was_pressed = true
		}
	} else {
		if rl.IsKeyUp(rl_key) {
			g_keys_down -= Keyboard_Keys{key}
		}
	}
	
	return was_pressed
}

init :: proc() {
	g_run = true
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(expand_values(DEFAULT_RES), "Animation Stopwatch")

	text := #load("codepoints.txt", cstring)

	// Get codepoints from text
	codepointCount := i32(0)
	codepoints := rl.LoadCodepoints(text, &codepointCount)
	
	g_font = rl.LoadFontEx("assets/NotoSansJP-Regular.ttf", 36, codepoints, codepointCount)
	rl.UnloadCodepoints(codepoints)

	rl.GuiSetFont(g_font)
	rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 36)
	// rl.GuiSetStyle(.DEFAULT, cast(i32)rl.GuiDefaultProperty.TEXT_SIZE, 36)

}

update :: proc() {
	total_time := rl.GetTime()
	next_24fps_frame := false

	g_time += f64(rl.GetFrameTime())

	if (g_time >= FRAMETIME_24FPS) {
		next_24fps_frame = true
		g_time -= FRAMETIME_24FPS
	} else {
		next_24fps_frame = false
	}

	if g_paused {
		next_24fps_frame = false
	}

	if next_24fps_frame {
		g_current_time_frames += 1 * g_time_rate
	}

	// crappy adhoc autolayout
	rect_pad     := [2]f32{15, 15}
	start_pos    := [2]f32{0, 0}
	pad          := [2]f32{0, 10} 
	//pad_start : [2]f32 = 0
	
	// controls_rect := rl.Rectangle{
	// 	start_pos.x,
	// 	start_pos.y,
	// 	BUTTON_SIZE.x + 2*rect_pad.x,
	// 	f32(rl.GetScreenHeight())
	// }

	rl.BeginDrawing()
	rl.ClearBackground({120, 120, 153, 255})

	// BG
	background := rl.Rectangle{0, 0, WIDTH, HEIGHT}
	rl.DrawRectangleRec(background, BG_COL)

	//GUI
	{
		cursor := start_pos
		cursor += rect_pad

		// rl.DrawRectangleRec(
		// 	controls_rect,
		// 	rl.BLACK,
		// )

		//TITLE
		rl.GuiLabelButton({cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y}, TITLE_STR[g_lang])
		cursor.y += pad.y + BUTTON_SIZE.y

		// if rl.GuiButton(
		// 	{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
		// 	CHANGE_LANG_STR[g_lang],
		// ) {
		// 	g_lang = .JP if g_lang == .ENG else .ENG
		// }

		cursor.y += pad.y + BUTTON_SIZE.y

		rl.GuiLabel(		
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			format_anim_time(g_current_time_frames)
		)
		cursor.y += pad.y + BUTTON_SIZE.y

		rl.GuiLabel(		
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			format_anim_time(g_time_since_last)
		)
		cursor.y += pad.y + BUTTON_SIZE.y

		rl.GuiLabel(		
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			format_anim_time(g_accumulated_time)
		)
		cursor.y += pad.y + BUTTON_SIZE.y
		

		// START/STOP

		start_str := START_STR[g_lang] if g_paused else STOP_STR[g_lang]

		if rl.GuiButton({cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y}, start_str) {
			g_paused = !g_paused
		}
		cursor.y += pad.y + BUTTON_SIZE.y

		// RESET
		if rl.GuiButton({cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y}, RESET_STR[g_lang]) {
			g_current_time_frames = 0
			g_time_since_last     = 0
			g_accumulated_time    = 0
		}
		cursor.y += pad.y + BUTTON_SIZE.y

		// TAKE TIME
		if rl.GuiButton({cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y}, GETTIME_STR[g_lang]) {
			get_curr_time()
		}
		cursor.y += pad.y + BUTTON_SIZE.y

		// rl.GuiLabel(
		// 	{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
		// 	fmt.ctprintf("ZOOM: %.2f %%", g_zoom_mod*100)
		// )
		// cursor.y += pad.y + BUTTON_SIZE.y

		cursor.y += pad.y + BUTTON_SIZE.y

		rl.GuiLabel(
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			"Controls:",
		)
		cursor.y += pad.y + BUTTON_SIZE.y
		rl.GuiLabel(
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			"Start/Stop: Space",
		)
		cursor.y += pad.y + BUTTON_SIZE.y
		rl.GuiLabel(
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			"Get Current Time: Enter",
		)
		cursor.y += pad.y + BUTTON_SIZE.y

		rl.GuiLabel(
			{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
			"Reset: R",
		)
		cursor.y += pad.y + BUTTON_SIZE.y

		if g_debug_mode {
			rl.GuiLabel(
				{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
				fmt.ctprintf("Debug info: frame %v : %0.3f", g_current_time_frames, f32(g_current_time_frames)/24),
			)
			cursor.y += pad.y + BUTTON_SIZE.y

			rl.GuiLabel(
				{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
				fmt.ctprintf("time: %.4f", g_time),
			)
			cursor.y += pad.y + BUTTON_SIZE.y

			rl.GuiLabel(
				{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
				fmt.ctprintf("rl time: %.4f", total_time),
			)
			cursor.y += pad.y + BUTTON_SIZE.y

			rl.GuiLabel(
				{cursor.x, cursor.y, BUTTON_SIZE.x, BUTTON_SIZE.y},
				fmt.ctprintf("time rate: %v", g_time_rate),
			)
			cursor.y += pad.y + BUTTON_SIZE.y
		}

	}

	rl.EndDrawing()

	// mouse_delta: f32

	// when ODIN_OS == .JS {
	// 	mouse_delta = emc_get_mousewheel_delta()
	// } else {
	// 	mouse_delta = rl.GetMouseWheelMove()
	// }
	
	
	if key_pressed_safe(.SPACE) {
		g_paused = !g_paused
	}

	if key_pressed_safe(.ENTER) {
		get_curr_time()
	}

	if key_pressed_safe(.R) {
		g_current_time_frames = 0
		g_time_since_last     = 0
		g_accumulated_time    = 0
	}

	if key_pressed_safe(.P) {
		g_debug_mode = !g_debug_mode
	}

	if g_debug_mode {
		if key_pressed_safe(.W) {
			g_time_rate += 1
		}

		if key_pressed_safe(.S) {
			g_time_rate -= 1
		}

		if key_pressed_safe(.D) {
			g_current_time_frames += 1
		}

		if key_pressed_safe(.A) {
			g_current_time_frames -= 1
		}
	} else {
		g_time_rate = 1
	}

	free_all(context.temp_allocator)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable program.
parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(c.int(w), c.int(h))
}

shutdown :: proc() {

	rl.UnloadFont(g_font)

	rl.CloseWindow()
}

should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			g_run = false
		}
	}

	return g_run
}