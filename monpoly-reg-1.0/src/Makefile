OCAMLOPT = ocamlopt
OCAMLC = ocamlc

# Set here which complier will be used
OCAML = $(OCAMLOPT)
# FLAGS = -p
# FLAGS = -ccopt -static

ifeq "$(OCAML)" "$(OCAMLOPT)"
  O = cmx
  A = cmxa
  LIBS = unix.$(A) str.$(A) 
  OCAMLDEPFLAGS = -native
else
  O = cmo
  A = cma
  LIBS = -custom unix.$(A) str.$(A)
endif

OCAMLEXE = $(OCAML) $(FLAGS) $(LIBS)


# The list of interface files
MLI = strmap.mli mona.mli misc.mli predicate.mli MFOTL.mli \
      aut.mli dfa_store.mli db.mli rewriting.mli perf.mli

OURMLI = $(MLI) log.mli algorithm.mli

ALLMLI = $(OURMLI) formula_parser.mli log_parser.mli


# The lists of implementation files
OURML = $(OURMLI:.mli=.ml) main.ml
ALLML = $(ALLMLI:.mli=.ml) main.ml

# The lists of object files
OBJML = $(MLI:.mli=.$(O)) \
       formula_parser.$(O) log_parser.$(O) \
       formula_lexer.$(O) log_lexer.$(O) \
       log.$(O) algorithm.$(O) 

OBJ = $(OBJML) dfa_aux.o dfa_stubs.o
OBJCMO = $(OBJML:.$(O)=.cmo)
OBJCMX = $(OBJML:.$(O)=.cmx)

DIRLIBS = /usr/local/lib
CCLIBS = -cclib '-lmonadfa -lmonabdd -lmonamem'
# CCLIBS = -cclib -static /usr/local/lib/libmonadfa.a \
# /usr/local/lib/libmonabdd.a /usr/local/lib/libmonamem.a

# Targets
all: monpoly-reg

monpoly-reg: .depend $(OBJ) version.ml main.ml mona.cmi
	$(OCAMLEXE) -I $(DIRLIBS) $(OBJ) version.ml main.ml $(CCLIBS) -o $@ 

dfa_aux.o: dfa_aux.c dfa_aux.h
	cc -c -I mona/Mem -I mona/BDD -I mona/DFA -I /home/mfotlranf/.opam/4.05.0/lib/ocaml dfa_aux.c

dfa_stubs.o: dfa_stubs.c
	cc -c -I mona/Mem -I mona/BDD -I mona/DFA -I /home/mfotlranf/.opam/4.05.0/lib/ocaml dfa_stubs.c

# update version with the latest revision number
version.ml: FORCE
	@echo "let ver = \"1.0 (`svnversion -cn`)\"" > version.ml
FORCE:


# Documentation
doc: $(OURMLI:.mli=.cmi)
	ocamldoc -html -d ../doc $(OURMLI)


# Clean-up
clean:
	rm -f .depend.init .depend
	rm -f *.cm[aiox] *.cmxa *.o
	rm -f *parser.mli *parser.ml *lexer.ml version.ml
	rm -f *~


# Dependencies
%.cmi: %.mli
	$(OCAMLC) -c $<

%.cmo: %.ml
	$(OCAMLC) $(FLAGS) -c $<

%.cmx: %.ml
	$(OCAMLOPT) $(FLAGS) -c $<

%.ml: %.mll
	ocamllex $<

%.ml: %.mly
	ocamlyacc $<

%.mli: %.mly
	ocamlyacc $<

.depend: .depend.init $(ALLMLI) $(ALLML) mona.mli
	ocamldep $(OCAMLDEPFLAGS) $(ALLMLI) mona.mli $(ALLML) > .depend

.depend.init: 
	ocamldep $(OCAMLDEPFLAGS) $(OURMLI) $(OURML) > .depend.init

depend: .depend

-include .depend











