let remdups l =
  let rec rm acc = function
    | [] -> List.rev acc
    | h::t  -> rm (h :: acc) (List.filter (fun x -> x <> h) t)
  in
  rm [] l

let union l1 l2 = remdups (l1 @ l2)
let union' ls = remdups (List.concat ls)

let inter l1 l2 = List.filter (fun x -> (List.mem x l2)) (remdups l1)
let diff l1 l2 = List.filter (fun x -> not (List.mem x l2)) (remdups l1)

let empty xs = (xs = [])
let disjoint l1 l2 = empty (inter l1 l2)

let rec subset l1 l2 =
  match l1 with
  | h::t -> (List.mem h l2) && (subset t l2)
  | [] -> true

let equal l1 l2 = (subset l1 l2 && subset l2 l1)
