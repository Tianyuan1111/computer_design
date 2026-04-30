import pyrtl
from pyrtl import Input, Register, WireVector, Const

# ------------------------------
# 参数定义
# ------------------------------
DATA_WIDTH = 8          # 数据总线宽度（位）
ADDR_WIDTH = 8          # 地址总线宽度（位），支持256个地址
REG_COUNT = 8           # 寄存器数量（实际只实现了0-5和SP）
INSTR_WIDTH = 16        # 指令宽度（位）

# 指令字段位域定义
OPCODE_HI = 15          # 操作码高位位置
OPCODE_LO = 12          # 操作码低位位置
RA_HI = 11              # 源/目标寄存器A高位位置
RA_LO = 8               # 源/目标寄存器A低位位置
RB_IMM_HI = 7           # 寄存器B/立即数字段高位位置
RB_IMM_LO = 0           # 寄存器B/立即数字段低位位置

# 操作码定义
OP_IMM   = 0b0000       # 立即数加载: Rd = imm8
OP_ADD   = 0b0001       # 加法: Rd = Rs + Rt
OP_SUB   = 0b0010       # 减法: Rd = Rs - Rt
OP_LOAD  = 0b0011       # 内存加载: Rd = mem[Rs]
OP_STORE = 0b0100       # 内存存储: mem[Rs] = Rt
OP_BEQ   = 0b0101       # 条件分支: if Z then PC += offset
OP_MOV   = 0b0110       # 寄存器移动: Rd = Rs
OP_HALT  = 0b0111       # 停机指令

# ------------------------------
# 定义存储器与初始化
# ------------------------------
# 通用寄存器文件（R0-R7）
# reg_file = [Register(DATA_WIDTH, f'r{i}') for i in range(8)] 
regs = pyrtl.MemBlock(bitwidth=DATA_WIDTH, addrwidth=3, name='regs', asynchronous=True, max_read_ports=4)

# 程序计数器
PC = Register(ADDR_WIDTH, 'PC')
# 零标志位寄存器
Z = Register(1, 'Z')

# 数据存储器（256字节）
memory = pyrtl.MemBlock(
    bitwidth=DATA_WIDTH,
    addrwidth=ADDR_WIDTH,
    name='mem',
    asynchronous=True
)
# 指令存储器（256条指令）
instr_mem = pyrtl.MemBlock(
    bitwidth=INSTR_WIDTH,
    addrwidth=ADDR_WIDTH,
    name='instr_mem',
    asynchronous=True
)

# 复位输入信号
reset = Input(1, 'reset')

# ------------------------------
# 顶层输出信号（用于综合）
# ------------------------------
out_PC   = pyrtl.Output(ADDR_WIDTH, 'out_PC')
out_halt = pyrtl.Output(1, 'out_halt')
out_Z    = pyrtl.Output(1, 'out_Z')

# ------------------------------
# 定义导线，分离指令
# ------------------------------
opcode = WireVector(4, 'opcode')        # 操作码
ra_field = WireVector(4, 'ra')          # 寄存器A字段（4位）
rb_imm_field = WireVector(8, 'rb_imm')  # 寄存器B/立即数字段（8位）
rb_field = WireVector(4, 'rb')          # 寄存器B字段（高4位）
imm8 = WireVector(8, 'imm8')            # 8位立即数

# 控制信号
reg_wen = WireVector(1, 'reg_wen')      # 寄存器写使能
mem_wen = WireVector(1, 'mem_wen')      # 内存写使能
z_wen = WireVector(1, 'z_wen')          # 零标志写使能
w_addr = WireVector(3, 'w_addr')        # 写寄存器地址

# 数据通路
reg_wdata = WireVector(DATA_WIDTH, 'reg_wdata')  # 寄存器写数据
alu_result = WireVector(DATA_WIDTH, 'alu_result') # ALU结果
mem_rdata = WireVector(DATA_WIDTH, 'mem_rdata')  # 内存读数据

# ------------------------------
# 取指与译码
# ------------------------------
instr = WireVector(INSTR_WIDTH, 'instr')          # 当前指令
instr <<= instr_mem[PC]                           # 从指令存储器读取指令

# 指令字段分离
opcode <<= instr[OPCODE_LO:OPCODE_HI+1]          # 提取操作码
ra_field <<= instr[RA_LO:RA_HI+1]                # 提取寄存器A字段
rb_imm_field <<= instr[RB_IMM_LO:RB_IMM_HI+1]    # 提取RB/立即数字段
rb_field <<= rb_imm_field[4:8]                   # 从rb_imm_field提取高4位

