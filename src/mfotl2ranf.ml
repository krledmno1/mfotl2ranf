open Trans

let _ =
  let prefix = Sys.argv.(1) in
  let (f, tlog) = tparse prefix in
  let _ = rtrans (prefix ^ ".") tlog f in
  ()
