`timescale 1ns / 100ps

// Defining our components' parts' positions on their bus
`define WIDTH 230
`define id 2:0 // 3 bits for component id (max components: 8)
`define type 5:3 // 3 bits for component type: 
				 // [Fan, Boiler, Sensor, AC Unit, Condenser]
`define currTemp 69:6 // 64 bits for current component temperature in Celcius 
					  // (IEEE floating point)
`define extra 101:70 // Any other information needed by the component
`define name 16*8+101:102 // Enough bits for a 16 length string

// Extra information for Fans
`define on 101:101 // whether the fan is on
`define speed 100:99 // 2 bits for fan speed setting: 
					  // [Extra Low, Low, Medium, High]

module components;
	
	reg[`WIDTH-1:0] component0;
	reg[`WIDTH-1:0] component1;
	reg[`WIDTH-1:0] component2;
	reg[`WIDTH-1:0] component3;
	reg[`WIDTH-1:0] component4;

	// Sends "init" stdout message for a given component
	task init;
		input [`WIDTH-1:0] in;
		begin
			$display("init %b %b %f %b %s", 
				in[`id],                    // %b
				in[`type],                  // %b
				$bitstoreal(in[`currTemp]), // %f
				in[`extra],                 // %b
				in[`name]);                 // $s
			$fflush;
		end
	endtask

	initial
		begin
			component0[`id] = 3'b000;
			component0[`type] = 3'b000;
			component0[`currTemp] = $realtobits(27);
			component0[`on] = 1'b1;
			component0[`speed] = 2'b10;
			component0[`name] = "Downstairs Bath";
			init(component0);

			component1[`id] = 3'b001;
			component1[`type] = 3'b001;
			component1[`currTemp] = $realtobits(28);
			component1[`name] = "Basement";
			init(component1);

			component2[`id] = 3'b010;
			component2[`type] = 3'b010;
			component2[`currTemp] = $realtobits(28.5);
			component2[`name] = "Thermostat";
			init(component2);

			component3[`id] = 3'b011;
			component3[`type] = 3'b011;
			component3[`currTemp] = $realtobits(29);
			component3[`name] = "Lobby";
			init(component3);

			component4[`id] = 3'b100;
			component4[`type] = 3'b100;
			component4[`currTemp] = $realtobits(26);
			component4[`name] = "Outside";
			init(component4);
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
	integer r;
	reg CLK;

	// This creates our clock. CLK will get inverted every clk_per/2 (ms?)
	initial
		begin
			CLK = 0;
			forever
			#(clk_per/2) CLK = ~CLK;
		end

	// This triggers whenever the clock ticks over to negative
	always @ (negedge CLK)
		// Check if we're at the end of file
		if (!$feof(STDIN))
			begin
				// Read the next character from stdin
				r = $fscanf(STDIN, "%s %b %d %d %b", command, id, right, width, value);
				// This is where the logic goes!
				case (command)
				"WRITE_DATA":
					// TODO better way of doing this?
					// tasks don't work (won't change the component registers' bits)
					if (components.component0[`id] == id)
						for (i = 0; i < width; i++) 
						begin
							components.component0[right - i] = value[width - 1 - i];
							//$display("%d %b %b %b", right - i, components.component0[right - i], value[width - 1 - i], components.component0[`extra]);
						end
					else if (components.component1[`id] == id)
						for (i = 0; i < width; i++) 
							components.component1[right - i] = value[width - 1 - i];
					else if (components.component2[`id] == id)
						for (i = 0; i < width; i++) 
							components.component2[right - i] = value[width - 1 - i];
					else if (components.component3[`id] == id)
						for (i = 0; i < width; i++) 
							components.component3[right - i] = value[width - 1 - i];
					else if (components.component4[`id] == id)
						for (i = 0; i < width; i++) 
							components.component4[right - i] = value[width - 1 - i];
				endcase
				$display("update %b %d %d %b", id, right, width, value);
				$fflush;
			end
		else
			$finish;

endmodule