ra_low3 = ra_field[0:3]                          # 取寄存器地址的低3位（0-7）
rb_low3 = rb_field[0:3]                          # 取寄存器地址的低3位

imm8 <<= rb_imm_field                            # 直接使用整个rb_imm_field

# 读取寄存器值
rdata1 = WireVector(DATA_WIDTH, 'rdata1')        # 源操作数1
rdata2 = WireVector(DATA_WIDTH, 'rdata2')        # 源操作数2
#rdata1 <<= pyrtl.mux(ra_low3, *reg_file)         # 根据ra_low3选择寄存器
#rdata2 <<= pyrtl.mux(rb_low3, *reg_file)         # 根据rb_low3选择寄存器
rdata1 <<= regs[ra_low3] # 根据 ra_low3 读取寄存器
rdata2 <<= regs[rb_low3] # 根据 rb_low3 读取寄存器
# ------------------------------
# ALU（算术逻辑单元）
# ------------------------------

with pyrtl.conditional_assignment:
    with opcode == OP_ADD:
        alu_result |= rdata1 + rdata2
    with opcode == OP_SUB:
        alu_result |= rdata1 - rdata2
    with pyrtl.otherwise:
        alu_result |= 0
# ------------------------------
# 写回数据选择（决定写回寄存器的值）
# ------------------------------
with pyrtl.conditional_assignment:
    with opcode == OP_IMM:
        reg_wdata |= imm8                        # 立即数直接写回
    with (opcode == OP_ADD) | (opcode == OP_SUB):
        reg_wdata |= alu_result                  # ALU结果写回
    with opcode == OP_LOAD:
        reg_wdata |= mem_rdata                   # 内存读数据写回
    with opcode == OP_MOV:
        reg_wdata |= rdata2                      # 寄存器间移动
    with pyrtl.otherwise:
        reg_wdata |= 0

# ------------------------------
# 内存访问
# ------------------------------
mem_addr = WireVector(ADDR_WIDTH, 'mem_addr')    # 内存访问地址
mem_wdata = WireVector(DATA_WIDTH, 'mem_wdata')  # 内存写数据

# 根据操作码生成内存地址
with pyrtl.conditional_assignment:
    with opcode == OP_LOAD:
        mem_addr |= rdata2[0:ADDR_WIDTH]         # LOAD使用rdata2作为地址
    with opcode == OP_STORE:
        mem_addr |= rdata1[0:ADDR_WIDTH]         # STORE使用rdata1作为地址
    with pyrtl.otherwise:
        mem_addr |= 0

mem_wdata <<= rdata2                             # 写数据来自rdata2
mem_rdata <<= memory[mem_addr]                   # 读数据来自内存
mem_wen <<= (opcode == OP_STORE)                 # 只有STORE指令才写内存

# ------------------------------
# 寄存器控制信号生成
# ------------------------------
# 需要写回寄存器的操作类型
is_writeback_op = (opcode == OP_IMM) | (opcode == OP_ADD) | (opcode == OP_SUB) | (opcode == OP_LOAD) | (opcode == OP_MOV)
# 寄存器写使能
reg_wen <<= is_writeback_op
w_addr <<= ra_low3                                # 写回地址来自ra_low3
z_wen <<= (opcode == OP_ADD) | (opcode == OP_SUB)                         # 零标志更新使能

# ------------------------------
# 分支控制
# ------------------------------
branch_taken = WireVector(1, 'branch_taken')      # 分支是否发生
branch_taken <<= (opcode == OP_BEQ) & Z           # BEQ且零标志为1时分支

next_pc = WireVector(ADDR_WIDTH, 'next_pc')       # 下一PC值
pc_plus_one = PC + Const(1, ADDR_WIDTH)           # PC+1
branch_target = pc_plus_one + imm8.sign_extended(ADDR_WIDTH)  # 分支目标地址

# 选择下一个PC值
with pyrtl.conditional_assignment:
    with branch_taken:
        next_pc |= branch_target                  # 分支：PC+1+偏移
    with pyrtl.otherwise:
        next_pc |= pc_plus_one                    # 顺序执行：PC+1

# ------------------------------
# HALT（停机处理）
# ------------------------------
halt = WireVector(1, 'halt')                      # 停机信号
halt <<= (opcode == OP_HALT)

# 最终PC值（停机时保持不变）
final_pc = WireVector(ADDR_WIDTH, 'final_pc')
with pyrtl.conditional_assignment:
    with halt:
        final_pc |= PC                            # 停机时PC保持不变
    with pyrtl.otherwise:
        final_pc |= next_pc

