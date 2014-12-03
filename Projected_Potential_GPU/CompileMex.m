clc; clear all;
mexGPU(1, 'getProjPotential.cu', 'D:/MULTEM/General_CPU_GPU', 'hQuadrature.cpp', 'hAtomicdata.cpp'...
    , 'hPotential_CPU.cpp', 'hMT_General_CPU.cpp', 'hMT_Specimen_CPU.cpp', 'hMT_General_GPU.cu'...
    , 'hMT_AtomTypes_GPU.cu', 'hMT_Potential_GPU.cu');