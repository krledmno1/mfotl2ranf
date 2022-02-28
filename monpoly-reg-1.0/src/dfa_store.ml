(*
 * This file is part of MonPoly-Reg.
 *
 * Copyright (C) 2014 ETH Zurich.
 * Contact:  ETH Zurich (Eugen Zalinescu: eugen.zalinescu@inf.ethz.ch)
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

open Mona


let mona_dir = ref "monaaut"


let aPlus = ref (Mona.dfaFalse ())
let aPlus' = ref (Mona.dfaFalse ())
let aLess = ref (Mona.dfaFalse ())
let aLessEq = ref (Mona.dfaFalse ())

let init_dfas () = 
  (* x0 + x1 = x2 *)
  aPlus := Mona.dfaImport (!mona_dir ^ "/presburger_plus_012.dfa");
  (* x2 + x1 = x0 *)
  aPlus' := Mona.dfaImport (!mona_dir ^ "/presburger_plus_210.dfa");
  (* x0 < x1 *)
  aLess := Mona.dfaImport (!mona_dir ^ "/presburger_less_01.dfa");
    (* x0 <= x1 *)
  aLessEq := (* Mona.dfaImport (!mona_dir ^ "/Examples/presburger_lesseq_01.dfa") *)
    Mona.dfaProduct !aLess (Mona.dfaEq2 0 1) PT_Or



(* returns automaton for x + c = y 
   idxs is the array of indices for x and y
   c is the constant *)
let get_plus_const2 ix iy c = 
  assert (ix < iy);
  let ac = Mona.dfaPresbConst 1 c in
  let a' = Mona.dfaProduct !aPlus ac PT_And in 
  let a = Mona.dfaProject a' 1 in 
  if ix <> 0 || iy <> 2 then 
    Mona.dfaReplaceIndices a [|ix;0;iy|]; 
  a

(* returns automaton for x + c = y 
   idxs is the array of indices for x and y
   c is the constant *)
let get_plus_const2' ix iy c = 
  assert (ix > iy);
  let ac = Mona.dfaPresbConst 1 c in
  let a' = Mona.dfaProduct !aPlus' ac PT_And in 
  let a = Mona.dfaProject a' 1 in 
  if ix <> 2 || iy <> 0 then 
    Mona.dfaReplaceIndices a [|iy;0;ix|]; 
  a


(* returns automaton for c <= x 
   i is the index of x *)
let get_lesseq_const1 i c = 
  let ac = Mona.dfaPresbConst 0 c in
  let a' = Mona.dfaProduct !aLessEq ac PT_And in 
  let a = Mona.dfaProject a' 0 in
  if i = 1 then a
  else begin Mona.dfaReplaceIndices a [|0;i|]; a end

(* x < y *)
let get_less ix iy =
  assert (ix < iy);
  let a = Mona.dfaCopy !aLess in
  if ix <> 0 || iy <> 1 then 
    Mona.dfaReplaceIndices a [|ix;iy|]; 
  a

(* returns automaton for x < c 
   i is the index of x *)
let get_less_const2 i c = 
  let ac = Mona.dfaPresbConst 1 c in
  let a' = Mona.dfaProduct !aLess ac PT_And in 
  let a = Mona.dfaProject a' 1 in
  if i = 0 then a
  else begin Mona.dfaReplaceIndices a [|i|]; a end


