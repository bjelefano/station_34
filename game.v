


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