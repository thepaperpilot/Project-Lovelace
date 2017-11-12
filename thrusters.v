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


module Thrusters(clk, rst, up, down, thrust, out) ;
  parameter n = 4 ;
  input clk, rst, up, down ;
  input [n-1:0] thrust ;
  output [n-1:0] out ;
  wire [n-1:0] next, outpm1 ;

  DFF #(n) count(clk, next, out) ;


  //assign outpm1 = out + {{n-1{down}},1'b1} ;//IF DOWN

  assign outpm1 = up ? out + thrust : out - thrust;

  Mux4 #(n) mux(out, thrust, outpm1,
		{n{1'b0}},//A ZERO
                {(~rst & ~up & ~down),//ALL OFF
                 (1'b0),//thrust
                 (~rst & (up | down)),//UP OR DOWN
                   rst}, //RESET
                  next) ;//OUTPUT
endmodule

//==================================
module TestBench ;
  reg clk, rst, up, down ;
  parameter n=4;
  reg [n-1:0] thrust;
  wire [n-1:0] out;


 Thrusters thruster(clk,rst,up,down,thrust,out);


  initial begin
    clk = 1 ; #5 clk = 0 ;
	    $display("CW|CCW|Thrust|Velocity");
	    $display("--+---+------+--------");
    forever
      begin
        $display(" %b|  %b|     %d|     %d",up,down,thrust,out ) ;
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
