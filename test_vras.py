import vras
import graphviz


def get_infos():
    raw_infos = vras.raw_info()
    branch_infos = vras.branch_infos()
    names = ["alloc_addr", "last_alloc_addr",
             "in_branch", "branch_list_empty",
             "current_branch_has_added", "current_branch_has_suppressed",
             "BOSP"]
    out = dict(zip(names, raw_infos))
    struct_map = {"vector_size_is_one": 1, "vector_size_is_two": 1,
                  "vector_previous": 4, "vector_head": 4,
                  "vector_second": 4, "vector_third": 4,
                  "vector_tail": 4, "vector_next": 4}
    idx = sum(struct_map.values())
    for (k, v) in struct_map.items():
        idx -= v
        out[k] = (branch_infos & (((1 << v) -1) << idx)) >> idx
    return out


def print_graph():
    prev = vras.prev_links()
    next = vras.next_links()
    data = vras.data()
    infos = get_infos()
    dot = graphviz.Digraph(comment='Vras')
    dot.attr(rankdir='LR')
    indexes_avail = list(range(len(data)))
    i = infos["BOSP"]
    with dot.subgraph() as s: # preserved
        s.attr(rank='same')
        first = True
        while i != (infos["ef_start"] if infos["in_branch"] else infos["pop_head"]) and i in indexes_avail:
            del indexes_avail[indexes_avail.index(i)] # remove from index_avail
            i = prev[i]
            s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#EEEEEE')
            s.edge(str(i), str(prev[i]), color='red')
            if not first:
                s.edge(str(i), str(next[i]), color='blue')
            first = False
    if infos["in_branch"]:
        if infos["has_suppressed"]:
            with dot.subgraph() as s: # deleted
                s.attr(rank='same')
                while i != infos["s_head"] and i in indexes_avail:
                    del indexes_avail[indexes_avail.index(i)] # remove from index_avail
                    i = prev[i]
                    s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#E9DF00')
                    s.edge(str(i), str(prev[i]), color='red')
                    s.edge(str(i), str(next[i]), color='blue')
        if infos["has_added"]:
            with dot.subgraph() as s: # added
                s.attr(rank='same')
                while i != infos["pop_head"] and i in indexes_avail:
                    del indexes_avail[indexes_avail.index(i)] # remove from index_avail
                    i = prev[i]
                    s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#5C9EAD')
                    s.edge(str(i), str(prev[i]), color='red')
                    s.edge(str(i), str(next[i]), color='blue')
    with dot.subgraph() as s: # free
        s.attr(rank='same')
        while i != infos["BOSP"] and i in indexes_avail:
            del indexes_avail[indexes_avail.index(i)] # remove from index_avail
            i = prev[i]
            s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#FFFFFF')
            s.edge(str(i), str(prev[i]), color='red')
    with dot.subgraph() as s: # lost_idx
        s.attr(rank='same')
        for lost_i in indexes_avail:
            s.node(str(lost_i), str(lost_i)+": "+str(data[lost_i]), style='filled', fillcolor='#E39774')
            s.edge(str(lost_i), str(prev[lost_i]), color='red')
            s.edge(str(lost_i), str(next[lost_i]), color='blue')
    dot.view()


def push(v, verbose=False):
    vras.next_input(push=1, data_in=v)
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()


def pop(verbose=False):
    out = vras.next_input(pop=1)
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()
    if vras.output_valid():
        return out
    return None


def branch(verbose=False):
    vras.next_input(branch=1)
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()


def close_valid(verbose=False):
    vras.next_input(close_valid=1)
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()


def close_invalid(verbose=False):
    vras.next_input(close_invalid=1)
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()


def nop(verbose=False):
    vras.next_input()
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()


def init():
    vras.init()
    vras.next_input()
    vras.process()
    print_graph()

"""
from test_vras import *
init()
push(1)
push(2)
push(3)
push(4)
branch()
pop()
push(5)
print(get_infos())
vras.next_input(close_valid=1, push=1, data_in=6)
print(get_infos())
vras.process()
print(get_infos())
vras.next_input()
print(get_infos())
vras.process()
print(get_infos())

print_graph()
print(get_infos())

close_valid()
print(get_infos())
nop()
print(get_infos())
"""