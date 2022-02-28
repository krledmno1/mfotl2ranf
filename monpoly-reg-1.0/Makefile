BIN = ~/bin/

all: monpoly-reg

.PHONY: monpoly-reg doc clean clean-all depend 

monpoly-reg: 
	cd src && $(MAKE) monpoly-reg
	mv src/monpoly-reg .

install: monpoly-reg
	cp -v monpoly-reg $(BIN)

doc: 
	cd src && $(MAKE) doc


clean: 
	cd src && $(MAKE) clean


clean-all: clean
	rm -f monpoly-reg
	rm -f doc/*
	rm -f $(BIN)monpoly-reg

depend:
	cd src && $(MAKE) depend


