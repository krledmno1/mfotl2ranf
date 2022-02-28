tools = {
    "monpoly": {
        "exec": "/home/mfotlranf/monpoly/monpoly", "fmla": ".mfodl", "fmla_flag": "-formula", "log": ".log", "log_flag": "-log", "flags": "-sig fmlas/vmon.sig", "pre_flags": "", "script": False
    },
    "verimon": {
        "exec": "/home/mfotlranf/monpoly/monpoly", "fmla": ".mfodl", "fmla_flag": "-formula", "log": ".log", "log_flag": "-log", "flags": "-sig fmlas/vmon.sig -verified", "pre_flags": "", "script": False
    },
}

formats = ["monpoly"]

def exp_sinceuntil_er(typ):
    return {"typ": "gen_exp", "gen": "gen_sinceuntil {}".format(typ ^ 8), "range": range(20, 220, 60), "fmlas": 1, "len": 20000, "tools": ["monpoly", "verimon"]}

def exp_sinceuntil_int(typ):
    return {"typ": "gen_exp", "gen": "gen_sinceuntil {}".format(typ), "range": range(200, 2200, 600), "fmlas": 1, "len": 20000, "tools": ["monpoly", "verimon"]}

exps = {
    "exp_sinceuntil_er_once": exp_sinceuntil_er(0),
    "exp_sinceuntil_er_since": exp_sinceuntil_er(1),
    "exp_sinceuntil_er_not_since": exp_sinceuntil_er(3),
    "exp_sinceuntil_er_eventually": exp_sinceuntil_er(4),
    "exp_sinceuntil_er_until": exp_sinceuntil_er(5),
    "exp_sinceuntil_er_not_until": exp_sinceuntil_er(7),
    "exp_sinceuntil_int_once": exp_sinceuntil_int(0),
    "exp_sinceuntil_int_since": exp_sinceuntil_int(1),
    "exp_sinceuntil_int_not_since": exp_sinceuntil_int(3),
    "exp_sinceuntil_int_eventually": exp_sinceuntil_int(4),
    "exp_sinceuntil_int_until": exp_sinceuntil_int(5),
    "exp_sinceuntil_int_not_until": exp_sinceuntil_int(7),
}

exp_config = {"reps": 1, "timeout": "200", "aggr": "median"}

def plot_sinceuntil_er(case):
    return {"case": case, "short": "", "title": True, "graph_type": "points", "size": "5,3", "xlabel": "Parameter (er x 10)", "xrange": "[0:22]", "yrange": {"time": "[0.001:180]", "space": "[0:100]"}, "log": {"x": None, "y": 10}, "xscale": 10}

def plot_sinceuntil_int(case):
    return {"case": case, "short": "", "title": True, "graph_type": "points", "size": "5,3", "xlabel": "Parameter (n x 100)", "xrange": "[0:22]", "yrange": {"time": "[0.001:180]", "space": "[0:100]"}, "log": {"x": None, "y": 10}, "xscale": 100}

plot_config_exp = {
    "exp_sinceuntil_er_once": plot_sinceuntil_er("Once"),
    "exp_sinceuntil_er_since": plot_sinceuntil_er("Since"),
    "exp_sinceuntil_er_not_since": plot_sinceuntil_er("Not Since"),
    "exp_sinceuntil_er_eventually": plot_sinceuntil_er("Eventually"),
    "exp_sinceuntil_er_until": plot_sinceuntil_er("Until"),
    "exp_sinceuntil_er_not_until": plot_sinceuntil_er("Not Until"),
    "exp_sinceuntil_int_once": plot_sinceuntil_int("Once"),
    "exp_sinceuntil_int_since": plot_sinceuntil_int("Since"),
    "exp_sinceuntil_int_not_since": plot_sinceuntil_int("Not Since"),
    "exp_sinceuntil_int_eventually": plot_sinceuntil_int("Eventually"),
    "exp_sinceuntil_int_until": plot_sinceuntil_int("Until"),
    "exp_sinceuntil_int_not_until": plot_sinceuntil_int("Not Until"),
}

plot_config_misc = {
    "font": "Times-Roman",
    "fontsize": "30",
    "keys": False,
}

plot_config_tools = {
    "monpoly": {"name": "MONPOLY", "pointtype": 6, "color": "\"0x00AA00\""},
    "verimon": {"name": "VERIMON", "pointtype": 4, "color": "\"0x0000FF\""},
}

plot_config_types = {
    "time": {"name": "Time Complexity", "ylabel": "Time [s]", "short": False},
    "space": {"name": "Space Complexity", "ylabel": "Space [MB]", "short": False}
}
