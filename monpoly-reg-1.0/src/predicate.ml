(*
 * This file is part of MonPoly-Reg.
 *
 * Copyright (C) 2011 Nokia Corporation and/or its subsidiary(-ies).
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
 *)



open Misc

type var = string
type cst = 
  | Int of int
  | Str of string

type tcst = TInt | TStr

type term = 
  | Var of var
  | Cst of cst


(* predicate = name, arity, and list of arguments *)
type predicate = var * int * term list 


let make_predicate (name,args) = 
   (name, List.length args, args) 


let get_info p = p
let get_name (name,ar,args) = name
let get_args (name,ar,args) = args


let type_of_cst = function
  | Int _ -> TInt
  | Str _ -> TStr

let tvars = function
  | Var v -> [v]
  | Cst c -> []


let pvars (p:predicate) = 
  let rec get_vars = function 
    | (Var v)::t -> v::(get_vars t)
    | (Cst c)::t -> get_vars t
    | [] -> []
  in 
    Misc.remove_duplicates (get_vars (get_args p))


let cst_smaller c c' = 
  match c,c' with
    | Int a, Int a' -> a < a'
    | Str a, Str a' -> a < a'
    | _ -> failwith "[Predicate.cst_smaller] incomparable constants"



let print_var = print_string

let print_tcst t =
  match t with
    | TInt -> print_string "int"
    | TStr -> print_string "string"

let string_of_cst c = 
  match c with
    | Int i -> string_of_int i
    | Str s -> if s = "" then "\"\"" else s

let print_cst c = print_string (string_of_cst c)
    
      
let string_of_term = function 
  | Var v -> "?" ^ v
  | Cst c -> string_of_cst c

let print_term t = print_string (string_of_term t)

let print_predicate (p,ar,args) = 
  print_var p;
  Misc.print_list print_term args

let print_vartypes_list vartypes_list = 
  Misc.print_list_ext "" "" ", "
    (fun (v,t) -> 
      print_string (v ^ ":");
      match t with
	| TInt -> print_string "int"
	| TStr -> print_string "string"
    ) 
    vartypes_list;
  print_newline()
