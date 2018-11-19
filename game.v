module InputModule(toggle,push,mic,mouse,clock,reset,out);
	input toggle;
	input push;
	input mic;
	input mouse;
	input clock;
	input reset;
	
	output reg [63:0] out;
	
	reg write, input1, input2, input3, input4;
	reg [2:0] inputType;
	
	StringRegister InputString(inputType,clock,reset,out);
	
	InputListener ToggleSwitchListener(toggle,clock,reset,input1);
	InputListener PushSwitchListener(push,clock,reset,input2);
	InputListener MicrophoneListener(mic,clock,reset,input3);
	InputListener MouseListener(mouse,clock,reset,input4);
	
	always @(input1,input2,input3,input4,reset)
	begin
		if (~reset)
			begin
				inputType <= 3'd0;
			end
		else
			begin
				if (input1)
					inputType <= 3'd1;
				else if (input2)
					inputType <= 3'd2;
				else if (input3)
					inputType <= 3'd3;
				else if (input4)
					inputType <= 3'd4;
				else 
					inputType <= 3'd0;
			end
	end
endmodule

module StringRegister(in,clock,reset,out);
	input [2:0] in;
	input write;
	input clock;
	input reset;
	
	output reg [63:0] out;
	
	always @(posedge clock)
	begin
		if (~reset)
			out <= 64'd0;
		else begin
			if (in == 3'd1)
				out <= (out << 2'd2) + 2'b10;
			else if (in == 3'd2)
				out <= (out << 2'd3) + 3'b110;
			else if (in == 3'd3)
				out <= (out << 2'd4) + 4'b1110;
			else if (in == 3'd4)
				out <= (out << 2'd5) + 5'b11110;
		end
	end
endmodule

module InputListener(toggle,clock,reset,out);
	input toggle;
	input clock;
	input reset;
	
	wire pulse;
   assign pulse = toggle & ~toggle;
	
	always @(pulse)
	begin
		if (~reset | ~pulse)
			out <= 1'b0;
		else
			out <= 1'b1;
	end
endmodule

module AddCounter(val,increase,clock,reset,out);
	input decrement;
	input clock;
	input reset;
	
	output reg out;
	
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
	input decrement;
	input clock;
	input reset;
	
	output reg out;
	
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