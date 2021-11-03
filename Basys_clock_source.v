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
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


//BCH to sevSeg module
module bcd_to_sevseg(BCD, segN);
input [3:0] BCD;
output [7:0] segN;

reg [7:0] segN;
//setting 7 segment values (G-A, active low) for each hexadecimal value 0-F
always @(BCD) begin
    if (BCD == 4'b0000) segN <= 7'b1000000;
    else if (BCD == 4'b0001) segN <= 7'b1111001;
    else if (BCD == 4'b0010) segN <= 7'b0100100;
    else if (BCD == 4'b0011) segN <= 7'b0110000;
    else if (BCD == 4'b0100) segN <= 7'b0011001;
    else if (BCD == 4'b0101) segN <= 7'b0010010;
    else if (BCD == 4'b0110) segN <= 7'b0000010;
    else if (BCD == 4'b0111) segN <= 7'b1111000;
    else if (BCD == 4'b1000) segN <= 7'b0000000;
    else if (BCD == 4'b1001) segN <= 7'b0010000;
    else segN <= 7'b1111111;
end
endmodule


//digital segment controller module which periodically refreshes to update the display
module dig_cont(clk, an);
input clk;
output [3:0] an;

reg [3:0] an;
reg [31:0] counter0 = 0;
reg [31:0] counter1 = 0;

parameter refresh_ms = 16; //value for refresh rate of each digit
parameter num_digits = 4; //number of digits in display
parameter rate = refresh_ms * 100000; //add *100,000 -------- 100,000,000 Mhz / 1,000 ms/s = 100,000

// resetting counter0 every refresh_ms, and counter1 every num_digits
always @(posedge (clk)) begin
    counter0 = counter0 + 1;
    if (counter0 >= (rate / num_digits)) begin    
        counter0 = 0;
        counter1 = counter1 + 1;
    end 
    if (counter1 >= (num_digits)) counter1 = 0;
end

//assigning AN value so only one digit is active low at a time
always @(posedge(clk)) begin
    if (counter1 == 0) an = 4'b0111;
    else if (counter1 == 1) an = 4'b1011;
    else if (counter1 == 2) an = 4'b1101;
    else if (counter1 == 3) an = 4'b1110;
    else an <= 4'b1111;
end
endmodule


//clock_divider inputs a 100Mhz clock and outputs a 1hz clock. 1 period = 1 second on the output.
module clock_divider(clk_100Mhz, clk_1hz);
input clk_100Mhz;
output clk_1hz;

reg [25:0] counter = 0;
reg clk_1hz = 0;

always @(posedge clk_100Mhz) begin
    counter <= counter + 1;
    if (counter >= 49999999) begin
        //49,999,999 outputs 1 second per second - use lower value for testing 
        //(499,999 gives 1 hour per 36 seconds)
        //(49,999 gives 1 hour per 3.6 seconds)
        counter <= 0;
        clk_1hz <= !clk_1hz;
    end
end
endmodule


//clock_module creates a 12-hour, 60 minute counter for each clock position; 2 digits for minutes, 2 for hours. 
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
wire c0; //divider output for 1 second clock signal
reg [8:0] sm = 0; // seconds counter


clock_divider (clk, c0);
always @(posedge c0) begin
    sm <= sm + 1;
    if (sm == 59) begin //resets seconds after 59 seconds
        sm <= 0;
        BCD0 <= BCD0 + 1;
        if (BCD0 == 9) begin //first minute digit
            BCD0 <= 0;
            BCD1 <= BCD1 + 1;
            if (BCD1 == 5) begin //second minute digit
                BCD1 <= 0;
                BCD2 <= BCD2 + 1;
                if (BCD2 == 9) begin //first hour digit
                    BCD2 <= 0;
                    BCD3 <= BCD3 + 1;
                end 
                else if ((BCD3 == 1) && (BCD2 == 2)) begin  
                    //for 24-hour clock change above "else if" to ((BCD3 == 2) && (BCD2 == 3))
                    BCD2 <= 1; // for 24-hour clock change this line to (BCD2 <= 0)
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

//creating BCD0-3 for tracking each digit
wire [3:0] BCD0;
wire [3:0] BCD1;
wire [3:0] BCD2;
wire [3:0] BCD3;
clock_mod (CLK, BCD0, BCD1, BCD2, BCD3);

wire [7:0] SEGN; //creating the 7 segment array plus the decimal point
reg [3:0] BCD;
reg segn = 1; //creating a register and setting initial value to 1 to write into SEGN[7] 
wire w1; //for obtaining second value
assign SEGN[7] = segn; //assigning 1 second period to SEGN at the decimal point

clock_divider (CLK, w1); //obtaining a 1 second clock to use on digit 0 decimal point

dig_cont (CLK, AN); //obtaining the cycling AN value for refreshing display
bcd_to_sevseg (BCD, SEGN[6:0]); //obtaining each BCD value, and only assigning to main 7 segments not decimal point

//assigning BCD0-3 to BCD according to current AN value
always @(posedge CLK) begin
    if (AN == 4'b1110) begin
        BCD <= BCD0;
    end else if (AN == 4'b1101) begin
        BCD <= BCD1;
    end else if (AN == 4'b1011) begin
        BCD <= BCD2;
    end else if (AN == 4'b0111) begin
        BCD <= BCD3;
    end else;
end

//assigning segn value to 1 second clock only if writing to the last digit on the display
always @(posedge CLK) begin
    if (AN == 4'b1110) begin
      segn <= !w1;
    end else segn <= 1;
end
endmodule


//Basys-3 implementation
module basys_clock(clk, an, seg);
input clk;
output [7:0] seg;
output [3:0] an;

bcd_seg_complete(clk, an, seg);

endmodule
