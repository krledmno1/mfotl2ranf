(*
 * This file is part of MonaPoly-Reg.
 * Copyright (C) 2014 ETH Zurich.
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, version 2.1 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program. If not, see
 * http://www.gnu.org/licenses/lgpl-2.1.html. 
 *)


type dfa

type dfaProductType =
  | PT_Impl
  | PT_Equiv
  | PT_And
  | PT_Or


(* All MONA stubs are in dfa_stubs.c *)

(* implementations in mona/DFA/ (see dfa.h) *)
external dfaTrue: unit -> dfa = "caml_mona_dfaTrue" 
external dfaFalse: unit -> dfa = "caml_mona_dfaFalse" 
external dfaEq2: int -> int -> dfa = "caml_mona_dfaEq2" 
external dfaPresbConst: int -> int -> dfa = "caml_mona_dfaPresbConst" 

external dfaNegation: dfa -> unit = "caml_mona_dfaNegation" 
external dfaProduct: dfa -> dfa -> dfaProductType -> dfa = "caml_mona_dfaProduct"
external dfaProject: dfa -> int -> dfa = "caml_mona_dfaProject" 
external dfaMinimize: dfa -> dfa = "caml_mona_dfaMinimize" 
external dfaReplaceIndices: dfa -> int array -> unit = "caml_mona_dfaReplaceIndices" 

external dfaPrint: dfa -> int -> string array -> int array -> unit = "caml_mona_dfaPrint" 
external dfaPrintVerbose: dfa -> unit = "caml_mona_dfaPrintVerbose" 
external dfaPrintGraphviz: dfa -> int -> int array -> unit = "caml_mona_dfaPrintGraphviz" 

external dfaCopy: dfa -> dfa = "caml_mona_dfaCopy" 
external dfaImport: string -> dfa = "caml_mona_dfaImport" 

external print_dfa: dfa -> string -> unit = "caml_mona_print_dfa" 

(* ours, implemented in dfa_aux.c *)
external isFinite: dfa -> int -> bool = "caml_isFinite"
external allWords: dfa -> int -> int array -> string = "caml_allWords"

(* ours, implemented in dfa_stubs.c *)
external numberOfStates: dfa -> int = "caml_numberOfStates"
external isFinal: dfa -> int -> bool = "caml_isFinal"


