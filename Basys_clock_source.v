`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dunwoody College of Technology
// Engineer: Jacob Kearin
// 
// Create Date: 09/29/2021 12:03:54 PM
// Design Name: 12hr_clock
// Module Name: basys_clock
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Outputs a 12 hour clock using the 4-digit, 7-segment display built into the Basys-3 FPGA board. 
//              Seconds are indicated on the decimal point for the first digit.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//BCD to sevSeg module
module bcd_to_sevseg(BCD, segN);
input [3:0] BCD;
output [7:0] segN;

reg [7:0] segN;

always @(BCD)
begin
    if (BCD == 4'b0000)
        segN <= 7'b1000000;
    else if (BCD == 4'b0001)
        segN <= 7'b1111001;
    else if (BCD == 4'b0010)
        segN <= 7'b0100100;
    else if (BCD == 4'b0011)
        segN <= 7'b0110000;
    else if (BCD == 4'b0100)
        segN <= 7'b0011001;
    else if (BCD == 4'b0101)
        segN <= 7'b0010010;
    else if (BCD == 4'b0110)
        segN <= 7'b0000010;
    else if (BCD == 4'b0111)
        segN <= 7'b1111000;
    else if (BCD == 4'b1000)
        segN <= 7'b0000000;
    else if (BCD == 4'b1001)
        segN <= 7'b0010000;
    else
        segN <= 7'b1111111;
    end
endmodule


//digital segment controller module which periodically refreshes to update the display
module dig_cont(clk, an);
input clk;
output [3:0] an;
reg [3:0] an;
reg [31:0] counter0 = 0;
reg [31:0] counter1 = 0;

parameter refresh_ms = 16;
parameter num_digits = 4;
parameter rate = refresh_ms * 100000; //add *100,000 for 100,000,000 Mhz / 1,000 ms/s

always @(posedge (clk))
begin
    counter0 = counter0 + 1;
    if (counter0 >= (rate / num_digits))
    begin    
        counter0 = 0;
        counter1 = counter1 + 1;
    end    
    if (counter1 >= (num_digits))
        counter1 = 0;
end

always @(posedge(clk))
begin
    if (counter1 == 0)
            an = 4'b0111;
    else if (counter1 == 1)
            an = 4'b1011;
    else if (counter1 == 2)
            an = 4'b1101;
    else if (counter1 == 3)
            an = 4'b1110;
    else 
        an <= 4'b1111;
end
endmodule

//clock_divider inputs a 100Mhz clock and outputs a 1hz clock. 1 period = 1 second on the output.
module clock_divider(clk_100Mhz, clk_1hz);
input clk_100Mhz;
output clk_1hz;
reg [26:0] counter = 0;
reg clk_1hz = 0;

always @(posedge clk_100Mhz) begin
    counter <= counter + 1;
    if (counter >= 49999999) begin 
    //49,999,999 outputs 1 second per second - use lower value for testing (499,999 gives 1 hour per 36 seconds).
        counter <= 0;
        clk_1hz <= !clk_1hz;
        end
end
endmodule

module clock_mod(clk, BCD0, BCD1, BCD2, BCD3);
input clk;
output [3:0] BCD0;
output [3:0] BCD1;
output [3:0] BCD2;
output [3:0] BCD3;
reg [3:0] BCD0 = 0;
reg [3:0] BCD1 = 0;
reg [3:0] BCD2 = 2;
reg [3:0] BCD3 = 1;
wire c0;
reg s0 = 0;
reg s1 = 0;
reg s2 = 0;
reg [8:0] sm = 0;

clock_divider (clk, c0);
always @(posedge c0) begin
    sm <= sm + 1;
    if (sm == 59) begin
        sm <= 0;
        BCD0 <= BCD0 + 1;
        if (BCD0 == 9) begin
            BCD0 <= 0;
            BCD1 <= BCD1 + 1;
            if (BCD1 == 5) begin
                BCD1 <= 0;
                BCD2 <= BCD2 + 1;
                if (BCD2 == 9) begin
                    BCD2 <= 0;
                    BCD3 <= 1;
                end
                else if ((BCD3 == 1) && (BCD2 == 2)) begin
                    BCD2 <= 1;
                    BCD3 <= 0;
                end
            end
        end
    end
end
endmodule


//complete clock module
module bcd_seg_complete(CLK, AN, SEGN);
input CLK;
output [3:0] AN;
output [7:0] SEGN;

wire [3:0] BCD0;
wire [3:0] BCD1;
wire [3:0] BCD2;
wire [3:0] BCD3;
clock_mod (CLK, BCD0, BCD1, BCD2, BCD3);

wire [7:0] SEGN;
reg [3:0] BCD;
reg segn = 1;
wire w1;
assign SEGN[7] = segn;

clock_divider (CLK, w1);

dig_cont (CLK, AN);
bcd_to_sevseg (BCD, SEGN[6:0]);

always @(posedge CLK)
begin
    if (AN == 4'b1110) begin
        BCD <= BCD0;
        end
    else if (AN == 4'b1101) begin
        BCD <= BCD1;
        end
    else if (AN == 4'b1011) begin
        BCD <= BCD2;
        end
    else if (AN == 4'b0111) begin
        BCD <= BCD3;
        end
    else;
end
always @(posedge CLK) begin
    if (AN == 4'b1110) begin
      segn <= !w1;
    end
    else begin
      segn <= 1;
    end
end
endmodule


//Basys 3 FPGA implementation utilizing switches as inputs
module basys_clock(clk, an, seg);
input clk;
output [7:0] seg;
output [3:0] an;

bcd_seg_complete(clk, an, seg);

endmodule
