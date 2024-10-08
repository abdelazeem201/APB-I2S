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

  // Internal signal and register declarations
  reg [31:0] reg_prdata;   // Register to store read data
  reg        irq;          // Interrupt signal

  reg        ssck;         // Internal serial clock signal
  reg        wws;          // Internal word select signal
  reg [31:0] d;            // Data bit counter for serial data transfer

  // FIFO buffer: 4 words of 32 bits each (4x32-bit FIFO)
  reg [31:0] mem[3:0];     // FIFO memory
  reg [2:0]  p, q;         // FIFO read/write pointers

  wire wrmem_en;           // FIFO write enable
  wire full, empty;        // FIFO full and empty flags

  integer k;               // Iterator for initializing FIFO
  reg [31:0] data_fifo;    // Data loaded from FIFO for transmission
  reg [31:0] control, state, data, interrupt;  // Control, state, data, and interrupt registers
  reg [7:0]  div;          // Frequency division factor for clock generation
  reg [7:0]  i;            // Clock division counter
  reg [4:0]  j;            // Word select bit counter

  reg  wrn, rdn;           // Write and read enable signals

  // APB read data output assignment
  assign prdata = (rdn == 1) ? reg_prdata : 32'b0;

  // Write memory enable logic: enabled when writing to address 0x04
  assign wrmem_en = (wrn == 1 && paddr == 8'h04) ? 1 : 0;

  // Control logic to generate write (wrn) and read (rdn) enables
  always @(posedge pclk or negedge presetn)
  begin
    if (!presetn) begin
      wrn <= 0;
      rdn <= 0;
    end
    else if (psel) begin
      if (penable) begin
        if (pwrite) begin
          rdn <= 0;
          wrn <= 1;  // Write operation
        end
        else begin
          rdn <= 1;  // Read operation
          wrn <= 0;
        end
      end
      else begin
        wrn <= 0;
        rdn <= 0;
      end
    end
    else begin
      wrn <= 0;
      rdn <= 0;
    end
  end

  // Control and data register access via APB
  always @(posedge pclk or negedge presetn)
  begin
    if (!presetn) begin
      interrupt <= 32'h00000000;
      control   <= 32'h00000022;
      data      <= 32'h10101010;
      reg_prdata <= 32'h00000000;
    end
    else if (wrn) begin  // Write operation
      case (paddr)
        8'h00: begin
          control <= pwdata;  // Write to control register
          div <= pwdata[7:0]; // Set frequency division factor
        end
        8'h04: data <= pwdata;  // Write to data register
        8'h08: interrupt <= pwdata;  // Write to interrupt register
        default: state <= state;
      endcase
    end
    else if (rdn) begin  // Read operation
      case (paddr)
        8'h00: reg_prdata <= control;    // Read control register
        8'h08: reg_prdata <= interrupt;  // Read interrupt register
        8'h0c: reg_prdata <= state;      // Read state register
        default: data <= data;
      endcase
    end
  end

  // Generate serial clock (sck) with frequency division based on `div`
  always @(posedge pclk or negedge presetn)
  begin
    if (!presetn) begin
      ssck <= 0;
      i <= 0;
    end
    else begin
      if (i < (div + 1)) begin
        i <= i + 1;
        ssck <= 0;
      end
      else if (i < (2 * (div + 1) - 1)) begin
        i <= i + 1;
        ssck <= 1;
      end
      else if (i == (2 * (div + 1) - 1)) begin
        i <= 0;
        ssck <= 1;
      end
    end
  end
  assign sck = ssck;

  // Generate word select (ws) signal: toggles every 16 bits
  always @(posedge ssck or negedge presetn)
  begin
    if (!presetn) begin
      wws <= 1;
      j <= 0;
    end
    else begin
      if (j < 16) begin
        j <= j + 1;
        wws <= 0;
      end
      else if (j < 31) begin
        j <= j + 1;
        wws <= 1;
      end
      else begin
        wws <= 1;
        j <= 0;
      end
    end
  end
  assign ws = wws;

  // FIFO write operation
  always @(posedge pclk or negedge presetn)
  begin
    if (!presetn) begin
      for (k = 0; k < 4; k = k + 1) begin
        mem[k] <= 32'h00000000;  // Clear FIFO memory on reset
      end
      p <= 3'b000;
    end
    else if (wrmem_en && !full) begin
      mem[p[1:0]] <= data;  // Write data into FIFO
      p <= p + 1;
    end
  end

  // FIFO read operation (triggered by word select)
  always @(negedge wws or negedge presetn)
  begin
    if (!presetn) begin
      q <= 3'b000;
    end
    else if (!empty) begin
      data_fifo <= mem[q[1:0]];  // Read data from FIFO
      q <= q + 1;
    end
  end

  // FIFO full and empty flags
  assign full = (q == {~p[2], p[1:0]});  // FIFO is full when write and read pointers align but differ in MSB
  assign empty = (p == q);               // FIFO is empty when write and read pointers are equal

  // IRQ generation based on FIFO full/empty status
  always @(full or empty or presetn)
  begin
    if (!presetn) begin
      state <= 32'h00000001;  // Reset state
    end
    else begin
      if (full) begin
        state[2] <= 1;  // Indicate FIFO full
        state[0] <= 1;
        irq <= (interrupt[0] == 1) ? 1 : 0;  // Trigger IRQ if enabled in interrupt register
      end
      else if (empty) begin
        state[2] <= 0;  // Indicate FIFO empty
        state[0] <= 0;
        irq <= (interrupt[0] == 1) ? 1 : 0;  // Trigger IRQ if enabled
      end
      else begin
        state[2] <= 0;
        state[0] <= 1;
        irq <= 0;
      end
    end
  end

  // Serial data output generation
  always @(posedge ssck or negedge presetn)
  begin
    if (!presetn) begin
      d <= 31;
    end
    else begin
      sd <= data_fifo[d];  // Send one bit of data per clock
      d <= d - 1;
    end
  end

endmodule
