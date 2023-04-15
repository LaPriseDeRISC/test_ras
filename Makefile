all:
	verilator --cc --exe --o ../vras$(shell python3-config --extension-suffix) -CFLAGS "$(shell python3 -m pybind11 --includes) -fPIC -O3 -Wall -shared -std=c++11 -fPIC" -LDFLAGS "$(shell python3-config --ldflags) --shared" --clk clk --Mdir build --build -j 0 -Wall --top ras src/sim_main.cpp src/*.sv

clean:
	rm -f *.gv
	rm -f *.gv.pdf
	rm -rf ./build
	rm -f vras.cpython*

