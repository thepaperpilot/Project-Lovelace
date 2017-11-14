module DFF(clk,in,out);
  parameter n=1;//width
  input clk;
  input [n-1:0] in;
  output [n-1:0] out;
  reg [n-1:0] out;

  always @(posedge clk)
  out = in;
 endmodule

module Mux4(a3, a2, a1, a0, s, b) ;
  parameter k = 1 ;
  input [k-1:0] a3, a2, a1, a0 ;  // inputs
  input [3:0]   s ; // one-hot select
  output[k-1:0] b ;
   assign b = ({k{s[3]}} & a3) |
              ({k{s[2]}} & a2) |
              ({k{s[1]}} & a1) |
              ({k{s[0]}} & a0) ;
endmodule // Mux4


module Thrusters(clk, rst, up, down, thrust, velocity, angle) ;
  parameter n = 4 ;
  input clk, rst, up, down ;
  input [n-1:0] thrust ;
  output [n-1:0] velocity, angle;
  wire [n-1:0] nextVelocity, nextAngle, outpm1 ;

  DFF #(n) countVelocity(clk, nextVelocity, velocity) ;
  DFF #(n) countAngle(clk, nextAngle, angle) ;


  //assign outpm1 = velocity + {{n-1{down}},1'b1} ;//IF DOWN

  assign outpm1 = up ? velocity + thrust : velocity - thrust;

  Mux4 #(n) mux(velocity, thrust, outpm1,
		{n{1'b0}},//A ZERO
                {(~rst & ~up & ~down),//ALL OFF
                 (1'b0),//thrust
                 (~rst & (up | down)),//UP OR DOWN
                   rst}, //RESET
                  nextVelocity) ;//OUTPUT
  assign nextAngle = rst ? 4'b0000 : angle + nextVelocity;
endmodule

//==================================
module TestBench ;
  reg clk, rst, up, down ;
  parameter n=4;
  reg [n-1:0] thrust;
  wire [n-1:0] velocity, angle;


 Thrusters thruster(clk,rst,up,down,thrust,velocity,angle);


  initial begin
    clk = 1 ; #5 clk = 0 ;
	    $display("CW|CCW|Thrust|Velocity|Angle");
	    $display("--+---+------+--------|-----");
    forever
      begin
        $display(" %b|  %b|     %d|     %d|   %d",up,down,thrust,velocity,angle ) ;
        #5 clk = 1 ;

		#5 clk = 0 ;
      end
    end

  // input stimuli
  initial begin
    rst=0;up=0;down=0;thrust=4'b0000;
    #10 $display("RESET");
        rst = 1 ;up=0;down=0;thrust=4'b0011;
    #10 rst = 0 ;up=0;down=0;thrust=4'b0011;
    #10 rst = 0 ;up=1;down=0;thrust=4'b0011;
    #50 rst = 0 ;up=0;down=0;thrust=4'b0011;
    #10 rst = 0 ;up=0;down=1;thrust=4'b0011;
    #50 rst = 0 ;up=0;down=0;thrust=4'b0011;
    #50
    $stop;
  end
endmodule
