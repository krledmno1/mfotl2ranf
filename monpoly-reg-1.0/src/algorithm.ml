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



(** This module implements the monitoring algorithm described in the
    paper "Runtime Monitoring of Metric First-order Temporal
    Properties" by David Basin, Felix Klaedtke, Samuel Muller, and
    Birgit Pfitzmann, presented at FSTTCS'08.
*)


open Strmap
open Misc
open Predicate
open MFOTL
open Log
open Mona
open Aut



type state_once = {mutable aR: dfa}
type state_evtl = {mutable aS: dfa; 
		   mutable tp_q: (int * int * int) Queue.t; }
type state_until = {mutable aRu: dfa; 
		    mutable aSu: dfa; 
		    mutable tp_qu: (int * int * int) Queue.t; }
type state_bin = {mutable q1: (int * int * int * dfa) Queue.t; 
		  mutable q2: (int * int * int * dfa) Queue.t;}

type extformula =
  | EPred of var * dfa * int list * int array option
  | ELess of dfa
  | EEqual of dfa
  | ENeg of extformula
  | EAnd of extformula * extformula * state_bin
      (* (int * int) list * int array * int *)
  | EOr of extformula * extformula * state_bin
  | EExists of int * extformula 
  | EPrev of interval * extformula
  | ENext of interval * extformula
  | EOnce of extformula * state_once * 
      int * int array * dfa option * dfa option
  | ESince of extformula * extformula * state_once * state_bin * 
      int * int array * dfa option * dfa option
  | EEventually of extformula * int * int * state_evtl * 
      int * int array * dfa option
  | EUntil of extformula * extformula * int * int * state_until * state_bin *
      int * int array * dfa option






(* We illustrate how the indexes are assigned: Consider
   p(y,15,16,17,z,y,z) where y has appeared already (say vmap is
   [x->0,y->1]), and z is new. Then the indexes of the automaton for
   the p's interpretation are 1,3,4,5,2,6,7,8. Note that the indexes
   of the automaton for the above atomic formula are 1,2.

   Note that the indexes for p^I automaton only need to be
   distinct. However, in order not to reindex later, it is
   useful to fix the indexes of the free variables. *)
