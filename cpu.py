import pyrtl
from pyrtl import Input, Register, WireVector, Const

# ------------------------------
# 参数定义
# ------------------------------
DATA_WIDTH = 8
ADDR_WIDTH = 8
REG_COUNT = 8
INSTR_WIDTH = 16

# 指令字段
OPCODE_HI = 15
OPCODE_LO = 12
RA_HI = 11
RA_LO = 8
RB_IMM_HI = 7
RB_IMM_LO = 0

# 操作码
OP_IMM   = 0b0000
OP_ADD   = 0b0001
OP_SUB   = 0b0010
OP_LOAD  = 0b0011
OP_STORE = 0b0100
OP_BEQ   = 0b0101
OP_MOV   = 0b0110
OP_HALT  = 0b0111

# ------------------------------
# 定义存储器与初始化
# ------------------------------
reg_file = [Register(DATA_WIDTH, f'r{i}') for i in range(6)]
SP = Register(DATA_WIDTH, 'SP')
PC = Register(ADDR_WIDTH, 'PC')
Z = Register(1, 'Z')

memory = pyrtl.MemBlock(DATA_WIDTH, 1 << ADDR_WIDTH, name='mem')
instr_mem = pyrtl.MemBlock(INSTR_WIDTH, 1 << ADDR_WIDTH, name='instr_mem')

# 复位到初始状态
reset = Input(1, 'reset')

# ------------------------------
# 定义导线，分离指令
# ------------------------------
opcode = WireVector(4, 'opcode')
ra_field = WireVector(4, 'ra')
#TODO:check here
rb_imm_field = WireVector(8, 'rb_imm')
rb_field = WireVector(4, 'rb')
rb_field <<= rb_imm_field[4:8]  # 高4位
# TODO: check here
imm8 = WireVector(8, 'imm8')
imm8 <<= rb_imm_field

reg_wen = WireVector(1, 'reg_wen')
mem_wen = WireVector(1, 'mem_wen')
z_wen = WireVector(1, 'z_wen')
w_addr = WireVector(3, 'w_addr')

reg_wdata = WireVector(DATA_WIDTH, 'reg_wdata')
alu_result = WireVector(DATA_WIDTH, 'alu_result')
mem_rdata = WireVector(DATA_WIDTH, 'mem_rdata')

# ------------------------------
# 取指与译码
# ------------------------------
instr = WireVector(INSTR_WIDTH, 'instr')
instr <<= instr_mem[PC]

opcode <<= instr[OPCODE_LO:OPCODE_HI+1]
ra_field <<= instr[RA_LO:RA_HI+1]
rb_imm_field <<= instr[RB_IMM_LO:RB_IMM_HI+1]
#TODO: ? maybe can get 4 bits directly
ra_low3 = ra_field[0:3]
rb_low3 = rb_field[0:3]

rdata1 = WireVector(DATA_WIDTH, 'rdata1')
rdata2 = WireVector(DATA_WIDTH, 'rdata2')
rdata1 <<= pyrtl.mux(ra_low3, *reg_file)
rdata2 <<= pyrtl.mux(rb_low3, *reg_file)

# ------------------------------
# ALU
# ------------------------------
add_res = rdata1 + rdata2
sub_res = rdata1 - rdata2

with pyrtl.conditional_assignment:
    with opcode == OP_ADD:
        alu_result |= add_res
    with opcode == OP_SUB:
        alu_result |= sub_res
    with pyrtl.otherwise:
        alu_result |= 0

# ------------------------------
# 写回数据选择
# ------------------------------
with pyrtl.conditional_assignment:
    with opcode == OP_IMM:
        reg_wdata |= imm8
    with (opcode == OP_ADD) | (opcode == OP_SUB):
        reg_wdata |= alu_result
    with opcode == OP_LOAD:
        reg_wdata |= mem_rdata
    with opcode == OP_MOV:
        reg_wdata |= rdata2
    with pyrtl.otherwise:
        reg_wdata |= 0

# ------------------------------
# 内存访问
# ------------------------------
mem_addr = WireVector(ADDR_WIDTH, 'mem_addr')
mem_wdata = WireVector(DATA_WIDTH, 'mem_wdata')

with pyrtl.conditional_assignment:
    with opcode == OP_LOAD:
        mem_addr |= rdata2[0:ADDR_WIDTH]
    with opcode == OP_STORE:
        mem_addr |= rdata1[0:ADDR_WIDTH]
    with pyrtl.otherwise:
        mem_addr |= 0

mem_wdata <<= rdata2
mem_rdata <<= memory[mem_addr]
mem_wen <<= (opcode == OP_STORE)

# ------------------------------
# 控制信号生成
# ------------------------------
is_writeback_op = (opcode == OP_IMM) | (opcode == OP_ADD) | (opcode == OP_SUB) | (opcode == OP_LOAD) | (opcode == OP_MOV)
reg_wen <<= is_writeback_op & (ra_low3 != Const(7, 3))
w_addr <<= ra_low3
z_wen <<= is_writeback_op

# ------------------------------
# 分支处理
# ------------------------------
branch_taken = WireVector(1, 'branch_taken')
branch_taken <<= (opcode == OP_BEQ) & (rdata1 == rdata2)

