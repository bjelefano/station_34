/**
 * #############
 * INSTRUCTIONS
 * #############
 *
 * This file contains modules that provide a high-level interface for
 * a PS/2 mouse, outputting the mouse's current X and Y position in 9 bits,
 * and left/right click signal. The origin (0, 0) is set at the top-left
 * corner of the screen. A position (X, Y) is X pixels to the right and
 * Y pixels down from the origin. Coordinate widths support up to 1023 pixel
 * resolutions in both dimensions.
 *
 * The modules contained in this file are designed for, and were tested on,
 * a DE1_SoC FPGA board. Be warned that performance is not guaranteed on
 * other boards.
 *
 * An additional test module has been provided to ensure the mouse controller
 * works properly. It is recommended to load the test module onto the board
 * before incorporating the mouse controller into any design.
 * See documentation for the mouse_interface_test module for more details.
 *
 *
 * #############################
 * RESOLUTION AND RANGE OPTIONS
 * #############################
 *
 * To limit the controller to operate in smaller dimensions, max X and Y
 * coordinate parameters have been provided. These can be set as follows:
 *
 * defparam XMAX 9'd319
 * defparam YMAX 9'b239
 *
 * Where the defparam statement can be placed in a module you define, near
 * the mouse controller module's instantiation. This particular example
 * sets the mouse to operate on a 320x240 pixel screen. Note that the values
 * set as the parameters must be one less than the actual screen width.
 * Specifing limits is necessary for both coordinates. If no defparam
 * statements are made, the controller will default to 160x120 resolution.
 *
 * In case the mouse is meant to operate inside a box and should not be
 * allowed to reach the edge of the screen, additional XMIN and YMIN
 * parameters have been provided. These can be defined in the same way as
 * XMAX and YMAX.
 * For example, suppose a mouse controller is instantiated as follows:
 *
 * mouse_tracker my_module(
 *                   ...
 *                   inputs/outputs
 *                   ...
 *                   );
 * 
 * To work with 320x240 screen resolution and prevent the mouse from being
 * within 5 pixels of the edge of the screen, write the following lines after
 * the module instantiation:
 *
 * defparam my_module.XMAX = 324,
 *          my_module.YMAX = 114,
 *          my_module.XMIN = 5,
 *          my_module.YMIN = 5;
 *
 * XMIN and YMIN are set to 0 by default, which will not restrict the mouse.
 *
 * Additionally, the mouse's initial position can be set with the XSTART and
 * YSTART parameters. These parameters should be set inside of the boundaries
 * XMAX, YMIN, etc. If not specified they will be set to the center of a screen
 * assuming 160x120 resolution, which is the default resolution.
 *
 *
 * ################################
 * INPUT AND OUTPUT SPECIFICATIONS
 * ################################
 *
 * clock - Main clock signal for the controller. This signal is separate from
 *         the mouse's clock signal, PS2_CLK. This input should be plugged into
 *         the same clock as the rest of the system is synchronized to.
 *
 * reset - Synchronous active-low reset signal. Resetting the controller will
 *         cause the mouse position to revert to its starting location specified
 *         by XSTART and YSTART. Resetting will also cause the mouse to go through
 *         its initialization sequence again.
 *
 * enable_tracking - Lowering this input will prevent the mouse's position from
 *                   changing even if the mouse is physically moving. This signal
 *                   must be kept high when mouse movement is to be recorded.
 *
 * PS2_CLK and PS2_DAT -
 *    These inputs correspond to the PS2_CLK and PS2_DAT signals from the board.
 *    Do NOT use PS2_CLK2 or PS2_DAT2 unless using a 2-1 splitter cable, or else
 *    neither input will be connected to anything.
 *
 *    These signals should be declared as inout (bidirectionals) ports in any
 *    ancestor modules to the mouse controller. Do NOT attempt to change the value
 *    of the clock or data wires or else indeterminate behaviour will result.
 *
 *
 * x_pos -
 *    Current X coordinate. Moving the mouse to the right causes this coordinate
 *    to increase; moving the mouse left causes the coordinate to decrease.
 *
 * y_pos -
 *    Current Y coordinate. Moving the mouse upward causes this coordinate
 *    to decrease; moving the mouse downward causes the coordinate to increase.
 *
 * right-click -
 *    High if the right mouse button is being pressed or held down, and low if
 *    the right mouse is not being pressed.
 *
 * right-click -
 *    High if the left mouse button is being pressed or held down, and low if
 *    the left mouse is not being pressed.
 *
 *
 * #################
 * ACKNOWLEDGEMENTS
 * #################
 *
 * Credit for low-level PS/2 driver module (also a resource for PS/2 protocol):
 * http://www.eecg.toronto.edu/~jayar/ece241_08F/AudioVideoCores/ps2/ps2.html
 */
