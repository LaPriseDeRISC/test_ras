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

uint32_t process(bool pop, bool push, bool branch, bool close_valid, bool close_invalid, uint32_t din) {
    top->clk = 0;
    top->eval();
    top->clk = 1;
    top->pop = pop;
    top->push = push;
    top->branch = branch;
    top->close_valid = close_valid;
    top->close_invalid = close_invalid;
    top->din = din;
    top->eval();
    return top->dout;
}

uint16_t get_next_push_addr() {
    return top->ras->next_push_addr;
}

uint16_t get_next_pop_addr() {
    return top->ras->next_pop_addr;
}

TO_ARRAY_CONTAINER(top->ras->next_links->ram.m_storage) get_next_links() {
    auto a = reinterpret_cast<TO_ARRAY_CONTAINER(
            top->ras->next_links->ram.m_storage) &>(top->ras->next_links->ram.m_storage);
    static_assert(sizeof(a) == sizeof(top->ras->next_links->ram.m_storage));
    return a;
}

TO_ARRAY_CONTAINER(top->ras->prev_links->ram.m_storage) get_prev_links() {
    auto a = reinterpret_cast<TO_ARRAY_CONTAINER(
            top->ras->prev_links->ram.m_storage) &>(top->ras->prev_links->ram.m_storage);
    static_assert(sizeof(a) == sizeof(top->ras->prev_links->ram.m_storage));
    return a;
}

TO_ARRAY_CONTAINER(top->ras->data->ram.m_storage) get_data() {
    auto a = reinterpret_cast<TO_ARRAY_CONTAINER(top->ras->data->ram.m_storage) &>(top->ras->data->ram.m_storage);
    static_assert(sizeof(a) == sizeof(top->ras->data->ram.m_storage));
    return a;
}

void infos() {
    py::print("next_push_addr :", top->ras->next_push_addr);
    py::print("next_pop_addr :", top->ras->next_pop_addr);
    py::print("next_deleted_addr :", top->ras->next_deleted_addr);
    py::print("push_head_next_value :", top->ras->push_head_next_value);
    py::print("next_preserved_addr :", top->ras->next_preserved_addr);
    py::print("push_head :", top->ras->push_head);
    py::print("push_queue :", top->ras->push_queue);
    py::print("pop_head :", top->ras->pop_head);
    py::print("pop_queue :", top->ras->pop_queue);
    py::print("deleted_head :", top->ras->deleted_head);
    py::print("preserved_head :", top->ras->preserved_head);
}

PYBIND11_MODULE(vras, m
) {
m.

doc() = "system_verilog ras module";

m.def("init", &init, "Init of the module");
m.def("process", &process, "Step in clock",
py::arg("pop") = false,
py::arg("push") = false,
py::arg("branch") = false,
py::arg("close_valid") = false,
py::arg("close_invalid") = false,
py::arg("data_in") = 0);
m.def("close", &close_module, "Close the module");
m.def("next_push_addr", &get_next_push_addr, "next_push addr");
m.def("next_pop_addr", &get_next_pop_addr, "next_pop addr");
m.def("infos", &infos, "various informations");
m.def("next_links", &get_next_links, "next ptrs");
m.def("prev_links", &get_prev_links, "prev ptrs");
m.def("data", &get_data, "data");
}

