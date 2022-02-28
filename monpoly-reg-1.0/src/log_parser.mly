/*
 * This file is part of MonPoly-Reg.
 *
 * Copyright © 2011 Nokia Corporation and/or its subsidiary(-ies).
 * Contact:  Nokia Corporation (Debmalya Biswas: debmalya.biswas@nokia.com)
 * 
 * Copyright (C) 2012-2014 ETH Zurich.
 * Contact:  ETH Zurich (Eugen Zalinescu: eugen.zalinescu@inf.ethz.ch)
 * 
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation, version 2.1 of the
 * License.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * http://www.gnu.org/licenses/lgpl-2.1.html.
 *
 * As a special exception to the GNU Lesser General Public License,
 * you may link, statically or dynamically, a "work that uses the
 * Library" with a publicly distributed version of the Library to
 * produce an executable file containing portions of the Library, and
 * distribute that executable file under terms of your choice, without
 * any of the additional requirements listed in clause 6 of the GNU
 * Lesser General Public License. By "a publicly distributed version
 * of the Library", we mean either the unmodified Library as
 * distributed by Nokia, or a modified version of the Library that is
 * distributed under the conditions defined in clause 3 of the GNU
 * Lesser General Public License. This exception does not however
 * invalidate any other reasons why the executable file might be
 * covered by the GNU Lesser General Public License.
 */



%{
  open Strmap
  open Misc
  open Predicate
  open MFOTL
  open Db
  open Mona


  let f str = 
    if Misc.debugging Dbg_log then
      Printf.printf "[Log_parser] %s with start=%d and end=%d\n%!" 
	str (symbol_start()) (symbol_end())
    else
      ()


  let sign = ref Strmap.empty


  let update_sign pred = 
    let name, type_list = pred in
    if Strmap.mem name !sign then
      let err_str = Printf.sprintf 
	"[Log_parser] Predicate %s already declared." name 
      in
      failwith err_str
    else
      sign := Strmap.add name type_list !sign
    

  let get_type = function
    | "int" -> TInt
    | "string" -> TStr
    | t -> let spos = Parsing.symbol_start_pos() in
	   let str = Printf.sprintf 
	     "[Log_parser.check_fields] Unknown type %s in signature at line %d."
	     t spos.Lexing.pos_lnum
	   in
	   failwith str

  let make_predicate =
    List.map 
      (fun str -> 
	match Str.split (Str.regexp ":") str with
	  | [type_str] | [_; type_str] -> get_type type_str
	  | _ -> failwith "[Log_parser.make_predicate] internal error"
      )


  (* let make_predicate = *)
  (*   List.map  *)
  (*     (fun str ->  *)
  (* 	 match str with *)
  (* 	   | "int" -> TInt *)
  (* 	   | "string" -> TStr *)
  (* 	   | t ->  *)
  (* 	       let spos = Parsing.symbol_start_pos() in *)
  (* 	       let err_str = Printf.sprintf  *)
  (* 		 "[Log_parser.check_fields] Unknown type %s in signature at line %d." *)
  (* 		 t spos.Lexing.pos_lnum *)
  (* 	       in *)
  (* 	       failwith err_str *)
  (*     ) *)




  let get_schema pname =  
    try
      Strmap.find pname !sign
    with Not_found -> 
      let spos = Parsing.symbol_start_pos() in
      let str = Printf.sprintf 
	"[Log_parser.get_schema] The predicate %s at line %d was not found in the signature." 
	pname spos.Lexing.pos_lnum
      in
      failwith str



  let process_tuple pname ar tuple = 
    let exit_err str = 
      let suffix =  Printf.sprintf " for predicate %s. See line %d in the log file."
	pname (Parsing.symbol_start_pos()).Lexing.pos_lnum
      in
      failwith (str ^ suffix)
    in
    if List.length tuple = ar then 
      try
	List.map (fun str -> 
	  let n = int_of_string str in
	    if n < 0 then exit_err "[Log_parser] Negative constant in tuple"
	    else n	  
	) tuple
      with Failure "int_of_string" -> exit_err "[Log_parser] Wrong type of a tuple field"
    else 
      exit_err "[Log_parser] Wrong tuple length"


  (* [rel] is a list of tuples of type Tuple.tuple *)
  let rel_to_aut p rel = 
    let get_idx = 
      if !Misc.p_idxs = Strmap.empty then
	fun pos -> pos
      else
	try
	  let p_arr = Strmap.find p !Misc.p_idxs in
	  fun pos -> p_arr.(pos)
	with Not_found -> 
	  fun pos -> pos
    in
    List.fold_left (fun aut_rel tuple ->
      let pos = ref 0 in
      let aut_tuple =
    	List.fold_left 
	  (fun aut_t field -> 
    	     let aut_field = Mona.dfaPresbConst (get_idx !pos) field in
    	     incr pos;
    	     Mona.dfaProduct aut_t aut_field PT_And
    	  ) (Mona.dfaTrue ()) tuple
      in 
      Mona.dfaProduct aut_rel aut_tuple PT_Or
    ) (Mona.dfaFalse()) rel


      
  (* A tuple in [tuples] is a list of strings here, not a value of
     type Tuple.tuple *)
  let make_table p tuples = 
    let type_list = get_schema p in
    List.iter (fun ty -> (match ty with 
      | TStr -> 
	failwith "[Log_parser] Strings are not supported (modify the signature)" 
      | TInt -> ())
    ) type_list;  
  let ar = List.length type_list in
  (* we only reverse because [rev_map] is tail-recursive, while [map] is not *)
  let rel = List.rev_map (process_tuple p ar) tuples in
  p, rel_to_aut p rel


  (* db is seen here as an association list *) 
  let add_table named_aut db =
    let p, dfa = named_aut in
    if Strmap.mem p db then
      let dfa' = Strmap.find p db in
      let db = Strmap.remove p db in
      let new_dfa = Mona.dfaProduct dfa dfa' PT_Or in
      Strmap.add p new_dfa db
    else
      Strmap.add p dfa db

%}




