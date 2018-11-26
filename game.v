module project(SW,KEY,LEDR,HEX0,HEX4,HEX5,CLOCK_50);
	input [9:0] SW;
	input [3:0] KEY;
	input CLOCK_50;
	output [9:0] LEDR;
	output [6:0] HEX0, HEX4, HEX5;
	
	wire [7:0] score;
	wire [3:0] lives;
	
	top Game(
		.inputs({SW[3],SW[2],SW[1],SW[0]}),
		.go(~KEY[0]),
		.clk(CLOCK_50),
		.reset_n(SW[9]),
		.curr_score(score),
		.curr_lives(lives),
		.prompts(LEDR[2:0])
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

module top(inputs,go,clk,reset_n,curr_score,curr_lives,prompts);
	input [3:0] inputs;
	input go;
	input clk;
	input reset_n;
	
	output [7:0] curr_score;
	output [3:0] curr_lives;
	output [2:0] prompts;
	
	wire [63:0] user_string, comp_string;
	wire start_display, finish_display, add_to_string, zero_lives, loss_life, gain_score, reset_IO;
	
	control c0(
		.go(go),
		.display_done(finish_display),
		.no_lives(1'b0),
		.check(user_string == comp_string),
		.clock(clk),
		.reset(reset_n),
		.display(start_display),
		.score_up(gain_score),
		.life_down(loss_life),
		.generate_string(add_to_string),
		.reset_user(reset_IO)
	);
	InputModule UserInput(
		.toggle(inputs[0]),
		.push(inputs[1]),
		.mic(inputs[2]),
		.mouse(inputs[3]),
		.clock(clk),
		.reset(reset_n | reset_IO),
		.out(user_string)
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
	AddCounter Score(
		.val(8'd0),
		.increase(gain_score),
		.clock(clk),
		.reset(reset_n),
		.out(curr_score)
	);
	SubCounter Lives(
		.val(8'd3),
		.decrease(loss_life),
		.clock(clk),
		.reset(reset_n),
		.out(curr_lives[3:0]),
		.is_zero(zero_lives)
	);
endmodule

module control(go,display_done,no_lives,check,clock,reset,display,score_up,life_down,generate_string,reset_user);
	input go;
	input display_done;
	input no_lives;
	input check;
	input clock;
	input reset;
	
	output reg display, score_up, life_down, generate_string, reset_user;
	
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
		score_up = 1'b0;
		life_down = 1'b0;
		generate_string = 1'b0;
		reset_user = 1'b1;
		
		case(current_state)
			NEXT_LEVEL : generate_string = 1'b1;
			DISPLAY : display = 1'b1;
			SCORE_INCREMENT: 
			begin
				score_up = 1'b1;
				reset_user = 1'b0;
			end
			LIFE_DECREMENT: 
			begin
				life_down = 1'b1;
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
		else if (displatBits == 5'b11000)
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

module StringGenerator(inc,clock,reset,out);
	input inc;
	input clock;
	input reset;
	
	output [63:0] out;
	
	reg [2:0] counter;
	reg [3:0] in;
	reg toggle;
	wire pulse;
	
	always @(posedge inc, negedge reset)
	begin
		if(~reset)
			counter <= 3'b000;
		else if(inc)
			counter <= (counter != 3'd4) ? counter + 1'b1 : 3'b001;
	end
	
	always @(counter, reset)
	begin
		if (~reset)
			begin
				in <= 4'b0000;
				toggle <= 1'b0;
			end
		else if (counter == 3'b001)
			begin
				in <= 4'b0001;
				toggle <= ~toggle;
			end
		else if (counter == 3'b010)
			begin
				in <= 4'b0010;
				toggle <= ~toggle;
			end
		else if (counter == 3'b011)
			begin
				in <= 4'b0100;
				toggle <= ~toggle;
			end
		else if (counter == 3'b100)
			begin
				in <= 4'b1000;
				toggle <= ~toggle;
			end
		else
			begin
				in <= 4'b0000;
				toggle <= ~toggle;
			end
			
	end
	
	InputListener SendPulse(toggle,clock,reset,pulse);
	InputModule generator(in[0],in[1],in[2],in[3],pulse,reset,out);
	
endmodule

module InputModule(toggle,push,mic,mouse,clock,reset,out);
	input toggle;
	input push;
	input mic;
	input mouse;
	input clock;
	input reset;
	
	output [63:0] out;
	
	wire [2:0] in;
	wire clk;
	
	InputType IOType(toggle,push,mic,mouse,clock,reset,in);
	StringRegister InputString(in,clock,reset,out);
	
endmodule

module InputType(toggle,push,mic,mouse,clock,reset,out);
	input toggle;
	input push;
	input mic;
	input mouse;
	input clock;
	input reset;
	
	output reg [2:0] out;
	
	wire input1, input2, input3, input4;
	
	InputListener ToggleSwitchListener(toggle,clock,reset,input1);
	InputListener PushSwitchListener(push,clock,reset,input2);
	InputListener MicrophoneListener(mic,clock,reset,input3);
	InputListener MouseListener(mouse,clock,reset,input4);
	
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
				out <= (out << 2'd2) + 2'b10000;
			else if (in == 3'd2)
				out <= (out << 2'd3) + 3'b11000;
			else if (in == 3'd3)
				out <= (out << 3'd4) + 4'b11100;
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
				out <= 1'b1;
				mem <= toggle;
			end
		else 
			out <= 1'b0;
	end
endmodule

module AddCounter(val,increase,clock,reset,out);
	input [7:0] val;
	input increase;
	input clock;
	input reset;
	
	output reg [7:0] out;
	
	always @(posedge clock)
	begin
		if (~reset)
			out <= val;
		else
		begin
			if (increase)
				out <= out + 1'b1;
		end
	end
endmodule

module SubCounter(val,decrease,clock,reset,out,is_zero);
	input [3:0] val;
	input decrease;
	input clock;
	input reset;
	
	output reg [3:0] out;
	output is_zero;
	
	always @(posedge clock)
	begin
		if (~reset)
			out <= val;
		else
		begin
			if (decrease)
				out <= out - 1'b1;
		end
	end
	
	assign is_zero = (out == 1'b0);
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
