all: mfotl2ranf.native mfotl2reg.native

mfotl2ranf.native: mfotl2ranf.ml trans.ml FO.ml Misc.ml log_lexer.mll log_parser.mly fo_lexer.mll fo_parser.mly verified.ml
	ocamlbuild -use-menhir -package zarith mfotl2ranf.native
	cp mfotl2ranf.native ../mfotl2ranf

mfotl2reg.native: mfotl2reg.ml FO.ml Misc.ml fo_lexer.mll fo_parser.mly
	ocamlbuild -use-menhir -package zarith mfotl2reg.native
