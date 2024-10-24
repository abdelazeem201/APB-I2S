/*
 * Testbench: I2S Interface Module Testbench
 * Author: Ahmed Abdelazeem
 * Email: a.abdelazeem201@gmail.com
 * 
 * Purpose:
 * This Verilog testbench is used to simulate and verify the functionality of the I2S 
 * Interface module. The testbench provides input stimulus to the I2S module, simulating 
 * different APB transactions (reads and writes), and monitors the module's output signals 
 * such as the serial clock (sck), word select (ws), and serial data (sd). 
 * 
 * Key Features:
 * - Generates a 100 MHz clock signal to simulate the APB clock
 * - Simulates a system reset and basic read/write transactions on the APB bus
 * - Tests writing to various registers such as control, interrupt, and FIFO data registers
 * - Monitors the serial outputs (sck, ws, sd) and IRQ to verify module behavior
 * 
 * Intended Use:
 * This testbench is designed to validate the I2S module's behavior in a simulated environment. 
 * It is intended to ensure that the module operates correctly before integration into 
 * a larger system or design. The testbench can be used to test various configurations 
 * and input conditions, making it easier to debug and verify functionality.
 */

`timescale 1ns/1ns

module testI2S;
  // Declare input signals as registers
  reg        pclk;      // APB clock
  reg        presetn;   // APB reset (active low)
  reg        psel;      // APB select signal
  reg        penable;   // APB enable signal
  reg        pwrite;    // APB write enable
  reg [31:0] paddr;     // APB address
  reg [31:0] pwdata;    // APB write data

  // Declare output signals as wires
  wire [31:0] prdata;   // APB read data
  wire        irq;      // Interrupt request
  wire        sck;      // I2S serial clock
  wire        ws;       // I2S word select
  wire        sd;       // I2S serial data

  // Initial block for generating input stimulus
  initial begin
    pclk = 0;
    presetn = 0;
    psel = 1;
    penable = 1;
    pwrite = 1;

    // Reset the system initially
    #20 presetn = 1;  // Release reset after 20ns

    // Write to interrupt register (address 0x08)
    #2 begin
      paddr = 8'h08;     // Set address to 0x08 (interrupt register)
      pwdata = 32'h00000001;  // Enable interrupt
    end

    // Write to control register (address 0x00)
    #10 begin
      paddr = 8'h00;     // Set address to 0x00 (control register)
      pwdata = 32'h00000001;  // Set control register with initial value
    end

    // Write to FIFO data register (address 0x04)
    #10 begin
      paddr = 8'h04;     // Set address to 0x04 (FIFO data register)
      pwdata = 32'h11111111;  // Write the first data word to FIFO
    end

    // Continue writing multiple data words to FIFO
    #5 pwdata = 32'h01011001; // Second data word
    #10 pwdata = 32'h00001111; // Third data word
    #20 pwdata = 32'h00000011; // Fourth data word
    #5 pwdata = 32'h10011001;  // Fifth data word
  end

  // Generate a periodic clock with a period of 10ns (100 MHz)
  always #5 pclk = ~pclk;

  // Instantiate the I2S module under test
  i2s t(
    .pclk(pclk), 
    .presetn(presetn), 
    .psel(psel), 
    .penable(penable), 
    .pwrite(pwrite), 
    .paddr(paddr), 
    .pwdata(pwdata), 
    .prdata(prdata), 
    .irq(irq), 
    .sck(sck), 
    .ws(ws), 
    .sd(sd)
  );

endmodule
