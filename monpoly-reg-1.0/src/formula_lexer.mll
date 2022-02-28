(*
 * This file is part of MonPoly-Reg.
 *
 * Copyright © 2011 Nokia Corporation and/or its subsidiary(-ies).
 * Contact:  Nokia Corporation (Debmalya Biswas: debmalya.biswas@nokia.com)
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
 *)



{
  open Formula_parser
  open Misc

  let f lexbuf = 
    if Misc.debugging Dbg_formula then
      Printf.printf "[Formula_lexer] lexbuf is  ---%s---\n" (Lexing.lexeme lexbuf) 
    else
      ()

  let my_int_of_string str = 
    try 
      int_of_string str
    with Failure "int_of_string" -> failwith "[formula_lexer, int_of_string]"

  let get_ts lxm = 
    Scanf.sscanf lxm "%d%c" (fun n -> fun c -> (n,c))
}

let lc = ['a'-'z']
let uc = ['A'-'Z']
let letter = uc | lc
let digit = ['0'-'9']
let integer = digit*
let unit =  digit+ letter
let string = (letter | digit | '_' | '\'' | '\"' | '/' | ':' | '-')*

rule 
  token = parse
  | [' ' '\t' '\n' '\r']      	{ f lexbuf; token lexbuf }

  | "."              		{ f lexbuf; DOT }
  | "*"              		{ f lexbuf; INF }
  | "("				{ f lexbuf; LPA }
  | ")"				{ f lexbuf; RPA }
  | "["				{ f lexbuf; LSB }
  | "]"				{ f lexbuf; RSB }
  | ","				{ f lexbuf; COM }
  | "?"				{ f lexbuf; QM }
  | "="				{ f lexbuf; EQ }
  | "<"				{ f lexbuf; LESS }
  | "NOT"                       { f lexbuf; NOT }
  | "AND"                       { f lexbuf; AND }
  | "OR"                        { f lexbuf; OR }
  | "IMPLIES"                   { f lexbuf; IMPL }
  | "EQUIV"                     { f lexbuf; EQUIV }
  | "EXISTS"                    { f lexbuf; EX }
  | "FORALL"                    { f lexbuf; FA }
  | "PREVIOUS"                  { f lexbuf; PREV }
  | "NEXT"                      { f lexbuf; NEXT }
  | "EVENTUALLY"                { f lexbuf; EVENTUALLY }
  | "SOMETIMES"                 { f lexbuf; EVENTUALLY }
  | "ONCE"                      { f lexbuf; ONCE }
  | "ALWAYS"                    { f lexbuf; ALWAYS }
  | "PAST_ALWAYS"               { f lexbuf; PAST_ALWAYS }
  | "HISTORICALLY"              { f lexbuf; PAST_ALWAYS }
  | "SINCE"                     { f lexbuf; SINCE }
  | "UNTIL"                     { f lexbuf; UNTIL }

  | unit as lxm                 { f lexbuf; TU (get_ts lxm)}
  | integer as lxm              { f lexbuf; NUM (int_of_string lxm) }
  | string as lxm		{ f lexbuf; STR lxm }
 
  | "(*"                        { f lexbuf; comment lexbuf } 
  | "#"                         { f lexbuf; line_comment lexbuf}

  | eof				{ f lexbuf; EOF }

  

and 
  line_comment = parse
  | ['\n' '\r']                 { f lexbuf; token lexbuf }
  | _                           { f lexbuf; line_comment lexbuf }
  | eof				{ f lexbuf; EOF }

and 
  comment = parse
  | "*)"                        { f lexbuf; token lexbuf }
  | _                           { f lexbuf; comment lexbuf }
  | eof                         { f lexbuf; failwith "comment not ended" }
