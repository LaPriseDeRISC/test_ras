from vras_python_impl import soft_vras
import vras
import random


def generate_instr(opened_branches, max_elems):
    a = {}
    if opened_branches:
        c = random.randint(0, 7)
        if c == 0:
            a = {"close_valid": 1}
            opened_branches -= 1
        if c == 1:
            a = {"close_invalid": 1}
            opened_branches = 0
            return max_elems, opened_branches, a
    if not random.randint(0, 5):  # 17%
        a = dict(a, **{"branch": 1})
        opened_branches += 1
    if not random.randint(0, 2) and max_elems:  # 33%
        a = dict(a, **{"pop": 1})
        if not opened_branches:
            max_elems -= 1
    if not random.randint(0, 2):  # 33%
        a = dict(a, **{"push": 1, "data_in": random.randint(0, 1 << 31)})
        max_elems += 1
    return max_elems, opened_branches, a


def generate_instrs(nbr):
    instrs = []
    opened_branches = 0
    max_elems = 0
    for i in range(nbr):
        max_elems, opened_branches, inst = generate_instr(opened_branches, max_elems)
        instrs.append(inst)
    return instrs


def compare_ras(instrs_q):
    idx = 0
    sras = soft_vras(1024)
    vras.init()
    vras.process()
    li = {}
    for i in instrs_q:
        if 'close_valid' in li.keys() and 'close_valid' in i.keys():
            print("stall!")
            vras.next_input()
            vras.process()
        empty = vras.empty()
        vras.next_input(**i)
        sras.next_input(**i)
        a = vras.process()
        b = sras.process()
        if empty or ("pop" not in i.keys()):
            a = None
        assert a is None or a == b, "Result mismatch, failed at " +\
                                         str(idx) + " with " + str(a) + ", " + str(b)
        idx += 1
        li = i
    vras.close()
    print("all correct !")

def test(size, ites):
    a = {}
    for i in range(ites):
        a = generate_instrs(size)
        try:
            compare_ras(a)
        except:
            print(i, "/", ites," tests completed")
            return a
    print(ites, " tests completed")