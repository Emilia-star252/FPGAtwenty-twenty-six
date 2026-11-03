
module Concat_6a1244b0da87#(
    parameter   PORT_NUM    = 1,
    parameter   IN_WIDTH_0  = 1,

    parameter   IN_WIDTH_1  = 1,

    parameter   IN_WIDTH_2  = 1,

    parameter   IN_WIDTH_3  = 1,

    parameter   OUT_WIDTH        =  32
)
(
    input  wire  [IN_WIDTH_0-1 : 0]     In0,

    input  wire  [IN_WIDTH_1-1 : 0]     In1,

    input  wire  [IN_WIDTH_2-1 : 0]     In2,

    input  wire  [IN_WIDTH_3-1 : 0]     In3,

    output wire  [OUT_WIDTH-1 : 0]      Dout

);
    assign  Dout = {
         
            In3, 
         
            In2, 
         
            In1, 
         
            In0
        };

endmodule
