// -----------------------------------------------------------------------------
// GLOBAL DEFINITIONS
// -----------------------------------------------------------------------------

// FSM stuff
`define SWIDTH 2
`define S_OFF 2'b00
`define S_A   2'b01
`define S_B   2'b10
`define S_C   2'b11

// -----------------------------------------------------------------------------
// CORE
// -----------------------------------------------------------------------------

// Handles talking between client and server
module io;

	parameter clk_per = 10;
	parameter STDIN = 32'h8000_0000;

	// TODO this is very specific to the command being "WRITE_DATA".
	// Find a way to generalize it for any command
	reg[1:0] id; // id of component to perform actions on
	integer index;
	reg[63:0] value;
	integer c,r;
	reg CLK;	// Pretend this is private- don't use it!
	reg tick;	// Use this one. It ticks based on the server 

	// This creates our clock. CLK will get inverted every (clk_per/2) cycles
	initial begin
		CLK = 0;
		tick = 0;
		forever
		#(clk_per/2) CLK = ~CLK;
	end

	// This triggers whenever the clock ticks over to negative
	always @ (negedge CLK)
		// Check if we're at the end of file
		if (!$feof(STDIN)) begin
			// Read the next command
			c = $fgetc(STDIN);
			case (c)
			"b":	// Write Binary
				begin
					c = $fgetc(STDIN); // Dump space character
					r = $fscanf(STDIN, "%b %d %b", id, index, value);
					case (id)
						2'b00: control.airflowComp.update_binary(index, value);
						2'b01: control.thrustersComp.update_binary(index, value);
						2'b10: control.solarComp.update_binary(index, value);
					endcase
				end
			"f":	// Write Float
				begin
					c = $fgetc(STDIN); // Dump space character
					r = $fscanf(STDIN, "%b %d %d", id, index, value);
					case (id)
						2'b00: control.airflowComp.update_float(index, value);
						2'b01: control.thrustersComp.update_float(index, value);
						2'b10: control.solarComp.update_float(index, value);
					endcase
				end
			"h":
				// TODO hacker mode state
				begin end
			"t":	// Tick
				tick = ~tick;
			endcase
		end else
			$finish;
		
endmodule

// Handles various components
module control;

	reg rst;		// Whether or not to reset everything
	reg airflow;	// Whether our airflow component is online
	reg thrusters;	// Whether our thrusters component is online
	reg solar;		// Whether our solar component is online

	// Notice we don't pass anything to it from the solar component
	// in the components module. That's because of how verilog
	// works. So my ideas of divorcing the logic from the data
	// ended up not really succeeding, because now each logic
	// module is hardcoded to its own data. Ah well, it would
	// tke too long to refactor all that at this point
	airflow airflowComp(io.tick, rst, thrusters);
	thrusters thrustersComp(io.tick, rst, thrusters);
	solar solarComp(io.tick, rst, solar);

	initial begin // Start up all our components
		// Don't activate so everything can reset for a bit
		rst = 1'b1;
		airflow = 1'b0;
		thrusters = 1'b0;
		solar = 1'b0;

		// Start up
		#100 rst = 1'b0;
		airflow = 1'b1;
		thrusters = 1'b1;
		solar = 1'b1;
	end

endmodule

// -----------------------------------------------------------------------------
// COMPONENTS
// -----------------------------------------------------------------------------

module airflow(clk, rst, in);

	input clk, rst, in;
	real oxygen = 198;
	reg r1 = 1, r2 = 1, r3 = 1, r4 = 1, alert = 0; // r{1-4} are rooms 1-4

	parameter id = 2'b00;

  	initial begin
  		$display("init %b %f %b %b %b %b %b",
			id,				// %b
			oxygen, 		// %f
			r1,				// %b
			r2,				// %b
			r3,				// %b
			r4,				// %b
			alert);			// %b
  		$fflush;
  	end

  	task update_binary;
  		input integer index;
  		input reg[63:0] value;
  		begin
  			case (index)
  				1: r1 = value;
  				2: r2 = value;
  				3: r3 = value;
  				4: r4 = value;
  				5: alert = value;
  			endcase
			update();
  		end
  	endtask

	task update_float;
		input integer index;
		input real value;
		begin
			case (index)
				0: oxygen = value;
			endcase
			update();
		end
	endtask

	task update;
		begin
			$display("update %b %f %b %b %b %b %b",
				id,				// %b
				oxygen, 		// %f
				r1,				// %b
				r2,				// %b
				r3,				// %b
				r4,				// %b
				alert);			// %b
			$fflush;
		end
	endtask

endmodule

module thrusters(clk, rst, in);

	input clk, rst, in;
	real angle = 1.57079632679;
	real velocity = 3.14;
	real thrust = 100;
	reg [1:0] direction = 2'b00;

	parameter id = 2'b01;

  	initial begin
  		$display("init %b %f %f %f %b",
			id,			// %b
			angle, 		// %f
			velocity, 	// %f
			thrust,		// %f
			direction);	// %b
  		$fflush;
  	end

  	task update_binary;
  		input integer index;
  		input reg[63:0] value;
  		begin
  			case (index)
  				3: direction = value;
  			endcase
			update();
  		end
  	endtask

	task update_float;
		input integer index;
		input real value;
		begin
			case (index)
				0: angle = value;
				1: velocity = value;
				2: thrust = value;
			endcase
			update();
		end
	endtask

	task update;
		begin
			$display("update %b %f %f %f %b", 
				id,			// %b
				angle, 		// %f
				velocity, 	// %f
				thrust,		// %f
				direction);	// %b
			$fflush;
		end
	endtask

endmodule

module solar(clk, rst, in);

	input clk, rst, in;
	wire [`SWIDTH-1:0] state, next;
	reg [`SWIDTH-1:0] next1;
	wire [4:0] sun;
	real angle = 1.57079632679;
	real power = 0;

	parameter ANGLE_DELTA = 0.23456789;
	parameter id = 2'b10;
	parameter POWER_CONSTANT = 120;

  	DFF #(`SWIDTH) state_reg(clk, next, state) ;

  	Counter sun_timer(clk, rst, sun) ;

  	initial begin
  		$display("init %b %f %f %b",
			id,		// %b
			angle, 	// %f
			power, 	// %f
			sun);	// %b
  		$fflush;
  	end

  	task update_binary;
  		input integer index;
  		input reg[63:0] value;
  		begin
  			/*
  			Solar doesn't have any write-able binary values
			Note that sun is a wire, not a register, so we
			can't write to it. 
  			case (index)
  				2: sun = value;
  			endcase
			update();
  			*/
  		end
  	endtask

	task update_float;
		input integer index;
		input real value;
		begin
			case (index)
				0: angle = value;
				1: power = value;
			endcase
			update();
		end
	endtask

	task update;
		begin
			$display("update %b %f %f %b", 
				id,		// %b
				angle, 	// %f
				power, 	// %f
				sun);	// %b
			$fflush;
		end
	endtask

	always @(posedge io.tick) begin
		case(state)
		// no concatenation here, because those don't support reals as operands
			`S_OFF: begin 
				power = 0;
				next1 = in ? `S_A : `S_OFF;
			end
			`S_A: begin
				angle = (angle + ANGLE_DELTA) % 6.28318530718;
				power = 0;
				next1 = sun[4:4] ? `S_B : `S_A;
			end
			`S_B: begin
				angle = (angle - ANGLE_DELTA) % 6.28318530718;
				power = POWER_CONSTANT;
				next1 = sun[4:4] ? `S_B : `S_A;
			end
		endcase
		update();
	end

	assign next = rst ? `S_OFF : next1 ;

endmodule

// -----------------------------------------------------------------------------
// UTILITY
// -----------------------------------------------------------------------------

module DFF(clk, in, out);

	parameter n=1;
	input clk;
	input[n-1:0] in;
	output[n-1:0] out;
	reg[n-1:0] out;

	always @(negedge clk)
		out = in;

endmodule

module Counter(clk, rst, out) ;

	parameter n=5 ;//Count of 0 to 31
	input rst, clk ; // reset and clock
	output [n-1:0] out ;
	wire [n-1:0] next = rst? 0 : out+1 ;

	DFF #(n) count(clk, next, out) ;

endmodule
