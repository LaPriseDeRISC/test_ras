all:
	verilator --cc --exe --o ../vras$(shell python3-config --extension-suffix) -CFLAGS "$(shell python3 -m pybind11 --includes) -fPIC -O3 -Wall -shared -std=c++11 -fPIC" -LDFLAGS "$(shell python3-config --ldflags) --shared" --clk clk --Mdir build --build -j 0 -Wall src/sim_main.cpp src/ras.sv src/bram.sv

clean:
	rm -rf ./build
	rm -f vras.cpython*