let deduce_indexes pred vmap first_idx = 
  let p, arity, tlist = Predicate.get_info pred in
  let arr = Array.make arity 0 in
  (* We first fix the positions of 1st occurrences of variables in
     tlist. For our example, this produces 1,?,?,?,2,?,?,?. . *)
  let rec fst_pass pos vmap' first_idx' vars = function
    | [] -> vmap', first_idx'
    | Var x :: t when not (List.mem x vars) -> 
      (* 1st occurrence of x in tlist *)
      (try 	     
	 arr.(pos) <- List.assoc x vmap';
	 fst_pass (pos+1) vmap' first_idx' (x::vars) t
       with Not_found -> 
	 begin
	   arr.(pos) <- first_idx';
	   fst_pass (pos+1) ((x, first_idx')::vmap') (first_idx'+1) (x::vars) t
	 end)
    | _ :: t -> 
      fst_pass (pos+1) vmap' first_idx' vars t
  in
  
  let rec snd_pass pos vars unused = function
    | [] -> ()
    | Var x :: t when (List.mem x vars) ->
      arr.(pos) <- unused;
      snd_pass (pos+1) vars (unused+1) t
    | Var x :: t -> (* case Var x with x first occurring in tlist *)
      snd_pass (pos+1) (x::vars) unused t
    | Cst _ :: t -> 
      arr.(pos) <- unused;
      snd_pass (pos+1) vars (unused+1) t
  in

  let new_vmap, new_first_idx = fst_pass 0 vmap first_idx [] tlist in
  snd_pass 0 [] new_first_idx tlist;
  arr, new_vmap, new_first_idx



let test_cyclicity a b n = 
  for i = 0 to n-2 do
    for j = i+1 to n-1 do
      if (a.(i) - a.(j)) * (b.(i) - b.(j)) < 0 then
	failwith "[Algorithm.test_cyclicity] test failed"
    done
  done

(* Given two arrays of indexes, find the map between them. 

   Example: get_map [2;5;1] [3;4;2] = [_;2;3;_;_;4]
   That is, get_map a b = f such that f[a[i]] = b[i].

   Note: We should fail if a and b are not "order-equivalent", that
   is, if there is i<>j such that a[i]<a[j] and b[i]>b[j].

   Note: we may fail for good reasons (as in p(x,y) AND p(y,x)), or
   for bad reasons: for instance, because of bad indexing of
   constants. *)
let get_map a b = 
  let n = Array.length a in
  test_cyclicity a b n;
  let max = ref 0 in
  for i = 0 to n - 1 do
    if a.(i) > !max then
      max := a.(i)
  done;
  let m = Array.make (!max+1) 0 in
  for i = 0 to n-1 do
    m.(a.(i)) <- b.(i);
  done;
  m

(* [idxs] is a tuple ([vmap], [pmap], [last_idx]) where 
     [vmap] is a map from free variables to indices
     [pmap] is a map from predicate symbols to arrays of indices
     [first_idx] is the first unused index in vmap
*)
let add_ext_pred idxs pred = 
  let vmap, pmap, first_idx = idxs in
  let p, _, tlist = Predicate.get_info pred in

  let p_idxs, new_pmap, new_vmap, new_first_idx, reindex = 
    try (* [p] already occurred; we (usually) need to reindex *)
      let p_idx = List.assoc p pmap in
      let p_arr, new_vmap, new_first_idx = deduce_indexes pred vmap first_idx in
      p_arr, (p,p_arr)::pmap, new_vmap, new_first_idx, Some (get_map p_idx p_arr)
    with Not_found -> (* 1st occurrence of [p] in the formula *)
      let p_arr, new_vmap, new_first_idx = deduce_indexes pred vmap first_idx in
      p_arr, (p,p_arr)::pmap, new_vmap, new_first_idx, None
  in

  let rec proc_terms pos curr_a proj vars = function
    | [] -> curr_a, proj

    | Var x :: t when List.mem_assoc x vars -> 
      let pos' = List.assoc x vars in
      let aEq = Mona.dfaEq2 p_idxs.(pos) p_idxs.(pos') in
      let new_a = dfaProduct curr_a aEq PT_And in
      proc_terms (pos+1) new_a (p_idxs.(pos)::proj) vars t
	
    | Var x :: t -> (* 1st occurrence of [x] *)
      proc_terms (pos+1) curr_a proj ((x,pos)::vars) t

    | Cst (Int c) :: t -> 
      let aConst = Mona.dfaPresbConst p_idxs.(pos) c in
      let new_a = dfaProduct curr_a aConst PT_And in
      proc_terms (pos+1) new_a (p_idxs.(pos)::proj) vars t

    | Cst (Str c) :: t -> 
      failwith "[Algorithm.add_ext_pred] internal error"
  in

  let aRestr, proj = proc_terms 0 (Mona.dfaTrue()) [] [] tlist in
  let new_idxs = new_vmap, new_pmap, new_first_idx in
  new_idxs, aRestr, proj, reindex


let get_vindex x vmap first_index = 
  try
    let ix = List.assoc x vmap in
    ix, vmap, first_index
  with Not_found ->
    first_index, (x,first_index)::vmap, first_index+1


let get_indexes vmap f = 
  let fv = MFOTL.free_vars f in
  let n = List.length fv in
  let idxs = Array.make n 0 in
  let rec loop pos = function
    | [] -> ()
    | x::t ->       
      idxs.(pos) <- List.assoc x vmap;
      loop (pos+1) t
  in  
  loop 0 fv;
  idxs


let rec add_ext idxs = function
  | Pred pred -> 
    let p = Predicate.get_name pred in
    let new_idxs, aRestr, proj, reindex = add_ext_pred idxs pred in
    new_idxs, EPred (p, aRestr, proj, reindex)

  | Less (t1, t2) ->
    let vmap, pmap, first_idx = idxs in
    (match t1, t2 with
      | Var x1, Var x2 -> 
	if x1 = x2 then 
	  idxs, ELess (Mona.dfaFalse ())
	else
	  let ix1, vmap1, first_idx1 = get_vindex x1 vmap first_idx in
	  let ix2, vmap2, first_idx2 = get_vindex x2 vmap1 first_idx1 in
	  let aLess = Dfa_store.get_less ix1 ix2 in
	  Mona.dfaReplaceIndices aLess [|ix1; ix2|];
	  (vmap2, pmap, first_idx2), ELess (aLess)

      | Cst (Int c1), Cst (Int c2) ->
	if c1 >= c2 
	then idxs, ELess (Mona.dfaFalse ())
	else idxs, ELess (Mona.dfaTrue ())

      | Cst (Int c), Var x ->
	let ix, vmap', first_idx' = get_vindex x vmap first_idx in
	let idxs' = vmap', pmap, first_idx' in
	idxs', ELess (Dfa_store.get_lesseq_const1 ix (c+1))

      | Var x, Cst (Int c) ->
	let ix, vmap', first_idx' = get_vindex x vmap first_idx in
	let idxs' = vmap', pmap, first_idx' in
	idxs', ELess (Dfa_store.get_less_const2 ix c)

      | _ -> failwith "[Algorithm.add_ext.Less] internal error"
    )

  | Equal (t1, t2) ->
    let vmap, pmap, first_idx = idxs in
    (match t1, t2 with
      | Var x1, Var x2 -> 
	if x1 = x2 then 
	  idxs, EEqual (Mona.dfaTrue ())
	else
	  let ix1, vmap1, first_idx1 = get_vindex x1 vmap first_idx in
	  let ix2, vmap2, first_idx2 = get_vindex x2 vmap1 first_idx1 in
	  let aEqual = Mona.dfaEq2 ix1 ix2 in
	  (vmap2, pmap, first_idx2), EEqual (aEqual)

      | Cst (Int c1), Cst (Int c2) ->
	if c1 = c2 
	then idxs, EEqual (Mona.dfaTrue ())
	else idxs, EEqual (Mona.dfaFalse ())

      | Cst (Int c), Var x 
      | Var x, Cst (Int c) ->
	let ix, vmap', first_idx' = get_vindex x vmap first_idx in
	let idxs' = vmap', pmap, first_idx' in
	idxs', EEqual (Mona.dfaPresbConst ix c)

      | _ -> failwith "[Algorithm.add_ext.Equal] internal error"
    )

  | Neg f -> 
    let idxs', g = add_ext idxs f in
    idxs', ENeg g

  | And (f1, f2) -> 
    let idxs1, g1 = add_ext idxs f1 in
    let idxs2, g2 = add_ext idxs1 f2 in
    let state = {q1 = Queue.create (); q2 = Queue.create ()} in
    idxs2,  EAnd (g1, g2, state)

  | Or (f1, f2) -> 
    let idxs1, g1 = add_ext idxs f1 in
    let idxs2, g2 = add_ext idxs1 f2 in
    let state = {q1 = Queue.create (); q2 = Queue.create ()} in
    idxs2,  EOr (g1, g2, state)

  | Exists (x, f) -> 
    let vmap, pmap, first_idx = idxs in     
    let vmap_no_x, idx_x = 
      try List.remove_assoc x vmap, Some (List.assoc x vmap)
      with Not_found -> vmap, None
    in
    let idxs', g = add_ext (vmap_no_x, pmap, first_idx) f in
    let vmap', pmap', first_idx' = idxs' in 
    let ix = List.assoc x vmap' in
    (* List.iter (fun (x,ix) -> Printf.printf "%s->%d " x ix) vmap; *)
    (* print_newline(); *)
    let vmap'' = List.remove_assoc x vmap' in
    let new_vmap = 
      match idx_x with
	| None -> vmap''
	| Some idx -> (x,idx)::vmap''
    in
    (new_vmap, pmap', first_idx'), EExists (ix, g)

  | Once (intv, f) ->
    (* We use the first unused index as the index of the age
       variable *)
    let idxs', g = add_ext idxs f in
    let vmap, pmap, age_idx = idxs' in
    let b, b' = intv in
    let state = {aR = (Mona.dfaTrue ())} in
    let aMinBnd = match b with 
      | CBnd 0 -> None
      | CBnd c -> Some (Dfa_store.get_lesseq_const1 age_idx c)
      | OBnd c -> Some (Dfa_store.get_lesseq_const1 age_idx (c+1))
      | Inf -> failwith "[Algorithm.add_ext.Once] internal error"
    in
    let aMaxBnd = match b' with
      | Inf -> None
      | CBnd c -> Some (Dfa_store.get_less_const2 age_idx (c+1))
      | OBnd c -> Some (Dfa_store.get_less_const2 age_idx c)
    in
    let f_idxs = get_indexes vmap f in
    let len = Array.length f_idxs in
    let idx_map = Array.make (age_idx+2) 0 in
    for i = 0 to len-1 do
      idx_map.(f_idxs.(i)) <- f_idxs.(i);
    done;
    idx_map.(age_idx+1) <- age_idx;
    idxs', EOnce (g, state, age_idx, idx_map, aMinBnd, aMaxBnd)

  | Since (intv, f1, f2) ->
    let idxs1, g1 = add_ext idxs f1 in
    let idxs2, g2 = add_ext idxs1 f2 in
    let vmap, pmap, age_idx = idxs2 in
    let b, b' = intv in
    let state = {aR = (Mona.dfaTrue ())} in 
    let aMinBnd = match b with 
      | CBnd 0 -> None
      | CBnd c -> Some (Dfa_store.get_lesseq_const1 age_idx c)
      | OBnd c -> Some (Dfa_store.get_lesseq_const1 age_idx (c+1))
      | Inf -> failwith "[Algorithm.add_ext.Since] internal error"
    in
    let aMaxBnd = match b' with
      | Inf -> None
      | CBnd c -> Some (Dfa_store.get_less_const2 age_idx (c+1))
      | OBnd c -> Some (Dfa_store.get_less_const2 age_idx c)
    in
    let f_idxs = get_indexes vmap f2 in
    let len = Array.length f_idxs in
    let idx_map = Array.make (age_idx+2) 0 in
    for i = 0 to len-1 do
      idx_map.(f_idxs.(i)) <- f_idxs.(i);
    done;
    idx_map.(age_idx+1) <- age_idx;
    let state' = {q1 = Queue.create (); q2 = Queue.create ()} in
    idxs2, ESince (g1, g2, state, state', age_idx, idx_map, aMinBnd, aMaxBnd)

  | Eventually (intv, f) ->
    let idxs', g = add_ext idxs f in
    let vmap, pmap, age_idx = idxs' in
    let b, b' = intv in
    let state = {aS = (Mona.dfaFalse ()); tp_q = Queue.create ()} in 
    let low_bnd, aMinBnd = match b with 
      | CBnd 0 -> 0, None
      | CBnd c -> c, Some (Dfa_store.get_lesseq_const1 age_idx c)
      | OBnd c -> c+1, Some (Dfa_store.get_lesseq_const1 age_idx (c+1))
      | Inf -> failwith "[Algorithm.add_ext.Evtl] internal error"
    in
    let up_bnd = 
      match b' with 
      | CBnd c -> c
      | OBnd c -> c-1
      | Inf -> failwith "[Algorithm.add_ext.Evtl2] internal error"
    in
    let f_idxs = get_indexes vmap f in
    let len = Array.length f_idxs in
    let idx_map = Array.make (age_idx+3) 0 in
    for i = 0 to len-1 do
      idx_map.(f_idxs.(i)) <- f_idxs.(i);
    done;
    idx_map.(age_idx) <- age_idx;
    idx_map.(age_idx+2) <- age_idx+1;
    idxs', EEventually (g, low_bnd, up_bnd, state, age_idx, idx_map, aMinBnd)

  | Until (intv, f1, f2) ->
    let idxs1, g1 = add_ext idxs f1 in
    let idxs2, g2 = add_ext idxs1 f2 in
    let _, _, idx1 = idxs2 in
    let vmap, pmap, idx2 = idxs2 in
    let idx = max idx1 idx2 in

    let b, b' = intv in
    let low_bnd, aMinBnd = match b with 
      | CBnd 0 -> 0, None
      | CBnd c -> c, Some (Dfa_store.get_lesseq_const1 (idx+2) c)
      | OBnd c -> c+1, Some (Dfa_store.get_lesseq_const1 (idx+2) (c+1))
      | Inf -> failwith "[Algorithm.add_ext.Until] internal error"
    in
    let up_bnd = 
      match b' with 
      | CBnd c -> c
      | OBnd c -> c-1
      | Inf -> failwith "[Algorithm.add_ext.Until2] internal error"
    in

    let f_idxs = get_indexes vmap f2 in
    let len = Array.length f_idxs in
    let idx_map = Array.make (idx+4) 0 in
    for i = 0 to len-1 do
      idx_map.(f_idxs.(i)) <- f_idxs.(i);
    done;
    idx_map.(idx) <- idx;
    idx_map.(idx+1) <- idx+1;
    idx_map.(idx+3) <- idx+2;

    (* for i = 0 to idx+3 do *)
    (*   Printf.printf "%d " idx_map.(i); *)
    (* done; *)
    (* print_newline(); *)

    let state = {aRu = (Mona.dfaFalse ()); aSu = (Mona.dfaFalse ()); tp_qu = Queue.create ()} in 
    let state' = {q1 = Queue.create (); q2 = Queue.create ()} in
    idxs2, EUntil (g1, g2, low_bnd, up_bnd, state, state', idx, idx_map, aMinBnd)

  | _ -> failwith "not yet"








let print_aut str a =
  print_endline str;
  dfaPrintVerbose a

(* This is a particular case of eval_since. *)
let eval_once age_idx idx_map aMinBnd aMaxBnd aNow aRold delta = 
  (* y + delta = y' *) (* Note: we could have a special case when delta = 0 *)
  let aPlusDelta = Dfa_store.get_plus_const2 age_idx (age_idx+1) delta in

  (* aRold is over (xs,y); aT is over (xs,y,y') with y + delta = y'*)
  let aT = Mona.dfaProduct aRold aPlusDelta PT_And in
  (* let aT = Mona.dfaMinimize aT in  *)
  (* project away y; aT' is over (xs,y') *)
  let aT' = Mona.dfaProject aT age_idx in

  (* rename y' to y; now aT' is over (xs,y) *)
  Mona.dfaReplaceIndices aT' idx_map;

  (* restrict aT' to those tuples (a,y) with y<b' *)
  let aU = 
    match aMaxBnd with
      | None -> aT'
      | Some a -> dfaProduct aT' a PT_And
  in

  let aZero = Mona.dfaPresbConst age_idx 0 in
  let aN = Mona.dfaProduct aNow aZero PT_And in
  (* let aN = Mona.dfaMinimize aN in *)

  let aRnew = Mona.dfaProduct aU aN PT_Or in
  (* let aRnew = Mona.dfaMinimize aRnew in *)

  (* restrict aRnew to those tuples (a,y) with b <= y *)
  let aR' = 
    match aMinBnd with
      | None -> aRnew 
      | Some a -> Mona.dfaProduct aRnew a PT_And
  in

  (* project away y; aRes is over (xs) *)
  let aRes = Mona.dfaProject aR' age_idx in

  (* Printf.printf "states: %d\n" (Mona.numberOfStates aRnew); *)

  (* let f = Mona.numberOfStates in *)
  (* (\* let g = function Some a -> f a | None -> -1 in *\) *)
  (* (\* Printf.eprintf "%d %d\n\n" (g aMinBnd) (g aMaxBnd); *\) *)
  (* Printf.eprintf "%d,%d,%d,%d,%d,%d,%d,%d,%d\n" *)
  (*   (f aNow) (f aRold) (f aT) (f aT') (f aU) (f aN) (f aRnew) (f aR') (f aRes); *)

  aRnew, aRes


let eval_since age_idx idx_map aMinBnd aMaxBnd aNow1 aNow2 aRold delta = 
  (* y + delta = y' *) (* Note: we could have a special case when delta = 0 *)
  let aPlusDelta = Dfa_store.get_plus_const2 age_idx (age_idx+1) delta in

  (* aRold is over (xs,y); aT is over (xs,y,y') with y + delta = y'*)
  let aT = Mona.dfaProduct aRold aPlusDelta PT_And in

  (* project away y; aT' is over (xs,y') *)
  let aT' = Mona.dfaProject aT age_idx in

  (* rename y' to y; now aT' is over (xs,y) *)
  Mona.dfaReplaceIndices aT' idx_map;

  (* restrict aT' to those tuples (a,y) with y<b' *)
  let aT'' = 
    match aMaxBnd with
      | None -> aT'
      | Some a -> dfaProduct aT' a PT_And
  in
  let aU = dfaProduct aNow1 aT'' PT_And in

  let aZero = Mona.dfaPresbConst age_idx 0 in
  let aN = Mona.dfaProduct aNow2 aZero PT_And in
  let aRnew = Mona.dfaProduct aU aN PT_Or in

  (* restrict aRnew to those tuples (a,y) with b <= y *)
  let aR' = 
    match aMinBnd with
      | None -> aRnew 
      | Some a -> Mona.dfaProduct aRnew a PT_And
  in

  (* project away y; aRes is over (xs) *)
  let aRes = Mona.dfaProject aR' age_idx in

  aRnew, aRes


let eval_evtl idx idx_map aMinBnd aSold delta tp_e = 
  (* Note: we could have a special case when delta = 0 *)
  (* y' + delta = y *) 
  let aPlusDelta = Dfa_store.get_plus_const2' (idx+2) (idx+1) delta in

  (* aSold is over (xs,j,y); aT is over (xs,j,y,y') with y + delta = y'*)
  let aT = Mona.dfaProduct aSold aPlusDelta PT_And in

  (* project away y; aU is over (xs,j,y') *)
  let aU = Mona.dfaProject aT (idx+1) in

  (* rename y' to y; now aU is over (xs,y) *)
  Mona.dfaReplaceIndices aU idx_map;

  (* eliminate tuples from the past *)
  let a_tp_next = Dfa_store.get_lesseq_const1 idx (tp_e+1) in
  let b = Mona.dfaProduct aU a_tp_next PT_And in

  (* restrict aSnew to those tuples (a,j,y) with b <= y *)
  match aMinBnd with
      | None -> b
      | Some a -> Mona.dfaProduct a b PT_And







let queue_singleton x =
  let nq = Queue.create () in
  Queue.add x nq;
  nq

let queue_map f q = 
  let nq = Queue.create () in
  Queue.iter (fun x -> Queue.add (f x) nq) q;
  nq

let eval f tp ts db delta = 
  (* Printf.printf "[eval] tp=%d ts=%d delta=%d\n%!" tp ts delta; *)
  let rec eval' = function
    | EPred (p, aRestr, proj, reindex) ->
      let aP = 
	try 
	  Strmap.find p db
	with Not_found -> 
	  Mona.dfaFalse()
      in 
      (match reindex with
	| Some idx_map -> 
	  Mona.dfaReplaceIndices aP idx_map
	| None -> ());
      let b = Mona.dfaProduct aP aRestr PT_And in
      let c = List.fold_left Mona.dfaProject b proj in
      queue_singleton (tp, ts, delta, c) 
  
    | ELess a -> 
      queue_singleton (tp, ts, delta, (Mona.dfaCopy a)) 

    | EEqual a -> 
      queue_singleton (tp, ts, delta, (Mona.dfaCopy a)) 

    | ENeg f' ->
      queue_map 
	(fun (tp, ts, d, a) -> (tp, ts, d, (Mona.dfaNegation a; a))) 
	(eval' f')

    | EAnd (f1, f2, state) -> 
      let new_q1 = eval' f1 in
      let new_q2 = eval' f2 in

      Queue.transfer new_q1 state.q1;
      Queue.transfer new_q2 state.q2;

      let res_queue = Queue.create () in
      let rec eval_aux_and () = 
	if not (Queue.is_empty state.q1 || Queue.is_empty state.q2) then
	  let (tp1, ts1, d1, a1) = Queue.top state.q1 in
	  let (tp2, ts2, d2, a2) = Queue.top state.q2 in
	  assert(tp1 = tp2 && ts1 = ts2 && d1 = d2);
	  let a = Mona.dfaProduct a1 a2 PT_And in
	  ignore(Queue.take state.q1);
	  ignore(Queue.take state.q2);
	  Queue.add (tp1, ts1, d1, a) res_queue;
	  eval_aux_and()
      in
      eval_aux_and ();
      res_queue

    | EOr (f1, f2, state) -> 
      let new_q1 = eval' f1 in
      let new_q2 = eval' f2 in

      Queue.transfer new_q1 state.q1;
      Queue.transfer new_q2 state.q2;

      let res_queue = Queue.create () in
      let rec eval_aux_or () = 
	if not (Queue.is_empty state.q1 || Queue.is_empty state.q2) then
	  let (tp1, ts1, d1, a1) = Queue.top state.q1 in
	  let (tp2, ts2, d2, a2) = Queue.top state.q2 in
	  assert(tp1 = tp2 && ts1 = ts2 && d1 = d2);
	  let a = Mona.dfaProduct a1 a2 PT_Or in
	  ignore(Queue.take state.q1);
	  ignore(Queue.take state.q2);
	  Queue.add (tp1, ts1, d1, a) res_queue;
	  eval_aux_or()
      in
      eval_aux_or();
      res_queue

    | EExists (ix, f') ->
      queue_map (fun (tp, ts, d, a) -> (tp, ts, d, Mona.dfaProject a ix)) (eval' f')
	
    | EOnce (f', state, age_idx, idx_map, aMinBnd, aMaxBnd) -> 
      let eval_once' tp delta aNow =
	if tp = 0 then
	  begin
	    state.aR <-   
	      (let aZero = Mona.dfaPresbConst age_idx 0 in
	       Mona.dfaProduct aNow aZero PT_And
	      );
	    match aMinBnd with
	      | None -> aNow
	      | _ -> Mona.dfaFalse()
	  end
	else
	  let aRnew, aRes = eval_once age_idx idx_map aMinBnd aMaxBnd aNow state.aR delta in
	  state.aR <- aRnew;
	  aRes
      in
      queue_map (fun (tp, ts, d, a) -> (tp, ts, d, eval_once' tp d a)) (eval' f')

    | ESince (f1, f2, state, state', age_idx, idx_map, aMinBnd, aMaxBnd) -> 
      let eval_since' tp delta aNow1 aNow2 = 
	if tp = 0 then
	  begin
	    state.aR <-   
	      (let aZero = Mona.dfaPresbConst age_idx 0 in
	       Mona.dfaProduct aNow2 aZero PT_And
	      );
	    match aMinBnd with
	      | None -> aNow2
	      | _ -> Mona.dfaFalse()
	  end
	else
	  let aRnew, aRes = eval_since age_idx idx_map aMinBnd aMaxBnd 
	    aNow1 aNow2 state.aR delta 
	  in
	  state.aR <- aRnew;
	  aRes
      in

      let new_q1 = eval' f1 in
      let new_q2 = eval' f2 in

      Queue.transfer new_q1 state'.q1;
      Queue.transfer new_q2 state'.q2;

      let res_queue = Queue.create () in
      let rec eval_aux_since () = 
	if not (Queue.is_empty state'.q1 || Queue.is_empty state'.q2) then
	  let (tp1, ts1, d1, a1) = Queue.take state'.q1 in
	  let (tp2, ts2, d2, a2) = Queue.take state'.q2 in
	  assert(tp1 = tp2 && ts1 = ts2 && d1 = d2);
	  let a = eval_since' tp1 d1 a1 a2 in
	  Queue.add (tp1, ts1, d1, a) res_queue;
	  eval_aux_since()
      in
      eval_aux_since();
      res_queue

    | EEventually (f', low_bnd, up_bnd, state, idx, idx_map, aMinBnd) -> 
      Queue.add (tp, ts, delta) state.tp_q;
      let q' = eval' f' in
      let res_q = Queue.create () in
      (* Printf.printf "at %d, q' hs length %d\n" tp (Queue.length q'); *)
      Queue.iter
	(fun (tp', ts', _, a') ->
	  (* Printf.printf "f' evaluated at %d\n%!" tp'; *)

	  let rec try_eval () = 
	    let tp_e, ts_e, delta_e = Queue.peek state.tp_q in
	    (* Note that tp_e <= tp' <= tp *)
	    if (ts' - ts_e) > up_bnd  then 
	      begin (* we can evaluate *)
		(* Printf.printf "we evaluate at %d\n%!" tp_e; *)
		(* project away j and y; aRes is over (xs) *)
		let b = Mona.dfaProject state.aS idx in
		let aRes = Mona.dfaProject b (idx+1) in
		ignore(Queue.take state.tp_q);
		Queue.add (tp_e, ts_e, delta_e, aRes) res_q;
		
		(* Note: delta_e = ts_{tp_e} - ts_{tp_e-1} 
		   We need: next_delta :=  ts_{tp_e+1} - ts_{tp_e} *)
		let _, _, next_delta = Queue.peek state.tp_q in
		state.aS <- eval_evtl idx idx_map aMinBnd state.aS next_delta tp_e;
		try_eval ()
	      end
	  in
	  try_eval();

	  let tp_e, ts_e, _ = Queue.peek state.tp_q in (* it might have been updated meanwhile *)
	  if ts' - ts_e >= low_bnd then
	    let a_tp_e = Mona.dfaPresbConst idx tp' in
	    let a'' = Mona.dfaProduct a' a_tp_e PT_And in
	    let aDelta = Mona.dfaPresbConst (idx+1) (ts' - ts_e) in
	    let aS_new = Mona.dfaProduct a'' aDelta PT_And in
	    state.aS <- Mona.dfaProduct state.aS aS_new PT_Or
	) q';
      res_q

    | EUntil (f1, f2, low_bnd, up_bnd, state, state', idx, idx_map, aMinBnd) -> 

      Queue.add (tp, ts, delta) state.tp_qu;

      let new_q1 = eval' f1 in
      let new_q2 = eval' f2 in

      Queue.transfer new_q1 state'.q1;
      Queue.transfer new_q2 state'.q2;

      let res_q = Queue.create () in

      let rec try_eval tp_e' ts_e' = 
	let tp_e, ts_e, delta_e = Queue.peek state.tp_qu in
	    (* Note that tp_e <= tp' <= tp *)
	if (ts_e' - ts_e) > up_bnd  then 
	  begin (* we can evaluate *)
	    (* Printf.printf "we evaluate at %d\n%!" tp_e; *)
	    ignore(Queue.take state.tp_qu);

	    (* compute aRes *)
	    let a_tp_now = Mona.dfaPresbConst idx tp_e in
	    let b1 = Mona.dfaProduct state.aSu a_tp_now PT_And in
	    let b2 = Mona.dfaProject b1 idx in
	    let b3 = Mona.dfaProject b2 (idx+1) in
	    let aRes = Mona.dfaProject b3 (idx+2) in
	    Queue.add (tp_e, ts_e, delta_e, aRes) res_q;
	    
	    (* update aR *)
	    let b1 = Mona.dfaPresbConst idx tp_e in
	    let b2 = Mona.dfaProduct state.aRu b1 PT_And in
	    dfaNegation b2;
	    state.aRu <- Mona.dfaProduct state.aRu b2 PT_And;

	    (* update aS *)
	    let _, _, next_delta = Queue.peek state.tp_qu in
	    let aPlusDelta = Dfa_store.get_plus_const2' (idx+3) (idx+2) next_delta in
	    let aT = Mona.dfaProduct state.aSu aPlusDelta PT_And in
	    let aU = Mona.dfaProject aT (idx+2) in
	    Mona.dfaReplaceIndices aU idx_map;
	    let a_tp_next = Dfa_store.get_lesseq_const1 idx (tp_e+1) in
	    let b = Mona.dfaProduct aU a_tp_next PT_And in
	    state.aSu <- (match aMinBnd with
	      | None -> b
	      | Some a -> Mona.dfaProduct a b PT_And);

	    try_eval tp_e' ts_e'
	  end
      in

      let rec eval_aux_until () = 
	if not (Queue.is_empty state'.q1 || Queue.is_empty state'.q2) then
	  let (tp1, ts1, d1, a1) = Queue.take state'.q1 in
	  let (tp2, ts2, d2, a2) = Queue.take state'.q2 in
	  assert(tp1 = tp2 && ts1 = ts2 && d1 = d2);

	  try_eval tp1 ts1;

	  (* update aS *)
	  let _, ts_e, _ = Queue.peek state.tp_qu in 
	  if ts2 - ts_e >= low_bnd then
	    begin
	      let a_j' = Mona.dfaPresbConst (idx+1) tp2 in
	      let aDelta = Mona.dfaPresbConst (idx+2) (ts2 - ts_e) in
	      let a_aux = Mona.dfaProduct a_j' aDelta PT_And in
	      let a_aux' = Mona.dfaProduct a2 a_aux PT_And in

	      (* case 1 *)
	      let aS_new1 = Mona.dfaProduct a_aux' state.aRu PT_And in

	      (* case 2 *)
	      let a_j2 = Mona.dfaPresbConst idx tp1 in
	      let aS_new2 = Mona.dfaProduct a_aux' a_j2 PT_And in

	      let aS_new = Mona.dfaProduct aS_new1 aS_new2 PT_Or in  
	      state.aSu <- Mona.dfaProduct state.aSu aS_new PT_Or;
	    end;
	  
	  (* update aR *)
	  let a' = Mona.dfaPresbConst idx tp1 in
	  let aR_new = Mona.dfaProduct a1 a' PT_And in
	  let aR_old' = Mona.dfaProduct a1 state.aRu PT_And in	      
	  state.aRu <- Mona.dfaProduct aR_old' aR_new PT_Or;

	  eval_aux_until()
      in
      eval_aux_until();
      res_q

    | _ -> failwith "not yet"
  in
  eval' f




let t_start = Unix.gettimeofday ()

let output tp ts a idxs = 
  if Misc.debugging Dbg_perf then
    Perf.show_results tp ts;
  let len = Array.length idxs in
  (* let a = Mona.dfaMinimize a in *)
  (* dfaPrintVerbose a; *)
  if not (Mona.isFinite a len) then
    Printf.printf "@%d (time-point %d): %s\n%!" ts tp
      "There is an infinite number of tuples satisfying the formula."
  else
    let str = Aut.getAllTuples a len idxs in
    (* Printf.eprintf "%.3f\n" ((Unix.gettimeofday ()) -. t_start); *)
    if !Misc.verbose || str <> "" then
      Printf.printf "@%d (time-point %d): %s\n%!" ts tp str






(* The arguments are:
   lexbuf - the lexer buffer (holds current state of the scanner)
   f - the extended MFOTL formula
   closed - true iff [f] is a ground formula
   i - the index of current entry in the log file 
   ([i] may be different from the current time-point when
   filter_empty_tp is enabled)
*)
let check_log lexbuf f f_idxs =
  let rec loop lastts =
    match Log.get_next_entry lexbuf with
      | Some (tp, ts, db) ->
	if !Misc.verbose then
	  Printf.printf "At time-point %d:\n%!" tp;
	assert(ts >= lastts);
	let a_q = eval f tp ts db (ts - lastts) in
	Queue.iter (fun (tp, ts, _, a) -> output tp ts a f_idxs) a_q;
	loop ts

      | None -> ()
  in
  loop MFOTL.ts_invalid




let monitor logfile f = 
  let lexbuf = Log.log_open logfile in
  let idxs, g = add_ext ([], [], 0) f in
  let vmap, pmap, _ = idxs in
  let f_idxs = get_indexes vmap f in
  (* print_pmap "at the end: " pmap; *)
  Misc.update_pred_indexes pmap;
  check_log lexbuf g f_idxs






let parse_log sign logfile =
  let lexbuf = Log.log_open logfile in
  let rec loop () =
    match Log.get_next_entry lexbuf with
      | Some (tp,ts,db) -> loop ()
      | None -> () 
  in
  loop ()

      
	  
