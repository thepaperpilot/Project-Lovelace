// -----------------------------------------------------------------------------
// GLOBAL DEFINITIONS
// -----------------------------------------------------------------------------

// FSM stuff
`define SWIDTH 3	// Number of bits needed to represent our current state
`define S_OFF 3'b000	// State when component is turned off
`define S_A   3'b001
`define S_B   3'b010
`define S_C   3'b011
`define S2_CW   3'b100
`define S2_CCW  3'b101
`define S2_NOGO 3'b110
`define S2_OFF   3'b111
// -----------------------------------------------------------------------------
// CORE
// -----------------------------------------------------------------------------

// Handles talking between client and server
module io;

	parameter clk_per = 10;
	parameter STDIN = 32'h8000_0000;

	reg[1:0] id; 		// id of component to perform actions on
	integer index;		// For some commands, index of a variable to change
	reg[63:0] value;	// For some commands, value to change a variable to
	integer c,r;		// For reading commands
	reg CLK;			// Pretend this is private- don't use it!
	reg tick;			// Use this one. It ticks based on the server

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
			"b": begin	// Write Binary Value
				c = $fgetc(STDIN); // Dump space character
				r = $fscanf(STDIN, "%b %d %b", id, index, value);
				case (id)
					control.airflowComp.id:
						control.airflowComp.update_binary(index, value);
					control.thrustersComp.id:
						control.thrustersComp.update_binary(index, value);
					control.solarComp.id:
						control.solarComp.update_binary(index, value);
				endcase
			end
			"f": begin	// Write Float Value
				c = $fgetc(STDIN); // Dump space character
				r = $fscanf(STDIN, "%b %d %d", id, index, value);
				case (id)
					control.airflowComp.id:
						control.airflowComp.update_float(index, value);
					control.thrustersComp.id:
						control.thrustersComp.update_float(index, value);
					control.solarComp.id:
						control.solarComp.update_float(index, value);
				endcase
			end
			"h": begin // Hacker mode

			end
			"t": begin	// Tick Server
				tick = ~tick;
			end
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
	airflow airflowComp(io.tick, rst, airflow);
	thrusters thrustersComp(io.tick, rst, thrusters);
	solar solarComp(io.tick, rst, solar);

	initial begin // Start up all our components
		// Don't activate so everything can reset for a bit
		rst = 1'b1;
		airflow = 1'b0;
		thrusters = 1'b0;
		solar = 1'b0;

		// Start all our components up after 100 clock cycles
		#100 rst = 1'b0;
		airflow = 1'b1;
		thrusters = 1'b1;
		solar = 1'b1;
	end

endmodule

// -----------------------------------------------------------------------------
// COMPONENTS
// -----------------------------------------------------------------------------

// Component in charge of managing airflow:
// Controls vents in each of the rooms on the ISS (inputs)
// And monitors our supply of oxygen (outputs)
module airflow(clk, rst, in);

	input clk, rst, in;					// These let the control FSM manage us
	real oxygen = 198;					// Our oxygen supply (client max: 256)
	reg r1 = 1, r2 = 1, r3 = 1, r4 = 1;	// Whether room vents are open or not
	reg alert = 0; 						// Whether our oxygen is critically low

	parameter id = 2'b00;				// The ID to use to refer to this comp

  	// Send message to client initializing this component
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

  	// Updates a binary value when called by the io module
  	task update_binary;
  		input integer index;	// Which value to update
  		input reg[63:0] value;	// New value
  		begin
  			case (index)
  				1: r1 = value;
  				2: r2 = value;
  				3: r3 = value;
  				4: r4 = value;
  				5: alert = value;
  			endcase
			update();			// Send update message to client
  		end
  	endtask

  	// Updates a float value when called by the io module
	task update_float;
		input integer index;	// Which value to update
		input real value;		// New value
		begin
			case (index)
				0: oxygen = value;
			endcase
			update();			// Send update message to client
		end
	endtask

	// Sends a message to the client with all of our current values
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

// Component in charge of the ISS' thrusters
// Controls the direction and magnitude of our thrust (inputs)
// and monitors our rotational velocity and current direction
module thrusters(clk, rst, in);

	input clk, rst, in;				// These let the control FSM manage us
	wire [`SWIDTH-1:0] state, next;	// Our current state, and next cycle's state
	reg [`SWIDTH-1:0] next1;
	real velocity = 0;			// Our rotational velocity
	real angle = 0;		// Our solar panels' current rotation
	real thrust = 100;				// Our current Thrust
	reg [1:0] direction = 2'b00;	// Our thrusters current direction (e.g. CW)

	parameter id = 2'b01;			// The ID to use to refer to this component
	
	// This flips our state from the current state to the next
  	DFF #(`SWIDTH) state_reg(clk, next, state) ;

  	// Send message to client initializing this component
  	initial begin
  		$display("init %b %f %f %f %b",
			id,			// %b
			angle, 		// %f
			velocity, 	// %f
			thrust,		// %f
			direction);	// %b
  		$fflush;
  	end

  	// Updates a binary value when called by the io module
  	task update_binary;
  		input integer index;	// Which value to update
  		input reg[63:0] value;	// New value
  		begin
  			case (index)
  				3: direction = value;
  			endcase
			update();			// Send update message to client
  		end
  	endtask

  	// Updates a float value when called by the io module
	task update_float;
		input integer index;	// Which value to update
		input real value;		// New value
		begin
			case (index)
				0: angle = value;
				1: velocity = value;
				2: thrust = value;
			endcase
			update();			// Send update message to client
		end
	endtask

	// Sends a message to the client with all of our current values
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

	always @(posedge clk) begin
		case(state)
		// no concatenation here, because that don't support reals as operands
			`S2_OFF: begin
				// Component is off, so thrust is 0
				thrust = 0;
				
				angle = (angle + velocity) % 6.28318530718;
				// Next state is dependent on whether we've been enabled or not
				next1 = in ? `S2_NOGO : `S2_OFF;
			end
			`S2_NOGO: begin
				// Going neither clockwise, nor countclockwise so thrust is 0
				thrust = 0;
				
				angle = (angle + velocity) % 6.28318530718;
				
				if(direction == 2'b00) // Move this into a function or rewrite in some way?
					next1 = `S2_NOGO;
				else if(direction == 2'b01)
					next1 = `S2_CW;
				else
					next1 = `S2_CCW;
			end
			`S2_CW: begin
				// Thrust is in Clockwise direction, add thrust to velocity
				velocity = velocity + thrust;
				
				angle = (angle + velocity) % 6.28318530718;	
				
				if(direction == 2'b00)
					next1 = `S2_NOGO;
				else if(direction == 2'b01)
					next1 = `S2_CW;
				else
					next1 = `S2_CCW;
			end
			`S2_CCW: begin
				// Thrust is in Counter-clockwise direction, subtract thrust from velocity
				velocity = velocity - thrust;
				
				angle = (angle + velocity) % 6.28318530718;	
				
				if(direction == 2'b00)
					next1 = `S2_NOGO;
				else if(direction == 2'b01)
					next1 = `S2_CW;
				else
					next1 = `S2_CCW;
			end
		endcase
		update();	// Send update message to client
	end
	
	assign next = rst ? `S2_OFF : next1 ;
	
endmodule

// Component in charge of the solar panels
// Monitors whether the sun is visible or blocked (inputs),
// and angles the solar panels accordingly (also monitors power gen) (outputs)
module solar(clk, rst, in);

	input clk, rst, in;				// These let the control FSM manage us
	wire [`SWIDTH-1:0] state, next;	// Our current state, and next cycle's state
	reg [`SWIDTH-1:0] next1;		// The state we want to go to next cycle

	wire [4:0] sun;					// Timer for whether we can see the sun
	real angle = 1.57079632679;		// Our solar panels' current rotation
	real power = 0;					// How much power is being generated

	parameter id = 2'b10;			// The ID to use to refer to this component
	parameter ANGLE_DELTA = 0.23456789;	// Solar panels' rotation/cycle
	parameter POWER_CONSTANT = 120;		// How much our solar panels generate

	// This flips our state from the current state to the next
  	DFF #(`SWIDTH) state_reg(clk, next, state) ;

  	// Constantly ticks up, represents time passing
  	Counter sun_timer(clk, rst | !in, sun) ;

	// Send message to client initializing this component
  	initial begin
  		$display("init %b %f %f %b",
			id,		// %b
			angle, 	// %f
			power, 	// %f
			sun);	// %b
  		$fflush;
  	end

	// Updates a binary value when called by the io module
  	task update_binary;
  		input integer index;	// Which value to update
  		input reg[63:0] value;	// New value
  		begin
  			// No binary registers in this component!
  		end
  	endtask

  	// Updates a binary value when called by the io module
	task update_float;
		input integer index;	// Which value to update
		input real value;		// New value
		begin
			case (index)
				0: angle = value;
				1: power = value;
			endcase
			update();			// Send update message to client
		end
	endtask

	// Sends a message to the client with all of our current values
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

	// The actual state machine
	// Each cycle it performs this state's actions
	always @(posedge clk) begin
		case(state)
		// no concatenation here, because that don't support reals as operands
			`S_OFF: begin
				// Component is off, so reset our solar panels' angle
				angle = 1.57079632679;	// Half PI
				// Component is off, so we can't generate power
				power = 0;
				// Next state is dependent on whether we've been enabled or not
				next1 = in ? `S_A : `S_OFF;
			end
			`S_A: begin
				// Increment our angle so we'll be facing the sun
				// once we can see it again
				angle = (angle + ANGLE_DELTA) % 6.28318530718;
				// We can't see the sun, so we don't generate any power
				power = 0;
				// Next state is dependent on whether we can see the sun
				next1 = sun[4:4] ? `S_B : `S_A;
			end
			`S_B: begin
				// Decrement our angle to continue facing directly at the sun
				// as we rotate around the earth
				angle = (angle - ANGLE_DELTA) % 6.28318530718;
				// We can see the sun, so we generate full power
				power = POWER_CONSTANT;
				// Next state is dependent on whether we can see the sun
				next1 = sun[4:4] ? `S_B : `S_A;
			end
		endcase
		update();	// Send update message to client
	end

	// When rst is true, go to the off state no matter
	// what state our FSM told us to go to
	assign next = rst ? `S_OFF : next1 ;

endmodule

// -----------------------------------------------------------------------------
// UTILITY
// -----------------------------------------------------------------------------

// D Flip Flop
module DFF(clk, in, out);

	parameter n=1;
	input clk;
	input[n-1:0] in;
	output[n-1:0] out;
	reg[n-1:0] out;

	always @(negedge clk)
		out = in;

endmodule

// Non-Saturated Counter
module Counter(clk, rst, out) ;

	parameter n=5 ;		// Count of 0 to 31
	input rst, clk ; 	// reset and clock
	output [n-1:0] out ;
	wire [n-1:0] next = rst? 0 : out+1 ;

	DFF #(n) count(clk, next, out) ;

endmodule
