/*
 * Project: I2S Interface Module
 * Author: Ahmed Abdelazeem
 * Email: a.abdelazeem201@gmail.com
 * 
 * Purpose:
 * This Verilog module implements an I2S (Inter-IC Sound) interface to facilitate 
 * serial communication for audio data transmission. The design integrates an 
 * APB (Advanced Peripheral Bus) interface, allowing a processor to interact 
 * with the I2S peripheral by reading and writing control, data, and interrupt 
 * registers. The module also includes an internal FIFO buffer for data storage 
 * and management during serial transfer.
 * 
 * Key Features:
 * - APB Interface for processor communication (control, data, and interrupt handling)
 * - Serial clock generation with adjustable frequency via a programmable divider
 * - Word select signal to alternate between left and right audio channels
 * - FIFO memory for buffering audio data before transmission
 * - IRQ (Interrupt Request) generation based on FIFO full/empty conditions
 * 
 * Enhancements for Reusability and Maintenance:
 * - Separation of control and data flow, making the design modular and easier to extend
 * - Frequency divider made programmable to support various audio data rates
 * - Configurable FIFO depth for flexible buffer sizing
 * - Clear APB address map for ease of integration and future expansion
 * 
 * Intended Use:
 * This module is designed for audio applications where a processor needs to send or 
 * receive audio data via I2S, typically used in embedded systems such as microcontrollers 
 * or SoCs interfacing with digital-to-analog converters (DACs), codecs, or other 
 * audio processing devices.
 */


module i2s (
  input        pclk,     // APB clock
  input        presetn,  // APB reset (active low)
  input        psel,     // APB select signal
  input        penable,  // APB enable signal
  input        pwrite,   // APB write enable
  input  [7:0] paddr,    // APB address bus
  input [31:0] pwdata,   // APB write data bus
  output [31:0] prdata,  // APB read data bus
  output       irq,      // Interrupt request output
  output       sck,      // I2S serial clock
  output       ws,       // I2S word select (left/right channel)
  output       sd        // I2S serial data output
);

  // Internal register declarations
  reg [31:0] reg_prdata;      // APB read data register
  reg        irq;             // Interrupt request signal
  reg [31:0] control_reg;     // Control register
  reg [31:0] interrupt_reg;   // Interrupt configuration register
  reg [31:0] state_reg;       // State register
  reg [31:0] data_reg;        // Data register

  reg        sck_reg;         // I2S serial clock signal
  reg        ws_reg;          // I2S word select signal
  reg [31:0] data_fifo;       // Data loaded from FIFO for transmission

  reg [7:0]  div;             // Clock division factor
  reg [7:0]  clk_count;       // Clock division counter
  reg [4:0]  ws_count;        // Word select bit counter
  reg [4:0]  bit_count;       // Data bit counter for serial data

  // FIFO memory and control signals
  reg [31:0] mem[3:0];        // 4x32-bit FIFO memory
  reg [2:0]  wr_ptr, rd_ptr;  // Write and read pointers
  wire       fifo_wr_en;      // FIFO write enable
  wire       fifo_full, fifo_empty;  // FIFO full and empty flags

  // APB control signals
  reg wr_en, rd_en;           // Write and read enable signals for APB

  // APB read data output assignment
  assign prdata = rd_en ? reg_prdata : 32'b0;

  // FIFO control signals
  assign fifo_wr_en = (wr_en && paddr == 8'h04);  // Write data to FIFO on address 0x04
  assign fifo_full  = (wr_ptr == {~rd_ptr[2], rd_ptr[1:0]});  // Full when write and read pointers differ only in MSB
  assign fifo_empty = (wr_ptr == rd_ptr);                     // Empty when write and read pointers are equal

  // APB write/read control
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      wr_en <= 0;
      rd_en <= 0;
    end else if (psel && penable) begin
      if (pwrite) begin
        wr_en <= 1;  // Enable write
        rd_en <= 0;
      end else begin
        rd_en <= 1;  // Enable read
        wr_en <= 0;
      end
    end else begin
      wr_en <= 0;
      rd_en <= 0;
    end
  end

  // APB register access
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      control_reg   <= 32'h00000022;
      interrupt_reg <= 32'h00000000;
      state_reg     <= 32'h00000001;
      data_reg      <= 32'h10101010;
      reg_prdata    <= 32'h00000000;
    end else if (wr_en) begin  // Write operation
      case (paddr)
        8'h00: begin
          control_reg <= pwdata;  // Control register
          div <= pwdata[7:0];     // Clock division factor
        end
        8'h04: data_reg <= pwdata;  // Data register
        8'h08: interrupt_reg <= pwdata;  // Interrupt configuration
        default: state_reg <= state_reg;
      endcase
    end else if (rd_en) begin  // Read operation
      case (paddr)
        8'h00: reg_prdata <= control_reg;  // Read control register
        8'h08: reg_prdata <= interrupt_reg;  // Read interrupt register
        8'h0C: reg_prdata <= state_reg;  // Read state register
        default: reg_prdata <= 32'b0;
      endcase
    end
  end

  // I2S clock generation (sck) with clock division
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      sck_reg <= 0;
      clk_count <= 0;
    end else if (clk_count < div) begin
      clk_count <= clk_count + 1;
      sck_reg <= 0;
    end else begin
      clk_count <= 0;
      sck_reg <= ~sck_reg;  // Toggle sck every div cycles
    end
  end
  assign sck = sck_reg;

  // I2S word select generation (ws), toggling every 16 bits
  always @(posedge sck or negedge presetn) begin
    if (!presetn) begin
      ws_reg <= 1;
      ws_count <= 0;
    end else if (ws_count < 31) begin
      ws_count <= ws_count + 1;
    end else begin
      ws_count <= 0;
      ws_reg <= ~ws_reg;  // Toggle ws every 32 clock cycles
    end
  end
  assign ws = ws_reg;

  // FIFO write operation
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      wr_ptr <= 0;
      // Initialize FIFO memory
      mem[0] <= 32'h0;
      mem[1] <= 32'h0;
      mem[2] <= 32'h0;
      mem[3] <= 32'h0;
    end else if (fifo_wr_en && !fifo_full) begin
      mem[wr_ptr[1:0]] <= data_reg;  // Write data to FIFO
      wr_ptr <= wr_ptr + 1;
    end
  end

  // FIFO read operation
  always @(posedge sck or negedge presetn) begin
    if (!presetn) begin
      rd_ptr <= 0;
      data_fifo <= 32'b0;
    end else if (!fifo_empty) begin
      data_fifo <= mem[rd_ptr[1:0]];  // Read data from FIFO
      rd_ptr <= rd_ptr + 1;
    end
  end

  // I2S serial data output (sd), sends 1 bit per sck cycle
  always @(posedge sck or negedge presetn) begin
    if (!presetn) begin
      bit_count <= 31;
    end else begin
      sd <= data_fifo[bit_count];  // Output data bit
      bit_count <= bit_count - 1;
    end
  end

  // IRQ generation based on FIFO state
  always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      irq <= 0;
    end else if (fifo_full && interrupt_reg[0]) begin
      irq <= 1;  // Trigger interrupt if FIFO is full and interrupts are enabled
    end else if (fifo_empty && interrupt_reg[0]) begin
      irq <= 1;  // Trigger interrupt if FIFO is empty and interrupts are enabled
    end else begin
      irq <= 0;
    end
  end

endmodule
