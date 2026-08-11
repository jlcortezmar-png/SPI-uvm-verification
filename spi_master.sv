interface spi_master_if;
    logic clk;
    logic rst;
    logic newd;
    logic [7:0] din;

    logic sclk = 1'b0;
    logic mosi;
    logic cs;
endinterface


module spi_master(spi_master_if vif);
    int count;
    int count_bits;
    bit [7:0] temp;
    typedef enum bit [1:0] {idle = 2'b00, enable = 2'b01, send = 2'b10, comp = 2'b11} state_type;
    state_type state = idle;

    always_ff @(posedge vif.clk) begin
        if(vif.rst) begin
            vif.sclk <= 1'b0;
            count <= 0;
        end else if(count == 10) begin
            vif.sclk <= ~vif.sclk;
            count <= 0;
        end else
            count <= count + 1;
    end

    always_ff @(posedge vif.sclk or posedge vif.rst) begin
        if(vif.rst) begin
            state <= idle;
            vif.cs <= 1'b1;
            vif.mosi <= 1'b0;
        end else begin
            case (state)
                idle: begin
                    if(vif.newd) begin
                        temp <= vif.din;
                        state <= enable;
                    end
                end

                enable: begin
                    vif.cs <= 1'b0;
                    state <= send;
                end

                send: begin
                    if(count_bits != 8) begin
                        vif.mosi <= temp[count_bits];
                        count_bits <= count_bits + 1;
                    end else begin
                        count_bits <= 0;
                        state <= comp;
                    end
                end

                comp: begin
                    vif.cs <= 1'b1;
                    vif.mosi <= 1'b0;
                    state <= idle;
                end
            endcase
        end
    end

endmodule