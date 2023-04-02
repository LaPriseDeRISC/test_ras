class soft_vras:
    def __init__(self, size):
        self.data = [0] * size
        self.branches = []
        self.pop = False
        self.push = False
        self.branch = False
        self.close_valid = False
        self.close_invalid = False
        self.data_in = 0
        self.nb_elems = 0
        self.size = size
        self.ofs = 0

    def next_input(self, pop=False, push=False,
                   branch=False, close_valid=False,
                   close_invalid=False, data_in=0):
        self.pop = pop
        self.push = push
        self.branch = branch
        self.close_valid = close_valid
        self.close_invalid = close_invalid
        self.data_in = data_in

    def process(self):
        out = None
        if self.close_valid:
            del self.branches[0]
        if self.close_invalid:
            self.data, self.nb_elems, self.ofs = self.branches[0]
            self.branches = []
        if self.pop and self.nb_elems > 0:
            out = self.data[(self.nb_elems + self.ofs) % self.size]
            self.nb_elems -= 1
        if self.push:
            self.nb_elems += 1
            if self.nb_elems > self.size:
                self.ofs = (self.ofs + 1) % self.size
                self.nb_elems = self.size
            self.data[(self.nb_elems + self.ofs) % self.size] = self.data_in
        if self.branch:
            self.branches.append(([i for i in self.data], self.nb_elems, self.ofs))
        return out

