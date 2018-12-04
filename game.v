// Adjust based on the machine

`include "D:/Quartus/labs/lab_project/PS2_Mouse_Controller.v"
`include "D:/Quartus/labs/lab_project/display.v"
`include "D:/Quartus/labs/lab_project/vga_adapter/vga_adapter.v"
`include "D:/Quartus/labs/lab_project/vga_adapter/vga_address_translator.v"
`include "D:/Quartus/labs/lab_project/vga_adapter/vga_controller.v"
`include "D:/Quartus/labs/lab_project/vga_adapter/vga_pll.v"

module game(SW,KEY,LEDR,HEX0,HEX4,HEX5,CLOCK_50,AUD_ADCDAT
	/*
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	*/
	);
	
	input [9:0] SW;
	input [3:0] KEY;
	input CLOCK_50;
	input AUD_ADCDAT;
	output [9:0] LEDR;
	output [6:0] HEX0, HEX4, HEX5;
	
	/*
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	*/
	
	wire [7:0] score;
	wire [17:0] mvmt;
	reg [17:0] mem;
	wire [3:0] lives;
	reg mouseMVMT;
	
	always @(posedge CLOCK_50)
	begin
		if (~SW[9])
			begin
				mouseMVMT <= 1'b0;
				mem <= 18'b0;
			end
		else if (mvmt != mem)
			begin
				mouseMVMT <= 1'b1;
				mem <= mvmt;
			end
		else
			mouseMVMT <= 1'b0;
	end
	
	wire [7:0] x,y;
	wire [2:0] colour;
	wire write;
	/*
	vga_adapter VGA(
			.resetn(SW[9]),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(write),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
	*/
	
	top Game(
		.inputs({SW[3],SW[2],SW[1],SW[0]}),
		.go(~KEY[0]),
		.clk(CLOCK_50),
		.reset_n(SW[9]),
		.curr_score(score),
		.curr_lives(lives),
		.x(x),
		.y(y),
		.flash(LEDR[9:8]),
		.write(write),
		.colour(colour)
	);
	
	mouse_tracker mouse(
		.clock(CLOCK_50),
		.reset(SW[9]),
		.enable_tracking(1'b1),
		.x_pos(mvmt[8:0]),
		.y_pos(mvmt[17:9])
	);
	
	HexDecoder H0(
		.in(lives),
		.out(HEX0)
	);
	
	HexDecoder H4(
		.in(score[3:0]),
		.out(HEX4)
	);
	
	HexDecoder H5(
		.in(score[7:4]),
		.out(HEX5)
	);
endmodule


module top(inputs,go,clk,reset_n,curr_score,curr_lives,x,y,flash,write,colour);
	input [3:0] inputs;
	input go;
	input clk;
	input reset_n;
	
	output [7:0] curr_score;
	output [3:0] curr_lives;
	output [7:0] x, y;
	output [1:0] flash;
	output write;
	output [2:0] colour;
	
	wire [99:0] user_string, comp_string;
	wire start_display, add_to_string, reset_IO, display_done, done_string, zero_done;
	wire ld_lives, ld_score, ld_alu_out, clk2;
	wire [1:0] alu_sel_a, alu_sel_b, alu_func;
	
	assign flash[0] = display_done;
	
	wire [15:0] position;
	wire [2:0] colour, prompts;
	reg promptChange;
	reg [2:0] mem;
	
	always @(posedge clk)
	begin
		if (~reset_n)
			begin
				promptChange <= 1'b0;
				mem <= 3'd0;
			end
		else if (prompts != mem)
			begin
				promptChange <= 1'b1;
				mem <= prompts;
			end
		else
			promptChange <= 1'b0;
	end
	
	RateDivider clock(
		.in(26'd50000000 - 1'b1),
		.clockIn(clk),
		.reset(reset_n),
		.clockOut(clk2)
	);
	control c0(
		.go(go),
		.display_done(display_done),
		.zero_done(zero_done),
		.string_done(done_string),
		.no_lives(curr_lives == 1'b0),
		.check(user_string == comp_string),
		.clock(clk2),
		.reset(reset_n),
		.display(start_display),
		.generate_string(add_to_string),
		.reset_user(reset_IO),
		.ld_lives(ld_lives),
		.ld_score(ld_score),
		.alu_sel_a(alu_sel_a),
		.alu_sel_b(alu_sel_b),
		.alu_func(alu_func)
	);
	InputModule UserInput(
		.toggle(inputs[0]),
		.push(inputs[1]),
		.mic(inputs[2]),
		.mouse(inputs[3]),
		.clock(clk2),
		.reset(reset_n & reset_IO),
		.out(user_string),
		.indicate(flash[1])
	);
	DisplayModule Display(
		.bstring(comp_string),
		.go(start_display),
		.clock(clk),
		.reset(reset_n),
		.out(prompts),
		.done(display_done),
		.zero_done(zero_done)
	);
	LUD posCol(
		.in(prompts),
		.position(position), 
		.colour(colour)
	);
	vgaDisplay screen(
		.start(promptChange),
		.in(position),
		.reset(reset_n),
		.clock(clk),
		.x(x),
		.y(y),
		.plot(write)
	);
	StringGenerator Comp(
		.inc(add_to_string),
		.clock(clk2),
		.reset(reset_n),
		.out(comp_string),
		.indicate(done_string)
	);
	
	datapath d0(
		.score(curr_score),
		.lives(curr_lives),
		.ld_score(ld_score),
		.ld_lives(ld_lives),
		.alu_sel_a(alu_sel_a),
		.alu_sel_b(alu_sel_b),
		.alu_func(alu_func),
		.clock(clk2),
		.reset(reset_n)
	);
endmodule

module control(go,display_done,zero_done,string_done,no_lives,check,clock,reset,display,generate_string,reset_user,ld_lives,ld_score,alu_sel_a,alu_sel_b,alu_func);
	input go;
	input display_done;
	input zero_done;
	input string_done;
	input no_lives;
	input check;
	input clock;
	input reset;
	
	output reg display,ld_lives,ld_score, generate_string, reset_user;
	output reg [1:0] alu_sel_a, alu_sel_b, alu_func;
	
	reg [3:0] current_state, next_state;
	
	localparam 
	START = 4'd0,
	START_WAIT = 4'd1,
	NEXT_LEVEL = 4'd2,
	NEXT_WAIT = 4'd3,
	DISPLAY = 4'd4,
	DISPLAY_WAIT = 4'd5,
	USER_INPUT = 4'd6,
	USER_INPUT_WAIT = 4'd7,
	CHECK = 4'd8,
	SCORE_INCREMENT = 4'd9,
	LIFE_DECREMENT = 4'd10,
	IS_GAME_OVER = 4'd11,
	GAME_OVER = 4'd12;
	
	always @(posedge clock)
	begin: state_FFs
		if(~reset)
			current_state <= 4'd0;
		else
			current_state <= next_state;
	end
	
	always @(*)
	begin: state_table
		case(current_state)
			START : next_state = go ? START_WAIT : START;
			START_WAIT : next_state = go ? START_WAIT : NEXT_LEVEL;
			NEXT_LEVEL : next_state = NEXT_WAIT;
			NEXT_WAIT : next_state = string_done ? DISPLAY : NEXT_WAIT;
			DISPLAY : next_state = zero_done ? DISPLAY_WAIT : DISPLAY;
			DISPLAY_WAIT : next_state = display_done ? USER_INPUT : DISPLAY_WAIT;
			USER_INPUT : next_state = go ? USER_INPUT_WAIT : USER_INPUT;
			USER_INPUT_WAIT : next_state = go ? USER_INPUT_WAIT : CHECK;
			CHECK : next_state = check ? SCORE_INCREMENT : LIFE_DECREMENT;
			SCORE_INCREMENT: next_state = NEXT_LEVEL;
			LIFE_DECREMENT: next_state = IS_GAME_OVER;
			IS_GAME_OVER: next_state = no_lives ? GAME_OVER : DISPLAY;
			GAME_OVER: next_state = ~reset ? START : GAME_OVER;
		endcase
	end
	
	always @(*)
	begin: enable_signals
		display = 1'b0;
		ld_lives = 1'b0;
		ld_score = 1'b0;
		alu_sel_a = 2'd3;
		alu_sel_b = 2'd3;
		alu_func = 2'd3;
		generate_string = 1'b0;
		reset_user = 1'b1;
		
		case(current_state)
			NEXT_LEVEL : generate_string = 1'b1;
			DISPLAY : display = 1'b1;
			SCORE_INCREMENT: 
			begin
				alu_sel_a = 2'd1; alu_func = 2'd0;
				ld_score = 1'b1; 
				reset_user = 1'b0;
			end
			LIFE_DECREMENT: 
			begin
				alu_sel_a = 2'd0; alu_func = 2'd1;
				ld_lives = 1'b1;
				reset_user = 1'b0;
			end
		endcase
	end
endmodule

module LUD(in,position, colour);
	input [2:0] in;
	output reg [15:0] position;
	output reg [2:0] colour;
	
	always @(in)
	begin
		case(in)
			3'd0:
				begin
					position = 16'd0;
					colour = 3'd1;
				end
			3'd1: 
				begin
					position = {8'd20, 8'd58};
					colour = (colour + 1'b1 == 3'd0) ? 3'd1 : colour + 1'b1;
				end
			3'd2: 
				begin
					position = {8'd78, 8'd20};
					colour = (colour + 1'b1 == 3'd0) ? 3'd1 : colour + 1'b1;
				end
			3'd3:	
				begin
					position = {8'd156, 8'd58};
					colour = (colour + 1'b1 == 3'd0) ? 3'd1 : colour + 1'b1;
				end
			3'd4:	
				begin
					position = {8'd78, 8'd100};
					colour = (colour + 1'b1 == 3'd0) ? 3'd1 : colour + 1'b1;
				end
			default:
				begin
					position = 16'd0;
					colour = 3'd1;
				end
		endcase
	end
endmodule 


module DisplayModule(bstring,go,clock,reset,out,done,zero_done);
	input [99:0] bstring;
	input go;
	input clock;
	input reset;
	
	output reg [2:0] out;
	output reg done;
	output zero_done;
	
	wire clk,start;
	wire [4:0] displayBits;
	wire [99:0] outstring;
	
	NoLeadingZeroRegister ZeroBit(bstring,go,clock,reset,outstring,start);
	RateDivider Hz2(26'd50000000 - 1'b1,clock,reset,clk);
	OutputRegister MSBit(outstring,start,clk,(reset | start),displayBits);
	assign zero_done = start;
		
	always @(posedge clk)
	begin
		if (displayBits == 5'b10000)
			begin
				out = 3'b001;
				done = 1'b0;
			end
		else if (displayBits == 5'b11000)
			begin
				out = 3'b010;
				done = 1'b0;
			end
		else if (displayBits == 5'b11100)
			begin
				out = 3'b011;
				done = 1'b0;
			end
		else if (displayBits == 5'b11110)
			begin
				out = 3'b100;
				done = 1'b0;
			end
		else 
			begin
				out = 3'b000;
				done = 1'b1;
			end
	end
endmodule

module OutputRegister(in,start,clock,reset,out);
	input [99:0] in;
	input start;
	input clock;
	input reset;
	output reg [4:0] out;
	
	reg [99:0] val2;
	
	always @(posedge clock, posedge start)
	begin
		if (~reset)
			begin
				out <= 4'd0;
				val2 <= 100'd0;
			end
		else
			begin
				if (start)
						val2 <= in;
				else
					begin
						out <= val2[99:95];
						val2 <= val2 << 3'd5;
					end
			end
	end
	
endmodule

module NoLeadingZeroRegister(in,start,clock,reset,out,trigger);
	input [99:0] in;
	input start;
	input clock;
	input reset;
	output reg [99:0] out;
	output reg trigger;
	
	reg mem;
	
	always @(posedge clock)
	begin
		if (~reset | (~start & mem))
			begin
				out <= 100'd0;
				trigger <= 1'b0;
				mem <= 1'b0;
			end
		else if (start & ~mem)
			begin
				out <= in;
				trigger <= 1'b0;
				mem <= 1'b1;
			end
		else if (out[99] == 1'b1)
				trigger <= 1'b1;
		else
			out <= out << 1'b1;
	end
	
endmodule

module Counter(clock,reset,out);
	input clock;
	input reset;
	output reg [1:0] out;
	
	always @(posedge clock)
	begin
		if (~reset)
			out <= 2'd0;
		else
			out <= (out < 3'd4) ? (out + 1'b1) : 2'd0;
	end
endmodule

module StringGenerator(inc,clock,reset,out,indicate);
	input inc;
	input clock;
	input reset;
	
	output reg [99:0] out;
	output reg indicate;
	
	wire [1:0] counter, num;
	reg mem, toggle;
	
	Counter RNG(clock, reset, counter);
	
	assign num = inc ? counter : 2'd0;
	
	always @(posedge inc, negedge reset)
	begin
		if (~reset)
			begin
				out <= 100'd0;
				toggle <= 1'b0;
			end
		else if (num == 2'd0)
			begin
				out <= (num << 3'd5) + 5'b10000;
				toggle <= ~toggle;
			end
		else if (num == 2'd1)
			begin
				out <= (out << 3'd5) + 5'b11000;
				toggle <= ~toggle;
			end
		else if (num == 2'd2)
			begin
				out <= (out << 3'd5) + 5'b11100;
				toggle <= ~toggle;
			end
		else if (num == 2'd3)
			begin
				out <= (out << 3'd5) + 5'b11110;
				toggle <= ~toggle;
			end
	end

	always @(posedge clock)
	begin
		if (~reset)
			begin
				indicate <= 1'b0;
				mem <= 1'b0;
			end
		else if (mem != toggle)
			begin
				indicate <= 1'b1;
				mem <= toggle;
			end
		else 
			indicate <= 1'b0;
	end
endmodule

module InputModule(toggle,push,mic,mouse,clock,reset,out,indicate);
	input toggle;
	input push;
	input mic;
	input mouse;
	input clock;
	input reset;
	
	output reg [99:0] out;
	output indicate;
	
	wire input1, input2, input3, input4;
	
	InputListener ToggleSwitchListener(toggle,clock,reset,input1);
	InputListener PushSwitchListener(push,clock,reset,input2);
	InputListener MicrophoneListener(mic,clock,reset,input3);
	InputListener MouseListener(mouse,clock,reset,input4);
	
	assign indicate = (input1 | input2 | input3 | input4);
	
	always @(posedge indicate, negedge reset)
	begin
		if (~reset)
			begin
				out <= 100'd0;
			end
		else if (input1)
			begin
				out <= (out << 3'd5) + 5'b10000;
			end
		else if (input2)
			begin
				out <= (out << 3'd5) + 5'b11000;
			end
		else if (input3)
			begin
				out <= (out << 3'd5) + 5'b11100;
			end
		else if (input4)
			begin
				out <= (out << 3'd5) + 5'b11110;
			end
	end
endmodule

module InputListener(toggle,clock,reset,out);
	input toggle;
	input clock;
	input reset;
	
	output reg out;
	
	reg mem;

	always @(posedge clock)
	begin
		if (~reset)
			begin
				out <= 1'b0;
				mem <= 1'b0;
			end
		else if (mem != toggle)
			begin
				if (toggle)
					begin
						out <= 1'b1;
						mem <= toggle;
					end
				else
					begin
						out <= 1'b0;
						mem <= toggle;
					end
			end
		else 
			out <= 1'b0;
	end
endmodule

module datapath(score,lives,ld_score,ld_lives,ld_alu_out,alu_sel_a,alu_sel_b,alu_func,clock,reset);
	input ld_score, ld_lives, ld_alu_out, clock, reset;
	input [1:0] alu_sel_a, alu_sel_b, alu_func;
	
	output reg [3:0] lives;
	output reg [7:0] score;
	
	reg [7:0] alu_a, alu_b, alu_out;
	
	always @(posedge clock)
	begin
		if (~reset)
			begin
				score <= 8'd0;
				lives <= 4'd3;
			end
		else
		begin
			if (ld_score)
				score <= alu_out;
			if (ld_lives)
				lives <= alu_out[3:0];
		end
	end
	
	always @(*)
	begin
		case (alu_sel_a)
			2'd0: alu_a = {4'd0, lives};
			2'd1: alu_a = score;
			default: alu_a = 8'd0;
		endcase
		case (alu_sel_b)
			2'd0: alu_b = {4'd0, lives};
			2'd1: alu_b = score;
			default: alu_b = 8'd0;
		endcase
	end
	
	always @(*)
	begin
		case (alu_func)
			2'd0: alu_out = alu_a + 1'b1;
			2'd1: alu_out = alu_a - 1'b1;
			default: alu_out = 8'd0;
		endcase
	end
endmodule

module RateDivider(in,clockIn,reset,clockOut);
	input [25:0] in;
	input clockIn;
	input reset;
	output clockOut;

	reg [25:0] q;
	
	always @(posedge clockIn)
	begin
		if (~reset) 
			q <= 26'd0;
		else
			begin
				if (|q == 1'b0)
					q <= in;
				else
					q <= q - 1'b1;
			end
	end
	
	assign clockOut = (|q == 1'b0) ?  1 : 0;
endmodule

module HexDecoder(in,out);
	input [3:0] in;
	
	output [6:0] out;
	
	assign out[0] = ((~in[3] & ~in[1]) & ((~in[2] & in[0]) | (in[2] & ~in[0]))) | ((in[3] & in[0]) & ((~in[2] & in[1]) | (in[2] & ~in[1])));
	assign out[1] = (in[2] & in[1] & ~in[0]) | (in[3] & ((in[1] & in[0]) | (in[2] & ~in[1] & ~in[0]))) | (~in[3] & in[2] & ~in[1] & in[0]);
	assign out[2] = ((in[3] & in[2]) & (in[1] | (~in[1] & ~in[0]))) | (~in[3] & ~in[2] & in[1] & ~in[0]);
	assign out[3] = (in[0] & ((in[2] & in[1]) | (~in[2] & ~in[1]))) | (~in[0] & ((~in[3] & in[2] & ~in[1]) | (in[3] & ~in[2] & in[1])));
	assign out[4] = (~in[3] & in[0]) | (~in[1] & ((~in[3] & in[2] & ~in[0]) | (in[3] & ~in[2] & in[0])));
	assign out[5] = ((~in[3] & ~in[2]) & ((in[1] | (~in[1] & in[0])))) | ((in[2] & in[0]) & ((~in[3] & in[1]) | (in[3] & ~in[1])));
	assign out[6] = (~in[3] & ((~in[2] & ~in[1]) | (in[2] & in[1] & in[0]))) | (in[3] & in[2] & ~in[1] & ~in[0]);	
endmodule
