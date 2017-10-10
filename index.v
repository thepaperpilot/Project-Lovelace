`timescale 1ns / 100ps

module mytb;

	parameter clk_per = 10;
	parameter STDIN = 32'h8000_0000;

	integer tmp;
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
				tmp = $fgetc(STDIN);
				// This is where the logic goes!
				$display("%h", tmp);
				$fflush;
			end
		else
			$finish;

endmodule
