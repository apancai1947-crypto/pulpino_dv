module boot_code
(
    input  logic        CLK,
    input  logic        RSTN,

    input  logic        CSN,
    input  logic [9:0]  A,
    output logic [31:0] Q
  );

  logic [31:0] mem [0:1023];

  initial begin
    $readmemh("/root/work/dv-flow/pulpino_dv/tb/boot_code.hex", mem);
    $display("[ROM_INIT] boot_code.hex loaded. mem[545]=0x%08h mem[546]=0x%08h mem[547]=0x%08h",
      mem[545], mem[546], mem[547]);
    $display("[ROM_INIT] mem[0]=0x%08h mem[1]=0x%08h mem[2]=0x%08h",
      mem[0], mem[1], mem[2]);
  end

  logic [9:0] A_Q;

  always_ff @(posedge CLK, negedge RSTN)
  begin
    if (~RSTN)
      A_Q <= '0;
    else
      if (~CSN)
        A_Q <= A;
  end

  assign Q = mem[A_Q];

endmodule
