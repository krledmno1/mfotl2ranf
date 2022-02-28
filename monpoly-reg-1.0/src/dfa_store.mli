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


val mona_dir: string ref

val aPlus: dfa ref
val aLess: dfa ref
val aLessEq: dfa ref
val init_dfas: unit -> unit

val get_plus_const2: int -> int -> int -> dfa
val get_plus_const2': int -> int -> int -> dfa
val get_less: int -> int -> dfa
val get_less_const2: int -> int -> dfa
val get_lesseq_const1: int -> int -> dfa


