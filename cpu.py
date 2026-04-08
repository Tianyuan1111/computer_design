import pyrtl
from pyrtl import Input, Output, Register, WireVector, Const, concat
from pyrtl.corecircuits import mux

# ------------------------------
# 参数定义
# ------------------------------
DATA_WIDTH = 8
ADDR_WIDTH = 8
REG_COUNT = 8
INSTR_WIDTH = 16

# 指令字段 - 统一格式
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
# 状态与存储器
# ------------------------------
reg_file = [Register(DATA_WIDTH, f'r{i}') for i in range(REG_COUNT)]
SP = reg_file[6]
PC = reg_file[7]

Z = Register(1, 'Z')

memory = pyrtl.MemBlock(DATA_WIDTH, 1 << ADDR_WIDTH, name='mem')
instr_mem = pyrtl.MemBlock(INSTR_WIDTH, 1 << ADDR_WIDTH, name='instr_mem')

# 添加复位信号
reset = Input(1, 'reset')

# ------------------------------
# 控制信号
# ------------------------------
opcode = WireVector(4, 'opcode')
ra_field = WireVector(4, 'ra')
rb_imm_field = WireVector(8, 'rb_imm')

# 从rb_imm_field中提取rb字段（用于R型指令）
rb_field = WireVector(4, 'rb')
rb_field <<= rb_imm_field[4:8]

imm8 = WireVector(8, 'imm8')
imm8 <<= rb_imm_field

reg_wen = WireVector(1, 'reg_wen')
mem_wen = WireVector(1, 'mem_wen')
z_wen = WireVector(1, 'z_wen')

w_addr = WireVector(3, 'w_addr')

# 数据通路
reg_wdata = WireVector(DATA_WIDTH, 'reg_wdata')
alu_result = WireVector(DATA_WIDTH, 'alu_result')
mem_rdata = WireVector(DATA_WIDTH, 'mem_rdata')

# ------------------------------
# 取指与译码
# ------------------------------
instr = WireVector(INSTR_WIDTH, 'instr')
instr <<= instr_mem[PC.out]

opcode <<= instr[OPCODE_HI:OPCODE_LO]
ra_field <<= instr[RA_HI:RA_LO]
rb_imm_field <<= instr[RB_IMM_HI:RB_IMM_LO]

ra_low3 = ra_field[0:3]
rb_low3 = rb_field[0:3]

# 读取寄存器文件
rdata1 = WireVector(DATA_WIDTH, 'rdata1')
rdata2 = WireVector(DATA_WIDTH, 'rdata2')

rdata1 <<= mux(ra_low3, *[reg_file[i].out for i in range(8)])
rdata2 <<= mux(rb_low3, *[reg_file[i].out for i in range(8)])

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
    with opcode == OP_ADD:
        reg_wdata |= alu_result
    with opcode == OP_SUB:
        reg_wdata |= alu_result
    with opcode == OP_LOAD:
        reg_wdata |= mem_rdata
    with opcode == OP_MOV:
        reg_wdata |= rdata2  # ✅修复：MOV Ra,Rb → Ra=Rb，应该读rdata2
    with pyrtl.otherwise:
        reg_wdata |= 0

# ------------------------------
# 内存访问
# ------------------------------
mem_addr = WireVector(ADDR_WIDTH, 'mem_addr')
mem_wdata = WireVector(DATA_WIDTH, 'mem_wdata')

# LOAD用Rb作地址，STORE用Ra作地址，存Rb的值
with pyrtl.conditional_assignment:
    with opcode == OP_LOAD:
        mem_addr |= rdata2[0:ADDR_WIDTH]
    with opcode == OP_STORE:
        mem_addr |= rdata1[0:ADDR_WIDTH]
    with pyrtl.otherwise:
        mem_addr |= 0

mem_wdata <<= rdata2

# ✅修复：内存读取去掉寄存器打拍，PyRTL MemBlock读是组合逻辑
mem_rdata <<= memory[mem_addr]

mem_wen <<= (opcode == OP_STORE)

# ------------------------------
# 控制信号生成
# ------------------------------
is_writeback_op = (
    (opcode == OP_IMM) |
    (opcode == OP_ADD) |
    (opcode == OP_SUB) |
    (opcode == OP_LOAD) |
    (opcode == OP_MOV)
)

# 不为PC生成写使能
reg_wen <<= is_writeback_op & (ra_low3 != Const(7, 3))

w_addr <<= ra_low3

# Z标志更新条件
z_update_op = (
    (opcode == OP_IMM) |
    (opcode == OP_ADD) |
    (opcode == OP_SUB) |
    (opcode == OP_LOAD) |
    (opcode == OP_MOV)
)
z_wen <<= z_update_op

# ------------------------------
# 分支处理 - BEQ比较Ra和Rb
# ------------------------------
branch_taken = WireVector(1, 'branch_taken')
branch_taken <<= (opcode == OP_BEQ) & (rdata1 == rdata2)

next_pc = WireVector(ADDR_WIDTH, 'next_pc')
pc_plus_one = PC.out + Const(1, ADDR_WIDTH)

# ✅修复：BEQ立即数是偏移，必须先符号扩展再相加
branch_target = pc_plus_one + imm8.sign_extended(ADDR_WIDTH)

with pyrtl.conditional_assignment:
    with branch_taken:
        next_pc |= branch_target
    with pyrtl.otherwise:
        next_pc |= pc_plus_one