next_pc = WireVector(ADDR_WIDTH, 'next_pc')
pc_plus_one = PC + Const(1, ADDR_WIDTH)
branch_target = pc_plus_one + imm8.sign_extended(ADDR_WIDTH)

with pyrtl.conditional_assignment:
    with branch_taken:
        next_pc |= branch_target
    with pyrtl.otherwise:
        next_pc |= pc_plus_one

# ------------------------------
# HALT
# ------------------------------
halt = WireVector(1, 'halt')
halt <<= (opcode == OP_HALT)

final_pc = WireVector(ADDR_WIDTH, 'final_pc')
with pyrtl.conditional_assignment:
    with halt:
        final_pc |= PC
    with pyrtl.otherwise:
        final_pc |= next_pc

# ------------------------------
# 寄存器更新
# ------------------------------
for i in range(6):
    with pyrtl.conditional_assignment:
        with reset:
            reg_file[i].next = 0
        with pyrtl.otherwise:
            with (reg_wen & (w_addr == Const(i, 3))):
                reg_file[i].next = reg_wdata
            with pyrtl.otherwise:
                reg_file[i].next = reg_file[i]

with pyrtl.conditional_assignment:
    with reset:
        SP.next = 0
    with pyrtl.otherwise:
        with (reg_wen & (w_addr == Const(6, 3))):
            SP.next = reg_wdata
        with pyrtl.otherwise:
            SP.next = SP

with pyrtl.conditional_assignment:
    with reset:
        PC.next = 0
    with pyrtl.otherwise:
        PC.next = final_pc

with pyrtl.conditional_assignment:
    with reset:
        Z.next = 0
    with pyrtl.otherwise:
        with z_wen:
            Z.next = (reg_wdata == Const(0, DATA_WIDTH))
        with pyrtl.otherwise:
            Z.next = Z

mem_write_enabled = WireVector(1, 'mem_write_enabled')
mem_write_enabled <<= mem_wen & ~reset

with pyrtl.conditional_assignment:
    with mem_write_enabled:
        memory[mem_addr] |= mem_wdata

# ------------------------------
# 辅助函数
# ------------------------------
def load_program(program):
    for addr, instr_val in enumerate(program):
        instr_mem[addr] <<= instr_val

def init_data_memory(data_dict):
    for addr, val in data_dict.items():
        memory[addr] <<= val

def print_cpu_state(sim, cycle):
    print(f"\n{'='*60}")
    print(f"Cycle {cycle:3d} | PC: {sim.inspect(PC):3d} | Z: {sim.inspect(Z)} | Halt: {sim.inspect(halt)}")
    print(f"IR: 0x{sim.inspect(instr):04x} | Opcode: {sim.inspect(opcode):01x}")
    print(f"Ra: {sim.inspect(ra_field)}, Rb: {sim.inspect(rb_field)}, Imm: {sim.inspect(imm8)}")
    reg_str = "Registers: "
    for i in range(6):
        reg_str += f"R{i}={sim.inspect(reg_file[i]):3d} "
    reg_str += f"SP={sim.inspect(SP):3d}"
    print(reg_str)
    print(f"{'='*60}")

# ------------------------------
# 测试程序
# ------------------------------
if __name__ == '__main__':
    program = [
        0b0000 << 12 | 0b0000 << 8 | 0b00000101,   # IMM R0,5
        0b0000 << 12 | 0b0001 << 8 | 0b00000011,   # IMM R1,3
        0b0001 << 12 | 0b0000 << 8 | 0b00010000,   # ADD R0,R1
        0b0010 << 12 | 0b0010 << 8 | 0b00000000,   # SUB R2,R0
        0b0110 << 12 | 0b0011 << 8 | 0b00100000,   # MOV R3,R2
        0b0000 << 12 | 0b0100 << 8 | 0b01100100,   # IMM R4,100
        0b0100 << 12 | 0b0100 << 8 | 0b00110000,   # STORE R4,R3
        0b0011 << 12 | 0b0101 << 8 | 0b01000000,   # LOAD R5,R4
        0b0101 << 12 | 0b0101 << 8 | 0b01010010,   # BEQ R5,R3,2
        0b0111 << 12 | 0b0000 << 8 | 0b00000000,   # HALT
    ]
    
    init_data_memory({100: 0})
    load_program(program)
    
    sim_trace = pyrtl.SimulationTrace()
    sim = pyrtl.Simulation(tracer=sim_trace)
    
    sim.step({'reset': 1})
    sim.step({'reset': 0})
    
    max_cycles = 30
    for cycle in range(max_cycles):
        sim.step({'reset': 0})
        print_cpu_state(sim, cycle)
        if sim.inspect(halt.name):
            print("\n*** CPU HALTED ***")
            break
    
    print("\nFinal Registers:")
    for i in range(6):
        reg = reg_file[i]
        print(f"  {reg.name:3} = {sim.inspect(reg.name)}")
    print(f"  SP  = {sim.inspect(SP.name)}")
    print(f"  PC  = {sim.inspect(PC.name)}")
    print("Memory[100] =", sim.inspect("memory[100]"))