module mouse_tracker(
    input clock,
	 input reset,
	 input enable_tracking,
	 
	 inout PS2_CLK,
	 inout PS2_DAT,
	 
	 output reg [8:0] x_pos,
	 output reg [8:0] y_pos,
	 output reg right_click,
	 output reg left_click,
	 output reg [3:0] count
    );

	 // A flag indicating when the mouse has sent a new byte.
	 wire byte_received;
	 // The most recent byte received from the mouse.
	 wire [7:0] newest_byte;
	 
	 // Registers hold bytes from each 3-byte packet received from the mouse.
	 reg [7:0] byte1;
	 reg [7:0] byte2;
	 reg [7:0] byte3;
	 
	 // The location of the mouse after the newest X and Y offsets have been
	 // added. This value will become the new X and Y position if it is in
	 // bounds. Otherwise the nearest in-bounds value will be used.
	 wire [8:0] new_x;
	 wire [8:0] new_y;
	 
	 assign new_x = x_pos + {byte1[4], byte2};
	 // New Y offset is subtracted from the previous position because the mouse
	 // reports Y offsets inverted relative to this controller's scheme (i.e.
	 // the origin is placed at the bottom left corner, so moving the mouse down
	 // causes its position to decrease instead of increase).
	 assign new_y = y_pos - {byte1[5], byte3};
	 
	 PS2_Controller #(.INITIALIZE_MOUSE(1)) tracker2(
	     .CLOCK_50(clock),
		  .reset(~reset),
		  .PS2_CLK(PS2_CLK),
		  .PS2_DAT(PS2_DAT),
		  .received_data(newest_byte),
		  .received_data_en(byte_received)
		  );
	 
	 reg [2:0] curr_state;
	 reg [2:0] next_state;
	 
	 // Flag indicating whether the first of the two initialization signals
	 // has been received from the mouse upon startup. This flag is not
	 // important if the controller is not in the WAIT_INIT state.
	 reg init_byte_received;
	 
	 localparam WAIT_INIT   = 3'b000, // Receive initial two mouse signals on startup.
	            GET_BYTE_1  = 3'b001, // Wait for mouse to send first byte of packet.
					LOAD_BYTE_1 = 3'b011, // Store the first byte of the packet.
					GET_BYTE_2  = 3'b010, // Wait for mouse to send second byte of packet.
					LOAD_BYTE_2 = 3'b110, // Store the second byte of the packet.
					GET_BYTE_3  = 3'b100, // Wait for mouse to send third byte of packet.
					LOAD_BYTE_3 = 3'b101, // Store the third byte of the packet.
					PROCESS     = 3'b111; // Extract new mouse state from 3-byte packet.

    parameter  XMIN        = 9'd0,   // Left boundary for X position.
	            YMIN        = 9'b0,   // Top boundary for Y position.
					XMAX        = 9'd159, // Right boundary for X position.
					YMAX        = 9'd119, // Bottom boundary for Y position.
					XSTART      = 9'd79,  // Initial X position on reset.
					YSTART      = 9'd59;  // Initial Y position on reset.
    
	 always @(*) begin: state_transitions
	     case (curr_state)
		      WAIT_INIT:  next_state = init_byte_received && byte_received ? GET_BYTE_1 : WAIT_INIT;
		      GET_BYTE_1: next_state = byte_received ? LOAD_BYTE_1 : GET_BYTE_1;
				LOAD_BYTE_1: next_state = GET_BYTE_2;
				GET_BYTE_2: next_state = byte_received ? LOAD_BYTE_2 : GET_BYTE_2;
				LOAD_BYTE_2: next_state = GET_BYTE_3;
				GET_BYTE_3: next_state = byte_received ? LOAD_BYTE_3 : GET_BYTE_3;
				LOAD_BYTE_3: next_state = PROCESS;
				PROCESS: next_state = GET_BYTE_1;
        endcase
    end  // state_transitions
	 
	 
	 always @(posedge clock) begin: receive_data
	     // All signals hold their values by default.
	     byte1 <= byte1;
		  byte2 <= byte2;
		  byte3 <= byte3;
		  x_pos <= x_pos;
		  y_pos <= y_pos;
		  left_click <= left_click;
		  init_byte_received <= init_byte_received;
		  count <= count;
		  
		  if (~reset) begin
		      byte1 <= 8'b0;
				byte2 <= 8'b0;
				byte3 <= 8'b0;
				x_pos <= XSTART;
				y_pos <= YSTART;
				left_click  <= 1'b0;
				right_click <= 1'b0;
				init_byte_received <= 1'b0;
				count <= 4'd15;
        end
		  if (byte_received)
		      init_byte_received <= 1'b1;
        if (curr_state == LOAD_BYTE_1)
		      // Store the newly received first byte of the new package.
            byte1 <= newest_byte;
        if (curr_state == LOAD_BYTE_2)
		      // Store the new second byte of the new package.
            byte2 <= newest_byte;
        if (curr_state == LOAD_BYTE_3)
		      // Store the third byte of the new package.
		      byte3 <= newest_byte;
        if (curr_state == PROCESS) begin
		      // Compute new X and Y locations from offsets.
				// See a page on PS/2 mouse protocol for interpretations of bytes
				// in byte1, byte2, and byte3.
		      x_pos <= ~enable_tracking || byte1[6] ? x_pos
				           // Mouse disabled/overflowed, so keep previous position.
                     : (new_x < XMIN || (byte1[4] && new_x > x_pos) ? XMIN
                       // Mouse has moved past its left boundary.
                     : (new_x > XMAX ? XMAX
                       // Mouse has moved past its right boundary.
                     : new_x));
                       // New mouse X position is in bounds.
							  
            y_pos <= ~enable_tracking || byte1[7] ? y_pos
                       // Mouse disabled/overflowed, so keep previous position.
                     : (new_y < YMIN || (~byte1[5] && new_y > y_pos) ? YMIN
							  // Mouse has moved past its upper boundary.
                     : (new_y > YMAX ? YMAX
							  // Mouse has moved past its lower boundary.
							: new_y));
							  // New mouse Y position is in bounds.

            // Right and left clicks are indicated by flag bits in byte1.
            right_click <= byte1[1];
				left_click  <= byte1[0];
				count <= count - 4'b1;
        end
    end  // receive_data
	 
	 
	 always @(posedge clock) begin: increment_state
	     if (~reset) begin
		      // Prepare to receive initialization bits from the mouse.
		      curr_state <= WAIT_INIT;
		  end
		  else begin
		      curr_state <= next_state;
		  end
    end  // increment_state
