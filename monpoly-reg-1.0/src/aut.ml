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


open Predicate
open Mona


(* automaton *)
type aut = int array * dfa


(* product [[a;b];[0;1;2]] = [(a,0); (a,1); (a,2); (b,0); (b,1); (b,2)] 
   Actually, we represent tuples as lists as well.
*)
let rec product llist = 
  match llist with
    | [] -> [[]]
    | h :: t ->
      let all = product t in
      List.fold_left (fun res c -> 
	(List.map (fun tuple -> c::tuple) all) @ res
      ) [] h

(* decodes a track: it returns the list of all integers encoded by a track *)
let decode_track track_len track = 
  (* print_endline ("decode_track: " ^ track); *)
  let rec decode pos values = 
    if pos = -1 then values 
    else match track.[pos] with
      | '0' -> decode (pos-1) (List.map (fun v -> 2*v) values)
      | '1' -> decode (pos-1) (List.map (fun v -> 2*v+1) values)
      | 'X' -> decode (pos-1) 
	((List.map (fun v -> 2*v) values) @ (List.map (fun v -> 2*v+1) values))
      | 'n' -> decode (pos-1) values 
      | _ -> failwith "[Aut.decode_track] internal error"
  in
  decode (track_len - 1) [0]


(* A word encodes a tuple if it contains no X, and it encodes a set of
   tuples if it contains at least an X;
   This function prints all tuples.
*)
let decode_word no_tracks len word = 
  let all_fields = ref [] in
  (* this is a list of lists of values: there are no_tracks outer
     lists; we need to compute their cartesian product *)
  for i = 0 to no_tracks - 1 do 
    let track = String.sub word (i * len) len in
    all_fields := (decode_track len track) :: !all_fields;
  done;
  all_fields := List.rev !all_fields;
  let tuples = product !all_fields in
  List.fold_left (fun old_str t ->
    old_str ^ (Misc.string_of_list string_of_int t) ^ " "
  ) "" tuples
  (* Misc.string_of_list (Misc.string_of_list string_of_int) tuples *)



let getAllTuples a no_tracks idxs = 
  let len = (Mona.numberOfStates a) - 2 in
  if len < 0 then
    begin
      Mona.dfaPrintVerbose a;
      failwith "[Aut.getAllTuples] internal error (strange automaton, see above)."
    end
  else if len = 0 then
    if Mona.isFinal a 1 then
      if no_tracks = 0 then if !Misc.verbose then "true" else "()" (* i.e. a = dfaTrue *)
      else failwith "[Aut.getAllTuples] Automaton is not finite!"
    else
      if !Misc.verbose && no_tracks = 0 then "false" else "" (* i.e. a = dfaFalse *)
  else
    if no_tracks = 0 then
      "true or false (don't know): see automaton"
    else
      let all_words = Mona.allWords a no_tracks idxs in
      (* print_endline ("[Aut.printAllTuples] all_words = " ^ all_words); *)
      let words_len = String.length all_words in
      (* each word in all_words has length word_len *)
      (* each word represents one or more tuples *)
      (* decode each word! *)
      let word_len = no_tracks * len in
      let str = ref "" in
      for i = 0 to (words_len / word_len) - 1 do
	str := !str ^ (decode_word no_tracks len (String.sub all_words (i * word_len) word_len))
      done;
      !str
