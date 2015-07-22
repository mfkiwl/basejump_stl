// MBT 11/26/2014
//
// bsg_fsb_node_trace_replay
//
// trace format
//
// 0: wait one cycle
// 1: send data
// 2: receive data
// 3: assert done_o; test complete.
// 4: end test; call $finish
//
// in theory, we could add branching, etc.
// before we know it, we have a processor =)
//
//

module bsg_fsb_node_trace_replay
  #(parameter   ring_width_p=80
    , parameter master_id_p ="inv"
    , parameter slave_id_p  ="inv"
    , parameter rom_addr_width_p=6
    )
   (input clk_i
    , input reset_i
    , input en_i

    // input channel
    , input v_i
    , input [ring_width_p-1:0] data_i
    , output ready_o

    // output channel
    , output v_o
    , output [ring_width_p-1:0] data_o
    , input yumi_i

    // connection to rom
    // note: asynchronous reads

    , output [rom_addr_width_p-1:0] rom_addr_o
    , input  [ring_width_p+4-1:0]   rom_data_i

    // true outputs
    , output reg done_o
    , output reg error_o
    );

   logic [rom_addr_width_p-1:0] addr_r, addr_n;
   logic                        done_r, done_n;
   logic                        error_r, error_n;

   assign rom_addr_o = addr_r;
   assign data_o     = rom_data_i[0+:ring_width_lp];
   assign done_o     = done_r;
   assign error_o    = error_r;

   always_ff @(posedge clk_i)
     begin
        if (reset_i)
          begin
             addr_r  <= 0;
             done_r  <= 0;
             error_r <= 0;
          end
        else
          begin
             addr_r  <= addr_n;
             done_r  <= done_n;
             error_r <= error_n;
          end
     end // always_ff @

   wire [3:0] op = rom_data_i[ring_width_p+:4];

   wire       addr_p1 = addr + 1;
   logic      instr_completed;

   assign addr_next =  instr_completed ? (addr_r+1) : addr_r;

   // handle outputs
   always_comb
     begin
        // defaults; not sending and not receiving unless done
        v_o             = 1'b0;
        ready_o         = done_r;
        done_n          = done_r;

        if (!done_r & en_i & ~reset_i)
          begin
             case (op)
               1: v_o     = 1'b1;
               2: ready_o = 1'b1;
               3: done_n  = 1'b1;
               default:
                 begin
                 end
             endcase
          end
     end // always_comb

   // next instruction logic
   always_comb
     begin
        instr_completed = 1'b0;
        error_n = error_r;

        if (!done_r & en_i & ~reset_i)
          begin
             case (op)
               0:  instr_completed = 1'b1;
               1:
                 begin
                    if (yumi_i)
                      instr_completed = 1'b1;
                 end
               2:
                 begin
                    if (v_i)
                      begin
                         instr_completed = 1'b1;
                         error_n = data_i != data_o;
                      end
                 end
               default:
                 begin
                 end
             endcase // case (op)
          end
     end

   // non-synthesizeable components
   always @(negedge clk_i)
     begin
        if (instr_completed & ~reset_i & ~done_r)
          begin
             case(op)
               1: $display("### trace %s sent %h", filename_p, data_o);
               2:
                 begin
                    if (data_i != data_o)
                      begin
                         $display("############################################################################");
                         $display("### %m ");
                         $display("###    ");
                         $display("### FAIL (trace mismatch) = %h", data_i);
                         $display("###              expected = %h\n", data_o);
                         $display("############################################################################");
                         $finish();
                      end
                    else
                      begin
                         $display("### %m trace %s matched %h", filename_p, data_o);
                      end // else: !if(data_i != data_o)
                 end
               3:
                 begin
                    $display("############################################################################");
                    $display("###### done_o=1 (trace %s finished) (%m)", filename_p);
                    $display("############################################################################");
                 end
               4:
                 begin
                    $display("############################################################################");
                    $display("###### DONE (trace %s finished; CALLING $finish) (%m)", filename_p);
                    $display("############################################################################");
                    $finish;
                 end
               default:
                 begin

                 end
             endcase // case (op)
             case (op)
               0,1,2,3,4:
                 begin
                 end
               default: $display("%m unknown op %x\n", op);
             endcase // case (op)
          end // if (instr_completed & ~reset_i & ~done_r)
     end // always @ (negedge clk_i)

endmodule