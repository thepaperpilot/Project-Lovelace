`timescale 1ns / 100ps

// Defining our components' parts' positions on their bus
`define WIDTH 227
`define id 1:0 // 2 bits for component id (max components: 4)
`define type 3:2 // 2 bits for component type: 
				 // [Airflow Control, Thrusters Control, Solar Panel Control]
`define float1 67:4 // First data float
`define float2 131:68 // Second data float
`define float3 195:132 // Third data float
`define extra 226:195 // Any other information needed by the component (32 bits)

// Extra information for Solar Panel Control
// float1 is current solar panel angle
// float2 is current solar panel energy output
// float3 is ignored
`define sun 226:226 // whether the sun is visible

module components;
	
	reg[`WIDTH-1:0] comp0;

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

	initial
		begin
			// Solar Panel Control Unit
			comp0[`id] = 2'b00;
			comp0[`type] = 2'b10;
			comp0[`sun] = 1'b1;
			comp0[`float1] = $realtobits(1.57);
			comp0[`float2] = $realtobits(120);
			init(comp0);
		end

endmodule

module io;

	parameter clk_per = 10;
	parameter STDIN = 32'h8000_0000;

	// TODO this is very specific to the command being "WRITE_DATA".
	// Find a way to generalize it for any command
	reg[10*8:0] command; // 10 length string
	reg[2:0] id; // id of component to perform actions on
	integer right; // LSB index
	integer width;
	integer i;
	reg[31:0] value;
	integer c,r;
	reg CLK;	// Pretend this is private- don't use it!
	reg tick;	// Use this one. It ticks based on the server 

	// This creates our clock. CLK will get inverted every (clk_per/2) clock cycles
	initial
		begin
			CLK = 0;
			tick = 0;
			forever
			#(clk_per/2) CLK = ~CLK;
		end

	// This triggers whenever the clock ticks over to negative
	always @ (negedge CLK)
		// Check if we're at the end of file
		if (!$feof(STDIN))
			begin
				// Read the next command
				c = $fgetc(STDIN);
				case (c)
				"e":	// Write Extra
					begin
						r = $fscanf(STDIN, "%b %d %d %b", id, right, width, value);
						if (components.comp0[`id] == id)
							for (i = 0; i < width; i++)
								components.comp0[right - i] = value[width - 1 - i];
						//else if (components.component1[`id] == id)
						//	for (i = 0; i < width; i++) 
						//		components.component1[right - i] = value[width - 1 - i];
						$display("update_extra %b %d %d %b", id, right, width, value);
						$fflush;
					end
				"f":	// Write Float
					begin
						r = $fscanf(STDIN, "%b %d %d", id, right, value);
						if (components.comp0[`id] == id)
							begin
								case (right)
								1:
									components.comp0[`float1] = $realtobits(value);
								2:
									components.comp0[`float2] = $realtobits(value);
								3:
									components.comp0[`float3] = $realtobits(value);
								endcase
							end
						$display("update_float %b %d %d", id, right, value);
						$fflush;
					end
				"t":	// Tick
					tick = ~tick;
				endcase
			end
		else
			$finish;
		
endmodule

module solar;

	// This triggers whenever the clock ticks over to negative
	always @ (posedge io.tick)
		begin
			components.comp0[`sun] = ~components.comp0[`sun];
			if (components.comp0[`sun])
				components.comp0[`float2] = $realtobits(120);
			else
				components.comp0[`float2] = $realtobits(0);
			$display("update_extra %b %d %d %b", components.comp0[`id], 8'd226, 1'd1, components.comp0[`sun]);
			$display("update_float %b %d %d", components.comp0[`id], 2'd2, $bitstoreal(components.comp0[`float2]));
			$fflush;
		end

endmodule