endmodule


/**
 * This module is meant to test that the mouse controller outputs the expected
 * signals when the mouse is moved and clicked. The mouse's X position is
 * displayed on hex displays HEX0 to HEX2, and the Y coordinate is displayed
 * on HEX3 to HEX5. Left click and right click are dispayed on LEDR[1] and
 * LEDR[0] respectively. Middle mouse buttons are currently not supported.
 * Press KEY[0] to reset the device. This will restore the mouse to its
 * starting position, set to its default of X = 79 and Y = 59.
 *
 * As specified above, moving the mouse right should increase
 * its recorded X coordinate, and moving the mouse down should increase its Y
 * coordinate. In addition, X coordinates should stay between XMIN and XMAX,
 * and Y coordinates should stay between YMIN and YMAX. The mouse should not
 * be able to loop from the top to the bottom when moved up, or from the left
 * to the right when moved left.
 *
 * If the coordinates do not change when the mouse is moved, the core driver
 * does not work with your board and you should try another mouse controller
 * entirely. If X and Y are getting reversed (i.e. Y coordinates show up on
 * HEX0 to HEX2) then the problem lies in the first setup state in the
 * mouse_tracker module. Any other problems will likely be found in the
 * calculations in module mouse_tracker.
 */
module mouse_interface_test(
    input CLOCK_50,
	 input [3:0] KEY,
	 
	 inout PS2_CLK,
	 inout PS2_DAT,
	 
	 output [6:0] HEX0,
	 output [6:0] HEX1,
	 output [6:0] HEX2,
	 output [6:0] HEX3,
	 output [6:0] HEX4,
	 output [6:0] HEX5,
	 output [9:0] LEDR
	 );
	 
	 wire [8:0] x_coord;
	 wire [8:0] y_coord;
	 
	 mouse_tracker tester(
	     .clock(CLOCK_50),
		  .reset(KEY[0]),
		  .enable_tracking(1'b1),
		  .PS2_CLK(PS2_CLK),
		  .PS2_DAT(PS2_DAT),
		  .x_pos(x_coord),
		  .y_pos(y_coord),
		  .left_click(LEDR[1]),
		  .right_click(LEDR[0])
		  );

    // Put X coordinates on hex displays 0-2

    hex_decoder hex0(
	     .hex_digit(x_coord[3:0]),
		  .segments(HEX0)
		  );

    hex_decoder hex1(
	     .hex_digit(x_coord[7:4]),
		  .segments(HEX1)
		  );

    hex_decoder hex2(
	     .hex_digit({3'b0, x_coord[8]}),
		  .segments(HEX2)
		  );

    // Put Y coordinates on hex displays 3-5

    hex_decoder hex3(
	     .hex_digit(y_coord[3:0]),
		  .segments(HEX3)
		  );

    hex_decoder hex4(
	     .hex_digit(y_coord[7:4]),
		  .segments(HEX4)
		  );

    hex_decoder hex5(
	     .hex_digit({3'b0, y_coord[8]}),
		  .segments(HEX5)
		  );
endmodule


/**
 * Hex decoder module provided for convenient testing. Displays all characters
 * from 0 to F.
 */
module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule

/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_PS2                                               *
 * Description:                                                              *
 *      This module communicates with the PS2 core.                          *
 *                                                                           *
 *****************************************************************************/

module PS2_Controller #(parameter INITIALIZE_MOUSE = 0) (
	// Inputs
	CLOCK_50,
	reset,

	the_command,
	send_command,

	// Bidirectionals
	PS2_CLK,					// PS2 Clock
 	PS2_DAT,					// PS2 Data

	// Outputs
	command_was_sent,
	error_communication_timed_out,

	received_data,
	received_data_en			// If 1 - new data has been received
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input			CLOCK_50;
input			reset;

input	[7:0]	the_command;
input			send_command;

// Bidirectionals
inout			PS2_CLK;
inout		 	PS2_DAT;

// Outputs
output			command_was_sent;
output			error_communication_timed_out;

output	[7:0]	received_data;
output		 	received_data_en;

wire [7:0] the_command_w;
wire send_command_w, command_was_sent_w, error_communication_timed_out_w;

generate
	if(INITIALIZE_MOUSE) begin
	   reg init_done;
		
		assign the_command_w = init_done ? the_command : 8'hf4;
		assign send_command_w = init_done ? send_command : (!command_was_sent_w && !error_communication_timed_out_w);
		assign command_was_sent = init_done ? command_was_sent_w : 0;
		assign error_communication_timed_out = init_done ? error_communication_timed_out_w : 1;
		
		always @(posedge CLOCK_50)
			if(reset) init_done <= 0;
			else if(command_was_sent_w) init_done <= 1;
		
	end else begin
		assign the_command_w = the_command;
		assign send_command_w = send_command;
		assign command_was_sent = command_was_sent_w;
		assign error_communication_timed_out = error_communication_timed_out_w;
	end
endgenerate

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
localparam	PS2_STATE_0_IDLE			= 3'h0,
			PS2_STATE_1_DATA_IN			= 3'h1,
			PS2_STATE_2_COMMAND_OUT		= 3'h2,
			PS2_STATE_3_END_TRANSFER	= 3'h3,
			PS2_STATE_4_END_DELAYED		= 3'h4;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires
wire			ps2_clk_posedge;
wire			ps2_clk_negedge;

wire			start_receiving_data;
wire			wait_for_incoming_data;

// Internal Registers
reg		[7:0]	idle_counter;

reg				ps2_clk_reg;
reg				ps2_data_reg;
reg				last_ps2_clk;

// State Machine Registers
reg		[2:0]	ns_ps2_transceiver;
reg		[2:0]	s_ps2_transceiver;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge CLOCK_50)
begin
	if (reset == 1'b1)
		s_ps2_transceiver <= PS2_STATE_0_IDLE;
	else
		s_ps2_transceiver <= ns_ps2_transceiver;
end

always @(*)
begin
	// Defaults
	ns_ps2_transceiver = PS2_STATE_0_IDLE;

    case (s_ps2_transceiver)
	PS2_STATE_0_IDLE:
		begin
			if ((idle_counter == 8'hFF) && 
					(send_command == 1'b1))
				ns_ps2_transceiver = PS2_STATE_2_COMMAND_OUT;
			else if ((ps2_data_reg == 1'b0) && (ps2_clk_posedge == 1'b1))
				ns_ps2_transceiver = PS2_STATE_1_DATA_IN;
			else
				ns_ps2_transceiver = PS2_STATE_0_IDLE;
		end
	PS2_STATE_1_DATA_IN:
		begin
			if ((received_data_en == 1'b1)/* && (ps2_clk_posedge == 1'b1)*/)
				ns_ps2_transceiver = PS2_STATE_0_IDLE;
			else
				ns_ps2_transceiver = PS2_STATE_1_DATA_IN;
		end
	PS2_STATE_2_COMMAND_OUT:
		begin
			if ((command_was_sent == 1'b1) ||
				(error_communication_timed_out == 1'b1))
				ns_ps2_transceiver = PS2_STATE_3_END_TRANSFER;
			else
				ns_ps2_transceiver = PS2_STATE_2_COMMAND_OUT;
		end
	PS2_STATE_3_END_TRANSFER:
		begin
			if (send_command == 1'b0)
				ns_ps2_transceiver = PS2_STATE_0_IDLE;
			else if ((ps2_data_reg == 1'b0) && (ps2_clk_posedge == 1'b1))
				ns_ps2_transceiver = PS2_STATE_4_END_DELAYED;
			else
				ns_ps2_transceiver = PS2_STATE_3_END_TRANSFER;
		end
	PS2_STATE_4_END_DELAYED:	
		begin
			if (received_data_en == 1'b1)
			begin
				if (send_command == 1'b0)
					ns_ps2_transceiver = PS2_STATE_0_IDLE;
				else
					ns_ps2_transceiver = PS2_STATE_3_END_TRANSFER;
			end
			else
				ns_ps2_transceiver = PS2_STATE_4_END_DELAYED;
		end	
	default:
			ns_ps2_transceiver = PS2_STATE_0_IDLE;
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

always @(posedge CLOCK_50)
begin
	if (reset == 1'b1)
	begin
		last_ps2_clk	<= 1'b1;
		ps2_clk_reg		<= 1'b1;

		ps2_data_reg	<= 1'b1;
	end
	else
	begin
		last_ps2_clk	<= ps2_clk_reg;
		ps2_clk_reg		<= PS2_CLK;

		ps2_data_reg	<= PS2_DAT;
	end
end

always @(posedge CLOCK_50)
begin
	if (reset == 1'b1)
		idle_counter <= 6'h00;
	else if ((s_ps2_transceiver == PS2_STATE_0_IDLE) &&
			(idle_counter != 8'hFF))
		idle_counter <= idle_counter + 6'h01;
	else if (s_ps2_transceiver != PS2_STATE_0_IDLE)
		idle_counter <= 6'h00;
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

assign ps2_clk_posedge = 
			((ps2_clk_reg == 1'b1) && (last_ps2_clk == 1'b0)) ? 1'b1 : 1'b0;
assign ps2_clk_negedge = 
			((ps2_clk_reg == 1'b0) && (last_ps2_clk == 1'b1)) ? 1'b1 : 1'b0;

assign start_receiving_data		= (s_ps2_transceiver == PS2_STATE_1_DATA_IN);
assign wait_for_incoming_data	= 
			(s_ps2_transceiver == PS2_STATE_3_END_TRANSFER);

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

Altera_UP_PS2_Data_In PS2_Data_In (
	// Inputs
	.clk							(CLOCK_50),
	.reset							(reset),

	.wait_for_incoming_data			(wait_for_incoming_data),
	.start_receiving_data			(start_receiving_data),

	.ps2_clk_posedge				(ps2_clk_posedge),
	.ps2_clk_negedge				(ps2_clk_negedge),
	.ps2_data						(ps2_data_reg),

	// Bidirectionals

	// Outputs
	.received_data					(received_data),
	.received_data_en				(received_data_en)
);

Altera_UP_PS2_Command_Out PS2_Command_Out (
	// Inputs
	.clk							(CLOCK_50),
	.reset							(reset),

	.the_command					(the_command_w),
	.send_command					(send_command_w),

	.ps2_clk_posedge				(ps2_clk_posedge),
	.ps2_clk_negedge				(ps2_clk_negedge),

	// Bidirectionals
	.PS2_CLK						(PS2_CLK),
 	.PS2_DAT						(PS2_DAT),

	// Outputs
	.command_was_sent				(command_was_sent_w),
	.error_communication_timed_out	(error_communication_timed_out_w)
);

endmodule

/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_PS2_Command_Out                                   *
 * Description:                                                              *
 *      This module sends commands out to the PS2 core.                      *
 *                                                                           *
 *****************************************************************************/


module Altera_UP_PS2_Command_Out (
	// Inputs
	clk,
	reset,

	the_command,
	send_command,

	ps2_clk_posedge,
	ps2_clk_negedge,

	// Bidirectionals
	PS2_CLK,
 	PS2_DAT,

	// Outputs
	command_was_sent,
	error_communication_timed_out
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/

// Timing info for initiating Host-to-Device communication 
//   when using a 50MHz system clock
parameter	CLOCK_CYCLES_FOR_101US		= 5050;
parameter	NUMBER_OF_BITS_FOR_101US	= 13;
parameter	COUNTER_INCREMENT_FOR_101US	= 13'h0001;

//parameter	CLOCK_CYCLES_FOR_101US		= 50;
//parameter	NUMBER_OF_BITS_FOR_101US	= 6;
//parameter	COUNTER_INCREMENT_FOR_101US	= 6'h01;

// Timing info for start of transmission error 
//   when using a 50MHz system clock
parameter	CLOCK_CYCLES_FOR_15MS		= 750000;
parameter	NUMBER_OF_BITS_FOR_15MS		= 20;
parameter	COUNTER_INCREMENT_FOR_15MS	= 20'h00001;

// Timing info for sending data error 
//   when using a 50MHz system clock
parameter	CLOCK_CYCLES_FOR_2MS		= 100000;
parameter	NUMBER_OF_BITS_FOR_2MS		= 17;
parameter	COUNTER_INCREMENT_FOR_2MS	= 17'h00001;

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				clk;
input				reset;

input		[7:0]	the_command;
input				send_command;

input				ps2_clk_posedge;
input				ps2_clk_negedge;

// Bidirectionals
inout				PS2_CLK;
inout			 	PS2_DAT;

// Outputs
output	reg			command_was_sent;
output	reg		 	error_communication_timed_out;

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
parameter	PS2_STATE_0_IDLE					= 3'h0,
			PS2_STATE_1_INITIATE_COMMUNICATION	= 3'h1,
			PS2_STATE_2_WAIT_FOR_CLOCK			= 3'h2,
			PS2_STATE_3_TRANSMIT_DATA			= 3'h3,
			PS2_STATE_4_TRANSMIT_STOP_BIT		= 3'h4,
			PS2_STATE_5_RECEIVE_ACK_BIT			= 3'h5,
			PS2_STATE_6_COMMAND_WAS_SENT		= 3'h6,
			PS2_STATE_7_TRANSMISSION_ERROR		= 3'h7;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires

// Internal Registers
reg			[3:0]	cur_bit;
reg			[8:0]	ps2_command;

reg			[NUMBER_OF_BITS_FOR_101US:1]	command_initiate_counter;

reg			[NUMBER_OF_BITS_FOR_15MS:1]		waiting_counter;
reg			[NUMBER_OF_BITS_FOR_2MS:1]		transfer_counter;

// State Machine Registers
reg			[2:0]	ns_ps2_transmitter;
reg			[2:0]	s_ps2_transmitter;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		s_ps2_transmitter <= PS2_STATE_0_IDLE;
	else
		s_ps2_transmitter <= ns_ps2_transmitter;
end

always @(*)
begin
	// Defaults
	ns_ps2_transmitter = PS2_STATE_0_IDLE;

    case (s_ps2_transmitter)
	PS2_STATE_0_IDLE:
		begin
			if (send_command == 1'b1)
				ns_ps2_transmitter = PS2_STATE_1_INITIATE_COMMUNICATION;
			else
				ns_ps2_transmitter = PS2_STATE_0_IDLE;
		end
	PS2_STATE_1_INITIATE_COMMUNICATION:
		begin
			if (command_initiate_counter == CLOCK_CYCLES_FOR_101US)
				ns_ps2_transmitter = PS2_STATE_2_WAIT_FOR_CLOCK;
			else
				ns_ps2_transmitter = PS2_STATE_1_INITIATE_COMMUNICATION;
		end
	PS2_STATE_2_WAIT_FOR_CLOCK:
		begin
			if (ps2_clk_negedge == 1'b1)
				ns_ps2_transmitter = PS2_STATE_3_TRANSMIT_DATA;
			else if (waiting_counter == CLOCK_CYCLES_FOR_15MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_2_WAIT_FOR_CLOCK;
		end
	PS2_STATE_3_TRANSMIT_DATA:
		begin
			if ((cur_bit == 4'd8) && (ps2_clk_negedge == 1'b1))
				ns_ps2_transmitter = PS2_STATE_4_TRANSMIT_STOP_BIT;
			else if (transfer_counter == CLOCK_CYCLES_FOR_2MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_3_TRANSMIT_DATA;
		end
	PS2_STATE_4_TRANSMIT_STOP_BIT:
		begin
			if (ps2_clk_negedge == 1'b1)
				ns_ps2_transmitter = PS2_STATE_5_RECEIVE_ACK_BIT;
			else if (transfer_counter == CLOCK_CYCLES_FOR_2MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_4_TRANSMIT_STOP_BIT;
		end
	PS2_STATE_5_RECEIVE_ACK_BIT:
		begin
			if (ps2_clk_posedge == 1'b1)
				ns_ps2_transmitter = PS2_STATE_6_COMMAND_WAS_SENT;
			else if (transfer_counter == CLOCK_CYCLES_FOR_2MS)
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
			else
				ns_ps2_transmitter = PS2_STATE_5_RECEIVE_ACK_BIT;
		end
	PS2_STATE_6_COMMAND_WAS_SENT:
		begin
			if (send_command == 1'b0)
				ns_ps2_transmitter = PS2_STATE_0_IDLE;
			else
				ns_ps2_transmitter = PS2_STATE_6_COMMAND_WAS_SENT;
		end
	PS2_STATE_7_TRANSMISSION_ERROR:
		begin
			if (send_command == 1'b0)
				ns_ps2_transmitter = PS2_STATE_0_IDLE;
			else
				ns_ps2_transmitter = PS2_STATE_7_TRANSMISSION_ERROR;
		end
	default:
		begin
			ns_ps2_transmitter = PS2_STATE_0_IDLE;
		end
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		ps2_command <= 9'h000;
	else if (s_ps2_transmitter == PS2_STATE_0_IDLE)
		ps2_command <= {(^the_command) ^ 1'b1, the_command};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		command_initiate_counter <= {NUMBER_OF_BITS_FOR_101US{1'b0}};
	else if ((s_ps2_transmitter == PS2_STATE_1_INITIATE_COMMUNICATION) &&
			(command_initiate_counter != CLOCK_CYCLES_FOR_101US))
		command_initiate_counter <= 
			command_initiate_counter + COUNTER_INCREMENT_FOR_101US;
	else if (s_ps2_transmitter != PS2_STATE_1_INITIATE_COMMUNICATION)
		command_initiate_counter <= {NUMBER_OF_BITS_FOR_101US{1'b0}};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		waiting_counter <= {NUMBER_OF_BITS_FOR_15MS{1'b0}};
	else if ((s_ps2_transmitter == PS2_STATE_2_WAIT_FOR_CLOCK) &&
			(waiting_counter != CLOCK_CYCLES_FOR_15MS))
		waiting_counter <= waiting_counter + COUNTER_INCREMENT_FOR_15MS;
	else if (s_ps2_transmitter != PS2_STATE_2_WAIT_FOR_CLOCK)
		waiting_counter <= {NUMBER_OF_BITS_FOR_15MS{1'b0}};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		transfer_counter <= {NUMBER_OF_BITS_FOR_2MS{1'b0}};
	else
	begin
		if ((s_ps2_transmitter == PS2_STATE_3_TRANSMIT_DATA) ||
			(s_ps2_transmitter == PS2_STATE_4_TRANSMIT_STOP_BIT) ||
			(s_ps2_transmitter == PS2_STATE_5_RECEIVE_ACK_BIT))
		begin
			if (transfer_counter != CLOCK_CYCLES_FOR_2MS)
				transfer_counter <= transfer_counter + COUNTER_INCREMENT_FOR_2MS;
		end
		else
			transfer_counter <= {NUMBER_OF_BITS_FOR_2MS{1'b0}};
	end
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		cur_bit <= 4'h0;
	else if ((s_ps2_transmitter == PS2_STATE_3_TRANSMIT_DATA) &&
			(ps2_clk_negedge == 1'b1))
		cur_bit <= cur_bit + 4'h1;
	else if (s_ps2_transmitter != PS2_STATE_3_TRANSMIT_DATA)
		cur_bit <= 4'h0;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		command_was_sent <= 1'b0;
	else if (s_ps2_transmitter == PS2_STATE_6_COMMAND_WAS_SENT)
		command_was_sent <= 1'b1;
	else if (send_command == 1'b0)
			command_was_sent <= 1'b0;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		error_communication_timed_out <= 1'b0;
	else if (s_ps2_transmitter == PS2_STATE_7_TRANSMISSION_ERROR)
		error_communication_timed_out <= 1'b1;
	else if (send_command == 1'b0)
		error_communication_timed_out <= 1'b0;
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/

assign PS2_CLK	= 
	(s_ps2_transmitter == PS2_STATE_1_INITIATE_COMMUNICATION) ? 
		1'b0 :
		1'bz;

assign PS2_DAT	= 
	(s_ps2_transmitter == PS2_STATE_3_TRANSMIT_DATA) ? ps2_command[cur_bit] :
	(s_ps2_transmitter == PS2_STATE_2_WAIT_FOR_CLOCK) ? 1'b0 :
	((s_ps2_transmitter == PS2_STATE_1_INITIATE_COMMUNICATION) && 
		(command_initiate_counter[NUMBER_OF_BITS_FOR_101US] == 1'b1)) ? 1'b0 : 
			1'bz;

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

endmodule

/*****************************************************************************
 *                                                                           *
 * Module:       Altera_UP_PS2_Data_In                                       *
 * Description:                                                              *
 *      This module accepts incoming data from a PS2 core.                   *
 *                                                                           *
 *****************************************************************************/


module Altera_UP_PS2_Data_In (
	// Inputs
	clk,
	reset,

	wait_for_incoming_data,
	start_receiving_data,

	ps2_clk_posedge,
	ps2_clk_negedge,
	ps2_data,

	// Bidirectionals

	// Outputs
	received_data,
	received_data_en			// If 1 - new data has been received
);


/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				clk;
input				reset;

input				wait_for_incoming_data;
input				start_receiving_data;

input				ps2_clk_posedge;
input				ps2_clk_negedge;
input			 	ps2_data;

// Bidirectionals

// Outputs
output reg	[7:0]	received_data;

output reg		 	received_data_en;

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/
// states
localparam	PS2_STATE_0_IDLE			= 3'h0,
			PS2_STATE_1_WAIT_FOR_DATA	= 3'h1,
			PS2_STATE_2_DATA_IN			= 3'h2,
			PS2_STATE_3_PARITY_IN		= 3'h3,
			PS2_STATE_4_STOP_IN			= 3'h4;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/
// Internal Wires
reg			[3:0]	data_count;
reg			[7:0]	data_shift_reg;

// State Machine Registers
reg			[2:0]	ns_ps2_receiver;
reg			[2:0]	s_ps2_receiver;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

always @(posedge clk)
begin
	if (reset == 1'b1)
		s_ps2_receiver <= PS2_STATE_0_IDLE;
	else
		s_ps2_receiver <= ns_ps2_receiver;
end

always @(*)
begin
	// Defaults
	ns_ps2_receiver = PS2_STATE_0_IDLE;

    case (s_ps2_receiver)
	PS2_STATE_0_IDLE:
		begin
			if ((wait_for_incoming_data == 1'b1) && 
					(received_data_en == 1'b0))
				ns_ps2_receiver = PS2_STATE_1_WAIT_FOR_DATA;
			else if ((start_receiving_data == 1'b1) && 
					(received_data_en == 1'b0))
				ns_ps2_receiver = PS2_STATE_2_DATA_IN;
			else
				ns_ps2_receiver = PS2_STATE_0_IDLE;
		end
	PS2_STATE_1_WAIT_FOR_DATA:
		begin
			if ((ps2_data == 1'b0) && (ps2_clk_posedge == 1'b1))
				ns_ps2_receiver = PS2_STATE_2_DATA_IN;
			else if (wait_for_incoming_data == 1'b0)
				ns_ps2_receiver = PS2_STATE_0_IDLE;
			else
				ns_ps2_receiver = PS2_STATE_1_WAIT_FOR_DATA;
		end
	PS2_STATE_2_DATA_IN:
		begin
			if ((data_count == 3'h7) && (ps2_clk_posedge == 1'b1))
				ns_ps2_receiver = PS2_STATE_3_PARITY_IN;
			else
				ns_ps2_receiver = PS2_STATE_2_DATA_IN;
		end
	PS2_STATE_3_PARITY_IN:
		begin
			if (ps2_clk_posedge == 1'b1)
				ns_ps2_receiver = PS2_STATE_4_STOP_IN;
			else
				ns_ps2_receiver = PS2_STATE_3_PARITY_IN;
		end
	PS2_STATE_4_STOP_IN:
		begin
			if (ps2_clk_posedge == 1'b1)
				ns_ps2_receiver = PS2_STATE_0_IDLE;
			else
				ns_ps2_receiver = PS2_STATE_4_STOP_IN;
		end
	default:
		begin
			ns_ps2_receiver = PS2_STATE_0_IDLE;
		end
	endcase
end

/*****************************************************************************
 *                             Sequential logic                              *
 *****************************************************************************/


always @(posedge clk)
begin
	if (reset == 1'b1) 
		data_count	<= 3'h0;
	else if ((s_ps2_receiver == PS2_STATE_2_DATA_IN) && 
			(ps2_clk_posedge == 1'b1))
		data_count	<= data_count + 3'h1;
	else if (s_ps2_receiver != PS2_STATE_2_DATA_IN)
		data_count	<= 3'h0;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		data_shift_reg			<= 8'h00;
	else if ((s_ps2_receiver == PS2_STATE_2_DATA_IN) && 
			(ps2_clk_posedge == 1'b1))
		data_shift_reg	<= {ps2_data, data_shift_reg[7:1]};
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		received_data		<= 8'h00;
	else if (s_ps2_receiver == PS2_STATE_4_STOP_IN)
		received_data	<= data_shift_reg;
end

always @(posedge clk)
begin
	if (reset == 1'b1)
		received_data_en		<= 1'b0;
	else if ((s_ps2_receiver == PS2_STATE_4_STOP_IN) &&
			(ps2_clk_posedge == 1'b1))
		received_data_en	<= 1'b1;
	else
		received_data_en	<= 1'b0;
end

/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/


/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/


endmodule

