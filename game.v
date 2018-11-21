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
	
	assign clock_out = (|q == 1'b0) ?  1 : 0;
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