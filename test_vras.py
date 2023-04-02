import vras
import graphviz


def _get_vec_info(vec):
    fields = {"size": 2, "previous": 4,
              "head": 4, "second": 4,
              "third": 4, "tail": 4,
              "next": 4}
    out = {}
    idx = sum(fields.values())
    for k in fields.keys():
        idx -= fields[k]
        out[k] = (vec >> idx) & ((1 << fields[k]) - 1)
    return out


def get_infos():
    vras.next_input()
    raw_infos = vras.raw_info()
    names = ["prev_tosp", "tosp", "empty_start", "empty_next",
             "in_branch", "on_branch", "branch_has_suppressed",
             "branch_tosp", "branch_empty_start",
             "branch_empty_next",
             "branch_initial_tosp", "branch_initial_empty_start",
             "bosp"]
    return dict(zip(names, raw_infos))


def print_graph():
    vras.next_input()
    prev = vras.free_slots()
    next = vras.next_links()
    data = vras.data()
    infos = get_infos()
    dot = graphviz.Digraph(comment='Vras')
    dot.attr(rankdir='LR')
    indexes_avail = list(range(len(data)))
    with dot.subgraph() as s: # current elems
        #s.attr(rank='same')
        i = infos["tosp"]
        while i != infos["bosp"]:
            if not i in indexes_avail:
                break
            del indexes_avail[indexes_avail.index(i)] # remove from index_avail
            s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#EEEEEE')
            s.edge(str(i), str(next[i]), color='blue')
            s.edge(str(i), str(prev[i]), color='red')
            i = next[i]
    if infos["in_branch"] and infos["branch_has_suppressed"]:
        with dot.subgraph() as s: # deleted
            #s.attr(rank='same')
            i = infos["branch_empty_start"]
            while i != infos["branch_initial_empty_start"]:
                if not i in indexes_avail:
                    break
                del indexes_avail[indexes_avail.index(i)] # remove from index_avail
                s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#E9DF00')
                s.edge(str(i), str(prev[i]), color='red')
                s.edge(str(i), str(next[i]), color='blue')
                i = prev[i]
    with dot.subgraph() as s: # free
        #s.attr(rank='same')
        i = infos["empty_start"]
        while i != infos["bosp"]:
            if not i in indexes_avail:
                break
            del indexes_avail[indexes_avail.index(i)] # remove from index_avail
            s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#FFFFFF')
            s.edge(str(i), str(prev[i]), color='red')
            i = prev[i]
        s.node(str(i), str(i)+": "+str(data[i]), style='filled', fillcolor='#FFFFFF')
        s.edge(str(i), str(prev[i]), color='red')
        if i in indexes_avail:
            del indexes_avail[indexes_avail.index(i)] # remove from index_avail
    with dot.subgraph() as s: # lost_idx
        #s.attr(rank='same')
        for lost_i in indexes_avail:
            s.node(str(lost_i), str(lost_i)+": "+str(data[lost_i]), style='filled', fillcolor='#E39774')
            s.edge(str(lost_i), str(prev[lost_i]), color='red')
            s.edge(str(lost_i), str(next[lost_i]), color='blue')
    dot.view()

def popnpush(v, verbose=False):
    empty = vras.empty()
    vras.next_input(pop=1, push=1, data_in=v)
    if verbose:
        get_infos()
    out = vras.process()
    if verbose:
        get_infos()
    print_graph()
    if not empty:
        return out
    return None


def push(v, verbose=False):
    vras.next_input(push=1, data_in=v)
    if verbose:
        get_infos()
    vras.process()
    if verbose:
        get_infos()
    print_graph()


def pop(verbose=False):
    empty = vras.empty()
    vras.next_input(pop=1)
    if verbose:
        get_infos()
    out = vras.process()
    if verbose:
        get_infos()
    print_graph()
    if not empty:
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


def close_valid(pop=False, push=None, verbose=False):
    empty = vras.empty()
    vras.next_input(close_valid=1, pop=pop, push=(push is not None), data_in=(push if push is not None else 0))
    if verbose:
        get_infos()
    out = vras.process()
    if verbose:
        get_infos()
    print_graph()
    if pop and not empty:
        return out


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


def step_exec_instrs(instrs):
    init()
    for i in instrs:
        print(i)
        empty = vras.empty()
        vras.next_input(**i)
        out = vras.process()
        if 'pop' in i.keys() and not empty:
            print("output :", out)
        print(get_infos())
        print_graph()
        input()
