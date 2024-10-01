# prj3 exp10 repo

## style

use extension ```SystemVerilog and Verilog Formatter```

#### Command Line Arguments

```sh
  Command Line Arguments:
  --indentation_spaces=4 --named_port_alignment=align  --ort_declarations_alignment=align --module_net_variable_alignment=align
  Verible Build:
  win64
```

## 传参约定

从ID到EXE传参约定：

1. ~~src1存放除数，src2存放被除数(参考手册默认约定)~~ src2存放除数，src1存放被除数（低能儿潘泓锟）
2. 扩展aluop，传递乘除模指令信号，具体为```assign new_aluop={mul.w,mulh.w,mulh.wu,div.w,mod.w,div.wu,mod.wu,alu_op};```

## using phk's pipeline cpu

## Notice

除法器每个人都要使用IP核生成

## todo

本实践任务要求在实践任务9实现的CPU基础上完成以下工作：

1. 添加算术逻辑运算类指令slti、sltui、andi、ori、xori、sll、srl、sra、pcaddu12i。
2. 添加乘除运算类指令mul.w、mulh.w、mulh.wu、div.w、mod.w、div.wu、mod.wu。
3. 运行 exp10 对应的 func，要求成功通过仿真和上板验证。

## team member's work allcation:

| name | job |
| ---- | --- |
| phk  | decode in IDreg.v  |
| rhl  | mul & div in EXreg.v |
| zc   | branch & new alu inst(andi...) in IDreg.v   |
