module control(start,display_done,no_lives,check,clock,reset,display,score_up,life_down,generate_string,fetch_check);
	input start;
	input display_done;
	input no_lives;
	input check;
	input clock;
	input reset;
	
	output reg display, score_up, life_down, generate_string,fetch_check;
	
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
	
	always @(posedge clock, reset)
	begin: state_FFs
		if(~reset)
			current_state <= START;
		else
			current_state <= next_state;
	end
	
	always @(*)
	begin: state_table
		case(current_state)
			START : next_state = start ? START_WAIT : START;
			START_WAIT : next_state = start ? START_WAIT : NEXT_LEVEL;
			NEXT_LEVEL : next_state = DISPLAY;
			DISPLAY : next_state = display_done ? USER_INPUT : DISPLAY;
			USER_INPUT : next_state = start ? USER_INPUT_WAIT : START;
			USER_INPUT_WAIT : next_state = start ? USER_INPUT_WAIT : CHECK;
			CHECK : next_state = check ? SCORE_INCREMENT : LIFE_DECREMENT;
			SCORE_INCREMENT: next_state = NEXT_LEVEL;
			LIFE_DECREMENT: next_state = no_lives ? GAME_OVER : DISPLAY;
		endcase
	end
	
	always @(*)
	begin: enable_signals
		display = 1'b0;
		score_up = 1'b0;
		life_down = 1'b0
		generate_string = 1'b0;
		fetch_check = 1'b0
		case(current_state)
			NEXT_LEVEL : generate_string = 1'b1;
			DISPLAY : display = 1'b1;
			CHECK : fetch_check = 1'b1;
			SCORE_INCREMENT: score_up = 1'b1;
			LIFE_DECREMENT: life_down = 1'b1;
		endcase
	end
endmodule

module DisplayModule(string,go,clock,reset,out,done);
	input [63:0] string;
	input go;
	input clock;
	input reset;
	
	output reg [2:0] out;
	output reg done;
	
	wire clk,bit,start;
	
	OutputRegister MSBit(string,go,clock,reset,bit,start);
	RateDivider twoHz2(26'b01011111010111100001000000 - 1'b1,clock,start,clk);
	
	reg [3:0] current_state, next_state;
	
	localparam 
	WAIT = 4'd0,
	BUFFER = 4'd1,
	ONE = 4'd2,
	TWO = 4'd3,
	THREE = 4'd4,
	FOUR = 4'd5,
	OUT_TOGGLE = 4'd6,
	OUT_PUSH = 4'd7,
	OUT_MIC = 4'd8,
	OUT_MOUSE = 4'd9;
	
	always @(posedge clk, reset)
	begin: state_FFs
		if(~reset)
			current_state <= WAIT;
		else
			current_state <= next_state;
	end
	
	always @(*)
	begin: state_table
		case(current_state)
			WAIT : next_state = start ? BUFFER : WAIT;
			BUFFER: next_state = ONE;
			ONE : next_state = bit ? TWO : OUT_TOGGLE;
			TWO : next_state = bit ? THREE : OUT_PUSH;
			THREE : next_state = bit ? FOUR : OUT_MIC;
			FOUR : next_state = OUT_MOUSE;
			OUT_TOGGLE : next_state = bit ? ONE : WAIT;
			OUT_PUSH : next_state = bit ? ONE : WAIT;
			OUT_MIC : next_state = bit ? ONE : WAIT;
			OUT_MOUSE : next_state = bit ? ONE : WAIT;
		endcase
	end
	
	always @(*)
	begin: enable_signals
		out = 3'd0;
		done = 1'b0;
		case(current_state)
			WAIT : 
			begin
				out = 3'd0;
				done = 1'b1;
			end
			OUT_TOGGLE : out = 3'd1;
			OUT_PUSH : out = 3'd2;
			OUT_MIC : out = 3'd3;
			OUT_MOUSE : out = 3'd4;
		endcase
	end
	
endmodule

module OutputRegister(in,start,clock,reset,out,trigger);
	input [63:0] in;
	input start;
	input clock;
	input reset;
	output reg out,trigger;
	
	reg [63:0] val1,val2;
	reg reset_clk,started;
	wire clk;
	
	always @(posedge clock)
	begin
		if (~reset)
			begin
				val1 <= 64'd0;
				reset_clk <= 1'd0;
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
				reset_clk <= 1'd1;
				trigger <= 1'b1;
			end
	end
	
	RateDivider twoHz1(26'b01011111010111100001000000 - 1'b1,clock,reset_clk,clk);
	
	always @(posedge clk, trigger,reset)
	begin
		if (~reset)
			begin
				out <= 0;
				val2 <= 64'd0;
				started <= 1'b0;
			end
		else if (trigger & ~started)
			begin
				val2 <= val1;
				started <= 1'b1;
			end
		else if (~trigger & started)
			started <= 1'b0;
		else
			begin
				out <= val2[63];
				val2 <= val2 << 1'b1;
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
	
	always @(posedge inc, reset)
	begin
		if(~reset)
			counter <= 3'b000;
		else if(inc)
			counter <= (counter != 3'd4) ? counter + 1'b1 : 3'b001;
	end
	
	always @(counter, reset)
	begin
		if (counter == 2'b00 | ~reset)
			in <= 4'b0000;
		else if (counter == 3'b001)
			in <= 4'b0001;
		else if (counter == 3'b010)
			in <= 4'b0010;
		else if (counter == 3'b011)
			in <= 4'b0100;
		else if (counter == 3'b100)
			in <= 4'b1000;
	end
	
	InputModule generator(in[0],in[1],in[2],in[3],clock,reset,out);
	
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
	
	RateDivider doubleTime(26'd1,clock,reset,clk);
	
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
	
	always @(clock)
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
				out <= (out << 2'd2) + 2'b10;
			else if (in == 3'd2)
				out <= (out << 2'd3) + 3'b110;
			else if (in == 3'd3)
				out <= (out << 3'd4) + 4'b1110;
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

	always @(clock)
	begin
		if (~reset)
			begin
				out <= 1'b0;
				mem <= 1'b0;
			end
		else if (mem != toggle)
			begin
				out <= toggle;
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

module SubCounter(val,decrease,clock,reset,out);
	input [7:0] val;
	input decrease;
	input clock;
	input reset;
	
	output reg [7:0] out;
	
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
endmodule

module RateDivider(in,clockIn,reset,clockOut);
	input [25:0] in;
	input clockIn;
	input reset;
	output clockOut;

	reg [25:0] q;
	
	always @(posedge clockIn)
	begin
		if (reset == 1'b0) 
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