module vgaDisplay(start,in,reset,clock,x,y,plot);
	input start;
	input clock, reset;
	input [15:0] in;
	
	output [7:0] x,y;
	output plot;

    wire load_x,load_y,load_alu,plot;
	 wire [1:0] alu_op, alu_sel_a, alu_sel_b;
	 
	 displayDATA data(
		.in(in),
		.reset_n(reset),
		.clock(clock),
		.alu_sel_a(alu_sel_a),
		.alu_sel_b(alu_sel_b),
		.load_x(load_x),
		.load_y(load_y),
		.load_alu(load_alu),
		.alu_op(alu_op),
		.out_x(x),
		.out_y(y)
	);
    displayCTRL ctrl(
		.go(start),
		.clock(clock),
		.reset_n(reset),
		.load_x(load_x),
		.load_y(load_y),
		.load_alu(load_alu),
		.alu_op(alu_op),
		.alu_sel_a(alu_sel_a),
		.alu_sel_b(alu_sel_b),
		.plot(plot)
	 );
endmodule

module displayCTRL(go,clock,reset_n,load_x,load_y,load_alu,alu_op,alu_sel_a,alu_sel_b,plot);
	input go;
	input clock;
	input reset_n;
	
	output reg load_x;
	output reg load_y;
	output reg load_alu;
	output reg [1:0] alu_op, alu_sel_a, alu_sel_b;
	
	output reg plot;
	
	reg [3:0] cur_state, next_state;
	reg [2:0] x_count, y_count;
	
	always @(posedge clock)
	begin
		if (~reset_n)
			begin
				cur_state <= 4'b0000;
			end
		else
			cur_state <= next_state;
	end
	
	localparam LOAD = 4'd0,
				  WAIT_LOAD = 4'd1,
				  PLOT = 4'd2,
				  PLOT_WAIT = 4'd3,
				  INCREMENT_X = 4'd4,
				  INCREMENT_Y = 4'd5,
				  RESET_X = 4'd6;
	
	always @(*)
	begin
		case (cur_state)
			LOAD: next_state = go ? WAIT_LOAD : LOAD;
			WAIT_LOAD: next_state = go ? WAIT_LOAD : PLOT;
			PLOT: next_state = PLOT_WAIT;
			PLOT_WAIT: next_state = (x_count < 3'd4) ? INCREMENT_X : INCREMENT_Y;
			INCREMENT_X: next_state = PLOT;
			INCREMENT_Y: next_state = RESET_X;
			RESET_X: next_state = (y_count < 3'd4) ? PLOT : LOAD;
		endcase
	end
	
	always @(*)
	begin
		load_x = 1'b0;
		load_y = 1'b0;
		load_alu = 1'b0;
		alu_sel_a = 2'd0;
		alu_sel_b = 2'd0;
		alu_op = 2'd0;
		plot = 1'b0;
		
		case (cur_state)
			WAIT_LOAD: 
				begin
					load_x = 1'b1;
					load_y = 1'b1;
					x_count = 3'd0;
					y_count = 3'd1;
				end
			PLOT:
				begin
					plot = 1'b1;
					x_count = x_count + 1;
				end
			INCREMENT_X:
				begin
					alu_sel_a = 2'd0; alu_op = 2'd0;
					load_x = 1'b1; load_alu = 1'b1;
				end
			INCREMENT_Y:
				begin
					alu_sel_a = 2'd1; alu_op = 2'd0;
					load_y = 1'b1; load_alu = 1'b1;
					x_count = 3'd0;
					y_count = y_count + 1;
				end
			RESET_X:
				begin
					alu_sel_a = 2'd0; alu_op = 2'd2;
					load_x = 1'b1; load_alu = 1'b1;
					load_alu = 1'b1;
				end
		endcase
	end

endmodule

module displayDATA(in,reset_n,clock,alu_sel_a,alu_sel_b,load_x,load_y,load_alu,alu_op,out_x,out_y);
	input [15:0] in;
	input [1:0] alu_sel_a, alu_sel_b;
	input reset_n;
	input clock;
	
	input load_x;
	input load_y;
	input load_alu;
	input [1:0] alu_op;
	
	output reg [7:0]  out_x, out_y;
	
	reg [7:0] alu_out, alu_a, alu_b;
	
	always @(posedge clock)
	begin
		if (~reset_n)
			begin
				out_x <= 8'b00000000;
				out_y <= 8'b00000000;
			end
		else
			begin
				if (load_x)
					out_x <= load_alu ? alu_out : in[15:8];
				if (load_y)
					out_y <= load_alu ? alu_out : in[7:0];
			end
	end
	
	
	always @(*)
	begin 
		case (alu_sel_a)
			2'd0: alu_a = out_x;
			2'd1: alu_a = out_y;
		endcase
		case (alu_sel_a)
			2'd0: alu_b = out_x;
			2'd1: alu_b = out_y;
		endcase
	end
	
	always @(*)
	begin 
		case (alu_op)
			2'b00: alu_out <= alu_a + 1;
			2'b01: alu_out <= alu_a - 1;
			2'b10: alu_out <= alu_a - 2'b11;
			default: alu_out <= 8'b00000000;
		endcase
	end
endmodule