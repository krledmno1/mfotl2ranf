#include <cassert>
#include <cstdio>
#include <map>
#include <random>
#include <set>
#include <sstream>
#include <vector>

std::mt19937 gen;

FILE *open_file_type(const char *prefix, const char *ftype, const char *mode) {
    std::ostringstream oss;
    oss << prefix << ftype;
    return fopen(oss.str().c_str(), mode);
}

void write_event(FILE *log, FILE *csv, FILE *timed_csv, int ts, int type, int x, int y) {
    const char *name = (type == 0 ? "acq" : type == 1 ? "rel" : type == 2 ? "read" : "write");
    fprintf(log, "@%d %s(%d,%d)\n", ts, name, x, y);
    fprintf(csv, "%s,%d,%d\n", name, x, y);
    fprintf(timed_csv, "%s,%d,%d,%d\n", name, x, y, ts);
}

void usage() {
  fprintf(stderr, "races PREFIX LEN NUMTH NUMLOCK NUMVAR SEED\n");
  exit(EXIT_FAILURE);
}

int main(int argc, char **argv) {
  if (argc != 7) usage();

  int len = atoi(argv[2]);
  int numth = atoi(argv[3]);
  int numlock = atoi(argv[4]);
  int numvar = atoi(argv[5]);
  int seed = atoi(argv[6]);
  gen.seed(seed);

  std::vector<int> lock(numvar), lock_var(numlock);
  for (int i = 0; i < numvar; i++) {
    lock[i] = gen() % numlock;
    lock_var[lock[i]]++;
  }

  FILE *log = open_file_type(argv[1], ".log", "w");
  FILE *csv = open_file_type(argv[1], ".csv", "w");
  FILE *timed_csv = open_file_type(argv[1], ".timed.csv", "w");

  std::vector<std::set<int> > has(numth);
  std::vector<int> taken(numlock, -1);
  std::set<int> ths, locks, vars;
  int total_lock = 0, total_var = 0;
  for (int i = 0; i < len; i++) {
    int th, l, x;
    int done = 0;
    while (!done) {
      int op = gen() % 7;
      switch (op) {
        case 0:
        case 1:
          if (total_lock == numlock) break;
          do {
            th = gen() % numth;
            l = gen() % numlock;
          } while (taken[l] != -1);
          write_event(log, csv, timed_csv, i, 0, th, l);
          ths.insert(th);
          locks.insert(l);
          has[th].insert(l);
          taken[l] = th;
          total_lock++;
          total_var += lock_var[l];
          done = 1;
          break;
        case 2:
          if (total_lock == 0) break;
          do {
            l = gen() % numlock;
          } while (taken[l] == -1);
          th = taken[l];
          write_event(log, csv, timed_csv, i, 1, th, l);
          ths.insert(th);
          locks.insert(l);
          has[th].erase(has[th].find(l));
          taken[l] = -1;
          total_lock--;
          total_var -= lock_var[l];
          done = 1;
          break;
        case 3:
        case 5:
          if (total_var == 0) break;
          do {
            x = gen() % numvar;
          } while (taken[lock[x]] == -1);
          th = taken[lock[x]];
          write_event(log, csv, timed_csv, i, op == 3 ? 2 : 3, th, x);
          ths.insert(th);
          vars.insert(x);
          done = 1;
          break;
        case 4:
        case 6:
          if (total_lock == 0 || total_var == numvar) break;
          do {
            th = gen() % numth;
            x = gen() % numvar;
          } while (has[th].empty() || has[th].find(lock[x]) != has[th].end());
          write_event(log, csv, timed_csv, i, op == 4 ? 2 : 3, th, x);
          ths.insert(th);
          vars.insert(x);
          done = 1;
          break;
        default:
          assert(0);
          break;
      }
    }
  }

  fclose(log);
  fclose(csv);
  fclose(timed_csv);

  FILE *bits = open_file_type(argv[1], ".bits", "w");
  int m = std::max(ths.size(), std::max(locks.size(), vars.size()));
  int b = 1;
  while ((1 << b) - 1 < m) b++;
  fprintf(bits, "%d", b);
  fclose(bits);

  return 0;
}
