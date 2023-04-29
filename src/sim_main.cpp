#include "Vras__Syms.h"
#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <assert.h>

namespace py = pybind11;
VerilatedContext *contextp;
Vras *top;

#define TO_ARRAY_CONTAINER(x) std::array<__typeof__(*(x)), sizeof(x)/sizeof(__typeof__(*(x)))>

void init_argv(int argc, char **argv) {
    contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    top = new Vras{contextp};
}

void reset() {
    top->rst_ni = 0;
    top->eval();
    top->rst_ni = 1;
    top->eval();
}

void init() {
    contextp = new VerilatedContext;
    top = new Vras{contextp};
}

void close_module() {
    delete top;
    delete contextp;
}

void next_input(bool pop, bool push, std::array<bool, 2> commit, std::array<bool, 2> flush, uint32_t din) {
    top->pop = pop;
    top->push = push;
    top->commit = 0b1 * commit[0] + 0b10 * commit[1];
    top->flush = 0b1 * flush[0] + 0b10 * flush[1];
    top->din = din;
    top->eval();
}

uint32_t process(){
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
    return top->dout;
}

PYBIND11_MODULE(vras, m
) {
m.

doc() = "system_verilog ras module";

m.def("init", &init, "Init of the module");
m.def("process", &process, "Step in clock");
m.def("next_input", &next_input, "Step in clock",
py::arg("pop") = false,
py::arg("push") = false,
py::arg("commit") = std::array<bool, 2>{false, false},
py::arg("flush") = std::array<bool, 2>{false, false},
py::arg("data_in") = 0);
m.def("close", &close_module, "Close the module");
m.def("reset", &reset, "resets the module");
m.def("empty", [](){return top->empty;});
}