# ------------------------------
# 寄存器和内存更新（时序逻辑）
# ------------------------------
# 更新通用寄存器R0-R7
#for i in range(8):
#    reg_file[i].next <<= pyrtl.select(  #type: ignore
#        reset,
#        0,
#        pyrtl.select(
#            reg_wen & (w_addr == Const(i, 3)),
#            reg_wdata,
#            reg_file[i]
#        )
#    )
regs[w_addr] <<= pyrtl.select( reset, 0, pyrtl.select( reg_wen, reg_wdata, regs[w_addr] ) )

PC.next <<= pyrtl.select(   #type: ignore
    reset,
    0,
    final_pc
)

# 更新零标志Z
Z.next <<= pyrtl.select(    #type: ignore
    reset,
    0,
    pyrtl.select(
        z_wen,
        reg_wdata == Const(0, DATA_WIDTH),
        Z
    )
)

# 内存写操作（只在非复位且写使能时进行）
mem_write_enabled = WireVector(1, 'mem_write_enabled')
mem_write_enabled <<= mem_wen & ~reset

with pyrtl.conditional_assignment:
    with mem_write_enabled:
        memory[mem_addr] |= mem_wdata

# ------------------------------
# 顶层输出连接
# ------------------------------
out_PC <<= PC
out_halt <<= halt
out_Z <<= Z

# ------------------------------
# 辅助函数
# ------------------------------
def print_cpu_state(sim, cycle):
    print(f"Cycle {cycle:3d} | PC: {sim.inspect(PC.name):3d} | Z: {sim.inspect(Z.name)} | Halt: {sim.inspect(halt.name)}")
    print(f"IR: 0x{sim.inspect(instr.name):04x} | Opcode: {sim.inspect(opcode.name):01x}")
    print(f"Ra: {sim.inspect(ra_field.name)}, Rb: {sim.inspect(rb_field.name)}, Imm: {sim.inspect(imm8.name)}")
    
    reg_state = sim.inspect_mem(regs)
    reg_str = "Registers: "
    for i in range(REG_COUNT):
        reg_str += f"R{i}={reg_state.get(i, 0):3d} "
    print(reg_str)
    print(f"{'='*60}")

# ------------------------------
# 测试程序
# ------------------------------
if __name__ == '__main__':
    # 测试程序：实现简单的算术运算和内存访问
    program = [
        0b0000 << 12 | 0b0000 << 8 | 0b00000101,   # IMM R0,5      ; R0 = 5
        0b0000 << 12 | 0b0001 << 8 | 0b00000011,   # IMM R1,3      ; R1 = 3
        0b0001 << 12 | 0b0000 << 8 | 0b00010000,   # ADD R0,R1     ; R0 = R0 + R1 = 8
        0b0010 << 12 | 0b0010 << 8 | 0b00000000,   # SUB R2,R0     ; R2 = R2 - R0 = -8
        0b0110 << 12 | 0b0011 << 8 | 0b00100000,   # MOV R3,R2     ; R3 = R2 = -8
        0b0000 << 12 | 0b0100 << 8 | 0b01100100,   # IMM R4,100    ; R4 = 100（地址）
        0b0100 << 12 | 0b0100 << 8 | 0b00110000,   # STORE R4,R3   ; mem[100] = R3 = -8
        0b0011 << 12 | 0b0101 << 8 | 0b01000000,   # LOAD R5,R4    ; R5 = mem[100] = -8
        0b0101 << 12 | 0b0101 << 8 | 0b01010010,   # BEQ 2         ; if Z then PC+=2（相等时跳转）
        0b0111 << 12 | 0b0000 << 8 | 0b00000000,   # HALT          ; 停机
    ]
    
    
    # 创建仿真器
    sim_trace = pyrtl.SimulationTrace()
    sim = pyrtl.Simulation(
    tracer=sim_trace,
    memory_value_map={
        memory: {100: 0},   # 数据内存初始化
        instr_mem: {i: instr for i, instr in enumerate(program)}  # 指令加载
    }
)
    
    # 复位CPU
    sim.step({'reset': 1})
    sim.step({'reset': 0})
    
    # 运行程序，最多30个周期
    max_cycles = 30
    for cycle in range(max_cycles):
        sim.step({'reset': 0})
        print_cpu_state(sim, cycle)
        if sim.inspect(halt.name):
            print("\n*** CPU HALTED ***")
            break
    
    # 路图打印
    #with open("cpu.dot", "w") as f:
        #pyrtl.output_to_graphviz(f)
 
    # 导出Verilog代码
    with open("cpu_memblock_regs.v", "w") as f:
        pyrtl.output_to_verilog(f, add_reset=False)
