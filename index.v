`timescale 1ns / 100ps

// FSM stuff
`define SWIDTH 2
`define S_OFF 3'b00
`define S_A   3'b01
`define S_B   3'b10
`define S_C   3'b11

// Defining our components' parts' positions on their bus
`define WIDTH 227
`define id 1:0 // 2 bits for component id (max components: 4)
`define type 3:2 // 2 bits for component type: 
				 // [Airflow Control, Thrusters Control, Solar Panel Control]
`define float1 67:4 // First data float (IEEE Standard)
`define float2 131:68 // Second data float
`define float3 195:132 // Third data float
`define extra 226:195 // Any extra data needed by the component (32 bits)

// Extra information for Airflow Control
// float1 is current oxygen supply (of 256)
// float2 is ignored
// float3 is ignored
`define rooms 226:223 // Which rooms have open vents (4 booleans - in a RAM)
`define alert 222:222 // Whether or not we're sending an alert to the client

// Extra information for Thrusters Control
// float1 is current ISS angle
// float2 is current ISS rotational velocity
// float3 is current thruster... thrust (independent from direction, think
// of direction as a modifier)
`define direction 226:225 // Thruster states: [CW, OFF, CCW]

// Extra information for Solar Panel Control
// float1 is current solar panel angle
// float2 is current solar panel energy output
// float3 is ignored
`define sun 226:226

module components;
	
	reg[`WIDTH-1:0] comp1;
	reg[`WIDTH-1:0] comp2;
	reg[`WIDTH-1:0] comp3;

	// Sends "init" stdout message for a given component
	task init;
		input [`WIDTH-1:0] in;
		begin
			$display("init %b %b %f %f %f %b", 
				in[`id],                    // %b
				in[`type],                  // %b
				$bitstoreal(in[`float1]),   // %f
				$bitstoreal(in[`float2]),   // %f
				$bitstoreal(in[`float3]),   // %f
				in[`extra]);                // %b
			$fflush;
		end
	endtask

	initial begin
		// Thrusters Control Unit
		comp1[`id] = 2'b00;
		comp1[`type] = 2'b00;
		comp1[`rooms] = 4'b1101;
		comp1[`alert] = 1'b0;
		comp1[`float1] = $realtobits(198);
		init(comp1);

		// Thrusters Control Unit
		comp2[`id] = 2'b01;
		comp2[`type] = 2'b01;
		comp2[`direction] = 2'b00;
		comp2[`float1] = $realtobits(1.57);
		comp2[`float2] = $realtobits(3.14);
		comp2[`float3] = $realtobits(100);
		init(comp2);

		// Solar Panel Control Unit
		comp3[`id] = 2'b10;
		comp3[`type] = 2'b10;
		comp3[`sun] = 1'b1;
		comp3[`float1] = $realtobits(1.57);
		comp3[`float2] = $realtobits(120);
		init(comp3);
	end

endmodule

module io;

	parameter clk_per = 10;
	parameter STDIN = 32'h8000_0000;

	// TODO this is very specific to the command being "WRITE_DATA".
	// Find a way to generalize it for any command
	reg[10*8:0] command; // 10 length string
	reg[1:0] id; // id of component to perform actions on
	integer right; // LSB index
	integer width;
	integer i;
	reg[31:0] value;
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
			"e":	// Write Extra
				begin
					c = $fgetc(STDIN); // Dump space character
					r = $fscanf(STDIN, "%b %d %d %b", id, right, width, value);
					if (components.comp1[`id] == id) begin
						for (i = 0; i < width; i++)
							components.comp1[right - i] = value[width - 1 - i];
						$display("update_extra %b %d %d %b", 
							id, 						// %b
							right, 						// %d
							width, 						// %d
							components.comp1[`extra]);	// %b
					end else if (components.comp2[`id] == id) begin
						for (i = 0; i < width; i++) 
							components.comp2[right - i] = value[width - 1 - i];
						$display("update_extra %b %d %d %b", 
							id, 						// %b
							right, 						// %d
							width, 						// %d
							components.comp2[`extra]);	// %b
					end else if (components.comp3[`id] == id) begin
						for (i = 0; i < width; i++) 
							components.comp3[right - i] = value[width - 1 - i];
						$display("update_extra %b %d %d %b", 
							id, 						// %b
							right, 						// %d
							width, 						// %d
							components.comp3[`extra]);	// %b
					end
					$fflush;
				end
			"f":	// Write Float
				begin
					c = $fgetc(STDIN); // Dump space character
					r = $fscanf(STDIN, "%b %d %d", id, right, value);
					if (components.comp1[`id] == id)
						begin
							case (right)
							1:
								components.comp1[`float1] = $realtobits(value);
							2:
								components.comp1[`float2] = $realtobits(value);
							3:
								components.comp1[`float3] = $realtobits(value);
							endcase
						end
					else if (components.comp2[`id] == id)
						begin
							case (right)
							1:
								components.comp2[`float1] = $realtobits(value);
							2:
								components.comp2[`float2] = $realtobits(value);
							3:
								components.comp2[`float3] = $realtobits(value);
							endcase
						end
					else if (components.comp3[`id] == id)
						begin
							case (right)
							1:
								components.comp3[`float1] = $realtobits(value);
							2:
								components.comp3[`float2] = $realtobits(value);
							3:
								components.comp3[`float3] = $realtobits(value);
							endcase
						end
					$display("update_float %b %d %d", id, right, value);
					$fflush;
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

module control;

	reg rst;	// Whether or not to reset everything
	reg solar;	// Whether our solar component is online

	// Notice we don't pass anything to it from the solar component
	// in the components module. That's because of how verilog
	// works. So my ideas of divorcing the logic from the data
	// ended up not really succeeding, because now each logic
	// module is hardcoded to its own data. Ah well, it would
	// tke too long to refactor all that at this point
	solar solarComp(io.tick, rst, solar);

	initial begin // Start up all our components
		solar = 1'b1;
	end

	//always @ (posedge io.tick) begin
		//components.comp3[`sun] = ~components.comp3[`sun];
	//end

endmodule

module solar(clk, rst, in);
	input clk, rst, in;
	wire [`SWIDTH-1:0] state, next;
	reg [`SWIDTH-1:0] next1;

	parameter ANGLE_DELTA = 1.57;

  	DFF #(`SWIDTH) state_reg(clk, next, state) ;

  	// TODO (ethan): instantiate a counter here 
  	// and use it instead of that always block in control
  	// that constantly flips sun

	always @(posedge io.tick) begin
		case(state)
			`S_OFF: {components.comp3[`float1], 
				components.comp2[`float1], 
				next1} =
					{components.comp3[`float1], 
						$realtobits(0), 
						in ? `S_A : `S_OFF};
			`S_A: {components.comp3[`float1], 
				components.comp3[`float2], 
				next1} =
				  {$realtobits($bitstoreal(components.comp3[`float1])
				   + ANGLE_DELTA), 
				   $realtobits(0), 
				   components.comp3[`sun] ? `S_B : `S_A};
			`S_B: {components.comp3[`float1], 
				components.comp3[`float2], 
				next1} =
				  {$realtobits($bitstoreal(components.comp3[`float1])
				   - ANGLE_DELTA), 
				   $realtobits(120), 
				   components.comp3[`sun] ? `S_B : `S_A};
		endcase
		$display("update_extra %b %d %d %b", 
			components.comp3[`id], 						// %b
			8'd226, 									// %d
			1'd1, 										// %d
			components.comp3[`extra]);					// %b
		$display("update_float %b %d %d", 
			components.comp3[`id], 						// %b
			2'd1, 										// %d
			$bitstoreal(components.comp3[`float1]));	// %d
		$display("update_float %b %d %d", 
			components.comp3[`id], 						// %b
			2'd2, 										// %d
			$bitstoreal(components.comp3[`float2]));	// %d
		$fflush;
	end

	assign next = rst ? `S_OFF : next1 ;

endmodule

module DFF(clk, in, out);

	parameter n=1;
	input clk;
	input[n-1:0] in;
	output[n-1:0] out;
	reg[n-1:0] out;

	always @(posedge clk)
		out = in;

endmodule
