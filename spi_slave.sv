interface spi_slave_if;
    logic sclk;
    logic cs;
    logic mosi;

    logic [7:0] dout;
    logic done;
endinterface


module spi_slave(spi_slave_if vif);
    typedef enum bit {start = 1'b0, read = 1'b1} state_type;
    state_type state = start;
    bit [7:0] mem = 8'b00000000;
    int count_bits = 0;

    always_ff @(posedge vif.sclk) begin
        case (state)
            start: begin
                vif.done <= 1'b0;
                if (vif.cs == 1'b0)
                    state <= read;
                else
                    state <= start;
            end

            read: begin
                if(count_bits < 8) begin
                    count_bits <= count_bits + 1;
                    mem <= {vif.mosi, mem[7:1]};
                end
                else begin
                    count_bits <= 0;
                    vif.done <= 1'b1;
                    state <= start;
                end
            end
        endcase
    end

    assign vif.dout = mem;
endmodule