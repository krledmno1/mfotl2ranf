open FO.FOInt
open Verified

let string_of_list string_of_val xs = String.concat ", " (List.map string_of_val xs)

let nat_of_int n = Monitor.nat_of_integer (Z.of_int n)

let rec conv_db = function
  | [] -> Monitor.empty_db
  | (r, t) :: rts -> Monitor.insert_into_db (r, nat_of_int (List.length t)) (List.map (fun x -> Some x) t) (conv_db rts)

let var x = Monitor.Var (nat_of_int x)
let const c = Monitor.Const (Monitor.EInt (Z.of_int c))

let tt = Monitor.Eq (const 0, const 0)
let ff = Monitor.Neg tt

let rec conv_fo fv =
  let rec lup i n = function
    | (v :: vs) -> if i = v then n else lup i (n + 1) vs in
  let rec conv_trm = function
    | Const c -> const c
    | Var v -> var (lup v 0 fv)
    | Mult (t1, t2) -> Monitor.Mult (conv_trm t1, conv_trm t2) in
  let conv_i = function
    | FO.TimestampInt.Interval (l, r, b1, b2) -> Monitor.interval (match l with Some l' -> nat_of_int (if b1 then l' else l' + 1))  (match r with Some r' -> Monitor.Enat (nat_of_int (if b2 then r' else r' - 1)) | None -> Monitor.Infinity_enat) in
  let rec aux fv = function
    | False -> ff
    | True -> tt
    | Eq (x, t) -> Monitor.Eq (conv_trm (Var x), conv_trm t)
    | Pred (r, ts) -> Monitor.Pred (r, List.map conv_trm ts)
    | Neg f -> Monitor.Neg (conv_fo fv f)
    | Conj (f, g) -> Monitor.And (conv_fo fv f, conv_fo fv g)
    | Disj (f, g) -> Monitor.Or (conv_fo fv f, conv_fo fv g)
    | Exists (v, f) -> Monitor.Exists (conv_fo (v :: fv) f)
    | Cnt (c, vs, f) -> Monitor.Agg (nat_of_int (lup c 0 fv), (Monitor.Agg_Cnt, Monitor.EInt (Z.of_int 0)), nat_of_int (List.length vs), const 1, conv_fo (vs @ fv) f)
    | Prev (i, f) -> Monitor.Prev (conv_i i, conv_fo fv f)
    | Next (i, f) -> Monitor.Next (conv_i i, conv_fo fv f)
    | Since (f, i, g) -> Monitor.Since (conv_fo fv f, conv_i i, conv_fo fv g)
    | Until (f, i, g) -> Monitor.Until (conv_fo fv f, conv_i i, conv_fo fv g)
  in aux fv

let map = Hashtbl.create 100000

let rec down p i = (if p i then (if i = 0 then 0 else down p (i - 1)) else i + 1)

let rec prog f ts = (match f with
  | Neg f -> prog f ts
  | Conj (f, g) -> min (prog f ts) (prog g ts)
  | Disj (f, g) -> min (prog f ts) (prog g ts)
  | Exists (v, f) -> prog f ts
  | Cnt (c, vs, f) -> prog f ts
  | Prev (ii, f) -> min (List.length ts) (prog f ts + 1)
  | Next (ii, f) -> (let p = prog f ts in if p = 0 then p else p - 1)
  | Since (f, ii, g) -> min (prog f ts) (prog g ts)
  | Until (f, ii, g) ->
    if List.length ts = 0 then 0
    else
      let k = min (List.length ts - 1) (min (prog f ts) (prog g ts)) in
      down (fun j -> FO.TimestampInt.memR (Some (Z.to_int (List.nth ts j))) (Some (Z.to_int (List.nth ts k))) ii) k
  | _ -> List.length ts)

