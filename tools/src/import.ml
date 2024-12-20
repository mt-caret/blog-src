include Composition_infix

let write_endline string ~filename =
  let open Shexp_process in
  echo ~where:Stdout ~n:() string |> outputs_to filename
;;
