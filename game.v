// Adjust based on the machine

`include "D:/Quartus/labs/lab_project/PS2_Mouse_Controller.v"

module game(SW,KEY,LEDR,HEX0,HEX4,HEX5,CLOCK_50,AUD_ADCDAT);
	input [9:0] SW;
	input [3:0] KEY;
	input CLOCK_50;
	input AUD_ADCDAT;
	output [9:0] LEDR;
	output [6:0] HEX0, HEX4, HEX5;
	
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
	
	top Game(
		.inputs({SW[0],~KEY[3],AUD_ADCDAT,mouseMVMT}),
		.go(~KEY[0]),
		.clk(CLOCK_50),
		.reset_n(SW[9]),
		.curr_score(score),
		.curr_lives(lives),
		.prompts(LEDR[2:0]),
		.flash(LEDR[9])
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

module top(inputs,go,clk,reset_n,curr_score,curr_lives,prompts,flash);
	input [3:0] inputs;
	input go;
	input clk;
	input reset_n;
	
	output [7:0] curr_score;
	output [3:0] curr_lives;
	output [2:0] prompts;
	output flash;
	
	wire [63:0] user_string, comp_string;
	wire start_display, finish_display, add_to_string, reset_IO;
	wire ld_lives, ld_score, ld_alu_out;
	wire [1:0] alu_sel_a, alu_sel_b, alu_func;
	
	control c0(
		.go(go),
		.display_done(finish_display),
		.no_lives(curr_lives == 1'b0),
		.check(user_string == comp_string),
		.clock(clk),
		.reset(reset_n),
		.display(start_display),
		.generate_string(add_to_string),
		.reset_user(reset_IO),
		.ld_lives(ld_lives),
		.ld_score(ld_score),
		.ld_alu_out(ld_alu_out),
		.alu_sel_a(alu_sel_a),
		.alu_sel_b(alu_sel_b),
		.alu_func(alu_func)
	);
	InputModule UserInput(
		.toggle(inputs[0]),
		.push(inputs[1]),
		.mic(inputs[2]),
		.mouse(inputs[3]),
		.clock(clk),
		.reset(reset_n | reset_IO),
		.out(user_string),
		.indicate(flash)
	);
	DisplayModule Display(
		.bstring(comp_string),
		.go(start_display),
		.clock(clk),
		.reset(reset_n),
		.out(prompts),
		.done(finish_display)
	);
	StringGenerator Comp(
		.inc(add_to_string),
		.clock(clk),
		.reset(reset_n),
		.out(comp_string)
	);
	
	datapath d0(
		.score(curr_score),
		.lives(curr_lives),
		.ld_score(ld_score),
		.ld_lives(ld_lives),
		.ld_alu_out(ld_alu_out),
		.alu_sel_a(ld_sel_a),
		.alu_sel_b(ld_sel_b),
		.alu_func(alu_func),
		.clock(clk),
		.reset(reset_n)
	);
endmodule

module control(go,display_done,no_lives,check,clock,reset,display,generate_string,reset_user,ld_lives,ld_score,ld_alu_out,alu_sel_a,alu_sel_b,alu_func);
	input go;
	input display_done;
	input no_lives;
	input check;
	input clock;
	input reset;
	
	output reg display,ld_lives,ld_score,ld_alu_out, generate_string, reset_user;
	output reg [1:0] alu_sel_a, alu_sel_b, alu_func;
	
	reg [3:0] current_state, next_state;
	
	localparam 
	START = 4'd0,
	START_WAIT = 4'd1,
	NEXT_LEVEL = 4'd2,
	DISPLAY = 4'd3,
	USER_INPUT = 4'd4,
	USER_INPUT_WAIT = 4'd5,
	CHECK = 4'd6,
	SCORE_INCREMENT = 4'd7,
	LIFE_DECREMENT = 4'd8,
	GAME_OVER = 4'd9;
	
	always @(posedge clock)
	begin: state_FFs
		if(~reset)
		begin
			current_state <= START;
		end
		else
			current_state <= next_state;
	end
	
	always @(*)
	begin: state_table
		case(current_state)
			START : next_state = go ? START_WAIT : START;
			START_WAIT : next_state = go ? START_WAIT : NEXT_LEVEL;
			NEXT_LEVEL : next_state = DISPLAY;
			DISPLAY : next_state = display_done ? USER_INPUT : DISPLAY;
			USER_INPUT : next_state = go ? USER_INPUT_WAIT : USER_INPUT;
			USER_INPUT_WAIT : next_state = go ? USER_INPUT_WAIT : CHECK;
			CHECK : next_state = check ? SCORE_INCREMENT : LIFE_DECREMENT;
			SCORE_INCREMENT: next_state = NEXT_LEVEL;
			LIFE_DECREMENT: next_state = no_lives ? GAME_OVER : DISPLAY;
			GAME_OVER: next_state = ~reset ? START : GAME_OVER;
		endcase
	end
	
	always @(*)
	begin: enable_signals
		display = 1'b0;
		ld_lives = 1'b0;
		ld_score = 1'b0;
		ld_alu_out = 1'b0;
		alu_sel_a = 2'd0;
		alu_sel_b = 2'd0;
		alu_func = 2'd0;
		generate_string = 1'b0;
		reset_user = 1'b1;
		
		case(current_state)
			START :
			begin
				ld_lives = 1'b1; ld_score = 1'b1;
			end
			NEXT_LEVEL : generate_string = 1'b1;
			DISPLAY : display = 1'b1;
			SCORE_INCREMENT: 
			begin
				ld_score = 1'b1; ld_alu_out = 1'b1;
				alu_sel_a = 2'd1; alu_func = 2'd0;
				reset_user = 1'b0;
			end
			LIFE_DECREMENT: 
			begin
				ld_lives = 1'b1; ld_alu_out = 1'b1;
				alu_sel_a = 2'd0; alu_func = 2'd1;
				reset_user = 1'b0;
			end
		endcase
	end
endmodule

module DisplayModule(bstring,go,clock,reset,out,done);
	input [63:0] bstring;
	input go;
	input clock;
	input reset;
	
	output reg [2:0] out;
	output reg done;
	
	wire clk,start;
	wire [4:0] displayBits;
	wire [63:0] outstring;
	
	NoLeadingZeroRegister ZeroBit(bstring,go,clock,reset,outstring,start);
	RateDivider Hz2(26'd50000000 - 1'b1,clock,start,clk);
	OutputRegister MSBit(outstring,start,clk,reset,displayBits);
		
	always @(displayBits)
	begin
		if (displayBits == 5'b10000)
			out = 3'b001;
		else if (displayBits == 5'b11000)
			out = 3'b010;
		else if (displayBits == 5'b11100)
			out = 3'b011;
		else if (displayBits == 5'b11110)
			out = 3'b100;
		else 
			out = 3'b000;
	end
endmodule

module OutputRegister(in,start,clock,reset,out);
	input [63:0] in;
	input start;
	input clock;
	input reset;
	output reg [4:0] out;
	
	reg [63:0] val2;
	reg mem;
	
	always @(posedge clock)
	begin
		if (~reset | (~start & mem))
			begin
				out <= 64'd0;
				val2 <= 64'd0;
				mem <= 1'b0;
			end
		else
			begin
				if (start & ~mem)
					begin
						val2 <= in;
						mem <= 1'b1;
					end
				else
				begin
					out <= val2[63:59];
					val2 <= val2 << 3'd5;
				end
			end
	end
	
endmodule

module NoLeadingZeroRegister(in,start,clock,reset,out,trigger);
	input [63:0] in;
	input start;
	input clock;
	input reset;
	output reg [63:0] out;
	output reg trigger;
	
	reg [63:0] val1;

	always @(posedge clock)
	begin
		if (~reset)
			begin
				val1 <= 64'd0;
				trigger <= 1'b0;
			end
		else if (start)
			begin
				val1 <= in;
				trigger <= 1'b0;
			end
		else if (val1[63] != 1'b1)
				val1 <= val1 << 1'b1;
		else
			begin
				out <= val1;
				trigger <= 1'b1;
			end
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
			out <= (out != 2'd3) ? out + 1'b1 : 2'd0;
	end
endmodule

module StringGenerator(inc,clock,reset,out);
	input inc;
	input clock;
	input reset;
	
	output reg [63:0] out;
	
	wire [1:0] counter;
	reg [3:0] in;
	
	Counter RNG(clock, reset, counter);
	
	always @(posedge inc, negedge reset)
	begin
		if (~reset)
			begin
				in <= 64'd0;
			end
		else if (counter == 2'd0)
			begin
				out <= (out << 3'd5) + 5'b10000;
			end
		else if (counter == 2'd1)
			begin
				out <= (out << 3'd5) + 5'b11000;
			end
		else if (counter == 2'd2)
			begin
				out <= (out << 3'd5) + 5'b11100;
			end
		else if (counter == 2'd3)
			begin
				out <= (out << 3'd5) + 5'b11110;
			end
	end
	
endmodule

module InputModule(toggle,push,mic,mouse,clock,reset,out,indicate);
	input toggle;
	input push;
	input mic;
	input mouse;
	input clock;
	input reset;
	
	output [63:0] out;
	output indicate;
	
	wire [2:0] in;
	
	InputType IOType(toggle,push,mic,mouse,clock,reset,in,indicate);
	StringRegister InputString(in,clock,reset,out);
	
endmodule

module InputType(toggle,push,mic,mouse,clock,reset,out,indicate);
	input toggle;
	input push;
	input mic;
	input mouse;
	input clock;
	input reset;
	
	output reg [2:0] out;
	output indicate;
	
	wire input1, input2, input3, input4;
	
	InputListener ToggleSwitchListener(toggle,clock,reset,input1);
	InputListener PushSwitchListener(push,clock,reset,input2);
	InputListener MicrophoneListener(mic,clock,reset,input3);
	InputListener MouseListener(mouse,clock,reset,input4);
	
	assign indicate = (input1 | input2 | input3 | input4);
	
	always @(posedge clock)
	begin
		if (~reset)
			begin
				out <= 3'd0;
			end
		else
			begin
				if (input1)
					out <= 3'd1;
				else if (input2)
					out <= 3'd2;
				else if (input3)
					out <= 3'd3;
				else if (input4)
					out <= 3'd4;
				else 
					out <= 3'd0;
			end
	end
endmodule

module StringRegister(in,clock,reset,out);
	input [2:0] in;
	input clock;
	input reset;
	
	output reg [63:0] out;
	
	always @(negedge clock)
	begin
		if (~reset)
			out <= 64'd0;
		else begin
			if (in == 3'd1)
				out <= (out << 4'd5) + 5'b10000;
			else if (in == 3'd2)
				out <= (out << 4'd5) + 5'b11000;
			else if (in == 3'd3)
				out <= (out << 3'd5) + 5'b11100;
			else if (in == 3'd4)
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
				lives <= 4'd0;
			end
		else
		begin
			if (ld_score)
				begin
					if (ld_alu_out)
						score <= alu_out;
					else
						score <= 8'd0;
				end
			if (ld_lives)
				begin
					if (ld_alu_out)
						lives <= alu_out[3:0];
					else
						score <= 4'd3;
				end
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
