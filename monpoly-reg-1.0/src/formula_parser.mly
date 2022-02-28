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
  open Predicate
  open MFOTL
  open Misc

  let f str = 
    if Misc.debugging Dbg_formula then
      Printf.printf "[Formula_parser] %s\t\n" str
    else
      ()

(* by default, the time unit is of 1 second *)
  let timeunits (n,c) = 
    let d = 
      match c with
	| 'd' -> 24 * 60 * 60
	| 'h' -> 60 * 60
	| 'm' -> 60
	| 's' -> 1
	| _ -> failwith "[Formula_parser.time_units] unrecognized time unit"
    in  
    d * n

  let rec exists varlist f =
    match varlist with
      | [] -> failwith "[Formula_parser.exists] no variables"
      | [v] -> Exists (v,f)
      | v::t -> Exists (v, exists t f)

  let rec forall varlist f =
    match varlist with
      | [] -> failwith "[Formula_parser.forall] no variables"
      | [v] -> ForAll (v,f)
      | v::t -> ForAll (v, forall t f)

  let dfintv = (CBnd MFOTL.ts_null, Inf) 

  let strip str = 
    let len = String.length str in
    if str.[0] = '\"' && str.[len-1] = '\"' then
      String.sub str 1 (len-2)
    else
      str

  let get_cst str = 
    try 
      Int (int_of_string str)
    with _ -> Str (strip str)

  let check f = 
    let _ = 
      match f with
	| Equal (t1,t2)  
	| Less (t1,t2) 
	  -> ( 	
	    match t1,t2 with
	      | Cst (Int _), Cst (Str _) 
	      | Cst (Str _), Cst (Int _) -> 
		failwith "[Formula_parser.check] \
              Comparisons should be between constants of the same type"
	      | _ -> () 
	  )      
	| _ -> failwith "[Formula_parser.check] internal error"
    in f
%}

%token LPA RPA LSB RSB COM DOT QM EQ LESS INF
%token <string> STR
%token <int> NUM
%token <int*char> TU
%token NOT AND OR IMPL EQUIV EX FA
%token PREV NEXT EVENTUALLY ONCE ALWAYS PAST_ALWAYS SINCE UNTIL
%token END
%token EOF 

%right SINCE UNTIL
%nonassoc PREV NEXT EVENTUALLY ONCE ALWAYS PAST_ALWAYS
%nonassoc EX FA
%left EQUIV
%right IMPL
%left OR
%left AND
%nonassoc NOT 

%start formula
%type <MFOTL.formula> formula

%%


formula:
      | LPA formula RPA                 { f "f()"; $2 }
      | predicate                       { f "f(pred)"; Pred $1}
      | term EQ term                    { f "f(eq)"; check (Equal ($1,$3)) }
      | term LESS term                  { f "f(eq)"; check (Less ($1,$3)) }
      | formula EQUIV formula           { f "f(<=>)"; Equiv ($1,$3) }
      | formula IMPL formula            { f "f(=>)"; Implies ($1,$3) }
      | formula OR formula              { f "f(or)"; Or ($1,$3) }    
      | formula AND formula             { f "f(and)"; And ($1,$3) }
      | NOT formula                     { f "f(not)"; Neg ($2) }
      | EX varlist DOT formula          { f "f(ex)"; exists $2 $4 }
      | FA varlist DOT formula          { f "f(fa)"; forall $2 $4 }
      | PREV interval formula           { f "f(prev)"; Prev ($2,$3) }
      | PREV formula                    { f "f(prevdf)"; Prev (dfintv,$2) }
      | NEXT interval formula           { f "f(next)"; Next ($2,$3) }
      | NEXT formula                    { f "f(nextdf)"; Next (dfintv,$2) }
      | EVENTUALLY interval formula     { f "f(ev)"; Eventually ($2,$3) }
      | ONCE interval formula           { f "f(once)"; Once ($2,$3) }
      | ONCE formula                    { f "f(oncedf)"; Once (dfintv,$2) }
      | ALWAYS interval formula         { f "f(always)"; Always ($2,$3) }
      | PAST_ALWAYS interval formula    { f "f(palways)"; PastAlways ($2,$3) }
      | PAST_ALWAYS formula             { f "f(palwaysdf)"; PastAlways (dfintv,$2) }
      | formula SINCE interval formula  { f "f(since)"; Since ($3,$1,$4) }
      | formula SINCE formula           { f "f(sincedf)"; Since (dfintv,$1,$3) }
      | formula UNTIL interval formula  { f "f(until)"; Until ($3,$1,$4) }


interval: 
      | lbound COM rbound     { f "interval"; ($1,$3) }

lbound:
      | LPA units             { f "opened lbound"; OBnd $2 }
      | LSB units             { f "closed lbound"; CBnd $2 }

rbound:
      | units RPA             { f "opened rbound"; OBnd $1 }
      | units RSB             { f "closed rbound"; CBnd $1 }
      | INF RPA               { f "no bound(1)"; Inf }
      | INF RSB               { f "no bound(2)"; Inf }

units: 
      | TU                    { f "ts";  timeunits $1 }
      | NUM                   { f "int"; $1 }


predicate:
      | pred LPA termlist RPA    { f "p()"; 
				    Predicate.make_predicate ($1,$3) } 

pred:
      | STR                   { f "pred"; $1 }


term:
      | var                   { f "term(var)"; Var $1 }
      | str_sb                { f "term(cst.str)"; Cst (get_cst $1) }
      | NUM                   { f "term(cst.num)"; Cst (Int $1) }

str_sb:
      | LSB STR RSB           { f "str_sb([str])"; "[" ^ $2 ^ "]" }
      | STR                   { f "str_sb(str)"; $1 }

termlist:
      | term COM termlist     { f "termlist(list)"; $1 :: $3 }
      | term 	              { f "termlist(end)"; [$1] }
      |  	              { f "termlist()"; [] }

varlist:
      | varlist DOT var       { f "varlist(list)"; $1 @ [$3] }
      | var 	              { f "varlist(end)"; [$1] }
      |  	              { f "varlist()"; [] }

var:
      | QM STR	              { f "var"; $2 }


      

