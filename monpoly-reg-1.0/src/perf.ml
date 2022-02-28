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



open Unix
open Misc
open MFOTL

let start_time = Unix.time()
let last_time_q = ref start_time

let q_step = ref 1000
let next_alarm = 300

let _ = 
  (* prerr_endline ("Current working directory: " ^ Sys.getcwd ()); *)
  try
    let ch = open_in "perf.conf" in
    q_step := int_of_string (input_line ch);
    close_in ch
  with _ -> () (* prerr_endline e *)

let show_results q tsq =
  if q mod !q_step = 0 then 
    begin
      let now = Unix.time() in
      let diff = now -. !last_time_q in      
	begin
	  let times = Unix.times() in
	  Printf.eprintf "show_results: loop %6d @%s (%2.2f  %5.0f s) \
                          (u:%.0f s:%.0f t:%.0f mem:%s kB)\n%!"
	  q (MFOTL.string_of_ts tsq)   diff (now -. start_time) 
	  times.tms_utime times.tms_stime 
	  (times.tms_utime +. times.tms_stime) 
	  (Misc.mem_current ());
          last_time_q := now
	end
    end; 