%token AT LPA RPA COM 
%token <string> STR 
%token EOF 
%token ERR

%start signature
%type <(Db.schema)> signature

%start tsdb
%type <(MFOTL.timestamp * Db.db) option> tsdb

%%


signature:
      | predicate signature     { f "signature(list)"; update_sign $1; !sign }
      |                         { f "signature(end)"; !sign }

predicate:
      | STR LPA fields RPA      { f "predicate"; ($1, make_predicate $3) }




tsdb:
      | AT STR db AT            { f "tsdb(next)"; 
				  Some (MFOTL.ts_of_string "Log_parser" $2, $3) }
      | AT STR db EOF           { f "tsdb(last)"; 
				  Some (MFOTL.ts_of_string "Log_parser" $2, $3) }
      | AT EOF                  { f "tsdb(ts eof)"; None }
      | EOF                     { f "tsdb(eof)"; None }

      | AT STR error AT         { f "tsdb(next-err)"; 
				  if !Misc.ignore_parse_errors then
				    Some (ts_invalid, Strmap.empty) 
				  else
				    raise Parsing.Parse_error
				}

      | AT STR error EOF        { f "tsdb(last-err)"; 
				  if !Misc.ignore_parse_errors then
				    Some (ts_invalid, Strmap.empty)
				  else
				    raise Parsing.Parse_error
				}

db:
      | table db                { f "db(list)"; add_table $1 $2}
      |                         { f "db()"; Strmap.empty }

table:
      | STR relation            { f "table"; 
				  try
				    make_table $1 $2 
				  with (Failure str) as e -> 
				    if !Misc.ignore_parse_errors then
				      begin
					prerr_endline str;
					raise Parsing.Parse_error
				      end
				    else
				      raise e				
				}

relation:
      | tuple relation          { f "relation(list)"; $1::$2 }
      |                         { f "relation(end)"; [] }

tuple: 
      | LPA fields RPA          { f "tuple"; $2 }


fields:
      | STR COM fields	        { f "fields(list)"; $1::$3 }
      | STR 	                { f "fields(end)"; [$1] }
      |  	                { f "fields()"; [] }


      

