module type Timestamp = sig
  type t
  type inter = Interval of t * t * bool * bool
  val zero: t
  val tfin: t -> bool
  val le: t -> t -> bool
  val lt: t -> t -> bool
  val add: t -> t -> t
  val string_of_i: inter -> string
  val memL: t -> t -> inter -> bool
  val memR: t -> t -> inter -> bool
  val rightI: inter -> t
  val isFull: inter -> bool
  val dropL: inter -> inter
  val dropR: inter -> inter
  val flipL: inter -> inter
end

module FO (T: Timestamp) : sig
  type 'a term =
      Const of 'a
    | Var of string
    | Mult of 'a term * 'a term
  type 'a fmla =
      False
    | True
    | Eq of string * 'a term
    | Pred of string * 'a term list
    | Neg of 'a fmla
    | Disj of 'a fmla * 'a fmla
    | Conj of 'a fmla * 'a fmla
    | Exists of string * 'a fmla
    | Cnt of string * string list * 'a fmla
    | Prev of T.inter * 'a fmla
    | Next of T.inter * 'a fmla
    | Since of 'a fmla * T.inter * 'a fmla
    | Until of 'a fmla * T.inter * 'a fmla
  val fv_fmla: 'a fmla -> string list
  val ranf: 'a fmla -> bool
  val string_of_fmla: ('a -> string) -> (string -> string) -> 'a fmla -> string
  val pp_fmla: ('a -> string) -> (string -> string) -> 'a fmla -> string
  val ra_of_fmla: ('a -> string) -> (string -> string) -> 'a fmla -> string
  val agg_of_fmla: ('a fmla -> int * int) -> 'a fmla -> 'a fmla
  val is_srnf: 'a fmla -> bool
  val srnf: 'a fmla -> 'a fmla
  val ssrnf: 'a fmla -> 'a fmla
  val sr: 'a fmla -> bool
  val evaluable: 'a fmla -> bool
  val rtrans: (int fmla -> int * int) -> int fmla -> int fmla * int fmla
end = struct
  
type 'a term =
    Const of 'a
  | Var of string
  | Mult of 'a term * 'a term
type 'a fmla =
    False
  | True
  | Eq of string * 'a term
  | Pred of string * 'a term list
  | Neg of 'a fmla
  | Disj of 'a fmla * 'a fmla
  | Conj of 'a fmla * 'a fmla
  | Exists of string * 'a fmla
  | Cnt of string * string list * 'a fmla
  | Prev of T.inter * 'a fmla
  | Next of T.inter * 'a fmla
  | Since of 'a fmla * T.inter * 'a fmla
  | Until of 'a fmla * T.inter * 'a fmla

let rec fv_term = function
  | Const n -> []
  | Var v -> [v]
  | Mult (t1, t2) -> Misc.union (fv_term t1) (fv_term t2)

let fv_terms ts = Misc.union' (List.map fv_term ts)

let rec fv_fmla = function
  | False -> []
  | True -> []
  | Eq (v, t) -> Misc.union [v] (fv_term t)
  | Pred (r, ts) -> fv_terms ts
  | Neg f -> fv_fmla f
  | Disj (f, g) -> Misc.union (fv_fmla f) (fv_fmla g)
  | Conj (f, g) -> Misc.union (fv_fmla f) (fv_fmla g)
  | Exists (v, f) -> Misc.diff (fv_fmla f) [v]
  | Cnt (c, vs, f) -> Misc.union [c] (Misc.diff (fv_fmla f) vs)
  | Prev (i, f) -> fv_fmla f
  | Next (i, f) -> fv_fmla f
  | Since (f, i, g) -> Misc.union (fv_fmla f) (fv_fmla g)
  | Until (f, i, g) -> Misc.union (fv_fmla f) (fv_fmla g)

let fv_fmlas fs = Misc.union' (List.map fv_fmla fs)

(* Figure 2.15 *)
let rec ranf = function
  | False -> true
  | True -> true
  | Eq (v, Const c) -> true
  | Eq (v, Var v') -> false
  | Eq (v, Mult (t1, t2)) -> false
  | Pred (r, ts) -> true
  | Neg f -> ranf f && Misc.empty (fv_fmla f)
  | Disj (f, g) -> ranf f && ranf g && Misc.equal (fv_fmla f) (fv_fmla g)
  | Conj (f, g) -> ranf f && (match g with
    | Eq (v, Var v') -> List.mem v (fv_fmla f) || List.mem v' (fv_fmla f)
    | Eq (v, Mult (t1, t2)) -> Misc.subset (fv_term (Mult (t1, t2))) (fv_fmla f)
    | Neg (Eq (v, t)) -> List.mem v (fv_fmla f) && Misc.subset (fv_term t) (fv_fmla f)
    | Neg g' -> ranf g' && Misc.subset (fv_fmla g') (fv_fmla f)
    | _ -> ranf g)
  | Exists (v, f) -> ranf f && List.mem v (fv_fmla f)
  | Cnt (c, vs, f) -> ranf f && not (List.mem c (fv_fmla f)) && Misc.subset vs (fv_fmla f)
  | Prev (i, f) -> ranf f
  | Next (i, f) -> ranf f
  | Since (f, i, g) -> ranf g && (match f with
    | Neg f' -> ranf f' && Misc.subset (fv_fmla f') (fv_fmla g)
    | _ -> ranf f && Misc.subset (fv_fmla f) (fv_fmla g))
  | Until (f, i, g) -> ranf g && (match f with
    | Neg f' -> ranf f' && Misc.subset (fv_fmla f') (fv_fmla g)
    | _ -> ranf f && Misc.subset (fv_fmla f) (fv_fmla g))

let string_of_list string_of_val xs = String.concat ", " (List.map string_of_val xs)

let rec string_of_fmla string_of_val string_of_var =
  let rec string_of_trm = function
    | Const n -> string_of_val n
    | Var v -> string_of_var v
    | Mult (t1, t2) -> "(" ^ string_of_trm t1 ^ " * " ^ string_of_trm t2 ^ ")" in
  let rec aux = function
  | False -> "FALSE"
  | True -> "TRUE"
  | Eq (v, t) -> string_of_var v ^ " = " ^ string_of_trm t
  | Pred (name, ts) -> name ^ "(" ^ string_of_list string_of_trm ts ^ ")"
  | Neg f -> "NOT (" ^ aux f ^ ")"
  | Disj (f, g) -> "(" ^ aux f ^ ") OR (" ^ aux g ^ ")"
  | Conj (f, g) -> "(" ^ aux f ^ ") AND (" ^ aux g ^ ")"
  | Exists (v, f) -> "EXISTS " ^ string_of_var v ^ ". (" ^ aux f ^ ")"
  | Cnt (c, [], f) -> "(" ^ aux f ^ ") AND (c = 1)"
  | Cnt (c, v :: vs, f) ->
    let gs = (match Misc.diff (fv_fmla f) (v :: vs) with [] -> "" | gs -> "; " ^ string_of_list string_of_var gs) in
    string_of_var c ^ " <- CNT " ^ string_of_var v ^ gs ^ " " ^ aux f
  | Prev (i, f) -> "PREVIOUS" ^ T.string_of_i i ^ " (" ^ aux f ^ ")"
  | Next (i, f) -> "NEXT" ^ T.string_of_i i ^ " (" ^ aux f ^ ")"
  | Since (f, i, g) -> (match f with True -> "ONCE" | _ -> "(" ^ aux f ^ ") SINCE") ^ T.string_of_i i ^ " (" ^ aux g ^ ")"
  | Until (f, i, g) -> (match f with True -> "EVENTUALLY" | _ -> "(" ^ aux f ^ ") UNTIL") ^ T.string_of_i i ^ " (" ^ aux g ^ ")"
  in aux

let printfmlas fs = Printf.printf "%s\n" (String.concat "$ " (List.map (string_of_fmla string_of_int (fun f -> f)) fs))
let printints ns = Printf.printf "%s\n" (String.concat "$ " (List.map string_of_int ns))
let printvars vs = Printf.printf "%s\n" (String.concat ", " vs)

let rec flatten_ex = function
  | Exists (v, f) -> let (vs, f') = flatten_ex f in (v :: vs, f')
  | f -> ([], f)

let exists vs f = List.fold_right (fun x f' -> if List.mem x (fv_fmla f') then Exists (x, f') else f') vs f
let proj v = exists [v]

let ra_of_fmla string_of_val string_of_var =
  let rec string_of_trm = function
    | Const n -> string_of_val n
    | Var v -> string_of_var v
    | Mult (t1, t2) -> "(" ^ string_of_trm t1 ^ " * " ^ string_of_trm t2 ^ ")" in
  let rec aux f =
    let fv = List.sort compare (fv_fmla f) in
    match f with
      | False -> "\\select_{0 = 1} tbl"
      | True -> "tbl"
      | Eq (v, Const c) -> "\\rename_{" ^ string_of_var v ^ "} \\project_{" ^ string_of_val c ^ "} tbl"
      | Pred (r, ts) ->
        let rec lup y n = function
          | (z :: zs) -> if y = z then n else lup y (n + 1) zs in
        let rec bs n = function
          | [] -> []
          | (Const c :: ts') -> ("x" ^ string_of_int n ^ " = " ^ string_of_val c) :: bs (n + 1) ts'
          | (Var v :: ts') -> let n' = lup (Var v) 0 ts in
            if n = n' then bs (n + 1) ts'
            else ("x" ^ string_of_int n ^ " = " ^ "x" ^ string_of_int n') :: bs (n + 1) ts'
        in let sel = match bs 0 ts with
            [] -> "tbl_" ^ r
          | cs -> "\\select_{" ^ String.concat " AND " cs ^ "} " ^ "tbl_" ^ r
        in (match fv with [] -> "\\project_{t} (tbl \\cross " ^ sel ^ ")"
          | _ -> "\\rename_{" ^ string_of_list string_of_var fv ^ "} \\project_{" ^
          string_of_list (fun v -> "x" ^ string_of_int (lup (Var v) 0 ts)) fv ^ "} " ^ sel)
      | Neg f -> "tbl \\diff (" ^ aux f ^ ")"
      | Disj (f, g) -> "(" ^ aux f ^ ") \\union (" ^ aux g ^ ")"
      | Conj (f, g) ->
        let zs = match fv with [] -> "t" | _ -> string_of_list string_of_var fv in
        if ranf g then "\\project_{" ^ zs ^ "} ((" ^ aux f ^ ") \\join (" ^ aux g ^ "))"
        else (match g with
            Eq (v, Var v') -> if Misc.subset [v; v'] (fv_fmla f) then
              "\\select_{" ^ string_of_var v ^ " = " ^ string_of_var v' ^ "} (" ^ aux f ^ ")"
              else if List.mem v (fv_fmla f) then "\\rename_{" ^ zs ^ "} \\project_{" ^
                string_of_list string_of_var (List.map (fun v'' -> if v'' = v' then v else v'') fv) ^
                "} (" ^ aux f ^ ")"
              else  "\\rename_{" ^ zs ^ "} \\project_{" ^
                string_of_list string_of_var (List.map (fun v'' -> if v'' = v then v' else v'') fv) ^
                "} (" ^ aux f ^ ")"
          | Eq (v, Mult (t1, t2)) -> if List.mem v (fv_fmla f) then
              "\\select_{" ^ string_of_var v ^ " = " ^ string_of_trm (Mult (t1, t2)) ^ "} (" ^ aux f ^ ")"
              else  "\\rename_{" ^ zs ^ "} \\project_{" ^
                string_of_list string_of_trm (List.map (fun v'' -> if v'' = v then Mult (t1, t2) else Var v'') fv) ^
                "} (" ^ aux f ^ ")"
          | Neg (Eq (v, t)) -> "\\select_{" ^ string_of_var v ^ " <> " ^ string_of_trm t ^
              "} (" ^ aux f ^ ")"
          | Neg g' -> "(" ^ aux f ^ ") \\diff (" ^ aux g' ^ ")")
      | Exists (v, f) ->
        let (_, f') = flatten_ex (Exists (v, f)) in
        (match fv with [] -> "\\project_{t} (tbl \\cross (" ^ aux f' ^ "))"
        | _ -> "\\project_{" ^ string_of_list string_of_var fv ^ "} (" ^ aux f' ^ ")")
      | Cnt (c, vs, f) ->
        let sc = string_of_var c in
        let xs = Misc.diff fv [c] in
        let sxs = string_of_list string_of_var xs in
        (match xs with [] -> "\\rename_{" ^ sc ^ "} \\aggr_{COUNT(1)} (" ^ aux f ^ ")"
        | _ -> "\\project_{" ^ string_of_list string_of_var fv ^ "} \\rename_{" ^
          sxs ^ ", " ^ sc ^ "} \\aggr_{" ^
          sxs ^ ": COUNT(1)} (" ^ aux f ^ ")")
  in aux

(* Figure 2.9 *)
let rec cp = function
  | False -> False
  | True -> True
  | Pred (r, ts) -> Pred (r, ts)
  | Eq (v, Const c) -> Eq (v, Const c)
  | Eq (v, Var v') -> if v = v' then True else Eq (v, Var v')
  | Eq (v, Mult (t1, t2)) -> Eq (v, Mult (t1, t2))
  | Neg f -> (match cp f with
      False -> True
    | True -> False
    | f' -> Neg f')
  | Conj (f, g) -> (match (cp f, cp g) with
      (False, _) -> False
    | (True, g') -> g'
    | (_, False) -> False
    | (f', True) -> f'
    | (f', g') -> Conj (f', g'))
  | Disj (f, g) -> (match (cp f, cp g) with
      (False, g') -> g'
    | (True, _) -> True
    | (f', False) -> f'
    | (_, True) -> True
    | (f', g') -> Disj (f', g'))
  | Exists (v, f) -> (match cp f with
      False -> False
    | True -> True
    | f' -> if List.mem v (fv_fmla f') then Exists (v, f') else f')
  | Cnt (c, vs, f) -> (match cp f with
      False -> False
    | f' -> Cnt (c, vs, f'))
  | Prev (i, f) -> (match cp f with
      False -> False
    | f' -> Prev (i, f'))
  | Next (i, f) -> (match cp f with
      False -> False
    | f' -> Next (i, f'))
  | Since (f, i, g) -> (match cp g with
      False -> False
    | g' -> Since (cp f, i, g'))
  | Until (f, i, g) -> (match cp g with
      False -> False
    | g' -> Until (cp f, i, g'))

let fresh_var fv =
  let rec fresh_var_rec v =
    let var = "x" ^ (string_of_int v) in
    if List.mem var fv then fresh_var_rec (v + 1)
    else var
  in fresh_var_rec 0

(* Definition 2.9 *)
let rec rename i j f =
  let rename_var i j v = if i = v then j else v in
  let rec rename_trm i j = function
    | Const c -> Const c
    | Var v -> Var (rename_var i j v)
    | Mult (t1, t2) -> Mult (rename_trm i j t1, rename_trm i j t2) in
  let rec aux i j = function
    | False -> False
    | True -> True
    | Eq (v, t) -> Eq (rename_var i j v, rename_trm i j t)
    | Pred (r, ts) -> Pred (r, List.map (rename_trm i j) ts)
    | Neg f -> Neg (aux i j f)
    | Conj (f, g) -> Conj (aux i j f, aux i j g)
    | Disj (f, g) -> Disj (aux i j f, aux i j g)
    | Exists (v, f) ->
      if i = v then Exists (v, f)
      else if j = v then
        let v' = fresh_var (i :: j :: fv_fmla f) in
        Exists (v', aux i j (aux v v' f))
      else Exists (v, aux i j f)
    | Prev (ii, f) -> Prev (ii, aux i j f)
    | Next (ii, f) -> Next (ii, aux i j f)
    | Since (f, ii, g) -> Since (aux i j f, ii, aux i j g)
    | Until (f, ii, g) -> Until (aux i j f, ii, aux i j g)
  in cp (aux i j f)

let eq_trans v es =
  let eq_derive vs (v, v') = if List.mem v vs || List.mem v' vs then [v; v'] else [] in
  let rec aux vs =
    let vs' = Misc.union vs (Misc.union' (List.map (eq_derive vs) es)) in
    if vs = vs' then vs else aux vs' in
  aux [v]

let splitconj fs =
  let rec aux (ps, eqs, nexs, nots) = function
    | [] -> (List.rev ps, List.rev eqs, List.rev nexs, List.rev nots)
    | Eq (v, Var v') :: fs' -> aux (ps, Eq (v, Var v') :: eqs, nexs, nots) fs'
    | Eq (v, Mult (t1, t2)) :: fs' -> aux (ps, Eq (v, Mult (t1, t2)) :: eqs, nexs, nots) fs'
    | Neg (Exists (v, f)) :: fs' -> aux (ps, eqs, Neg (Exists (v, f)) :: nexs, nots) fs'
    | Neg f :: fs' -> aux (ps, eqs, nexs, Neg f :: nots) fs'
    | f :: fs' -> aux (f :: ps, eqs, nexs, nots) fs'
  in aux ([], [], [], []) fs

let rec flatten_conj = function
  | Conj (f, g) -> Misc.union (flatten_conj f) (flatten_conj g)
  | f -> [f]

let conj fs =
  let rec aux = function
    | [] -> True
    | [f] -> f
    | (f :: fs) -> Conj (aux fs, f)
  in cp (aux (List.rev (Misc.remdups fs)))

let rec insorte v v' acc = function
  | [] -> List.rev (Eq (v, Var v') :: acc)
  | f :: fs ->
    let vs = fv_fmlas acc in
    if List.mem v vs || List.mem v' vs then List.rev (Eq (v, Var v') :: acc) @ f :: fs else insorte v v' (f :: acc) fs

let rec insortet v t acc = function
  | [] -> List.rev (Eq (v, t) :: acc)
  | f :: fs ->
    let vs = fv_fmlas acc in
    if Misc.subset (fv_term t) vs then List.rev (Eq (v, t) :: acc) @ f :: fs else insortet v t (f :: acc) fs

let rec insortes ps = function
  | [] -> ps
  | Eq (v, Var v') :: es -> insortes (insorte v v' [] ps) es
  | Eq (v, Mult (t1, t2)) :: es -> insortes (insortet v (Mult (t1, t2)) [] ps) es

let rec insortn n acc = function
  | [] -> List.rev (n :: acc)
  | f :: fs ->
    if Misc.subset (fv_fmla n) (fv_fmlas acc) then List.rev (n :: acc) @ f :: fs else insortn n (f :: acc) fs

let rec insortns ps = function
  | [] -> ps
  | n :: ns -> insortns (insortn n [] ps) ns

let rconj fs =
  let (ps, eqs, nexs, nots) = splitconj (List.concat (List.map flatten_conj fs)) in
  match Misc.inter (ps @ eqs) (List.map (fun f -> match f with Neg f -> f) (nexs @ nots)) with [] -> conj fs
  | _ -> False

let sconj fs =
  let (ps, eqs, nexs, nots) = splitconj (List.concat (List.map flatten_conj fs)) in
  match Misc.inter (ps @ eqs) (List.map (fun f -> match f with Neg f -> f) (nexs @ nots)) with [] ->
    let ps' = List.sort (fun g f -> compare (List.length (fv_fmla f)) (List.length (fv_fmla g))) ps in
    conj (insortns (insortes ps' eqs) (nexs @ nots))
  | _ -> False

let rec sz = function
  | Neg f -> 1 + sz f
  | Conj (f, g) -> 1 + sz f + sz g
  | Disj (f, g) -> 1 + sz f + sz g
  | Exists (v, f) -> 1 + sz f
  | Cnt (c, vs, f) -> 1 + sz f
  | Prev (i, f) -> 1 + sz f
  | Next (i, f) -> 1 + sz f
  | Since (f, i, g) -> 1 + sz f + sz g
  | Until (f, i, g) -> 1 + sz f + sz g
  | _ -> 1

let opt_choice cost =
  let rec aux = function
    | [] -> failwith "[opt_choice] empty set"
    | [f] -> f
    | (f :: f' :: fs) ->
      let (p, c) = cost f in
      let (p', c') = cost f' in
      if p > p' || (p = p' && c < c') then aux (f :: fs)
      else aux (f' :: fs)
  in aux

let perms =
  let rec ins y = function
    | [] -> [[y]]
    | (x :: xs) -> (y :: x :: xs) :: List.map (fun zs -> x :: zs) (ins y xs)
  in let rec aux = function
    | [] -> [[]]
    | v :: vs ->
      List.concat (List.map (ins v) (aux vs))
  in aux

let rec flatten_disj = function
  | Disj (f, g) -> Misc.union (flatten_disj f) (flatten_disj g)
  | f -> [f]

let disj fs =
  let rec aux = function
    | [] -> False
    | [f] -> f
    | (f :: fs) -> Disj (aux fs, f)
  in cp (aux (List.rev (Misc.remdups fs)))

let rec pp_fmla string_of_val string_of_var =
  let rec repl n c = if n = 0 then "" else c ^ repl (n - 1) c in
  let rec string_of_trm = function
    | Const n -> string_of_val n
    | Var v -> string_of_var v
    | Mult (t1, t2) -> "(" ^ string_of_trm t1 ^ " * " ^ string_of_trm t2 ^ ")" in
  let rec aux n = function
  | False -> repl n "|" ^ "FALSE\n"
  | True -> repl n "|" ^ "TRUE\n"
  | Eq (v, t) -> repl n "|" ^ string_of_var v ^ " = " ^ string_of_trm t ^ "\n"
  | Pred (name, ts) -> repl n "|" ^ name ^ "(" ^ string_of_list string_of_trm ts ^ ")\n"
  | Neg f -> repl n "|" ^ "NOT\n" ^ aux (n + 1) f
  | Disj (f, g) -> repl n "|" ^ "OR\n" ^ String.concat "" (List.map (aux (n + 1)) (flatten_disj (Disj (f, g))))
  | Conj (f, g) -> repl n "|" ^ "AND\n" ^ String.concat "" (List.map (aux (n + 1)) (flatten_conj (Conj (f, g))))
  | Exists (v, f) -> let (vs, f') = flatten_ex (Exists (v, f)) in repl n "|" ^ "EXISTS " ^ String.concat " " (List.map string_of_var vs) ^ ".\n" ^ aux (n + 1) f'
  | Cnt (c, vs, f) -> repl n "|" ^ string_of_var c ^ " <- CNT " ^ String.concat " " (List.map string_of_var vs) ^ "\n" ^ aux (n + 1) f
  | Prev (i, f) -> repl n "|" ^ "PREVIOUS" ^ T.string_of_i i ^ "\n" ^ aux (n + 1) f
  | Next (i, f) -> repl n "|" ^ "NEXT" ^ T.string_of_i i ^ "\n" ^ aux (n + 1) f
  | Since (f, i, g) -> repl n "|" ^ "SINCE" ^ T.string_of_i i ^ "\n" ^ aux (n + 1) f ^ aux (n + 1) g
  | Until (f, i, g) -> repl n "|" ^ "UNTIL" ^ T.string_of_i i ^ "\n" ^ aux (n + 1) f ^ aux (n + 1) g
  in aux 0

let rec is_srnf = function
  | Neg (Neg _) -> false
  | Neg (Disj _) -> false
  | Neg (Conj _) -> false
  | Neg f -> is_srnf f
  | Disj (f, g) -> is_srnf f && is_srnf g
  | Conj (f, g) -> is_srnf f && is_srnf g
  | Exists (v, Disj _) -> false
  | Exists (v, f) -> List.mem v (fv_fmla f) && is_srnf f
  | Prev (i, f) -> is_srnf f
  | Next (i, f) -> is_srnf f
  | Since (Neg f, i, g) -> is_srnf f && is_srnf g
  | Since (f, i, g) -> is_srnf f && is_srnf g
  | Until (Neg f, i, g) -> is_srnf f && is_srnf g
  | Until (f, i, g) -> is_srnf f && is_srnf g
  | _ -> true

(* Figures 2.14 and 4.9 *)
let rec srnf = function
  | Neg (Neg f) -> srnf f
  | Neg (Disj (f, g)) -> srnf (Conj (Neg f, Neg g))
  | Neg (Conj (f, g)) -> srnf (Disj (Neg f, Neg g))
  | Neg (Exists (v, f)) ->
    let (vs, f') = flatten_ex (Exists (v, f)) in
    if Misc.disjoint vs (fv_fmla f') then srnf (Neg f') else
    (match srnf f' with
    | Disj (f'', g'') -> srnf (Conj (Neg (exists vs f''), Neg (exists vs g'')))
    | f'' -> Neg (exists vs f''))
  | Neg f -> Neg (srnf f)
  | Disj (f, g) -> disj (List.map srnf (flatten_disj (Disj (f, g))))
  | Conj (f, g) -> rconj (List.map srnf (flatten_conj (Conj (f, g))))
  | Exists (v, f) ->
    let (vs, f') = flatten_ex (Exists (v, f)) in
    (match srnf f' with
    | Disj (f'', g'') -> srnf (Disj (exists vs f'', exists vs g''))
    | f'' -> exists vs f'')
  | Cnt (c, vs, f) -> Cnt (c, vs, srnf f)
  | Prev (i, f) -> Prev (i, srnf f)
  | Next (i, f) -> Next (i, srnf f)
  | Since (Neg f, i, g) -> Since (Neg (srnf f), i, srnf g)
  | Since (f, i, g) -> Since (srnf f, i, srnf g)
  | Until (Neg f, i, g) -> Until (Neg (srnf f), i, srnf g)
  | Until (f, i, g) -> Until (srnf f, i, srnf g)
  | f -> f

let neg f = Neg f

let rec ssrnf = function
  | Neg (Neg f) -> ssrnf f
  | Neg (Disj (f, g)) -> ssrnf (Conj (Neg f, Neg g))
  | Neg (Conj (f, g)) -> ssrnf (Disj (Neg f, Neg g))
  | Neg (Exists (v, f)) ->
    let (vs, f') = flatten_ex (Exists (v, f)) in
    (match ssrnf f' with
    | Disj (f'', g'') -> ssrnf (Conj (Neg (exists vs f''), Neg (exists vs g'')))
    | f'' -> Neg (exists vs f''))
  | Neg f -> Neg (ssrnf f)
  | Disj (f, g) -> disj (List.map ssrnf (flatten_disj (Disj (f, g))))
  | Conj (f, g) ->
    let (fps, feqs, fnexs, fns) = splitconj (flatten_conj (Conj (f, g))) in
    let ps' = List.map ssrnf fps @ feqs in
    let ns' = List.map (fun f -> match f with Neg f' -> ssrnf f') (fnexs @ fns) in
    let nns' = List.filter (fun f -> match f with Neg _ -> true | _ -> false) ns' in
    let cns' = List.filter (fun f -> match f with Conj _ -> true | _ -> false) ns' in
    let dns' = List.filter (fun f -> match f with Disj _ -> true | _ -> false) ns' in
    let ens' = List.filter (fun f -> match f with Neg _ -> false | Conj _ -> false | Disj _ -> false | _ -> true) ns' in
    let ps' = ps' @ List.map (fun f -> match f with Neg f' -> f') nns' in
    let ps' = (match cns' with [] -> ps' | _ -> List.map (fun c -> disj (List.map (fun c -> sconj (ps' @ [Neg c])) (flatten_conj c))) cns') in
    (match nns' @ cns' @ dns' with [] -> sconj (ps' @ List.map neg ens')
    | _ -> ssrnf (sconj (ps' @ List.concat (List.map (fun f -> List.map neg (flatten_disj f)) dns') @ List.map neg ens')))
  | Exists (v, f) ->
    let (vs, f') = flatten_ex (Exists (v, f)) in
    (match ssrnf f' with
    | Disj (f'', g'') -> ssrnf (Disj (exists vs f'', exists vs g''))
    | f'' -> exists vs f'')
  | Cnt (c, vs, f) -> Cnt (c, vs, ssrnf f)
  | Prev (i, f) -> Prev (i, ssrnf f)
  | Next (i, f) -> Next (i, ssrnf f)
  | Since (Neg f, i, g) -> Since (Neg (ssrnf f), i, ssrnf g)
  | Since (f, i, g) -> Since (ssrnf f, i, ssrnf g)
  | Until (Neg f, i, g) -> Until (Neg (ssrnf f), i, ssrnf g)
  | Until (f, i, g) -> Until (ssrnf f, i, ssrnf g)
  | f -> f

let rec powset = function
  | [] -> [[]]
  | x :: xs -> let xss = powset xs in List.map (fun xs -> x :: xs) xss @ xss

(* Lemma 4.21 *)
let agg1 vs f =
  let (fps, feqs, fnexs, fns) = splitconj (flatten_conj f) in
  let ns = fnexs @ fns in
  match ns with [] -> exists vs f
  | _ ->
    let ps = fps @ feqs in
    let cps = sconj ps in
    let fvps = fv_fmla cps in
    let exps = exists vs cps in
    let c = fresh_var fvps in
    let c' = fresh_var (Misc.union fvps [c]) in
    let nps = List.map (fun n -> match n with Neg n' -> sconj (ps @ [n'])) ns in
    let nexnps = List.map (fun f -> Neg (exists vs f)) nps in
    disj [sconj (exps :: nexnps); exists [c; c'] (sconj (Cnt (c, vs, cps) :: Cnt (c', vs, disj nps) :: Neg (Eq (c, Var c')) :: []))]

(* Lemma 4.22 *)
let agg2 s' vs f' =
  let (fps, feqs, fnexs, fns) = splitconj (flatten_conj f') in
  let ns = fnexs @ fns in
  match ns with [] -> sconj (s' @ [Neg (exists vs f')])
  | _ ->
    let ps = fps @ feqs in
    let cps = sconj ps in
    let fvsps = Misc.union (fv_fmlas s') (fv_fmla cps) in
    let exps = exists vs cps in
    let c = fresh_var fvsps in
    let c' = fresh_var (Misc.union fvsps [c]) in
    let nps = List.map (fun n -> match n with Neg n' -> sconj (ps @ [n'])) ns in
    disj [sconj (s' @ [Neg exps]); exists [c; c'] (sconj (s' @ Cnt (c, vs, cps) :: Cnt (c', vs, disj nps) :: Eq (c, Var c') :: []))]

let drop fs =
  let rec aux f =
    if List.mem f fs then True
    else (match f with
      | Neg f -> Neg (aux f)
      | Disj (f, g) -> Disj (aux f, aux g)
      | Conj (f, g) -> Conj (aux f, aux g)
      | Exists (v, f) -> Exists (v, aux f)
      | Prev (i, f) -> Prev (i, aux f)
      | Next (i, f) -> Next (i, aux f)
      | Since (f, i, g) -> Since (aux f, i, aux g)
      | Until (f, i, g) -> Until (aux f, i, aux g)
      | _ -> f)
  in aux

let agg_of_fmla cost f =
  let mmap = Hashtbl.create 100000 in
  let rec ms f =
    try
      Hashtbl.find mmap f
    with
      | Not_found ->
        let f' = (match f with
    | False -> False
    | True -> True
    | Eq (v, t) -> Eq (v, t)
    | Pred (r, ts) -> Pred (r, ts)
    | Neg f -> Neg (ms f)
    | Disj (f, g) -> disj (flatten_disj (ms f) @ flatten_disj (ms g))
    | Conj (f, g) -> sconj (flatten_conj (ms f) @ flatten_conj (ms g))
    | Exists (v, f) ->
      let (vs, f') = flatten_ex (Exists (v, f)) in
      let fs' = flatten_disj (ms f') in
      opt_choice cost (List.map (fun vs ->
      let step = (fun v f' ->
      let vs = [v] in
      let fs = flatten_conj f' in
      let spullout = (fun fs' -> List.map (fun f'' -> cp (drop fs' f'')) (Misc.diff fs fs')) in
      let spull = (fun fs' -> sconj (spullout fs' @ [exists vs (sconj fs')])) in
      let fss' = List.filter (fun fs' -> Misc.disjoint (fv_fmlas (spullout fs')) vs && ranf (sconj fs') && ranf (spull fs')) (powset fs) in
      opt_choice cost (List.map (fun fs' -> if List.length fs' = List.length fs then spull fs else ms (spull fs')) fss')) in
      disj (List.fold_right (fun v -> List.map (step v)) vs fs')) (perms vs))
    | Cnt (c, vs, f) ->
      let fs = flatten_conj (ms f) in
      let spullout = (fun fs' -> List.map (fun f'' -> cp (drop fs' f'')) (Misc.diff fs fs')) in
      let spull = (fun fs' -> sconj (spullout fs' @ [Cnt (c, vs, sconj fs')])) in
      let fss' = List.filter (fun fs' -> Misc.disjoint (fv_fmlas (spullout fs')) vs && ranf (sconj fs') && ranf (spull fs')) (powset fs) in
      let candpull = List.map (fun fs' -> if List.length fs' = List.length fs then spull fs else ms (spull fs')) fss' in
      let smult = (fun fs' ->
          let fs'' = Misc.diff fs fs' in
          let c1 = fresh_var (Misc.union [c] (fv_fmlas fs)) in
          let c2 = fresh_var (Misc.union [c; c1] (fv_fmlas fs)) in
          exists [c1; c2] (sconj (Cnt (c1, Misc.inter vs (fv_fmlas fs'), sconj fs') ::
                  Cnt (c2, Misc.inter vs (fv_fmlas fs''), sconj fs'') :: Eq (c, Mult (Var c1, Var c2)) :: []))) in
      let fss' = List.filter (fun fs' -> let x1 = Misc.inter vs (fv_fmlas fs') in let x2 = Misc.inter vs (fv_fmlas (Misc.diff fs fs')) in
                                         Misc.disjoint x1 x2 && List.length x1 <> 0 && List.length x2 <> 0 && ranf (smult fs')) (powset fs) in
      let candmult = List.map (fun fs' -> ms (smult fs')) fss' in
      opt_choice cost (candpull @ candmult)
    | Prev (i, f) -> Prev (i, ms f)
    | Next (i, f) -> Next (i, ms f)
    | Since (f, i, g) -> Since (ms f, i, ms g)
    | Until (f, i, g) -> Until (ms f, i, ms g)) in
      Hashtbl.add mmap f f'; f'
  in let rec aux = function
    | False -> False
    | True -> True
    | Eq (v, t) -> Eq (v, t)
    | Pred (r, ts) -> Pred (r, ts)
    | Neg f -> Neg (aux f)
    | Disj (f, g) -> disj (flatten_disj (aux f) @ flatten_disj (aux g))
    | Conj (f, g) ->
      let (fps, feqs, fnexs, fns) = splitconj (flatten_conj (Conj (f, g))) in
      let ps' = List.map aux (fps @ feqs @ fns) in
      (match fnexs with [] -> sconj ps'
      | _ -> sconj (List.concat (List.map (fun f -> match f with Neg ex -> let (vs, f') = flatten_ex ex in List.concat (List.map (fun f'' -> flatten_conj (ms (agg2 ps' vs f''))) (flatten_disj (aux f')))) fnexs)))
    | Exists (v, f) ->
      let (vs, f') = flatten_ex (Exists (v, f)) in
      disj (List.map (fun f'' -> ms (agg1 vs f'')) (flatten_disj (aux f')))
    | Prev (i, f) -> Prev (i, aux f)
    | Next (i, f) -> Next (i, aux f)
    | Since (f, i, g) -> Since (aux f, i, aux g)
    | Until (f, i, g) -> Until (aux f, i, aux g)
  in ssrnf (aux (ms f))

(* Definition 2.10 *)
let var_bot x f =
  let rec aux = function
    | False -> False
    | True -> True
    | Eq (v, Const c) -> if x = v then False else Eq (v, Const c)
    | Eq (v, Var v') -> if v = v' then True
                        else if x = v || x = v' then False
                        else Eq (v, Var v')
    | Eq (v, Mult (t1, t2)) -> failwith "[var_bot]"
    | Pred (r, ts) -> if List.mem x (fv_terms ts) then False else Pred (r, ts)
    | Neg f -> Neg (aux f)
    | Conj (f, g) -> Conj (aux f, aux g)
    | Disj (f, g) -> Disj (aux f, aux g)
    | Exists (v, f) -> if x = v then Exists (v, f) else Exists (v, aux f)
    | Prev (i, f) -> Prev (i, aux f)
    | Next (i, f) -> Next (i, aux f)
    | Since (f, i, g) -> Since (aux f, i, aux g)
    | Until (f, i, g) -> Until (aux f, i, aux g)
  in cp (aux f)

let map_nested f xss = List.map (List.map f) xss

let rec pairwise f xs ys = match xs with [] -> []
                           | z :: zs -> Misc.union (List.map (f z) ys) (pairwise f zs ys)

let rec once i f = match f with
| Since (True, j, g) -> 
  if T.isFull j
    then if T.isFull i
         then once i g
         else Conj ((once (T.dropR i) g), (once i True))
    else Since (True, i, f)
| _ -> Since (True, i, f)


  (* ONCE [a,b] SINCE f *)
         

let rec eventually i f = match f with
| Until (True, j, g) -> 
  if T.isFull j
    then if T.isFull i
         then eventually i g
         else Conj ((eventually (T.dropR i) g), (eventually i True))
    else Until (True, i, f)
| _ -> Until (True, i, f)



(* Figure 2.10 *)
let rec gen v = function
  | False -> [[]]
  | True -> []
  | Eq (v', Const c) -> if v = v' then [[Eq (v, Const c)]] else []
  | Eq (v', Var v'') -> []
  | Pred (r, ts) -> if List.mem v (fv_terms ts) then [[Pred (r, ts)]] else []
  | Neg (Neg f) -> gen v f
  | Neg (Conj (f, g)) -> gen v (Disj (Neg f, Neg g))
  | Neg (Disj (f, g)) -> gen v (Conj (Neg f, Neg g))
  | Neg f -> []
  | Disj (f, g) -> pairwise Misc.union (gen v f) (gen v g)
  | Conj (f, (Eq (v', Var v''))) ->
    if v = v' then Misc.union (gen v f) (map_nested (rename v'' v) (gen v'' f))
    else if v = v'' then Misc.union (gen v f) (map_nested (rename v' v) (gen v' f))
    else gen v f
  | Conj (f, g) -> Misc.union (gen v f) (gen v g)
  | Exists (v', f) -> if v = v' then []
                      else map_nested (proj v') (gen v f)
  | Prev (i, f) -> List.map (List.map (fun g -> Prev (i, g))) (gen v f)
  | Next (i, f) -> List.map (List.map (fun g -> Next (i, g))) (gen v f)
  | Since (f, i, g) -> List.map (List.map (fun g -> once i g)) (gen v g)
  | Until (f, i, g) -> List.map (List.map (fun g -> eventually i g)) (gen v g)

let rec gen_var v = function
  | False -> true
  | True -> false
  | Eq (v', Const c) -> v = v'
  | Eq (v', Var v'') -> false
  | Pred (r, ts) -> List.mem v (fv_terms ts)
  | Neg (Neg f) -> gen_var v f
  | Neg (Conj (f, g)) -> gen_var v (Disj (Neg f, Neg g))
  | Neg (Disj (f, g)) -> gen_var v (Conj (Neg f, Neg g))
  | Neg f -> false
  | Disj (f, g) -> gen_var v f && gen_var v g
  | Conj (f, (Eq (v', Var v''))) ->
    if v = v' then gen_var v f || gen_var v'' f
    else if v = v'' then gen_var v f || gen_var v' f
    else gen_var v f
  | Conj (f, g) -> gen_var v f || gen_var v g
  | Exists (v', f) -> if v = v' then false
                      else gen_var v f
  | Prev (i, f) -> gen_var v f
  | Next (i, f) -> gen_var v f
  | Since (f, i, g) -> gen_var v g
  | Until (f, i, g) -> gen_var v g

let eqonce i = function
  | Eq (v, Var v') -> Eq (v, Var v')
  | f -> once i f
let eqeventually i = function
  | Eq (v, Var v') -> Eq (v, Var v')
  | f -> eventually i f

(* Figures 4.1 and 4.7 *)
let rec cov v = function
  | False -> [[]]
  | True -> [[]]
  | Eq (v', Const c) -> if v = v' then [[Eq (v, Const c)]] else [[]]
  | Eq (v', Var v'') -> if v = v' && v <> v'' then [[Eq (v, Var v'')]]
                        else if v = v'' && v <> v' then [[Eq (v, Var v')]]
                        else [[]]
  | Pred (r, ts) -> if List.mem v (fv_terms ts) then [[Pred (r, ts)]] else [[]]
  | Neg f -> cov v f
  | Disj (f, g) -> (match (var_bot v f, var_bot v g) with
      (True, True) -> Misc.union (cov v f) (cov v g)
    | (True, _) -> cov v f
    | (_, True) -> cov v g
    | _ -> pairwise Misc.union (cov v f) (cov v g))
  | Conj (f, g) -> (match (var_bot v f, var_bot v g) with
      (False, False) -> Misc.union (cov v f) (cov v g)
    | (False, _) -> cov v f
    | (_, False) -> cov v g
    | _ -> pairwise Misc.union (cov v f) (cov v g))
  | Exists (v', f) -> if v = v' then [[]] else
    Misc.union' (List.map (fun cs -> if List.mem (Eq (v, Var v')) cs then pairwise Misc.union
                                       [List.map (proj v') (Misc.diff cs [Eq (v, Var v')])]
                                       (map_nested (rename v' v) (gen v' f))
                                     else [List.map (proj v') cs]) (cov v f))
  | Prev (i, f) -> List.map (List.map (fun g -> Prev (i, g))) (cov v f)
  | Next (i, f) -> List.map (List.map (fun g -> Next (i, g))) (cov v f)
  | Since (f, i, g) ->
    let css = (match var_bot v g with
      False -> cov v g
    | _ -> pairwise Misc.union (cov v f) (cov v g)) in
    List.map (List.map (fun h -> eqonce i h)) css
  | Until (f, i, g) ->
    let css = (match var_bot v g with
      False -> cov v g
    | _ -> pairwise Misc.union (cov v f) (cov v g)) in
    List.map (List.map (fun h -> eqeventually i h)) css

(* Figure 2.11 *)
let rec vgen v = function
  | False -> [[]]
  | True -> []
  | Eq (v', Const c) -> if v = v' then [[Eq (v, Const c)]] else []
  | Eq (v', Var v'') -> []
  | Pred (r, ts) -> if List.mem v (fv_terms ts) then [[Pred (r, ts)]] else []
  | Neg (Neg f) -> vgen v f
  | Neg (Conj (f, g)) -> vgen v (Disj (Neg f, Neg g))
  | Neg (Disj (f, g)) -> vgen v (Conj (Neg f, Neg g))
  | Neg (Exists (v', f)) -> if v = v' then [] else vgen v (Neg f)
  | Neg f -> []
  | Disj (f, g) -> pairwise Misc.union (vgen v f) (vgen v g)
  | Conj (f, g) -> Misc.union (vgen v f) (vgen v g)
  | Exists (v', f) -> if v = v' then []
                      else map_nested (proj v') (vgen v f)

(* Figure 2.11 *)
let rec con v = function
  | False -> [[]]
  | True -> [[]]
  | Eq (v', Const c) -> if v = v' then [[Eq (v, Const c)]] else [[]]
  | Eq (v', Var v'') -> if v = v' && v <> v'' then []
                        else if v = v'' && v <> v' then []
                        else [[]]
  | Pred (r, ts) -> if List.mem v (fv_terms ts) then [[Pred (r, ts)]] else [[]]
  | Neg (Neg f) -> con v f
  | Neg (Conj (f, g)) -> con v (Disj (Neg f, Neg g))
  | Neg (Disj (f, g)) -> con v (Conj (Neg f, Neg g))
  | Neg (Exists (v', f)) -> if v = v' then [[]] else con v (Neg f)
  | Disj (f, g) -> pairwise Misc.union (con v f) (con v g)
  | Conj (f, g) -> Misc.union (pairwise Misc.union (con v f) (con v g)) (Misc.union (vgen v f) (vgen v g))
  | Exists (v', f) -> if v = v' then [[]] else map_nested (proj v') (con v f)
  | f -> if List.mem v (fv_fmla f) then [] else [[]]

let eqs x cs = List.concat (List.map (fun c -> match c with Eq (_, Var v) -> if x = v then [] else [v] | _ -> []) cs)
let qpreds cs = List.filter (fun c -> match c with Eq (_, Var _) -> false | _ -> true) cs

let opt_cov cost =
  let rec aux = function
    | [] -> failwith "[opt_cov] empty set"
    | [(x, cs)] -> (x, cs)
    | ((x, cs) :: (x', cs') :: xcss) ->
      if cs = [] then (x, cs) else if cs' = [] then (x', cs') else
      let fold_cs = List.fold_left (fun (po, cst) c -> let (p', cst') = cost c in (Some (match po with Some p -> min p p' | None -> p'), cst + cst')) (None, 0) in
      let (Some p, cst) = fold_cs cs in
      let (Some p', cst') = fold_cs cs' in
      let n = List.length (eqs x cs) in
      let n' = List.length (eqs x' cs') in
      if p > p' then aux ((x, cs) :: xcss)
      else if p < p' then aux ((x', cs') :: xcss)
      else if n < n' then aux ((x, cs) :: xcss)
      else if n' < n then aux ((x', cs') :: xcss)
      else if cst < cst' then aux ((x, cs) :: xcss)
      else aux ((x', cs') :: xcss)
  in aux

(* Figures 4.2 and 4.8 *)
let rb restr cov cost =
  let rec aux = function
    | Neg f -> Neg (aux f)
    | Disj (f, g) -> Disj (aux f, aux g)
    | Conj (f, g) -> Conj (aux f, aux g)
    | Exists (v, f) ->
      let rec r acc = function
        | [] -> List.rev acc
        | (h :: hs) ->
          if not (List.mem v (fv_fmla h)) then r (h :: acc) hs else
          if gen_var v h then r (h :: acc) hs else
             let vcss = List.map (fun cs -> (v, cs)) (cov v h) in
             let (_, cs) = opt_cov cost vcss in
             r acc (Misc.remdups (conj (h :: disj (List.map (restr v) (qpreds cs)) :: []) ::
                                  var_bot v h ::
                                  List.map (fun x -> rename v x h) (eqs v cs) @ hs))
      in disj (List.map (exists [v]) (r [] (flatten_disj (aux f))))
    | Prev (i, f) -> Prev (i, aux f)
    | Next (i, f) -> Next (i, aux f)
    | Since (f, i, g) ->
      let doSince = (fun f i g op ->
        let ngf = List.filter (fun v -> not (gen_var v f)) (fv_fmla f) in
        let ngg = List.filter (fun v -> not (gen_var v g)) (fv_fmla g) in
        if Misc.empty (Misc.union ngf ngg) && Misc.subset (fv_fmla f) (fv_fmla g) then
          Since (op f, i, g)
        else
          let covsince = (fun v -> match var_bot v g with False -> cov v g | _ -> pairwise Misc.union (cov v f) (cov v g)) in
          let xcss = List.concat (List.map (fun v -> List.map (fun cs -> (v, cs)) (covsince v)) (Misc.union (Misc.union ngf ngg) (Misc.diff (fv_fmla f) (fv_fmla g)))) in
          let (x, cs) = opt_cov cost xcss in
          let i' = T.dropL i in
          let tqpredsoronce = disj (List.map (once i') (qpreds cs)) in
          let tqpredsor = disj (qpreds cs) in
          let neqs = List.map (fun y -> Neg (Eq (x, Var y))) (eqs x cs) in
          let f' = if List.mem x (fv_fmla f) && not (gen_var x f) then rconj [f; tqpredsoronce] else f in
          let q = aux (disj (conj (Since (op f', i', rconj [g; tqpredsoronce]) :: neqs) ::
          conj (Since (op f', i', rconj [op f; tqpredsor; Prev (i', rconj [Neg tqpredsoronce; var_bot x (Since (op f, i', g))])]) :: neqs) ::
          conj (Neg tqpredsoronce :: var_bot x (Since (op f, i', g)) :: neqs) :: List.map (fun y -> rconj [Eq (x, Var y); rename x y (Since (op f, i', g))]) (eqs x cs))) in
          if T.memL T.zero T.zero i then q
          else rconj [once i True; Neg (once (T.flipL i) (Disj (Neg (op f), Neg (Prev (i', q)))))]
      ) in
      if T.tfin (T.rightI i) then Since (aux f, i, aux g)
      else
        (match aux f with
          Neg f' -> doSince f' i (aux g) (fun h -> Neg h)
        | f' -> doSince f' i (aux g) (fun h -> h))
    | Until (f, i, g) -> Until (aux f, i, aux g)
    | f -> f
  in aux

(* Figure 4.3 *)
let split restr cov cost f =
  let w f es = List.filter (fun v -> Misc.disjoint (eq_trans v es) (fv_fmla f)) (Misc.union' (List.map (fun (x, y) -> [x; y]) es)) in
  let rec aux (qfin, qinf) = function
    | [] -> (List.rev qfin, List.rev qinf)
    | ((h, es) :: hes) ->
      let ngh = List.filter (fun v -> not (gen_var v h)) (fv_fmla h) in
      if ngh = [] then aux ((h, es) :: qfin, qinf) hes
      else (
         let xcss = List.concat (List.map (fun v -> List.map (fun cs -> (v, cs)) (cov v h)) ngh) in
         let (x, cs) = opt_cov cost xcss in
         aux (qfin, var_bot x h :: qinf)
             ((conj (h :: disj (List.map (restr x) (qpreds cs)) :: []), es) ::
                        List.map (fun y -> rename x y h, es @ [(x, y)]) (eqs x cs) @ hes))
  in let rec foo (qfin, qinf) = function
    | [] -> (qfin, qinf)
    | ((h, es) :: hes) ->
      let ches = conj (h :: List.map (fun (x, y) -> Eq (x, Var y)) es) in
      if Misc.equal (fv_fmla ches) (fv_fmla f) && w h es = [] then foo ((h, es) :: qfin, qinf) hes
      else foo (qfin, ches :: qinf) hes
  in let f' = rb restr cov cost f
  in let (qfin, qinf) = aux ([], []) [(f', [])]
  in let (qfin, qinf) = foo ([], qinf) qfin
  in (disj (List.map (fun (f, es) -> conj (f :: List.map (fun (x, y) -> Eq (x, Var y)) es)) qfin),
      rb restr cov cost (disj (List.map (fun f -> exists (fv_fmla f) f) qinf)))

let sr f =
  let rec aux = function
    | False -> true
    | True -> true
    | Eq (v, t) -> true
    | Pred (r, ts) -> true
    | Neg f -> aux f
    | Conj (f, g) -> aux f && aux g
    | Disj (f, g) -> aux f && aux g
    | Exists (v, f) -> gen_var v f && aux f
    | Prev (i, f) -> aux f
    | Next (i, f) -> aux f
    | Since (f, i, g) -> aux f && aux g
    | Until (f, i, g) -> aux f && aux g
  in aux f && List.for_all (fun v -> gen_var v f) (fv_fmla f)

let evaluable f =
  let rec aux = function
    | False -> true
    | True -> true
    | Eq (v, t) -> true
    | Pred (r, ts) -> true
    | Neg f -> aux f
    | Conj (f, g) -> aux f && aux g
    | Disj (f, g) -> aux f && aux g
    | Exists (v, f) -> (match con v f with [] -> false | _ -> aux f)
    | _ -> false
  in aux f && List.for_all (fun v -> match vgen v f with [] -> false | _ -> true) (fv_fmla f)

let minimal p xs =
  let rec aux xs = function
  | [] -> false
  | (y :: ys) -> p (xs @ ys) || aux (y :: xs) ys in
  p xs && not (aux [] xs)

(* Figures 2.16 and 4.12 *)
let srra cost q =
  let opt_srra = opt_choice (fun (f, rs) -> cost f) in
  let rec aux q rs =
  let do_bin q1 op1 q2 rs op2 op3 =
    let rss' = List.filter (minimal (fun rs' -> sr (rconj (q1 :: q2 :: rs')) && sr (rconj (q2 :: rs')) && Misc.subset (fv_fmla q1) (fv_fmla (conj (q2 :: rs'))))) (powset rs) in
    opt_srra (List.concat (List.map (fun rs' ->
      let q1's = (if ranf q1 then [(q1, [])] else aux (rconj (q1 :: op3 q2 :: List.map op2 rs')) [] :: (if sr (rconj (q1 :: rs')) then [aux (rconj (q1 :: List.map op2 rs')) []] else [])) in
      let (q2', _) = aux (rconj (q2 :: List.map op2 rs')) [] in
      List.map (fun (q1', _) -> (cp (op1 q1' q2'), [])) q1's
    ) rss')) in
  if ranf q then (q, []) else
  match q with
    | Eq (v, Var v') -> aux (rconj (Eq (v, Var v') :: rs)) []
    | Neg f ->
      let rss' = List.filter (minimal (fun rs' -> sr (rconj (Neg f :: rs')))) (powset rs) in
      opt_srra (List.map (fun rs' -> match rs' with [] -> let (f', _) = aux f [] in (cp (Neg f'), []) | _ -> aux (rconj (Neg f :: rs')) []) rss')
    | Disj _ ->
      let fs = flatten_disj q in
      let rss' = List.filter (minimal (fun rs' -> sr (disj (List.map (fun f -> rconj (f :: rs')) fs)))) (powset rs) in
      opt_srra (List.map (fun rs' -> (disj (List.map (fun f -> let (f', _) = aux (rconj (f :: rs')) [] in f') fs), rs')) rss')
    | Conj _ ->
      let fs = flatten_conj q @ rs in
      let fps = List.filter (fun f -> match f with Eq (v, Var v') -> false | Neg _ -> false | _ -> true) fs in
      let feqs = List.filter (fun f -> match f with Eq (v, Var v') -> true | _ -> false) fs in
      let fns = List.filter (fun f -> match f with Neg (Eq (v, Var v')) -> false | Neg _ -> true | _ -> false) fs in
      let fneqs = List.filter (fun f -> match f with Neg (Eq (v, Var v')) -> true | _ -> false) fs in
      let fps' = List.map (fun f -> (aux f (Misc.diff (Misc.union fps feqs) [f]), f)) fps in
      let fns' = List.map (fun f -> match f with Neg f -> let (f', _) = aux f (Misc.union fps feqs) in Neg f') fns in
      let fpss' = List.filter (minimal (fun fs' -> Misc.subset fps (Misc.union' (List.map (fun ((f', rs'), f) -> Misc.union rs' [f]) fs')))) (powset fps') in
      opt_srra (List.map (fun fs' -> (sconj (List.map (fun ((f', rs'), f) -> f') fs' @ feqs @ fns' @ fneqs),
                                      Misc.union' (List.map (fun ((f', rs'), f) -> Misc.inter rs' rs) fs'))) fpss')
    | Exists (v, f) ->
      let (vs, f) = flatten_ex (Exists (v, f)) in
      let fvrs = fv_fmlas rs in
      let (vs, f) = List.fold_right (fun v (vs, f) ->
        if List.mem v fvrs then
          let v' = fresh_var (fv_fmlas (f :: rs)) in
          (v' :: vs, rename v v' f)
        else (v :: vs, f)) vs ([], f) in
      let rss' = List.filter (minimal (fun rs' -> sr (rconj (f :: rs')))) (powset rs) in
      opt_srra (List.map (fun rs' -> let (f', _) = aux (rconj (f :: rs')) [] in (cp (exists vs f'), rs')) rss')
    | Prev (i, f) ->
      let (f', rs') = aux f (List.map (fun r -> Next (i, r)) rs) in
      (cp (Prev (i, f')), List.map (fun r -> match r with Next (i', r') -> r') rs')
    | Next (i, f) ->
      let (f', rs') = aux f (List.map (fun r -> Prev (i, r)) rs) in
      (cp (Next (i, f')), List.map (fun r -> match r with Prev (i', r') -> r') rs')
    | Since (f, i, g) ->
      let doSince = (fun f g op ->
        if T.tfin (T.rightI i) then do_bin f (fun q1 q2 -> Since (op q1, i, q2)) g rs (eventually (T.dropL i)) (once (T.dropL i))
        else (
          let (f', _) = aux f [] in
          let (g', _) = aux g [] in
          (cp (Since (op f', i, g')), [])
        )
      ) in
      (match f with
        Neg f' -> doSince f' g (fun h -> Neg h)
      | _ -> doSince f g (fun h -> h))
    | Until (f, i, g) ->
      let doUntil = (fun f g op -> do_bin f (fun q1 q2 -> Until (op q1, i, q2)) g rs (once (T.dropL i)) (eventually (T.dropL i))) in
      (match f with
        Neg f' -> doUntil f' g (fun h -> Neg h)
      | _ -> doUntil f g (fun h -> h))
    | _ -> (cp q, [])
  in let (q', _) = aux (srnf q) []
  in q'

let rw restr cov cost f =
  let (qfin, qinf) = split restr cov cost f in
  (ssrnf (srra cost qfin), ssrnf (srra cost qinf))

let rtrans cost f = rw (fun v f -> f) cov cost f

end

module TimestampInt = struct
  type t = int option
  type inter = Interval of t * t * bool * bool
  let zero = Some 0
  let tfin = function
  | Some _ -> true
  | None -> false
  let le x = function
  | Some y' -> (match x with Some x' -> x' <= y' | None -> false)
  | None -> true
  let lt x y = le x y && not (x = y)
  let add x = function
  | Some y' -> (match x with Some x' -> Some (x' + y') | None -> None)
  | None -> None
  let string_of_i = function
  | Interval (Some l, r, b1, b2) -> "[" ^ string_of_int (if b1 then l else l + 1) ^ ", " ^ (match r with Some r' -> string_of_int (if b2 then r' else r' - 1) | _ -> "*") ^ "]"
  | _ -> failwith "[string_of_i]"
  let memL u v = function
  | Interval (l, r, true, b2) -> le (add u l) v
  | Interval (l, r, false, b2) -> lt (add u l) v
  let memR u v = function
  | Interval (l, r, b1, true) -> le v (add u r)
  | Interval (l, r, b1, false) -> lt v (add u r)
  let rightI = function
  | Interval (l, r, b1, b2) -> r
  let isFull i = (not (tfin (rightI i))) && (memL zero zero i)
  let dropL = function
  | Interval (l, r, b1, b2) -> Interval (zero, r, true, b2)
  let dropR = function
  | Interval (l, r, b1, b2) -> Interval (l, None, b1, true)
  let flipL = function
  | Interval (l, r, b1, b2) -> if not (l = zero && b1) then Interval (zero, l, true, not b1) else failwith "invalid flipL"
end

module FOInt = FO(TimestampInt)