# ------------------------------
# HALT处理
# ------------------------------
halt = WireVector(1, 'halt')
halt <<= (opcode == OP_HALT)

final_pc = WireVector(ADDR_WIDTH, 'final_pc')
with pyrtl.conditional_assignment:
    with halt:
        final_pc |= PC.out
    with pyrtl.otherwise:
        final_pc |= next_pc

# ------------------------------
# 寄存器更新
# ------------------------------
for i in range(6):
    with pyrtl.conditional_assignment:
        with reset:
            reg_file[i].next |= 0
        with pyrtl.otherwise:
            with (reg_wen & (w_addr == Const(i, 3))):
                reg_file[i].next |= reg_wdata
            with pyrtl.otherwise:
                reg_file[i].next |= reg_file[i].out

# SP更新
with pyrtl.conditional_assignment:
    with reset:
        SP.next |= 0
    with pyrtl.otherwise:
        with (reg_wen & (w_addr == Const(6, 3))):
            SP.next |= reg_wdata
        with pyrtl.otherwise:
            SP.next |= SP.out

# PC更新
with pyrtl.conditional_assignment:
    with reset:
        PC.next |= 0
    with pyrtl.otherwise:
        PC.next |= final_pc

# Z标志更新
with pyrtl.conditional_assignment:
    with reset:
        Z.next |= 0
    with pyrtl.otherwise:
        with z_wen:
            Z.next |= (reg_wdata == Const(0, DATA_WIDTH))
        with pyrtl.otherwise:
            Z.next |= Z.out

# 内存写入控制
mem_write_enabled = WireVector(1, 'mem_write_enabled')
mem_write_enabled <<= mem_wen & ~reset

with pyrtl.conditional_assignment:
    with mem_write_enabled:
        memory[mem_addr] |= mem_wdata

# ------------------------------
# 辅助函数
# ------------------------------
def load_program(program):
    """加载程序到指令内存"""
    for addr, instr in enumerate(program):
        instr_mem[addr] <<= instr

def init_data_memory(data_dict):
    """初始化数据内存"""
    for addr, val in data_dict.items():
        memory[addr] <<= val

def print_cpu_state(sim, cycle):
    """打印CPU状态的辅助函数"""
    print(f"\n{'='*60}")
    print(f"Cycle {cycle:3d} | PC: {sim.inspect(PC.out):3d} | Z: {sim.inspect(Z.out)} | Halt: {sim.inspect(halt)}")
    print(f"IR: 0x{sim.inspect(instr):04x} | Opcode: {sim.inspect(opcode):01x}")
    print(f"Ra: {sim.inspect(ra_field)}, Rb: {sim.inspect(rb_field)}, Imm: {sim.inspect(imm8)}")
    print("Registers:")
    reg_str = ""
    for i in range(6):
        reg_str += f"R{i}={sim.inspect(reg_file[i].out):3d} "
    reg_str += f"SP={sim.inspect(SP.out):3d} "
    print(f"  {reg_str}")
    print(f"{'='*60}")

# ------------------------------
# 测试程序
# ------------------------------
if __name__ == '__main__':
    program = [
        0b0000 << 12 | 0b0000 << 8 | 0b00000101,   # IMM R0,5
        0b0000 << 12 | 0b0001 << 8 | 0b00000011,   # IMM R1,3
        0b0001 << 12 | 0b0000 << 8 | 0b0001 << 4, # ADD R0,R1
        0b0010 << 12 | 0b0010 << 8 | 0b0000 << 4, # SUB R2,R0
        0b0110 << 12 | 0b0011 << 8 | 0b0010 << 4, # MOV R3,R2
        0b0000 << 12 | 0b0100 << 8 | 0b01100100,   # IMM R4,100
        0b0100 << 12 | 0b0100 << 8 | 0b0011 << 4, # STORE R4,R3
        0b0011 << 12 | 0b0101 << 8 | 0b0100 << 4, # LOAD R5,R4
        0b0101 << 12 | 0b0101 << 8 | 0b0011 << 4 | 0b00000010, # BEQ R5,R3,2
        0b0111 << 12 | 0b0000 << 8 | 0b00000000,   # HALT
        0b0000 << 12 | 0b0110 << 8 | 0b01100011,   # IMM R6,99
        0b0111 << 12 | 0b0000 << 8 | 0b00000000,   # HALT
    ]
    
    init_data_memory({100: 0})
    load_program(program)
    
    sim_trace = pyrtl.SimulationTrace()
    sim = pyrtl.Simulation(tracer=sim_trace)
    
    print("="*60)
    print("RESETTING CPU")
    print("="*60)
    
    sim.step({'reset': 1})
    sim.step({'reset': 0})
    
    print("\n" + "="*60)
    print("STARTING EXECUTION")
    print("="*60)
    
    max_cycles = 30
    for cycle in range(max_cycles):
        sim.step({'reset': 0})
        print_cpu_state(sim, cycle)
        
        if sim.inspect(halt):
            print("\n*** CPU HALTED ***")
            break
    else:
        print(f"\n*** Simulation reached max cycles ({max_cycles}) ***")
    
    print("\n" + "="*60)
    print("FINAL STATE")
    print("="*60)
    for i in range(8):
        reg_name = "SP" if i == 6 else "PC" if i == 7 else f"R{i}"
        print(f"  {reg_name:3} = {sim.inspect(reg_file[i].out):3d}")
    
    print("\nMemory [100] =", sim.inspect(memory[100]))