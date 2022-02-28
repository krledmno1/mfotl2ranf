#include "util.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <set>
#include <sstream>
#include <vector>

#define BIT(x, i) (((x)>>(i))&1)

const int groups = 10;

std::mt19937 gen;

std::vector<std::pair<int, int> > r;
std::set<int> s;

std::vector<std::string> l;

int main(int argc, char **argv) {
    if (argc != 6) {
        fprintf(stderr, "sinceuntil TYPE PREFIX_FMLA PREFIX_LOG N LEN\n");
        exit(EXIT_FAILURE);
    }

    int type = atoi(argv[1]);
    int n = atoi(argv[4]);
    int len = atoi(argv[5]);
    gen.seed(len);
    int sfrom = 0;
    int sto = groups;
    int var = BIT(type, 0);
    int neg = BIT(type, 1);
    int future = BIT(type, 2);
    int er = (BIT(type, 3) ? n : 1);

    int int_from = (BIT(type, 3) ? 10 : n);
    int int_to = (BIT(type, 3) ? 20 : 2 * n);

    FILE *f = open_file_type(argv[2], ".mfodl", "w");
    if (var) {
        fprintf(f, "q(x, y) AND (%ss(x) %s[%d,%d] r(x, y))\n", (neg ? "NOT " : ""), (future ? "UNTIL" : "SINCE"), int_from, int_to);
    } else {
        fprintf(f, "q(x, y) AND (%s[%d,%d] r(x, y))\n", (future ? "EVENTUALLY" : "ONCE"), int_from, int_to);
    }
    fclose(f);

    for (int i = 0; i < len; i++) {
        std::stringstream line;
        int rx, ry;
        if (var && !neg) {
            rx = sfrom + gen() % (sto - sfrom);
        } else {
            rx = gen() % len;
        }
        ry = gen() % len;
        r.push_back(std::make_pair(rx, ry));
        s.insert(rx);
        line << " r(" << rx << "," << ry << ")";
        if (var) {
            if (neg) {
                int sx, sy;
                if (gen() % 2 == 0) {
                    int idx = gen() % r.size();
                    sx = r[idx].first;
                } else {
                    sx = gen() % len;
                }
                line << " s(" << sx << ")";
            } else {
                for (auto &it : s) {
                    if (gen() % len  == 0) continue;
                    line << " s(" << it << ")";
                }
            }
        }
        int qx, qy;
        int qfrom = std::max(0, (i / er - int_to)) * er;
        int qto = std::max(0, i / er - (int_from - 1)) * er;
        if (qfrom != qto && gen() % 2 == 0) {
            int idx = qfrom + gen() % (qto - qfrom);
            qx = r[idx].first;
            qy = r[idx].second;
        } else {
            qx = gen() % len;
            qy = gen() % len;
        }
        line << " q(" << qx << "," << qy << ")";
        l.push_back(line.str());
    }
    FILE *log = open_file_type(argv[3], ".log", "w");
    for (int i = 0; i < l.size(); i++) {
        fprintf(log, "@%d%s\n", i / er, l[future ? l.size() - 1 - i : i].c_str());
    }
    fclose(log);
    FILE *slog = open_file_type(argv[3], ".slog", "w");
    for (int i = 0; i < l.size(); i++) {
        fprintf(slog, "@%d%s;\n", i / er, l[future ? l.size() - 1 - i : i].c_str());
    }
    fclose(slog);

    return 0;
}