let eval f log =
  try
    Hashtbl.find map f
  with
    | Not_found ->
      let p = prog f (List.map (fun (_, ts) -> ts) log) in
      let init_state = Monitor.minit_safe (conv_fo (fv_fmla f) f) in
      let (cst, i, _) = List.fold_left (fun (cst, i, st) (db, ts) ->
        let (xs, st') = Monitor.mstep (db, Monitor.nat_of_integer ts) st in
        let (cst', i') = List.fold_left (fun (cst, i) (_, (_, Monitor.RBT_set x)) ->
          let sz = Monitor.rbt_fold (fun _ c -> c + 1) x 0 in
          (if i < p then (cst + sz, i + 1) else (cst, i))) (cst, i) xs in
        (cst', i', st')
      ) (0, 0, init_state) log in
      let _ = assert (i = p) in
      let res = List.length (fv_fmla f) * cst in
      Hashtbl.add map f res; res

let rec subs = function
  | Neg f -> Misc.union (subs f) [Neg f]
  | Conj (f, g) -> Misc.union (Misc.union (subs f) (subs g)) [Conj (f, g)]
  | Disj (f, g) -> Misc.union (Misc.union (subs f) (subs g)) [Disj (f, g)]
  | Exists (v, f) -> Misc.union (subs f) [Exists (v, f)]
  | Cnt (c, vs, f) -> Misc.union (subs f) [Cnt (c, vs, f)]
  | Prev (i, f) -> Misc.union (subs f) [Prev (i, f)]
  | Next (i, f) -> Misc.union (subs f) [Next (i, f)]
  | Since (f, i, g) -> Misc.union (subs f) [Since (f, i, g)]
  | Until (f, i, g) -> Misc.union (subs f) [Until (f, i, g)]
  | f -> [f]

let rec sum = function
  | [] -> 0
  | x :: xs -> x + sum xs

let cost log f =
  let cst = sum (List.map (fun f -> eval f log) (List.filter ranf (subs f))) in
  (prog f (List.map (fun (_, ts) -> ts) log), cst)

let dump prefix fin inf nfin ninf nrfin nrinf =
  let _ =
      (let ch = open_out (prefix ^ nfin) in
      Printf.fprintf ch "%s\n" (string_of_fmla string_of_int (fun f -> f) fin); close_out ch) in
  let _ =
      (let ch = open_out (prefix ^ ninf) in
      Printf.fprintf ch "%s\n" (string_of_fmla string_of_int (fun f -> f) inf); close_out ch) in
  let _ =
      (let ch = open_out (prefix ^ nrfin) in
      Printf.fprintf ch "%s\n" (ra_of_fmla string_of_int (fun f -> f) fin); close_out ch) in
  let _ =
      (let ch = open_out (prefix ^ nrinf) in
      Printf.fprintf ch "%s\n" (ra_of_fmla string_of_int (fun f -> f) inf); close_out ch) in
  ()

let rec conj = function
  | [] -> True
  | [f] -> f
  | (f :: fs) -> Conj (f, conj fs)

let tdump prefix fin inf name pname =
  let f = ssrnf (Disj (conj (inf :: Eq ("__inf", Const 1) :: List.map (fun v -> Eq (v, Const 1)) (fv_fmla fin)),
                       conj (Neg inf :: Eq ("__inf", Const 0) :: fin :: []))) in
  let _ = assert (is_srnf f) in
  let _ = assert (ranf f) in
  let _ =
      (let ch = open_out (prefix ^ name) in
      Printf.fprintf ch "%s\n" (string_of_fmla string_of_int (fun f -> f) f); close_out ch) in
  let _ =
      (let ch = open_out (prefix ^ pname) in
      Printf.fprintf ch "%s\n" (pp_fmla string_of_int (fun f -> f) f); close_out ch) in
  ()

let tparse prefix =
  let f =
    (let ch = open_in (prefix ^ ".mfotl") in
     let f = Fo_parser.formula Fo_lexer.token (Lexing.from_channel ch) in
     (close_in ch; f)) in
  let tlog =
    (let ch = open_in (prefix ^ ".tlog") in
     let log = Log_parser.log Log_lexer.token (Lexing.from_channel ch) in
     (close_in ch; List.map (fun (db, ts) -> (conv_db db, ts)) log)) in
  (f, tlog)

let rtrans prefix log f =
  let (sfin, sinf) = rtrans (cost log) f in
  let _ = assert (is_srnf sfin) in
  let _ = assert (is_srnf sinf) in
  let _ = assert (ranf sfin) in
  let _ = assert (ranf sinf) in
  let _ = tdump prefix sfin sinf "smfotl" "pmfotl" in
  ()
