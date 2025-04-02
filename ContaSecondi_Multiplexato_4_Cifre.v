module ContatoreSecondi(
    input wire clk,          // Clock principale del sistema (alta frequenza)
    input wire rst_n,        // Reset attivo basso
    output reg [3:0] digit_sel, // Selezione del display attivo (4 cifre)
    output reg [6:0] segment_out // Uscite per i segmenti del display (a-g)
);

    // Dichiarazioni interne (fili e registri)

    // 1. Generazione del segnale di conteggio dei millisecondi

    localparam CLK_FREQ = 100_000_000; // 100 MHz
    localparam MS_PERIOD = 1000;      // 1000 millisecondi in un secondo

    reg [31:0] clk_counter; //Controllare il numero di bit, può essere ridotto
    reg ms_tick;            //diventa '1' per un ciclo di clock ogni millisecondo

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= 32'b0;
            ms_tick <= 1'b0;
        end else begin
            if (clk_counter == (CLK_FREQ / MS_PERIOD) - 1) begin
                clk_counter <= 32'b0;
                ms_tick <= 1'b1; // Impulso di 1 millisecondo
            end else begin
                clk_counter <= clk_counter + 1'b1;
                ms_tick <= 1'b0;
            end
        end
    end

    // 2. Logica di conteggio 

    reg [9:0] milliseconds; // Conta da 0 a 999 -> occorrono 10 bit
    reg [5:0] seconds;      // Conta da 0 a 59 -> occorrono 6 bit
    reg [5:0] minutes;      // Conta da 0 a 59 
    reg [5:0] hours;        // Conta da 0 a 99 

    always @(posedge ms_tick or negedge rst_n) begin
        if (!rst_n) begin
            milliseconds <= 10'b0;
                 seconds <= 6'b0;
                 minutes <= 6'b0;
                   hours <= 6'b0;
        end else begin
            if (milliseconds == MS_PERIOD - 1) begin
                milliseconds <= 10'b0;
                if (seconds == 59) begin
                    seconds <= 6'b0;
                    if (minutes == 59) begin
                        minutes <= 6'b0;
                        if (hours < 99) begin // Esempio di limite massimo per le ore
                            hours <= hours + 1'b1;
                        end else begin
                            hours <= 6'b0; // Ritorna a 0 dopo 99 ore
                        end
                    end else begin
                        minutes <= minutes + 1'b1;
                    end
                end else begin
                    seconds <= seconds + 1'b1;
                end
            end else begin
                milliseconds <= milliseconds + 1'b1;
            end
        end
    end

    // 3. Conversione del conteggio in cifre BCD

    reg [3:0] sec_unit;
    reg [3:0] sec_tens;

    always @(posedge ms_tick or negedge rst_n) begin
        if (!rst_n) begin
            sec_unit <= 4'b0;
            sec_tens <= 4'b0;
        end else begin
            sec_unit <= seconds % 10;  //secondi
            sec_tens <= seconds / 10;  //decine di secondi
        end
    end

    reg [3:0] ms_hundreds;
    reg [3:0] ms_tens_digit;

    always @(posedge ms_tick or negedge rst_n) begin
        if (!rst_n) begin
            ms_hundreds <= 4'b0;
            ms_tens_digit <= 4'b0;
        end else begin
            ms_hundreds <= (milliseconds / 100) % 10;   // Centinaia di millisecondi
            ms_tens_digit <= (milliseconds / 10) % 10;  // Decine di millisecondi
        end
    end

    // 4. Logica di multiplexing dei display

    localparam NUM_DIGITS = 4;
    reg [1:0] digit_counter; // Conta da 0 a 3 per selezionare il display

    localparam REFRESH_DIVIDER = CLK_FREQ / (1000 * NUM_DIGITS);

    reg [31:0] refresh_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_counter <= 32'b0;
            digit_counter <= 2'b00;
        end else begin
            if (refresh_counter == REFRESH_DIVIDER - 1) begin
                refresh_counter <= 32'b0;
                digit_counter <= (digit_counter == NUM_DIGITS - 1) ? 2'b00 : digit_counter + 1'b1;
            end else begin
                refresh_counter <= refresh_counter + 1'b1;
            end
        end
    end



    always @(digit_counter) begin
        case (digit_counter)
            2'b00: digit_sel <= 4'b1110; // Accende il primo display (LSB)
            2'b01: digit_sel <= 4'b1101; // Accende il secondo display
            2'b10: digit_sel <= 4'b1011; // Accende il terzo display
            2'b11: digit_sel <= 4'b0111; // Accende il quarto display (MSB)
            default: digit_sel <= 4'b1110;
        endcase
    end


    // 5. Generazione dei segnali per i segmenti



    reg [3:0] current_digit_bcd;

    always @(digit_counter or sec_unit or sec_tens or ms_hundreds or ms_tens_digit) begin
        case (digit_counter)
            2'b00: current_digit_bcd <= sec_unit;      // Unità dei secondi
            2'b01: current_digit_bcd <= sec_tens;      // Decine dei secondi
            2'b10: current_digit_bcd <= ms_tens_digit; // Decine di millisecondi
            2'b11: current_digit_bcd <= ms_hundreds;   // Centinaia di millisecondi
            default: current_digit_bcd <= 4'b0000;
        endcase
    end

     always @(current_digit_bcd) begin
        case (current_digit_bcd)
            4'h0: segment_out =  7'b0000001; // 0
            4'h1: segment_out =  7'b1001111; // 1
            4'h2: segment_out =  7'b0010010; // 2
            4'h3: segment_out =  7'b0001010; // 3
            4'h4: segment_out =  7'b1001100; // 4
            4'h5: segment_out =  7'b0101000; // 5
            4'h6: segment_out =  7'b0100000; // 6
            4'h7: segment_out =  7'b0001111; // 7
            4'h8: segment_out =  7'b0000000; // 8
            4'h9: segment_out =  7'b0001100; // 9
            default: segment_out =  7'b1111111; // Spento (tutti i segmenti a '1' per anodo comune)
        endcase
    end

    

endmodule