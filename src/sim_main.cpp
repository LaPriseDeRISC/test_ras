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
    top->clk = 0;
    top->pop = pop;
    top->push = push;
    top->branch = branch;
    top->close_valid = close_valid;
    top->close_invalid = close_invalid;
    top->din = din;
    top->eval();
}

uint32_t process(){
    top->clk = 1;
    top->eval();
    return top->dout;
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
    py::print("push_head :", top->ras->push_head);
    py::print("pop_head :", top->ras->pop_head);
    py::print("empty :", top->ras->empty);
    py::print("full :", top->ras->full);
}

void infos_branch() {
    py::print("a : [", top->ras->pop_head, "..", top->ras->a_end, "]");
    py::print("s : [", top->ras->s_head, ',', top->ras->s_queue, "..", top->ras->s_tail, "]");
    py::print("e : [", top->ras->ef_start, "..", top->ras->BOSP, "]");
    py::print("f : [", top->ras->BOSP, "..", top->ras->push_head, "]");
    py::print("has_added :", top->ras->has_added);
    py::print("has_suppressed :", top->ras->has_suppressed);
    py::print("in_branch :", top->ras->in_branch);
    py::print("branch_list_empty :", top->ras->branch_list_empty);
}
std::array<uint32_t, 15> raw_infos() {
    return {top->ras->pop_head, top->ras->a_end,
            top->ras->s_head, top->ras->s_queue,top->ras->s_tail,
            top->ras->ef_start, top->ras->BOSP,
            top->ras->BOSP, top->ras->push_head,
            top->ras->push_queue, top->ras->pop_queue,
            top->ras->has_added,
            top->ras->has_suppressed,
            top->ras->in_branch,
            top->ras->branch_list_empty};
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
m.def("infos", &infos, "various informations");
m.def("infos_branch", &infos_branch, "various informations about current branch");
m.def("next_links", &get_next_links, "next ptrs");
m.def("prev_links", &get_prev_links, "prev ptrs");
m.def("output_valid", [](){return top->pop_valid;});
m.def("raw_info", &raw_infos);
m.def("data", &get_data, "data");
}

