  #include "Vras.h"
  #include "Vras_ras.h"
  #include "verilated.h"
  #include <pybind11/pybind11.h>
  namespace py = pybind11;
  VerilatedContext* contextp;
  Vras* top;

  void init_argv(int argc, char** argv){
      contextp = new VerilatedContext;
      contextp->commandArgs(argc, argv);
      top = new Vras{contextp};
  }
  
  void init(){
      contextp = new VerilatedContext;
      top = new Vras{contextp};
  }
  
  void close_module(){
      delete top;
      delete contextp;
  }
  
  uint32_t process(bool pop, bool push, bool branch, bool close_valid, bool close_invalid, uint32_t din){
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
  uint16_t get_next_push_addr(){
      return top->ras->next_push_addr;
  }
  uint16_t get_next_pop_addr(){
      return top->ras->next_pop_addr;
  }
  
  PYBIND11_MODULE(vras, m) {
    m.doc() = "system_verilog ras module";

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
  }

