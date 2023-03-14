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

void init() {
    contextp = new VerilatedContext;
    top = new Vras{contextp};
}

void close_module() {
    delete top;
    delete contextp;
}

void next_input(bool pop, bool push, bool branch, bool close_valid, bool close_invalid, uint32_t din) {
    top->pop = pop;
    top->push = push;
    top->branch = branch;
    top->close_valid = close_valid;
    top->close_invalid = close_invalid;
    top->din = din;
}

uint32_t process(){
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->eval();
    return top->dout;
}

TO_ARRAY_CONTAINER(top->ras->next_links->ram.m_storage) get_next_links() {
    auto a = reinterpret_cast<TO_ARRAY_CONTAINER(
            top->ras->next_links->ram.m_storage) &>(top->ras->next_links->ram.m_storage);
    static_assert(sizeof(a) == sizeof(top->ras->next_links->ram.m_storage), "TO_ARRAY_CONTAINER MACRO FAILED");
    return a;
}

TO_ARRAY_CONTAINER(top->ras->memory->free_data->ram.m_storage) get_free_slots() {
    auto a = reinterpret_cast<TO_ARRAY_CONTAINER(
            top->ras->memory->free_data->ram.m_storage) &>(top->ras->memory->free_data->ram.m_storage);
    static_assert(sizeof(a) == sizeof(top->ras->memory->free_data->ram.m_storage), "TO_ARRAY_CONTAINER MACRO FAILED");
    return a;
}

TO_ARRAY_CONTAINER(top->ras->data->ram.m_storage) get_data() {
    auto a = reinterpret_cast<TO_ARRAY_CONTAINER(top->ras->data->ram.m_storage) &>(top->ras->data->ram.m_storage);
    static_assert(sizeof(a) == sizeof(top->ras->data->ram.m_storage), "TO_ARRAY_CONTAINER MACRO FAILED");
    return a;
}

std::array<uint32_t,7> raw_infos() {
    return {top->ras->alloc_addr, top->ras->last_alloc_addr,
            top->ras->in_branch, top->ras->branch_list_empty,
            top->ras->current_branch_has_added, top->ras->current_branch_has_suppressed,
            top->ras->BOSP
            };
}

uint32_t get_current_branch_infos(){
    return top->ras->current_branch_vector;
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
py::arg("branch") = false,
py::arg("close_valid") = false,
py::arg("close_invalid") = false,
py::arg("data_in") = 0);
m.def("close", &close_module, "Close the module");
m.def("next_links", &get_next_links, "next ptrs");
m.def("free_slots", &get_free_slots, "prev ptrs");
m.def("output_valid", [](){return top->pop_valid;});
m.def("raw_info", &raw_infos);
m.def("branch_infos", &get_current_branch_infos);
m.def("data", &get_data, "data");
}

